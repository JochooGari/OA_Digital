import csv
import logging
import os
from datetime import datetime

logger = logging.getLogger(__name__)


def export_dry_run_csv(emails: list[str], path: str) -> None:
    """Export the list of users that would be revoked to a CSV file for validation."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["email", "action", "generated_at"])
        generated_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
        for email in emails:
            writer.writerow([email, "REVOKE_PRO_LICENCE", generated_at])

    logger.info("[DRY-RUN] CSV report exported → %s (%d users)", path, len(emails))


def export_live_summary_csv(summary: dict, emails: list[str], path: str) -> None:
    """Export the post-execution summary to CSV for audit trail."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

    executed_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["email", "status", "executed_at"])
        for email in emails:
            status = "REVOKED" if summary["failed"] == 0 else "PARTIAL_FAILURE"
            writer.writerow([email, status, executed_at])

    logger.info("Execution report exported → %s", path)
