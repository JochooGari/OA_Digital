---
description: "BTDP naming conventions for GCP projects, resources, BigQuery datasets/tables, service accounts, and flows"
user_invocable: true
---

# BTDP Naming Conventions — GCP, BigQuery & Flows

Source : Confluence BTDP — sections 4.2.1, 4.2.2, 4.2.3

---

## 1. Environments

| Name | GCP field | Azure field | Azure App |
|------|-----------|-------------|-----------|
| Production | `pd` | PRD | BTDP-APP-PD-PRD |
| Non-production | `np` | PPRD | BTDP-APP-NP-PPRD |
| Qualification | `qa` | QUAL | BTDP-APP-QA-QUAL |
| Development | `dv` | DEV | BTDP-APP-DV-DEV |

---

## 2. GCP Project Naming

### Format

```
entity-application-country-area-env
```

| Field | Description | Examples |
|-------|-------------|---------|
| `entity` | IT trigram | `itg` |
| `application` | App short name | `btdpback`, `btdppublished` |
| `country` | Country code | `gbl` (global), `fr`, `us` |
| `area` | Zone | `ww` (worldwide), `eu`, `na` |
| `env` | Environment | `pd`, `np`, `qa`, `dv` |

### Examples

```
itg-btdpback-gbl-ww-np
itg-btdppublished-gbl-ww-pd
oa-data-coepowerbi-np
```

---

## 3. GCP Resource Naming

### Format

```
app_short_name-service_trigram-identifier-region_id-env
```

### Service Trigrams

| Trigram | Service |
|---------|---------|
| `gcr` | Cloud Run |
| `gcf` | Cloud Function |
| `gcs` | Cloud Storage |
| `gps` | Pub/Sub |
| `gwf` | Cloud Workflows |
| `gce` | Compute Engine |
| `gke` | Kubernetes Engine |
| `gar` | Artifact Registry |
| `gsm` | Secret Manager |
| `gsc` | Cloud Scheduler |
| `gbq` | BigQuery |
| `gcb` | Cloud Build |

### Region IDs

| ID | Region |
|----|--------|
| `ew1` | europe-west1 (Belgium) |
| `ew3` | europe-west3 (Frankfurt) |
| `ew4` | europe-west4 (Netherlands) |
| `eu` | EU multi-region |

### Examples

```
btdp-gcr-configinterface-ew1-dv
btdp-gcs-rawdata-eu-pd
btdp-gsm-apikey-ew1-np
autoclean-gcr-main-ew1-np
autoclean-gsc-daily-trigger-ew1-np
```

---

## 4. Service Account Naming

### Format

```
app_name_short-sa-name-env
```

### Examples

```
btdp-sa-dataflow-qa
btdp-sa-cloudbuild-pd
autoclean-sa-runner-np
```

---

## 5. Secret Manager Naming

### Format

```
app_name_short-srt-identifier-env
```

### Examples

```
btdp-srt-db_config-qa
btdp-srt-api_key-pd
autoclean-srt-group-email-np
```

---

## 6. Cloud Storage Bucket Naming

### Format

```
app_name_short-gcs-name-location_id-env
```

### Examples

```
btdp-gcs-rawdata-eu-pd
btdp-gcs-exports-ew1-np
```

---

## 7. BigQuery Dataset Naming

### Format

```
application_ds_confidentiality_label_location_env
```

| Field | Description | Values |
|-------|-------------|--------|
| `application` | App short name | `btdp`, `p360`, etc. |
| `ds` | Fixed prefix | always `ds` |
| `confidentiality` | Data classification | `c1` (public), `c2` (internal), `c3` (confidential) |
| `label` | Domain + free field | `0a2_powerbimetadata` |
| `location` | Region | `eu`, `us` |
| `env` | Environment | `pd`, `np`, `qa`, `dv` |

### Domain Reference (first digit of label)

| Code | Domain |
|------|--------|
| 0 | Information Technology |
| 1 | Finance & Company Structure |
| 2 | Product |
| 3 | Sell-out |
| 4 | Manufacturing |
| 5 | Supply Chain |
| 6 | Customer & Sales Activation |
| 7 | Consumer Intelligence |
| 8 | Consumer O+O Activation |
| 9 | Sourcing |
| a | MQEHS |

### Examples

```
btdp_ds_c1_0a2_powerbimetadata_eu_pd
btdp_ds_c2_1b1_financedata_eu_np
p360_ds_c1_2a1_productref_eu_pd
```

---

## 8. BigQuery Table Naming

### Business tables

```
bo_name_version
```

Examples: `license_pro_users_v1`, `job_logs_v1`, `capacity_unit_timepoint_v2`

### Technical tables

```
tech_bo_name_version_label
```

Examples: `tech_audit_log_v1_raw`, `tech_error_log_v1_staging`

---

## 9. Flow Naming (Data Integration)

### Format by layer

| Layer | Trigram | Format |
|-------|---------|--------|
| Source | `SRC` | `SRC_app_code_name_version_env` |
| Domain (shared) | `DMN` | `DMN_family_code_name_version_env` |
| Consumption (specific) | `CSP` | `CSP_project_code_name_version_env` |
| Data Management | `DMS` | `DMS_number_name_version_env` |

### Examples

```
SRC_201_vl060stackingfactor_v1_pd
DMN_201_elixgbo_v1_np
CSP_P360_ibiplantdatawise_v1_pd
DMS_100_collibraIntake_v1_dv
```

Note: `_env` is added dynamically via templating in YAML configs or IaC.

---

## Quick Reference — Naming for Auto Licence Clean project

```
GCP Project:     oa-data-coepowerbi-np
Cloud Run Job:   autoclean-gcr-main-ew1-np
Scheduler:       autoclean-gsc-daily-trigger-ew1-np
Service Account: autoclean-sa-runner-np
Secret (group):  autoclean-srt-group-email-np
BigQuery table:  license_pro_users_v1
BigQuery dataset: btdp_ds_c1_0a2_powerbimetadata_eu_pd
```
