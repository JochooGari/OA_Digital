# Plan : Deploy Dashboard Cloud Run Service

- **TODO associe** : [../TODO/002-deploy-dashboard-matthieu.md](../TODO/002-deploy-dashboard-matthieu.md)
- **Statut** : En attente des prerequis GCP

---

## Contexte

Le code Auto Licence Clean inclut deja un dashboard web complet (FastAPI + HTML/Tailwind).
Il faut le deployer comme Cloud Run **Service** (en plus du Job batch) pour que Matthieu ait un lien web.

## Fichier a creer

`Auto_Licence_Clean/deploy-dashboard.sh` — script de deploiement Cloud Run Service

### Specifications

- ENV=dv par defaut
- Image Docker : `docker/Dockerfile` existant (python:3.12, copie src/ + docs/)
- CMD override : `uvicorn src.api:app --host 0.0.0.0 --port 8080`
- Nom BTDP : `autoclean-gcr-dashboard-ew1-{env}`
- `--min-instances 0` (scale-to-zero)
- `--max-instances 2`
- `--allow-unauthenticated` (DV uniquement)
- DRY_RUN=true par defaut
- Affiche l'URL finale en sortie

### Fichiers existants NON modifies

- `deploy.sh` (Cloud Run Job batch)
- `src/api.py` (FastAPI backend)
- `docs/index.html` (dashboard HTML)
- `docker/Dockerfile`
