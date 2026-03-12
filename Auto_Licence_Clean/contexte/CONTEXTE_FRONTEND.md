# Contexte IA — Frontend Auto Licence Clean

> Ce fichier contient tout le contexte necessaire pour qu'une IA puisse reprendre le travail sur le frontend du projet Auto Licence Clean.

---

## 1. Description du projet

**Auto Licence Clean** automatise la revocation des licences Power BI Pro pour les utilisateurs inactifs chez L'Oreal. Le frontend est un dashboard qui permet de :
- Visualiser le statut du systeme (nombre d'utilisateurs inactifs, config, historique)
- Lancer des requetes BigQuery pour compter les utilisateurs a revoquer
- Documenter les endpoints de l'API BTDP Groups API
- Afficher l'architecture du systeme

---

## 2. Stack technique

| Composant | Technologie | Notes |
|-----------|-------------|-------|
| Frontend | HTML + Tailwind CSS (CDN) + vanilla JS | Fichier unique `index.html` |
| Backend | **FastAPI** (Python) | `api.py` — sert le front + expose les endpoints |
| BDD source | BigQuery (GCP) | Table `license_pro_users_v1` |
| API externe | BTDP Groups API (L'Oreal) | DELETE /groups/{email}/members |
| Auth | Google OAuth2 (ADC) | `gcloud auth application-default login` en local |

---

## 3. Structure des fichiers

```
auto-licence-clean/
├── contexte/
│   └── CONTEXTE_FRONTEND.md  ← CE FICHIER
├── docker/
│   └── Dockerfile            ← Image Docker (python:3.12-slim)
├── docs/
│   ├── index.html            ← PAGE PRINCIPALE (Tailwind CSS, tout-en-un)
│   ├── style.css             ← ancien CSS vanilla (non utilise par index.html)
│   ├── app.js                ← ancien JS vanilla (non utilise par index.html)
│   └── PRD_FRONTEND.md       ← PRD original
├── sql/
│   └── licence_pro_usage.sql ← Requete SQL BigQuery
├── src/
│   ├── api.py                ← BACKEND FASTAPI (sert le front + API)
│   ├── main.py               ← orchestrateur batch (Cloud Run Job)
│   ├── config.py             ← variables d'environnement
│   ├── bigquery_client.py    ← requete SQL BigQuery
│   ├── groups_api_client.py  ← appels BTDP Groups API (Google OAuth2)
│   └── reporter.py           ← export CSV
├── .env                      ← variables locales (NE PAS COMMITTER)
├── .env.example              ← template des variables
├── .gitignore
├── deploy.sh                 ← deploiement Cloud Run + Scheduler (BTDP naming)
├── README.md
└── requirements.txt          ← dependances Python
```

---

## 4. Frontend (index.html)

### Design
- **Style** : inspire du portail BTDP Groups API de L'Oreal (Apigee)
- **Framework CSS** : Tailwind CSS via CDN (`https://cdn.tailwindcss.com`)
- **Police** : Inter (Google Fonts)
- **Icones** : Material Symbols Outlined (Google Fonts)
- **Couleurs** :
  - Noir L'Oreal : `#1a1a1a` (header, avatars)
  - Dore/primary : `#c5a86d` (boutons, accents, badges)
  - Background : `#f8f7f6`

### Sections de la page
1. **Header** : barre noire avec logo L'OREAL, titre, badges Live/Pre-Prod/DRY_RUN
2. **Sidebar** : navigation fixe (Overview, API Endpoints, Architecture, Execution)
3. **Status Cards** : 5 cartes (Last Run, Identified, Revoked, Retention, Batch Size)
4. **API Endpoints** : liste des endpoints BTDP Groups API avec badges GET/DELETE/POST, expandables au clic avec exemples curl + bouton Copy
5. **Architecture** : diagramme visuel Cloud Scheduler → Cloud Run → BigQuery/API/Logging
6. **Configuration** : tableau des variables d'environnement avec statut OK/En attente
7. **Dry Run Preview** : affiche le resultat du comptage BigQuery (nombre d'utilisateurs)
8. **Execution Logs** : historique des executions (timestamp, mode, users, outcome)
9. ~~Contacts~~ : **supprime** (le client ne veut pas afficher les noms)

### Boutons connectes au backend
| Bouton | ID HTML | Endpoint backend | Action |
|--------|---------|-----------------|--------|
| Refresh | `btn-refresh` | GET `/api/status` + GET `/api/logs` | Rafraichit les cartes + logs |
| Query BigQuery | `btn-count` | GET `/api/count` | Compte les utilisateurs inactifs dans BigQuery |
| Validate Config | `btn-validate-config` | GET `/api/config/validate` | Verifie les variables d'env |
| Refresh Logs | `btn-refresh-logs` | GET `/api/logs` | Rafraichit les logs |

### JavaScript (inline dans index.html)
- `loadStatus()` : appelle `/api/status`, met a jour les cartes
- `loadLogs()` : appelle `/api/logs`, met a jour le tableau d'historique
- Expand/collapse des endpoints au clic
- Bouton Copy pour les blocs curl
- Sidebar active state (visuel uniquement, pas de scroll automatique)

---

## 5. Backend FastAPI (api.py)

### Migration Flask → FastAPI
Le backend a ete migre de Flask vers **FastAPI** pour respecter les preconisations BTDP Framework (FastAPI est le standard pour les APIs sur la plateforme).

### Endpoints

| Route | Methode | Description | Necessite BigQuery |
|-------|---------|-------------|-------------------|
| `/` | GET | Sert `index.html` | Non |
| `/health` | GET | **Health check (standard BTDP Cloud Run)** | Non |
| `/api/status` | GET | Config actuelle + dernier run | Non |
| `/api/users` | GET | Liste complete des emails (BigQuery) | Oui |
| `/api/count` | GET | Nombre d'utilisateurs seulement | Oui |
| `/api/dry-run` | POST | Dry run complet + export CSV | Oui |
| `/api/logs` | GET | Historique des executions (in-memory) | Non |
| `/api/auth/status` | GET | Verifie si les credentials Google ADC sont configurees | Non |
| `/api/auth/login` | POST | Lance `gcloud auth application-default login` (ouvre navigateur) | Non |
| `/api/config/validate` | GET | Statut de chaque variable d'env | Non |

### Demarrage
```bash
cd auto-licence-clean/src
uvicorn api:app --reload --port 5000

# ou directement :
python api.py
```

Le serveur demarre sur `http://localhost:5000`.

### Prerequis pour BigQuery
```bash
gcloud auth application-default login
```
Sans ca, les endpoints `/api/count`, `/api/users` et `/api/dry-run` retourneront une erreur 500 "credentials not found".

---

## 6. API BTDP Groups API (L'Oreal)

### Base URL
```
https://api.loreal.net/global/it4it/itg-groupsapi/v1
```

### Authentification
Depuis GCP : **Google OAuth2 token** (pas Azure client_id/secret).
```bash
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" ...
```

### Endpoints documentes dans le front

| Methode | Path | Description |
|---------|------|-------------|
| GET | `/groups/{group_email}/members` | Lister les membres |
| DELETE | `/groups/{group_email}/members` | Supprimer des membres (body: `{"members": [...]}`) |
| POST | `/groups/{group_email}/members` | Ajouter des membres |
| GET | `/groups/{group_email}/authorized` | Lister les owners du groupe |

### Conditions d'acces
- Le service account doit etre **invoker** de l'API (groupe d'invokers)
- Le service account doit etre **owner** du groupe licence Pro pour pouvoir ajouter/supprimer des membres
- API catalogue : https://api.loreal.com/api-catalogue/btdp-groups-api-54

---

## 7. Variables d'environnement

| Variable | Valeur actuelle | Statut |
|----------|----------------|--------|
| `BIGQUERY_BILLING_PROJECT` | `oa-data-coepowerbi-np` | OK |
| `PRO_LICENSE_GROUP_EMAIL` | *(vide)* | En attente — demander a Anes |
| `DRY_RUN` | `true` | OK |
| `BATCH_SIZE` | `20` | OK |
| `RETENTION_DAYS` | `120` | OK |

Service account GCP : `89152354183-compute@developer.gserviceaccount.com`

---

## 8. Deploiement (BTDP naming conventions)

### Naming des ressources GCP
| Ressource | Nom BTDP |
|-----------|----------|
| Cloud Run Job | `autoclean-gcr-main-ew1-np` |
| Cloud Scheduler | `autoclean-gsc-daily-ew1-np` |
| Artifact Registry | `autoclean-gar-images-ew1-np` |
| Service Account | `autoclean-sa-runner-np` |

### Docker
- Image : `europe-west1-docker.pkg.dev/{PROJECT}/autoclean-gar-images-ew1-np/auto-licence-clean`
- Base : `python:3.12-slim`
- Deux modes :
  - **Batch** (Cloud Run Job) : `CMD ["python", "src/main.py"]`
  - **Dashboard** : `uvicorn src.api:app --host 0.0.0.0 --port $PORT`

### Script : `deploy.sh`
Deploie Cloud Run Job + Cloud Scheduler avec les conventions BTDP (Artifact Registry, naming, Europe-West1).

---

## 9. Ce qui reste a faire

### Frontend
- [ ] Afficher un message d'erreur user-friendly quand les credentials Google ne sont pas configurees
- [ ] Ajouter un spinner/loading state sur les cartes pendant le chargement
- [ ] Sidebar : scroll vers les sections au clic (actuellement visuel uniquement)
- [ ] Mode dark (le HTML a les classes Tailwind `dark:` mais pas de toggle)
- [ ] Responsive mobile : tester et ajuster

### Backend
- [ ] Persister l'historique des executions (actuellement in-memory, perdu au restart)
- [ ] Ajouter un endpoint pour telecharger le CSV dry-run

### Infra / Acces
- [ ] Obtenir `PRO_LICENSE_GROUP_EMAIL` aupres d'Anes
- [ ] Ajouter le service account comme invoker de la Groups API (Service Request BTDP)
- [ ] Ajouter le service account comme owner du groupe licence Pro
- [ ] Ouvrir une SR ServiceNow "BTDP GCP Project Creation Request" pour creer le projet GCP + repo officiel
- [ ] Demander invitation a l'org `loreal-datafactory` (contacter Arnaud BAKOULA ou Mathieu DEBON)

---

## 10. Historique des decisions

| Decision | Raison |
|----------|--------|
| Tailwind CSS via CDN | Pas de build tool, ouvrable directement dans le navigateur |
| JS inline dans index.html | Simplicite, pas de bundler |
| **FastAPI** pour le backend | **Standard BTDP Framework** — remplace Flask (migration faite) |
| Google OAuth2 (ADC) au lieu de Azure client_id/secret | Documentation BTDP confirme que depuis GCP, un token Google suffit |
| Pas de framework JS (React/Vue) | Prototype V1, complexite minimale |
| Contacts supprimes du front | Demande du client |
| Endpoint `/health` ajoute | Standard BTDP pour Cloud Run |
| Artifact Registry au lieu de gcr.io | Recommandation BTDP (gcr.io deprecie) |
| Naming GCP `autoclean-gcr-main-ew1-np` | Convention BTDP : `app-trigram-name-region-env` |

---

## 11. Git & Repository

### Repository
- **URL** : https://github.com/mmadi-oa/auto-licence-clean
- **Organisation cible** : `loreal-datafactory` (en attente d'invitation)
- **Branche par defaut** : `develop`
- **Branches** : `master` (production), `develop` (integration)

### Conventions Git BTDP
- **Branch naming** : `feat/BTDP-XXX/description`, `bugfix/BTDP-XXX/description`
- **Commit messages** : `[BTDP-XXX](tag) Description` — tags: feat, bugfix, update, refactor, doc, test, ci, debt
- **Workflow** : Squash & Merge via PR sur `develop`
- **Commits signes** : GPG obligatoire (`commit.gpgsign = true`)

---

## 12. Comment lancer le projet

```bash
# 1. Cloner le repo
git clone git@github.com:mmadi-oa/auto-licence-clean.git
cd auto-licence-clean

# 2. Creer l'environnement virtuel
python -m venv .venv

# 3. Activer (Windows)
.venv\Scripts\activate

# 4. Installer les dependances
pip install -r requirements.txt

# 5. Configurer les variables
cp .env.example .env
# Editer .env avec BIGQUERY_BILLING_PROJECT=oa-data-coepowerbi-np

# 6. S'authentifier avec Google (necessaire pour BigQuery)
gcloud auth application-default login

# 7. Lancer le serveur
cd src
uvicorn api:app --reload --port 5000

# 8. Ouvrir http://localhost:5000
```
