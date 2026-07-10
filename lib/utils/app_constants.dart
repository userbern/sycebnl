/// Extension de fichier utilisée pour les dossiers comptables créés par
/// l'application. L'utilisateur ne doit jamais manipuler de fichier ".db"
/// directement — en interne, le fichier reste une base SQLite valide,
/// seule l'extension visible change. Modifier cette constante suffit à
/// changer l'extension partout dans l'application.
const String databaseExtension = '.syca';

/// [databaseExtension] sans le point, pour les `allowedExtensions` de
/// `file_picker` (qui n'accepte pas le point).
const String databaseExtensionNoDot = 'syca';
