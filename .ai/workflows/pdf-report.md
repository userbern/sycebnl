# Workflow: génération d'un rapport PDF

## Agents impliqués

- Orchestrateur
- Expert Comptable SYCEBNL
- Expert Impression
- Développeur Flutter si une UI de lancement existe
- QA
- Reviewer

## Ordre d'exécution

1. Valider les données métier à exporter.
2. Définir la structure du document.
3. Localiser les points d'intégration réels dans `lib/services/export_service.dart` et les widgets de prévisualisation si nécessaires.
4. Implémenter le rendu ou l'adaptation nécessaire.
5. Vérifier la lisibilité et la pagination.
6. Valider le contenu avec le métier.

## Critères de validation

- document fidèle aux données;
- pagination correcte;
- rendu lisible;
- intégration conforme au service d'export existant;
- conformité métier.

## Livrables

- export PDF;
- points de contrôle;
- cas de test;
- rapport final.
