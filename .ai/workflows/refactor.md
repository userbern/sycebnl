# Workflow: refactoring

## Agents impliqués

- Orchestrateur
- Architecte
- Agent concerné par la couche ciblée
- Reviewer
- QA si le comportement peut changer

## Ordre d'exécution

1. Définir le motif de refactor.
2. Identifier ce qui est conservé.
3. Cibler les fichiers concrets dans `lib/pages`, `lib/widgets`, `lib/services`, `lib/models` ou `lib/utils`.
4. Extraire ou simplifier sans changer le comportement.
5. Vérifier la compatibilité.
6. Revue.

## Critères de validation

- comportement inchangé sauf demande contraire;
- moins de duplication;
- meilleure lisibilité;
- aucun déplacement de responsabilité entre couches sans justification;
- architecture plus stable.

## Livrables

- refactor ciblé;
- justification;
- risques résiduels;
- rapport final.
