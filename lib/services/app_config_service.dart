import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service pour gérer la configuration globale de l'application
/// Stocke les fichiers récents dans une base de données locale
class AppConfigService {
  static Database? _database;
  static String? _dbPath;

  /// Initialiser la base de données de configuration de l'application
  static Future<void> initialize() async {
    if (_database != null) return;

    // Initialiser sqflite_ffi pour Windows
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Obtenir le chemin AppData/Local/SYCEBNL
    final appDir = await getApplicationSupportDirectory();
    final configDir = Directory(path.join(appDir.path, 'SYCEBNL'));

    // Créer le dossier s'il n'existe pas
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    _dbPath = path.join(configDir.path, 'app_config.db');

    // Ouvrir/créer la base de données
    _database = await databaseFactory.openDatabase(
      _dbPath!,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
  }

  /// Créer les tables de configuration
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recent_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        last_opened TEXT NOT NULL,
        has_password INTEGER DEFAULT 0
      )
    ''');
  }

  /// Obtenir la base de données
  static Database get database {
    if (_database == null) {
      throw Exception(
        'AppConfigService non initialisé. Appelez initialize() d\'abord.',
      );
    }
    return _database!;
  }

  /// Ajouter ou mettre à jour un fichier récent
  static Future<void> addRecentFile({
    required String filePath,
    required String fileName,
    required bool hasPassword,
  }) async {
    await database.insert('recent_files', {
      'file_path': filePath,
      'file_name': fileName,
      'last_opened': DateTime.now().toIso8601String(),
      'has_password': hasPassword ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Obtenir la liste des fichiers récents (triés par date)
  static Future<List<Map<String, dynamic>>> getRecentFiles() async {
    final results = await database.query(
      'recent_files',
      orderBy: 'last_opened DESC',
      limit: 10,
    );
    return results;
  }

  /// Supprimer un fichier de la liste des fichiers récents
  static Future<void> removeRecentFile(String filePath) async {
    await database.delete(
      'recent_files',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Vérifier si un fichier existe dans la liste des récents
  static Future<bool> isRecentFile(String filePath) async {
    final results = await database.query(
      'recent_files',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
    return results.isNotEmpty;
  }

  /// Mettre à jour la date d'ouverture d'un fichier
  static Future<void> updateLastOpened(String filePath) async {
    await database.update(
      'recent_files',
      {'last_opened': DateTime.now().toIso8601String()},
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Nettoyer les fichiers qui n'existent plus sur le disque
  static Future<void> cleanupMissingFiles() async {
    final recentFiles = await getRecentFiles();
    for (var file in recentFiles) {
      final filePath = file['file_path'] as String;
      if (!await File(filePath).exists()) {
        await removeRecentFile(filePath);
      }
    }
  }

  /// Fermer la base de données
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
