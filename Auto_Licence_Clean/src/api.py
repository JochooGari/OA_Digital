"""
FastAPI backend for Auto Licence Clean dashboard.
Exposes endpoints for the frontend to query BigQuery, check config, and trigger dry runs.

Usage:
    cd Auto_Licence_Clean/src
    uvicorn api:app --reload --port 5000
"""

import logging
import os
import subprocess
import sys
import uuid
from collections import defaultdict
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import bigquery_client
import config
import reporter
import storage

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

HISTORY_FILE = "execution_history.json"
SCHEDULE_FILE = "schedule.json"
MAX_HISTORY = 200


def _load_history() -> list[dict]:
    return storage.read_json(HISTORY_FILE, default=[])


def _save_history(history: list[dict]):
    storage.write_json(HISTORY_FILE, history[-MAX_HISTORY:])


def _append_history(record: dict):
    history = _load_history()
    history.append(record)
    _save_history(history)


@asynccontextmanager
async def lifespan(application: FastAPI):
    # Load .env file on startup
    try:
        from dotenv import load_dotenv
        load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
        import importlib
        importlib.reload(config)
        logger.info("Loaded .env file")
    except ImportError:
        logger.info("python-dotenv not installed — using system env vars only")
    yield


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


app = FastAPI(
    title="Auto Licence Clean API",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Serve frontend ──────────────────────────────────

@app.get("/", include_in_schema=False)
async def serve_frontend():
    return FileResponse(os.path.join(os.path.dirname(__file__), "..", "docs", "index.html"))


# ── API: Status ─────────────────────────────────────

@app.get("/api/status")
async def get_status():
    """Return current configuration and last run info."""
    history = _load_history()
    last_run = history[-1] if history else None
    return {
        "config": {
            "BIGQUERY_BILLING_PROJECT": config.BIGQUERY_BILLING_PROJECT or "",
            "BIGQUERY_PROJECT": config.BIGQUERY_PROJECT,
            "PRO_LICENSE_GROUP_EMAIL": config.PRO_LICENSE_GROUP_EMAIL or "",
            "API_BASE_URL": config.API_BASE_URL,
            "DRY_RUN": config.DRY_RUN,
            "BATCH_SIZE": config.BATCH_SIZE,
            "RETENTION_DAYS": config.RETENTION_DAYS,
        },
        "last_run": last_run,
        "total_runs": len(history),
    }


# ── API: Query BigQuery ─────────────────────────────

@app.get("/api/users")
async def get_users():
    """Query BigQuery and return the list of users to revoke."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        return {
            "status": "ok",
            "count": len(emails),
            "users": emails,
            "queried_at": _now(),
        }
    except Exception as e:
        logger.error("BigQuery query failed: %s", e)
        return JSONResponse({"status": "error", "message": str(e)}, status_code=500)


@app.get("/api/count")
async def count_users():
    """Query BigQuery and return ONLY the count (no emails)."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        count = len(emails)

        run_record = {
            "run_id": str(uuid.uuid4())[:8],
            "timestamp": _now(),
            "mode": "COUNT",
            "users_identified": count,
            "revoked": 0,
            "failed": 0,
            "outcome": "SUCCESS",
            "trigger": "manual",
        }
        _append_history(run_record)

        return {
            "status": "ok",
            "count": count,
            "queried_at": run_record["timestamp"],
        }
    except Exception as e:
        logger.error("BigQuery count failed: %s", e)
        return JSONResponse({"status": "error", "message": str(e)}, status_code=500)


# ── API: Dry Run ────────────────────────────────────

@app.post("/api/dry-run")
async def trigger_dry_run():
    """Run the BigQuery query and export CSV without revoking anything."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        csv_path = config.CSV_EXPORT_PATH
        reporter.export_dry_run_csv(emails, csv_path)

        run_record = {
            "run_id": str(uuid.uuid4())[:8],
            "timestamp": _now(),
            "mode": "DRY_RUN",
            "users_identified": len(emails),
            "revoked": 0,
            "failed": 0,
            "outcome": "SUCCESS (DRY)",
            "csv_path": csv_path,
            "trigger": "manual",
        }
        _append_history(run_record)

        return {
            "status": "ok",
            "run": run_record,
            "total": len(emails),
        }
    except Exception as e:
        run_record = {
            "run_id": str(uuid.uuid4())[:8],
            "timestamp": _now(),
            "mode": "DRY_RUN",
            "users_identified": 0,
            "revoked": 0,
            "failed": 0,
            "outcome": "FAILED",
            "error": str(e),
            "trigger": "manual",
        }
        _append_history(run_record)
        logger.error("Dry run failed: %s", e)
        return JSONResponse({"status": "error", "message": str(e), "run": run_record}, status_code=500)


# ── API: Revoke (live execution) ─────────────────────

@app.post("/api/revoke")
async def revoke_users():
    """Execute live revocation via Groups API. Requires DRY_RUN=false."""
    if config.DRY_RUN:
        return JSONResponse(
            {"status": "error", "message": "DRY_RUN is enabled. Set DRY_RUN=false in .env to allow live revocation."},
            status_code=403,
        )

    try:
        import groups_api_client

        emails = bigquery_client.get_users_to_revoke()
        if not emails:
            run_record = {
                "run_id": str(uuid.uuid4())[:8],
                "timestamp": _now(),
                "mode": "LIVE",
                "users_identified": 0,
                "revoked": 0,
                "failed": 0,
                "outcome": "SUCCESS",
                "trigger": "manual",
            }
            _append_history(run_record)
            return {"status": "ok", "message": "No users to revoke.", "run": run_record}

        summary = groups_api_client.revoke_licences(emails)

        csv_path = config.CSV_EXPORT_PATH
        reporter.export_live_summary_csv(emails, summary, csv_path)

        outcome = "SUCCESS" if summary["failed"] == 0 else "PARTIAL_FAILURE"
        run_record = {
            "run_id": str(uuid.uuid4())[:8],
            "timestamp": _now(),
            "mode": "LIVE",
            "users_identified": len(emails),
            "revoked": summary["revoked"],
            "failed": summary["failed"],
            "outcome": outcome,
            "csv_path": csv_path,
            "trigger": "manual",
        }
        _append_history(run_record)

        return {"status": "ok", "run": run_record, "summary": summary}
    except Exception as e:
        run_record = {
            "run_id": str(uuid.uuid4())[:8],
            "timestamp": _now(),
            "mode": "LIVE",
            "users_identified": 0,
            "revoked": 0,
            "failed": 0,
            "outcome": "FAILED",
            "error": str(e),
            "trigger": "manual",
        }
        _append_history(run_record)
        logger.error("Live revocation failed: %s", e)
        return JSONResponse({"status": "error", "message": str(e), "run": run_record}, status_code=500)


# ── API: Execution History ──────────────────────────

@app.get("/api/logs")
async def get_logs():
    """Return execution history."""
    history = _load_history()
    return {
        "status": "ok",
        "logs": list(reversed(history)),
        "count": len(history),
    }


@app.get("/api/history/summary")
async def get_history_summary():
    """Return aggregated execution statistics."""
    history = _load_history()

    total_identified = sum(r.get("users_identified", 0) for r in history)
    total_revoked = sum(r.get("revoked", 0) for r in history)

    last_live = None
    last_dry = None
    for r in reversed(history):
        if r.get("mode") == "LIVE" and not last_live:
            last_live = r.get("timestamp")
        if r.get("mode") == "DRY_RUN" and not last_dry:
            last_dry = r.get("timestamp")
        if last_live and last_dry:
            break

    by_month = defaultdict(lambda: {"count": 0, "identified": 0, "revoked": 0})
    for r in history:
        month = r.get("timestamp", "")[:7]
        if month:
            by_month[month]["count"] += 1
            by_month[month]["identified"] += r.get("users_identified", 0)
            by_month[month]["revoked"] += r.get("revoked", 0)

    return {
        "status": "ok",
        "total_executions": len(history),
        "total_users_identified": total_identified,
        "total_revoked": total_revoked,
        "last_live_run": last_live,
        "last_dry_run": last_dry,
        "executions_by_month": [
            {"month": m, **v} for m, v in sorted(by_month.items(), reverse=True)
        ],
    }


# ── API: Schedule ────────────────────────────────────

FREQUENCY_CRON = {
    "monthly_last_day": "0 {h} L * *",
    "monthly_first": "0 {h} 1 * *",
    "weekly_monday": "0 {h} * * 1",
}

DEFAULT_SCHEDULE = {
    "enabled": False,
    "frequency": "monthly_last_day",
    "time": "02:00",
    "cron_expression": "0 2 L * *",
    "updated_at": None,
    "cloud_scheduler_synced": False,
}


@app.get("/api/schedule")
async def get_schedule():
    """Return current schedule configuration."""
    schedule = storage.read_json(SCHEDULE_FILE, default=DEFAULT_SCHEDULE)
    return {"status": "ok", "schedule": schedule}


class ScheduleUpdate(BaseModel):
    enabled: bool
    frequency: str
    time: str = "02:00"


@app.put("/api/schedule")
async def update_schedule(payload: ScheduleUpdate):
    """Update schedule configuration."""
    if payload.frequency not in FREQUENCY_CRON:
        return JSONResponse(
            {"status": "error", "message": f"Invalid frequency. Must be one of: {list(FREQUENCY_CRON.keys())}"},
            status_code=400,
        )

    try:
        hour = int(payload.time.split(":")[0])
    except (ValueError, IndexError):
        hour = 2

    cron = FREQUENCY_CRON[payload.frequency].format(h=hour)

    schedule = {
        "enabled": payload.enabled,
        "frequency": payload.frequency,
        "time": payload.time,
        "cron_expression": cron,
        "updated_at": _now(),
        "cloud_scheduler_synced": False,
    }
    storage.write_json(SCHEDULE_FILE, schedule)
    logger.info("Schedule updated: %s", schedule)
    return {"status": "ok", "schedule": schedule}


# ── API: SQL Query text (for FAQ) ─────────────────────

@app.get("/api/query-text")
async def get_query_text():
    """Return the SQL query text for display in the FAQ section."""
    return {
        "status": "ok",
        "query_identify": bigquery_client.SQL.strip(),
        "retention_days": config.RETENTION_DAYS,
        "table": "itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.license_pro_users_v1",
    }


# ── API: Auth (GCP ADC) ───────────────────────────

@app.get("/api/auth/status")
async def auth_status():
    """Check if Google ADC credentials are configured."""
    try:
        import google.auth
        credentials, project = google.auth.default()
        return {
            "status": "ok",
            "authenticated": True,
            "project": project or "",
            "account": getattr(credentials, "service_account_email", None)
                       or getattr(credentials, "_account", None)
                       or "ADC configured",
        }
    except Exception as e:
        return {
            "status": "ok",
            "authenticated": False,
            "message": str(e),
        }


@app.post("/api/auth/login")
async def auth_login():
    """Launch gcloud auth application-default login (opens browser)."""
    try:
        gcloud_cmd = "gcloud"
        gcloud_paths = [
            os.path.expandvars(r"%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"),
            os.path.expandvars(r"%APPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"),
            r"C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
            r"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        ]
        for path in gcloud_paths:
            if os.path.exists(path):
                gcloud_cmd = path
                break

        subprocess.Popen(
            f'"{gcloud_cmd}" auth application-default login',
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
        )
        return {
            "status": "ok",
            "message": "Browser opened — complete the Google login, then click Check Auth.",
        }
    except FileNotFoundError:
        return JSONResponse(
            {"status": "error", "message": "gcloud CLI not found. Install it from https://cloud.google.com/sdk/docs/install"},
            status_code=500,
        )
    except Exception as e:
        return JSONResponse({"status": "error", "message": str(e)}, status_code=500)


# ── API: Validate Config ───────────────────────────

@app.get("/api/config/validate")
async def validate_config():
    """Check which config variables are set."""
    variables = [
        {
            "key": "BIGQUERY_BILLING_PROJECT",
            "value": config.BIGQUERY_BILLING_PROJECT or "",
            "required": True,
            "set": bool(config.BIGQUERY_BILLING_PROJECT),
            "source": "Matthieu",
        },
        {
            "key": "PRO_LICENSE_GROUP_EMAIL",
            "value": config.PRO_LICENSE_GROUP_EMAIL or "",
            "required": True,
            "set": bool(config.PRO_LICENSE_GROUP_EMAIL),
            "source": "Anes",
        },
        {
            "key": "DRY_RUN",
            "value": str(config.DRY_RUN),
            "required": False,
            "set": True,
            "source": "Config",
        },
        {
            "key": "BATCH_SIZE",
            "value": str(config.BATCH_SIZE),
            "required": False,
            "set": True,
            "source": "Config",
        },
        {
            "key": "RETENTION_DAYS",
            "value": str(config.RETENTION_DAYS),
            "required": False,
            "set": True,
            "source": "Config",
        },
    ]
    all_ok = all(v["set"] for v in variables if v["required"])
    return {"status": "ok" if all_ok else "incomplete", "variables": variables}


# ── Health check (BTDP standard) ──────────────────

@app.get("/health")
async def health():
    """Health check endpoint for Cloud Run."""
    return {"status": "ok"}


# ── Static files (must be last) ───────────────────

docs_path = os.path.join(os.path.dirname(__file__), "..", "docs")
if os.path.isdir(docs_path):
    app.mount("/", StaticFiles(directory=docs_path), name="static")


# ── Main ────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 5000))
    logger.info("Starting Auto Licence Clean API on http://localhost:%d", port)
    uvicorn.run("api:app", host="0.0.0.0", port=port, reload=True)
