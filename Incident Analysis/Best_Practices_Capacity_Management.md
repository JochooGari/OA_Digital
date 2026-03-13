# Best Practices — Fabric / Power BI Capacity Management

> Document a publier sur Confluence (espace BTDP ou COE Power BI).
> Maintenu par l'equipe COE Power BI.
> Derniere mise a jour : 2026-03-12

---

## 1. Comprendre le modele de capacite Fabric

### SKU et Capacity Units (CU)

Fabric utilise un systeme de **Capacity Units (CU)** pour mesurer la consommation de ressources.
Chaque SKU Fabric (F2, F4, F8, F16, F32, F64, F128...) dispose d'un nombre fixe de CU par seconde.

| SKU | CU/s | CU/30s (base) | Cas d'usage |
|-----|------|--------------|-------------|
| F2 | 2 | 60 | POC, dev |
| F4 | 4 | 120 | Petites equipes |
| F8 | 8 | 240 | Equipes moyennes |
| F16 | 16 | 480 | Equipes larges |
| F32 | 32 | 960 | Departements |
| F64 | 64 | 1920 | Large scale |

### Comment fonctionne le throttling

1. Fabric mesure la consommation CU sur des fenetres de **30 secondes**
2. Si la consommation depasse **100% de la base capacity** → Fabric commence a **ralentir** les requetes (throttling)
3. A **200%+** → les requetes sont **rejetees** (Failure)
4. Le throttling est **cumulatif** — une surcharge a un instant T impacte les 30 secondes suivantes

### Seuils critiques

| % Base Capacity | Comportement |
|----------------|-------------|
| 0-80% | Normal — aucun impact |
| 80-100% | Zone d'attention — proche des limites |
| 100-120% | Throttling leger — requetes ralenties |
| 120-200% | Throttling severe — timeouts frequents |
| 200%+ | **Rejection** — requetes en echec |

---

## 2. Regles de conception des modeles semantiques

### DirectQuery vs Import vs Dual — Quand utiliser quoi

| Mode | Quand l'utiliser | CU Impact | Latence |
|------|-----------------|-----------|---------|
| **Import** | Donnees < 1 Go, refresh tolerable (1-4x/jour) | Faible (seulement au refresh) | Excellent (<1s) |
| **DirectQuery** | Donnees temps reel obligatoire, volume enorme | **Eleve** (chaque interaction) | Variable (1-30s) |
| **Dual** | Dimensions utilisees dans des slicers/filtres | Faible pour les filtres | Excellent pour les filtres |
| **Direct Lake** | Donnees dans OneLake, volume moyen-large | Moyen | Bon (1-5s) |

### Regles d'or

1. **Jamais de DirectQuery sur les tables de dimension**
   - Les dimensions (`Dim_date`, `country`, `Platform`, `Brands`) doivent etre en **Dual** ou **Import**
   - Raison : les slicers et filtres generent des requetes DQ a chaque interaction
   - Impact : reduit ~30-50% des requetes DQ

2. **Limiter le DirectQuery chaine**
   - Un modele DQ vers un autre modele AS/Fabric = **double consommation CU**
   - Chaque requete traverse 2 moteurs → latence et CU multipliees
   - Preferer : Import/Direct Lake quand possible, ou Dual pour les dimensions

3. **Limiter le nombre de colonnes par table**
   - Objectif : < 50 colonnes par table de faits en DirectQuery
   - Tables a 100+ colonnes = requetes massives meme pour un seul visuel
   - Solution : creer des vues SQL avec seulement les colonnes necessaires

4. **Limiter le nombre de mesures complexes**
   - Chaque mesure visible sur une page = une requete DQ
   - Regrouper les mesures par page/onglet
   - Eviter les mesures imbriquees (mesure qui appelle 5 autres mesures)

5. **Utiliser des agregations**
   - Pre-calculer les mesures les plus requetees (KPI principaux)
   - Stocker en Import, Fabric routera automatiquement
   - Gain : 10-100x moins de CU pour les requetes courantes

---

## 3. Monitoring et alertes

### Indicateurs a surveiller

| Indicateur | Source | Seuil d'alerte | Seuil critique |
|-----------|--------|----------------|----------------|
| % Base Capacity | Admin Portal / Monitoring Hub | > 80% | > 100% |
| Throttling (s) | Capacity Metrics | > 0s | > 10s |
| Query Failure Rate | Monitoring Hub | > 5% | > 20% |
| Query Duration (p95) | Monitoring Hub | > 30s | > 120s |
| Nb concurrent users/capacity | Monitoring Hub | > 50 | > 100 |

### Outils de monitoring

| Outil | Acces | Latence | Usage |
|-------|-------|---------|-------|
| **Fabric Monitoring Hub** | app.fabric.microsoft.com | Temps reel | KQL queries, alertes |
| **Admin Portal > Capacity Metrics** | app.powerbi.com/admin | ~5 min | Vue capacite globale |
| **BigQuery `capacity_unit_timepoint_v2`** | GCP Console | 24h | Historique, tendances |
| **V2 - Service Level Dashboard** | Power BI | Variable | Vue metier |
| **MCP Power BI** | Claude Code / VS Code | Temps reel | Audit modele semantique |

### Requete KQL — Monitoring Hub

