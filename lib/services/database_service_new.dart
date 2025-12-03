import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'database_service.dart' as old_service;
import '../models/tiers.dart';
import '../models/compte.dart';

/// Service pour gérer le fichier comptable (base de données SQLite)
/// Ce service délègue à database_service.dart pour partager la même connexion
class DatabaseService {
  /// S'assurer que la base est ouverte avant toute requête
  static Future<void> ensureDatabaseOpen() async {
    if (!old_service.DatabaseService.isConnected) {
      print('⚠️ DEBUG: Base fermée, tentative de réouverture...');
      final dbPath = old_service.DatabaseService.currentDatabasePath;
      if (dbPath != null) {
        print('🔓 DEBUG: Réouverture de la base: $dbPath');
        await old_service.DatabaseService.connectToDatabase(dbPath);
      } else {
        print('❌ DEBUG: Impossible de rouvrir, chemin inconnu');
        throw Exception('Chemin de base de données inconnu');
      }
    } else {
      print('✅ DEBUG: Base déjà ouverte');
    }
  }

  /// Obtenir le chemin de la base de données actuelle
  static String? get currentDatabasePath =>
      old_service.DatabaseService.currentDatabasePath;

  /// Obtenir la base de données actuelle
  static Database get database => old_service.DatabaseService.database;

  /// Initialiser SQLite FFI
  static Future<void> initializeFfi() async {
    return old_service.DatabaseService.initializeFfi();
  }

  /// Ouvrir une base de données existante (délègue à connectToDatabase de l'ancien service)
  static Future<void> openDatabase(String databasePath) async {
    return old_service.DatabaseService.connectToDatabase(databasePath);
  }

  /// Vérifier le mot de passe et retourner l'utilisateur
  /// Note: cherche dans la table 'utilisateur' (pas 'users')
  static Future<Map<String, dynamic>?> verifyLogin(
    String login,
    String password,
  ) async {
    try {
      final users = await database.query(
        'utilisateur',
        where: 'login = ? AND deleted_at IS NULL',
        whereArgs: [login],
        limit: 1,
      );

      if (users.isEmpty) return null;

      final user = users.first;
      final storedHash = user['password'] as String;

      if (verifyPasswordHash(password, storedHash)) {
        return user;
      }

      return null;
    } catch (e) {
      print('❌ DEBUG verifyLogin error: $e');
      return null;
    }
  }

  /// Vérifier si le fichier nécessite un mot de passe
  static Future<bool> requiresPassword(String databasePath) async {
    try {
      // Si c'est le fichier déjà ouvert, utiliser la connexion existante
      if (old_service.DatabaseService.isConnected &&
          old_service.DatabaseService.currentDatabasePath == databasePath) {
        final users = await database.query('utilisateur', limit: 1);
        return users.isNotEmpty;
      }

      // Sinon, ouvrir temporairement pour vérifier
      await initializeFfi();
      final db = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true),
      );

      // Vérifier s'il y a des utilisateurs dans la table 'utilisateur'
      final users = await db.query('utilisateur', limit: 1);
      await db.close();

