# Stack technique

## Socle

- Flutter desktop
- Dart 3.7
- Material 3
- Riverpod
- SQLite via `sqflite_common_ffi`
- PDF via `pdf`
- export tableur via `excel`

## Dépendances clés observées

- `path`
- `path_provider`
- `crypto`
- `file_picker`
- `window_manager`
- `cryptography`
- `uuid`

## Implications pour les agents

- l'UI doit rester compatible desktop;
- les accès base de données doivent rester isolés;
- l'état applicatif doit passer par des providers ou repositories;
- les exports doivent être pensés comme des services dédiés;
- les décisions de design doivent respecter Material 3 et le style desktop.
