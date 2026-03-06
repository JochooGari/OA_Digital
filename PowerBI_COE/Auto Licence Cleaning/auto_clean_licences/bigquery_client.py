import logging
from google.cloud import bigquery
import config

logger = logging.getLogger(__name__)

SQL = """
SELECT
  *
FROM
  (
    SELECT
      *,
      CASE WHEN is_pro_builder IS TRUE THEN "BUILDER"
           WHEN is_pro_consummer IS TRUE THEN "CONSUMER"
           ELSE NULL END AS pro_user_type,
      CASE WHEN is_pro_consummer IS TRUE OR is_pro_builder IS TRUE OR is_pro_owner IS TRUE
           THEN TRUE ELSE FALSE END AS need_pro_license
    FROM
      (
        SELECT
          *,
          CASE WHEN last_pro_consumer_activity_days <= number_of_retention_days THEN TRUE ELSE FALSE END AS is_pro_consummer,
          CASE WHEN last_pro_builder_activity_days  <= number_of_retention_days THEN TRUE ELSE FALSE END AS is_pro_builder,
          CASE WHEN pbi_asset_ownership_details IS NOT NULL                      THEN TRUE ELSE FALSE END AS is_pro_owner
        FROM
          (
            SELECT
              TRIM(LOWER(user_email))                                                                AS user_email,
              CASE WHEN is_oapass_user IS TRUE THEN 1 ELSE 0 END                                    AS is_oapass_user,
              @retention_days                                                                        AS number_of_retention_days,
              last_event_timestamp                                                                   AS last_activity,
              last_workspace_pro_consumer_activity                                                   AS last_pro_consumer_activity,
              DATE_DIFF(CURRENT_DATE(), DATE(last_workspace_pro_consumer_activity), DAY)             AS last_pro_consumer_activity_days,
              last_workspace_pro_builder_activity                                                    AS last_pro_builder_activity,
              DATE_DIFF(CURRENT_DATE(), DATE(last_workspace_pro_builder_activity), DAY)              AS last_pro_builder_activity_days,
              pbi_asset_ownership_details,
              start_date,
              DATE_DIFF(CURRENT_DATE(), start_date, DAY)                                            AS NbDayHaveLicence,
              CASE WHEN STRPOS(REPLACE(user_email, '@loreal.com', ''), '.') = 0 THEN FALSE ELSE TRUE END AS IsHuman
            FROM
              `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.license_pro_users_v1`
            WHERE
              end_date = '9999-12-31'
            ORDER BY 1 ASC
          )
      )
  )
WHERE
  need_pro_license = FALSE
  AND NbDayHaveLicence > 60
  AND IsHuman = TRUE
"""


def get_users_to_revoke() -> list[str]:
    """Run the SQL query and return the list of user emails to revoke."""
    client = bigquery.Client(project=config.BIGQUERY_BILLING_PROJECT)

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("retention_days", "INT64", config.RETENTION_DAYS)
        ]
    )

    logger.info("Running BigQuery query (retention_days=%d)...", config.RETENTION_DAYS)
    query_job = client.query(SQL, job_config=job_config)
    results = query_job.result()

    emails = [row.user_email for row in results]
    logger.info("Found %d users to revoke.", len(emails))
    return emails
