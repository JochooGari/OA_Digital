---
description: "How to consume BTDP APIs via Apigee — authentication from GCP or Azure, token generation, service requests"
user_invocable: true
---

# BTDP API Consumption — Apigee Authentication & Access

Source : Confluence BTDP — section 3.5, Service Access, Group Management

---

## 1. Overview

BTDP APIs are exposed via **Apigee** (API Gateway L'Oreal).
- API Catalog: `https://api.loreal.com/api-catalogue/`
- Base URL pattern: `https://api.loreal.net/global/it4it/<api-name>/v1/`

Two authentication paths depending on your origin:
- **From GCP** → Google ADC (Application Default Credentials)
- **From Azure** → Azure AD OAuth2 + Token Exchange

---

## 2. Authentication from GCP (recommended)

When calling BTDP APIs from a GCP service (Cloud Run, Cloud Function, etc.), use Google ADC.

### Get a Bearer token

```bash
# CLI
gcloud auth print-access-token

# Python
import google.auth
import google.auth.transport.requests

credentials, project = google.auth.default(
    scopes=["https://www.googleapis.com/auth/cloud-platform"]
)
credentials.refresh(google.auth.transport.requests.Request())
token = credentials.token
```

### Use it

```bash
curl -X GET "https://api.loreal.net/global/it4it/<api-name>/v1/<endpoint>" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

### Prerequisites

1. Service account must be member of the **invokers group** for the target API
2. Request access via Service Request: **BTDP Service Access** (see section 5)

---

## 3. Authentication from Azure

When calling from an Azure-hosted application.

### Steps

1. **Create Azure AD application** for each environment (PRD, PPRD, QUAL, DEV)
2. **Grant permission** `BTDPAPI.RW` to app `BTDP-APP-PD-PRD` on your application
3. **Request Apigee access** — contact BTDP admins with your `CLIENT_ID` and `APP_NAME`
4. **Create GCP project + service account** (via SR: Google Cloud - Create Project(s))
5. **Map service account to Azure App** (via SR: BTDP Token Exchange Mapping)
6. **Add service account to invokers group** (via SR: BTDP Group Management)

### Generate token

```bash
curl -X POST https://api.loreal.net/v1/oauth20/token \
  --header "content-type: application/x-www-form-urlencoded" \
  --data "grant_type=client_credentials&client_id=CLIENT_ID&client_secret=CLIENT_SECRET&scope=api://TARGET_CLIENT_ID/.default"
```

| Variable | Description | Where to find |
|----------|-------------|---------------|
| `CLIENT_ID` | Your Azure app ID | Azure Portal > App > Overview |
| `CLIENT_SECRET` | Your Azure app secret | Azure Portal > App > Certificates & secrets |
| `TARGET_CLIENT_ID` | BTDP PROD Azure app ID | `61f4d745-2ed5-4c9c-8e40-87234333319e` |

### Azure BTDP Applications

| Environment | App Name |
|-------------|----------|
| Production | BTDP-APP-PD-PRD |
| Non-production | BTDP-APP-NP-PPRD |
| Qualification | BTDP-APP-QA-QUAL |
| Development | BTDP-APP-DV-DEV |

**Owners/Admins**: Sebastien MORAND, Arnaud BAKOULA

---

## 4. Key BTDP APIs

### Groups API
- **Catalog**: `https://api.loreal.com/api-catalogue/btdp-groups-api-54`
- **Base URL**: `https://api.loreal.net/global/it4it/itg-groupsapi/v1`
- **Endpoints**:
  - `GET /groups/{group_email}/members` — list members
  - `POST /groups/{group_email}/members` — add members
  - `DELETE /groups/{group_email}/members` — remove members (batch max 20)
- **Invokers group**: use BTDP Service Access SR

### Notification Service
- **Base URL**: `https://api.loreal.net/global/it4it/btdp-notification/v1`
- **Endpoints**:
  - `GET /notifications/allocations` — check quota
  - `POST /notifications` — send notification (email)
- **Invokers group**: `IT-GLOBAL-GCP-BTDP_SRV_NOTIFICATIONS_INVOKERS-PD@loreal.com`
- **Default quota**: 100 notifications/channel/day/recipient

### Project Creation API
- **Catalog**: `https://api.loreal.com/api-catalogue/btdp-project-creation-api-10`
- **Invokers group**: `IT-GLOBAL-GCP-INTSEC_DATASRV_PROJECTCREATION_PD@loreal.com`
- **Project types**: `exploration` (NP only), `usecase` (4 envs), `poc` (DV only)

### Service Access API
- **Invokers group**: `IT-GLOBAL-GCP-BTDP_SRV_SERVICEACCESS_INVOKERS-PD@loreal.com`

---

## 5. Service Requests (ServiceNow)

| Service Request | Purpose | When to use |
|----------------|---------|-------------|
| **BTDP Service Access** | Grant/remove access to a BTDP service for user, SA, or Azure App | First step — get invoker access to an API |
| **BTDP Group Management** | Add/remove members from BTDP AD groups | Add SA to invokers group |
| **BTDP Token Exchange Mapping** | Map GCP service account to Azure App ID | Required for Azure → GCP auth |
| **BTDP Create Project(s)** | Create GCP projects (exploration, usecase, poc) | New project setup |
| **BTDP Miscellaneous Requests** | Register Azure App on Apigee proxy | Apigee configuration |

### BTDP Service Access — Azure App granting

When granting access to an Azure App, provide:
1. The environment of the Azure App (`dv`, `qa`, `np`, `pd`)
2. The Application Service Number for the consumer app

The system will automatically:
- Create the consumer GCP Project
- Create the service account
- Create the Token Exchange mapping
- Register the Apigee app

---

## 6. Environments & URLs

| Environment | Apigee Base URL |
|-------------|----------------|
| Production | `https://api.loreal.net/` |
| SIT | `https://sit.api.loreal.net/` |
| DEV | `https://dev-emea.api.loreal.net/` |

**Rule**: Always use production APIs (`api.loreal.net`) for stable services.

---

## Quick Reference — For Auto Licence Clean project

```bash
# From GCP Cloud Run, authenticate to Groups API:
import google.auth
import google.auth.transport.requests

credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
credentials.refresh(google.auth.transport.requests.Request())

headers = {"Authorization": f"Bearer {credentials.token}"}
# DELETE https://api.loreal.net/global/it4it/itg-groupsapi/v1/groups/{group_email}/members
```

**Service Requests needed**:
1. BTDP Service Access — for Groups API invoker access
2. BTDP Group Management — add SA to invokers group
