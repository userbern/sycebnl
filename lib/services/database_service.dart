import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/compte.dart';
import '../models/tiers.dart';
import '../models/journal.dart';

class DatabaseService {
  static Database? _database;
  static String? _currentDatabasePath;

  /// Obtenir le chemin de la base de données actuelle
  static String? get currentDatabasePath => _currentDatabasePath;

  /// Initialiser SQLite FFI pour Windows/Desktop
  static Future<void> initializeFfi() async {
    // Factory already initialized in main.dart
    sqfliteFfiInit();
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
    print('DEBUG: Création de la base de données: $databasePath');
    _database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Créer les tables
          await _createTables(db);

          // Insérer les modules granulaires (un par sous-menu)
          for (final nom in const [
            'identification',
            'plan_comptable', 'liste_tiers', 'codes_journaux',
            'liste_bailleurs', 'liste_projets', 'gestion_budgets',
            'saisie_comptable', 'journaux_de_saisie', 'interrogations',
            'balance_comptes', 'grand_livre', 'journal',
            'exercices',
          ]) {
            await db.insert('modules', {'nom': nom});
          }

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
              final modules = await db.query('modules');
              for (final module in modules) {
                await db.insert('permissions', {
                  'utilisateur_id': userId,
                  'module_id': module['id'],
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
    print('DEBUG: Base de données créée et ouverte: $databasePath');
  }

  /// Se connecter à une base de données existante
  static Future<void> connectToDatabase(String databasePath) async {
    await initializeFfi();

    if (!File(databasePath).existsSync()) {
      throw Exception('Aucune base de données trouvée à cet emplacement');
    }

    print('DEBUG: Connexion à la base de données: $databasePath');
    _database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onOpen: (db) async {
          await _ensureCompteSchema(db);
          await _ensureUtilisateurSchema(db);

          // Migration: Ajouter exercice_id à la table budget
          try {
            final columns = await db.rawQuery("PRAGMA table_info(budget)");
            final hasExerciceId = columns.any(
              (col) => col['name'] == 'exercice_id',
            );

            if (!hasExerciceId) {
              print('Migration: Ajout de exercice_id à la table budget');

              try {
                // Ajouter la colonne exercice_id
                await db.execute(
                  'ALTER TABLE budget ADD COLUMN exercice_id INTEGER',
                );
                print('Migration: Colonne exercice_id ajoutée');
              } catch (e) {
                print('Migration: Impossible d\'ajouter exercice_id ($e)');
                // Continuer même si la migration échoue
              }
            }

            // Migration: Corriger la table journal
            final journalColumns = await db.rawQuery(
              "PRAGMA table_info(journal)",
            );
            final hasNumeroColumn = journalColumns.any(
              (col) => col['name'] == 'numero_compte_tresorerie',
            );

            if (!hasNumeroColumn) {
              print(
                'Migration: Recréation de la table journal avec numero_compte_tresorerie',
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

              print('Migration complétée');
            }

            // Créer les tables manquantes pour la saisie comptable
            try {
              // Vérifier si la table journaux_periodes existe
              final tableList = await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='journaux_periodes'",
              );

              if (tableList.isEmpty) {
                print('Création des tables de saisie comptable');

                await db.execute('''
                  CREATE TABLE journaux_periodes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    code_journal TEXT NOT NULL,
                    annee INTEGER NOT NULL,
                    mois INTEGER NOT NULL,
                    exercice_id INTEGER,
                    nombre_ecritures INTEGER DEFAULT 0,
                    total_debit REAL DEFAULT 0,
                    total_credit REAL DEFAULT 0,
                    solde_final REAL DEFAULT 0,
                    is_equilibre INTEGER DEFAULT 0,
                    is_closed INTEGER DEFAULT 0,
                    created_at TEXT,
                    updated_at TEXT,
                    UNIQUE(code_journal, annee, mois, exercice_id),
                    FOREIGN KEY (code_journal) REFERENCES journal(code),
                    FOREIGN KEY (exercice_id) REFERENCES exercice(id)
                  )
                ''');

                await db.execute('''
                  CREATE TABLE ecritures (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    journal_periode_id INTEGER NOT NULL,
                    numero_enregistrement INTEGER NOT NULL,
                    jour INTEGER NOT NULL,
                    date_comptable TEXT,
                    numero_document TEXT,
                    reference TEXT,
                    numero_compte TEXT NOT NULL,
                    numero_tiers TEXT,
                    libelle TEXT NOT NULL,
                    montant_debit REAL DEFAULT 0,
                    montant_credit REAL DEFAULT 0,
                    is_ventilee INTEGER DEFAULT 0,
                    lettrage_code TEXT,
                    lettrage_date TEXT,
                    created_at TEXT,
                    updated_at TEXT,
                    FOREIGN KEY (journal_periode_id) REFERENCES journaux_periodes(id),
                    FOREIGN KEY (numero_compte) REFERENCES compte(numero_compte),
                    FOREIGN KEY (numero_tiers) REFERENCES tiers(numero_tiers)
                  )
                ''');

                await db.execute('''
                  CREATE TABLE ventilations_analytiques (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ecriture_id INTEGER NOT NULL,
                    type TEXT NOT NULL,
                    id_projet INTEGER,
                    volet TEXT,
                    id_bailleur INTEGER,
                    id_poste_budgetaire INTEGER,
                    id_ligne_budgetaire INTEGER,
                    montant_ventile REAL DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT (datetime('now')),
                    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                    deleted_at TEXT,
                    FOREIGN KEY (ecriture_id) REFERENCES ecritures(id) ON DELETE CASCADE,
                    FOREIGN KEY (id_projet) REFERENCES projet(id) ON DELETE CASCADE,
                    FOREIGN KEY (id_poste_budgetaire) REFERENCES poste_budgetaire(id) ON DELETE CASCADE,
                    FOREIGN KEY (id_ligne_budgetaire) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE
                  )
                ''');

                print('Tables de saisie comptable créées');
              } else {
                await _ensureJournalPeriodeSchema(db);
              }

              await _ensureEcrituresDateComptable(db);
            } catch (e) {
              print('Erreur création tables saisie comptable: $e');
            }
          } catch (e) {
            print('Erreur général migration: $e');
          }

          // Migration : modules granulaires
          try {
            final existingModules = await db.query('modules');
            final existingNoms =
                existingModules.map((m) => m['nom'] as String).toSet();

            if (!existingNoms.contains('plan_comptable')) {
              const oldToNew = {
                'notre_entite': ['identification'],
                'parametrages': [
                  'plan_comptable', 'liste_tiers', 'codes_journaux',
                  'liste_bailleurs', 'liste_projets', 'gestion_budgets',
                ],
                'traitements': [
                  'saisie_comptable', 'journaux_de_saisie', 'interrogations',
                ],
                'edition': ['balance_comptes', 'grand_livre', 'journal'],
              };

              final users = await db.rawQuery(
                'SELECT id FROM utilisateur WHERE deleted_at IS NULL',
              );

              for (final entry in oldToNew.entries) {
                final oldRow = existingModules
                    .where((m) => m['nom'] == entry.key)
                    .firstOrNull;
                final oldId = oldRow?['id'] as int?;

                for (final newNom in entry.value) {
                  if (existingNoms.contains(newNom)) continue;
                  final newId = await db.insert('modules', {'nom': newNom});

                  for (final user in users) {
                    final userId = user['id'] as int;
                    Map<String, dynamic> oldPerms = {};
                    if (oldId != null) {
                      final rows = await db.query(
                        'permissions',
                        where: 'utilisateur_id = ? AND module_id = ?',
                        whereArgs: [userId, oldId],
                      );
                      if (rows.isNotEmpty) oldPerms = rows.first;
                    }
                    await db.insert(
                      'permissions',
                      {
                        'utilisateur_id': userId,
                        'module_id': newId,
                        'lecture': oldPerms['lecture'] ?? 0,
                        'ajout': oldPerms['ajout'] ?? 0,
                        'modification': oldPerms['modification'] ?? 0,
                        'suppression': oldPerms['suppression'] ?? 0,
                        'created_at': DateTime.now().toIso8601String(),
                      },
                      conflictAlgorithm: ConflictAlgorithm.ignore,
                    );
                  }
                }
              }

              // Module exercices (pas d'ancien équivalent)
              if (!existingNoms.contains('exercices')) {
                final newId = await db.insert('modules', {'nom': 'exercices'});
                for (final user in users) {
                  await db.insert(
                    'permissions',
                    {
                      'utilisateur_id': user['id'] as int,
                      'module_id': newId,
                      'lecture': 0, 'ajout': 0,
                      'modification': 0, 'suppression': 0,
                      'created_at': DateTime.now().toIso8601String(),
                    },
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
            }
          } catch (e) {
            print('Migration modules granulaires: $e');
          }
        },
      ),
    );

    _currentDatabasePath = databasePath;
    print('DEBUG: Base de données connectée: $databasePath');
  }

  /// Fermer la connexion à la base de données
  static Future<void> closeDatabase() async {
    if (_database != null) {
      print('DEBUG: Fermeture de la base de données: $_currentDatabasePath');
      await _database!.close();
      _database = null;
      _currentDatabasePath = null;
      print('DEBUG: Base de données fermée');
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
        nom TEXT,
        prenom TEXT,
        email TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (created_by) REFERENCES utilisateur(id)
      )
    ''');

    // Table compte
    await db.execute('''
      CREATE TABLE compte (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_compte TEXT UNIQUE NOT NULL,
        intitule TEXT NOT NULL,
        type TEXT NOT NULL,
        nature TEXT NOT NULL,
        liaison_tiers INTEGER DEFAULT 0,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
        FOREIGN KEY (numero_compte_tresorerie) REFERENCES compte(numero_compte)
      )
    ''');

    // Table bailleur
    await db.execute('''
      CREATE TABLE bailleur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sigle TEXT UNIQUE NOT NULL,
        designation TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT
      )
    ''');

    // Table liaison projet-bailleur (plusieurs bailleurs par projet)
    await db.execute('''
      CREATE TABLE projet_bailleur (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projet_id INTEGER NOT NULL,
        bailleur_id INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
        FOREIGN KEY (bailleur_id) REFERENCES bailleur(id),
        UNIQUE (projet_id, bailleur_id)
      )
    ''');

    // Table budget (niveau 1 : Budget principal lié à projet + bailleur + exercice)
    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projet_id INTEGER NOT NULL,
        bailleur_id INTEGER NOT NULL,
        exercice_id INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
        FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
        FOREIGN KEY (bailleur_id) REFERENCES bailleur(id) ON DELETE CASCADE,
        FOREIGN KEY (exercice_id) REFERENCES exercice(id) ON DELETE CASCADE,
        UNIQUE (projet_id, bailleur_id, exercice_id)
      )
    ''');

    // Table poste_budgetaire (niveau 2 : Postes budgétaires d'un budget)
    await db.execute('''
      CREATE TABLE poste_budgetaire (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER NOT NULL,
        intitule TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT
      )
    ''');

    // Table config pour les longueurs de comptes
    await db.execute('''
      CREATE TABLE config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        longueur_compte_general INTEGER NOT NULL,
        longueur_compte_tiers INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT
      )
    ''');

    // Table journaux_periodes (journal + mois + année)
    await db.execute('''
      CREATE TABLE journaux_periodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_journal TEXT NOT NULL,
        annee INTEGER NOT NULL,
        mois INTEGER NOT NULL,
        exercice_id INTEGER,
        nombre_ecritures INTEGER DEFAULT 0,
        total_debit REAL DEFAULT 0,
        total_credit REAL DEFAULT 0,
        solde_final REAL DEFAULT 0,
        is_equilibre INTEGER DEFAULT 0,
        is_closed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (code_journal) REFERENCES journal(code),
        FOREIGN KEY (exercice_id) REFERENCES exercice(id),
        UNIQUE (code_journal, annee, mois, exercice_id)
      )
    ''');

    // Table ecritures (lignes d'écriture comptable)
    await db.execute('''
      CREATE TABLE ecritures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journal_periode_id INTEGER NOT NULL,
        numero_enregistrement INTEGER NOT NULL,
        jour INTEGER NOT NULL,
        date_comptable TEXT,
        numero_document TEXT NOT NULL,
        reference TEXT,
        numero_compte TEXT NOT NULL,
        numero_tiers TEXT,
        libelle TEXT NOT NULL,
        montant_debit REAL DEFAULT 0,
        montant_credit REAL DEFAULT 0,
        is_ventilee INTEGER DEFAULT 0,
        lettrage_code TEXT,
        lettrage_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
        FOREIGN KEY (journal_periode_id) REFERENCES journaux_periodes(id) ON DELETE CASCADE,
        FOREIGN KEY (numero_compte) REFERENCES compte(numero_compte),
        FOREIGN KEY (numero_tiers) REFERENCES tiers(numero_compte)
      )
    ''');

    // Table ventilations_analytiques (détail ventilation d'une écriture)
    await db.execute('''
      CREATE TABLE ventilations_analytiques (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ecriture_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        id_projet INTEGER,
        volet TEXT,
        id_bailleur INTEGER,
        id_poste_budgetaire INTEGER,
        id_ligne_budgetaire INTEGER,
        montant_ventile REAL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        deleted_at TEXT,
        FOREIGN KEY (ecriture_id) REFERENCES ecritures(id) ON DELETE CASCADE,
        FOREIGN KEY (id_projet) REFERENCES projet(id) ON DELETE CASCADE,
        FOREIGN KEY (id_poste_budgetaire) REFERENCES poste_budgetaire(id) ON DELETE CASCADE,
        FOREIGN KEY (id_ligne_budgetaire) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _ensureJournalPeriodeSchema(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(journaux_periodes)");
      final hasExerciceColumn = columns.any(
        (col) => col['name'] == 'exercice_id',
      );

      bool needsRebuild = !hasExerciceColumn;
      await _ensureEcrituresLettrage(db);

      if (!needsRebuild) {
        final indexList = await db.rawQuery(
          "PRAGMA index_list('journaux_periodes')",
        );

        bool hasCompositeUnique = false;
        for (final index in indexList) {
          final isUnique = (index['unique'] as int? ?? 0) == 1;
          if (!isUnique) continue;

          final indexName = index['name'] as String?;
          if (indexName == null) continue;

          final indexInfo = await db.rawQuery(
            "PRAGMA index_info('$indexName')",
          );
          final columnNames =
              indexInfo
                  .map((row) => row['name'] as String?)
                  .whereType<String>()
                  .toList();

          if (columnNames.contains('code_journal') &&
              columnNames.contains('annee') &&
              columnNames.contains('mois') &&
              columnNames.contains('exercice_id')) {
            hasCompositeUnique = true;
            break;
          }
        }

        if (!hasCompositeUnique) {
          needsRebuild = true;
        }
      }

      if (needsRebuild) {
        print(
          'Migration: mise à jour de journaux_periodes pour gérer les exercices',
        );
        await _rebuildJournalPeriodesTable(
          db,
          hasExistingExerciceColumn: hasExerciceColumn,
        );
        print('Migration journaux_periodes terminée');
      }
    } catch (e) {
      print('Migration journaux_periodes échouée: $e');
    }
  }

  static Future<void> _ensureCompteSchema(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(compte)");
      final hasDescription = columns.any((col) => col['name'] == 'description');

      if (!hasDescription) {
        print('Migration: ajout de description à la table compte');
        await db.execute('ALTER TABLE compte ADD COLUMN description TEXT');
      }
    } catch (e) {
      print('Migration compte échouée: $e');
    }
  }

  static Future<void> _ensureUtilisateurSchema(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(utilisateur)");
      final names = columns.map((col) => col['name']).toSet();

      if (!names.contains('nom')) {
        print('Migration: ajout de nom à la table utilisateur');
        await db.execute('ALTER TABLE utilisateur ADD COLUMN nom TEXT');
      }
      if (!names.contains('prenom')) {
        print('Migration: ajout de prenom à la table utilisateur');
        await db.execute('ALTER TABLE utilisateur ADD COLUMN prenom TEXT');
      }
      if (!names.contains('email')) {
        print('Migration: ajout de email à la table utilisateur');
        await db.execute('ALTER TABLE utilisateur ADD COLUMN email TEXT');
      }
      if (!names.contains('is_active')) {
        print('Migration: ajout de is_active à la table utilisateur');
        await db.execute(
          'ALTER TABLE utilisateur ADD COLUMN is_active INTEGER DEFAULT 1',
        );
      }
    } catch (e) {
      print('Migration utilisateur échouée: $e');
    }
  }

  static Future<void> _ensureEcrituresDateComptable(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(ecritures)");
      final hasDateComptable = columns.any(
        (col) => col['name'] == 'date_comptable',
      );

      if (!hasDateComptable) {
        print('Migration: ajout de date_comptable à ecritures');
        await db.execute(
          'ALTER TABLE ecritures ADD COLUMN date_comptable TEXT',
        );
      }

      await db.execute('''
        UPDATE ecritures
        SET date_comptable = (
          SELECT printf('%04d-%02d-%02d', jp.annee, jp.mois,
            CASE WHEN jour BETWEEN 1 AND 31 THEN jour ELSE 1 END)
          FROM journaux_periodes jp
          WHERE jp.id = ecritures.journal_periode_id
        )
        WHERE date_comptable IS NULL OR date_comptable = ''
      ''');
    } catch (e) {
      print('Migration ecritures.date_comptable échouée: $e');
    }
  }

  static Future<void> _ensureEcrituresLettrage(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(ecritures)");
      final hasLettrageCode = columns.any(
        (col) => col['name'] == 'lettrage_code',
      );
      final hasLettrageDate = columns.any(
        (col) => col['name'] == 'lettrage_date',
      );

      if (!hasLettrageCode) {
        print('Migration: ajout de lettrage_code à ecritures');
        await db.execute('ALTER TABLE ecritures ADD COLUMN lettrage_code TEXT');
      }

      if (!hasLettrageDate) {
        print('Migration: ajout de lettrage_date à ecritures');
        await db.execute('ALTER TABLE ecritures ADD COLUMN lettrage_date TEXT');
      }
    } catch (e) {
      print('Migration ecritures.lettrage échouée: $e');
    }
  }

  static Future<void> _rebuildJournalPeriodesTable(
    Database db, {
    required bool hasExistingExerciceColumn,
  }) async {
    await db.execute('PRAGMA foreign_keys=OFF');
    int maxId = 0;

    try {
      await db.execute('''
        CREATE TABLE journaux_periodes_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code_journal TEXT NOT NULL,
          annee INTEGER NOT NULL,
          mois INTEGER NOT NULL,
          exercice_id INTEGER,
          nombre_ecritures INTEGER DEFAULT 0,
          total_debit REAL DEFAULT 0,
          total_credit REAL DEFAULT 0,
          solde_final REAL DEFAULT 0,
          is_equilibre INTEGER DEFAULT 0,
          is_closed INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (code_journal) REFERENCES journal(code),
          FOREIGN KEY (exercice_id) REFERENCES exercice(id),
          UNIQUE(code_journal, annee, mois, exercice_id)
        )
      ''');

      final periodes = await db.query('journaux_periodes');
      final exercicesRaw = await db.query('exercice');
      final exercices =
          exercicesRaw
              .map((row) {
                final id = row['id'];
                final startRaw = row['date_debut'];
                final endRaw = row['date_fin'];
                if (id is! int || startRaw is! String || endRaw is! String) {
                  return null;
                }
                try {
                  return (
                    id: id,
                    start: DateTime.parse(startRaw),
                    end: DateTime.parse(endRaw),
                    isActive: (row['is_active'] as int? ?? 0) == 1,
                  );
                } catch (_) {
                  return null;
                }
              })
              .whereType<
                ({int id, DateTime start, DateTime end, bool isActive})
              >()
              .toList();

      int? fallbackId;
      if (exercices.isNotEmpty) {
        final active = exercices.firstWhere(
          (ex) => ex.isActive,
          orElse: () => exercices.first,
        );
        fallbackId = active.id;
      }

      for (final periode in periodes) {
        final rawId = periode['id'];
        final rawCode = periode['code_journal'];
        final rawAnnee = periode['annee'];
        final rawMois = periode['mois'];

        if (rawId is! int || rawCode is! String) {
          continue;
        }

        final annee = rawAnnee is int ? rawAnnee : int.tryParse('$rawAnnee');
        final mois = rawMois is int ? rawMois : int.tryParse('$rawMois');

        if (annee == null || mois == null) {
          continue;
        }

        int? exerciceId =
            hasExistingExerciceColumn ? periode['exercice_id'] as int? : null;

        if (exerciceId == null) {
          try {
            final candidateDate = DateTime(annee, mois, 1);
            for (final exercice in exercices) {
              if (!candidateDate.isBefore(exercice.start) &&
                  !candidateDate.isAfter(exercice.end)) {
                exerciceId = exercice.id;
                break;
              }
            }
          } catch (_) {
            // Ignore parsing errors and fall back later
          }
        }

        exerciceId ??= fallbackId;

        final insertData = <String, Object?>{
          'id': rawId,
          'code_journal': rawCode,
          'annee': annee,
          'mois': mois,
          'exercice_id': exerciceId,
          'nombre_ecritures': periode['nombre_ecritures'],
          'total_debit': periode['total_debit'],
          'total_credit': periode['total_credit'],
          'solde_final': periode['solde_final'],
          'is_equilibre': periode['is_equilibre'],
          'is_closed': periode['is_closed'],
          'created_at': periode['created_at'],
          'updated_at': periode['updated_at'],
        };

        await db.insert(
          'journaux_periodes_new',
          insertData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (rawId > maxId) {
          maxId = rawId;
        }
      }

      await db.execute('DROP TABLE journaux_periodes');
      await db.execute(
        'ALTER TABLE journaux_periodes_new RENAME TO journaux_periodes',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journaux_periodes_exercice ON journaux_periodes(exercice_id)',
      );

      if (maxId > 0) {
        await db.rawUpdate(
          'UPDATE sqlite_sequence SET seq = ? WHERE name = ?',
          [maxId, 'journaux_periodes'],
        );
      }
    } finally {
      await db.execute('PRAGMA foreign_keys=ON');
    }
  }

  /// S'assurer que la base est ouverte avant toute requête
  static Future<void> ensureDatabaseOpen() async {
    if (!isConnected) {
      print('DEBUG: Base fermée, tentative de réouverture...');
      final dbPath = currentDatabasePath;
      if (dbPath != null) {
        print('DEBUG: Réouverture de la base: $dbPath');
        await connectToDatabase(dbPath);
      } else {
        print('DEBUG: Impossible de rouvrir, chemin inconnu');
        throw Exception('Chemin de base de données inconnu');
      }
    } else {
      print('DEBUG: Base déjà ouverte');
    }
  }

  /// Alias pour compatibilité: openDatabase -> connectToDatabase
  static Future<void> openDatabase(String databasePath) async {
    return connectToDatabase(databasePath);
  }

  /// Récupérer tous les comptes (liste de `Compte`)
  static Future<List<Compte>> getAllComptes() async {
    await ensureDatabaseOpen();
    try {
      final results = await database.query(
        'compte',
        where: 'deleted_at IS NULL',
        orderBy: 'numero_compte ASC',
      );
      return results.map((r) => Compte.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur récupération comptes: $e');
    }
  }

  /// Créer un compte (compatible avec usages existants)
  static Future<void> createCompte({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String nature,
    bool? liaisonTiers,
    String? description,
  }) async {
    await ensureDatabaseOpen();

    // Check if account already exists
    final existing = await database.query(
      'compte',
      where: 'numero_compte = ?',
      whereArgs: [numeroCompte],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('Le compte $numeroCompte existe déjà');
    }

    try {
      await database.insert('compte', {
        'numero_compte': numeroCompte,
        'intitule': intitule,
        'type': type,
        'nature': nature,
        'liaison_tiers': (liaisonTiers ?? false) ? 1 : 0,
        'description': description,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint')) {
        throw Exception('Le compte $numeroCompte existe déjà');
      }
      rethrow;
    }
  }

  static Future<void> updateCompte({
    int? id,
    String? compteId,
    String? numeroCompte,
    String? intitule,
    String? type,
    String? nature,
    bool? liaisonTiers,
    String? description,
  }) async {
    await ensureDatabaseOpen();
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (numeroCompte != null) data['numero_compte'] = numeroCompte;
    if (intitule != null) data['intitule'] = intitule;
    if (type != null) data['type'] = type;
    if (nature != null) data['nature'] = nature;
    if (liaisonTiers != null) data['liaison_tiers'] = liaisonTiers ? 1 : 0;
    if (description != null) data['description'] = description;
    final finalId = id ?? (compteId != null ? int.parse(compteId) : null);
    if (finalId == null)
      throw Exception('updateCompte requires id or compteId');
    await database.update(
      'compte',
      data,
      where: 'id = ?',
      whereArgs: [finalId],
    );
  }

  static Future<void> deleteCompte(dynamic id) async {
    await ensureDatabaseOpen();
    final finalId = id is String ? int.parse(id) : id as int;
    await database.update(
      'compte',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [finalId],
    );
  }

  /// Tiers helpers
  static Future<List<Tiers>> getAllTiers() async {
    await ensureDatabaseOpen();
    final results = await database.query(
      'tiers',
      where: 'deleted_at IS NULL',
      orderBy: 'intitule ASC',
    );
    return results.map((r) => Tiers.fromMap(r)).toList();
  }

  static Future<void> createTiers(
    String numeroCompte,
    String intitule,
    String type,
    String compteCollectif, [
    String? nif,
    String? adresse,
  ]) async {
    await ensureDatabaseOpen();
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

  static Future<void> updateTiers(
    int id,
    String numeroCompte,
    String intitule,
    String type,
    String compteCollectif, [
    String? nif,
    String? adresse,
  ]) async {
    await ensureDatabaseOpen();
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'numero_compte': numeroCompte,
      'intitule': intitule,
      'type': type,
      'compte_collectif': compteCollectif,
      'nif': nif,
      'adresse': adresse,
    };
    await database.update('tiers', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTiers(int id) async {
    await ensureDatabaseOpen();
    await database.update(
      'tiers',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compatibility wrapper: getFileConfig -> getConfig
  static Future<Map<String, dynamic>?> getFileConfig() async {
    return getConfig();
  }

  /// Récupérer un journal par code
  static Future<Journal?> getJournalByCode(String code) async {
    await ensureDatabaseOpen();
    final results = await database.query(
      'journal',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Journal.fromMap(results.first);
  }

  /// Vérifie si un compte est utilisé dans la table journaux (compte de trésorerie)
  static Future<bool> isCompteUsedInJournaux(String numeroCompte) async {
    await ensureDatabaseOpen();
    try {
      final result = await database.query(
        'journal',
        where: 'compte_tresorerie = ? AND is_active = 1',
        whereArgs: [numeroCompte],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Table journaux absente ou erreur SQL: $e');
      return false;
    }
  }

  /// Vérifier le mot de passe et retourner l'utilisateur
  static Future<Map<String, dynamic>?> verifyLogin(
    String login,
    String password,
  ) async {
    try {
      await ensureDatabaseOpen();
      final users = await database.query(
        'utilisateur',
        where: 'login = ? AND deleted_at IS NULL',
        whereArgs: [login],
        limit: 1,
      );

      if (users.isEmpty) return null;

      final user = users.first;
      final storedHash = user['password'] as String?;

      if (storedHash != null && verifyPassword(password, storedHash)) {
        return user;
      }

      return null;
    } catch (e) {
      print('DEBUG verifyLogin error: $e');
      return null;
    }
  }

  /// Vérifier si le fichier nécessite un mot de passe
  static Future<bool> requiresPassword(String databasePath) async {
    try {
      if (isConnected && currentDatabasePath == databasePath) {
        final users = await database.query('utilisateur', limit: 1);
        return users.isNotEmpty;
      }

      await initializeFfi();
      final db = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final users = await db.query('utilisateur', limit: 1);
      await db.close();
      return users.isNotEmpty;
    } catch (e) {
      print('DEBUG requiresPassword error: $e');
      return false;
    }
  }

  /// Obtenir la configuration du fichier
  static Future<Map<String, dynamic>?> getConfig() async {
    try {
      await ensureDatabaseOpen();
      final results = await database.query('config', limit: 1);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('DEBUG: Table config not found, returning null');
      return null;
    }
  }

  /// Obtenir les données de l'entité
  static Future<Map<String, dynamic>?> getEntite() async {
    try {
      await ensureDatabaseOpen();
      final results = await database.query('entite', limit: 1);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('DEBUG getEntite error: $e');
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
      print('DEBUG getExercices error: $e');
      return [];
    }
  }

  /// Changer l'exercice actif
  static Future<void> setActiveExercice(int exerciceId) async {
    await ensureDatabaseOpen();
    await database.update('exercice', {
      'is_active': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

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

    final exercices = await getExercices();
    if (exercices.length >= 5) {
      throw Exception('Maximum 5 exercices par fichier comptable');
    }

    final existing = exercices.where((e) => e['code'] == code);
    if (existing.isNotEmpty) {
      throw Exception('Un exercice avec ce code existe déjà');
    }

    await database.transaction((txn) async {
      final nouvelExerciceId = await txn.insert('exercice', {
        'code': code,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'duree_mois': dureeMois,
        'is_active': 0,
        'is_cloture': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (reportSoldes) {
        await _reportSoldesOuverture(
          txn,
          nouvelExerciceId: nouvelExerciceId,
          nouvelExerciceCode: code,
          dateDebut: DateTime.parse(dateDebut),
          exercices: exercices,
        );
      }
    });
  }

  static Future<void> _reportSoldesOuverture(
    Transaction txn, {
    required int nouvelExerciceId,
    required String nouvelExerciceCode,
    required DateTime dateDebut,
    required List<Map<String, dynamic>> exercices,
  }) async {
    final exercicePrecedent = _findExercicePrecedent(exercices, dateDebut);
    if (exercicePrecedent == null) {
      return;
    }

    final exercicePrecedentId = exercicePrecedent['id'] as int?;
    if (exercicePrecedentId == null) {
      return;
    }

    final soldes = await txn.rawQuery(
      '''
      SELECT
        c.numero_compte,
        c.intitule,
        COALESCE(SUM(e.montant_debit - e.montant_credit), 0) AS solde
      FROM compte c
      JOIN ecritures e ON e.numero_compte = c.numero_compte
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE jp.exercice_id = ?
        AND c.deleted_at IS NULL
        AND substr(c.numero_compte, 1, 1) IN ('1', '2', '3', '4', '5')
      GROUP BY c.numero_compte, c.intitule
      HAVING ABS(solde) > 0.01
      ORDER BY c.numero_compte
      ''',
      [exercicePrecedentId],
    );

    if (soldes.isEmpty) {
      return;
    }

    await _ensureJournalAN(txn);

    final now = DateTime.now().toIso8601String();
    final periodeRows = await txn.query(
      'journaux_periodes',
      where: 'code_journal = ? AND annee = ? AND mois = ? AND exercice_id = ?',
      whereArgs: ['AN', dateDebut.year, dateDebut.month, nouvelExerciceId],
      limit: 1,
    );

    final periodeId =
        periodeRows.isNotEmpty
            ? periodeRows.first['id'] as int
            : await txn.insert('journaux_periodes', {
              'code_journal': 'AN',
              'annee': dateDebut.year,
              'mois': dateDebut.month,
              'exercice_id': nouvelExerciceId,
              'nombre_ecritures': 0,
              'total_debit': 0,
              'total_credit': 0,
              'solde_final': 0,
              'is_equilibre': 0,
              'is_closed': 0,
              'created_at': now,
              'updated_at': now,
            });

    final dateOuverture = _formatDateYMD(dateDebut);
    final document = 'OUV-$nouvelExerciceCode';
    double totalDebit = 0;
    double totalCredit = 0;

    for (final row in soldes) {
      final numeroCompte = row['numero_compte']?.toString() ?? '';
      final solde = (row['solde'] as num?)?.toDouble() ?? 0.0;
      if (numeroCompte.isEmpty || solde.abs() <= 0.01) {
        continue;
      }

      final debit = solde > 0 ? solde : 0.0;
      final credit = solde < 0 ? -solde : 0.0;
      totalDebit += debit;
      totalCredit += credit;

      await txn.insert('ecritures', {
        'journal_periode_id': periodeId,
        'numero_enregistrement': 1,
        'jour': dateDebut.day,
        'date_comptable': dateOuverture,
        'numero_document': document,
        'reference': document,
        'numero_compte': numeroCompte,
        'numero_tiers': null,
        'libelle': 'Solde d\'ouverture $nouvelExerciceCode',
        'montant_debit': debit,
        'montant_credit': credit,
        'is_ventilee': 0,
        'created_at': now,
        'updated_at': now,
      });
    }

    final ecart = totalDebit - totalCredit;
    if (ecart.abs() > 0.01) {
      await _ensureReportANouveauCompte(txn, now);
      final debit = ecart < 0 ? -ecart : 0.0;
      final credit = ecart > 0 ? ecart : 0.0;
      totalDebit += debit;
      totalCredit += credit;

      await txn.insert('ecritures', {
        'journal_periode_id': periodeId,
        'numero_enregistrement': 1,
        'jour': dateDebut.day,
        'date_comptable': dateOuverture,
        'numero_document': document,
        'reference': document,
        'numero_compte': '120000',
        'numero_tiers': null,
        'libelle': 'Report a nouveau $nouvelExerciceCode',
        'montant_debit': debit,
        'montant_credit': credit,
        'is_ventilee': 0,
        'created_at': now,
        'updated_at': now,
      });
    }

    await txn.update(
      'journaux_periodes',
      {
        'nombre_ecritures': 1,
        'total_debit': totalDebit,
        'total_credit': totalCredit,
        'solde_final': totalDebit - totalCredit,
        'is_equilibre': (totalDebit - totalCredit).abs() <= 0.01 ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [periodeId],
    );
  }

  static Map<String, dynamic>? _findExercicePrecedent(
    List<Map<String, dynamic>> exercices,
    DateTime dateDebut,
  ) {
    Map<String, dynamic>? selected;
    DateTime? selectedEnd;

    for (final exercice in exercices) {
      final rawEnd = exercice['date_fin'];
      if (rawEnd == null) {
        continue;
      }

      final end = DateTime.tryParse(rawEnd.toString());
      if (end == null || !end.isBefore(dateDebut)) {
        continue;
      }

      if (selectedEnd == null || end.isAfter(selectedEnd)) {
        selected = exercice;
        selectedEnd = end;
      }
    }

    return selected;
  }

  static Future<void> _ensureJournalAN(Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    await txn.insert('journal', {
      'code': 'AN',
      'libelle': 'A nouveaux',
      'type': 'operations_diverses',
      'numero_compte_tresorerie': null,
      'saisie_analytique': 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _ensureReportANouveauCompte(
    Transaction txn,
    String now,
  ) async {
    final existing = await txn.query(
      'compte',
      where: 'numero_compte = ? AND deleted_at IS NULL',
      whereArgs: ['120000'],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return;
    }

    await txn.insert('compte', {
      'numero_compte': '120000',
      'intitule': 'Report a nouveau',
      'type': 'detail',
      'nature': 'bilan_ressources_durables',
      'liaison_tiers': 0,
      'description':
          'Compte cree automatiquement pour equilibrer les soldes d\'ouverture',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  static String _formatDateYMD(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Wrapper de hash/verification pour compatibilité
  static bool verifyPasswordHash(String password, String hash) {
    return verifyPassword(password, hash);
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
      if (storedHash != null && !verifyPassword(oldPassword, storedHash)) {
        throw Exception('Ancien mot de passe incorrect');
      }
    }

    final targetUserId = userId ?? 1;
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
}
