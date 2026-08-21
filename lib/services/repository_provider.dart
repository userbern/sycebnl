import 'i_accounting_repository.dart';
import 'local_repository.dart';

/// Point d'accès unique au [IAccountingRepository] actif de l'application.
///
/// Par défaut, l'implémentation locale ([LocalRepository]). Lorsqu'une
/// connexion réseau est établie (`NetworkConnectionService.connect`), [current]
/// est remplacé par un `RemoteRepository` ; à la déconnexion, il est restauré
/// à [LocalRepository]. Les services métier (`AuthService`,
/// `SaisieComptableService`, `KpiService`, ...) lisent [current] à chaque
/// appel plutôt que de mémoriser une instance, pour basculer immédiatement
/// sans redémarrer l'application.
class RepositoryProvider {
  RepositoryProvider._();

  static IAccountingRepository current = const LocalRepository();
}
