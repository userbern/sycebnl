import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth_service.dart';
import '../database_service.dart';
import '../saisie_comptable_service.dart';
import '../../models/saisie_comptable.dart';
import 'network_http.dart';
import 'network_permission.dart';
import 'network_session_service.dart';

/// Construit le routeur HTTP exposé par le serveur réseau : authentification
/// + endpoints comptables (comptes, tiers, journaux, écritures, budgets,
/// exercices). Chaque endpoint délègue à la logique métier déjà utilisée
/// par l'interface locale (`AuthService`, `SaisieComptableService`,
/// `DatabaseService`) — aucune règle de gestion n'est dupliquée ici.
///
/// Volontairement absent : toute route de gestion des utilisateurs ou des
/// permissions (`/utilisateur`, `/permissions`, ...). Un client réseau ne
/// doit jamais pouvoir consulter ou modifier ses propres droits — cette
/// gestion reste exclusivement locale, sur le poste du chef comptable
/// (`permissions_page.dart`). Ne pas ajouter de telles routes sans revoir
/// ce choix explicitement.
Router buildAccountingRouter() {
  final router = Router();

  router.post('/auth/login', _login);
  router.post('/auth/logout', _logout);

  router.get('/comptes', _guarded('plan_comptable', 'lecture', _getComptes));
  router.post(
    '/comptes',
    _guarded('plan_comptable', 'ajout', _createCompte),
  );
  router.put(
    '/comptes/<id>',
    _guarded('plan_comptable', 'modification', _updateCompte),
  );
  router.delete(
    '/comptes/<id>',
    _guarded('plan_comptable', 'suppression', _deleteCompte),
  );

  router.get('/tiers', _guarded('liste_tiers', 'lecture', _getTiers));
  router.post('/tiers', _guarded('liste_tiers', 'ajout', _createTiers));
  router.put(
    '/tiers/<id>',
    _guarded('liste_tiers', 'modification', _updateTiers),
  );
  router.delete(
    '/tiers/<id>',
    _guarded('liste_tiers', 'suppression', _deleteTiers),
  );

  router.get(
    '/journaux',
    _guarded('codes_journaux', 'lecture', _getJournaux),
  );
  router.post(
    '/journaux',
    _guarded('codes_journaux', 'ajout', _createJournal),
  );
  router.put(
    '/journaux/<id>',
    _guarded('codes_journaux', 'modification', _updateJournal),
  );
  router.delete(
    '/journaux/<id>',
    _guarded('codes_journaux', 'suppression', _deleteJournal),
  );

  router.get(
    '/ecritures/<journalPeriodeId>',
    _guarded('saisie_comptable', 'lecture', _getEcritures),
  );
  router.post(
    '/ecritures',
    _guarded('saisie_comptable', 'ajout', _createEcriture),
  );
  router.put(
    '/ecritures/<id>',
    _guarded('saisie_comptable', 'modification', _updateEcriture),
  );
  router.delete(
    '/ecritures/<id>',
    _guarded('saisie_comptable', 'suppression', _deleteEcriture),
  );

  router.get(
    '/budgets',
    _guarded('gestion_budgets', 'lecture', _getBudgets),
  );
  router.post(
    '/budgets',
    _guarded('gestion_budgets', 'ajout', _createBudget),
  );
  router.delete(
    '/budgets/<id>',
    _guarded('gestion_budgets', 'suppression', _deleteBudget),
  );

  router.get('/exercices', _guarded('exercices', 'lecture', _getExercices));

  return router;
}

// ---------------------------------------------------------------------
// Authentification
// ---------------------------------------------------------------------

Future<Response> _login(Request request) async {
  final body = await readJsonBody(request);
  final login = body['login'] as String?;
  final password = body['password'] as String?;
  if (login == null || login.isEmpty || password == null) {
    return jsonError(400, 'login et password requis');
  }
  if (!DatabaseService.isConnected) {
    return jsonError(409, 'Base de données non connectée sur le serveur');
  }

  try {
    final result = await AuthService.login(login: login, password: password);
    final user = result['user'] as Map<String, dynamic>;
    final token = NetworkSessionService.instance.createSession(
      userId: user['id'] as int,
      login: user['login'] as String,
      role: (user['role'] as String?) ?? 'utilisateur',
    );
    return jsonResponse({
      'token': token,
      'user': user,
      'permissions': result['permissions'],
    });
  } catch (_) {
    return jsonError(401, 'Login ou mot de passe incorrect');
  }
}

Future<Response> _logout(Request request) async {
  final token = extractBearerToken(request);
  if (token != null) NetworkSessionService.instance.revoke(token);
  return jsonResponse({'ok': true});
}

