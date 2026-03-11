# PRD — Auto Licence Clean Dashboard & API Documentation

**Version** : 1.0
**Date** : 2026-03-11
**Auteur** : M. MMADI — Power BI COE

---

## 1. Objectif

Créer une page web statique (HTML/CSS/JS) qui sert de **tableau de bord et documentation** pour le projet Auto Licence Clean. Le design doit s'inspirer du style corporate L'Oréal utilisé dans le portail BTDP Groups API (Apigee).

---

## 2. Audience cible

- Équipe Power BI COE (Anes, Abdelkader, Matthieu)
- Administrateurs IT qui supervisent le processus de nettoyage des licences
- Équipe BTDP pour validation technique

---

## 3. Design & Style Guide

### 3.1 Référence visuelle

S'inspirer du portail **BTDP Groups API** (L'Oréal Apigee) :

| Élément | Spécification |
|---------|--------------|
| **Header** | Barre sombre (#1a1a1a) avec logo L'ORÉAL blanc, navigation horizontale |
| **Badges environnement** | Pill badges : Live (vert), Pre-Production (orange), Quality (gris) |
| **Fond de page** | Blanc (#ffffff) avec sections séparées par bordures légères (#e0e0e0) |
| **Sidebar** | Navigation fixe à gauche, liens vers les sections |
| **Badges HTTP** | GET (bleu #2196F3), POST (vert #4CAF50), DELETE (rouge #f44336), PATCH (orange #FF9800) |
| **Typographie** | Sans-serif (system font stack ou Inter/Roboto), titres en gras |
| **Cards endpoints** | Ligne avec badge méthode + path monospace + description, bordure subtile |
| **Couleur accent** | Noir L'Oréal (#1a1a1a) + doré discret (#c5a76c) pour les liens |

### 3.2 Responsive

- Desktop first (usage principal sur PC de bureau)
- Sidebar collapse sur mobile (< 768px)

---

## 4. Structure de la page

### 4.1 Header

```
┌─────────────────────────────────────────────────────────────┐
│ L'ORÉAL    Auto Licence Clean    Power BI COE               │
│ [Live] [Pre-Prod]                                           │
└─────────────────────────────────────────────────────────────┘
```

- Logo L'Oréal à gauche
- Titre "Auto Licence Clean" au centre
- Badges d'environnement : **Live** (vert), **Pre-Prod** (orange)
- Badge statut DRY_RUN actif/inactif

### 4.2 Sidebar (navigation fixe)

```
Overview
├── Status
├── Configuration
API Endpoints
├── BigQuery
├── Groups API
Architecture
├── Diagramme
├── Composants
Exécution
├── Dry Run
├── Logs
```

### 4.3 Section 1 — Overview / Status

Carte résumé avec :

| Métrique | Exemple |
|----------|---------|
| Mode actuel | `DRY_RUN: true` (badge vert/rouge) |
| Dernière exécution | 2026-03-10 02:00 UTC |
| Utilisateurs identifiés | 342 |
| Licences révoquées (dernier run) | 0 (dry-run) |
| Retention days | 120 |
| Batch size | 20 |

### 4.4 Section 2 — API Endpoints

Style identique au portail BTDP : liste d'endpoints avec badges HTTP.

#### BigQuery

```
┌──────────────────────────────────────────────────────────────┐
│  BigQuery — Identification des licences à révoquer           │
│  Table: license_pro_users_v1          [Voir la requête SQL]  │
├──────────────────────────────────────────────────────────────┤
│ SELECT  licence_pro_usage.sql   Requête d'identification     │
└──────────────────────────────────────────────────────────────┘
```

#### BTDP Groups API

```
┌──────────────────────────────────────────────────────────────┐
│  BTDP Groups API — Gestion des membres du groupe licence     │
│  Base URL: api.loreal.net/global/it4it/itg-groupsapi/v1     │
├──────────────────────────────────────────────────────────────┤
│ GET    /groups/{group_email}/members        List members     │
│ DELETE /groups/{group_email}/members        Remove members   │
│ GET    /groups/{group_email}/authorized     List owners      │
│ POST   /groups/{group_email}/authorized     Add owner        │
└──────────────────────────────────────────────────────────────┘
```

Chaque endpoint est cliquable et affiche un panneau expandable avec :
- Description
- Exemple curl
- Paramètres (path, query, body)
- Réponse attendue (JSON)

### 4.5 Section 3 — Architecture

Diagramme ASCII ou SVG du flow :

```
Cloud Scheduler (02h00)
       │
       ▼
Cloud Run Job (Python)
       │
       ├──► BigQuery → emails à révoquer
       ├──► Groups API → DELETE par batches
       └──► Cloud Logging → audit
```

Tableau des composants (comme dans le README) :

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| Orchestration | Cloud Scheduler | Cron quotidien |
| Exécution | Cloud Run Job | Conteneur Python |
| Source | BigQuery | Identification |
| Révocation | BTDP Groups API | Suppression groupe AD |
| Monitoring | Cloud Logging | Traçabilité |

### 4.6 Section 4 — Configuration

Tableau interactif des variables d'environnement :

| Variable | Valeur actuelle | Source | Statut |
|----------|----------------|--------|--------|
| `BIGQUERY_BILLING_PROJECT` | `oa-data-coepowerbi-np` | Matthieu | ✅ |
| `PRO_LICENSE_GROUP_EMAIL` | — | Anes | ⏳ |
| `DRY_RUN` | `true` | Config | ✅ |
| `BATCH_SIZE` | `20` | Config | ✅ |
| `RETENTION_DAYS` | `120` | Config | ✅ |

### 4.7 Section 5 — Exécution & Logs

#### Dry Run

Affichage du dernier CSV dry-run (tableau HTML) :

| Email | Action | Date |
|-------|--------|------|
| john.doe@loreal.com | REVOKE_PRO_LICENCE | 2026-03-10 |
| jane.smith@loreal.com | REVOKE_PRO_LICENCE | 2026-03-10 |

#### Historique des exécutions

| Date | Mode | Utilisateurs | Révoqués | Échecs |
|------|------|-------------|----------|--------|
| 2026-03-10 | DRY_RUN | 342 | 0 | 0 |

### 4.8 Section 6 — Contacts

Cards avec :
- Matthieu BUREL — Architecture / GCP
- Anes — SQL / Données SSDS IT
- Abdelkader — Script PowerShell original
- M. MMADI — Tenant Admin / Pilotage

---

## 5. Spécifications techniques

### 5.1 Stack

| Technologie | Usage |
|-------------|-------|
| HTML5 | Structure |
| CSS3 (vanilla) | Styling — pas de framework (rester léger et corporate) |
| JavaScript (vanilla) | Interactions (expand/collapse endpoints, sidebar toggle) |
| Aucun build tool | Fichier statique, ouvrable directement dans le navigateur |

### 5.2 Structure des fichiers

```
Auto_Licence_Clean/
└── docs/
    ├── PRD_FRONTEND.md       ← ce fichier
    ├── index.html            ← page principale
    ├── style.css             ← styles
    └── app.js                ← interactions
```

### 5.3 Données

Pour la V1, les données sont **statiques** (hardcodées dans le HTML).
Évolution future : lecture du CSV dry-run via JavaScript FileReader.

---

## 6. Critères d'acceptation

- [ ] Le design ressemble visuellement au portail BTDP Groups API
- [ ] Header sombre avec branding L'Oréal
- [ ] Sidebar de navigation fonctionnelle (scroll vers les sections)
- [ ] Badges HTTP colorés (GET bleu, POST vert, DELETE rouge)
- [ ] Endpoints expandables avec exemples curl
- [ ] Section configuration avec statut des variables
- [ ] Responsive basique (sidebar collapse sur mobile)
- [ ] Ouvrable directement dans un navigateur (pas de serveur requis)

---

## 7. Hors scope (V1)

- Authentification / login
- Connexion live à BigQuery ou à l'API
- Upload de fichiers CSV
- Backend / serveur

---

## 8. Évolutions futures (V2)

- Connexion au CSV dry-run pour affichage dynamique
- Bouton "Lancer le dry-run" (appel API)
- Dashboard temps réel avec Cloud Monitoring
- Intégration dans un portail interne L'Oréal
