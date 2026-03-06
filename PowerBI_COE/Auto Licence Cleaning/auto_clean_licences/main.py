import logging
import sys
import config
import bigquery_client
import groups_api_client
import reporter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


def run():
    # 1. Validate configuration
    config.validate()

    mode = "DRY-RUN" if config.DRY_RUN else "LIVE"
    logger.info("=== Auto-Clean Licences Pro — %s mode ===", mode)
    logger.info("Group: %s | Retention: %d days | Batch size: %d",
                config.PRO_LICENSE_GROUP_EMAIL, config.RETENTION_DAYS, config.BATCH_SIZE)

    # 2. Fetch users to revoke from BigQuery
    try:
        emails = bigquery_client.get_users_to_revoke()
    except Exception as e:
        logger.critical("BigQuery query failed: %s", e)
        sys.exit(1)

    if not emails:
        logger.info("No users to revoke. Job complete.")
        return

    logger.info("Users to revoke (%d):", len(emails))
    for email in emails:
        logger.info("  - %s", email)

    # 3. Dry-run: export CSV for validation, no API call
    if config.DRY_RUN:
        reporter.export_dry_run_csv(emails, config.CSV_EXPORT_PATH)
        logger.info("[DRY-RUN] No licences were revoked. Review the CSV then set DRY_RUN=false to apply.")
        return

    # 4. Revoke licences via BTDP Groups API
    try:
        summary = groups_api_client.revoke_licences(emails)
    except Exception as e:
        logger.critical("Groups API call failed critically: %s", e)
        sys.exit(1)

    # 5. Log summary
    logger.info("=== Summary ===")
    logger.info("Total users processed : %d", summary["total"])
    logger.info("Successfully revoked  : %d", summary["revoked"])
    logger.info("Failed                : %d", summary["failed"])

    if summary["errors"]:
        logger.error("Errors encountered:")
        for err in summary["errors"]:
            logger.error("  %s", err)

    # 6. Export audit CSV
    reporter.export_live_summary_csv(summary, emails, config.CSV_EXPORT_PATH)

    # 7. Exit with error code if any failure (triggers Cloud Run Job failure → Cloud Monitoring alert)
    if summary["failed"] > 0:
        logger.error("Job completed with %d failure(s). Check logs above.", summary["failed"])
        sys.exit(1)

    logger.info("Job completed successfully.")


if __name__ == "__main__":
    run()
