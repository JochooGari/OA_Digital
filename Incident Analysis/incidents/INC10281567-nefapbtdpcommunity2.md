# INC10281567 — Surcharge capacite nefapbtdpcommunity2

## Informations generales

| Champ | Valeur |
|-------|--------|
| **ID Incident** | INC10281567 |
| **Date de detection** | 2026-03-12 17:12 |
| **Signale par** | BUREL Matthieu (OA Analytics Services) |
| **Capacite impactee** | nefapbtdpcommunity2 |
| **Workspace(s) impacte(s)** | Tous les workspaces sur cette capacite, dont [Supply Chain] - WW - Service Level - PROD, GLOBAL - CPD CDMO |
| **Severite** | **CRITIQUE** |
| **Statut** | EN COURS |
| **Date de resolution** | - |
| **Duree totale incident** | En cours |
| **Responsable COE** | Mohamed MMADI |

## Description de l'incident

Le 12 mars 2026 a 17h12, Matthieu BUREL a signale via Teams un incident Power BI / Fabric
sur la capacite `nefapbtdpcommunity2`. L'incident affecte **tous les projets heberges** sur
cette capacite, causant des echecs de chargement de rapports et des performances degradees.

Message officiel :
> "We are currently facing an PowerBI / Fabric capacity incident related to
> nefapbtdpcommunity2, and affecting all projects hosted in it, starting this afternoon.
> The issue is causing report loading failures and slow performances."

## Impact utilisateur

| Metrique | Valeur observee | Valeur normale |
|----------|----------------|----------------|
| % of Base Capacity | **209,63%** | < 80% |
| Taux d'echec requetes | **~89%** (8 Failure / 1 Success) | < 5% |
| Throttling moyen (s) | **20s** par requete | 0s |
| Duration requetes (s) | **225-230s** | < 30s |
| Total CU (s) | 160 996 | Variable |
| Timepoint CU (s) | 16 099 | Variable |
| Nb utilisateurs impactes | 3+ (elisa.fievet, samir.kicha, abdallah.sellami) | |
| Billing type | Billable | |

## Chronologie

| Heure | Evenement |
|-------|-----------|
| ~15:00 | Debut probable de la surcharge (a confirmer via Monitoring Hub) |
| 17:12 | Signalement par Matthieu BUREL sur Teams |
| 17:30 | Investigation COE : audit MCP du modele A&I |
| 17:45 | Cause racine identifiee : modele 100% DirectQuery chaine |
| - | En attente d'actions correctives |

## Diagnostic

### Methode d'investigation

- [ ] Fabric Monitoring Hub (KQL)
- [ ] Admin Portal > Capacity Metrics
- [ ] BigQuery `capacity_unit_timepoint_v2`
- [x] **Audit MCP Power BI** (modele semantique A&I)
- [x] **Audit MCP Power BI** (modele V2 - Service Level Dashboard)
- [x] **Analyse requete DAX** (Dax KBL eventText.sql — requete la plus longue)
- [ ] Logs Cloud Run / Cloud Logging

### Cause racine

