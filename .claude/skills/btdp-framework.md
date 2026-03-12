---
description: "BTDP Framework for building applications — Core setup, APIs (FastAPI+CloudRun), WebApps (React), Data pipelines, ML, MCP Servers, CI/CD"
user_invocable: true
---

# BTDP Framework — Building Applications on GCP

Source : Confluence BTDP — BTDP Framework, Technical Project Management, Observability, Notifications

---

## 1. Overview

The BTDP Framework standardizes development on GCP with:
- **Terraform** for infrastructure as code
- **Makefiles** as developer CLI
- **GitHub + Cloud Build V2** for CI/CD
- **Cloud Workflows** for orchestration

### Features

| Feature | Stack | Description |
|---------|-------|-------------|
| **Core** | Terraform, Makefiles | Project setup, AD groups, GitHub init |
| **Data & Orchestration** | Cloud Workflows, BigQuery, YAML | Data pipelines, scheduled queries, storage |
| **API** | CloudRun + FastAPI + Apigee | REST APIs auto-published to Apigee |
| **WebApp** | React + Cloud CDN + CloudRun (BFF) | Frontend + Backend-for-Frontend |
| **Machine Learning** | Vertex AI, BigQuery ML | ML model training and serving |
| **MCP Server** | FastAPI | GenAI agent tool execution |

---

## 2. Core Setup

### Prerequisites

1. AD groups created
2. GCP projects created (via SR: BTDP Create Project(s))
3. GitHub repository initialized (see btdp-git skill)
4. Developer environment configured

### Project Types

| Type | Environments | Use case |
|------|-------------|----------|
| `exploration` | NP only | Data exploration, POC light |
| `usecase` | DV, QA, NP, PD | Full project lifecycle |
| `poc` | DV only | Proof of concept |

### GCP Project Creation

Via Service Request **BTDP Create Project(s)** or API.

Presets available:
- `labelling` : default labels (env, project type, org, app service)
- `billing` : link to billing account + budget
- `core_setup` : create project + activate required APIs
- `quotas` : BigQuery usage quotas
- `data_apis` : enable data-related APIs
- `ai_apis` : enable AI/ML APIs

---

## 3. API Development

### Stack
- **Runtime**: Cloud Run (Python)
- **Framework**: FastAPI
- **Gateway**: Apigee (auto-published)

### Pattern

```python
from fastapi import FastAPI

app = FastAPI(title="My BTDP API")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/v1/my-resource")
def get_resource():
    # Business logic
    return {"data": "..."}
```

### Deployment
- Docker container → Artifact Registry → Cloud Run
- Apigee proxy auto-configured via framework
- Authentication: Bearer token (Google ADC or Azure Token Exchange)

---

## 4. WebApp Development

### Architecture

```
Browser → Cloud CDN + Load Balancer → Static files (React)
                                    → Cloud Run (FastAPI BFF)
```

### Stack
- **Frontend**: React, Cloud CDN, Load Balancing
- **Backend for Frontend (BFF)**: Cloud Run + FastAPI
- **Authentication**: Google Identity-Aware Proxy (IAP) or custom

---

## 5. Data Pipelines

### Configuration
- Defined via **YAML configuration files**
- Orchestrated by **Cloud Workflows**

### Capabilities
- File ingestion into BigQuery
- BigQuery transformations
- Data exports to external tools
- Access Management Service application
- Scheduled queries
- Storage bucket management

### Layers

| Layer | Prefix | Purpose |
|-------|--------|---------|
| Source (SDS) | `SRC` | Raw data ingestion from operational systems |
| Domain (SDDS) | `DMN` | Shared domain datasets, curated |
| Consumption (CDS) | `CSP` | Use-case specific views/extracts |

---

## 6. CI/CD

### Pipeline
1. Developer pushes to GitHub
2. **Cloud Build V2 trigger** fires
3. Build → Test → Deploy
4. Apigee proxy updated (for APIs)

### GitHub Configuration
- Repository in `loreal-datafactory` or appropriate org
- Branch protection rules on `master` and `develop`
- PR required for merge (squash and merge)
- Hooks validate branch names and commit messages

---

## 7. Observability (BTDP Supervision)

Service: `SNSVC0015419 - BTDP Supervision`

### Dashboards (Power BI)

| Dashboard | Audience | AD Group |
|-----------|----------|----------|
| BTDP SLT Monitoring | SLT users | `[ITG] btdpslt-admin-ww-pd` |
| BTDP NEO Dashboard | NEO users | `IT-GLOBAL-GCP-NEOANALYTICS_TECH_USR` |
| BTDP FTS Monitoring | FTS, Use Case teams, DPOs | `IT-GLOBAL-GCP-BTDP_DATAENG_FTS` |
| BTDP ADMIN Dashboard | Tech leads, Management | `IT-GLOBAL-GCP-BTDP_DATAENG_LEAD` |

### Features
- Supervision Dashboards
- Data Health monitoring
- Incident Life Cycle management
- Data Lineage
- Monitoring Interface & WebApp

---

## 8. Notification Service

