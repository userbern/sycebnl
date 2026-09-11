import 'package:flutter/foundation.dart';

import '../local_repository.dart';
import '../repository_provider.dart';
import 'network_client.dart';
import 'remote_repository.dart';

enum NetworkConnectionStatus {
  /// Aucune connexion réseau : l'application travaille sur le dossier local
  /// (comportement historique, [RepositoryProvider.current] == [LocalRepository]).
  disconnected,

  /// Tentative de connexion/login en cours.
  connecting,

  /// Connecté : [RepositoryProvider.current] pointe vers un [RemoteRepository].
  connected,

  /// La connexion était établie mais le serveur ne répond plus (arrêté,
  /// réseau coupé, ...). L'UI doit afficher « Base réseau indisponible ».
  unavailable,
}

/// Source de vérité unique pour l'état de connexion à une base réseau.
///
/// Ne concerne que le mode « client distant » (se connecter au dossier
/// ouvert par un autre poste) : le partage réseau côté « chef comptable »
/// (héberger le dossier local) reste géré par `AccountingServerService`,
/// indépendamment de ce service.
class NetworkConnectionService extends ChangeNotifier {
  NetworkConnectionService._();
  static final NetworkConnectionService instance = NetworkConnectionService._();

  NetworkClient? _client;
  NetworkConnectionStatus _status = NetworkConnectionStatus.disconnected;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>>? _permissions;
  String? _lastError;

  NetworkConnectionStatus get status => _status;
  bool get isConnected => _status == NetworkConnectionStatus.connected;
  Map<String, dynamic>? get currentUser => _user;
  List<Map<String, dynamic>>? get permissions => _permissions;
  String? get lastError => _lastError;

  /// Se connecte au serveur réseau [host]:[port] avec les identifiants
  /// fournis. Lève [NetworkUnavailableException] si le serveur est
  /// injoignable, ou [NetworkApiException] (401) si les identifiants sont
  /// incorrects. Le token reçu n'est conservé qu'en mémoire, dans [NetworkClient].
  Future<void> connect({
    required String host,
    required int port,
    required String login,
    required String password,
  }) async {
    _status = NetworkConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    final client = NetworkClient(host: host, port: port);
    try {
      final result = await client.login(login, password);
      _client = client;
      _user = (result['user'] as Map).cast<String, dynamic>();
      _permissions = (result['permissions'] as List)
          .map((p) => (p as Map).cast<String, dynamic>())
          .toList();
      RepositoryProvider.current = RemoteRepository(client);
      _status = NetworkConnectionStatus.connected;
    } on NetworkUnavailableException catch (e) {
      _status = NetworkConnectionStatus.disconnected;
      _lastError = e.message;
      rethrow;
    } on NetworkApiException catch (e) {
      _status = NetworkConnectionStatus.disconnected;
      _lastError = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Ferme la session réseau et restaure [RepositoryProvider.current] sur
  /// [LocalRepository] : l'application revient au comportement local normal.
  Future<void> disconnect() async {
    await _client?.logout();
    _client = null;
    _user = null;
    _permissions = null;
    _status = NetworkConnectionStatus.disconnected;
    _lastError = null;
    RepositoryProvider.current = const LocalRepository();
    notifyListeners();
  }

  /// À appeler quand un appel réseau échoue avec [NetworkUnavailableException]
  /// pendant une session déjà active (le serveur est tombé en cours
  /// d'utilisation) : bascule l'état sur « indisponible » pour que l'UI
  /// puisse le signaler, sans perdre le token (le serveur peut revenir).
  void markUnavailable(String message) {
    if (_status != NetworkConnectionStatus.connected) return;
    _status = NetworkConnectionStatus.unavailable;
    _lastError = message;
    notifyListeners();
  }

  /// À appeler après [markUnavailable] si une requête ultérieure réussit à
  /// nouveau (le serveur est revenu) : restaure l'état "connected".
  void markAvailableAgain() {
    if (_status != NetworkConnectionStatus.unavailable) return;
    _status = NetworkConnectionStatus.connected;
    _lastError = null;
    notifyListeners();
  }
}