Le modele **A&I** (et potentiellement d'autres modeles sur cette capacite) est configure
en **DirectQuery chaine** vers un modele Analysis Services. Ce pattern est extremement
gourmand en CU car :

1. **Chaque interaction utilisateur** (clic, filtre, navigation) genere des requetes DAX
2. Ces requetes sont **traduites et envoyees** au modele AS backend (`itg_dc360_advocated_c2_v4`)
3. Le modele AS backend execute les requetes et renvoie les resultats
4. **Double consommation CU** : la capacite Fabric + le backend AS

Avec 3+ utilisateurs simultanement actifs, le cumul des requetes depasse la capacite
de base (209%) et declenche le **throttling Fabric** :
- Chaque requete recoit 20s de penalite
- Les requetes depassent le timeout (225s)
- Status = Failure
- Les utilisateurs relancent -> **effet boule de neige**

### Modele(s) audite(s)

| Modele | Workspace | Mode | Tables | Mesures | Probleme |
|--------|-----------|------|--------|---------|----------|
| **A&I** | GLOBAL - CPD CDMO | **DirectQuery chaine** | 56 (53 DQ) | 260+ | 95% des tables en DQ vers AS, tables a 159 colonnes, aucune agregation |
| **V2 - Service Level Dashboard** | [Supply Chain] - WW - Service Level - PROD | **DirectQuery BigQuery** | 30 (4 DQ, 1 Dual, 25 Import) | 194 | Table principale a 190 colonnes en DQ, visuel "Raw data" generant des requetes massives |

### Detail des tables critiques (A&I)

| Table | Colonnes | Mode | Source DQ |
|-------|----------|------|-----------|
| `fact_traackr_irm_post_level` | **159** | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `fact_traackr_irm` | **148** | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `Indicators_influencer` | **120** | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `Indicators` | **119** | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `fact_traackr_irm_campaign_setup` | 37 | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `fact_traackr_mim_detail_data` | 35 | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `fact_compass` | 32 | DirectQuery | AS itg_dc360_advocated_c2_v4 |
| `Spend Media` | 19 | DirectQuery | AS A&I Spend Compass |
| `Spend Advocacy Media` | 19 | DirectQuery | AS A&I Spend Compass |

### Tables en Import (seulement 3)

| Table | Type | Raison |
|-------|------|--------|
| `Dim_TiersOrder` | Import (M query) | Petite table de tri |
| `Dim_L4Order` | Import (M query) | Petite table de tri |
| `Spend Media L3 Parameter` | Import (Calculated) | Table de parametres DAX |

### Configuration du modele

- `defaultMode` : Import (trompeusement — les partitions individuelles overrident en DQ)
- `sourceQueryCulture` : fr-FR
- `dataSourceDefaultMaxConnections` : 20
- 2 sources DirectQuery :
  - `DirectQuery to AS - itg_dc360_advocated_c2_v4` (53 tables)
  - `DirectQuery a AS - A&I Spend Compass Semantic Model` (2 tables)

## Actions correctives

### Immediates (jour J)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1 | Identifier tous les modeles DQ sur nefapbtdpcommunity2 | Mohamed | [ ] |
| 2 | Suspendre les refresh planifies aux heures de pointe | Mohamed / Matthieu | [ ] |
| 3 | Communiquer aux utilisateurs impactes (eviter de relancer) | Matthieu | [x] (Teams) |
| 4 | Verifier si d'autres capacites ont de la marge pour deplacer des workspaces | Mohamed | [ ] |

### Moyen terme (semaine prochaine)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1 | Migrer les dimensions en mode Dual (country, Platform, Brands, Dim_date, Period, Dim_currency) | Proprietaire modele A&I | [ ] |
| 2 | Ajouter des tables d'agregation pour les mesures SOE, SOI, SOV, CPE, CPV | Proprietaire modele A&I | [ ] |
| 3 | Mettre en place alerte CU > 80% via Fabric Monitoring | Mohamed | [ ] |
| 4 | Auditer les autres modeles DQ sur la capacite | Mohamed | [ ] |

### Long terme (mois suivant)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1 | Evaluer l'activation de l'autoscale Fabric | Matthieu / IT Platform | [ ] |
| 2 | Creer un dashboard de monitoring capacite COE | Mohamed | [ ] |
| 3 | Instituer une revue trimestrielle des modeles sur capacites critiques | COE | [ ] |
| 4 | Publier le Troubleshooting Guide sur Confluence | Mohamed | [ ] |

## Post-mortem

### Ce qui a bien fonctionne

- Detection rapide par Matthieu (communication Teams immediate)
- Audit MCP du modele semantique a permis d'identifier la cause racine rapidement
- Les skills BTDP ont fourni le contexte necessaire (naming, monitoring, alertes)

### Ce qui doit etre ameliore

- Pas d'alerte proactive sur le CU — l'incident a ete detecte par les utilisateurs
- Pas de visibilite en temps reel sur la consommation CU par capacite
- Les modeles DirectQuery chaines ne sont pas revus systematiquement

### Actions preventives a mettre en place

| Action | Priorite | Ref |
|--------|----------|-----|
| Alerte CU > 80% | HAUTE | Best Practices §3 |
| Dashboard monitoring capacite | HAUTE | Plan 002 |
| Revue modeles DQ sur capacites critiques | MOYENNE | Best Practices §5 |
| Documentation pattern DQ chaine et limites | MOYENNE | Troubleshooting Guide |

---

## Audit MCP — V2 - Service Level Dashboard

> Audit realise le 2026-03-13 via MCP Power BI (connexion Power BI Desktop locale).
> Workspace : `[Supply Chain] - WW - Service Level - PROD`
> Modele : `V2 - Service Level Dashboard`

### Configuration du modele

- `defaultMode` : Import
- `culture` : en-US
- `sourceQueryCulture` : en-US
- `dataSourceDefaultMaxConnections` : 100
- Source de donnees : **Google BigQuery** (DirectQuery)

### Vue d'ensemble des tables (30 tables)

| Table | Colonnes | Mesures | Mode | Source BigQuery |
|-------|----------|---------|------|----------------|
| **kpi_servicelevel** | **190** | **194** | **DirectQuery** | `auth_dgo_servicelevel_v1_unsecured` |
| **DataMont** | 30 | 3 | **DirectQuery** | `auth_dgo_servicelevel_monitor_v1_unsecured` |
| **DataQuality** | 41 | 12 | **DirectQuery** | `auth_dgo_servicelevel_quality_v1_unsecured` |
| **tech_dgo_servicelevel_snapshot_timeline_v1** | 7 | 4 | **DirectQuery** | `tech_dgo_servicelevel_snapshot_timeline_v1` |
| servicelevel_pbi_filter_v1 | 13 | 0 | **Dual** | `dgo_servicelevel_pbi_filter_v1` |
| 00_Dates | 14 | 4 | Import | Calculated (DAX CALENDAR) |
| Date 1 | 12 | 5 | Import | Calculated |
| 00_Dates_Mon | 10 | 0 | Import | Calculated |
| currency_switch | 1 | 1 | Import | Calculated |
| units_switch | 1 | 1 | Import | Calculated |
| imported_local | 1 | 1 | Import | Calculated |
| Raw data | 3 | 1 | Import | Calculated |
| BOM_Selection | 1 | 1 | Import | Calculated |
| TopNParameter | 1 | 1 | Import | Calculated |
| Options | 3 | 1 | Import | Calculated |
| Hero | 2 | 0 | Import | Calculated |
| Parameter / Parameter1 / WeeklyParameter | 3-4 | 0 | Import | Calculated |
| YTD Parameter | 3 | 0 | Import | Calculated |
| Measure Selection | 3 | 0 | Import | Calculated |
| Selections | 3 | 0 | Import | Calculated |
| RootCauseParameter | 4 | 0 | Import | Calculated |
| Description & EAN | 4 | 0 | Import | Calculated |
| DescEAN | 3 | 0 | Import | Calculated |
| Glossary | 2 | 0 | Import | Calculated |
| timestramp / Timestamp 2 | 1 | 0 | Import | Calculated |
| bkp_tech_dgo_servicelevel_v1_26052025 | 2 | 0 | Import | Calculated |

### Problemes identifies

#### 1. Table `kpi_servicelevel` : 190 colonnes + 194 mesures en DirectQuery

C'est la table de faits principale du modele. Avec **190 colonnes**, chaque requete DAX
genere un `SELECT` massif vers BigQuery. C'est la table la plus problematique de tout
le modele.

La requete M (Power Query) source pointe vers la vue BigQuery `auth_dgo_servicelevel_v1_unsecured`
et applique :
- 80+ renommages de colonnes (`Table.RenameColumns`)
- 3 filtres (`Plant code <> "404A"`, `<> "404B"`, `Material code` ne commence pas par "PP")
- 3 remplacements de texte sur la colonne `Currency`

#### 2. Visuel "Raw data" — Requete DAX la plus couteuse

La requete DAX capturee (fichier `Dax KBL eventText.sql`) provient d'un visuel **"Raw data"**
(export detail). Ce visuel genere la requete la plus couteuse possible :

- **42 colonnes** demandees simultanement depuis `kpi_servicelevel`
- **18 mesures** calculees pour chaque ligne
- **Double `SUMMARIZECOLUMNS`** : une passe pour filtrer (`Show_Table_Data = 1`),
  une passe pour le resultat final
- **`ROLLUPADDISSUBTOTAL`** : calcul du grand total en plus des lignes detail
- **`TOPN 502`** : limite Power BI, mais le moteur scanne tout avant de tronquer
- Filtres : `YearMonth = "Sep 2025"`, `Currency = "Euro"`

Un seul utilisateur ouvrant cette page genere une charge equivalente a ~50 requetes normales.

#### 3. Tables secondaires en DirectQuery

- `DataMont` (30 colonnes) : monitoring → pourrait passer en Import
- `DataQuality` (41 colonnes) : qualite des donnees → pourrait passer en Import
- `tech_dgo_servicelevel_snapshot_timeline_v1` (7 colonnes) : petite table, impact faible

#### 4. Seule 1 table de filtre en Dual

`servicelevel_pbi_filter_v1` (13 colonnes) est la seule table correctement configuree en **Dual**.
Les tables de dates (`00_Dates`) sont en Import pur — elles devraient etre en Dual pour
optimiser les jointures avec la table de faits DQ.

### Recommandations

| # | Action | Impact estime | Priorite |
|---|--------|---------------|----------|
| 1 | **Reduire les colonnes de `kpi_servicelevel`** : creer une vue BigQuery avec seulement les ~50 colonnes utilisees dans les visuels (sur 190 actuelles) | -70% colonnes DQ | HAUTE |
| 2 | **Desactiver ou restreindre le visuel "Raw data"** : remplacer par un bouton "Export to Excel" via paginated report | Supprime la requete la plus couteuse | HAUTE |
| 3 | **Passer `00_Dates` en mode Dual** pour optimiser les jointures date/table DQ | Optimisation jointures | MOYENNE |
| 4 | **Creer des tables d'agregation Import** pour les KPI principaux (Service Level %, qty processed, value invoiced) par mois/division/zone | -80% requetes DQ pour les pages principales | HAUTE |
| 5 | **Evaluer le passage de `DataMont` et `DataQuality` en Import** avec refresh planifie la nuit | Moins de DQ sur la capacite | MOYENNE |
| 6 | **Limiter les mesures visibles** : 194 mesures sur une seule table, regrouper par page/onglet | Moins de mesures evaluees par page | BASSE |

---

## Pieces jointes

- [x] Screenshots metriques capacite (conversation Teams Matthieu)
- [x] Audit MCP modele A&I (section Diagnostic)
- [x] Audit MCP modele V2 - Service Level Dashboard (section ci-dessus)
- [x] Requete DAX capturee (`Dax KBL eventText.sql`)
- [ ] Export KQL Monitoring Hub (a faire)
- [ ] Capture Admin Portal Capacity Metrics (a faire)

