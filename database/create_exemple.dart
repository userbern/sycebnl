import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

/// Script pour créer un fichier de base de données exemple avec des données de test
/// Usage: dart run database/create_exemple.dart

void main() async {
  // Initialiser sqflite_ffi pour desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Chemin du fichier exemple
  final dbPath = join(Directory.current.path, 'database', 'exemple.db');

  // Supprimer le fichier s'il existe déjà
  if (await File(dbPath).exists()) {
    await File(dbPath).delete();
    print('Ancien fichier supprimé');
  }

  // Créer la base de données
  final db = await openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      // Table config (paramètres fixes)
      await db.execute('''
        CREATE TABLE config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          longueur_compte_general INTEGER DEFAULT 6,
          longueur_compte_tiers INTEGER DEFAULT 8,
          has_password INTEGER DEFAULT 0,
          password_hash TEXT,
          login TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Table exercice (multi-exercices)
      await db.execute('''
        CREATE TABLE exercice (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          date_debut TEXT NOT NULL,
          date_fin TEXT NOT NULL,
          duree_mois INTEGER NOT NULL,
          statut TEXT DEFAULT 'OUVERT',
          is_current INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          CHECK(statut IN ('OUVERT', 'CLOTURE')),
          CHECK(is_current IN (0, 1))
        )
      ''');

      // Table users (utilisateurs du fichier)
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          prenom TEXT,
          login TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          email TEXT,
          role TEXT DEFAULT 'user',
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT,
          CHECK(role IN ('admin', 'user')),
          CHECK(is_active IN (0, 1))
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
          currency TEXT DEFAULT 'FCFA (XOF)',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Table compte
      await db.execute('''
        CREATE TABLE compte (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_compte TEXT NOT NULL UNIQUE,
          intitule TEXT NOT NULL,
          type TEXT,
          nature TEXT,
          liaison_tiers INTEGER DEFAULT 0,
          description TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT,
          deleted_at TEXT
        )
      ''');

      // Table tiers
      await db.execute('''
        CREATE TABLE tiers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          type_tiers TEXT,
          adresse TEXT,
          telephone TEXT,
          email TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Table journal
      await db.execute('''
        CREATE TABLE journal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          libelle TEXT NOT NULL,
          type_journal TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Table bailleur
      await db.execute('''
        CREATE TABLE bailleur (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sigle TEXT NOT NULL,
          designation TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Table projet
      /*  await db.execute('''
        CREATE TABLE projet (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          intitule TEXT NOT NULL,
          date_debut TEXT,
          date_fin TEXT,
          statut TEXT DEFAULT 'Actif',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      '''); */

      // Table budget
      /* await db.execute('''
        CREATE TABLE budget (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL,
          intitule TEXT NOT NULL,
          exercice_id INTEGER NOT NULL,
          montant REAL DEFAULT 0,
          projet_id INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (exercice_id) REFERENCES exercice (id),
          FOREIGN KEY (projet_id) REFERENCES projet (id)
        )
      '''); */

      // Table monnaie
      /*  await db.execute('''
        CREATE TABLE monnaie (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          nom TEXT NOT NULL,
          symbole TEXT,
          is_active INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      '''); */

      print('Tables créées avec succès');

      // Insérer la configuration (paramètres fixes)
      await db.insert('config', {
        'longueur_compte_general': 6,
        'longueur_compte_tiers': 8,
        'has_password': 0,
        'password_hash': null,
        'login': null,
      });

      // Insérer l'exercice 2025 (exercice courant)
      await db.insert('exercice', {
        'code': '2025',
        'date_debut': '2025-01-01T00:00:00.000',
        'date_fin': '2025-12-31T00:00:00.000',
        'duree_mois': 12,
        'statut': 'OUVERT',
        'is_current': 1,
      });

      // Insérer l'entité exemple
      await db.insert('entite', {
        'denomination_sociale': 'ONG Développement Communautaire',
        'sigle_usuel': 'ODC',
        'domaine_intervention': 'Éducation et santé communautaire',
        'forme_juridique': 'ONG locale',
        'pays': 'Bénin',
        'region': 'Atlantique',
        'ville': 'Cotonou',
        'quartier': 'Akpakpa',
        'email': 'contact@ongexemple.org',
        'telephone': '+229 97 00 00 00',
        'fixe_fax': '+229 21 30 00 00',
        'numero_fiscal': 'IFU0123456789',
        'numero_cnss': 'CNSS987654321',
        'numero_recepisse': 'REC/2020/001',
        'informations_complementaires':
            'ONG créée en 2020, spécialisée dans l\'éducation et la santé communautaire en zone rurale.',
        'currency': 'FCFA (XOF)',
      });

      // Insérer quelques comptes
      final comptes = [
        ['101000', 'Capital social', 'Capitaux propres'],
        ['120000', 'Résultat de l\'exercice', 'Capitaux propres'],
        ['401000', 'Fournisseurs', 'Dettes'],
        ['411000', 'Clients', 'Créances'],
        ['512000', 'Banque', 'Trésorerie'],
        ['530000', 'Caisse', 'Trésorerie'],
        ['601000', 'Achats de marchandises', 'Charges'],
        ['606000', 'Achats de fournitures', 'Charges'],
        ['621000', 'Personnel', 'Charges'],
        ['701000', 'Ventes de produits', 'Produits'],
      ];

      for (var compte in comptes) {
        await db.insert('compte', {
          'numero_compte': compte[0],
          'intitule': compte[1],
          'type_compte': compte[2],
        });
      }

      // Insérer quelques tiers
      final tiers = [
        [
          'Fournisseur ABC',
          'Fournisseur',
          'Rue de la Paix, Cotonou',
          '+229 97 11 11 11',
          'abc@example.com',
        ],
        [
          'Client XYZ',
          'Client',
          'Avenue de l\'Indépendance, Porto-Novo',
          '+229 97 22 22 22',
          'xyz@example.com',
        ],
        [
          'Consultant Martin',
          'Prestataire',
          'Quartier Agla, Cotonou',
          '+229 97 33 33 33',
          'martin@example.com',
        ],
      ];

      for (var tier in tiers) {
        await db.insert('tiers', {
          'nom': tier[0],
          'type_tiers': tier[1],
          'adresse': tier[2],
          'telephone': tier[3],
          'email': tier[4],
        });
      }

      // Insérer quelques journaux
      final journaux = [
        ['VTE', 'Journal des ventes', 'Vente'],
        ['ACH', 'Journal des achats', 'Achat'],
        ['BQ', 'Journal de banque', 'Banque'],
        ['CAIS', 'Journal de caisse', 'Caisse'],
        ['OD', 'Opérations diverses', 'Divers'],
      ];

      for (var journal in journaux) {
        await db.insert('journal', {
          'code': journal[0],
          'libelle': journal[1],
          'type_journal': journal[2],
        });
      }

      // Insérer quelques bailleurs
      final bailleurs = [
        [
          'Union Européenne',
          'Institution internationale',
          'Belgique',
          'Jean Dupont',
          'eu@example.com',
          '+32 2 123 45 67',
        ],
        [
          'Banque Mondiale',
          'Institution financière',
          'États-Unis',
          'Sarah Johnson',
          'wb@example.com',
          '+1 202 123 4567',
        ],
        [
          'AFD',
          'Agence',
          'France',
          'Pierre Martin',
          'afd@example.com',
          '+33 1 23 45 67 89',
        ],
      ];

      for (var bailleur in bailleurs) {
        await db.insert('bailleur', {
          'nom': bailleur[0],
          'type_bailleur': bailleur[1],
          'pays': bailleur[2],
          'contact': bailleur[3],
          'email': bailleur[4],
          'telephone': bailleur[5],
        });
      }

      // Insérer quelques projets
      final projets = [
        ['PROJ001', 'Éducation pour tous', '2025-01-01', '2027-12-31', 'Actif'],
        ['PROJ002', 'Santé communautaire', '2024-06-01', '2026-05-31', 'Actif'],
        [
          'PROJ003',
          'Développement agricole',
          '2023-01-01',
          '2024-12-31',
          'Terminé',
        ],
      ];

      for (var projet in projets) {
        await db.insert('projet', {
          'code': projet[0],
          'intitule': projet[1],
          'date_debut': projet[2],
          'date_fin': projet[3],
          'statut': projet[4],
        });
      }

      // Insérer quelques budgets (liés à l'exercice 2025, id = 1)
      final budgets = [
        ['BUD2025-01', 'Budget Éducation 2025', 1, 50000000.0, 1],
        ['BUD2025-02', 'Budget Santé 2025', 1, 35000000.0, 2],
      ];

      for (var budget in budgets) {
        await db.insert('budget', {
          'code': budget[0],
          'intitule': budget[1],
          'exercice_id': budget[2],
          'montant': budget[3],
          'projet_id': budget[4],
        });
      }

      // Insérer les monnaies
      final monnaies = [
        ['XOF', 'Franc CFA', 'FCFA', 1],
        ['EUR', 'Euro', '€', 0],
        ['USD', 'Dollar américain', '\$', 0],
        ['GBP', 'Livre sterling', '£', 0],
      ];

      for (var monnaie in monnaies) {
        await db.insert('monnaie', {
          'code': monnaie[0],
          'nom': monnaie[1],
          'symbole': monnaie[2],
          'is_active': monnaie[3],
        });
      }

      print('Données de test insérées avec succès');
    },
  );

  await db.close();

  print('\n✅ Fichier exemple.db créé avec succès !');
  print('📁 Emplacement: $dbPath');
  print('\nContenu:');
  print('  - 1 entité: ONG Développement Communautaire');
  print('  - 10 comptes dans le plan comptable');
  print('  - 3 tiers (fournisseurs, clients, prestataires)');
  print('  - 5 journaux comptables');
  print('  - 3 bailleurs de fonds');
  print('  - 3 projets');
  print('  - 2 budgets');
  print('  - 4 monnaies (FCFA actif par défaut)');
  print('\nPas de mot de passe configuré.');
}
