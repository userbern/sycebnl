# Système agentique

## Vue d'ensemble

Le système est conçu comme une équipe de développement spécialisée.

Il s'aligne sur la structure réelle du dépôt Flutter: `lib/pages`, `lib/widgets`, `lib/services`, `lib/models`, `lib/utils`.

### Rôle des couches

- `context/`: informations partagées par tous les agents;
- `rules/`: contraintes obligatoires;
- `memory/`: décisions persistantes;
- `agents/`: contrat de chaque agent;
- `prompts/`: prompt système prêt à l'emploi;
- `workflows/`: procédures réutilisables;
- `templates/`: formats normalisés;
- `reports/`: sorties finales standardisées.

## Flux de travail recommandé

1. L'utilisateur formule une demande.
2. L'orchestrateur charge le contexte et les règles.
3. Il découpe le travail en tâches atomiques.
4. Il assigne les tâches aux agents spécialisés.
5. Les agents produisent leurs livrables.
6. Le reviewer ou la QA valident selon le besoin.
7. L'orchestrateur consolide le résultat et la mémoire.

## Réduction des tokens

- ne jamais répéter le contexte complet si un fichier de contexte existe;
- référencer les décisions stables plutôt que les réexpliquer;
- conserver des templates pour les sorties récurrentes;
- utiliser des workflows standard au lieu de reformuler les étapes.