      return users.isNotEmpty;
    } catch (e) {
      print('⚠️ DEBUG requiresPassword error: $e');
      return false;
    }
  }

  /// Obtenir la configuration du fichier
  /// Note: l'ancien service n'a pas de table 'config', retourne null
  static Future<Map<String, dynamic>?> getConfig() async {
    try {
      await ensureDatabaseOpen();
      // Essayer de lire depuis la table config si elle existe
      final results = await database.query('config', limit: 1);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('⚠️ DEBUG: Table config not found, returning null');
      return null;
    }
  }

  /// Obtenir les données de l'entité
  static Future<Map<String, dynamic>?> getEntite() async {
    try {
      print('🔍 DEBUG getEntite: Vérification de l\'état de la base...');
      print('   - isConnected: ${old_service.DatabaseService.isConnected}');
      print(
        '   - currentPath: ${old_service.DatabaseService.currentDatabasePath}',
      );

      await ensureDatabaseOpen();

      print('🔍 DEBUG getEntite: Tentative de requête...');
      final results = await database.query('entite', limit: 1);
      print(
        '✅ DEBUG getEntite: Requête réussie, ${results.length} résultat(s)',
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('❌ DEBUG getEntite error: $e');
      print('   Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Mettre à jour l'entité (une seule entité par fichier)
  static Future<void> updateEntite(Map<String, dynamic> entiteData) async {
    await ensureDatabaseOpen();
    final entite = await getEntite();
    if (entite == null) {
      throw Exception('Aucune entité trouvée dans ce fichier');
    }

    await database.update(
      'entite',
      {...entiteData, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [entite['id']],
    );
  }

  /// Obtenir tous les exercices comptables
  static Future<List<Map<String, dynamic>>> getExercices() async {
    try {
      await ensureDatabaseOpen();
      final results = await database.query(
        'exercice',
        orderBy: 'date_debut DESC',
      );
      return results;
    } catch (e) {
      print('❌ DEBUG getExercices error: $e');
      return [];
    }
  }

  /// Changer l'exercice actif
  static Future<void> setActiveExercice(int exerciceId) async {
    await ensureDatabaseOpen();

    // Désactiver tous les exercices
    await database.update('exercice', {
      'is_active': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Activer l'exercice sélectionné
    await database.update(
      'exercice',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [exerciceId],
    );
  }

  /// Créer un nouvel exercice comptable
  static Future<void> createExercice({
    required String code,
    required String dateDebut,
    required String dateFin,
    required int dureeMois,
    bool reportSoldes = false,
  }) async {
    await ensureDatabaseOpen();

    // Vérifier qu'on n'a pas déjà 5 exercices
    final exercices = await getExercices();
    if (exercices.length >= 5) {
      throw Exception('Maximum 5 exercices par fichier comptable');
    }

    // Vérifier que le code n'existe pas déjà
    final existing = exercices.where((e) => e['code'] == code);
    if (existing.isNotEmpty) {
      throw Exception('Un exercice avec ce code existe déjà');
    }

    // Insérer le nouvel exercice
    await database.insert('exercice', {
      'code': code,
      'date_debut': dateDebut,
      'date_fin': dateFin,
      'duree_mois': dureeMois,
      'is_active': 0, // Par défaut non actif
      'is_cloture': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // TODO: Si reportSoldes est true, copier les soldes de l'exercice précédent
  }

  /// Créer une nouvelle base de données (délègue à l'ancien service)
  static Future<void> createDatabase({
    required String databasePath,
    required Map<String, dynamic> entiteData,
    required Map<String, dynamic> configData,
    required Map<String, dynamic> exerciceData,
    String? login,
    String? password,
  }) async {
    // Déléguer à l'ancien service avec toutes les données
    return old_service.DatabaseService.createDatabase(
      databasePath,
      adminLogin: login,
      adminPassword: password,
      entiteData: entiteData,
      exerciceData: exerciceData,
      configData: configData,
    );
  }

  /// Hasher un mot de passe
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Vérifier un mot de passe
  static bool verifyPasswordHash(String password, String hash) {
    return hashPassword(password) == hash;
  }

  /// Récupérer tous les utilisateurs
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    await ensureDatabaseOpen();
    return await database.query(
      'utilisateur',
      where: 'deleted_at IS NULL',
      orderBy: 'login ASC',
    );
  }

  /// Créer un nouvel utilisateur
  static Future<int> createUser({
    required String login,
    String? description,
    String? role,
    String? password,
  }) async {
    await ensureDatabaseOpen();

    // Vérifier si le login existe déjà
    final existing = await database.query(
      'utilisateur',
      where: 'login = ? AND deleted_at IS NULL',
      whereArgs: [login],
    );

    if (existing.isNotEmpty) {
      throw Exception('Un utilisateur avec ce login existe déjà');
    }

    return await database.insert('utilisateur', {
      'login': login,
      'password': password != null ? hashPassword(password) : null,
      'role': role ?? 'utilisateur',
      'nom': description ?? '',
      'prenom': '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Mettre à jour un utilisateur
  static Future<void> updateUser({
    required int userId,
    String? login,
    String? description,
    String? role,
  }) async {
    await ensureDatabaseOpen();

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (login != null) updates['login'] = login;
    if (description != null) updates['nom'] = description;
    if (role != null) updates['role'] = role;

    await database.update(
      'utilisateur',
      updates,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Supprimer un utilisateur (soft delete)
  static Future<void> deleteUser(int userId) async {
    await ensureDatabaseOpen();

    await database.update(
      'utilisateur',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Changer le mot de passe
  static Future<void> changePassword({
    int? userId,
    String? oldPassword,
    required String newPassword,
    required bool isAdmin,
  }) async {
    await ensureDatabaseOpen();

    // Si admin, pas besoin de vérifier l'ancien mot de passe
    if (!isAdmin && oldPassword != null && userId != null) {
      final user = await database.query(
        'utilisateur',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (user.isEmpty) {
        throw Exception('Utilisateur non trouvé');
      }

      final storedHash = user.first['password'] as String?;
      if (storedHash != null && !verifyPasswordHash(oldPassword, storedHash)) {
        throw Exception('Ancien mot de passe incorrect');
      }
    }

    // Mettre à jour le mot de passe
    final targetUserId = userId ?? 1; // Si null, mettre à jour l'utilisateur 1
    await database.update(
      'utilisateur',
      {
        'password': hashPassword(newPassword),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [targetUserId],
    );
  }

  // ===== MÉTHODES POUR GÉRER LES COMPTES =====

  /// Récupérer tous les comptes actifs
  static Future<List<Compte>> getAllComptes() async {
    await ensureDatabaseOpen();

    final results = await database.query(
      'compte',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'numero_compte ASC',
    );

    return results.map((map) => Compte.fromMap(map)).toList();
  }

  /// Créer un nouveau compte
  static Future<void> createCompte({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String nature,
    bool liaisonTiers = false,
    String? description,
  }) async {
    await ensureDatabaseOpen();

    // Vérifier si le numéro existe déjà (actif ou inactif)
    final existing = await database.query(
      'compte',
      where: 'numero_compte = ?',
      whereArgs: [numeroCompte],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('Un compte avec ce numéro existe déjà');
    }

    await database.insert('compte', {
      'numero_compte': numeroCompte,
      'intitule': intitule,
      'type': type,
      'nature': nature,
      'liaison_tiers': liaisonTiers ? 1 : 0,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Modifier un compte existant
  static Future<void> updateCompte({
    required String compteId,
    required String numeroCompte,
    required String intitule,
    required String type,
    required String nature,
    bool liaisonTiers = false,
    String? description,
  }) async {
    await ensureDatabaseOpen();

    // Vérifier si le numéro existe déjà (sauf pour ce compte, et actif ou inactif)
    final existing = await database.query(
      'compte',
      where: 'numero_compte = ? AND id != ?',
      whereArgs: [numeroCompte, compteId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('Un autre compte avec ce numéro existe déjà');
    }

    await database.update(
      'compte',
      {
        'numero_compte': numeroCompte,
        'intitule': intitule,
        'type': type,
        'nature': nature,
        'liaison_tiers': liaisonTiers ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [compteId],
    );
  }

  /// Supprimer un compte (désactivation)
  static Future<void> deleteCompte(String compteId) async {
    await ensureDatabaseOpen();

    await database.update(
      'compte',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [compteId],
    );
  }

  /// Récupérer la configuration du fichier
  static Future<Map<String, dynamic>?> getFileConfig() async {
    await ensureDatabaseOpen();

    try {
      final results = await database.query('config', limit: 1);
      if (results.isEmpty) return null;

      return results.first;
    } catch (e) {
      // Si la table n'existe pas, retourner null
      print('⚠️ Erreur getFileConfig: $e');
      return null;
    }
  }

  // ==================== GESTION DES TIERS ====================

  /// Récupérer tous les tiers actifs
  static Future<List<Tiers>> getAllTiers() async {
    await ensureDatabaseOpen();

    final results = await database.query(
      'tiers',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'numero_compte ASC',
    );

    return results.map((map) => Tiers.fromMap(map)).toList();
  }

  /// Créer un nouveau tiers
  static Future<void> createTiers(
    String numeroCompte,
    String intitule,
    String type,
    String compteCollectif,
    String? nif,
    String? adresse,
  ) async {
    await ensureDatabaseOpen();

    // Vérifier l'unicité du numéro de compte
    final existing = await database.query(
      'tiers',
      where: 'numero_compte = ? AND is_active = 1',
      whereArgs: [numeroCompte],
    );

    if (existing.isNotEmpty) {
      throw Exception('Un tiers avec ce numéro de compte existe déjà');
    }

    await database.insert('tiers', {
      'numero_compte': numeroCompte,
      'intitule': intitule,
      'type': type,
      'compte_collectif': compteCollectif,
      'nif': nif,
      'adresse': adresse,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Modifier un tiers existant
  static Future<void> updateTiers(
    int tiersId,
    String numeroCompte,
    String intitule,
    String type,
    String compteCollectif,
    String? nif,
    String? adresse,
  ) async {
    await ensureDatabaseOpen();

    // Vérifier l'unicité (sauf pour le tiers en cours de modification)
    final existing = await database.query(
      'tiers',
      where: 'numero_compte = ? AND is_active = 1 AND id != ?',
      whereArgs: [numeroCompte, tiersId],
    );

    if (existing.isNotEmpty) {
      throw Exception('Un autre tiers avec ce numéro de compte existe déjà');
    }

    await database.update(
      'tiers',
      {
        'numero_compte': numeroCompte,
        'intitule': intitule,
        'type': type,
        'compte_collectif': compteCollectif,
        'nif': nif,
        'adresse': adresse,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tiersId],
    );
  }

  /// Supprimer un tiers (désactivation)
  static Future<void> deleteTiers(int tiersId) async {
    await ensureDatabaseOpen();

    await database.update(
      'tiers',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [tiersId],
    );
  }
}
