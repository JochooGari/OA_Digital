import logging
import time
import requests
import google.auth
import google.auth.transport.requests
import config

logger = logging.getLogger(__name__)


def get_access_token() -> str:
    """Obtain a Google OAuth2 access token from the service account (ADC).

    On Cloud Run, the service account token is generated automatically.
    Locally, uses Application Default Credentials (gcloud auth application-default login).
    """
    credentials, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    credentials.refresh(google.auth.transport.requests.Request())
    logger.info("Google OAuth2 token obtained (project=%s).", project)
    return credentials.token


_RETRY_STATUS_CODES = {429, 500, 502, 503, 504}
_MAX_RETRIES = 3
_RETRY_BACKOFF = 2  # seconds (doubles each attempt)


def remove_members_batch(token: str, members: list[str]) -> dict:
    """
    Remove a batch of members from the Pro licence group.
    Retries automatically on transient errors (429, 5xx) with exponential backoff.
    """
    url = f"{config.API_BASE_URL}/groups/{config.PRO_LICENSE_GROUP_EMAIL}/members"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {"members": members}

    for attempt in range(1, _MAX_RETRIES + 1):
        response = requests.delete(url, json=payload, headers=headers, timeout=30)
        if response.status_code not in _RETRY_STATUS_CODES:
            response.raise_for_status()
            return response.json()
        wait = _RETRY_BACKOFF ** attempt
        logger.warning("Attempt %d/%d failed (HTTP %d) — retrying in %ds...",
                       attempt, _MAX_RETRIES, response.status_code, wait)
        time.sleep(wait)

    response.raise_for_status()  # raise after all retries exhausted
    return response.json()


def revoke_licences(emails: list[str]) -> dict:
    """
    Revoke Pro licences for a list of users.
    Splits into batches of BATCH_SIZE to comply with API limits.

    Returns a summary dict with counts of successes and failures.
    """
    summary = {"total": len(emails), "revoked": 0, "failed": 0, "errors": []}

    if not emails:
        logger.info("No users to revoke.")
        return summary

    token = get_access_token()
    batches = [emails[i:i + config.BATCH_SIZE] for i in range(0, len(emails), config.BATCH_SIZE)]
    logger.info("Processing %d users in %d batch(es) of max %d.", len(emails), len(batches), config.BATCH_SIZE)

    for i, batch in enumerate(batches, start=1):
        logger.info("Batch %d/%d — revoking %d users: %s", i, len(batches), len(batch), batch)
        try:
            result = remove_members_batch(token, batch)
            summary["revoked"] += len(batch)
            logger.info("Batch %d/%d — success. API response: %s", i, len(batches), result.get("status"))
        except requests.HTTPError as e:
            summary["failed"] += len(batch)
            error_msg = f"Batch {i}/{len(batches)} failed (HTTP {e.response.status_code}): {e.response.text}"
            summary["errors"].append(error_msg)
            logger.error(error_msg)
        except Exception as e:
            summary["failed"] += len(batch)
            error_msg = f"Batch {i}/{len(batches)} failed (unexpected error): {e}"
            summary["errors"].append(error_msg)
            logger.error(error_msg)

    return summary
