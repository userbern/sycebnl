import 'package:flutter/material.dart';

/// Affiche un message d'erreur convivial et fixe à l'utilisateur (SnackBar),
/// jamais le détail technique brut (exception, requête SQL, trace...) — ce
/// détail est uniquement journalisé dans la console de développement via
/// [debugPrint], pour que les développeurs puissent diagnostiquer sans
/// exposer d'information technique à l'utilisateur final.
void showFriendlyError(BuildContext context, String message, Object error) {
  debugPrint('[Erreur] $message : $error');
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
