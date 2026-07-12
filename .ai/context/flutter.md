# Règles Flutter

## UI

- Desktop First;
- Material 3 obligatoire;
- composants réutilisables avant les variantes locales;
- dialogs, tables et formulaires doivent rester cohérents sur desktop.

## Architecture UI

- éviter la logique métier dans les widgets;
- extraire les sections de page en widgets dédiés;
- garder les widgets lisibles et testables;
- gérer l'état via Riverpod ou un équivalent déjà adopté dans le projet.

## Responsabilité

- l'agent Flutter ne modifie pas les règles métier;
- il ne rédige pas de SQL;
- il se concentre sur présentation, navigation, interactions et responsive.
