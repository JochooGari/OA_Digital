---
description: "Power BI on BTDP — licences, BigQuery connectivity, Direct Query, monitoring dashboards, load testing, best practices"
user_invocable: true
---

# Power BI on BTDP — Configuration & Best Practices

Source : Confluence BTDP — Power BI [DRAFT], SDDS IT, Performance Testing docs

---

## 1. Overview

- **Service**: `SNSVC0006658 - Power BI`
- **Contact**: powerbi.coe@loreal.com
- **Audience**: Global Data Community

---

## 2. Power BI Desktop

### Installation
- **L'Oreal PC**: Open L'Oreal App Catalog → download latest Power BI Desktop
- **External PC**: Download from Microsoft Apps (Power BI Desktop)

### Optimize Ribbon
1. File > Options and Settings > Options
2. Preview Features > Check "Optimize Ribbon"
3. Restart Power BI Desktop
4. Use "Pause Visuals" when adding/editing visuals to prevent unnecessary queries

### Developer Mode
- Enables advanced features for report development
- Access via Options > Preview Features

---

## 3. Power BI Service

### Licences
- **Pro**: Standard collaboration licence
- **Premium Per User (PPU)**: Advanced features per user
- **Premium Capacity**: Dedicated resources (F/P SKUs)

### Environments
- Separate workspaces for Dev / Test / Prod
- Use deployment pipelines when available

### Self BI
- Users can create their own reports
- Must follow data governance rules

### Multiple Audiences
- Use Power BI Apps with multiple audience groups
- Different views for different user groups

---

## 4. Direct Query

### Best Practices
- Minimize the number of visuals per page
- Use aggregations where possible
- Limit row-level security complexity
- Optimize source queries

### Row Level Security (RLS)
- Can be combined with Direct Query
- Performance impact — test thoroughly
- Document RLS roles and mappings

### Performance Optimization Checklist
- Reduce number of tables in model
- Minimize calculated columns (prefer measures)
- Use appropriate data types
- Limit bidirectional cross-filtering
- Test with Performance Analyzer

---

## 5. BigQuery Connectivity

### Prerequisites
- Google BigQuery connector in Power BI Desktop
- Proper authentication (Google account or service account)
- Network access to GCP from your environment

### Google BigQuery (Azure AD) Beta
- Allows using Azure AD credentials for BigQuery
- Requires proper token exchange configuration
- See btdp-api skill for Token Exchange details

### Key Tables for Power BI COE

| Table | Dataset | Description |
|-------|---------|-------------|
| `license_pro_users_v1` | `btdp_ds_c1_0a2_powerbimetadata_eu_pd` | Pro licence users with activity |
| `capacity_unit_timepoint_v2` | (same dataset) | Capacity metrics (24h delay) |

### SQL for licence monitoring

```sql
SELECT *
FROM `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.license_pro_users_v1`
WHERE need_pro_license = FALSE
  AND NbDayHaveLicence > 60
  AND IsHuman = TRUE
```

---

## 6. Monitoring Dashboards

### BTDP Monitoring (Power BI)

| Dashboard | Purpose | AD Group |
|-----------|---------|----------|
| FTS Monitoring | Data flow monitoring, incidents | `IT-GLOBAL-GCP-BTDP_DATAENG_FTS` |
| SLT Monitoring | SLT replication stats | `[ITG] btdpslt-admin-ww-pd` |
| NEO Dashboard | NEO analytics | `IT-GLOBAL-GCP-NEOANALYTICS_TECH_USR` |
| ADMIN Dashboard | Tech leads overview | `IT-GLOBAL-GCP-BTDP_DATAENG_LEAD` |

### Fabric Monitoring
- Use Fabric Monitoring Hub for KQL queries on `SemanticModelLogs`
- Capacity metrics available in BigQuery (24h delay)

---

## 7. Realistic Load Testing

### Tool
- **OA Realistic Load Testing Framework v2.0** (PowerShell)
- Script: `Orchestrator.ps1`
- Config: `PBIReport.json`

### Procedure

1. Configure `PBIReport.json` with target report/page/filters
2. Run `.\Orchestrator.ps1` in PowerShell
3. Check logs: `logs/orchestrator_log.csv`, `logs/logPage.csv`
4. Open Fabric Notebook → Run all → refresh model
5. View results in Power BI monitoring report

### PBIReport.json Structure

```json
{
  "reportId": "82891daf-...",
  "groupId": "83771731-...",
  "pageId": "45941f97-...",
  "filters": {
    "division.division_code": ["CPD", "LDB", "LLD", "No-division-code", "PPD"]
  }
}
```

---

## 8. AD Service Account Usage

- Service accounts can be used for automated Power BI operations
- Requires proper Azure AD configuration
- Used for: automated refresh, API calls, embedded reports

---

## 9. Backup/Restore

- Power BI backup capabilities available
- Follow organizational backup policies
- Consider PBIP (Power BI Project) format for version control

---

## Quick Reference — Power BI COE Tasks

| Task | How |
|------|-----|
| Check inactive licences | BigQuery SQL on `license_pro_users_v1` |
| Revoke licence | Remove user from Pro group via BTDP Groups API |
| Monitor capacity | Fabric Monitoring Hub + BigQuery `capacity_unit_timepoint_v2` |
| Load test | `Orchestrator.ps1` + Fabric Notebook |
| Request dashboard access | Join appropriate AD group |
| Report incident | ServiceNow incident form |
