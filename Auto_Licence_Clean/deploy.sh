#!/bin/bash
# =============================================================
# deploy.sh — Build & Deploy Auto-Clean Licences Pro sur GCP
# Usage: ./deploy.sh [np|pd]
#
# Naming conventions (btdp-naming):
#   Project:   oa-data-coepowerbi-{env}
#   Job:       autoclean-gcr-main-ew1-{env}
#   Scheduler: autoclean-gsc-daily-ew1-{env}
#   SA:        autoclean-sa-runner-{env}
#   Registry:  Artifact Registry (gcr.io is deprecated)
# =============================================================

set -e

ENV=${1:-np}

# --- GCP Configuration (BTDP naming conventions) ---
GCP_PROJECT="oa-data-coepowerbi-${ENV}"
GCP_REGION="europe-west1"
AR_REPO="autoclean-gar-images-ew1-${ENV}"
IMAGE_NAME="autoclean-gcr-main"
JOB_NAME="autoclean-gcr-main-ew1-${ENV}"
SCHEDULER_NAME="autoclean-gsc-daily-ew1-${ENV}"
SERVICE_ACCOUNT=""  # Ex: autoclean-sa-runner-np@oa-data-coepowerbi-np.iam.gserviceaccount.com

# --- Validation ---
if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "ERREUR: SERVICE_ACCOUNT doit être rempli dans deploy.sh"
  echo "Format attendu: autoclean-sa-runner-${ENV}@${GCP_PROJECT}.iam.gserviceaccount.com"
  exit 1
fi

IMAGE_URI="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/${IMAGE_NAME}:${ENV}-latest"

echo "=== Deploy Auto-Clean Licences Pro (BTDP conventions) ==="
echo "Environment : ${ENV}"
echo "Project     : ${GCP_PROJECT}"
echo "Image       : ${IMAGE_URI}"
echo "Job         : ${JOB_NAME}"
echo "SA          : ${SERVICE_ACCOUNT}"
echo ""

# 0. Create Artifact Registry repo if needed
echo "[0/3] Création du dépôt Artifact Registry (si nécessaire)..."
gcloud artifacts repositories create "${AR_REPO}" \
  --repository-format=docker \
  --location="${GCP_REGION}" \
  --project="${GCP_PROJECT}" \
  2>/dev/null || echo "Dépôt déjà existant — ignoré."

# 1. Build & push Docker image via Cloud Build
echo "[1/3] Build et push de l'image Docker..."
gcloud builds submit \
  --tag "${IMAGE_URI}" \
  --project "${GCP_PROJECT}"

# 2. Deploy Cloud Run Job (Google ADC — no Azure secrets needed)
echo "[2/3] Déploiement du Cloud Run Job..."
gcloud run jobs deploy "${JOB_NAME}" \
  --image "${IMAGE_URI}" \
  --region "${GCP_REGION}" \
  --project "${GCP_PROJECT}" \
  --service-account "${SERVICE_ACCOUNT}" \
  --set-env-vars "DRY_RUN=true,RETENTION_DAYS=120,BATCH_SIZE=20,BIGQUERY_BILLING_PROJECT=${GCP_PROJECT}" \
  --max-retries 1 \
  --task-timeout 600

# 3. Create Cloud Scheduler (daily at 02:00 CET)
echo "[3/3] Configuration du Cloud Scheduler (1x/jour à 02h00 CET)..."
gcloud scheduler jobs create http "${SCHEDULER_NAME}" \
  --location "${GCP_REGION}" \
  --schedule "0 2 * * *" \
  --time-zone "Europe/Paris" \
  --uri "https://${GCP_REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${GCP_PROJECT}/jobs/${JOB_NAME}:run" \
  --oauth-service-account-email "${SERVICE_ACCOUNT}" \
  --project "${GCP_PROJECT}" \
  2>/dev/null || echo "Scheduler déjà existant — ignoré."

echo ""
echo "=== Déploiement terminé ==="
echo "Exécuter manuellement : gcloud run jobs execute ${JOB_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT}"
echo "Voir les logs          : gcloud logging read 'resource.type=cloud_run_job' --project ${GCP_PROJECT} --limit 50"
