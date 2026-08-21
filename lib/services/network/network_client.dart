import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Levée quand le serveur réseau est injoignable : hôte/port incorrect,
/// connexion refusée, timeout. Distincte de [NetworkApiException] pour
/// permettre à l'UI d'afficher l'état « Base réseau indisponible » plutôt
/// qu'une simple erreur de requête.
class NetworkUnavailableException implements Exception {
  NetworkUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Erreur applicative renvoyée par le serveur (401, 403, 404, 409, ...).
class NetworkApiException implements Exception {
  NetworkApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

/// Client HTTP vers le serveur réseau embarqué exposé par
/// `AccountingServerService` / `network_routes.dart` sur un autre poste.
///
/// Le token de session n'est conservé qu'en mémoire (champ [_token]) : il
/// n'est jamais écrit sur disque et disparaît à la déconnexion ou à la
/// fermeture de l'application.
class NetworkClient {
  NetworkClient({required this.host, required this.port});

  final String host;
  final int port;

  String? _token;
  bool get hasToken => _token != null;

  String get baseUrl => 'http://$host:$port';

  static const _connectTimeout = Duration(seconds: 5);
  static const _requestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> login(String login, String password) async {
    final result = await _send('POST', '/auth/login', body: {
      'login': login,
      'password': password,
    });
    final map = result as Map<String, dynamic>;
    _token = map['token'] as String;
    return map;
  }

  /// Révoque le token côté serveur. Best-effort : si le serveur est déjà
  /// injoignable, le token local est tout de même oublié.
  Future<void> logout() async {
    if (_token == null) return;
    try {
      await _send('POST', '/auth/logout');
    } catch (_) {
      // Ignoré : la session sera de toute façon perdue localement.
    } finally {
      _token = null;
    }
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final result = await _send('GET', path);
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final result = await _send('POST', path, body: body);
    return (result as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final result = await _send('PUT', path, body: body);
    return (result as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final result = await _send('DELETE', path);
    return (result as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await _open(client, method, uri);
      if (_token != null) {
        request.headers.set('Authorization', 'Bearer $_token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_requestTimeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      final decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final message = (decoded is Map && decoded['error'] != null)
          ? decoded['error'] as String
          : 'Erreur serveur (${response.statusCode})';
      throw NetworkApiException(response.statusCode, message);
    } on NetworkApiException {
      rethrow;
    } on SocketException catch (e) {
      throw NetworkUnavailableException(
        'Impossible de joindre le serveur réseau $host:$port (${e.message})',
      );
    } on TimeoutException {
      throw NetworkUnavailableException(
        'Le serveur réseau $host:$port ne répond pas',
      );
    } on HttpException catch (e) {
      throw NetworkUnavailableException(
        'Erreur de connexion au serveur réseau : ${e.message}',
      );
    } catch (e) {
      throw NetworkUnavailableException(
        'Erreur de connexion au serveur réseau : $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientRequest> _open(HttpClient client, String method, Uri uri) {
    switch (method) {
      case 'GET':
        return client.getUrl(uri);
      case 'POST':
        return client.postUrl(uri);
      case 'PUT':
        return client.putUrl(uri);
      case 'DELETE':
        return client.deleteUrl(uri);
      default:
        throw ArgumentError('Méthode HTTP non supportée: $method');
    }
  }
}
