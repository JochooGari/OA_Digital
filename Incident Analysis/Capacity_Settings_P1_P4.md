# Preconisations Capacite Power BI — P1 a P4

> Document a publier sur Confluence (espace COE Power BI).
> Maintenu par : Mohcine MMADI — Tenant Admin Power BI / Fabric
> Derniere mise a jour : 2026-03-16

---

## Contexte

Ce document regroupe les parametres recommandes et les preconisations du COE Power BI
pour les capacites Premium (P1 a P4) du tenant L'Oreal, suite aux analyses d'incidents
et aux audits de modeles semantiques realises en mars 2026.

Objectifs :
- Eviter la **surconsommation** de CUs (Capacity Units)
- Garantir la **disponibilite** pour l'ensemble des utilisateurs
- Prevenir le **throttling** et les incidents de capacite
- **Responsabiliser** les equipes proprietaires de rapports

---

## 1. Parametres de capacite recommandes

### Ressources par SKU

| SKU | vCores | RAM totale | CU/s | Usage typique |
|-----|--------|-----------|------|---------------|
| P1 | 8 | 25 Go | 8 | Equipes <= 100 utilisateurs |
| P2 | 16 | 50 Go | 16 | Equipes <= 300 utilisateurs |
| P3 | 32 | 100 Go | 32 | Departement / usage intensif |
| P4 | 64 | 200 Go | 64 | Large scale / usage critique |

### Tableau de configuration

| Parametre | P1 | P2 | P3 | P4 | Defaut |
|-----------|----|----|----|----|--------|
| **Delai d'expiration requete (s)** | 120 | 180 | 180 | 300 | 3600 |
| **Limite memoire de requete (%)** | 10 | 15 | 20 | 20 | 0 (illimite) |
| **Nb max lignes intermediaires** | 1 000 000 | 1 000 000 | 1 000 000 | 1 000 000 | 1 000 000 |
| **Auto-refresh page — intervalle min** | 15 min | 10 min | 10 min | 5 min | 5 min |
| **Detection des changements — intervalle min** | 5 min | 5 min | 2 min | 1 min | 30 s |
| **Requetes paralleles DirectQuery** | Active | Active | Active | Active | Active |
| **Point de terminaison XMLA** | Lecture seule* | Lecture/ecriture | Lecture/ecriture | Lecture/ecriture | Lecture seule |

> *Lecture/ecriture uniquement si les equipes utilisent des outils XMLA (Tabular Editor, ALM Toolkit...).

### Detail des parametres

#### Delai d'expiration de la requete

**Concerne** : requetes DAX interactives uniquement (rapports, dashboards, Q&A, XMLA).
**Ne concerne pas** : les actualisations (refresh) de datasets — celles-ci ont un timeout propre de 5h.

> La valeur par defaut de 3600s (1h) est beaucoup trop permissive.
> Une requete qui tourne 1h monopolise les ressources sans valeur pour l'utilisateur.

#### Limite de memoire de requete (%)

C'est le % de **RAM** maximum qu'**une seule requete DAX** peut allouer.

| SKU | RAM totale | 10% | 15% | 20% |
|-----|-----------|-----|-----|-----|
| P1 | 25 Go | 2,5 Go | 3,7 Go | 5 Go |
| P2 | 50 Go | 5 Go | 7,5 Go | 10 Go |
| P3 | 100 Go | 10 Go | 15 Go | 20 Go |
| P4 | 200 Go | 20 Go | 30 Go | 40 Go |

> La valeur **0** (par defaut) est illimitee — une requete peut saturer toute la RAM
> et bloquer les autres utilisateurs.

#### Detection des changements — Parametre critique

> C'est le parametre **le plus impactant** en termes de consommation continue.
> A 30s avec 10 utilisateurs sur un rapport = **20 requetes/min en permanence**.
> Sur P1, cela peut declencher du throttling meme en dehors des heures de pointe.