```kql
// Top 10 requetes les plus gourmandes en CU sur les dernieres 24h
SemanticModelLogs
| where Timestamp > ago(24h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| extend DurationSec = DurationMs / 1000.0
| extend CpuTimeSec = CpuTimeMs / 1000.0
| project Timestamp, ItemName, WorkspaceName, ExecutingUser, DurationSec, CpuTimeSec, Status
| order by CpuTimeSec desc
| take 10
```

```kql
// Taux d'echec par dataset sur la derniere heure
SemanticModelLogs
| where Timestamp > ago(1h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    TotalQueries = count(),
    FailedQueries = countif(Status == "Failure"),
    AvgDuration = avg(DurationMs),
    MaxCpuTime = max(CpuTimeMs)
    by ItemName
| extend FailureRate = round(100.0 * FailedQueries / TotalQueries, 1)
| order by FailureRate desc
```

### Mettre en place des alertes

**Option 1 : Fabric Data Activator (recommande)**
- Creer un reflexe Data Activator sur le Monitoring Hub
- Condition : CU > 80% pendant 5 minutes
- Action : envoyer un email a l'equipe COE

**Option 2 : BTDP Notification Service**
- Cloud Scheduler GCP → script Python → requete BigQuery → si CU > seuil → BTDP Notification API
- Avantage : integre dans l'ecosysteme BTDP
- Inconvenient : delai 24h (donnees BigQuery)

---

## 4. Gestion des refresh

### Planning des refresh

| Periode | Recommandation |
|---------|---------------|
| 00h00 - 06h00 | **Fenetre de refresh privilegiee** — peu d'utilisateurs |
| 06h00 - 09h00 | Eviter les gros refresh — pic de connexion matinal |
| 09h00 - 12h00 | **Heures de pointe** — pas de refresh > 5 min |
| 12h00 - 14h00 | Creux — refresh moyen acceptable |
| 14h00 - 18h00 | **Heures de pointe** — pas de refresh > 5 min |
| 18h00 - 00h00 | Fenetre de refresh acceptable |

### Regles

1. Les datasets **Import** volumineux (> 1 Go) doivent etre refresh entre 00h et 06h
2. Eviter de planifier plusieurs refresh simultanement sur la meme capacite
3. Utiliser le **refresh incremental** quand possible (tables de faits avec date)
4. Monitorer la duree des refresh — un refresh qui s'allonge = signe de degradation

---

## 5. Revue periodique des modeles

### Frequence

- **Trimestrielle** pour les capacites critiques (production, community)
- **Semestrielle** pour les capacites de developpement

### Checklist de revue

- [ ] Lister tous les datasets sur la capacite
- [ ] Pour chaque dataset, verifier le mode (Import / DQ / Dual / Direct Lake)
- [ ] Identifier les modeles DirectQuery chaines
- [ ] Verifier le nombre de colonnes par table de faits (< 50 recommande)
- [ ] Verifier le nombre de mesures (< 200 recommande)
- [ ] Verifier que les dimensions sont en Dual ou Import
- [ ] Verifier la presence d'agregations pour les KPI principaux
- [ ] Verifier le planning de refresh (pas de conflit en heures de pointe)
- [ ] Verifier le taux d'echec moyen sur les 30 derniers jours

### Outil d'audit automatise

L'audit peut etre realise via le **MCP Power BI** (Claude Code) :

```
1. Se connecter au modele :
   ConnectFabric → workspace + semantic model

2. Lister les tables et leurs modes :
   partition_operations → List → verifier "mode" de chaque partition

3. Compter les colonnes par table :
   table_operations → List → verifier "columnCount"

4. Lister les mesures :
   measure_operations → List → compter et verifier la complexite

5. Verifier les relations :
   relationship_operations → List → identifier les cross-filter bidirectionnels
```

---

## 6. Patterns a eviter

| Anti-pattern | Risque | Alternative |
|-------------|--------|-------------|
| **DQ chaine** (DQ → autre modele AS/Fabric) | Double CU, latence x2 | Import/Direct Lake, ou Dual dimensions |
| **Dimensions en DirectQuery** | Requete DQ a chaque clic de slicer | Passer en Dual |
| **Tables de faits > 100 colonnes en DQ** | Requetes massives | Vue SQL avec colonnes necessaires |
| **260+ mesures sans agregation** | CU eleve par page | Agregations, regroupement par page |
| **Cross-filter bidirectionnel** | Multiplie les requetes | Unidirectionnel sauf necessaire |
| **Refresh aux heures de pointe** | Consomme des CU pendant l'usage | Planifier la nuit |
| **Pas de monitoring** | Incident detecte trop tard | Alertes CU > 80% |
| **Modele "fourre-tout"** | Trop de tables/mesures, lent | Decouper en sous-modeles |

---

## 7. Contacts et escalade

| Niveau | Contact | Quand |
|--------|---------|-------|
| COE Power BI | powerbi.coe@loreal.com | Premier niveau, monitoring |
| OA Analytics Services | Matthieu BUREL | Capacites, workspaces, infrastructure |
| BTDP Support | IT-GLOBAL-GCP-BTDP_DATAENG_L3 | Supervision, BigQuery, alertes |
| Microsoft Support | Via portail admin Power BI | Incidents plateforme, bugs |
