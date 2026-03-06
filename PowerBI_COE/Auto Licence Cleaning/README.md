# Auto-Cleaning des Licences Power BI Pro

**Équipe** : Power BI COE — L'Oréal
**Statut** : En cours de développement
**Dernière mise à jour** : Mars 2026

---

## Contexte

L'Oréal dispose d'un parc de licences Power BI Pro attribuées aux collaborateurs via des groupes Azure Active Directory. Au fil du temps, des licences restent assignées à des utilisateurs qui n'utilisent plus la plateforme (départs, changements de poste, inactivité prolongée), générant un coût inutile et une surface de gouvernance non maîtrisée.

Jusqu'à présent, la détection des licences à révoquer reposait sur :
- Une **requête SQL manuelle** exécutée à la demande sur la base de données SSDS IT (BigQuery)
- Un **script PowerShell** exécuté manuellement par Abdelkader pour appliquer les révocations

Ce processus entièrement manuel n'était pas exécuté à fréquence régulière et dépendait de la disponibilité des personnes concernées.

---

## Besoin métier

| Besoin | Détail |
|--------|--------|
| **Réduire les coûts de licences** | Révoquer automatiquement les licences des utilisateurs inactifs |
| **Fiabiliser le processus** | Ne plus dépendre d'une action manuelle ponctuelle |
| **Protéger les assets** | Ne pas révoquer la licence d'un utilisateur qui est propriétaire de rapports ou datasets actifs |
| **Traçabilité** | Garder un historique des révocations pour audit |
| **Sécurité** | Ne jamais révoquer en masse sans contrôle — conserver un mécanisme de limite |

### Règles métier appliquées

Un utilisateur est candidat à la révocation si **toutes** les conditions suivantes sont remplies :

1. Il n'a pas eu d'activité **CONSUMER** (lecture de rapports) depuis plus de **120 jours**
2. Il n'a pas eu d'activité **BUILDER** (création/édition) depuis plus de **120 jours**
3. Il n'est **pas propriétaire** d'un workspace, semantic model ou rapport Pro actif
4. Il possède la licence depuis plus de **60 jours** (évite de révoquer les nouveaux arrivants)
5. Il s'agit d'un **compte humain** (les comptes techniques sont exclus)

---

## Solution technique retenue

### Pourquoi GCP ?

La table source des utilisateurs (`license_pro_users_v1`) est hébergée sur **Google Cloud Platform** dans le projet BigQuery de L'Oréal (`itg-btdppublished-gbl-ww-pd`). Orchestrer l'automatisation depuis GCP évite tout transfert de données inter-cloud et s'inscrit dans l'infrastructure existante.

### Pourquoi Python et non PowerShell ?

Le script PowerShell existant était exécuté en local sur un poste Windows. La cible d'automatisation sur GCP (sans VM) nécessite un langage compatible avec les environnements conteneurisés serverless. **Python** a été retenu sur demande de Matthieu BUREL, et s'intègre nativement avec les SDK GCP (BigQuery, Cloud Logging, Secret Manager).

### Architecture

```
Cloud Scheduler (cron : 1x/jour à 02h00)
        │
        ▼
Cloud Run Job (Python — conteneur Docker)
        │
        ├─► BigQuery (SSDS IT)
        │       └── Requête SQL → liste des emails à révoquer
        │
        ├─► BTDP Groups API (L'Oréal)
        │       └── DELETE /groups/{group_email}/members
        │           └── Suppression par batches de 20 (SafeMode API)
        │
        └─► Cloud Logging
                └── Logs structurés + alerte email sur erreur critique
```

### Composants

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| Orchestration | Cloud Scheduler | Déclenchement quotidien |
| Exécution | Cloud Run Job | Conteneur Python sans VM |
| Source de données | BigQuery (SSDS IT) | Identification des licences à révoquer |
| Révocation | BTDP Groups API | Suppression du groupe AD → révocation licence |
| Secrets | GCP Secret Manager | Stockage sécurisé des credentials API |
| Monitoring | Cloud Logging + Cloud Monitoring | Traçabilité et alertes |

