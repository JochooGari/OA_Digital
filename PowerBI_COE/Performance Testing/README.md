# Tests de Performance Power BI — Documentation Opérationnelle

**Équipe** : Power BI COE — L'Oréal
**Outil** : OA Realistic Load Testing Framework v2.0
**Mis à jour** : Mars 2026

---

## Sommaire

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Prérequis](#2-prérequis)
3. [Installation de l'outil](#3-installation-de-loutil)
4. [Exécuter un test pas à pas](#4-exécuter-un-test-pas-à-pas)
5. [Intégrer les résultats via le notebook Fabric](#5-intégrer-les-résultats-via-le-notebook-fabric)
6. [Configurer les scénarios avancés](#6-configurer-les-scénarios-avancés)
7. [Lire et interpréter les résultats](#7-lire-et-interpréter-les-résultats)
8. [Analyse des capacités Premium via GCP](#8-analyse-des-capacités-premium-via-gcp)
9. [Bonnes pratiques L'Oréal](#9-bonnes-pratiques-loréal)
10. [Dépannage](#10-dépannage)

---

## 1. Contexte et objectifs

### Pourquoi tester les performances ?

L'Oréal exploite plusieurs capacités Power BI Premium (P2, P3, P5) réparties sur plusieurs régions. Ces capacités sont partagées entre de nombreux workspaces et utilisateurs. Un rapport mal optimisé ou un pic de charge peut provoquer du **throttling** (ralentissement forcé de la capacité) et impacter tous les utilisateurs de cette capacité, pas seulement ceux du rapport testé.

### Ce que permet l'outil

Le **OA Realistic Load Testing Framework** simule des utilisateurs réels accédant simultanément à un rapport Power BI, en reproduisant des comportements réalistes :
- Navigation entre pages
- Changement de filtres et slicers
- Navigation entre bookmarks
- Temps de réflexion entre actions

### Cas d'usage

| Objectif | Instances recommandées |
|----------|----------------------|
| Planification de capacité (max users avant dégradation) | 10 – 50 |
| Optimisation d'un rapport (identifier les goulots) | 2 – 5 |
| Test de charge d'une capacité Premium | 50 – 100+ |
| Analyse du cache (warm vs cold) | 5 – 10 |
| Impact DirectQuery sur la source de données | 10 – 20 |

---

## 2. Prérequis

### Accès requis

- [ ] **Compte Power BI** avec rôle Member, Contributor ou Admin sur le workspace à tester
- [ ] **Accès au workspace dédié stress test** L'Oréal (voir section 4 — demande par email)
- [ ] **Admin de la capacité** concernée (pour analyser les logs de capacité)
- [ ] **Accès BigQuery** `itg-btdppublished-gbl-ww-pd` (pour l'analyse GCP post-test)

> **Note** : Pour être admin des capacités Premium, voir le Portail d'administration Power BI → Paramètres de capacité → ⚙️ sur chaque capacité.

### Logiciels requis

| Logiciel | Version | Remarque |
|----------|---------|----------|
| Windows | 10 / 11 | Obligatoire |
| PowerShell | 5.0+ | Pré-installé Windows |
| Google Chrome | Dernière version | Installer avec `ChromeSetup.exe --system-level` dans `C:\Program Files` |
| Fichiers du framework | v2.0 | Contacter l'équipe BTDP Analytics |

### Configuration machine recommandée

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| RAM | 8 GB | 16 GB+ |
| CPU | 4 cœurs | 8+ cœurs |
| Disque | 500 MB | 2 GB |

**Règle de calcul des instances max** :
```
Max instances = min(CPU physiques, RAM totale (GB) / 2)
Exemple : 16 GB RAM, 8 cœurs → max 8 instances
```

---

## 3. Installation de l'outil

### Étape 1 — Localiser les fichiers

Le framework est déjà installé localement :
```
C:\Users\M.MMADI-EXT\Documents\Business\OA Digital\OARealisticLoadTestTool\OARealisticLoadTestTool\
```

Structure présente :
```
OARealisticLoadTestTool/
├── Orchestrator.ps1              ← Point d'entrée principal
├── Install-LoadTestFramework.ps1 ← Vérification de l'installation
├── Run_Load_Test_Only.ps1
├── Monitoring.ps1
├── View-LiveMetrics.ps1
├── Update_Token_Only.ps1
├── PBIReport.json                ← Déjà configuré (rapport + filtres)
├── PBIToken.json                 ← Token OAuth (à rafraîchir si expiré)
├── RealisticLoadTest.html
├── LoadTestDashBoard.pbix        ← Rapport de visualisation des résultats
└── logs/
    ├── orchestrator_log.csv      ← Vide (aucun test lancé)
    └── logPage.csv               ← Vide (aucun test lancé)
```

### Étape 2 — Vérifier l'installation

Ouvrir **PowerShell en tant qu'administrateur** et exécuter :

```powershell
cd "C:\Users\M.MMADI-EXT\Documents\Business\OA Digital\OARealisticLoadTestTool\OARealisticLoadTestTool"
.\Install-LoadTestFramework.ps1
```

L'installateur vérifie automatiquement :
- ✅ Version PowerShell (5.0+)
- ✅ Politique d'exécution (RemoteSigned)
- ✅ Module Power BI PowerShell
- ✅ Présence de Google Chrome dans `C:\Program Files`
- ✅ Création des dossiers `logs/` et `ChromeProfiles/`

### En cas d'erreur à l'installation

```powershell
# Erreur d'exécution de scripts
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Get-ChildItem -Path . -Filter *.ps1 | Unblock-File

# Module Power BI manquant
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
```

---

## 4. Exécuter un test pas à pas

### Étape 1 — Demander l'accès au workspace dédié stress test

L'Oréal dispose d'un **workspace Fabric isolé** pour les tests de charge, sans impact sur la production.

Envoyer un email à l'équipe BTDP Analytics en précisant :
- Ton nom et email
- Département / équipe
- Objectif et durée du test
- Nombre de rapports à tester

Délai de réponse : 1-2 jours ouvrés.

### Étape 2 — Uploader le rapport dans le workspace de test

Avant le test, uploader le rapport `.pbix` dans le workspace dédié stress test (pas dans le workspace de production).

Nommage recommandé : `YYYYMMDD_NomEquipe_Objet`
Exemple : `20260305_PBI_COE_NERD_StressTest`

### Étape 3 — Lancer le test

```powershell
cd "C:\Users\M.MMADI-EXT\Documents\Business\OA Digital\OARealisticLoadTestTool\OARealisticLoadTestTool"
.\Orchestrator.ps1 -TestId "20260305_NERD_StressTest"
```

> Le fichier `PBIReport.json` est **déjà configuré** avec un rapport, une page et un filtre `division_code`. Pas besoin de le modifier pour un premier test.

Suivre les prompts :

1. **Login Power BI** → entrer ses credentials L'Oréal
2. **Sélectionner le workspace** → choisir le workspace dédié stress test
3. **Sélectionner le rapport** → choisir le rapport à tester
4. **Nombre d'instances** → commencer par **2 ou 3** pour valider la config

### Étape 4 — Surveiller en temps réel

Une fenêtre **Live Metrics** s'ouvre automatiquement avec :

| Métrique | Vert ✅ | Orange ⚠️ | Rouge ❌ |
|----------|---------|-----------|---------|
| Durée moyenne | < 5s | 5-10s | > 10s |
| Cache Hit Rate | > 70% | 40-70% | < 40% |
| Mémoire par instance | < 300 MB | 300-500 MB | > 500 MB |

### Étape 5 — Arrêter le test

Appuyer sur **Entrée** dans la fenêtre PowerShell principale. Toutes les fenêtres Chrome se ferment automatiquement et un résumé s'affiche.

### Pour les tests longs (> 60 min)

Le token OAuth expire après 60 min. Dans une **deuxième fenêtre PowerShell**, lancer :

```powershell
while ($true) {
    Start-Sleep -Seconds (50 * 60)
    .\Update_Token_Only.ps1
    Write-Host "Token rafraîchi à $(Get-Date)" -ForegroundColor Green
}
```

---

## 5. Intégrer les résultats via le notebook Fabric

Après le test, les fichiers CSV générés doivent être intégrés dans le rapport de stress test via un **notebook Fabric développé par Anes**. C'est cette étape qui alimente le rapport Power BI de suivi des tests.

> **Note** : Il existe un Google Sheet de suivi des tests (80 tests documentés pendant l'été). Il n'a pas été supprimé — demander le lien à Anes. Un fichier Excel est également en cours de création par Abdelkader pour le modèle composite Kivos.

### Workflow d'intégration

```
Test terminé
    ↓
logPage.csv + orchestrator_log.csv générés dans .\logs\
    ↓
Uploader les 2 fichiers dans le workspace Fabric dédié
    ↓
Lancer le notebook Fabric (demander le lien à Anes)
    ↓
Le notebook :
  ├── Lit logPage.csv + orchestrator_log.csv
  ├── Récupère les métriques de capacité (Capacity Metrics App + SSDS IT)
  ├── Crée un flag "occurrence" (si même test lancé plusieurs fois)
  ├── Filtre les tests en succès (erreurs d'auth exclues)
  ├── Exécute les requêtes KQL de monitoring
  ├── Supprime et recrée les tables Fabric
  └── Déclenche un refresh du modèle (import mode)
    ↓
Rapport Power BI mis à jour automatiquement
```

### Étapes détaillées

**1. Localiser les fichiers CSV générés**
```
C:\Users\M.MMADI-EXT\Documents\Business\OA Digital\OARealisticLoadTestTool\OARealisticLoadTestTool\logs\
├── orchestrator_log.csv    ← historique d'exécution des tests
└── logPage.csv             ← métriques détaillées de chaque refresh
```

**2. Uploader dans le workspace Fabric**
- Aller dans le workspace Fabric dédié aux stress tests
- Uploader les 2 fichiers CSV

**3. Lancer le notebook**
- Ouvrir le notebook dans Fabric (lien à récupérer auprès d'Anes)
- Vérifier que le **nom de la capacité** est correct dans le notebook (paramètre à ne pas oublier si changement de capacité)
- Exécuter toutes les cellules

**4. Vérifier le refresh**
- Le notebook déclenche un refresh du modèle en import mode
- Attendre la fin du refresh (SQL endpoint synchronisation ~quelques minutes)
- Le rapport est prêt

### Point d'attention — Clear cache DAX Studio

Avant de lancer un **nouveau batch de tests** (pas le premier), il faut vider le cache :
1. Ouvrir **DAX Studio** connecté au dataset
2. Menu **Advanced → Clear Cache**
3. Attendre ~5 minutes
4. Relancer le test

Sans cette étape, les résultats du batch suivant seront faussés par le cache du précédent.

### Sources de logs à récupérer après chaque test

| Source | Où | Délai |
|--------|----|-------|
| `logPage.csv` | `.\logs\` en local → upload Fabric | Immédiat |
| `orchestrator_log.csv` | `.\logs\` en local → upload Fabric | Immédiat |
| Logs capacité Fabric (KQL) | Fabric Monitoring Hub → `SemanticModelLogs` | Immédiat |
| Logs capacité GCP | BigQuery `capacity_unit_timepoint_v2` | **Attendre 24h** |

### Obtenir le notebook et les fichiers de test

Contacter **Anes** pour :
- Le lien du Google Sheet de suivi des 80 tests (toujours disponible)
- Le lien du notebook Fabric

Contacter **Abdelkader** pour :
- Le script de test configuré
- Un exemple de logPage.csv pour valider le workflow sans lancer de vrai test

---

## Pistes d'automatisation

Anes reconnaît que le workflow actuel est **chronophage et répétitif** (clear cache, upload manuel, lancement du notebook…). Voici les étapes manuelles et ce qu'on peut en faire :

### Étapes manuelles actuelles

```
[MANUEL] Lancer le test (Orchestrator.ps1)
[MANUEL] Clear cache DAX Studio → attendre 5 min
[MANUEL] Relancer le batch suivant si plusieurs scénarios
[MANUEL] Uploader logPage.csv + orchestrator_log.csv dans Fabric
[MANUEL] Lancer le notebook Fabric
[MANUEL] Attendre le refresh du modèle
[MANUEL] Requête KQL dans Fabric Monitoring Hub
[MANUEL] Requête BigQuery (24h après)
```

### Ce qui peut être automatisé

| Étape | Solution technique | Effort |
|-------|-------------------|--------|
| Upload CSV → Fabric après test | Step PowerShell ajouté en fin d'Orchestrator (Fabric REST API) | Faible |
| Déclenchement notebook Fabric | Appel API Fabric `POST /items/{notebookId}/jobs/instances` | Faible |
| Clear cache entre batches | `Invoke-ASCmd` via PowerShell (XMLA endpoint) | Moyen |
| Token refresh automatique | Boucle PowerShell toutes les 50 min (déjà documentée) | Fait |
| Notification résultats | Power Automate déclenché par fin de refresh | Faible |

> **Recommandation** : Prioriser l'upload automatique des CSV + déclenchement du notebook — c'est le gain de temps le plus immédiat pour les 2 étapes les plus répétitives.

---

## 6. Configurer les scénarios avancés

Après le premier lancement, un dossier horodaté est créé avec un fichier `PBIReport.JSON` à éditer.

### Trouver les identifiants nécessaires

**Page ID** :
1. Ouvrir le rapport dans Power BI Service
2. Naviguer sur la page souhaitée
3. URL du navigateur : `.../reports/reportId/ReportSection123abc`
4. Utiliser `ReportSection123abc` comme `pageName`

**Bookmark GUID** :
1. Cliquer sur un bookmark du rapport (pas un bookmark personnel)
2. URL du navigateur : `...?bookmarkGuid=Bookmark1d7f5476`
3. Utiliser `Bookmark1d7f5476` dans `bookmarkList`

**Noms de tables/colonnes pour les filtres** :
1. Ouvrir le rapport dans Power BI Desktop
2. Cliquer sur le visuel avec le slicer/filtre
3. Dans le volet Visualisations, noter le nom exact du champ

### Exemple de configuration PBIReport.JSON

```json
reportParameters={
  "reportUrl": "https://app.powerbi.com/reportEmbed?reportId=...",
  "pageName": "ReportSectionABC",
  "bookmarkList": ["BookmarkGUID1", "BookmarkGUID2"],
  "thinkTimeSeconds": 15,
  "sessionRestart": 100,
  "layoutType": "Master",
  "filters": [
    {
      "filterTable": "dim_realms",
      "filterColumn": "zone",
      "isSlicer": true,
      "filtersList": ["Europe", "Americas", "Global"]
    },
    {
      "filterTable": "dim_date",
      "filterColumn": "year",
      "isSlicer": false,
      "filtersList": ["2025", "2026"]
    }
  ]
};
```

### Think time selon l'objectif

| Scénario | Think time | Usage |
|----------|-----------|-------|
| Stress pur (point de rupture) | 0-1s | Trouver la limite maximale |
| Simulation réaliste | 15-30s | Reproduire le comportement réel |
| Planification de capacité | 5-10s | Équilibre réalisme / durée |

---

## 6. Lire et interpréter les résultats

### Métriques clés dans logPage.csv

| Colonne | Signification | Seuil cible |
|---------|--------------|-------------|
| `TimeToLoad` | Temps de requête + réseau | < 3s |
| `TimeToRender` | Temps de rendu dans le navigateur | < 2s |
| `TotalTime` | Expérience utilisateur complète | < 5s |
| `IsCached` | Données servies depuis le cache | > 70% |

### Identifier le goulot d'étranglement

```
Si TimeToLoad > TimeToRender × 1.5
→ Goulot : Modèle de données / DAX
→ Action : Optimiser les mesures DAX, ajouter des agrégations, réduire le volume

Si TimeToRender > TimeToLoad × 1.5
→ Goulot : Rendu des visuels
→ Action : Réduire le nombre de visuels, simplifier les graphiques

Si équilibré
→ Performance bien optimisée
```

### Benchmarks de référence

| Métrique | Excellent | Bon | Attention | Critique |
|----------|-----------|-----|-----------|---------|
| Durée moyenne | < 3s | 3-5s | 5-10s | > 10s |
| P95 | < 5s | 5-10s | 10-20s | > 20s |
| Cache Hit Rate | > 70% | 50-70% | 30-50% | < 30% |
| Taux d'erreur | 0% | < 1% | 1-5% | > 5% |
| Mémoire/instance | < 200 MB | 200-300 MB | 300-500 MB | > 500 MB |

### Calculer le nombre d'utilisateurs réels simulés

```
Utilisateurs réels / instance = (Temps de refresh moyen + Think time réel) / Temps de refresh moyen

Exemple :
- Temps de refresh moyen : 10s
- Think time réel utilisateur : 30s
- Résultat : (10 + 30) / 10 = 4 utilisateurs réels par instance
```

---

## 7. Analyse des capacités Premium via GCP

Après le test, il est possible d'analyser l'impact sur les capacités Premium via les logs consolidés dans BigQuery.

> **Important** : Les logs sont consolidés toutes les **24 heures**. Attendre au moins 24h après le test avant de lancer l'analyse.

### Requête BigQuery — Impact sur la capacité

```sql
SELECT
    capacity_name,
    interactive_value,    -- CPU des opérations interactives (utilisateurs)
    background_value,     -- CPU des opérations en arrière-plan (refreshs)
    capacity_unit_count   -- Unités totales disponibles
FROM `itg-btdppublished-gbl-ww-pd.btdp_ds_c1_0a2_powerbimetadata_eu_pd.capacity_unit_timepoint_v2`
WHERE usage_timepoint BETWEEN DATETIME("YYYY-MM-DD")  -- Remplacer par la date du test
    AND DATETIME_ADD("YYYY-MM-DD", INTERVAL 1 DAY)
ORDER BY usage_timepoint ASC
LIMIT 1000
```

### Interpréter les colonnes

| Colonne | Signification | Signal d'alerte |
|---------|--------------|-----------------|
| `interactive_value` | CPU consommé par les utilisateurs | > 100% = throttling actif |
| `background_value` | CPU consommé par les refreshs | Pic = refresh concurrent au test |
| `capacity_unit_count` | Capacité totale disponible | Comparer avec `interactive_value` |

### Analyse croisée — Corréler les deux sources

Pour une analyse complète, croiser :
1. `logPage.csv` du framework → actions utilisateur avec timestamps
2. Requête BigQuery → consommation capacité sur la même période

Cela permet d'identifier si les dégradations de performance sont dues à la capacité (throttling) ou au rapport lui-même.

### Requête KQL dans Fabric Monitoring Hub

Pour une analyse DAX query par query dans le workspace de test :

```kql
let result = SemanticModelLogs
| where OperationName in ("QueryEnd") and ItemName == "NomDuDataset"
| sort by Timestamp asc
| extend app = tostring(parse_json(ApplicationContext))
| project Timestamp, ItemName, OperationName, ExecutingUser,
          DurationMs, CpuTimeMs,
          visualId = extract_json("$.Sources[0].VisualId", app),
          usersession = extract_json("$.Sources[0].HostProperties.UserSession", app)
| extend WaitTimeMs = toint(extract(@"WaitTime:\s*(\d+)\s*ms", 1, EventText))
| project Timestamp, ItemName, ExecutingUser, DurationMs, CpuTimeMs, WaitTimeMs, visualId;
result
```

---

## 8. Bonnes pratiques L'Oréal

### Avant le test

- [ ] Valider que le rapport fonctionne correctement en Power BI Desktop
- [ ] Tester d'abord avec 2-3 instances pour valider la config
- [ ] Uploader dans le **workspace dédié stress test** — jamais en production
- [ ] Prévenir l'administrateur de la capacité (impact réel sur la capacité partagée)
- [ ] Noter l'heure exacte de début et de fin du test (nécessaire pour l'analyse GCP)
- [ ] Vérifier que les **RLS** (Row Level Security) sont bien appliquées si présentes

### Pendant le test

- [ ] Surveiller la fenêtre Live Metrics
- [ ] Maintenir le CPU machine < 80% pour des résultats fiables
- [ ] Pour les tests > 60 min : rafraîchir le token toutes les 50 min

### Après le test

- [ ] Supprimer le rapport du workspace de test dans les **7 jours**
- [ ] Attendre 24h puis lancer la requête BigQuery de capacité
- [ ] Exporter `logPage.csv` et partager avec l'équipe pour analyse
- [ ] Documenter les résultats dans ce dossier avec la convention : `YYYYMMDD_NomRapport_Résultats.md`

### Nommage des tests

```
YYYYMMDD_NomEquipe_Objet_NbInstances
Exemples :
  20260305_PBICOE_NERD_Stress_10users
  20260310_DGAF_Dashboard_Perf_5users
```

---

## 9. Dépannage

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| Chrome s'ouvre mais le rapport ne charge pas | Token expiré | `.\Update_Token_Only.ps1` |
| "Waiting for log file..." dans la fenêtre métriques | Démarrage lent (normal) | Attendre 15-20 secondes |
| Chrome crash / système lent | Trop d'instances | Réduire les instances, fermer les autres applis |
| Durées > 20s sur toutes les instances | VPN actif ou capacité throttlée | Tester sans VPN, vérifier la capacité |
| Erreur "File cannot be loaded" | Politique PowerShell restrictive | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` |
| Résultats très variables entre runs | Cache, heure de test | Utiliser le P95, pas la moyenne ; tester à heure fixe |
| Aucune donnée dans BigQuery après 24h | Mauvais format de date ou mauvaise capacité | Vérifier le format `YYYY-MM-DD` et le nom de la capacité |

### Nettoyage après test

```powershell
# Fermer tous les Chrome
Get-Process chrome | Stop-Process -Force

# Supprimer les dossiers de test anciens (> 7 jours)
Get-ChildItem -Directory |
    Where {$_.Name -match '\d{2}-\d{2}-\d{4}' -and $_.CreationTime -lt (Get-Date).AddDays(-7)} |
    Remove-Item -Recurse -Force
```

---

## Contacts

| Besoin | Interlocuteur |
|--------|--------------|
| Fichiers du framework (ZIP) | Équipe BTDP Analytics |
| Accès workspace dédié stress test | Équipe BTDP Analytics |
| Admin des capacités Premium | Abdelkader (compte ADM) |
| Analyse résultats / script | Abdelkader |
| Questions gouvernance / COE | Matthieu BUREL |