**Recommandation forte** : ne jamais descendre sous 2 minutes, meme sur P4.

---

## 2. Securite — Tables "Unsecured" et profils eleves

### Le connecteur AMAAS (OA Pass)

L'ancien connecteur BigQuery utilise un systeme de **Row-Level Security (RLS) cote GCP** via les vues `*_unsecured`. Le principe :

1. La vue BigQuery contient **toutes les donnees** (ex : 1 million de lignes × 300 utilisateurs = **300 millions de lignes**)
2. Le filtre se fait via une **jointure sur l'adresse e-mail** de l'utilisateur connecte (AMAAS)
3. Le resultat affiche uniquement le scope autorise pour cet utilisateur

### Le probleme

Lorsqu'un utilisateur dispose d'un **acces Membre ou Admin** sur l'espace de travail, **Power BI ne lui applique pas la securite RLS**. La consequence :

- Power BI tente de charger la **vue complete** (plusieurs millions de lignes) au lieu du scope filtre
- Une seule connexion d'un admin genere une charge equivalente a des centaines de requetes normales
- Cela provoque une surcharge immediate de la capacite, impactant **tous les espaces de travail** heberges sur cette capacite

### Recommandations d'acces

| Profil | Acces recommande | Justification |
|--------|-----------------|---------------|
| **Utilisateur final** (consultation) | **Viewer (Lecteur)** | Le RLS s'applique correctement, seul le scope autorise est charge |
| **Developpeur / contributeur** | Membre ou Contributeur | Doit utiliser **"Tester en tant que role"** pour consulter les rapports |
| **Administrateur workspace** | Admin | Ne pas ouvrir les rapports en mode normal — utiliser "Tester en tant que role" |

> **Regle** : toute personne qui ne publie pas, ne met pas a jour l'application et ne modifie pas les rapports **doit etre en acces Lecteur (Viewer)** sur l'espace de travail.

---

## 3. Donnees UAT en production

### Constat

Il arrive que des donnees d'un environnement inferieur (UAT, DEV) soient poussees en production pour tester les performances d'un rapport sur une capacite superieure (ex : P1/P2 en UAT → P3/P4 en PROD).

### Position du COE

Le COE peut faire preuve de **souplesse** et autoriser ce type de test sur une **periode limitee (1-2 jours maximum)**, sous reserve de :

1. **Prevenir le COE** avant le test
2. **Planifier en heures creuses** (avant 9h ou apres 18h)
3. **Nettoyer les donnees UAT** immediatement apres le test

### Points d'attention

- **Si les performances sont mauvaises sur un environnement inferieur, elles le seront aussi sur un environnement superieur.** Le probleme vient du modele, pas de la capacite. Un SKU superieur a plus de ressources mais si le modele genere des requetes massives, la charge augmentera proportionnellement au nombre d'utilisateurs.
- L'**outil de stress test** du COE (OA Realistic Load Test Tool) est plus adapte pour tester les performances sous charge. Il simule des utilisateurs simultanes sans necessiter de pousser des donnees de test en production.
- **Contacter le COE pour planifier un stress test** plutot que de pousser des donnees UAT en prod.

---

## 4. Optimisation des modeles semantiques

### 4.1 Tables avec trop de colonnes

**Constat** : certaines tables de faits en DirectQuery contiennent jusqu'a **190 colonnes**. Chaque requete DAX genere un `SELECT` massif vers BigQuery, meme pour afficher un seul visuel.

**Recommandation** : adopter un **modele en etoile** :

| Principe | Action |
|----------|--------|
| **Tables de faits** | Ne conserver que les **cles (ID)** et les **valeurs numeriques** necessaires aux calculs |
| **Tables de dimensions** | Deporter les informations descriptives (noms, labels, codes) dans des tables de dimensions separees |
| **Objectif** | < 50 colonnes par table de faits en DirectQuery |

**Exemple** :

