#!/bin/bash
# =============================================================
# deploy.sh — Build & Deploy Auto-Clean Licences Pro sur GCP
# Usage: ./deploy.sh [dev|prod]
# =============================================================

set -e

ENV=${1:-dev}

# --- A REMPLIR avec les valeurs confirmées par Matthieu BUREL ---
GCP_PROJECT=""                    # Ex: itg-myproject-gbl-ww-pd
GCP_REGION="europe-west1"
IMAGE_NAME="auto-clean-licences"
JOB_NAME="auto-clean-licences-pro"
SERVICE_ACCOUNT=""                # Ex: sa-auto-clean@myproject.iam.gserviceaccount.com

# --- Validation des variables requises ---
if [ -z "$GCP_PROJECT" ] || [ -z "$SERVICE_ACCOUNT" ]; then
  echo "ERREUR: GCP_PROJECT et SERVICE_ACCOUNT doivent être remplis dans deploy.sh"
  exit 1
fi

IMAGE_URI="gcr.io/${GCP_PROJECT}/${IMAGE_NAME}:${ENV}-latest"

echo "=== Deploy Auto-Clean Licences Pro ==="
echo "Environment : $ENV"
echo "Project     : $GCP_PROJECT"
echo "Image       : $IMAGE_URI"
echo ""

# 1. Build & push l'image Docker
echo "[1/3] Build et push de l'image Docker..."
gcloud builds submit \
  --tag "$IMAGE_URI" \
  --project "$GCP_PROJECT"

# 2. Créer ou mettre à jour le Cloud Run Job
echo "[2/3] Déploiement du Cloud Run Job..."
gcloud run jobs deploy "$JOB_NAME" \
  --image "$IMAGE_URI" \
  --region "$GCP_REGION" \
  --project "$GCP_PROJECT" \
  --service-account "$SERVICE_ACCOUNT" \
  --set-secrets "API_CLIENT_ID=api-client-id:latest,API_CLIENT_SECRET=api-client-secret:latest" \
  --set-env-vars "DRY_RUN=true,RETENTION_DAYS=120,BATCH_SIZE=20" \
  --max-retries 1 \
  --task-timeout 600

# 3. Créer le Cloud Scheduler (si première installation)
echo "[3/3] Configuration du Cloud Scheduler (1x/jour à 02h00)..."
gcloud scheduler jobs create http "$JOB_NAME-scheduler" \
  --location "$GCP_REGION" \
  --schedule "0 2 * * *" \
  --uri "https://${GCP_REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${GCP_PROJECT}/jobs/${JOB_NAME}:run" \
  --oauth-service-account-email "$SERVICE_ACCOUNT" \
  --project "$GCP_PROJECT" \
  2>/dev/null || echo "Scheduler déjà existant — ignoré."

echo ""
echo "=== Déploiement terminé ==="
echo "Pour exécuter manuellement : gcloud run jobs execute $JOB_NAME --region $GCP_REGION"
echo "Pour voir les logs         : gcloud logging read 'resource.type=cloud_run_job' --project $GCP_PROJECT --limit 50"
