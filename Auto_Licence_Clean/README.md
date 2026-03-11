# Auto-Cleaning des Licences Power BI Pro

**Équipe** : Power BI COE — L'Oréal
**Statut** : En cours de développement
**Dernière mise à jour** : Mars 2026

---

## Contexte

L'Oréal dispose d'un parc de licences Power BI Pro attribuées aux collaborateurs via des groupes Azure Active Directory. Au fil du temps, des licences restent assignées à des utilisateurs qui n'utilisent plus la plateforme, générant un coût inutile.

Jusqu'à présent, la détection reposait sur une requête SQL manuelle + un script PowerShell exécuté manuellement par Abdelkader.

---

## Règles métier

Un utilisateur est candidat à la révocation si **toutes** les conditions sont remplies :

1. Pas d'activité **CONSUMER** depuis > **120 jours**
2. Pas d'activité **BUILDER** depuis > **120 jours**
3. **Pas propriétaire** d'un workspace, semantic model ou rapport Pro actif
4. Licence depuis > **60 jours** (protège les nouveaux arrivants)
5. **Compte humain** (exclut les comptes techniques)

---

## Architecture

```
Cloud Scheduler (cron : 1x/jour à 02h00)
        │
        ▼
Cloud Run Job (Python — conteneur Docker)
        │
        ├─► BigQuery (SSDS IT) → liste des emails à révoquer
        ├─► BTDP Groups API   → DELETE par batches de 20 (SafeMode)
        └─► Cloud Logging     → audit + alertes
```

---

## Structure du projet

```
Auto_Licence_Clean/
├── README.md              ← ce fichier
├── .env.example           ← template des variables d'environnement
├── .gitignore             ← exclut .env, output/, .venv/
├── requirements.txt       ← dépendances Python
├── deploy.sh              ← script de déploiement GCP
├── sql/
│   └── licence_pro_usage.sql  ← requête SQL BigQuery
├── src/
│   ├── main.py            ← orchestrateur principal
│   ├── config.py          ← variables d'environnement + validation
│   ├── bigquery_client.py ← connexion BigQuery + exécution SQL
│   ├── groups_api_client.py ← OAuth2 + appels API batched
│   ├── reporter.py        ← export CSV dry-run + audit
│   └── tests/
│       ├── test_bigquery_client.py
│       ├── test_groups_api_client.py
│       └── test_reporter.py
└── docker/
    └── Dockerfile         ← image Cloud Run Job
```

---

## Quick start

```bash
# 1. Créer l'environnement virtuel
python -m venv .venv
.venv/Scripts/activate        # Windows
# source .venv/bin/activate   # Linux/Mac

# 2. Installer les dépendances
pip install -r requirements.txt

# 3. Configurer les variables
cp .env.example .env
# Éditer .env avec tes valeurs

# 4. Lancer en dry-run
cd src
python main.py

# 5. Lancer les tests
pytest tests/
```

---

## Variables d'environnement

| Variable | Description | Source |
|----------|-------------|--------|
| `BIGQUERY_BILLING_PROJECT` | Projet GCP facturé pour les requêtes BQ | Matthieu |
| `API_CLIENT_ID` | Client ID OAuth2 | Matthieu |
| `API_CLIENT_SECRET` | Client Secret OAuth2 | Matthieu |
| `PRO_LICENSE_GROUP_EMAIL` | Email du groupe AD licence Pro | Anes |
| `DRY_RUN` | `true` = simulation, `false` = révocation | Défaut: `true` |

---

## Contacts

| Rôle | Personne |
|------|----------|
| Architecture / GCP | Matthieu BUREL |
| SQL / données SSDS IT | Anes |
| Script PowerShell original | Abdelkader |
| Tenant Admin / pilotage | M. MMADI |