```
AVANT (table plate — 190 colonnes) :
  kpi_servicelevel : division_name, division_code, country_name, country_code,
                     plant_name, plant_code, material_name, material_code,
                     qty_processed, value_invoiced, service_level_pct, ...

APRES (modele en etoile) :
  fact_servicelevel : division_id, country_id, plant_id, material_id,
                      qty_processed, value_invoiced, service_level_pct
  dim_division : division_id, division_name, division_code
  dim_country : country_id, country_name, country_code
  dim_plant : plant_id, plant_name, plant_code
  dim_material : material_id, material_name, material_code
```

### 4.2 Cas ou toutes les colonnes sont necessaires

Si apres analyse toutes les colonnes sont reellement utilisees :

1. Utiliser les **Google Functions** et les **binding parameters** dans Power Query
2. Cela permet de recuperer via SQL **uniquement les colonnes et lignes necessaires** a chaque requete
3. Reduit considerablement la charge sur BigQuery et sur la capacite Power BI

### 4.3 Visuels avec trop de mesures

**Constat** : certains visuels affichent **40+ mesures** simultanement, avec des mesures imbriquees (une mesure qui en appelle 5 autres).

**Recommandations** :

| Action | Impact |
|--------|--------|
| Limiter a **10-15 mesures par page** | Reduit le nombre de requetes DQ par interaction |
| Eviter les mesures imbriquees profondes | Une mesure qui appelle 5 sous-mesures = 6 evaluations |
| Utiliser des **tables d'agregation** en Import pour les KPI principaux | Elimine les requetes DQ pour les metriques courantes |
| Proposer un **export paginated report** plutot qu'un visuel "Raw data" | Supprime la requete la plus couteuse du modele |

### 4.4 Dimensions en DirectQuery

Les tables de dimension (dates, pays, marques, filtres...) ne doivent **jamais** etre en DirectQuery pur.

| Mode recommande | Quand |
|----------------|-------|
| **Dual** | Dimension utilisee dans des slicers/filtres ET reliee a une table de faits DQ |
| **Import** | Dimension petite (< 100 000 lignes) sans besoin temps reel |

> Impact : passer les dimensions de DQ a Dual reduit de **30 a 50%** les requetes DirectQuery.

---

## 5. Monitoring : Fabric vs Premium

### Comparaison

| Critere | Premium (P SKU) | Fabric (F SKU) |
|---------|----------------|----------------|
| **Granularite monitoring** | Fenetres de **2 heures** | Fenetres de **30 secondes** |
| **Mode de gestion** | **Reactif** — on detecte apres l'incident | **Preventif** — on detecte en quasi temps reel |
| **Monitoring Hub** | Non disponible | KQL en temps reel |
| **Autoscale** | Non disponible | Disponible (ajout de CU automatique) |
| **Alertes** | Via Admin Portal (delai) | Via Data Activator (temps reel) |

### Recommandation

La migration vers **Fabric (F SKU)** est recommandee pour les capacites critiques. Le monitoring en quasi temps reel permet de passer d'une logique de **reparation** a une logique de **prevention**.

### Outils a disposition des equipes

