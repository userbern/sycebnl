import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import 'dossier_crypto_service.dart';
import '../models/entite.dart';
import '../models/compte.dart';
import '../models/tiers.dart';
import '../models/journal.dart';
import '../models/bailleur.dart';
import '../models/projet.dart';
import '../models/exercice.dart';

class AuthService {
  static Database get _db => DatabaseService.database;

  /// Se connecter avec login et password
  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    try {
      // 1. Récupérer l'utilisateur par login
      final users = await _db.query(
        'utilisateur',
        where: 'login = ? AND deleted_at IS NULL',
        whereArgs: [login],
      );

      if (users.isEmpty) {
        throw Exception('Login ou mot de passe incorrect');
      }

      final user = users.first;

      // 2. Vérifier le mot de passe (Argon2id si migré, sinon SHA-256 legacy)
      final algo = user['password_algo'] as String? ?? 'sha256';
      final storedHash = user['password'] as String;
      bool passwordOk;
      if (algo == 'argon2id') {
        final salt = user['password_salt'] as String?;
        passwordOk = salt != null &&
            await DossierCryptoService.verifySecret(password, storedHash, salt);
      } else {
        passwordOk = DatabaseService.verifyPassword(password, storedHash);
        if (passwordOk) {
          // Migration transparente SHA-256 -> Argon2id après connexion réussie.
          final (newHash, newSalt) =
              await DossierCryptoService.hashSecret(password);
          await _db.update(
            'utilisateur',
            {
              'password': newHash,
              'password_algo': 'argon2id',
              'password_salt': newSalt,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
      if (!passwordOk) {
        throw Exception('Login ou mot de passe incorrect');
      }

      // 3. Récupérer les permissions de l'utilisateur
      final permissions = await _db.rawQuery(
        '''
        SELECT p.*, m.nom as module_nom
        FROM permissions p
        JOIN modules m ON p.module_id = m.id
        WHERE p.utilisateur_id = ?
      ''',
        [user['id']],
      );

      // 4. Formater les données de session
      return {
        'user': {
          'id': user['id'],
          'login': user['login'],
          'nom': user['nom'],
          'prenom': user['prenom'],
          'role': user['role'] ?? 'utilisateur',
        },
        'permissions':
            permissions
                .map(
                  (p) => {
                    'module_nom': p['module_nom'],
                    'lecture': p['lecture'],
                    'ajout': p['ajout'],
                    'modification': p['modification'],
                    'suppression': p['suppression'],
                  },
                )
                .toList(),
      };
    } catch (e) {
      throw Exception('Erreur lors du login: $e');
    }
  }

  /// Vérifier si l'utilisateur courant est admin (rôle = 'admin')
  static Future<bool> isCurrentUserAdmin(int currentUserId) async {
    try {
      final rows = await _db.query(
        'utilisateur',
        columns: ['role'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [currentUserId],
        limit: 1,
      );

      if (rows.isEmpty) return false;

      return (rows.first['role'] as String?)?.toLowerCase() == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Créer un nouvel utilisateur (inscription)
  /// Seul l'admin (premier utilisateur) peut créer des utilisateurs
  static Future<int> createUser({
    required String login,
    required String password,
    required String nom,
    required String prenom,
    String? email,
    String role = 'utilisateur',
    int? createdBy,
  }) async {
    try {
      // Vérifier que seul l'admin peut créer des utilisateurs
      if (createdBy != null) {
        final isAdmin = await isCurrentUserAdmin(createdBy);
        if (!isAdmin) {
          throw Exception(
            'Seul l\'administrateur peut créer de nouveaux utilisateurs',
          );
        }
      }

      // Vérifier si le login existe déjà
      final existing = await _db.query(
        'utilisateur',
        where: 'login = ?',
        whereArgs: [login],
      );

      if (existing.isNotEmpty) {
        throw Exception('Ce login existe déjà');
      }

      // Hasher le mot de passe (Argon2id pour tout nouvel utilisateur)
      final (hashedPassword, salt) =
          await DossierCryptoService.hashSecret(password);

      // Insérer l'utilisateur
      final userId = await _db.insert('utilisateur', {
        'login': login,
        'password': hashedPassword,
        'password_algo': 'argon2id',
        'password_salt': salt,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'role': role,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return userId;
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'utilisateur: $e');
    }
  }

  /// Hache un mot de passe en Argon2id, retourne (hash, sel) à stocker dans
  /// les colonnes `password`/`password_salt` avec `password_algo='argon2id'`.
  static Future<(String, String)> _hashPassword(String password) {
    return DossierCryptoService.hashSecret(password);
  }

  /// Récupérer la liste de tous les utilisateurs
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final users = await _db.query(
        'utilisateur',
        where: 'deleted_at IS NULL',
        orderBy: 'login ASC',
      );
      return users;
    } catch (e) {
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }

  /// Mettre à jour un utilisateur
  static Future<void> updateUser({
    required int id,
    String? login,
    String? password,
    String? nom,
    String? prenom,
    String? email,
    String? role,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (login != null) data['login'] = login;
      if (password != null) {
        final (hash, salt) = await _hashPassword(password);
        data['password'] = hash;
        data['password_algo'] = 'argon2id';
        data['password_salt'] = salt;
      }
      if (nom != null) data['nom'] = nom;
      if (prenom != null) data['prenom'] = prenom;
      if (email != null) data['email'] = email;
      if (role != null) data['role'] = role;
      if (isActive != null) data['is_active'] = isActive ? 1 : 0;

      await _db.update('utilisateur', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'utilisateur: $e');
    }
  }

  /// Réinitialiser le mot de passe d'un utilisateur (action admin, sans ancien mot de passe)
  static Future<void> resetPassword({
    required int userId,
    required String newPassword,
  }) async {
    await changePassword(
      userId: userId,
      newPassword: newPassword,
      isAdmin: true,
    );
  }

  /// Supprimer un utilisateur (soft delete)
  static Future<void> deleteUser(int id) async {
    try {
      await _db.update(
        'utilisateur',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'utilisateur: $e');
    }
  }

  /// Changer le mot de passe d'un utilisateur
  static Future<void> changePassword({
    required int userId,
    String? oldPassword,
    required String newPassword,
    required bool isAdmin,
  }) async {
    try {
      if (!isAdmin) {
        if (oldPassword == null || oldPassword.isEmpty) {
          throw Exception('L\'ancien mot de passe est requis');
        }

        final user = await _db.query(
          'utilisateur',
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [userId],
          limit: 1,
        );

        if (user.isEmpty) {
          throw Exception('Utilisateur non trouvé');
        }

        final storedHash = user.first['password'] as String?;
        final algo = user.first['password_algo'] as String? ?? 'sha256';
        bool oldPasswordOk = false;
        if (storedHash != null) {
          if (algo == 'argon2id') {
            final salt = user.first['password_salt'] as String?;
            oldPasswordOk = salt != null &&
                await DossierCryptoService.verifySecret(
                  oldPassword,
                  storedHash,
                  salt,
                );
          } else {
            oldPasswordOk =
                DatabaseService.verifyPassword(oldPassword, storedHash);
          }
        }
        if (!oldPasswordOk) {
          throw Exception('Ancien mot de passe incorrect');
        }
      }

      final (newHash, newSalt) = await _hashPassword(newPassword);
      await _db.update(
        'utilisateur',
        {
          'password': newHash,
          'password_algo': 'argon2id',
          'password_salt': newSalt,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw Exception('Erreur lors du changement de mot de passe: $e');
    }
  }

  // ==================== ENTITÉS ====================

  static Future<List<Entite>> getEntites() async {
    try {
      final results = await _db.query(
        'entite',
        where: 'deleted_at IS NULL',
        orderBy: 'denomination_sociale ASC',
      );
      return results.map((e) => Entite.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des entités: $e');
    }
  }

  static Future<void> createEntite({
    required String denominationSociale,
    String? sigleUsuel,
    String? domaineIntervention,
    String? formeJuridique,
    String? ongType,
    String? pays,
    String? region,
    String? ville,
    String? quartier,
    String? email,
    String? telephone,
    String? fixeFax,
    String? numeroFiscal,
    String? numeroCnss,
    String? numeroRecepisse,
    String? informationsComplementaires,
    String? currency,
  }) async {
    try {
      await _db.insert('entite', {
        'denomination_sociale': denominationSociale,
        'sigle_usuel': sigleUsuel,
        'domaine_intervention': domaineIntervention,
        'forme_juridique': formeJuridique,
        'ong_type': ongType,
        'pays': pays,
        'region': region,
        'ville': ville,
        'quartier': quartier,
        'email': email,
        'telephone': telephone,
        'fixe_fax': fixeFax,
        'numero_fiscal': numeroFiscal,
        'numero_cnss': numeroCnss,
        'numero_recepisse': numeroRecepisse,
        'informations_complementaires': informationsComplementaires,
        'currency': currency,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'created_by': _currentUser?['id'],
        'is_active': 1,
      });
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'entité: $e');
    }
  }

  static Future<void> updateEntite({
    required int id,
    String? denominationSociale,
    String? sigleUsuel,
    String? domaineIntervention,
    String? formeJuridique,
    String? ongType,
    String? pays,
    String? region,
    String? ville,
    String? quartier,
    String? email,
    String? telephone,
    String? fixeFax,
    String? numeroFiscal,
    String? numeroCnss,
    String? numeroRecepisse,
    String? informationsComplementaires,
    String? currency,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (denominationSociale != null) {
        data['denomination_sociale'] = denominationSociale;
      }
      if (sigleUsuel != null) data['sigle_usuel'] = sigleUsuel;
      if (domaineIntervention != null) {
        data['domaine_intervention'] = domaineIntervention;
      }
      if (formeJuridique != null) data['forme_juridique'] = formeJuridique;
      if (ongType != null) data['ong_type'] = ongType;
      if (pays != null) data['pays'] = pays;
      if (region != null) data['region'] = region;
      if (ville != null) data['ville'] = ville;
      if (quartier != null) data['quartier'] = quartier;
      if (email != null) data['email'] = email;
      if (telephone != null) data['telephone'] = telephone;
      if (fixeFax != null) data['fixe_fax'] = fixeFax;
      if (numeroFiscal != null) data['numero_fiscal'] = numeroFiscal;
      if (numeroCnss != null) data['numero_cnss'] = numeroCnss;
      if (numeroRecepisse != null) data['numero_recepisse'] = numeroRecepisse;
      if (informationsComplementaires != null) {
        data['informations_complementaires'] = informationsComplementaires;
      }
      if (currency != null) data['currency'] = currency;

      await _db.update('entite', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'entité: $e');
    }
  }

  static Future<void> deleteEntite(int id) async {
    try {
      await _db.update(
        'entite',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'entité: $e');
    }
  }

  // ==================== COMPTES ====================

  static Future<List<Compte>> getComptes() async {
    try {
      final results = await _db.query(
        'compte',
        where: 'is_active = ? AND deleted_at IS NULL',
        whereArgs: [1],
        orderBy: 'numero_compte ASC',
      );
      return results.map((c) => Compte.fromMap(c)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des comptes: $e');
    }
  }

  static Future<void> createCompte({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String nature,
  }) async {
    try {
      await _db.insert('compte', {
        'numero_compte': numeroCompte,
        'intitule': intitule,
        'type': type,
        'nature': nature,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la création du compte: $e');
    }
  }

  static Future<void> updateCompte({
    required int id,
    String? numeroCompte,
    String? intitule,
    String? type,
    String? nature,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (numeroCompte != null) data['numero_compte'] = numeroCompte;
      if (intitule != null) data['intitule'] = intitule;
      if (type != null) data['type'] = type;
      if (nature != null) data['nature'] = nature;

      await _db.update('compte', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du compte: $e');
    }
  }

  static Future<void> deleteCompte(int id) async {
    try {
      // Récupérer le numéro du compte
      final results = await _db.query(
        'compte',
        where: 'id = ?',
        whereArgs: [id],
        columns: ['numero_compte'],
      );

      if (results.isEmpty) {
        throw Exception('Compte non trouvé');
      }

      final numeroCompte = results.first['numero_compte'] as String;

      // Vérifier s'il y a des écritures liées à ce compte
      final ecrituresResults = await _db.rawQuery(
        '''
        SELECT le.id FROM ligne_ecriture le
        WHERE le.numero_compte = ? AND le.id IS NOT NULL
        LIMIT 1
      ''',
        [numeroCompte],
      );

      if (ecrituresResults.isNotEmpty) {
        throw Exception(
          'Ce compte a des écritures et ne peut pas être supprimé',
        );
      }

      // Vérifier s'il y a des tiers liés à ce compte
      final tiersResults = await _db.query(
        'tiers',
        where: 'compte_collectif = ?',
        whereArgs: [numeroCompte],
      );

      if (tiersResults.isNotEmpty) {
        throw Exception(
          'Ce compte a des tiers associés et ne peut pas être supprimé',
        );
      }

      // Soft delete le compte
      await _db.update(
        'compte',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du compte: $e');
    }
  }

  // ==================== TIERS ====================

  static Future<List<Tiers>> getTiers() async {
    try {
      final results = await _db.query(
        'tiers',
        where: 'is_active = ? AND deleted_at IS NULL',
        whereArgs: [1],
        orderBy: 'intitule ASC',
      );
      return results.map((t) => Tiers.fromMap(t)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des tiers: $e');
    }
  }

  static Future<void> createTiers({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String compteCollectif,
    String? nif,
    String? adresse,
  }) async {
    try {
      await _db.insert('tiers', {
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
    } catch (e) {
      throw Exception('Erreur lors de la création du tiers: $e');
    }
  }

  static Future<void> updateTiers({
    required int id,
    String? numeroCompte,
    String? intitule,
    String? type,
    String? compteCollectif,
    String? nif,
    String? adresse,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (numeroCompte != null) data['numero_compte'] = numeroCompte;
      if (intitule != null) data['intitule'] = intitule;
      if (type != null) data['type'] = type;
      if (compteCollectif != null) data['compte_collectif'] = compteCollectif;
      if (nif != null) data['nif'] = nif;
      if (adresse != null) data['adresse'] = adresse;

      await _db.update('tiers', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du tiers: $e');
    }
  }

  static Future<void> deleteTiers(int id) async {
    try {
      // Récupérer le numéro du compte du tiers
      final results = await _db.query(
        'tiers',
        where: 'id = ?',
        whereArgs: [id],
        columns: ['numero_compte'],
      );

      if (results.isEmpty) {
        throw Exception('Tiers non trouvé');
      }

      final numeroCompte = results.first['numero_compte'] as String?;

      // Vérifier s'il y a des écritures liées à ce tiers
      if (numeroCompte != null && numeroCompte.isNotEmpty) {
        final ecrituresResults = await _db.rawQuery(
          '''
          SELECT le.id FROM ligne_ecriture le
          WHERE le.numero_compte = ? AND le.id IS NOT NULL
          LIMIT 1
        ''',
          [numeroCompte],
        );

        if (ecrituresResults.isNotEmpty) {
          throw Exception(
            'Ce tiers a des écritures et ne peut pas être supprimé',
          );
        }
      }

      // Soft delete le tiers
      await _db.update(
        'tiers',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du tiers: $e');
    }
  }

  // ==================== JOURNAUX ====================

  static Future<List<Journal>> getJournaux() async {
    try {
      final results = await _db.query(
        'journal',
        where: 'is_active = ? AND deleted_at IS NULL',
        whereArgs: [1],
        orderBy: 'code ASC',
      );
      return results.map((j) => Journal.fromMap(j)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des journaux: $e');
    }
  }

  static Future<void> createJournal({
    required String code,
    required String libelle,
    required String type,
    String? numeroCompteFresorerie,
    bool saisieAnalytique = false,
  }) async {
    try {
      await _db.insert('journal', {
        'code': code,
        'libelle': libelle,
        'type': type,
        'numero_compte_tresorerie': numeroCompteFresorerie,
        'saisie_analytique': saisieAnalytique ? 1 : 0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la création du journal: $e');
    }
  }

  static Future<void> updateJournal({
    required int id,
    String? code,
    String? libelle,
    String? type,
    String? numeroCompteFresorerie,
    bool? saisieAnalytique,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (code != null) data['code'] = code;
      if (libelle != null) data['libelle'] = libelle;
      if (type != null) data['type'] = type;
      if (numeroCompteFresorerie != null) {
        data['numero_compte_tresorerie'] = numeroCompteFresorerie;
      }
      if (saisieAnalytique != null) {
        data['saisie_analytique'] = saisieAnalytique ? 1 : 0;
      }
      if (libelle != null) data['libelle'] = libelle;
      if (type != null) data['type'] = type;

      await _db.update('journal', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du journal: $e');
    }
  }

  static Future<void> deleteJournal(int id) async {
    try {
      // Récupérer le code du journal
      final results = await _db.query(
        'journal',
        where: 'id = ?',
        whereArgs: [id],
        columns: ['code'],
      );

      if (results.isEmpty) {
        throw Exception('Journal non trouvé');
      }

      final codeJournal = results.first['code'] as String;

      // Vérifier s'il y a des périodes avec des écritures
      final periodResults = await _db.rawQuery(
        '''
        SELECT jp.id FROM journaux_periodes jp
        LEFT JOIN ecritures e ON jp.id = e.journal_periode_id
        WHERE jp.code_journal = ? AND e.id IS NOT NULL
        LIMIT 1
      ''',
        [codeJournal],
      );

      if (periodResults.isNotEmpty) {
        throw Exception(
          'Ce journal contient des écritures et ne peut pas être supprimé',
        );
      }

      // Soft delete le journal
      await _db.update(
        'journal',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du journal: $e');
    }
  }

  // ==================== BAILLEURS ====================

  static Future<List<Bailleur>> getBailleurs() async {
    try {
      final results = await _db.query(
        'bailleur',
        where: 'deleted_at IS NULL',
        orderBy: 'sigle ASC',
      );
      return results.map((b) => Bailleur.fromMap(b)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des bailleurs: $e');
    }
  }

  static Future<void> createBailleur({
    required String code,
    required String nom,
    String? typeBailleur,
    String? pays,
    String? contact,
    String? email,
  }) async {
    try {
      await _db.insert('bailleur', {
        'sigle': code,
        'designation': nom,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      });
    } catch (e) {
      throw Exception('Erreur lors de la création du bailleur: $e');
    }
  }

  static Future<void> updateBailleur({
    required int id,
    String? code,
    String? nom,
    String? typeBailleur,
    String? pays,
    String? contact,
    String? email,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (code != null) data['sigle'] = code;
      if (nom != null) data['designation'] = nom;

      await _db.update('bailleur', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du bailleur: $e');
    }
  }

  static Future<void> deleteBailleur(int id) async {
    try {
      // Soft delete: mettre à jour deleted_at au lieu de supprimer physiquement
      await _db.update(
        'bailleur',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du bailleur: $e');
    }
  }

  // ==================== PROJETS ====================

  static Future<List<Projet>> getProjets() async {
    try {
      final results = await _db.query(
        'projet',
        where: 'deleted_at IS NULL',
        orderBy: 'designation ASC',
      );
      return results.map((p) => Projet.fromMap(p)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des projets: $e');
    }
  }

  /// Récupérer les projets avec les informations du bailleur
  static Future<List<Map<String, dynamic>>> getProjetsWithBailleur() async {
    try {
      final results = await _db.rawQuery('''
        SELECT 
          p.id,
          p.code,
          p.designation,
          p.date_debut,
          p.date_fin,
          p.created_at,
          p.updated_at,
          p.deleted_at,
          GROUP_CONCAT(b.sigle || ' - ' || b.designation) as bailleurs
        FROM projet p
        LEFT JOIN projet_bailleur pb ON p.id = pb.projet_id
        LEFT JOIN bailleur b ON pb.bailleur_id = b.id
        GROUP BY p.id
        ORDER BY p.code ASC
      ''');
      return results;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des projets avec bailleur: $e',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getBailleursForProjet(
    int projetId,
  ) async {
    try {
      final results = await _db.rawQuery(
        '''
        SELECT b.id, b.sigle, b.designation
        FROM bailleur b
        INNER JOIN projet_bailleur pb ON b.id = pb.bailleur_id
        WHERE pb.projet_id = ? AND b.deleted_at IS NULL
      ''',
        [projetId],
      );
      return results;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des bailleurs du projet: $e',
      );
    }
  }

  static Future<void> createProjet({
    required String code,
    required String designation,
    List<int>? bailleurIds,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    try {
      // Insérer le projet
      final projetId = await _db.insert('projet', {
        'code': code,
        'designation': designation,
        'date_debut': dateDebut?.toIso8601String() ?? '',
        'date_fin': dateFin?.toIso8601String() ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insérer les relations projet-bailleur
      if (bailleurIds != null && bailleurIds.isNotEmpty) {
        for (final bailleurId in bailleurIds) {
          await _db.insert('projet_bailleur', {
            'projet_id': projetId,
            'bailleur_id': bailleurId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la création du projet: $e');
    }
  }

  static Future<void> updateProjet({
    required int id,
    String? code,
    String? designation,
    List<int>? bailleurIds,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (code != null) data['code'] = code;
      if (designation != null) data['designation'] = designation;
      if (dateDebut != null) data['date_debut'] = dateDebut.toIso8601String();
      if (dateFin != null) data['date_fin'] = dateFin.toIso8601String();

      await _db.update('projet', data, where: 'id = ?', whereArgs: [id]);

      // Mettre à jour les bailleurs si fournis
      if (bailleurIds != null) {
        // Supprimer les anciennes relations
        await _db.delete(
          'projet_bailleur',
          where: 'projet_id = ?',
          whereArgs: [id],
        );

        // Insérer les nouvelles relations
        for (final bailleurId in bailleurIds) {
          await _db.insert('projet_bailleur', {
            'projet_id': id,
            'bailleur_id': bailleurId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du projet: $e');
    }
  }

  static Future<void> deleteProjet(int id) async {
    try {
      // Soft-delete: mettre à jour deleted_at
      await _db.update(
        'projet',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du projet: $e');
    }
  }

  // ==================== BUDGETS ====================

  // Récupérer tous les budgets (projet + bailleur) filtrés par exercice
  static Future<List<Map<String, dynamic>>> getBudgetsWithDetails({
    required int exerciceId,
  }) async {
    try {
      // Vérifier d'abord si la colonne exercice_id existe
      final columns = await _db.rawQuery("PRAGMA table_info(budget)");
      final hasExerciceId = columns.any((col) => col['name'] == 'exercice_id');

      late List<Map<String, dynamic>> results;

      if (hasExerciceId) {
        // Si la colonne existe, l'utiliser dans le WHERE
        results = await _db.rawQuery(
          '''
          SELECT 
            b.id,
            b.projet_id,
            b.bailleur_id,
            COALESCE(b.exercice_id, 0) as exercice_id,
            b.created_at,
            b.updated_at,
            b.deleted_at,
            p.code as projet_code,
            p.designation as projet_designation,
            ba.sigle as bailleur_sigle,
            ba.designation as bailleur_designation
          FROM budget b
          LEFT JOIN projet p ON b.projet_id = p.id
          LEFT JOIN bailleur ba ON b.bailleur_id = ba.id
          WHERE b.deleted_at IS NULL AND b.exercice_id = ?
          ORDER BY p.code ASC, ba.sigle ASC
        ''',
          [exerciceId],
        );
      } else {
        // Si la colonne n'existe pas, retourner une liste vide
        // Les budgets anciens sans exercice_id ne seront pas visibles
        results = [];
      }

      return results;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des budgets avec détails: $e',
      );
    }
  }

  // Créer un budget (projet + bailleur + exercice)
  static Future<int> createBudget({
    required int projetId,
    required int bailleurId,
    required int exerciceId,
  }) async {
    try {
      // Vérifier s'il existe un budget supprimé avec cette combinaison
      final existingBudget = await _db.query(
        'budget',
        where: 'projet_id = ? AND bailleur_id = ? AND exercice_id = ?',
        whereArgs: [projetId, bailleurId, exerciceId],
      );

      if (existingBudget.isNotEmpty) {
        final budget = existingBudget.first;
        final deletedAt = budget['deleted_at'];

        // Si le budget existe et n'est pas supprimé, c'est une violation de contrainte
        if (deletedAt == null) {
          throw Exception(
            'Un budget existe déjà pour cette combinaison projet + bailleur + exercice',
          );
        }

        // Si le budget est supprimé, le réactiver
        await _db.update(
          'budget',
          {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [budget['id']],
        );
        return budget['id'] as int;
      }

      // Sinon, créer un nouveau budget
      final budgetId = await _db.insert('budget', {
        'projet_id': projetId,
        'bailleur_id': bailleurId,
        'exercice_id': exerciceId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return budgetId;
    } catch (e) {
      throw Exception('Erreur lors de la création du budget: $e');
    }
  }

  // Supprimer un budget (soft-delete)
  static Future<void> deleteBudget(int budgetId) async {
    try {
      await _db.update(
        'budget',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [budgetId],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du budget: $e');
    }
  }

  // ==================== POSTES BUDGETAIRES ====================

  static Future<List<Map<String, dynamic>>> getPostesBudgetaires(
    int budgetId,
  ) async {
    try {
      final results = await _db.query(
        'poste_budgetaire',
        where: 'budget_id = ? AND deleted_at IS NULL',
        whereArgs: [budgetId],
        orderBy: 'intitule ASC',
      );
      return results;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des postes budgétaires: $e',
      );
    }
  }

  static Future<int> createPosteBudgetaire({
    required int budgetId,
    required String intitule,
  }) async {
    try {
      final posteId = await _db.insert('poste_budgetaire', {
        'budget_id': budgetId,
        'intitule': intitule,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return posteId;
    } catch (e) {
      throw Exception('Erreur lors de la création du poste budgétaire: $e');
    }
  }

  static Future<void> updatePosteBudgetaire({
    required int posteId,
    String? intitule,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (intitule != null) data['intitule'] = intitule;

      await _db.update(
        'poste_budgetaire',
        data,
        where: 'id = ?',
        whereArgs: [posteId],
      );
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du poste budgétaire: $e');
    }
  }

  static Future<void> deletePosteBudgetaire(int posteId) async {
    try {
      await _db.update(
        'poste_budgetaire',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [posteId],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression du poste budgétaire: $e');
    }
  }

  // ==================== LIGNES BUDGETAIRES ====================

  static Future<List<Map<String, dynamic>>> getLignesBudgetaires(
    int posteId,
  ) async {
    try {
      final results = await _db.query(
        'ligne_budgetaire',
        where: 'poste_budgetaire_id = ? AND deleted_at IS NULL',
        whereArgs: [posteId],
        orderBy: 'code ASC',
      );
      return results;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des lignes budgétaires: $e',
      );
    }
  }

  static Future<int> createLigneBudgetaire({
    required int posteBudgetaireId,
    required String code,
    required String intitule,
  }) async {
    try {
      final ligneId = await _db.insert('ligne_budgetaire', {
        'poste_budgetaire_id': posteBudgetaireId,
        'code': code,
        'intitule': intitule,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return ligneId;
    } catch (e) {
      throw Exception('Erreur lors de la création de la ligne budgétaire: $e');
    }
  }

  static Future<void> updateLigneBudgetaire({
    required int ligneId,
    String? code,
    String? intitule,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (code != null) data['code'] = code;
      if (intitule != null) data['intitule'] = intitule;

      await _db.update(
        'ligne_budgetaire',
        data,
        where: 'id = ?',
        whereArgs: [ligneId],
      );
    } catch (e) {
      throw Exception(
        'Erreur lors de la mise à jour de la ligne budgétaire: $e',
      );
    }
  }

  static Future<void> deleteLigneBudgetaire(int ligneId) async {
    try {
      await _db.update(
        'ligne_budgetaire',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [ligneId],
      );
    } catch (e) {
      throw Exception(
        'Erreur lors de la suppression de la ligne budgétaire: $e',
      );
    }
  }

  // ==================== SOUS-RUBRIQUES ====================

  static Future<List<Map<String, dynamic>>> getSousRubriques(
    int ligneBudgetaireId,
  ) async {
    try {
      final results = await _db.rawQuery(
        '''
        SELECT 
          sr.id,
          sr.ligne_budgetaire_id,
          sr.intitule,
          sr.montant,
          sr.compte_id,
          sr.created_at,
          sr.updated_at,
          sr.deleted_at,
          c.numero_compte,
          c.intitule as compte_intitule
        FROM sous_rubrique sr
        LEFT JOIN compte c ON sr.compte_id = c.id
        WHERE sr.ligne_budgetaire_id = ? AND sr.deleted_at IS NULL
        ORDER BY sr.intitule ASC
      ''',
        [ligneBudgetaireId],
      );
      return results;
    } catch (e) {
      throw Exception('Erreur lors de la récupération des sous-rubriques: $e');
    }
  }

  static Future<int> createSousRubrique({
    required int ligneBudgetaireId,
    required String intitule,
    required double montant,
    int? compteId,
  }) async {
    try {
      final sousRubriqueId = await _db.insert('sous_rubrique', {
        'ligne_budgetaire_id': ligneBudgetaireId,
        'intitule': intitule,
        'montant': montant,
        'compte_id': compteId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return sousRubriqueId;
    } catch (e) {
      throw Exception('Erreur lors de la création de la sous-rubrique: $e');
    }
  }

  static Future<void> updateSousRubrique({
    required int sousRubriqueId,
    String? intitule,
    double? montant,
    int? compteId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (intitule != null) data['intitule'] = intitule;
      if (montant != null) data['montant'] = montant;
      if (compteId != null) data['compte_id'] = compteId;

      await _db.update(
        'sous_rubrique',
        data,
        where: 'id = ?',
        whereArgs: [sousRubriqueId],
      );
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la sous-rubrique: $e');
    }
  }

  static Future<void> deleteSousRubrique(int sousRubriqueId) async {
    try {
      await _db.update(
        'sous_rubrique',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sousRubriqueId],
      );
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la sous-rubrique: $e');
    }
  }

  // Récupérer le montant total d'une ligne budgétaire (somme des sous-rubriques)
  static Future<double> getMontantLigneBudgetaire(int ligneBudgetaireId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT SUM(montant) as total
        FROM sous_rubrique
        WHERE ligne_budgetaire_id = ? AND deleted_at IS NULL
      ''',
        [ligneBudgetaireId],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception(
        'Erreur lors du calcul du montant de la ligne budgétaire: $e',
      );
    }
  }

  // Récupérer le montant total d'un poste budgétaire (somme des lignes budgétaires)
  static Future<double> getMontantPosteBudgetaire(int posteBudgetaireId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT SUM(sr.montant) as total
        FROM sous_rubrique sr
        JOIN ligne_budgetaire lb ON sr.ligne_budgetaire_id = lb.id
        WHERE lb.poste_budgetaire_id = ? 
        AND sr.deleted_at IS NULL 
        AND lb.deleted_at IS NULL
      ''',
        [posteBudgetaireId],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception(
        'Erreur lors du calcul du montant du poste budgétaire: $e',
      );
    }
  }

  // Récupérer le montant total d'un budget
  static Future<double> getMontantBudget(int budgetId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT SUM(sr.montant) as total
        FROM sous_rubrique sr
        JOIN ligne_budgetaire lb ON sr.ligne_budgetaire_id = lb.id
        JOIN poste_budgetaire pb ON lb.poste_budgetaire_id = pb.id
        WHERE pb.budget_id = ? 
        AND sr.deleted_at IS NULL 
        AND lb.deleted_at IS NULL 
        AND pb.deleted_at IS NULL
      ''',
        [budgetId],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception('Erreur lors du calcul du montant du budget: $e');
    }
  }

  // ==================== PERMISSIONS ====================

  static Future<List<Map<String, dynamic>>> getPermissions(
    int utilisateurId,
  ) async {
    try {
      final results = await _db.rawQuery(
        '''
        SELECT p.*, m.nom as module_nom
        FROM permissions p
        JOIN modules m ON p.module_id = m.id
        WHERE p.utilisateur_id = ?
      ''',
        [utilisateurId],
      );
      return results;
    } catch (e) {
      throw Exception('Erreur lors de la récupération des permissions: $e');
    }
  }

  static Future<void> updatePermission({
    required int utilisateurId,
    required int moduleId,
    required bool lecture,
    required bool ajout,
    required bool modification,
    required bool suppression,
  }) async {
    try {
      // Vérifier si la permission existe
      final existing = await _db.query(
        'permissions',
        where: 'utilisateur_id = ? AND module_id = ?',
        whereArgs: [utilisateurId, moduleId],
      );

      if (existing.isEmpty) {
        // Créer la permission
        await _db.insert('permissions', {
          'utilisateur_id': utilisateurId,
          'module_id': moduleId,
          'lecture': lecture ? 1 : 0,
          'ajout': ajout ? 1 : 0,
          'modification': modification ? 1 : 0,
          'suppression': suppression ? 1 : 0,
        });
      } else {
        // Mettre à jour la permission
        await _db.update(
          'permissions',
          {
            'lecture': lecture ? 1 : 0,
            'ajout': ajout ? 1 : 0,
            'modification': modification ? 1 : 0,
            'suppression': suppression ? 1 : 0,
          },
          where: 'utilisateur_id = ? AND module_id = ?',
          whereArgs: [utilisateurId, moduleId],
        );
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la permission: $e');
    }
  }

  // ==================== MÉTHODES SUPPLÉMENTAIRES ====================

  /// Récupérer tous les modules
  static Future<List<Map<String, dynamic>>> getAllModules() async {
    try {
      return await _db.query('modules', orderBy: 'nom ASC');
    } catch (e) {
      throw Exception('Erreur lors de la récupération des modules: $e');
    }
  }

  /// Récupérer les permissions d'un utilisateur avec les noms des modules
  static Future<List<Map<String, dynamic>>> getUserPermissions(
    int userId,
  ) async {
    try {
      return await _db.rawQuery(
        '''
        SELECT 
          p.*,
          m.nom as module_nom
        FROM permissions p
        INNER JOIN modules m ON p.module_id = m.id
        WHERE p.utilisateur_id = ?
      ''',
        [userId],
      );
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des permissions utilisateur: $e',
      );
    }
  }

  /// Mettre à jour les permissions d'un utilisateur
  static Future<void> updatePermissions(
    int userId,
    List<Map<String, dynamic>> permissions,
  ) async {
    try {
      // Supprimer les anciennes permissions
      await _db.delete(
        'permissions',
        where: 'utilisateur_id = ?',
        whereArgs: [userId],
      );

      // Insérer les nouvelles permissions
      for (var permission in permissions) {
        await _db.insert('permissions', {
          'utilisateur_id': userId,
          'module_id': permission['moduleId'],
          'lecture': (permission['lecture'] == true) ? 1 : 0,
          'ajout': (permission['ajout'] == true) ? 1 : 0,
          'modification': (permission['modification'] == true) ? 1 : 0,
          'suppression': (permission['suppression'] == true) ? 1 : 0,
        });
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour des permissions: $e');
    }
  }

  /// Déconnexion
  static Future<void> logout() async {
    // Pour une base de données locale, logout signifie simplement effacer la session
    // Pas besoin d'appel serveur comme avec Supabase
    _currentUser = null;
  }

  // Utilisateur courant (pour tracking)
  static Map<String, dynamic>? _currentUser;

  /// Définir l'utilisateur courant
  static void setCurrentUser(Map<String, dynamic>? user) {
    _currentUser = user;
  }

  /// Obtenir l'utilisateur courant
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  /// Récupérer l'exercice comptable actif
  static Future<Exercice?> getExerciceActif() async {
    try {
      final result = await _db.query(
        'exercice',
        where: 'is_active = 1',
        limit: 1,
      );

      if (result.isEmpty) {
        return null;
      }

      return Exercice.fromMap(result.first);
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération de l\'exercice actif: $e',
      );
    }
  }
}