### Sécurité

- Les credentials OAuth2 (client_id / client_secret) ne sont **jamais** dans le code — stockés dans **GCP Secret Manager**
- L'API BTDP intègre un mécanisme **SafeMode** : maximum 20 suppressions par appel, pour éviter toute révocation accidentelle en masse
- Un mode **DRY_RUN** permet de simuler l'exécution complète sans aucune révocation réelle

---

## Structure du projet

```
Auto Licence Cleaning/
├── README.md                        ← ce fichier
├── Licence Pro Usage.sql            ← requête SQL d'identification des licences à révoquer
├── Open API Specification.json      ← spécification OpenAPI de la BTDP Groups API
└── auto_clean_licences/
    ├── main.py                      ← orchestrateur principal
    ├── bigquery_client.py           ← connexion BigQuery + exécution SQL
    ├── groups_api_client.py         ← authentification OAuth2 + appels API
    ├── config.py                    ← variables d'environnement + validation
    ├── requirements.txt             ← dépendances Python
    └── Dockerfile                   ← image Cloud Run Job
```

---

## Variables d'environnement requises

| Variable | Description | Valeur exemple |
|----------|-------------|----------------|
| `BIGQUERY_PROJECT` | Projet GCP contenant la table source | `itg-btdppublished-gbl-ww-pd` |
| `BIGQUERY_BILLING_PROJECT` | Projet GCP facturé pour les requêtes BQ | À confirmer avec l'équipe GCP |
| `API_BASE_URL` | URL de base de la BTDP Groups API | `https://api.loreal.net/global/it4it/itg-groupsapi/v1` |
| `API_TOKEN_URL` | URL OAuth2 pour obtenir un token | `https://api.loreal.net/v1/oauth20/token` |
| `API_CLIENT_ID` | Client ID OAuth2 (Secret Manager) | — |
| `API_CLIENT_SECRET` | Client Secret OAuth2 (Secret Manager) | — |
| `PRO_LICENSE_GROUP_EMAIL` | Email du groupe AD qui assigne la licence Pro | À confirmer avec IT / Anes |
| `DRY_RUN` | `true` = simulation, `false` = révocation réelle | `true` (défaut) |
| `RETENTION_DAYS` | Jours d'inactivité avant révocation | `120` |
| `BATCH_SIZE` | Taille des batches d'appels API (max 20) | `20` |

---

## Stratégie de test

| Étape | Environnement | Mode | Valideur |
|-------|--------------|------|----------|
| 1. Valider la SQL | BigQuery dev | Lecture seule | Anes |
| 2. Tester l'API | `dev-emea.api.loreal.net` | DRY_RUN=true | Dev |
| 3. Test réel sur 1 compte de test | QUA | DRY_RUN=false | Dev + Anes |
| 4. Dry-run prod — valider la liste | PROD | DRY_RUN=true | Anes |
| 5. Go prod | PROD | DRY_RUN=false | Matthieu BUREL |

---

## Informations manquantes (à obtenir)

- [ ] **Email du groupe AD** Power BI Pro → Anes ou IT
- [ ] **client_id** et **client_secret** OAuth2 → IT Platform Services (`IT-GLOBAL-GCP-BTDP_TEAM_PLATFORMSERVICES@loreal.com`)
- [ ] **Projet GCP de facturation** BigQuery → Matthieu BUREL
- [ ] **Projet GCP de déploiement** Cloud Run → Matthieu BUREL
- [ ] **Service account GCP** pour le Cloud Run Job → Matthieu BUREL

---

## Contacts

| Rôle | Personne |
|------|----------|
| Décision architecture / déploiement GCP | Matthieu BUREL |
| Requête SQL / données SSDS IT | Anes |
| Script PowerShell original | Abdelkader |
| IT Platform Services (API BTDP) | IT-GLOBAL-GCP-BTDP_TEAM_PLATFORMSERVICES@loreal.com |
| Tenant Admin Power BI / pilotage sujet | M. MMADI |
