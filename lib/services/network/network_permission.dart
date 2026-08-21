import '../auth_service.dart';

/// Vérification des permissions côté serveur pour les requêtes réseau.
///
/// Ne fait jamais confiance à un éventuel indicateur de permission envoyé
/// par le client : relit systématiquement les permissions réelles de
/// l'utilisateur en base (table `permissions`), exactement comme le fait
/// déjà l'interface locale via `PermissionService`.
class NetworkPermission {
  NetworkPermission._();

  /// [action] doit être l'une de : 'lecture', 'ajout', 'modification',
  /// 'suppression' (colonnes de la table `permissions`).
  static Future<bool> check(int userId, String module, String action) async {
    final permissions = await AuthService.getUserPermissions(userId);
    final modulePerms = permissions.where(
      (p) =>
          (p['module_nom'] as String?)?.toLowerCase() == module.toLowerCase(),
    );
    if (modulePerms.isEmpty) return false;

    final value = modulePerms.first[action];
    return value == 1 || value == true;
  }
}
