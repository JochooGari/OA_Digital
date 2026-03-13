# Troubleshooting Guide — Incidents Capacite Power BI / Fabric

> Guide de resolution des incidents les plus courants sur les capacites Fabric.
> A publier sur Confluence pour l'equipe COE et les equipes projet.
> Remplacer `<CAPACITY_ID>` par le GUID de la capacite (ex: `799dde1d-a775-4a11-b4ea-d03da356b009` = nefapbtdpcommunity2).
> Derniere mise a jour : 2026-03-13

---

## Comment utiliser ce guide

1. Identifier le **symptome** observe (section 1)
2. Suivre la **procedure de diagnostic** (section 2)
3. Appliquer la **resolution** correspondante (section 3)
4. Documenter dans une **fiche incident** (voir templates/)

---

## 1. Symptomes et diagnostic rapide

### S1 — Rapports lents (> 30s de chargement)

| Cause probable | Verification | Resolution |
|---------------|-------------|------------|
| Capacite surchargee | Admin Portal > Capacity > CU% | Voir R1 |
| Modele DirectQuery non optimise | MCP audit : partition mode | Voir R2 |
| Refresh en cours | Admin Portal > Datasets > Refresh history | Voir R3 |
| Source de donnees lente | Performance Analyzer dans Power BI Desktop | Voir R4 |

### S2 — Rapports en echec (Failure / "Cannot load model")

| Cause probable | Verification | Resolution |
|---------------|-------------|------------|
| Throttling severe (CU > 200%) | Admin Portal > Capacity Metrics | Voir R1 |
| Modele corrompu | Refresh dataset | Voir R5 |
| Credentials expirees | Admin Portal > Datasets > Settings > Data source credentials | Voir R6 |
| Capacite pausee | Admin Portal > Capacities > Status | Voir R7 |

### S3 — Refresh en echec

| Cause probable | Verification | Resolution |
|---------------|-------------|------------|
| Source de donnees inaccessible | Refresh error message | Voir R4 |
| Timeout (refresh > 2h pour Pro, > 5h pour Premium) | Duration du refresh | Voir R8 |
| Espace memoire insuffisant | Capacity Metrics > Memory | Voir R9 |
| Credentials expirees | Dataset settings | Voir R6 |

### S4 — Throttling continu (> 80% CU en permanence)

| Cause probable | Verification | Resolution |
|---------------|-------------|------------|
| Trop de modeles DQ sur la capacite | Audit des datasets | Voir R10 |
| Trop d'utilisateurs simultanes | Monitoring Hub > Concurrent users | Voir R11 |
| Refresh planifies en heures de pointe | Refresh schedules | Voir R3 |
| SKU sous-dimensionne | Comparer CU utilise vs CU disponible | Voir R12 |

---

## 2. Procedures de diagnostic

### D1 — Verification rapide capacite (< 5 min)

```
1. Ouvrir Power BI Admin Portal (app.powerbi.com/admin)
2. Aller dans Capacity settings
3. Selectionner la capacite concernee
4. Onglet "Metrics" → verifier :
   - CU% actuel (< 80% = OK, > 100% = probleme)
   - Throttling (0 = OK, > 0 = probleme)
   - Nombre de requetes en echec
```

### D2 — Audit Monitoring Hub (< 15 min)

```kql
// Etape 1 : Vue globale des 2 dernieres heures
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    Failures = countif(Status == "Failure"),
    AvgDurationMs = avg(DurationMs),
    MaxCpuTimeMs = max(CpuTimeMs),
    Users = dcount(ExecutingUser)
    by bin(Timestamp, 5m)
| order by Timestamp desc
```

```kql
// Etape 2 : Top datasets consommateurs
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by ItemName
| order by TotalCpuMs desc
| take 10
```

```kql
// Etape 3 : Top utilisateurs
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs)
    by ExecutingUser
| order by TotalCpuMs desc
| take 10
```

### D3 — Audit modele semantique via MCP (< 10 min)

```
1. Claude Code > MCP Power BI > ConnectFabric
   - WorkspaceName: "<nom du workspace>"
   - SemanticModelName: "<nom du modele>"

2. table_operations > List
   → Verifier columnCount par table (alerte si > 100)

3. partition_operations > List
   → Verifier "mode" de chaque partition
   → Compter : combien en DirectQuery vs Import vs Dual

4. measure_operations > List
   → Compter le nombre total de mesures (alerte si > 200)

5. model_operations > Get
   → Verifier defaultMode, sources DQ chainees
```

### D4 — Verification BigQuery (delai 24h)

```sql
-- Top datasets par CU sur les 7 derniers jours
SELECT
  dataset_name,
  workspace_name,
  SUM(total_cu_seconds) as total_cu,
  AVG(duration_seconds) as avg_duration,
  COUNT(*) as query_count
FROM `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.capacity_unit_timepoint_v2`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND capacity_name = '<NOM_CAPACITE>'
GROUP BY dataset_name, workspace_name
ORDER BY total_cu DESC
LIMIT 20
```

---

## 3. Resolutions

### R1 — Capacite surchargee (CU > 100%)

**Actions immediates :**
1. Identifier le(s) dataset(s) qui surconsomment (D2, etape 2)
2. Suspendre les refresh planifies non-critiques
3. Contacter les utilisateurs impactes — leur demander de ne pas relancer les rapports
4. Si disponible, deplacer des workspaces non-critiques vers une autre capacite

