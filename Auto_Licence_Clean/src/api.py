"""
Flask API backend for Auto Licence Clean dashboard.
Exposes endpoints for the frontend to query BigQuery, check config, and trigger dry runs.

Usage:
    cd Auto_Licence_Clean/src
    python api.py
"""

import logging
import os
import sys
import json
from datetime import datetime
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

import config
import bigquery_client
import reporter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

app = Flask(__name__, static_folder="../docs", static_url_path="")
CORS(app)

# In-memory execution history (reset on restart — use a DB for persistence)
execution_history = []


# ── Serve frontend ──────────────────────────────────

@app.route("/")
def serve_frontend():
    return send_from_directory(app.static_folder, "index.html")


# ── API: Status ─────────────────────────────────────

@app.route("/api/status")
def get_status():
    """Return current configuration and last run info."""
    last_run = execution_history[-1] if execution_history else None
    return jsonify({
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
        "total_runs": len(execution_history),
    })


# ── API: Query BigQuery ─────────────────────────────

@app.route("/api/users")
def get_users():
    """Query BigQuery and return the list of users to revoke."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        return jsonify({
            "status": "ok",
            "count": len(emails),
            "users": emails,
            "queried_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
        })
    except Exception as e:
        logger.error("BigQuery query failed: %s", e)
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/count")
def count_users():
    """Query BigQuery and return ONLY the count (no emails)."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        count = len(emails)

        run_record = {
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
            "mode": "COUNT",
            "users_identified": count,
            "revoked": 0,
            "failed": 0,
            "outcome": "SUCCESS",
        }
        execution_history.append(run_record)

        return jsonify({
            "status": "ok",
            "count": count,
            "queried_at": run_record["timestamp"],
        })
    except Exception as e:
        logger.error("BigQuery count failed: %s", e)
        return jsonify({"status": "error", "message": str(e)}), 500


# ── API: Dry Run ────────────────────────────────────

@app.route("/api/dry-run", methods=["POST"])
def trigger_dry_run():
    """Run the BigQuery query and export CSV without revoking anything."""
    try:
        emails = bigquery_client.get_users_to_revoke()
        csv_path = config.CSV_EXPORT_PATH
        reporter.export_dry_run_csv(emails, csv_path)

        run_record = {
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
            "mode": "DRY_RUN",
            "users_identified": len(emails),
            "revoked": 0,
            "failed": 0,
            "outcome": "SUCCESS (DRY)",
            "csv_path": csv_path,
        }
        execution_history.append(run_record)

        return jsonify({
            "status": "ok",
            "run": run_record,
            "users": emails[:50],  # Return first 50 for preview
            "total": len(emails),
        })
    except Exception as e:
        run_record = {
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
            "mode": "DRY_RUN",
            "users_identified": 0,
            "revoked": 0,
            "failed": 0,
            "outcome": "FAILED",
            "error": str(e),
        }
        execution_history.append(run_record)
        logger.error("Dry run failed: %s", e)
        return jsonify({"status": "error", "message": str(e), "run": run_record}), 500


# ── API: Execution History ──────────────────────────

@app.route("/api/logs")
def get_logs():
    """Return execution history."""
    return jsonify({
        "status": "ok",
        "logs": list(reversed(execution_history)),
        "count": len(execution_history),
    })


# ── API: Validate Config ───────────────────────────

@app.route("/api/config/validate")
def validate_config():
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
    return jsonify({"status": "ok" if all_ok else "incomplete", "variables": variables})


# ── Main ────────────────────────────────────────────

if __name__ == "__main__":
    # Load .env file if python-dotenv is installed
    try:
        from dotenv import load_dotenv
        load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
        # Reload config values after loading .env
        import importlib
        importlib.reload(config)
        logger.info("Loaded .env file")
    except ImportError:
        logger.info("python-dotenv not installed — using system env vars only")

    port = int(os.environ.get("PORT", 5000))
    logger.info("Starting Auto Licence Clean API on http://localhost:%d", port)
    app.run(host="0.0.0.0", port=port, debug=True)
