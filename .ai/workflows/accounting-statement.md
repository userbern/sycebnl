# Workflow: création d'un état comptable

## Agents impliqués

- Orchestrateur
- Expert Comptable SYCEBNL
- Expert Impression
- Expert SQLite si les agrégations changent
- Expert Riverpod si un état est piloté par l'état applicatif
- QA
- Reviewer

## Ordre d'exécution

1. Définir l'état attendu et ses règles.
2. Valider les agrégations et regroupements.
3. Concevoir le stockage ou la requête source dans la couche adaptée du dépôt.
4. Construire le rendu ou l'export.
5. Vérifier la conformité métier.

## Critères de validation

- état fidèle au métier;
- données cohérentes;
- rendu clair;
- intégration respectueuse des couches existantes;
- pas de calcul caché dans l'UI.

## Livrables

- état comptable;
- règles de calcul documentées;
- validation métier;
- rapport final.
