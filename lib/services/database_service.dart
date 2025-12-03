import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _database;
  static String? _currentDatabasePath;

  /// Obtenir le chemin de la base de données actuelle
  static String? get currentDatabasePath => _currentDatabasePath;

  /// Initialiser SQLite FFI pour Windows/Desktop
  static Future<void> initializeFfi() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /// Créer une nouvelle base de données à l'emplacement spécifié
  static Future<void> createDatabase(
    String databasePath, {
    String? adminLogin,
    String? adminPassword,
    Map<String, dynamic>? entiteData,
    Map<String, dynamic>? exerciceData,
    Map<String, dynamic>? configData,
  }) async {
    await initializeFfi();

    // Vérifier si le fichier existe déjà
    if (File(databasePath).existsSync()) {
      throw Exception('Une base de données existe déjà à cet emplacement');
    }

    // Créer le répertoire parent si nécessaire
    final directory = Directory(path.dirname(databasePath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    // Ouvrir/créer la base de données
    print('📂 DEBUG: Création de la base de données: $databasePath');
    _database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Créer les tables
          await _createTables(db);

          // Insérer les modules
          await db.insert('modules', {'nom': 'notre_entite'});
          await db.insert('modules', {'nom': 'parametrages'});
          await db.insert('modules', {'nom': 'traitements'});
          await db.insert('modules', {'nom': 'edition'});

          // Créer l'entité avec les données utilisateur
          if (entiteData != null) {
            await db.insert('entite', {
              ...entiteData,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'is_active': 1,
            });
          }

          // Créer le premier exercice comptable
          if (exerciceData != null) {
            await db.insert('exercice', {
              ...exerciceData,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'is_active': 1,
            });
          }

          // Enregistrer les longueurs de comptes
          if (configData != null) {
            await db.insert('config', {
              ...configData,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          }

          // Créer l'utilisateur admin par défaut si login et password fournis
          if (adminLogin != null &&
              adminLogin.isNotEmpty &&
              adminPassword != null &&
              adminPassword.isNotEmpty) {
            final hashedPassword = hashPassword(adminPassword);
            await db.insert('utilisateur', {
              'login': adminLogin,
              'password': hashedPassword,
              'nom': 'Administrateur',
              'prenom': 'Système',
              'role': 'admin',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            // Donner tous les droits à l'admin
            final adminId = await db.query(
              'utilisateur',
              where: 'login = ?',
              whereArgs: [adminLogin],
            );
            if (adminId.isNotEmpty) {
              final userId = adminId.first['id'];
              for (int moduleId = 1; moduleId <= 4; moduleId++) {
                await db.insert('permissions', {
                  'utilisateur_id': userId,
                  'module_id': moduleId,
                  'lecture': 1,
                  'ajout': 1,
                  'modification': 1,
                  'suppression': 1,
                });
              }
            }
          }
        },
      ),
    );

    _currentDatabasePath = databasePath;
    print('✅ DEBUG: Base de données créée et ouverte: $databasePath');
  }

  /// Se connecter à une base de données existante
  static Future<void> connectToDatabase(String databasePath) async {
    await initializeFfi();

    if (!File(databasePath).existsSync()) {
      throw Exception('Aucune base de données trouvée à cet emplacement');
    }

    print('📂 DEBUG: Connexion à la base de données: $databasePath');
    _database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onOpen: (db) async {
          // Migration: Corriger la table journal
          try {
            // Vérifier si la colonne numero_compte_tresorerie existe
            final columns = await db.rawQuery("PRAGMA table_info(journal)");
            final hasNumeroColumn = columns.any(
              (col) => col['name'] == 'numero_compte_tresorerie',
            );

            if (!hasNumeroColumn) {
              print(
                '🔄 Migration: Recréation de la table journal avec numero_compte_tresorerie',
              );

              // Sauvegarder les données existantes
              final journalData = await db.query('journal');

              // Supprimer l'ancienne table
              await db.execute('DROP TABLE IF EXISTS journal');

              // Créer la nouvelle table avec la bonne structure
              await db.execute('''
              CREATE TABLE journal (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE NOT NULL,
                libelle TEXT NOT NULL,
                type TEXT NOT NULL,
                numero_compte_tresorerie TEXT,
                saisie_analytique INTEGER DEFAULT 0,
                is_active INTEGER DEFAULT 1,
                created_at TEXT,
                updated_at TEXT,
                FOREIGN KEY (numero_compte_tresorerie) REFERENCES compte(numero_compte)
              )
            ''');

              // Réinsérer les données (sans numero_compte_tresorerie)
              for (var journal in journalData) {
                await db.insert('journal', {
                  'id': journal['id'],
                  'code': journal['code'],
                  'libelle': journal['libelle'],
                  'type': journal['type'],
                  'saisie_analytique': journal['saisie_analytique'],
                  'is_active': journal['is_active'],
                  'created_at': journal['created_at'],
                  'updated_at': journal['updated_at'],
                });
              }

              print('✅ Migration complétée');
            }
          } catch (e) {
            print('⚠️ Migration error: $e');
          }
        },
      ),
    );

    _currentDatabasePath = databasePath;
    print('✅ DEBUG: Base de données connectée: $databasePath');
  }

  /// Fermer la connexion à la base de données
  static Future<void> closeDatabase() async {
    if (_database != null) {
      print('🔒 DEBUG: Fermeture de la base de données: $_currentDatabasePath');
      await _database!.close();
      _database = null;
      _currentDatabasePath = null;
      print('❌ DEBUG: Base de données fermée');
    }
  }

  /// Obtenir l'instance de la base de données
  static Database get database {
    if (_database == null) {
      throw Exception(
        'Base de données non initialisée. Appelez connectToDatabase() ou createDatabase() d\'abord.',
      );
    }
    return _database!;
  }

  /// Vérifier si une base de données est connectée
  static bool get isConnected => _database != null;

  /// Hasher un mot de passe
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Vérifier un mot de passe
  static bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }

  /// Créer toutes les tables
  static Future<void> _createTables(Database db) async {
    // Table utilisateur
    await db.execute('''
      CREATE TABLE utilisateur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT DEFAULT 'utilisateur',
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // Table modules
    await db.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT UNIQUE NOT NULL
      )
    ''');

    // Table permissions
    await db.execute('''
      CREATE TABLE permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        utilisateur_id INTEGER NOT NULL,
        module_id INTEGER NOT NULL,
        lecture INTEGER DEFAULT 0,
        ajout INTEGER DEFAULT 0,
        modification INTEGER DEFAULT 0,
        suppression INTEGER DEFAULT 0,
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE CASCADE,
        FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE,
        UNIQUE (utilisateur_id, module_id)
      )
    ''');

    // Table entite
    await db.execute('''
      CREATE TABLE entite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        denomination_sociale TEXT NOT NULL,
        sigle_usuel TEXT,
        domaine_intervention TEXT,
        forme_juridique TEXT,
        ong_type TEXT,
        pays TEXT,
        region TEXT,
        ville TEXT,
        quartier TEXT,
        email TEXT,
        telephone TEXT,
        fixe_fax TEXT,
        numero_fiscal TEXT,
        numero_cnss TEXT,
        numero_recepisse TEXT,
        informations_complementaires TEXT,
        currency TEXT DEFAULT 'XOF',
        created_by INTEGER,
        created_at TEXT,
        updated_at TEXT,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (created_by) REFERENCES utilisateur(id)
      )
    ''');

    // Table monnaie
    /* await db.execute('''
      CREATE TABLE monnaie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        libelle TEXT NOT NULL,
        symbole TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    '''); */

    // Table compte
    await db.execute('''
      CREATE TABLE compte (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_compte TEXT UNIQUE NOT NULL,
        intitule TEXT NOT NULL,
        type TEXT NOT NULL,
        nature TEXT NOT NULL,
        liaison_tiers INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Table tiers
    await db.execute('''
      CREATE TABLE tiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_compte TEXT NOT NULL,
        intitule TEXT NOT NULL,
        type TEXT NOT NULL,
        compte_collectif TEXT NOT NULL,
        nif TEXT,
        adresse TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Table journal
    await db.execute('''
      CREATE TABLE journal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        libelle TEXT NOT NULL,
        type TEXT NOT NULL,
        numero_compte_tresorerie TEXT,
        saisie_analytique INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (numero_compte_tresorerie) REFERENCES compte(numero_compte)
      )
    ''');

    // Table bailleur
    await db.execute('''
      CREATE TABLE bailleur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sigle TEXT UNIQUE NOT NULL,
        designation TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // Table projet
    await db.execute('''
      CREATE TABLE projet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        designation TEXT NOT NULL,
        date_debut TEXT NOT NULL,
        date_fin TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // Table liaison projet-bailleur (plusieurs bailleurs par projet)
    await db.execute('''
      CREATE TABLE projet_bailleur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projet_id INTEGER NOT NULL,
        bailleur_id INTEGER NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
        FOREIGN KEY (bailleur_id) REFERENCES bailleur(id),
        UNIQUE (projet_id, bailleur_id)
      )
    ''');

    // Table budget (niveau 1 : Budget principal lié à projet + bailleur)
    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projet_id INTEGER NOT NULL,
        bailleur_id INTEGER NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
        FOREIGN KEY (bailleur_id) REFERENCES bailleur(id) ON DELETE CASCADE,
        UNIQUE (projet_id, bailleur_id)
      )
    ''');

    // Table poste_budgetaire (niveau 2 : Postes budgétaires d'un budget)
    await db.execute('''
      CREATE TABLE poste_budgetaire (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER NOT NULL,
        intitule TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (budget_id) REFERENCES budget(id) ON DELETE CASCADE
      )
    ''');

    // Table ligne_budgetaire (niveau 3 : Lignes budgétaires d'un poste)
    await db.execute('''
      CREATE TABLE ligne_budgetaire (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poste_budgetaire_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        intitule TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (poste_budgetaire_id) REFERENCES poste_budgetaire(id) ON DELETE CASCADE
      )
    ''');

    // Table sous_rubrique (niveau 4 : Sous-rubriques d'une ligne budgétaire)
    await db.execute('''
      CREATE TABLE sous_rubrique (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ligne_budgetaire_id INTEGER NOT NULL,
        intitule TEXT NOT NULL,
        montant REAL NOT NULL DEFAULT 0,
        compte_id INTEGER,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (ligne_budgetaire_id) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE,
        FOREIGN KEY (compte_id) REFERENCES compte(id)
      )
    ''');

    // Table exercice (max 5 exercices par fichier)
    await db.execute('''
      CREATE TABLE exercice (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        date_debut TEXT NOT NULL,
        date_fin TEXT NOT NULL,
        duree_mois INTEGER,
        is_active INTEGER DEFAULT 1,
        is_cloture INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Table config pour les longueurs de comptes
    await db.execute('''
      CREATE TABLE config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        longueur_compte_general INTEGER NOT NULL,
        longueur_compte_tiers INTEGER NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }
}
