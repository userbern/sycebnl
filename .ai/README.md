# AI Operating System

Ce dossier contient le système agentique du projet SYCEBNL Accounting.

Objectif:

- centraliser le contexte pour éviter les répétitions inutiles;
- séparer strictement les responsabilités par agent;
- fournir des workflows réutilisables pour accélérer le développement;
- garder une mémoire évolutive des décisions de projet;
- permettre un usage quotidien avec Codex sans toucher à l'architecture Flutter existante.

Ce système est aligné sur la structure réelle du dépôt, centrée sous `lib/` autour de `pages/`, `widgets/`, `services/`, `models/` et `utils/`.

## Principe de fonctionnement

1. L'orchestrateur lit d'abord les contextes partagés.
2. Il choisit les agents spécialisés utiles à la demande.
3. Chaque agent ne traite que son périmètre.
4. Les livrables sont validés selon les règles globales et les workflows.
5. Les décisions importantes sont consignées dans la mémoire du projet.

## Arborescence

- `context/`: contexte partagé, architecture, stack, conventions, carte de structure, design system.
- `agents/`: contrat de chaque agent spécialisé.
- `prompts/`: prompts système prêts à être réutilisés.
- `workflows/`: déroulés opérationnels par type de demande.
- `tasks/`: modèles de tâches unitaires.
- `reports/`: modèles de compte-rendu.
- `rules/`: règles globales et règles métier techniques.
- `templates/`: canevas de documents et de sorties.
- `memory/`: décisions persistantes et journal d'évolution.
- `commands/`: commandes d'usage quotidien dans Codex.
- `docs/`: documentation d'exploitation du système.

## Ordre de lecture recommandé

1. `context/index.md`
2. `rules/global-rules.md`
3. `memory/decisions.md`
4. Prompt de l'agent concerné
5. Workflow associé

## Usage conseillé

Pour une nouvelle demande, l'orchestrateur doit produire:

- le contexte utile;
- la liste des agents mobilisés;
- le plan de travail;
- les validations attendues;
- le rapport final.

Les agents de spécialité ne doivent jamais élargir leur périmètre au-delà de leur contrat.
