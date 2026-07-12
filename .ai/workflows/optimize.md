# Workflow: optimisation

## Agents impliqués

- Orchestrateur
- Architecte
- Expert SQLite si la donnée est concernée
- Expert Riverpod si l'état est concerné
- Reviewer
- QA

## Ordre d'exécution

1. Identifier le goulot.
2. Choisir l'optimisation utile et mesurable.
3. Modifier la couche concernée dans la structure réelle du dépôt.
4. Contrôler les effets de bord.
5. Valider.

## Critères de validation

- optimisation mesurable ou au moins justifiée;
- pas de complexité inutile;
- alignement avec la couche concernée du dépôt;
- comportement préservé.

## Livrables

- optimisation appliquée;
- justification;
- impact attendu;
- rapport final.
