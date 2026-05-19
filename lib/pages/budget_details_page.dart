import 'package:flutter/material.dart';
import '../models/user_session.dart';

// Cette page nécessite une refonte complète car elle utilise des queries complexes

class BudgetDetailsPage extends StatelessWidget {
  final Map<String, dynamic> budget;
  final UserSession? userSession;

  const BudgetDetailsPage({super.key, required this.budget, this.userSession});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du budget - ${budget['nom'] ?? 'Sans nom'}'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Page en cours de migration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cette page est en cours de migration vers la base de données locale SQLite.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Elle sera disponible prochainement.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations du budget',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('ID', budget['id']?.toString() ?? '-'),
                      _buildInfoRow('Nom', budget['nom']?.toString() ?? '-'),
                      _buildInfoRow(
                        'Montant',
                        budget['montant']?.toString() ?? '-',
                      ),
                      _buildInfoRow(
                        'Exercice',
                        budget['exercice']?.toString() ?? '-',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
