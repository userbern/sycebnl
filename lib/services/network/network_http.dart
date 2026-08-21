import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Petits utilitaires JSON partagés par les handlers du serveur réseau.
/// Volontairement minimalistes : pas de framework de sérialisation, juste
/// de quoi encoder/décoder des `Map`/`List` simples.
const Map<String, Object> jsonHeaders = {
  'content-type': 'application/json; charset=utf-8',
};

Response jsonResponse(Object? data, {int status = 200}) {
  return Response(status, body: jsonEncode(data), headers: jsonHeaders);
}

Response jsonError(int status, String message) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: jsonHeaders,
  );
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return {};
  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic> ? decoded : {};
}

String? extractBearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final token = header.substring('Bearer '.length).trim();
  return token.isEmpty ? null : token;
}
