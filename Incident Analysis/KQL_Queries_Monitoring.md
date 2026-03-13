# KQL Queries — Monitoring Capacite Fabric / Power BI

> Requetes KQL a executer dans **Fabric Monitoring Hub**.
> Acces : app.fabric.microsoft.com > Monitoring Hub > KQL (accessible depuis n'importe quel workspace)
>
> Remplacer `<CAPACITY_ID>` par le GUID de la capacite ciblee.
> Exemple : `799dde1d-a775-4a11-b4ea-d03da356b009` = nefapbtdpcommunity2
>
> Remplacer `<EMAIL>` par l'adresse email de l'utilisateur a filtrer.
>
> Derniere mise a jour : 2026-03-13

---

## Colonnes disponibles (table SemanticModelLogs)

```
Timestamp, OperationName, ItemId, ItemKind, ItemName, WorkspaceId,
WorkspaceName, CapacityId, CorrelationId, OperationId, Identity,
CustomerTenantId, DurationMs, Status, Level, Region, Category,
CallerIpAddress, ApplicationName, DatasetMode, EventText,
OperationDetailName, ProgressCounter, ReplicaId, StatusCode,
User, XmlaObjectPath, CpuTimeMs, ExecutingUser
```

---

## 1. Vue globale — Etat de la capacite

### 1.1 Resume des 2 dernieres heures

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    Failures = countif(Status == "Failure"),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1),
    AvgDurationMs = round(avg(DurationMs), 0),
    MaxDurationMs = max(DurationMs),
    TotalCpuMs = sum(CpuTimeMs),
    Users = dcount(ExecutingUser)
```

### 1.2 Evolution CU par tranche de 5 minutes

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    Failures = countif(Status == "Failure"),
    AvgDurationMs = round(avg(DurationMs), 0),
    TotalCpuMs = sum(CpuTimeMs),
    Users = dcount(ExecutingUser)
    by bin(Timestamp, 5m)
| order by Timestamp desc
```

### 1.3 Evolution CU par heure sur 24h

```kql
SemanticModelLogs
| where Timestamp > ago(24h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by bin(Timestamp, 1h)
| order by Timestamp asc
```

---

## 2. Diagnostic — Identifier les coupables

### 2.1 Top 10 datasets par consommation CU

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    AvgDurationMs = round(avg(DurationMs), 0),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by ItemName
| order by TotalCpuMs desc
| take 10
```

### 2.2 Top 10 datasets par taux d'echec

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Total = count(),
    Failed = countif(Status == "Failure")
    by ItemName, WorkspaceName
| extend FailRate = round(100.0 * Failed / Total, 1)
| where Total > 5
| order by FailRate desc
| take 10
```

### 2.3 Top 10 requetes les plus gourmandes

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| extend DurationSec = round(DurationMs / 1000.0, 1)
| extend CpuTimeSec = round(CpuTimeMs / 1000.0, 1)
| project Timestamp, ItemName, WorkspaceName, ExecutingUser, DurationSec, CpuTimeSec, Status
| order by CpuTimeSec desc
| take 10
```

### 2.4 Top 10 utilisateurs par consommation CU

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by ExecutingUser
| order by TotalCpuMs desc
| take 10
```

### 2.5 Top workspaces par consommation CU

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    Datasets = dcount(ItemName),
    Users = dcount(ExecutingUser),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by WorkspaceName
| order by TotalCpuMs desc
```

### 2.6 Detail par utilisateur (toutes colonnes)

```kql
// Remplacer <EMAIL> par l'adresse email de l'utilisateur
SemanticModelLogs
| where Timestamp > ago(24h)
| where CapacityId == "<CAPACITY_ID>"
| where ExecutingUser == "<EMAIL>"
| where OperationName == "QueryEnd"
| project
    Timestamp,
    ItemName,
    OperationName,
    ItemKind,
    WorkspaceName,
    EventText,
    OperationDetailName,
    DurationMs,
    CpuTimeMs,
    Status,
    StatusCode
