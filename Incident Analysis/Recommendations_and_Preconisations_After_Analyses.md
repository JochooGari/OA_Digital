# Recommandations et preconisations suite aux analyses d'incidents capacite

> Document de synthese a destination du COE Power BI / Fabric, d'OA Analytics Services et des equipes proprietaires de modeles.
> Base sur l'analyse des incidents du dossier `Incident Analysis/`, en particulier `INC10281567-nefapbtdpcommunity2`, ainsi que sur les audits de modeles, les best practices et le troubleshooting guide.
> Derniere mise a jour : 2026-03-16

---

## 1. Synthese executive

Les analyses realisees montrent que les incidents de capacite observes ne relevent pas d'un probleme isole de plateforme, mais d'une combinaison recurrente de facteurs :

1. **Modeles DirectQuery trop couteux**, parfois en **DirectQuery chaine** vers Analysis Services ou vers des sources volumineuses
2. **Tables de faits trop larges** en DirectQuery, avec un nombre de colonnes tres eleve
3. **Visuels et pages trop riches** en mesures et en detail, en particulier les vues type "Raw data"
4. **Absence de prevention temps reel** : la surcharge est detectee trop tard, une fois les echecs utilisateurs deja visibles
5. **Parametrage et gouvernance insuffisants** sur les capacites, les refreshs, les droits et les regles de mise en production

Le cas `nefapbtdpcommunity2` confirme qu'un seul ou quelques modeles mal calibres peuvent degrader l'ensemble d'une capacite partagee. La priorite n'est donc pas seulement de reparer les incidents lorsqu'ils surviennent, mais de **reduire structurellement la probabilite de recurrence**.

---

## 2. Constats majeurs issus des analyses

### 2.1 Les incidents sont principalement lies aux patterns de modelisation

Les audits realises mettent en evidence plusieurs patterns a risque :

- **DirectQuery chaine** vers un autre modele Analysis Services / Fabric
- **Tables de faits en DirectQuery avec 100+ colonnes**, parfois jusqu'a 190 colonnes
- **Grand nombre de mesures** sur une meme table ou une meme page
- **Dimensions non optimales** pour les usages de filtrage
- **Visuels detaillees** qui demandent simultanement un grand nombre de colonnes et de mesures

Ces patterns augmentent fortement la consommation CU, la latence et le risque de throttling.

### 2.2 La capacite partagee amplifie les effets

Une capacite heberge plusieurs workspaces et plusieurs usages concurrents. Lorsqu'un modele genere des requetes trop couteuses :

- il consomme une part disproportionnee des ressources partagees
- il degrade les autres workspaces non fautifs
- il pousse les utilisateurs a relancer les rapports
- cela cree un **effet boule de neige** qui aggrave encore l'incident

### 2.3 Le manque d'alerting et de pilotage retarde la reaction

Les documents existants montrent que :

- les incidents sont souvent detectes apres les premiers impacts utilisateurs
- le suivi temps reel n'est pas encore generalise
- la revue periodique des modeles a risque n'est pas industrialisee
- la gouvernance pre-publication n'est pas encore suffisamment bloquante

---

## 3. Cause racine recurrente

La cause racine recurrente n'est pas simplement "une capacite surchargee". La surcharge est la consequence visible. Les causes racines observees sont :

1. **Architecture semantique inadaptee** pour une capacite partagee
2. **Absence d'encadrement des modeles gourmands avant mise en production**
3. **Usage trop permissif de DirectQuery**, notamment pour des besoins qui pourraient etre couverts par Import, Dual, Direct Lake ou agregations
4. **Charge continue inutile** liee a certains parametres et comportements d'usage
5. **Pilotage reactif** au lieu d'un pilotage preventif

---

## 4. Recommandations prioritaires

## 4.1 Priorite 1 - Reduire immediatement les causes de surcharge

### A. Interdire ou encadrer fortement le DirectQuery chaine

Le DirectQuery chaine doit etre considere comme un **pattern exceptionnel**, jamais comme un standard.

Preconisations :

- ne plus autoriser de nouveau modele en DQ chaine sans validation explicite du COE
- auditer en priorite les capacites critiques pour identifier tous les modeles DQ chaine
- exiger un plan de remediation pour chaque modele concerne :
  - bascule partielle en Import
  - usage de tables d'agregation
  - dimensions en Dual
  - redesign du modele source

### B. Reduire la largeur des tables de faits en DirectQuery

Les tables de faits en DQ doivent etre limitees aux colonnes strictement utiles.

Preconisations :

- fixer un objectif de **< 50 colonnes utiles** pour les tables de faits en DQ
- creer des vues SQL / BigQuery dediees aux usages reporting
- deplacer les attributs descriptifs vers des dimensions
- supprimer les colonnes non exploitees par les visuels

### C. Supprimer ou encadrer les visuels "Raw data"

Les visuels detaillees sont parmi les plus couteux.

Preconisations :

- interdire les visuels "Raw data" sur les modeles DQ critiques sans justification forte
- remplacer les besoins d'extraction par :
  - paginated reports
  - exports dedies
  - tables d'agregation / tables de detail ciblees

## 4.2 Priorite 2 - Renforcer la prevention

### D. Mettre en place un monitoring proactif

Preconisations :

- activer un suivi temps reel des capacites critiques
- mettre en place une alerte **CU > 80%**
- mettre en place une alerte sur :
  - taux d'echec
  - requetes > 2 minutes
  - hausse soudaine des utilisateurs concurrents
