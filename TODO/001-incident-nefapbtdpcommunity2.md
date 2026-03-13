# INC10281567 — Incident capacite nefapbtdpcommunity2

- **Date** : 2026-03-12 17:12
- **Signale par** : BUREL Matthieu (Analytics Services)
- **Capacite** : nefapbtdpcommunity2
- **Impact** : Report loading failures + slow performances sur tous les projets
- **Statut** : EN COURS
- **Plan associe** : [../Plan/002-prevention-incidents-capacite.md](../Plan/002-prevention-incidents-capacite.md)

---

## Metriques observees

| Metrique | Valeur | Seuil critique |
|----------|--------|---------------|
| % of Base Capacity | **209,63%** | >100% = throttling |
| Total CU (s) | 160 996 | - |
| Timepoint CU (s) | 16 099 | - |
| Throttling (s) | 20 860 | 0 = normal |
| Taux d'echec | ~89% (8 Failure / 1 Success) | 0% = normal |
| Duration requetes | 225-230s | <30s = acceptable |
| Utilisateurs impactes | elisa.fievet, samir.kicha, abdallah.sellami | - |

## Cause racine identifiee (audit MCP)

Modele **A&I** (workspace GLOBAL - CPD CDMO) :
- **53/56 tables en DirectQuery** vers AS `itg_dc360_advocated_c2_v4`
- **260+ mesures DAX** evaluees a chaque requete
- Tables massives : `fact_traackr_irm_post_level` (159 colonnes), `fact_traackr_irm` (148 col)
- **Chainage DirectQuery** : ce modele pointe vers un autre modele AS = double charge
- Plusieurs utilisateurs simultanes = cascade de CU

## Actions immediates

- [ ] Identifier les refresh planifies sur la capacite et les suspendre temporairement
- [ ] Contacter les proprietaires des rapports les plus consommateurs
- [ ] Verifier s'il y a d'autres modeles DQ sur cette capacite
- [ ] Envisager un deplacement temporaire de workspaces non-critiques

## Actions moyen terme

- [ ] Migrer les tables de dimension en mode **Dual** (Import + DQ) — voir Plan 002
- [ ] Ajouter des tables d'agregation pour les mesures les plus utilisees
- [ ] Mettre en place des alertes CU > 80%
- [ ] Planifier les refresh hors heures de pointe

## Suivi

| Date | Action | Resultat |
|------|--------|---------|
| 2026-03-12 | Audit MCP du modele A&I | 53/56 tables DQ, 260+ mesures, cause identifiee |
| | | |
