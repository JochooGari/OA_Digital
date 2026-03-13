# INC[NUMERO] — [Titre court de l'incident]

## Informations generales

| Champ | Valeur |
|-------|--------|
| **ID Incident** | INC__________ |
| **Date de detection** | YYYY-MM-DD HH:MM |
| **Signale par** | Nom (equipe) |
| **Capacite impactee** | nom_capacite |
| **Workspace(s) impacte(s)** | |
| **Severite** | CRITIQUE / HAUTE / MOYENNE / BASSE |
| **Statut** | OUVERT / EN COURS / RESOLU / CLOS |
| **Date de resolution** | |
| **Duree totale incident** | |
| **Responsable COE** | |

## Description de l'incident

> Description factuelle : quoi, quand, qui est impacte, quel message d'erreur.

## Impact utilisateur

| Metrique | Valeur observee | Valeur normale |
|----------|----------------|----------------|
| % of Base Capacity | | < 80% |
| Taux d'echec requetes | | < 5% |
| Throttling moyen (s) | | 0s |
| Duration requetes (s) | | < 30s |
| Nb utilisateurs impactes | | |
| Nb workspaces impactes | | |

## Chronologie

| Heure | Evenement |
|-------|-----------|
| HH:MM | Premier signalement |
| HH:MM | Debut d'investigation |
| HH:MM | Cause identifiee |
| HH:MM | Action corrective appliquee |
| HH:MM | Retour a la normale |

## Diagnostic

### Methode d'investigation

- [ ] Fabric Monitoring Hub (KQL)
- [ ] Admin Portal > Capacity Metrics
- [ ] BigQuery `capacity_unit_timepoint_v2`
- [ ] Audit MCP Power BI (modele semantique)
- [ ] Logs Cloud Run / Cloud Logging

### Cause racine

> Description technique detaillee de la cause.

### Modele(s) / Dataset(s) implique(s)

| Modele | Workspace | Mode | Tables | Mesures | Probleme |
|--------|-----------|------|--------|---------|----------|
| | | Import/DQ/Dual | | | |

## Actions correctives

### Immediates (jour J)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1 | | | [ ] |
| 2 | | | [ ] |

### Moyen terme (semaine suivante)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1 | | | [ ] |
| 2 | | | [ ] |

## Post-mortem

### Ce qui a bien fonctionne

-

### Ce qui doit etre ameliore

-

### Actions preventives a mettre en place

| Action | Priorite | Ticket/Ref |
|--------|----------|------------|
| | | |

## Pieces jointes

- [ ] Screenshots des metriques
- [ ] Export KQL Monitoring Hub
- [ ] Rapport d'audit MCP