Service: `SNSVC0019009 - BTDP Notification Service`

### Send email notification

```bash
curl -X POST https://api.loreal.net/global/it4it/btdp-notification/v1/notifications \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "notifications": [{
      "channel": "email",
      "subject": "Auto Licence Clean Report",
      "body": "Dry-run completed. 42 users identified.",
      "to": ["mohcine.mmadi@loreal.com"]
    }]
  }'
```

### Access
- Group: `IT-GLOBAL-GCP-BTDP_SRV_NOTIFICATIONS_INVOKERS-PD@loreal.com`
- Contact: `IT-GLOBAL-GCP-BTDP_DATAENG_L3_GCPINTSEC@loreal.com`
- Default quota: 100 notifications/channel/day/recipient

---

## 9. MCP Server Development

### Overview

MCP (Model Context Protocol) servers enable GenAI agents to access tools and data through a standardized protocol.
BTDP Framework provides a module template for building MCP servers integrated with L'Oréal GPT.

### Key Features

- **Automatic tool discovery**: loads tools from `src/tools/` directory
- **Dual authentication**: OAuth2 (user token forwarding) and Cloud Run IAM
- **GenAI integration**: auto-registers with GenAI Config API for agent discovery
- **FastAPI framework**: built on FastAPI for high performance
- **Cloud Run deployment**: fully managed serverless

### Quick Start

```bash
# Copy MCP sample module
cp -r modules/mcp.sample modules/mcp

# Deploy to development
ENV=dv make mcp
```

### Adding a Tool

1. Create Python file in `src/tools/my_tool.py`
2. Register in `configuration.yaml`:
```yaml
tools:
  - name: "my_tool"
    description: "What the tool does"
```
3. Deploy: `ENV=dv make mcp`

### Service Naming

Pattern: `${APP_NAME_SHORT}-gcr-<module-name>-${REGION_ID}-${ENV}`
Example: `frmwrk-gcr-mcp-ew1-dv`

### Authentication Types

| Type | Use case |
|------|----------|
| `cloud-run` | Backend operations, service account permissions (default) |
| `oauth` | User token forwarding, personal resource access |
| `authorization` | Simple Bearer token |

### GenAI Agent Configuration

Agents are configured via YAML in `configuration/genai/<context>/<agent>.yaml`:

```yaml
name: My Agent
type: chat
is_active: true
params:
  llm:
    model: claude-4-sonnet
  tools:
    toolkit:
      - name: mcp-tool
        params:
          name: My MCP Tool
          auth:
            type: cloud-run
          config:
            url: https://my-mcp-server.run.app/mcp
```

### Available Tool Types in GenAI Config API

| Type | Description |
|------|-------------|
| `rag` | Retrieval-Augmented Generation (Pinecone) |
| `semantic` | BigQuery domain exploration |
| `agent_tool` | Use another agent as a tool |
| `mcp-tool` | MCP server integration |
| `smart-sheets` | Google Sheets integration |
| `remember` | Save to companion memory |

### Conversational Analytics (CA)

Architecture for natural-language querying of BI data via L'Oréal GPT:

```
User question → Orchestrator Agent
  ├── Master Data Agent → entity/terminology resolution
  ├── Data Fetching Agent → Looker / Power BI / SQL
  └── Presentation Agent → Highcharts visualization
```

**Power BI Agent** — generates and executes DAX queries from natural language:
```yaml
- name: agent_tool
  params:
    config_id: powerbi-agent
    context_id: btdp_agents-${project_env}
    description: |
      PowerBI Agent - generates DAX queries from natural-language questions
      and executes them, returning results in JSONL format
```

### GenAI Config API

```bash
# List available tool types
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://api.loreal.net/global/it4it/btdp-genaiconfig/v1/tools"

# Deploy/update agent config
curl -X PUT "https://api.loreal.net/global/it4it/btdp-genaiconfig/v1/contexts/<context>-<env>/configs/<agent-id>" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "Content-Type: application/json" \
  --data @config.json
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Terraform 500 "Json threat detected" | `terraform state rm restapi_object.mcp_server_registration` then `terraform apply` |
| 401 Unauthorized | Check Cloud Run IAM policies, verify SA has `roles/run.invoker` |
| Tool not appearing in agent | Redeploy MCP server, check GenAI Config API registration |

---

## 10. Icebreaker (Temporary Access)

Feature of Technical Project Management service.

- Request temporary permissions on a resource (project, bucket, dataset)
- Time-limited access
- Via Service Request or API

---

## Quick Reference — For Auto Licence Clean project

```
Stack:      Python + Cloud Run Job (not a service)
Scheduler:  Cloud Scheduler → triggers Cloud Run Job
Auth:       Google ADC (service account)
Data:       BigQuery query → list inactive users
Action:     BTDP Groups API DELETE → remove from licence group
Logging:    Cloud Logging (structured)
Alerting:   Cloud Monitoring (on failure)
Notify:     BTDP Notification Service (optional email report)
CI/CD:      GitHub → Cloud Build V2 → Cloud Run deploy
```
