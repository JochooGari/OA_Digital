# CLAUDE.md — Contexte projet OA Digital / Power BI COE

> Fichier lu automatiquement par Claude Code à chaque démarrage.
> Mis à jour le 2026-03-12.

---

## Qui suis-je ?

**Mohcine MMADI** — Tenant Administrator Power BI / Fabric chez L'Oréal (depuis mars 2026).
Rattaché à l'équipe **OA Digital / Power BI COE**.

Contacts clés :
- **Anes** — Expert Power BI COE, référent sur les sujets licences et stress test
- **Abdelkader** — Développeur, auteur du script PowerShell de stress test (`Orchestrator.ps1`)
- **Matthieu** — Responsable IT Platform Services / GCP, à contacter pour les credentials et projets GCP

---

## Projets en cours

### 1. Auto Licence Cleaning (PRIORITÉ 1)

**Objectif** : Automatiser la révocation des licences Power BI Pro pour les utilisateurs inactifs.
Actuellement manuel (SQL + PowerShell exécuté par Abdelkader).

**Architecture cible** :
```
Cloud Scheduler (1x/jour, 02h00)
  → Cloud Run Job Python (GCP)
     ├── BigQuery → liste emails à révoquer
     ├── BTDP Groups API → DELETE /groups/{group_email}/members
     ├── Cloud Logging → audit
     └── Cloud Monitoring → alertes
```

**Code disponible** : `PowerBI_COE/Auto Licence Cleaning/auto_clean_licences/`
- `config.py` — variables d'environnement
- `bigquery_client.py` — requête SQL BigQuery
- `groups_api_client.py` — OAuth2 + appels API batched (max 20/appel)
- `main.py` — orchestrateur principal
- `reporter.py` — export CSV dry-run + audit
- `tests/` — tests unitaires complets (sans credentials)
- `deploy.sh` — déploiement Cloud Run Job + Cloud Scheduler
- `.env.example` — toutes les variables avec commentaires

**SQL source** : `PowerBI_COE/Auto Licence Cleaning/Licence Pro Usage.sql`
Table BigQuery : `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.license_pro_users_v1`
Filtre : `need_pro_license=FALSE AND NbDayHaveLicence>60 AND IsHuman=TRUE`

