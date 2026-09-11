import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/network/network_connection_service.dart';
import 'home_page.dart';

/// Écran affiché juste après une connexion réseau réussie.
///
/// Tant que la connexion est active, il s'efface derrière la véritable
/// [HomePage] (celle-ci s'adapte au mode réseau : voir `home_page.dart`,
/// `_isNetworkMode`). Il ne reprend la main que si le serveur devient
/// injoignable (`NetworkConnectionStatus.unavailable`), pour l'afficher
/// clairement plutôt que de laisser l'utilisateur face à des écrans qui
/// échoueraient silencieusement.
class NetworkSessionPage extends StatelessWidget {
  const NetworkSessionPage({super.key, required this.userSession});

  final UserSession userSession;

  Future<void> _disconnect(BuildContext context) async {
    await NetworkConnectionService.instance.disconnect();
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NetworkConnectionService.instance,
      builder: (context, _) {
        final status = NetworkConnectionService.instance.status;

        // Quel que soit le chemin de sortie (bouton, geste retour, flèche
        // AppBar), la session réseau doit être fermée : sinon
        // `RepositoryProvider.current` resterait sur `RemoteRepository` alors
        // que l'utilisateur croit être revenu en mode local.
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) NetworkConnectionService.instance.disconnect();
          },
          child: status == NetworkConnectionStatus.connected
              ? HomePage(userSession: userSession)
              : _buildStatusScreen(context, status),
        );
      },
    );
  }

  Widget _buildStatusScreen(
    BuildContext context,
    NetworkConnectionStatus status,
  ) {
    final unavailable = status == NetworkConnectionStatus.unavailable;
    return Scaffold(
      appBar: AppBar(title: const Text('Base réseau')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unavailable ? Icons.cloud_off : Icons.wifi_tethering,
                  size: 64,
                  color: unavailable ? Colors.orange : Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  unavailable
                      ? 'Base réseau indisponible'
                      : 'Connexion à la base réseau…',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unavailable) ...[
                  const SizedBox(height: 8),
                  Text(
                    NetworkConnectionService.instance.lastError ??
                        'Le serveur ne répond plus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Utilisateur', userSession.fullName),
                        _infoRow('Identifiant', userSession.login),
                        _infoRow('Rôle', userSession.role),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _disconnect(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
