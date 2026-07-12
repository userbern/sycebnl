# Workflow: ajout d'une permission

## Agents impliqués

- Orchestrateur
- Architecte
- Expert Riverpod
- Développeur Flutter
- Expert SQLite si la permission est persistée en base
- QA
- Reviewer

## Ordre d'exécution

1. Définir la permission et son périmètre.
2. Vérifier les impacts sur l'état et le stockage.
3. Implémenter l'UI et l'accès logique.
4. Valider les cas d'accès autorisé et refusé.
5. Revue finale.

## Critères de validation

- permission explicite;
- accès cohérent partout;
- pas de fuite de responsabilité;
- tests de refus inclus.

## Livrables

- modèle de permission;
- intégration UI/état/données;
- cas de test;
- rapport final.
