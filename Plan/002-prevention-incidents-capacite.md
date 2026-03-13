# Plan : Prevention des incidents de capacite Fabric

- **TODO associe** : [../TODO/001-incident-nefapbtdpcommunity2.md](../TODO/001-incident-nefapbtdpcommunity2.md)
- **Statut** : Analyse terminee, actions a valider

---

## Probleme

La capacite `nefapbtdpcommunity2` a atteint 209% de sa base capacity le 12/03/2026.
Cause : modeles en DirectQuery chaine avec 260+ mesures et tables a 159 colonnes.

## Diagnostic detaille (audit MCP du modele A&I)

| Constat | Detail | Severite |
|---------|--------|----------|
| 53/56 tables en DirectQuery | Vers AS `itg_dc360_advocated_c2_v4` | CRITIQUE |
| Chainage DQ | Ce modele pointe vers un autre modele AS | CRITIQUE |
| 260+ mesures DAX | Evaluees a chaque interaction utilisateur | HAUTE |
| Tables massives | `fact_traackr_irm_post_level` (159 col), `fact_traackr_irm` (148 col) | HAUTE |
| Pas d'agregations | Aucune table d'agregation detectee | HAUTE |
| Dimensions en DQ | Meme les petites dimensions (country, Platform) sont en DQ | MOYENNE |

## Pistes de solutions

### Court terme (1-2 jours)

1. **Suspendre les refresh non-critiques** sur la capacite
   - Admin Portal > Capacities > nefapbtdpcommunity2 > Settings
   - Identifier les datasets avec refresh planifie durant les heures de pointe

2. **Contacter les proprietaires des rapports** pour limiter l'usage concurrent
   - elisa.fievet, samir.kicha, abdallah.sellami (utilisateurs en echec)

3. **Deplacer des workspaces** non-critiques vers une autre capacite disponible

### Moyen terme (1-2 semaines)

4. **Migrer les dimensions en mode Dual (Import + DirectQuery)**
   - Tables candidates : `country` (6 col), `Platform` (6 col), `Brands` (8 col),
     `Dim_date` (19 col), `Period` (18 col), `Dim_currency` (3 col)
   - Impact : reduit drastiquement le nombre de requetes DQ pour les filtres/slicers
   - Risque : faible (tables petites, refresh rapide)

5. **Ajouter des tables d'agregation**
   - Pre-calculer les mesures les plus utilisees (SOE, SOI, SOV, CPE, CPV)
   - Stocker en Import avec refresh planifie
   - Fabric/Power BI routera automatiquement les requetes vers les agregations

6. **Mettre en place des alertes proactives**
   - Fabric Monitoring Hub : alerte si CU > 80% pendant 5 min
   - Email via BTDP Notification Service (voir skill btdp-framework)
   - BigQuery : monitorer `capacity_unit_timepoint_v2` (delai 24h)

### Long terme (1-3 mois)

7. **Configurer l'autoscale Fabric**
   - Si SKU F, activer le burst/autoscale pour absorber les pics
   - Cout supplementaire mais evite les incidents

8. **Revue trimestrielle des modeles**
   - Auditer tous les modeles DQ sur les capacites critiques
   - Identifier les candidats a la migration Import/Dual
   - Utiliser le MCP Power BI pour automatiser l'audit

9. **Load testing preventif**
   - Utiliser l'outil de stress test (Orchestrator.ps1) avant toute mise en prod
   - Valider que la capacite tient la charge prevue

10. **Dashboard de monitoring capacite COE**
    - Creer un rapport Power BI dedie au suivi CU / throttling / echecs
    - Source : BigQuery `capacity_unit_timepoint_v2` + Fabric Monitoring Hub
    - Audience : equipe COE + IT Platform

## Metriques de succes

| Metrique | Objectif | Actuel |
|----------|----------|--------|
| % Base Capacity (pic) | < 80% | 209% |
| Taux d'echec requetes | < 5% | 89% |
| Throttling moyen | 0s | 20s |
| Duration requetes | < 30s | 225s |
