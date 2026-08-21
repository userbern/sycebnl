import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/network/accounting_server_service.dart';
import '../services/network/network_session_service.dart';

/// Boîte de dialogue de contrôle du partage réseau du dossier comptable
/// actuellement ouvert : démarrer/arrêter le serveur embarqué, afficher
/// l'adresse à communiquer aux postes clients.
class NetworkShareDialog extends StatefulWidget {
  const NetworkShareDialog({super.key});

  @override
  State<NetworkShareDialog> createState() => _NetworkShareDialogState();
}

class _NetworkShareDialogState extends State<NetworkShareDialog> {
  bool _isBusy = false;
  String? _error;
  List<String> _addresses = [];

  @override
  void initState() {
    super.initState();
    _refreshAddresses();
  }

  Future<void> _refreshAddresses() async {
    final addresses = await AccountingServerService.localAddresses();
    if (!mounted) return;
    setState(() => _addresses = addresses);
  }

  Future<void> _toggleServer() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      if (AccountingServerService.instance.isRunning) {
        await AccountingServerService.instance.stop();
      } else {
        await AccountingServerService.instance.start();
      }
    } catch (e) {
      _error = 'Impossible de démarrer le serveur : $e';
    }
    if (!mounted) return;
    setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = AccountingServerService.instance.isRunning;
    final port = AccountingServerService.port;

    return AlertDialog(
      title: const Text('Partage réseau du dossier'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRunning ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: isRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isRunning ? 'Partage actif' : 'Partage désactivé',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isRunning) ...[
              const Text('Communiquez ces informations aux autres postes :'),
              const SizedBox(height: 6),
              if (_addresses.isEmpty)
                const Text(
                  'Aucune adresse réseau locale détectée (vérifiez la connexion Wi-Fi/Ethernet).',
                  style: TextStyle(color: Colors.orange),
                )
              else
                ..._addresses.map(
                  (a) => SelectableText(
                    '$a:$port',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildSessionsList(),
            ] else
              const Text(
                'Une fois activé, les autres postes du réseau local pourront '
                'se connecter avec leur compte utilisateur habituel.',
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          onPressed: _isBusy ? null : _toggleServer,
          icon:
              _isBusy
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(isRunning ? Icons.stop : Icons.play_arrow),
          label: Text(isRunning ? 'Arrêter le partage' : 'Activer le partage'),
          style: FilledButton.styleFrom(
            backgroundColor: isRunning ? Colors.red : null,
          ),
        ),
      ],
    );
  }

  /// Liste live des sessions réseau actives, avec déconnexion forcée par
  /// session. Se met à jour automatiquement (login, logout, révocation
  /// suite à désactivation d'un compte) via `NetworkSessionService`.
  Widget _buildSessionsList() {
    return ListenableBuilder(
      listenable: NetworkSessionService.instance,
      builder: (context, _) {
        final sessions = NetworkSessionService.instance.sessions;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sessions connectées : ${sessions.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (sessions.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  itemBuilder: (context, i) {
                    final session = sessions[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline, size: 18),
                      title: Text(
                        session.login,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${session.role} · connecté à '
                        '${DateFormat('HH:mm').format(session.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, size: 18),
                        tooltip: 'Déconnecter',
                        onPressed:
                            () => NetworkSessionService.instance.revoke(
                              session.token,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