| Outil | Description | Statut |
|-------|-------------|--------|
| **OA Realistic Load Test Tool** | Stress test Power BI — simule des utilisateurs simultanes avec filtres, bookmarks, think time configurable. Mesure TimeToLoad, TimeToRender, cache hit rate, memoire. Documentation complete disponible. | Disponible |
| **Workspace dedie Stress Test (Fabric)** | Environnement isole avec monitoring KQL pre-configure pour les tests de charge sans impact sur la production | Disponible |
| **Analyse des logs capacite (GCP BigQuery)** | Requete sur `capacity_unit_timepoint_v2` pour analyser interactive_value, background_value et capacity_unit_count apres un stress test (delai 24h) | Disponible |
| **Dashboard de monitoring capacite** | Suivi CU, throttling, taux d'echec par capacite | En cours de deploiement |
| **Dashboard planning des refreshes** | Vue partagee de tous les refreshes planifies par capacite (dataset, workspace, heure, duree, CU). Permet aux use cases de voir les chevauchements et d'etaler leurs refreshes | A developper |
| **Checklist pre-publication** | Verification du modele avant mise en prod (mode DQ, nb colonnes, nb mesures, dimensions Dual, refresh planifie, marge CU) | Disponible |
| **Audit MCP automatise** | Audit du modele semantique via Claude Code / MCP Power BI (tables, colonnes, partitions, mesures, relations) | Disponible |
| **Templates de rapport optimise** | Modeles de rapports respectant les bonnes pratiques (etoile, < 50 colonnes DQ, dimensions Dual) | A developper |
| **Systeme d'alerting Background CU** | Alerte quand le Background % depasse 80% sur une capacite — detection des conflits de refresh avant impact utilisateur | A developper |
| **Frontend Stress Test** | Interface web pour piloter les stress tests, visualiser les resultats en temps reel et consulter l'historique des runs | A developper |

---

## 6. Strategie du COE

### Principes

La capacite Power BI est une **ressource partagee**. La performance de chacun depend du comportement de tous. Le COE a pour mission d'**accompagner** les use cases, pas de corriger les modeles a leur place.

### Repartition des responsabilites

| Responsabilite | Porteur |
|----------------|---------|
| Optimisation des modeles semantiques | **Equipe use case** |
| Respect des bonnes pratiques de developpement | **Equipe use case** |
| Gestion des acces et du RLS | **Equipe use case** |
| Nettoyage des datasets obsoletes | **Equipe use case** |
| Accompagnement, audit, recommandations | **COE** |
| Monitoring des capacites et alertes | **COE** |
| Definition des bonnes pratiques et gouvernance | **COE** |
| Gestion de l'infrastructure (SKU, capacites) | **IT Platform Services** |

### Ce que le COE propose

- **Audit** de vos modeles semantiques sur demande
- **Stress test** de vos rapports avant mise en production
- **Accompagnement** sur l'optimisation des modeles
- **Formation** aux bonnes pratiques Power BI

### Ce que le COE attend des equipes

- Respecter les **bonnes pratiques** (modele en etoile, < 50 colonnes DQ, dimensions en Dual)
- **Prevenir le COE** avant tout test de charge ou push de donnees UAT en prod
- **Gerer les acces** correctement (Viewer pour les consultants, "Tester en tant que role" pour les devs)
- **Reagir** aux recommandations d'optimisation dans un delai raisonnable

---

## 7. Resume des actions prioritaires

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 1 | Passer les non-contributeurs en **Viewer** sur les workspaces avec tables unsecured | Elimine les scans de tables completes | Faible |
| 2 | Configurer les **parametres de capacite** selon le tableau §1 | Protege la capacite contre les requetes abusives | Faible |
| 3 | Passer la **detection changements** de 30s a 5 min minimum | Reduit le polling continu | Faible |
| 4 | Reduire les colonnes des tables de faits DQ a **< 50 colonnes** (modele en etoile) | Reduit la charge par requete de 70%+ | Moyen |
| 5 | Limiter a **10-15 mesures par page**, eviter les mesures imbriquees | Reduit les evaluations DAX | Moyen |
| 6 | Migrer les capacites critiques vers **Fabric (F SKU)** | Monitoring preventif au lieu de reactif | Eleve |

---

## References

- [Microsoft Docs — Premium capacity settings](https://learn.microsoft.com/en-us/power-bi/admin/service-admin-premium-workloads)
- [Comprendre le throttling Fabric](https://learn.microsoft.com/en-us/fabric/enterprise/throttling)
- Monitoring KQL : `Incident Analysis/KQL_Queries_Monitoring.md`
- Best practices : `Incident Analysis/Best_Practices_Capacity_Management.md`
- Troubleshooting : `Incident Analysis/Troubleshooting_Guide.md`

---

*Power BI COE — Mohcine MMADI — Mars 2026*
