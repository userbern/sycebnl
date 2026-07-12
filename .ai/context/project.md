# Vue projet

## Résumé

SYCEBNL Accounting est une application desktop Flutter déjà avancée, organisée aujourd'hui surtout en couches sous `lib/` (`pages/`, `widgets/`, `services/`, `models/`, `utils/`).

L'objectif du système agentique est de travailler avec cette structure réelle, tout en permettant une évolution progressive vers des découpages plus fins si nécessaire.

## Contraintes d'intégration

- ne pas casser l'architecture actuelle;
- travailler en ajoutant des couches et non en remplaçant brutalement l'existant;
- respecter en priorité les dossiers déjà présents dans `lib/`;
- garder les modifications locales et lisibles;
- éviter les duplications de logique et de composants;
- privilégier les abstractions déjà présentes dans le projet.

## Priorités produit

- accélérer la livraison des fonctionnalités restantes;
- garder une base de code cohérente;
- préserver la maintenabilité à long terme;
- maintenir la conformité métier SYCEBNL.
