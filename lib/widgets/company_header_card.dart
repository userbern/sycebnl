import 'package:flutter/material.dart';
import 'app_icon.dart';

/// Carte d'en-tête horizontale affichant le logo de l'entité, sa
/// dénomination sociale et l'exercice actif. Utilisée dans la barre
/// latérale de [HomePage] et réutilisable ailleurs dans l'application.
class CompanyHeaderCard extends StatelessWidget {
  final String companyName;
  final String? exerciceCode;

  const CompanyHeaderCard({
    super.key,
    required this.companyName,
    this.exerciceCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          const AppIcon(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  companyName,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (exerciceCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Exercice: $exerciceCode',
                      style: TextStyle(
                        color: Colors.blue.shade400,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
