import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'network_http.dart';
import 'network_routes.dart';
import 'network_session_service.dart';

/// Serveur HTTP embarqué qui transforme le poste du chef comptable en
/// serveur local pour le dossier `.syca` actuellement ouvert. Écoute sur
/// toutes les interfaces IPv4 du réseau local, port fixe [port].
///
/// Ne gère ni l'ouverture ni le déchiffrement du dossier : il sert le
/// dossier tel qu'il est déjà ouvert par [DatabaseService] au moment du
/// démarrage (chiffré ou non, peu importe — c'est la même connexion SQLite
/// que celle utilisée par l'interface locale).
class AccountingServerService {
  AccountingServerService._();
  static final AccountingServerService instance = AccountingServerService._();

  static const int port = 8765;

  HttpServer? _server;
  int? _boundPort;

  bool get isRunning => _server != null;

  /// Port effectivement lié par [start] (utile pour les tests, qui passent
  /// `port: 0` pour obtenir un port libre attribué par l'OS et éviter les
  /// collisions entre suites de tests exécutées en parallèle). En usage réel,
  /// c'est toujours [port].
  int get boundPort => _boundPort ?? port;

  /// Adresses IPv4 locales sur lesquelles le serveur écoute, pour affichage
  /// à l'utilisateur (ex: partager "192.168.1.10:8765" aux postes clients).
  static Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return interfaces.expand((i) => i.addresses).map((a) => a.address).toList();
  }

  /// Démarre le serveur. [port] par défaut à [AccountingServerService.port]
  /// (port fixe attendu par les postes clients) ; passer `0` (utilisé par les
  /// tests) fait attribuer un port libre par l'OS, lisible ensuite via
  /// [boundPort].
  Future<void> start({int? port}) async {
    if (_server != null) return;

    final router = buildAccountingRouter();
    final handler = const Pipeline()
        .addMiddleware(_errorMiddleware)
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port ?? AccountingServerService.port,
      shared: true,
    );
    _boundPort = _server!.port;
  }

  /// Arrête le serveur et révoque immédiatement toutes les sessions réseau
  /// actives : les clients connectés perdent l'accès sur-le-champ.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _boundPort = null;
    await server?.close(force: true);
    NetworkSessionService.instance.clear();
  }

  static Handler _errorMiddleware(Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } catch (e) {
        return jsonError(500, 'Erreur serveur: $e');
      }
    };
  }
}
