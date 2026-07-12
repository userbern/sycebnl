# Règles Riverpod

## Principes

- privilégier des providers orientés cas d'usage;
- séparer l'état de l'UI;
- injecter les dépendances via providers plutôt que via globals;
- isoler les repositories derrière des abstractions claires.

## Attentes

- l'état doit être prévisible;
- les effets de bord doivent être regroupés dans des services ou repositories;
- les providers doivent être nommés de façon explicite;
- éviter les dépendances circulaires entre providers.
