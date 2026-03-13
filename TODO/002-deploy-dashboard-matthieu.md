# Deploy Dashboard Auto Licence Clean pour Matthieu

- **Priorite** : HAUTE
- **Assignee** : Mohamed MMADI
- **Dependance** : Matthieu doit fournir projet GCP + service account
- **Plan associe** : [../Plan/001-deploy-dashboard.md](../Plan/001-deploy-dashboard.md)

---

## Objectif

Deployer le dashboard web Auto Licence Clean sur Cloud Run Service pour que Matthieu puisse tester via un simple lien HTTPS, sans git ni ligne de commande.

## Prerequis (en attente de Matthieu)

- [ ] Projet GCP DV (ex: `itg-coedataviz-gbl-ww-dv`)
- [ ] Service Account (ex: `autoclean-sa-runner-dv@<project>.iam.gserviceaccount.com`)
- [ ] BTDP Service Access pour Groups API
- [ ] PRO_LICENSE_GROUP_EMAIL

## A faire

- [x] Code backend FastAPI (api.py) — 17 endpoints
- [x] Frontend dashboard (index.html) — Tailwind CSS
- [x] Dockerfile (docker/Dockerfile)
- [x] deploy.sh (Cloud Run Job batch)
- [ ] Creer `deploy-dashboard.sh` (Cloud Run Service)
- [ ] Tester le deploiement en DV
- [ ] Envoyer l'URL a Matthieu

## Livrable

URL type : `https://autoclean-gcr-dashboard-ew1-dv-xxxxx.run.app`
