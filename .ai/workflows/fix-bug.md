# Workflow: correction d'un bug

## Agents impliqués

- Orchestrateur
- Agent spécialisé selon la zone touchée
- QA
- Reviewer

## Ordre d'exécution

1. Reproduire ou décrire précisément le bug.
2. Localiser la couche fautive dans `lib/pages`, `lib/widgets`, `lib/services`, `lib/models` ou `lib/utils`.
3. Corriger au plus près de la cause.
4. Vérifier l'absence de régression.
5. Rédiger le rapport final.

## Critères de validation

- bug reproduit puis corrigé;
- correctif local et minimal;
- correctif dans la couche réellement concernée;
- pas de régression fonctionnelle;
- cause racine documentée.

## Livrables

- correctif;
- explication de cause racine;
- scénario de vérification;
- rapport final.
