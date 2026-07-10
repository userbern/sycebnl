import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_service.dart';
import '../services/dossier_crypto_service.dart';
import 'recovery_key_display_page.dart';

/// Page « Mot de passe oublié » du module Sécurité du dossier comptable :
/// vérifie une clé de récupération et permet de définir un nouveau mot de
/// passe, sans perte de données. Une nouvelle clé de récupération est
/// générée et affichée à la suite (bonne pratique après une récupération).
class DossierRecoveryPage extends StatefulWidget {
  final String filePath;

  const DossierRecoveryPage({super.key, required this.filePath});

  @override
  State<DossierRecoveryPage> createState() => _DossierRecoveryPageState();
}

class _DossierRecoveryPageState extends State<DossierRecoveryPage> {
  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _recoveryKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _submit() async {
    final recoveryKey = _recoveryKeyController.text.trim().toUpperCase();
    final newPassword = _newPasswordController.text;

    if (recoveryKey.isEmpty) {
      _showError('Veuillez saisir votre clé de récupération');
      return;
    }
    if (newPassword.isEmpty) {
      _showError('Veuillez saisir un nouveau mot de passe');
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DossierCryptoService.resetPasswordViaRecoveryKey(
        widget.filePath,
        recoveryKey,
        newPassword,
      );

      final newRecoveryKey = await DossierCryptoService.regenerateRecoveryKey(
        widget.filePath,
        newPassword,
      );

      final dossierUuid = await _readDossierUuid(newPassword);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecoveryKeyDisplayPage(
            dossierUuid: dossierUuid ?? '',
            recoveryKey: newRecoveryKey,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on WrongPasswordException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Clé de récupération incorrecte');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Erreur: ${e.toString()}');
    }
  }

  /// Lit l'UUID du dossier à des fins d'affichage uniquement : déchiffre
  /// vers un fichier temporaire jetable (lecture seule, aucune donnée
  /// modifiée, donc pas besoin de rechiffrer ni d'enregistrer de session).
  Future<String?> _readDossierUuid(String password) async {
    try {
      final decrypted =
          await DossierCryptoService.decryptToTemp(widget.filePath, password);
      await DatabaseService.initializeFfi();
      final db = await databaseFactoryFfi.openDatabase(
        decrypted.tempPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final rows = await db.query('dossier_security', limit: 1);
      await db.close();
      final tempFile = File(decrypted.tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (rows.isEmpty) return null;
      return rows.first['dossier_uuid'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Saisissez votre clé de récupération pour définir un '
                  'nouveau mot de passe. Vos données seront conservées.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _recoveryKeyController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Clé de récupération',
                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Réinitialiser le mot de passe'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
