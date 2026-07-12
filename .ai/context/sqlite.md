# Règles SQLite

## Périmètre

- schéma;
- index;
- vues;
- triggers;
- migrations;
- optimisation des requêtes.

## Bonnes pratiques

- aucune logique SQL dans les widgets;
- requêtes concentrées dans les repositories ou un service de données;
- migrations versionnées et reproductibles;
- index ajoutés pour les parcours réellement utilisés;
- requêtes documentées lorsqu'elles portent une règle métier importante.
