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
          // Migration: Ajouter exercice_id à la table budget
          try {
            final columns = await db.rawQuery("PRAGMA table_info(budget)");
            final hasExerciceId = columns.any(
              (col) => col['name'] == 'exercice_id',
            );

            if (!hasExerciceId) {
              print('🔄 Migration: Ajout de exercice_id à la table budget');

              try {
                // Ajouter la colonne exercice_id
                await db.execute(
                  'ALTER TABLE budget ADD COLUMN exercice_id INTEGER',
                );
                print('✅ Migration: Colonne exercice_id ajoutée');
              } catch (e) {
                print('⚠️ Migration: Impossible d\'ajouter exercice_id ($e)');
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

            // Créer les tables manquantes pour la saisie comptable
            try {
              // Vérifier si la table journaux_periodes existe
              final tableList = await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='journaux_periodes'",
              );

              if (tableList.isEmpty) {
                print('🔄 Création des tables de saisie comptable');

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

                print('✅ Tables de saisie comptable créées');
              } else {
                await _ensureJournalPeriodeSchema(db);
              }

              await _ensureEcrituresDateComptable(db);
            } catch (e) {
              print('⚠️ Erreur création tables saisie comptable: $e');
            }
          } catch (e) {
            print('⚠️ Erreur général migration: $e');
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
          '🔄 Migration: mise à jour de journaux_periodes pour gérer les exercices',
        );
        await _rebuildJournalPeriodesTable(
          db,
          hasExistingExerciceColumn: hasExerciceColumn,
        );
        print('✅ Migration journaux_periodes terminée');
      }
    } catch (e) {
      print('⚠️ Migration journaux_periodes échouée: $e');
    }
  }

  static Future<void> _ensureEcrituresDateComptable(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(ecritures)");
      final hasDateComptable = columns.any(
        (col) => col['name'] == 'date_comptable',
      );

      if (!hasDateComptable) {
        print('🔄 Migration: ajout de date_comptable à ecritures');
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
      print('⚠️ Migration ecritures.date_comptable échouée: $e');
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
}
