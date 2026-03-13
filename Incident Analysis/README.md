# Incident Analysis — Power BI COE

> Ce dossier centralise l'analyse des incidents Power BI / Fabric,
> les best practices et le troubleshooting guide pour l'equipe COE.

## Structure

```
Incident Analysis/
├── README.md                              ← Ce fichier
├── incidents/
│   └── INC10281567-nefapbtdpcommunity2.md ← Fiches incidents (1 par incident)
├── templates/
│   └── incident-template.md               ← Template pour nouveaux incidents
├── Best_Practices_Capacity_Management.md  ← Best practices Confluence-ready
└── Troubleshooting_Guide.md               ← Guide de resolution Confluence-ready
```

## Processus incident COE

1. **Detection** : alerte CU > 80%, signalement utilisateur, ou Teams OA Analytics
2. **Qualification** : ouvrir une fiche dans `incidents/` a partir du template
3. **Diagnostic** : utiliser le Troubleshooting Guide + audit MCP si possible
4. **Resolution** : appliquer les actions correctives
5. **Post-mortem** : completer la fiche incident, alimenter les best practices
