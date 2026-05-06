class UserSession {
  final String id;
  final String login;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final List<Map<String, dynamic>> permissions;

  UserSession({
    required this.id,
    required this.login,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.permissions,
  });

  String get fullName => '$prenom $nom';

  /// Vérifier si l'utilisateur est administrateur
  bool get isAdmin => role == 'admin';

  /// Vérifier si l'utilisateur a une permission spécifique pour un module
  bool hasPermission(String moduleNom, String action) {
    if (isAdmin) return true;

    final permission = permissions.firstWhere((p) {
      final moduleName =
          p['module_nom']?.toString().toLowerCase() ??
          p['modules']?['nom']?.toString().toLowerCase() ??
          '';
      return moduleName == moduleNom.toLowerCase();
    }, orElse: () => {});

    if (permission.isEmpty) return false;

    switch (action) {
      case 'read':
        return (permission['lecture'] == 1 || permission['lecture'] == true);
      case 'create':
        return (permission['ajout'] == 1 || permission['ajout'] == true);
      case 'update':
        return (permission['modification'] == 1 ||
            permission['modification'] == true);
      case 'delete':
        return (permission['suppression'] == 1 ||
            permission['suppression'] == true);
      default:
        return false;
    }
  }

  /// Vérifier si l'utilisateur peut voir un module (au moins une action)
  bool canAccessModule(String moduleNom) {
    if (isAdmin) return true;

    return permissions.any((p) {
      final moduleName =
          p['module_nom']?.toString().toLowerCase() ??
          p['modules']?['nom']?.toString().toLowerCase() ??
          '';
      return moduleName == moduleNom.toLowerCase() &&
          ((p['lecture'] == 1 || p['lecture'] == true) ||
              (p['ajout'] == 1 || p['ajout'] == true) ||
              (p['modification'] == 1 || p['modification'] == true) ||
              (p['suppression'] == 1 || p['suppression'] == true));
    });
  }

  bool canRead(String moduleCode) {
    return hasPermission(moduleCode, 'read');
  }

  bool canCreate(String moduleCode) {
    return hasPermission(moduleCode, 'create');
  }

  bool canModify(String moduleCode) {
    return hasPermission(moduleCode, 'update');
  }

  bool canDelete(String moduleCode) {
    return hasPermission(moduleCode, 'delete');
  }
}