/// Enveloppe un handler avec authentification (token Bearer valide) et
/// autorisation (permission [action] sur [module]), vérifiées côté serveur
/// à chaque requête — jamais côté client.
Handler _guarded(
  String module,
  String action,
  Future<Response> Function(Request request, NetworkSession session) handler,
) {
  return (Request request) async {
    final token = extractBearerToken(request);
    if (token == null) return jsonError(401, 'Token manquant');

    final session = NetworkSessionService.instance.getSession(token);
    if (session == null) return jsonError(401, 'Session invalide ou expirée');

    if (!DatabaseService.isConnected) {
      return jsonError(409, 'Base de données non connectée sur le serveur');
    }

    final allowed = await NetworkPermission.check(
      session.userId,
      module,
      action,
      role: session.role,
    );
    if (!allowed) return jsonError(403, 'Permission refusée pour ce module');

    return handler(request, session);
  };
}

int? _idParam(Request request) => int.tryParse(request.params['id'] ?? '');

// ---------------------------------------------------------------------
// Comptes
// ---------------------------------------------------------------------

Future<Response> _getComptes(Request request, NetworkSession session) async {
  final comptes = await AuthService.getComptes();
  return jsonResponse(
    comptes.map((c) => {'id': c.id, ...c.toJson()}).toList(),
  );
}

Future<Response> _createCompte(
  Request request,
  NetworkSession session,
) async {
  final body = await readJsonBody(request);
  await AuthService.createCompte(
    numeroCompte: body['numero_compte'] as String,
    intitule: body['intitule'] as String,
    type: body['type'] as String,
    nature: body['nature'] as String,
  );
  return jsonResponse({'ok': true}, status: 201);
}

Future<Response> _updateCompte(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  final body = await readJsonBody(request);
  await AuthService.updateCompte(
    id: id,
    numeroCompte: body['numero_compte'] as String?,
    intitule: body['intitule'] as String?,
    type: body['type'] as String?,
    nature: body['nature'] as String?,
  );
  return jsonResponse({'ok': true});
}

Future<Response> _deleteCompte(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  await AuthService.deleteCompte(id);
  return jsonResponse({'ok': true});
}

// ---------------------------------------------------------------------
// Tiers
// ---------------------------------------------------------------------

Future<Response> _getTiers(Request request, NetworkSession session) async {
  final tiers = await AuthService.getTiers();
  return jsonResponse(tiers.map((t) => {'id': t.id, ...t.toJson()}).toList());
}

Future<Response> _createTiers(
  Request request,
  NetworkSession session,
) async {
  final body = await readJsonBody(request);
  await AuthService.createTiers(
    numeroCompte: body['numero_compte'] as String,
    intitule: body['intitule'] as String,
    type: body['type'] as String,
    compteCollectif: body['compte_collectif'] as String,
    nif: body['nif'] as String?,
    adresse: body['adresse'] as String?,
  );
  return jsonResponse({'ok': true}, status: 201);
}

Future<Response> _updateTiers(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  final body = await readJsonBody(request);
  await AuthService.updateTiers(
    id: id,
    numeroCompte: body['numero_compte'] as String?,
    intitule: body['intitule'] as String?,
    type: body['type'] as String?,
    compteCollectif: body['compte_collectif'] as String?,
    nif: body['nif'] as String?,
    adresse: body['adresse'] as String?,
  );
  return jsonResponse({'ok': true});
}

Future<Response> _deleteTiers(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  await AuthService.deleteTiers(id);
  return jsonResponse({'ok': true});
}

// ---------------------------------------------------------------------
// Journaux
// ---------------------------------------------------------------------

Future<Response> _getJournaux(Request request, NetworkSession session) async {
  final journaux = await AuthService.getJournaux();
  return jsonResponse(
    journaux.map((j) => {'id': j.id, ...j.toJson()}).toList(),
  );
}

Future<Response> _createJournal(
  Request request,
  NetworkSession session,
) async {
  final body = await readJsonBody(request);
  await AuthService.createJournal(
    code: body['code'] as String,
    libelle: body['libelle'] as String,
    type: body['type'] as String,
    numeroCompteFresorerie: body['numero_compte_tresorerie'] as String?,
    saisieAnalytique: body['saisie_analytique'] as bool? ?? false,
  );
  return jsonResponse({'ok': true}, status: 201);
}

Future<Response> _updateJournal(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  final body = await readJsonBody(request);
  await AuthService.updateJournal(
    id: id,
    code: body['code'] as String?,
    libelle: body['libelle'] as String?,
    type: body['type'] as String?,
    numeroCompteFresorerie: body['numero_compte_tresorerie'] as String?,
    saisieAnalytique: body['saisie_analytique'] as bool?,
  );
  return jsonResponse({'ok': true});
}

