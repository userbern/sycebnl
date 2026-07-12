# Workflow: ajout d'une fonctionnalité

## Agents impliqués

- Orchestrateur
- Expert Comptable SYCEBNL si le sujet est métier
- Développeur Flutter
- Expert Riverpod
- Expert SQLite si nécessaire
- QA
- Reviewer

## Ordre d'exécution

1. Compréhension de la demande.
2. Identification des contraintes métier et UI.
3. Repérage des points d'entrée réels dans `lib/pages`, `lib/widgets`, `lib/services` et `lib/models`.
4. Conception de la solution minimale cohérente.
5. Implémentation par couche.
6. Vérification fonctionnelle.
7. Revue.

## Critères de validation

- fonctionnalité conforme au besoin;
- fichiers modifiés alignés sur les couches existantes;
- pas de rupture d'architecture;
- composants réutilisables si pertinents;
- absence de logique métier dans les widgets;
- validation métier si impact SYCEBNL.

## Livrables

- implémentation;
- points de vérification;
- cas de test;
- rapport final.
