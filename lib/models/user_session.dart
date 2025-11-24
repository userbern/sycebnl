class UserSession {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final List<Map<String, dynamic>> permissions;

  UserSession({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.permissions,
  });

  String get fullName => '$prenom $nom';

  /// Vérifier si l'utilisateur est administrateur
  bool get isAdmin => role == 'admin';

  bool canRead(String moduleCode) {
    return permissions.any(
      (p) => p['modules']?['nom'] == moduleCode && (p['lecture'] ?? false),
    );
  }

  bool canCreate(String moduleCode) {
    return permissions.any(
      (p) => p['modules']?['nom'] == moduleCode && (p['ajout'] ?? false),
    );
  }

  bool canModify(String moduleCode) {
    return permissions.any(
      (p) => p['modules']?['nom'] == moduleCode && (p['modification'] ?? false),
    );
  }

  bool canDelete(String moduleCode) {
    return permissions.any(
      (p) => p['modules']?['nom'] == moduleCode && (p['suppression'] ?? false),
    );
  }
}