| order by Timestamp desc
```

### 2.7 Resume par utilisateur et par dataset

```kql
SemanticModelLogs
| where Timestamp > ago(24h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    AvgDurationMs = round(avg(DurationMs), 0),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by ExecutingUser, ItemName
| order by TotalCpuMs desc
| take 20
```

---

## 3. Alertes — Detection proactive

### 3.1 Datasets avec taux d'echec > 10% (24h)

```kql
SemanticModelLogs
| where Timestamp > ago(24h)
| where OperationName == "QueryEnd"
| summarize
    Total = count(),
    Failed = countif(Status == "Failure")
    by ItemName, CapacityId, WorkspaceName
| extend FailRate = round(100.0 * Failed / Total, 1)
| where FailRate > 10
| where Total > 10
| order by FailRate desc
```

### 3.2 Requetes en echec sur la derniere heure (detail)

```kql
SemanticModelLogs
| where Timestamp > ago(1h)
| where OperationName == "QueryEnd"
| where Status == "Failure"
| project
    Timestamp,
    CapacityId,
    ItemName,
    WorkspaceName,
    ExecutingUser,
    DurationMs,
    CpuTimeMs,
    StatusCode
| order by Timestamp desc
```

### 3.3 Requetes depassant 2 minutes (signe de throttling)

```kql
SemanticModelLogs
| where Timestamp > ago(1h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| where DurationMs > 120000
| extend DurationSec = round(DurationMs / 1000.0, 1)
| project Timestamp, ItemName, ExecutingUser, DurationSec, Status, CpuTimeMs
| order by DurationSec desc
```

### 3.4 Pic d'utilisateurs simultanes

```kql
SemanticModelLogs
| where Timestamp > ago(2h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize Users = dcount(ExecutingUser) by bin(Timestamp, 1m)
| order by Users desc
| take 20
```

---

## 4. Refresh — Suivi des actualisations

### 4.1 Refresh en cours et recents

```kql
SemanticModelLogs
| where Timestamp > ago(4h)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName in ("ProcessEnd", "ProcessStart", "RefreshStart", "RefreshEnd")
| project Timestamp, ItemName, WorkspaceName, OperationName, Status, DurationMs
| order by Timestamp desc
```

### 4.2 Refresh les plus longs (7 jours)

```kql
SemanticModelLogs
| where Timestamp > ago(7d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "RefreshEnd"
| extend DurationMin = round(DurationMs / 60000.0, 1)
| project Timestamp, ItemName, WorkspaceName, DurationMin, Status
| order by DurationMin desc
| take 20
```

### 4.3 Refresh en echec (7 jours)

```kql
SemanticModelLogs
| where Timestamp > ago(7d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "RefreshEnd"
| where Status == "Failure"
| project Timestamp, ItemName, WorkspaceName, DurationMs, StatusCode
| order by Timestamp desc
```

---

## 5. Tendances — Analyse long terme

### 5.1 CU moyen par jour (30 jours)

```kql
SemanticModelLogs
| where Timestamp > ago(30d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Queries = count(),
    TotalCpuMs = sum(CpuTimeMs),
    AvgDurationMs = round(avg(DurationMs), 0),
    FailRate = round(100.0 * countif(Status == "Failure") / count(), 1)
    by bin(Timestamp, 1d)
| order by Timestamp asc
```

### 5.2 Evolution du taux d'echec par semaine

```kql
SemanticModelLogs
| where Timestamp > ago(90d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Total = count(),
    Failed = countif(Status == "Failure")
    by Week = startofweek(Timestamp)
| extend FailRate = round(100.0 * Failed / Total, 1)
| order by Week asc
```

### 5.3 Datasets avec consommation croissante

```kql
SemanticModelLogs
| where Timestamp > ago(14d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize TotalCpuMs = sum(CpuTimeMs)
    by ItemName, Week = startofweek(Timestamp)
| order by ItemName asc, Week asc
```

---

## 6. Audit de securite — Qui accede a quoi

### 6.1 Utilisateurs uniques par dataset (7 jours)

```kql
SemanticModelLogs
| where Timestamp > ago(7d)
| where CapacityId == "<CAPACITY_ID>"
| where OperationName == "QueryEnd"
| summarize
    Users = dcount(ExecutingUser),
    Queries = count()
    by ItemName, WorkspaceName
| order by Users desc
```

### 6.2 Activite d'un utilisateur specifique

```kql
// Remplacer <EMAIL> par l'adresse email
SemanticModelLogs
| where Timestamp > ago(24h)
| where ExecutingUser == "<EMAIL>"
| where OperationName == "QueryEnd"
| project Timestamp, ItemName, WorkspaceName, DurationMs, CpuTimeMs, Status
| order by Timestamp desc
```

---

## Aide-memoire

| Besoin | Requete |
|--------|---------|
| La capacite est-elle surchargee ? | 1.1 |
| Quel dataset cause le probleme ? | 2.1 + 2.2 |
| Qui consomme le plus ? | 2.4 |
| Detail d'un utilisateur ? | 2.6 |
| Resume utilisateur/dataset ? | 2.7 |
| Y a-t-il des requetes lentes ? | 3.3 |
| Les refresh sont-ils OK ? | 4.3 |
| La situation s'ameliore-t-elle ? | 5.1 |

## CapacityId connus

| Capacite | CapacityId (GUID) |
|----------|-------------------|
| nefapbtdpcommunity2 | `799dde1d-a775-4a11-b4ea-d03da356b009` |
