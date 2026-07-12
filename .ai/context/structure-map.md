# Carte de structure réelle du dépôt

Le projet n'est pas organisé ici comme un monolithe feature-first strict.
Le code existant suit surtout une structuration par couches sous `lib/`.

## Entrée

- `lib/main.dart`: point d'entrée Flutter et bootstrap desktop.

## Interface utilisateur

- `lib/pages/`: écrans et flux de navigation;
- `lib/widgets/`: composants UI réutilisables;
- `lib/widgets/company_header_card.dart`: exemple de composant réutilisable déjà présent.

## Données et logique technique

- `lib/services/`: accès base de données, export, sécurité, fichiers et services transverses;
- `lib/models/`: modèles métier et structures de données;
- `lib/utils/`: constantes, aides et utilitaires partagés.

## Règle d'alignement

- une demande UI commence en priorité dans `lib/pages` ou `lib/widgets`;
- une demande d'accès données commence dans `lib/services`;
- une demande de structure métier commence dans `lib/models` ou dans le service qui la consomme;
- une évolution transversale doit rester compatible avec l'existant, sans réorganisation brutale.