Future<Response> _deleteJournal(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  await AuthService.deleteJournal(id);
  return jsonResponse({'ok': true});
}

// ---------------------------------------------------------------------
// Écritures
// ---------------------------------------------------------------------

Map<String, dynamic> _ligneToJson(LigneEcriture e) => {
  'id': e.id,
  'journal_periode_id': e.journalPeriodeId,
  'numero_enregistrement': e.numeroEnregistrement,
  'jour': e.jour,
  'date_comptable': e.dateComptable.toIso8601String(),
  'numero_document': e.numeroDocument,
  'reference': e.reference,
  'numero_compte': e.numeroCompte,
  'numero_tiers': e.numeroTiers,
  'libelle': e.libelle,
  'montant_debit': e.montantDebit,
  'montant_credit': e.montantCredit,
  'lettrage_code': e.lettrageCode,
  'has_ventilation': e.hasVentilation,
};

LigneEcriture _ligneFromBody(Map<String, dynamic> body, {int? id}) {
  return LigneEcriture(
    id: id,
    journalPeriodeId: body['journal_periode_id'] as int,
    numeroEnregistrement: body['numero_enregistrement'] as int,
    jour: body['jour'] as int,
    dateComptable: DateTime.parse(body['date_comptable'] as String),
    numeroDocument: body['numero_document'] as String,
    reference: body['reference'] as String?,
    numeroCompte: body['numero_compte'] as String,
    numeroTiers: body['numero_tiers'] as String?,
    libelle: body['libelle'] as String,
    montantDebit: (body['montant_debit'] as num?)?.toDouble() ?? 0.0,
    montantCredit: (body['montant_credit'] as num?)?.toDouble() ?? 0.0,
  );
}

Future<Response> _getEcritures(
  Request request,
  NetworkSession session,
) async {
  final journalPeriodeId = int.tryParse(
    request.params['journalPeriodeId'] ?? '',
  );
  if (journalPeriodeId == null) {
    return jsonError(400, 'journalPeriodeId invalide');
  }
  final ecritures = await SaisieComptableService.getEcritures(
    journalPeriodeId,
  );
  return jsonResponse(ecritures.map(_ligneToJson).toList());
}

Future<Response> _createEcriture(
  Request request,
  NetworkSession session,
) async {
  final body = await readJsonBody(request);
  final id = await SaisieComptableService.addLigneEcriture(
    _ligneFromBody(body),
  );
  return jsonResponse({'id': id}, status: 201);
}

Future<Response> _updateEcriture(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  final body = await readJsonBody(request);
  await SaisieComptableService.updateEcriture(_ligneFromBody(body, id: id));
  return jsonResponse({'ok': true});
}

Future<Response> _deleteEcriture(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  await SaisieComptableService.deleteEcriture(id);
  return jsonResponse({'ok': true});
}

// ---------------------------------------------------------------------
// Budgets
// ---------------------------------------------------------------------

Future<Response> _getBudgets(Request request, NetworkSession session) async {
  final exerciceId = int.tryParse(
    request.url.queryParameters['exercice_id'] ?? '',
  );
  if (exerciceId == null) {
    return jsonError(400, 'paramètre exercice_id requis');
  }
  final budgets = await AuthService.getBudgetsWithDetails(
    exerciceId: exerciceId,
  );
  return jsonResponse(budgets);
}

Future<Response> _createBudget(
  Request request,
  NetworkSession session,
) async {
  final body = await readJsonBody(request);
  final projetId = body['projet_id'] as int?;
  final bailleurId = body['bailleur_id'] as int?;
  final exerciceId = body['exercice_id'] as int?;
  if (projetId == null || bailleurId == null || exerciceId == null) {
    return jsonError(400, 'projet_id, bailleur_id et exercice_id requis');
  }
  final id = await AuthService.createBudget(
    projetId: projetId,
    bailleurId: bailleurId,
    exerciceId: exerciceId,
  );
  return jsonResponse({'id': id}, status: 201);
}

Future<Response> _deleteBudget(
  Request request,
  NetworkSession session,
) async {
  final id = _idParam(request);
  if (id == null) return jsonError(400, 'id invalide');
  await AuthService.deleteBudget(id);
  return jsonResponse({'ok': true});
}

// ---------------------------------------------------------------------
// Exercices
// ---------------------------------------------------------------------

Future<Response> _getExercices(
  Request request,
  NetworkSession session,
) async {
  final exercices = await DatabaseService.getExercices();
  return jsonResponse(exercices);
}
