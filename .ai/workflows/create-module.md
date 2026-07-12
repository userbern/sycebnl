# Workflow: création d'un module

## Agents impliqués

- Orchestrateur
- Architecte
- Développeur Flutter
- Expert Riverpod
- Expert SQLite si le module touche aux données
- QA
- Reviewer

## Ordre d'exécution

1. Cadrage par l'Orchestrateur.
2. Validation de l'architecture cible.
3. Localisation du module dans la structure réelle du dépôt: `lib/pages`, `lib/widgets`, `lib/services`, `lib/models`, `lib/utils`.
4. Conception des couches et des dépendances.
5. Implémentation UI/état/données selon le besoin.
6. Validation fonctionnelle.
7. Revue finale.

## Critères de validation

- le module respecte Feature First;
- ou, s'il s'insère dans l'existant, il respecte la couche Flutter déjà en place sans réorganisation brutale;
- pas de SQL dans l'UI;
- providers et repositories séparés;
- composants réutilisables extraits;
- aucun effet de bord non documenté.

## Livrables

- structure du module;
- composants ou services nouveaux;
- notes d'intégration;
- validation QA;
- rapport final.
