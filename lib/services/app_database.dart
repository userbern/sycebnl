import '../utils/app_constants.dart';
import 'database_service.dart';

/// Façade autour de [DatabaseService] centralisant les conventions liées à
/// l'extension des dossiers comptables ([databaseExtension]). Ne duplique
/// aucune logique SQL : toutes les opérations réelles restent dans
/// [DatabaseService] (sqflite/sqlite3 ne se soucient pas de l'extension du
/// fichier, seul le nommage/la présentation change ici).
class AppDatabase {
  AppDatabase._();

  /// Vérifie si [path] est un fichier de dossier comptable (extension
  /// [databaseExtension], insensible à la casse).
  static bool isAccountingFile(String path) {
    return path.toLowerCase().endsWith(databaseExtension.toLowerCase());
  }

  /// Crée un nouveau dossier comptable à [path]. [path] doit déjà se
  /// terminer par [databaseExtension] (validé par les sélecteurs de
  /// fichiers en amont) ; délègue entièrement à
  /// [DatabaseService.createDatabase].
  static Future<void> createAccountingFile(
    String path, {
    String? adminLogin,
    String? adminPassword,
    Map<String, dynamic>? entiteData,
    Map<String, dynamic>? exerciceData,
    Map<String, dynamic>? configData,
  }) {
    return DatabaseService.createDatabase(
      path,
      adminLogin: adminLogin,
      adminPassword: adminPassword,
      entiteData: entiteData,
      exerciceData: exerciceData,
      configData: configData,
    );
  }

  /// Ouvre un dossier comptable existant à [path] (délègue à
  /// [DatabaseService.openDatabase]). [path] peut être un fichier `.syca`
  /// non chiffré, ou le chemin temporaire déjà déchiffré d'un dossier
  /// chiffré (cf. `password_login_page.dart`).
  static Future<void> openAccountingFile(String path) {
    return DatabaseService.openDatabase(path);
  }
}