**Actions moyen terme :**
- Optimiser les modeles DirectQuery (voir R2)
- Revoir le planning de refresh (voir R3)
- Evaluer un upgrade de SKU (voir R12)

### R2 — Modele DirectQuery non optimise

**Dimensions en DirectQuery :**
1. Identifier les tables de dimension (Dim_, country, Platform, Brands, Date...)
2. Ouvrir le modele dans Power BI Desktop
3. Pour chaque dimension : Properties > Storage mode > **Dual**
4. Sauvegarder et republier

**Tables de faits trop larges :**
1. Creer une vue SQL avec seulement les colonnes utilisees dans les visuels
2. Pointer la partition vers cette vue au lieu de la table complete

**Agregations :**
1. Creer une table Import avec les KPI pre-calcules (sommes, moyennes par jour/mois)
2. Configurer les agregations dans Power BI Desktop (Manage Aggregations)
3. Fabric routera automatiquement les requetes simples vers la table Import

### R3 — Refresh en heures de pointe

1. Admin Portal > Datasets > selectionner le dataset
2. Settings > Scheduled refresh
3. Deplacer les refresh entre 00h00 et 06h00
4. Si le dataset doit etre frais le matin, planifier a 05h00

### R4 — Source de donnees lente

1. Tester la requete source directement (BigQuery Console, SQL Server Management Studio)
2. Verifier les index, partitionnement, filtres
3. Si c'est un DQ chaine vers un autre modele AS : optimiser le modele source

### R5 — Modele corrompu

1. Admin Portal > Datasets > Refresh now (Full refresh)
2. Si echec : verifier les credentials (R6)
3. Si echec persiste : re-publier le .pbix depuis Power BI Desktop

### R6 — Credentials expirees

1. Admin Portal > Datasets > Settings > Data source credentials
2. Cliquer "Edit credentials" pour chaque source
3. Se reauthentifier
4. Relancer le refresh

### R7 — Capacite pausee

1. Admin Portal > Capacities > selectionner la capacite
2. Verifier le statut (Active / Paused)
3. Si Paused : cliquer Resume (attention au cout)

### R8 — Timeout de refresh

1. Verifier la taille des donnees source
2. Activer le refresh incremental :
   - Power BI Desktop > Table properties > Incremental refresh
   - Definir la periode incrementale (ex: 30 derniers jours en refresh, reste archive)
3. Optimiser les requetes M/Power Query (eliminer les transformations lourdes)

### R9 — Memoire insuffisante

1. Verifier la taille des datasets en memoire (Admin Portal > Capacity Metrics > Memory)
2. Identifier les datasets les plus volumineux
3. Options : compresser les colonnes, reduire la cardinalite, passer en DirectQuery pour les tables volumineuses

### R10 — Trop de modeles DQ sur la capacite

1. Lister tous les datasets avec leur mode (Admin Portal ou Monitoring Hub)
2. Prioriser la migration des plus petits modeles en Import
3. Regrouper les modeles DQ sur des capacites dediees

### R11 — Trop d'utilisateurs simultanes

1. Monitoring Hub > Concurrent users par dataset
2. Si un rapport a > 50 users simultanes : envisager un cache ou paginated report
3. Utiliser Power BI Apps pour distribuer les rapports (meilleur cache)

### R12 — SKU sous-dimensionne

1. Calculer le CU moyen necessaire sur 30 jours
2. Comparer avec le SKU actuel
3. Si CU moyen > 70% du SKU : demander un upgrade via IT Platform
4. Alternative : activer l'autoscale Fabric (F SKU uniquement)

---

## 4. Requetes KQL utiles

### Alertes en temps reel

```kql
// Requetes en echec sur la derniere heure
SemanticModelLogs
| where Timestamp > ago(1h)
| where OperationName == "QueryEnd"
| where Status == "Failure"
| project Timestamp, ItemName, WorkspaceName, ExecutingUser, DurationMs, StatusCode
| order by Timestamp desc
```

### Tendances

```kql
// Evolution CU par heure sur 24h
SemanticModelLogs
| where Timestamp > ago(24h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize TotalCpuMs = sum(CpuTimeMs) by bin(Timestamp, 1h)
| order by Timestamp asc
```

### Detection de modeles problematiques

```kql
// Datasets avec taux d'echec > 10% sur 24h
SemanticModelLogs
| where Timestamp > ago(24h)
| where OperationName == "QueryEnd"
| summarize
    Total = count(),
    Failed = countif(Status == "Failure")
    by ItemName, CapacityId
| extend FailRate = round(100.0 * Failed / Total, 1)
| where FailRate > 10
| order by FailRate desc
```

---

## 5. Checklist de prevention

A executer **avant** chaque mise en production d'un nouveau rapport/dataset :

- [ ] Le modele a ete teste avec Performance Analyzer
- [ ] Les dimensions sont en Import ou Dual (pas DirectQuery)
- [ ] Les tables de faits DQ ont < 50 colonnes utiles
- [ ] Le nombre de mesures est < 200
- [ ] Les refresh sont planifies hors heures de pointe
- [ ] La capacite cible a une marge CU > 20%
- [ ] Le modele n'utilise pas de cross-filter bidirectionnel non-necessaire
- [ ] Un stress test a ete realise si > 50 utilisateurs attendus
