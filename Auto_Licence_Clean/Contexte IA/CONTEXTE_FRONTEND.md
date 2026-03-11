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
| Backend | Flask (Python) | `api.py` — sert le front + expose les endpoints |
| BDD source | BigQuery (GCP) | Table `license_pro_users_v1` |
| API externe | BTDP Groups API (L'Oreal) | DELETE /groups/{email}/members |
| Auth | Google OAuth2 (ADC) | `gcloud auth application-default login` en local |

---

## 3. Structure des fichiers

```
Auto_Licence_Clean/
├── docs/
│   ├── index.html          ← PAGE PRINCIPALE (Tailwind CSS, tout-en-un)
│   ├── style.css           ← ancien CSS vanilla (non utilise par index.html)
│   ├── app.js              ← ancien JS vanilla (non utilise par index.html)
│   └── PRD_FRONTEND.md     ← PRD original
├── src/
│   ├── api.py              ← BACKEND FLASK (sert le front + API)
│   ├── main.py             ← orchestrateur batch (Cloud Run Job)
│   ├── config.py           ← variables d'environnement
│   ├── bigquery_client.py  ← requete SQL BigQuery
│   ├── groups_api_client.py ← appels BTDP Groups API (Google OAuth2)
│   └── reporter.py         ← export CSV
├── .env                    ← variables locales (NE PAS COMMITTER)
├── .env.example            ← template des variables
└── requirements.txt        ← dependances Python
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

## 5. Backend Flask (api.py)

### Endpoints

| Route | Methode | Description | Necessite BigQuery |
|-------|---------|-------------|-------------------|
| `/` | GET | Sert `index.html` | Non |
| `/api/status` | GET | Config actuelle + dernier run | Non |
| `/api/users` | GET | Liste complete des emails (BigQuery) | Oui |
| `/api/count` | GET | Nombre d'utilisateurs seulement | Oui |
| `/api/dry-run` | POST | Dry run complet + export CSV | Oui |
| `/api/logs` | GET | Historique des executions (in-memory) | Non |
| `/api/config/validate` | GET | Statut de chaque variable d'env | Non |

### Demarrage
```bash
cd Auto_Licence_Clean/src
../.venv/Scripts/python api.py    # Windows
# ou: ../.venv/bin/python api.py  # Linux/Mac
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

## 8. Ce qui reste a faire

### Frontend
- [ ] Afficher un message d'erreur user-friendly quand les credentials Google ne sont pas configurees
- [ ] Ajouter un spinner/loading state sur les cartes pendant le chargement
- [ ] Sidebar : scroll vers les sections au clic (actuellement visuel uniquement)
- [ ] Mode dark (le HTML a les classes Tailwind `dark:` mais pas de toggle)
- [ ] Responsive mobile : tester et ajuster

### Backend
- [ ] Persister l'historique des executions (actuellement in-memory, perdu au restart)
- [ ] Ajouter un endpoint pour telecharger le CSV dry-run
- [ ] Ajouter un health check endpoint `/api/health`

### Infra / Acces
- [ ] Obtenir `PRO_LICENSE_GROUP_EMAIL` aupres d'Anes
- [ ] Ajouter le service account comme invoker de la Groups API (Service Request BTDP)
- [ ] Ajouter le service account comme owner du groupe licence Pro
- [ ] Activer Secret Manager API sur `oa-data-coepowerbi-np` (bloque — demande a Matthieu)

---

## 9. Historique des decisions

| Decision | Raison |
|----------|--------|
| Tailwind CSS via CDN | Pas de build tool, ouvrable directement dans le navigateur |
| JS inline dans index.html | Simplicite, pas de bundler |
| Flask pour le backend | Leger, deja utilise dans l'ecosysteme BTDP |
| Google OAuth2 (ADC) au lieu de Azure client_id/secret | Documentation BTDP confirme que depuis GCP, un token Google suffit |
| Pas de framework JS (React/Vue) | Prototype V1, complexite minimale |
| Contacts supprimes du front | Demande du client |

---

## 10. Comment lancer le projet

```bash
# 1. Cloner le repo
git clone https://github.com/JochooGari/OA_Digital.git
cd OA_Digital/Auto_Licence_Clean

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
python api.py

# 8. Ouvrir http://localhost:5000
```
