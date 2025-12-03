import 'auth_service.dart';

/// Service de gestion des permissions utilisateur
class PermissionService {
  /// Récupère les permissions d'un utilisateur pour un module spécifique
  static Future<Map<String, dynamic>> getModulePermissions(
    int userId,
    String moduleName,
  ) async {
    try {
      final permissions = await AuthService.getUserPermissions(userId);

      // Trouver les permissions pour ce module spécifique
      final modulePermsList =
          permissions
              .where(
                (p) =>
                    p['module_nom']?.toString().toLowerCase() ==
                    moduleName.toLowerCase(),
              )
              .toList();

      // Si aucune permission trouvée, retourner des permissions vides
      if (modulePermsList.isEmpty) {
        return {'lecture': 0, 'ajout': 0, 'modification': 0, 'suppression': 0};
      }

      final modulePerms = modulePermsList.first;

      return {
        'lecture': modulePerms['lecture'] ?? 0,
        'ajout': modulePerms['ajout'] ?? 0,
        'modification': modulePerms['modification'] ?? 0,
        'suppression': modulePerms['suppression'] ?? 0,
      };
    } catch (e) {
      print('Erreur lors du chargement des permissions pour $moduleName: $e');
      return {'lecture': 0, 'ajout': 0, 'modification': 0, 'suppression': 0};
    }
  }

  /// Vérifie si l'utilisateur peut lire/voir le module
  static bool canRead(Map<String, dynamic> permissions) {
    final value = permissions['lecture'];
    return value == 1 || value == true;
  }

  /// Vérifie si l'utilisateur peut créer/ajouter
  static bool canCreate(Map<String, dynamic> permissions) {
    final value = permissions['ajout'];
    return value == 1 || value == true;
  }

  /// Vérifie si l'utilisateur peut modifier
  static bool canEdit(Map<String, dynamic> permissions) {
    final value = permissions['modification'];
    return value == 1 || value == true;
  }

  /// Vérifie si l'utilisateur peut supprimer
  static bool canDelete(Map<String, dynamic> permissions) {
    final value = permissions['suppression'];
    return value == 1 || value == true;
  }

  /// Vérifie si l'utilisateur a au moins une permission (lecture, ajout, modification ou suppression)
  static bool hasAnyPermission(Map<String, dynamic> permissions) {
    return canRead(permissions) ||
        canCreate(permissions) ||
        canEdit(permissions) ||
        canDelete(permissions);
  }
}
