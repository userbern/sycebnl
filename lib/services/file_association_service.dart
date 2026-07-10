import 'dart:io';

/// Association du fichier ".syca" avec l'application sous Windows, pour
/// qu'un double-clic sur un dossier comptable lance l'application et
/// l'ouvre directement (cf. `main.dart` qui lit les arguments de lancement).
///
/// Écrit uniquement dans `HKEY_CURRENT_USER\Software\Classes` (aucun droit
/// administrateur requis, n'affecte que l'utilisateur courant), via la
/// commande `reg.exe` intégrée à Windows — aucune dépendance supplémentaire.
/// L'icône du fichier réutilise celle de l'exécutable (déjà le logo officiel,
/// cf. `flutter_launcher_icons` dans pubspec.yaml).
class FileAssociationService {
  FileAssociationService._();

  static const String _progId = 'SYCEBNL.AccountingFile';
  static const String _extensionKey = r'HKCU\Software\Classes\.syca';
  static String get _progIdCommandKey =>
      'HKCU\\Software\\Classes\\$_progId\\shell\\open\\command';
  static String get _progIdIconKey =>
      'HKCU\\Software\\Classes\\$_progId\\DefaultIcon';

  /// Enregistre l'association si elle n'est pas déjà correcte pour
  /// l'exécutable courant. Ne fait rien hors Windows. N'échoue jamais de
  /// façon bloquante : toute erreur est silencieusement ignorée (l'absence
  /// d'association n'empêche pas l'utilisation normale de l'application).
  static Future<void> registerIfNeeded() async {
    if (!Platform.isWindows) return;
    try {
      final exePath = Platform.resolvedExecutable;
      if (await _isAlreadyRegistered(exePath)) return;

      await Process.run('reg', [
        'add', _extensionKey,
        '/ve', '/d', _progId, '/f',
      ]);
      await Process.run('reg', [
        'add', _progIdIconKey,
        '/ve', '/d', '"$exePath",0', '/f',
      ]);
      await Process.run('reg', [
        'add', _progIdCommandKey,
        '/ve', '/d', '"$exePath" "%1"', '/f',
      ]);
    } catch (_) {
      // Association non critique : on n'interrompt jamais le démarrage.
    }
  }

  static Future<bool> _isAlreadyRegistered(String exePath) async {
    try {
      final result = await Process.run('reg', ['query', _progIdCommandKey, '/ve']);
      if (result.exitCode != 0) return false;
      return (result.stdout as String).contains(exePath);
    } catch (_) {
      return false;
    }
  }
}
