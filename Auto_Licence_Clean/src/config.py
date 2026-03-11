import os

# BigQuery
BIGQUERY_PROJECT = os.environ.get("BIGQUERY_PROJECT", "itg-btdppublished-gbl-ww-pd")
BIGQUERY_BILLING_PROJECT = os.environ.get("BIGQUERY_BILLING_PROJECT")  # Required — GCP project used for query billing

# BTDP Groups API (Google OAuth2 — no Azure client_id/secret needed from GCP)
API_BASE_URL = os.environ.get("API_BASE_URL", "https://api.loreal.net/global/it4it/itg-groupsapi/v1")

# Licence group
PRO_LICENSE_GROUP_EMAIL = os.environ.get("PRO_LICENSE_GROUP_EMAIL")  # Required — e.g. IT-GLOBAL-PBI-PRO@loreal.com

# Script behaviour
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "20"))   # Max 20 per API call (SafeMode)
RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "120"))

# CSV export (dry-run)
CSV_EXPORT_PATH = os.environ.get("CSV_EXPORT_PATH", "./output/dry_run_report.csv")


def validate():
    """Fail fast if required environment variables are missing."""
    missing = []
    if not BIGQUERY_BILLING_PROJECT:
        missing.append("BIGQUERY_BILLING_PROJECT")
    if not PRO_LICENSE_GROUP_EMAIL:
        missing.append("PRO_LICENSE_GROUP_EMAIL")
    if missing:
        raise EnvironmentError(f"Missing required environment variables: {', '.join(missing)}")