**API** : BTDP Groups API (interne L'Oréal)
- Spec : `PowerBI_COE/Auto Licence Cleaning/Open API Specification.json`
- Auth : OAuth2 Client Credentials, scope `BTDPAPI.RW`
- PROD base URL : `https://api.loreal.net/global/it4it/itg-groupsapi/v1`
- Token URL PROD : `https://api.loreal.net/v1/oauth20/token`
- SafeMode : max 20 suppressions/appel → batching de 20 implémenté

**Éléments manquants (à demander)** :

| Info | À qui | Statut |
|------|-------|--------|
| `PRO_LICENSE_GROUP_EMAIL` | Anes | ⏳ En attente |
| `API_CLIENT_ID` | Matthieu | ⏳ En attente |
| `API_CLIENT_SECRET` | Matthieu | ⏳ En attente |
| `BIGQUERY_BILLING_PROJECT` | Matthieu | ⏳ En attente |
| Projet GCP déploiement | Matthieu | ⏳ En attente |
| Service account GCP | Matthieu | ⏳ En attente |

**Mode DRY_RUN=true par défaut** — le script est prêt à coder/tester sans credentials.

---

### 2. Performance Testing / Stress Test Power BI

**Objectif** : Tester la capacité Premium Power BI sous charge.

**Outil** : OA Realistic Load Testing Framework v2.0 (PowerShell)
**Chemin local** : `OARealisticLoadTestTool/OARealisticLoadTestTool/`
**Script principal** : `Orchestrator.ps1`
**Config rapport** : `PBIReport.json` — déjà configuré (reportId=82891daf, groupId=83771731, page=45941f97)

**Rapport ciblé** : NERD Dashboard (performance Salesforce Commerce Cloud)
**Filtres configurés** : `division.division_code` in [CPD, LDB, LLD, No-division-code, PPD]

**Procédure complète** :
1. Ouvrir PowerShell → `cd "OARealisticLoadTestTool\OARealisticLoadTestTool"`
2. Lancer : `.\Orchestrator.ps1`
3. Attendre la fin → vérifier `logs/orchestrator_log.csv` et `logs/logPage.csv`
4. Ouvrir le Fabric Notebook dans le workspace de performance testing
5. Cliquer "Run all" → rafraîchissement du modèle
6. Actualiser le rapport Power BI pour voir les résultats

**Sources de logs** :
- Local : `logs/orchestrator_log.csv`, `logs/logPage.csv`
- Fabric Monitoring Hub : KQL sur `SemanticModelLogs`
- GCP BigQuery : `capacity_unit_timepoint_v2` (délai 24h)

**Documentation** : `PowerBI_COE/Performance Testing/README.md`
**Passation Anes** : `PowerBI_COE/Performance Testing/Passation.md`

**En attente** :
- Lien Google Sheet de résultats (demander à Anes)
- Lien notebook Fabric (demander à Abdelkader)
- Confirmer avec Abdelkader que PBIReport.json cible bien le bon rapport

---

### 3. NERD Dashboard

**Objectif** : Rapport Power BI monitorant les performances Salesforce Commerce Cloud (SFCC).
Métriques : response time, cache hit rate, error rate, best practices score.

**Guide utilisateur** : `Documentation/GUIDE_UTILISATEUR_METIER.md`
**Documentation technique complète** : `Documentation/DOCUMENTATION_COMPLETE_NERD.md`

---

## Actions en attente / TODO

- [ ] Contacter Anes pour : `PRO_LICENSE_GROUP_EMAIL`, lien Google Sheet stress test
- [ ] Contacter Matthieu pour : client_id, client_secret, billing project, deployment project, service account GCP
- [ ] S'ajouter aux capacités Premium (EUROPE-0, EUROPE-3, BTDP Retail, DGAF DATA FACTORY TEAM) via le portail admin — faire pendant que les droits Tenant Admin sont actifs
- [ ] Confirmer avec Abdelkader le rapport ciblé par PBIReport.json + lien notebook Fabric
- [ ] Tester le script auto-clean en dry-run une fois les credentials reçus

---

## Accès Confluence BTDP

Claude peut interroger Confluence L'Oréal via l'API REST pour chercher de la documentation BTDP.

**URL de base** : `https://confluence.e-loreal.com/rest/api/`
**Espace principal** : `BTDP`
**Auth** : Bearer token (Personal Access Token)

### Utilisation

```bash
# Rechercher des pages
curl -s -H "Authorization: Bearer <TOKEN>" \
  "https://confluence.e-loreal.com/rest/api/search?cql=text~%22mot+clé%22+AND+space=BTDP&limit=20"

# Lire une page (contenu HTML)
curl -s -H "Authorization: Bearer <TOKEN>" \
  "https://confluence.e-loreal.com/rest/api/content/<PAGE_ID>?expand=body.view"
```

### Pages clés identifiées

| ID | Titre | Contenu |
|----|-------|---------|
| 698409093 | 9. MCP Server (DRAFT) | Module MCP FastAPI, déploiement Cloud Run, ajout de tools |
| 666345194 | 8.2 Framework MCP | Overview framework v2.26.2, modules disponibles |
| 712065707 | 4.11 Conversational Analytics | Architecture CA, Power BI Agent DAX, Orchestrator |
| 698408985 | 2.1.16 GenAI Configurations | Config agents YAML, OAuth/Cloud-Run auth, GenAI Config API |
| 512729274 | BTDP Framework | Page racine du framework |

---

## MCP Servers disponibles localement

### powerbi-modeling-mcp (Microsoft, v0.4.0)

**MCP officiel Microsoft** pour interagir avec les modèles sémantiques Power BI.
Repo : `github.com/microsoft/powerbi-modeling-mcp` (Public Preview)

**Installé** : `C:\Users\M.MMADI-EXT\MCPServers\PowerBIModelingMCP\powerbi-modeling-mcp.exe`
**Config** : `~/.claude/settings.json` → `mcpServers.powerbi-modeling-mcp`

**23 tools disponibles** :
- `connection_operations` — connexion à Power BI Desktop, Fabric Workspace, ou dossier PBIP
- `table_operations` — lecture/modification des tables
- `relationship_operations` — relations entre tables
- `measure_operations` / `batch_measure_operations` — mesures DAX
- `column_operations` / `batch_column_operations` — colonnes
- `partition_operations` — partitions
- `named_expression_operations` — expressions M/DAX nommées
- Requêtes DAX, sécurité (RLS), TMDL import/export, déploiement Fabric

**Connexion** :
- Power BI Desktop : `"Connect to '[Nom du fichier]' in Power BI Desktop"`
- Fabric : `"Connect to semantic model '[Nom]' in Fabric Workspace '[Workspace]'"`
- PBIP : `"Open semantic model from PBIP folder '[Chemin]'"`

**Args CLI** : `--start` (requis), `--readonly`, `--readwrite` (défaut), `--skipconfirmation`

### filesystem

MCP server pour accès au système de fichiers local :
- `list_directory`, `directory_tree`, `read_text_file`

---

## Git — Dépôts du projet

### 1. Dépôt personnel (JochooGari) — repo complet OA Digital

**URL** : `https://github.com/JochooGari/OA_Digital`
**Remote git** : `origin`
**Branche** : `main`
**Contenu** : tout le workspace OA Digital (Auto_Licence_Clean, CLAUDE.md, Mockup Front...)

### 2. Dépôt pro L'Oréal — Auto Licence Clean uniquement

**URL** : `https://github.com/mmadi-oa/auto-licence-clean`
**Remote git** : `loreal`
**Branche** : `main`
**Contenu** : uniquement le dossier `Auto_Licence_Clean/` (subtree push)
**Compte** : `mmadi-oa` (compte GitHub L'Oréal pro)

Pour pusher vers le dépôt pro :
```bash
git subtree push --prefix=Auto_Licence_Clean loreal main
```

### Connexion SSH (configurée pour les deux)

| Élément | Valeur |
|---------|--------|
| Clé privée | `~/.ssh/loreal_ed25519` |
| Clé publique | `~/.ssh/loreal_ed25519.pub` |
| Host | `github.com` |
| User | `git` |

**Config SSH** (`~/.ssh/config`) :
```
Host github.com
    HostName github.com
    User git
    AddKeysToAgent yes
    IdentityFile ~/.ssh/loreal_ed25519
```

### Règles de commit
- Ne jamais committer automatiquement — toujours demander confirmation
- Ne pas committer : `Auto_Licence_Clean/data/`, `*.docx`, `.env`, secrets
- Les fichiers sensibles sont dans `.gitignore`

---

## Préférences et conventions

- Langue de travail : **français** pour les échanges, **anglais** pour le code
- Ne jamais committer automatiquement — toujours demander confirmation
- Style de réponse : concis, directs, sans fioritures
- Niveau technique : intermédiaire sur Power BI/DAX, débutant sur GCP/Python/PowerShell

---

## Structure des dossiers clés

```
OA Digital/
├── CLAUDE.md                          ← CE FICHIER
├── Documentation/
│   ├── GUIDE_UTILISATEUR_METIER.md    ← Guide NERD Dashboard
│   └── DOCUMENTATION_COMPLETE_NERD.md
├── OARealisticLoadTestTool/
│   └── OARealisticLoadTestTool/
│       ├── Orchestrator.ps1           ← Script stress test
│       ├── PBIReport.json             ← Config rapport (déjà configurée)
│       └── logs/                      ← Résultats des tests
└── PowerBI_COE/
    ├── Auto Licence Cleaning/
    │   ├── Licence Pro Usage.sql
    │   ├── Open API Specification.json
    │   ├── README.md
    │   └── auto_clean_licences/       ← Code Python complet
    │       ├── main.py
    │       ├── config.py
    │       ├── bigquery_client.py
    │       ├── groups_api_client.py
    │       ├── reporter.py
    │       ├── tests/
    │       ├── deploy.sh
    │       └── .env.example
    └── Performance Testing/
        ├── README.md                  ← Documentation complète
        └── Passation.md              ← Transcript réunion avec Anes
```
