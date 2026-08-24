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
  ///
  /// Un utilisateur admin n'a jamais de lignes dans la table `permissions`
  /// (voir `permissions_page.dart`, `_initializeBaselinePermissions` n'est
  /// appelé que pour les rôles non-admin) : côté local, `UserSession.isAdmin`
  /// court-circuite déjà la vérification pour ce rôle. Il faut reproduire ce
  /// même court-circuit ici, sinon un admin connecté à distance se voit
  /// refuser l'accès à tous les endpoints protégés faute de lignes en base.
  static Future<bool> check(
    int userId,
    String module,
    String action, {
    String? role,
  }) async {
    if (role == 'admin') return true;
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
