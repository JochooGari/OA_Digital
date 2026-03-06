SELECT
  *
FROM
  (
    SELECT
      *,
      CASE WHEN is_pro_builder IS TRUE THEN "BUILDER" ELSE CASE WHEN is_pro_consummer IS TRUE THEN "CONSUMER" ELSE NULL END END   AS pro_user_type,
      CASE WHEN is_pro_consummer IS TRUE OR is_pro_builder IS TRUE OR is_pro_owner IS TRUE    THEN TRUE ELSE FALSE END            AS need_pro_license
    FROM
      (
        SELECT
          *,
          CASE WHEN last_pro_consumer_activity_days <= number_of_retention_days               THEN TRUE ELSE FALSE END            AS is_pro_consummer,  -- Est-ce que l'utilisateur a eu une activité de type "CONSUMER" nécessitant une licence Pro sur les XXX derniers jours
          CASE WHEN last_pro_builder_activity_days <= number_of_retention_days                THEN TRUE ELSE FALSE END            AS is_pro_builder,    -- Est-ce que l'utilisateur a eu une activité de type "BUILDER" nécessitant une licence Pro sur les XXX derniers jours
          CASE WHEN pbi_asset_ownership_details IS NOT NULL                                   THEN TRUE ELSE FALSE END            AS is_pro_owner,      -- Est-ce que l'utilisateur est owner d'objets (workspace/semantic model/report) de type Pro, à date
        FROM
          (
            SELECT
              TRIM(LOWER(user_email))                                                                                             AS user_email,
              CASE WHEN is_oapass_user IS TRUE THEN 1 ELSE 0 END                                                                  AS is_oapass_user,
              120                                                                                                                  AS number_of_retention_days,
              last_event_timestamp                                                                                                AS last_activity,
              last_workspace_pro_consumer_activity                                                                                AS last_pro_consumer_activity,
              DATE_DIFF(CURRENT_DATE(), DATE(last_workspace_pro_consumer_activity), DAY)                                          AS last_pro_consumer_activity_days,
              last_workspace_pro_builder_activity                                                                                 AS last_pro_builder_activity,
              DATE_DIFF(CURRENT_DATE(), DATE(last_workspace_pro_builder_activity), DAY)                                           AS last_pro_builder_activity_days,
              pbi_asset_ownership_details                                                                                         AS pbi_asset_ownership_details,
              start_date,
              DATE_DIFF(CURRENT_DATE(),start_date, DAY)                                                                           AS NbDayHaveLicence,
             CASE WHEN STRPOS( REPLACE(user_email,'@loreal.com',''),'.')=0 THEN FALSE ELSE TRUE END                               AS IsHuman

            FROM
              `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.license_pro_users_v1`
            WHERE
              end_date = '9999-12-31'
            ORDER BY
              1 ASC
          )
      )
  )
  where need_pro_license=FALSE
    and NbDayHaveLicence>60 
    and IsHuman=TRUE
;