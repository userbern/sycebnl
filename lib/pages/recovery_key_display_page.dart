import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/export_service.dart';

/// Affiche une clé de récupération de dossier comptable une seule fois, avec
/// les actions Copier / Exporter en PDF (module Sécurité du dossier
/// comptable). L'appelant est responsable de ne présenter cette page qu'au
/// moment de la génération ou de la régénération de la clé : elle n'est pas
/// stockée en clair et ne peut plus être récupérée ensuite.
class RecoveryKeyDisplayPage extends StatelessWidget {
  final String dossierUuid;
  final String recoveryKey;
  final String? entiteNom;

  const RecoveryKeyDisplayPage({
    super.key,
    required this.dossierUuid,
    required this.recoveryKey,
    this.entiteNom,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clé de récupération'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.vpn_key, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Conservez cette clé de récupération',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elle permet de réinitialiser le mot de passe de ce dossier '
                    'en cas d\'oubli, sans perte de données. Elle ne sera plus '
                    'affichée après avoir fermé cette fenêtre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      recoveryKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID du dossier : $dossierUuid',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: recoveryKey),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Clé copiée dans le presse-papiers'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copier'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ExportService.exportRecoveryKeyPDF(
                            dossierUuid: dossierUuid,
                            recoveryKey: recoveryKey,
                            entiteNom: entiteNom ?? '',
                            context: context,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Exporter PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('J\'ai conservé cette clé, continuer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
