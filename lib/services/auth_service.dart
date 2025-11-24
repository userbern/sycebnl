import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entite.dart';
import '../models/compte.dart';
import '../models/tiers.dart';
import '../models/journal.dart';

class AuthService {
  static late SupabaseClient _client;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!_initialized) {
      _client = Supabase.instance.client;
      _initialized = true;
    }
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
        'AuthService not initialized. Call AuthService.initialize() first.',
      );
    }
    return _client;
  }

  /// Se connecter avec email et password
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authentifier via Supabase Auth
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Authentification échouée');
      }

      // 2. Récupérer le profil utilisateur
      final userData =
          await client
              .from('utilisateur')
              .select('id, nom, prenom, email, role')
              .eq('id', authResponse.user!.id)
              .single();

      // 3. Récupérer les permissions de l'utilisateur
      final permissions = await client
          .from('permissions')
          .select('*, modules(nom)')
          .eq('utilisateur_id', authResponse.user!.id);

      // 4. Formatter les données de session
      return {'user': userData, 'permissions': permissions};
    } on AuthException catch (e) {
      throw Exception('Erreur d\'authentification: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors du login: $e');
    }
  }

  /// S'inscrire avec email et password
  static Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    try {
      return await client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception('Erreur d\'inscription: ${e.message}');
    }
  }

  /// Se déconnecter
  static Future<void> logout() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Vérifier si connecté
  static bool isLoggedIn() {
    return client.auth.currentUser != null;
  }

  /// Récupérer l'utilisateur actuel
  static User? getCurrentUser() {
    return client.auth.currentUser;
  }

  /// Récupérer la liste de tous les utilisateurs
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await client
          .from('utilisateur')
          .select('id, email, nom, prenom');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }

  /// Récupérer les permissions d'un utilisateur
  static Future<List<Map<String, dynamic>>> getUserPermissions(
    String userId,
  ) async {
    try {
      final response = await client
          .from('permissions')
          .select('*, modules(nom)')
          .eq('utilisateur_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des permissions: $e');
    }
  }

  /// Récupérer la liste de tous les modules
  static Future<List<Map<String, dynamic>>> getAllModules() async {
    try {
      final response = await client.from('modules').select('id, nom');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des modules: $e');
    }
  }

  /// Créer un nouvel utilisateur
  static Future<void> createUser({
    required String email,
    required String password,
    required String prenom,
    required String nom,
  }) async {
    try {
      // 1. Créer l'utilisateur dans Supabase Auth
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Impossible de créer l\'utilisateur');
      }

      // 2. Confirmer l'email automatiquement
      await client.rpc(
        'confirm_user_email',
        params: {'user_id': authResponse.user!.id},
      );

      // 3. Ajouter le profil dans la table utilisateur via fonction SQL
      await client.rpc(
        'create_user_profile',
        params: {
          'user_id': authResponse.user!.id,
          'user_email': email,
          'user_prenom': prenom,
          'user_nom': nom,
        },
      );

      // 4. Créer les permissions par défaut
      await client.rpc(
        'create_default_permissions',
        params: {'user_id': authResponse.user!.id},
      );
    } on AuthException catch (e) {
      throw Exception('Erreur création utilisateur: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'utilisateur: $e');
    }
  }

  /// Mettre à jour une permission
  static Future<void> updatePermission(
    String userId,
    int moduleId,
    String permission,
    bool value,
  ) async {
    try {
      await client
          .from('permissions')
          .update({permission: value})
          .eq('utilisateur_id', userId)
          .eq('module_id', moduleId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la permission: $e');
    }
  }

  /// Mettre à jour PLUSIEURS permissions d'un utilisateur en une transaction
  /// utilisé quand on clique sur "Enregistrer" pour sauvegarder tous les changements à la fois
  static Future<void> updatePermissions(
    String userId,
    List<Map<String, dynamic>> updates,
  ) async {
    try {
      // 'updates' est une liste de : {moduleId, lecture, ajout, modification, suppression}
      for (var update in updates) {
        await client
            .from('permissions')
            .update({
              'lecture': update['lecture'],
              'ajout': update['ajout'],
              'modification': update['modification'],
              'suppression': update['suppression'],
            })
            .eq('utilisateur_id', userId)
            .eq('module_id', update['moduleId']);
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour des permissions: $e');
    }
  }

  /// Créer les permissions par défaut pour un utilisateur
  static Future<void> createDefaultPermissions(String userId) async {
    try {
      await client.rpc(
        'create_default_permissions',
        params: {'user_id': userId},
      );
    } catch (e) {
      throw Exception('Erreur lors de la création des permissions: $e');
    }
  }

  // ============================================================
  // MÉTHODES POUR GÉRER LES ENTITÉS (IDENTIFICATION)
  // ============================================================

  /// Récupérer toutes les entités
  static Future<List<Entite>> getEntites() async {
    try {
      final response = await client
          .from('entite')
          .select()
          .order('denomination_sociale', ascending: true);

      return (response as List)
          .map((data) => Entite.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des entités: $e');
    }
  }

  /// Récupérer une entité par ID
  static Future<Entite> getEntiteById(String id) async {
    try {
      final response =
          await client.from('entite').select().eq('id', id).single();

      return Entite.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors du chargement de l\'entité: $e');
    }
  }

  /// Créer une nouvelle entité (seulement pour les admins)
  /// Le RLS policy va vérifier que l'utilisateur est admin
  static Future<Entite> createEntite({
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
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final response =
          await client
              .from('entite')
              .insert({
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
                'created_by': userId,
              })
              .select()
              .single();

      return Entite.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'entité: $e');
    }
  }

  /// Mettre à jour une entité (seulement pour les admins)
  static Future<Entite> updateEntite({
    required String id,
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
      // Créer un map avec seulement les champs non-null à mettre à jour
      final updateData = <String, dynamic>{};
      if (denominationSociale != null) {
        updateData['denomination_sociale'] = denominationSociale;
      }
      if (sigleUsuel != null) updateData['sigle_usuel'] = sigleUsuel;
      if (domaineIntervention != null) {
        updateData['domaine_intervention'] = domaineIntervention;
      }
      if (formeJuridique != null)
        updateData['forme_juridique'] = formeJuridique;
      if (ongType != null) updateData['ong_type'] = ongType;
      if (pays != null) updateData['pays'] = pays;
      if (region != null) updateData['region'] = region;
      if (ville != null) updateData['ville'] = ville;
      if (quartier != null) updateData['quartier'] = quartier;
      if (email != null) updateData['email'] = email;
      if (telephone != null) updateData['telephone'] = telephone;
      if (fixeFax != null) updateData['fixe_fax'] = fixeFax;
      if (numeroFiscal != null) updateData['numero_fiscal'] = numeroFiscal;
      if (numeroCnss != null) updateData['numero_cnss'] = numeroCnss;
      if (numeroRecepisse != null) {
        updateData['numero_recepisse'] = numeroRecepisse;
      }
      if (informationsComplementaires != null) {
        updateData['informations_complementaires'] =
            informationsComplementaires;
      }
      if (currency != null) updateData['currency'] = currency;

      final response =
          await client
              .from('entite')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return Entite.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'entité: $e');
    }
  }

  /// Supprimer une entité (soft delete) (seulement pour les admins)
  static Future<void> deleteEntite(String id) async {
    try {
      await client.from('entite').update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'entité: $e');
    }
  }

  /// Rechercher les entités par dénomination sociale
  static Future<List<Entite>> searchEntites(String query) async {
    try {
      final response = await client
          .from('entite')
          .select()
          .ilike('denomination_sociale', '%$query%')
          .order('denomination_sociale', ascending: true);

      return (response as List)
          .map((data) => Entite.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  // ============ MÉTHODES POUR GÉRER LES COMPTES COMPTABLES ============

  /// Récupérer tous les comptes comptables
  static Future<List<Compte>> getComptes() async {
    try {
      final response = await client
          .from('compte')
          .select()
          .eq('is_active', true)
          .order('numero_compte', ascending: true);

      return (response as List)
          .map((data) => Compte.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des comptes: $e');
    }
  }

  /// Créer un nouveau compte comptable
  static Future<Compte> createCompte({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String nature,
    required bool liaisonTiers,
    String? description,
  }) async {
    try {
      final response =
          await client
              .from('compte')
              .insert({
                'numero_compte': numeroCompte,
                'intitule': intitule,
                'type': type,
                'nature': nature,
                'liaison_tiers': liaisonTiers,
                'description': description,
              })
              .select()
              .single();

      return Compte.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création du compte: $e');
    }
  }

  /// Mettre à jour un compte comptable
  static Future<Compte> updateCompte({
    required String id,
    String? numeroCompte,
    String? intitule,
    String? type,
    String? nature,
    bool? liaisonTiers,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (numeroCompte != null) updateData['numero_compte'] = numeroCompte;
      if (intitule != null) updateData['intitule'] = intitule;
      if (type != null) updateData['type'] = type;
      if (nature != null) updateData['nature'] = nature;
      if (liaisonTiers != null) updateData['liaison_tiers'] = liaisonTiers;
      if (description != null) updateData['description'] = description;

      final response =
          await client
              .from('compte')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return Compte.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du compte: $e');
    }
  }

  /// Supprimer un compte comptable (soft delete)
  static Future<void> deleteCompte(String id) async {
    try {
      await client.from('compte').update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du compte: $e');
    }
  }

  // ============ GESTION DES TIERS ============

  /// Récupérer tous les tiers
  static Future<List<Tiers>> getTiers() async {
    try {
      final response = await client
          .from('tiers')
          .select()
          .eq('is_active', true)
          .order('numero_compte', ascending: true);

      return (response as List)
          .map((item) => Tiers.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des tiers: $e');
    }
  }

  /// Chercher des tiers
  static Future<List<Tiers>> searchTiers(String query) async {
    try {
      final response = await client
          .from('tiers')
          .select()
          .eq('is_active', true)
          .or('numero_compte.ilike.%$query%,intitule.ilike.%$query%')
          .order('numero_compte', ascending: true);

      return (response as List)
          .map((item) => Tiers.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche de tiers: $e');
    }
  }

  /// Créer un nouveau tiers
  static Future<void> createTiers({
    required String numeroCompte,
    required String intitule,
    required String type,
    required String compteCollectif,
    String? nif,
    String? adresse,
  }) async {
    try {
      await client.from('tiers').insert({
        'numero_compte': numeroCompte,
        'intitule': intitule,
        'type': type,
        'compte_collectif': compteCollectif,
        'nif': nif,
        'adresse': adresse,
        'is_active': true,
      });
    } catch (e) {
      throw Exception('Erreur lors de la création du tiers: $e');
    }
  }

  /// Modifier un tiers
  static Future<void> updateTiers({
    required String id,
    String? numeroCompte,
    String? intitule,
    String? type,
    String? compteCollectif,
    String? nif,
    String? adresse,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (numeroCompte != null) updateData['numero_compte'] = numeroCompte;
      if (intitule != null) updateData['intitule'] = intitule;
      if (type != null) updateData['type'] = type;
      if (compteCollectif != null)
        updateData['compte_collectif'] = compteCollectif;
      if (nif != null) updateData['nif'] = nif;
      if (adresse != null) updateData['adresse'] = adresse;

      await client.from('tiers').update(updateData).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la modification du tiers: $e');
    }
  }

  /// Supprimer un tiers (soft delete)
  static Future<void> deleteTiers(String id) async {
    try {
      await client.from('tiers').update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du tiers: $e');
    }
  }

  // ============ GESTION DES JOURNAUX ============

  /// Récupérer tous les journaux
  static Future<List<Journal>> getJournaux() async {
    try {
      final response = await client
          .from('journal')
          .select()
          .eq('is_active', true)
          .order('code', ascending: true);

      return (response as List)
          .map((item) => Journal.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des journaux: $e');
    }
  }

  /// Chercher des journaux
  static Future<List<Journal>> searchJournaux(String query) async {
    try {
      final response = await client
          .from('journal')
          .select()
          .eq('is_active', true)
          .or('code.ilike.%$query%,intitule.ilike.%$query%')
          .order('code', ascending: true);

      return (response as List)
          .map((item) => Journal.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche de journaux: $e');
    }
  }

  /// Créer un nouveau journal
  static Future<void> createJournal({
    required String code,
    required String intitule,
    required String type,
    String? compteFresorerie,
    required bool saisieAnalytique,
  }) async {
    try {
      await client.from('journal').insert({
        'code': code,
        'intitule': intitule,
        'type': type,
        'compte_fresorerie': compteFresorerie,
        'saisie_analytique': saisieAnalytique,
        'is_active': true,
      });
    } catch (e) {
      throw Exception('Erreur lors de la création du journal: $e');
    }
  }

  /// Modifier un journal
  static Future<void> updateJournal({
    required String id,
    String? code,
    String? intitule,
    String? type,
    String? compteFresorerie,
    bool? saisieAnalytique,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (code != null) updateData['code'] = code;
      if (intitule != null) updateData['intitule'] = intitule;
      if (type != null) updateData['type'] = type;
      if (compteFresorerie != null)
        updateData['compte_fresorerie'] = compteFresorerie;
      if (saisieAnalytique != null)
        updateData['saisie_analytique'] = saisieAnalytique;

      await client.from('journal').update(updateData).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la modification du journal: $e');
    }
  }

  /// Supprimer un journal (soft delete)
  static Future<void> deleteJournal(String id) async {
    try {
      await client.from('journal').update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du journal: $e');
    }
  }
}
