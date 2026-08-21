import 'dart:math';

import 'package:flutter/foundation.dart';

/// Session réseau active, créée au login d'un client distant. Le token
/// reste valide tant que le serveur tourne (pas d'expiration séparée) :
/// il est révoqué à la déconnexion explicite, à l'arrêt du serveur, ou à la
/// fermeture du dossier comptable sur le poste serveur.
class NetworkSession {
  NetworkSession({
    required this.token,
    required this.userId,
    required this.login,
    required this.role,
  }) : createdAt = DateTime.now();

  final String token;
  final int userId;
  final String login;
  final String role;
  final DateTime createdAt;
}

/// Registre en mémoire des sessions réseau actives sur le serveur. Aucune
/// persistance : un redémarrage du serveur (ou de l'application) invalide
/// toutes les sessions, ce qui est cohérent avec « valide tant que le
/// serveur tourne ».
///
/// `ChangeNotifier` pour permettre à l'interface (boîte de dialogue de
/// partage réseau) d'afficher la liste des sessions actives en temps réel.
class NetworkSessionService extends ChangeNotifier {
  NetworkSessionService._();
  static final NetworkSessionService instance = NetworkSessionService._();

  final Map<String, NetworkSession> _sessions = {};

  /// Sessions actives, pour affichage (login, rôle, heure de connexion) et
  /// déconnexion forcée depuis l'interface du chef comptable.
  List<NetworkSession> get sessions => List.unmodifiable(_sessions.values);

  String createSession({
    required int userId,
    required String login,
    required String role,
  }) {
    final token = _generateToken();
    _sessions[token] = NetworkSession(
      token: token,
      userId: userId,
      login: login,
      role: role,
    );
    notifyListeners();
    return token;
  }

  NetworkSession? getSession(String token) => _sessions[token];

  void revoke(String token) {
    if (_sessions.remove(token) != null) notifyListeners();
  }

  /// Révoque immédiatement toutes les sessions d'un utilisateur donné :
  /// utilisé quand son compte est désactivé, supprimé, ou que son mot de
  /// passe est changé par un administrateur.
  void revokeUser(int userId) {
    final hadAny = _sessions.values.any((s) => s.userId == userId);
    if (!hadAny) return;
    _sessions.removeWhere((_, s) => s.userId == userId);
    notifyListeners();
  }

  /// Révoque toutes les sessions actives (arrêt du serveur, fermeture du
  /// dossier comptable sur le poste serveur).
  void clear() {
    if (_sessions.isEmpty) return;
    _sessions.clear();
    notifyListeners();
  }

  int get activeSessionCount => _sessions.length;

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