- formaliser un tableau de bord COE de suivi capacite

### E. Revoir le parametage des capacites

Les capacites ne doivent pas rester avec des reglages trop permissifs.

Preconisations :

- appliquer les parametres recommandes du document `Capacity_Settings_P1_P4.md`
- relever l'intervalle minimal de detection des changements
- limiter les comportements de polling trop frequents
- verifier les timeouts et la memoire max par requete

### F. Mieux piloter les refreshs

Les refreshs concurrents accentuent la saturation.

Preconisations :

- deplacer les refreshs lourds hors heures de pointe
- reduire les chevauchements sur une meme capacite
- imposer une revue des refreshs pour les datasets volumineux
- promouvoir le refresh incremental

## 4.3 Priorite 3 - Installer une gouvernance COE plus structurante

### G. Introduire une checklist de pre-publication obligatoire

Avant toute mise en production sur une capacite partagee, verifier au minimum :

- mode de stockage du modele
- nombre de colonnes des faits DQ
- nombre de mesures
- presence de dimensions en Dual/Import
- absence de DQ chaine non valide
- planning de refresh compatible
- estimation de charge si audience importante

### H. Rendre l'audit de modele semi-systematique

Preconisations :

- audit trimestriel des capacites critiques
- audit semestriel des capacites de moindre criticite
- utilisation du MCP Power BI pour accelerer les revues
- classement des modeles par niveau de risque : faible / moyen / eleve / critique

### I. Clarifier les responsabilites

Le COE accompagne, mais les equipes proprietaires doivent corriger leurs modeles.

Preconisations :

- formaliser les responsabilites dans les documents COE
- associer chaque recommandation a un proprietaire et une date cible
- rendre visible le statut des plans d'action par use case

---

## 5. Preconisations par horizon

## 5.1 Actions immediates (0 a 7 jours)

1. Lister les modeles DirectQuery et DirectQuery chaine sur les capacites critiques
2. Identifier les workspaces les plus consommateurs via KQL
3. Mettre en place une alerte CU > 80% sur les capacites les plus sensibles
4. Geler les nouvelles mises en production de modeles DQ non audites sur ces capacites
5. Revoir les refreshs des datasets les plus lourds
6. Communiquer aux equipes projet les patterns a proscrire

## 5.2 Actions court terme (2 a 4 semaines)

1. Auditer les modeles les plus consommateurs
2. Faire corriger les dimensions DQ pour les passer en Dual ou Import
3. Faire retirer ou remplacer les visuels detaillees les plus couteux
4. Construire un dashboard COE de suivi capacite
5. Standardiser un runbook incident capacite
6. Publier les bonnes pratiques et les preconisations sur Confluence

## 5.3 Actions moyen terme (1 a 3 mois)

1. Mettre en place une revue de capacite trimestrielle
2. Mettre en place une checklist de pre-go-live obligatoire
3. Etudier la migration des capacites critiques vers des environnements plus pilotables
4. Etudier l'autoscale pour les F SKU critiques si pertinent
5. Construire des templates de modeles optimises

---

## 6. Preconisations techniques detaillees

### 6.1 Sur la modelisation

- privilegier **Import** quand le besoin temps reel n'est pas indispensable
- utiliser **Dual** pour les dimensions exploitees en filtres et slicers
- reserver **DirectQuery** aux cas justifies et maitrises
- ajouter des **agregations** pour les KPI principaux
- limiter le nombre de mesures visibles sur une page
- reduire les relations bidirectionnelles

### 6.2 Sur l'exploitation

- eviter les refreshs longs en heures de pointe
- surveiller regulierement les top datasets par consommation CU
- documenter les incidents avec les memes metriques et les memes preuves
- centraliser les KQL de diagnostic et leur interpretation

### 6.3 Sur les acces et la securite

- passer les utilisateurs de consultation en **Viewer** lorsque le contexte RLS l'exige
- eviter l'ouverture des rapports sensibles avec des droits trop eleves en usage normal
- rappeler l'usage de **"Tester en tant que role"** pour les developpeurs et admins

---

## 7. Indicateurs de succes proposes

Pour mesurer l'efficacite des actions, suivre mensuellement :

| Indicateur | Objectif |
|-----------|----------|
| % capacites critiques avec alerte active | 100% |
| % modeles critiques audites | 100% |
| Nb de modeles DQ chaine sans plan de remediation | 0 |
| Taux d'incidents capacite recurrents | En baisse continue |
| % refreshs lourds hors heures de pointe | > 90% |
| Taux de requetes en echec sur capacites critiques | < 5% |

---

## 8. Position recommandee du COE

Le COE doit porter une position claire :

- **pas de tolerance durable** pour les modeles structurellement dangereux
- **accompagnement fort** des equipes sur les remediations
- **standardisation** des controles avant mise en production
- **monitoring preventif** comme norme de fonctionnement

L'objectif n'est pas seulement de traiter les incidents, mais de faire evoluer le mode operatoire du tenant vers une gestion de capacite plus previsible, plus industrialisee et plus responsabilisante.

---

## 9. References

- `Incident Analysis/incidents/INC10281567-nefapbtdpcommunity2.md`
- `Incident Analysis/Best_Practices_Capacity_Management.md`
- `Incident Analysis/Capacity_Settings_P1_P4.md`
- `Incident Analysis/Troubleshooting_Guide.md`
- `Incident Analysis/KQL_Queries_Monitoring.md`
