import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_session.dart';
import '../services/auth_service_local.dart';
import '../services/database_service.dart';
import '../services/dossier_crypto_service.dart';
import 'recovery_key_display_page.dart';

/// Écran « Sécurité » du dossier comptable : affiche l'ID du dossier,
/// permet de changer le mot de passe et de gérer la clé de récupération.
/// Réservé aux administrateurs, à l'instar de [PermissionsPage].
class DossierSecurityPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const DossierSecurityPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
  });

  @override
  State<DossierSecurityPage> createState() => _DossierSecurityPageState();
}

class _DossierSecurityPageState extends State<DossierSecurityPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _dossierUuid;
  bool _isEncrypted = false;
  String? _editorUnlockBlob;
  String? _error;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _regenCurrentPasswordController = TextEditingController();

  bool get _isAdmin => widget.userSession?.isAdmin == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _regenCurrentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final security = await DatabaseService.getDossierSecurity();
      setState(() {
        _dossierUuid = security?.dossierUuid;
        _isEncrypted = security?.isEncrypted ?? false;
        _editorUnlockBlob = security?.editorUnlockPubkeyWrapped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _changePassword() async {
    final realPath = DossierCryptoService.openRealPath;
    if (realPath == null) {
      _showMessage(
        'Le chiffrement du dossier n\'est pas activé pour ce fichier',
        isError: true,
      );
      return;
    }
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showMessage('Veuillez remplir tous les champs', isError: true);
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      _showMessage('Les mots de passe ne correspondent pas', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Ré-enveloppe la clé de chiffrement du fichier sous le nouveau
      //    mot de passe.
      await DossierCryptoService.rewrapWithNewPassword(
        realPath,
        currentPassword,
        newPassword,
      );

      // 2. Met à jour le mot de passe de connexion de l'utilisateur courant
      //    (même mot de passe utilisé pour déverrouiller le dossier et pour
      //    se connecter, cf. assistant de création du dossier).
      final userId = int.tryParse(widget.userSession?.id ?? '');
      if (userId != null) {
        await AuthService.changePassword(
          userId: userId,
          oldPassword: currentPassword,
          newPassword: newPassword,
          isAdmin: false,
        );
      }

      // Ré-enregistre la session ouverte avec le nouveau mot de passe pour
      // que le rechiffrement à la fermeture utilise la bonne clé.
      final tempPath = DatabaseService.currentDatabasePath;
      if (tempPath != null) {
        DossierCryptoService.registerOpenSession(
          tempPath: tempPath,
          realPath: realPath,
          password: newPassword,
        );
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) _showMessage('Mot de passe modifié avec succès');
    } on WrongPasswordException {
      _showMessage('Mot de passe actuel incorrect', isError: true);
    } catch (e) {
      _showMessage('Erreur: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _regenerateRecoveryKey() async {
    final realPath = DossierCryptoService.openRealPath;
    if (realPath == null) {
      _showMessage(
        'Le chiffrement du dossier n\'est pas activé pour ce fichier',
        isError: true,
      );
      return;
    }
    final currentPassword = _regenCurrentPasswordController.text;
    if (currentPassword.isEmpty) {
      _showMessage('Veuillez saisir le mot de passe actuel', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newRecoveryKey = await DossierCryptoService.regenerateRecoveryKey(
        realPath,
        currentPassword,
      );
      _regenCurrentPasswordController.clear();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecoveryKeyDisplayPage(
            dossierUuid: _dossierUuid ?? '',
            recoveryKey: newRecoveryKey,
          ),
        ),
      );
    } on WrongPasswordException {
      _showMessage('Mot de passe actuel incorrect', isError: true);
    } catch (e) {
      _showMessage('Erreur: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité du dossier')),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Erreur: $_error'));
    }
    if (!_isAdmin) {
      return const Center(
        child: Text(
          'Seul un administrateur peut accéder à la sécurité du dossier.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'Identifiant du dossier',
              icon: Icons.badge_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _dossierUuid ?? 'Indisponible',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copier',
                    onPressed: _dossierUuid == null
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: _dossierUuid!),
                            );
                            _showMessage('ID copié');
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!_isEncrypted)
              _sectionCard(
                title: 'Chiffrement',
                icon: Icons.lock_open,
                child: const Text(
                  'Ce dossier n\'a pas été créé avec le chiffrement activé. '
                  'Le changement de mot de passe et la clé de récupération ne '
                  'sont disponibles que pour les dossiers créés avec un mot '
                  'de passe (module Sécurité).',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else ...[
              _sectionCard(
                title: 'Modifier le mot de passe',
                icon: Icons.password,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _changePassword,
                      child: const Text('Modifier le mot de passe'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard(
                title: 'Clé de récupération',
                icon: Icons.vpn_key_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Régénérer la clé de récupération invalide l\'ancienne '
                      'clé. La nouvelle clé ne sera affichée qu\'une seule '
                      'fois.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regenCurrentPasswordController,
                      obscureText: true,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _regenerateRecoveryKey,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Régénérer la clé de récupération'),
                    ),
                  ],
                ),
              ),
              if (_editorUnlockBlob != null) ...[
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Assistance éditeur',
                  icon: Icons.support_agent_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'En cas de blocage, ce code peut être transmis à '
                        'l\'éditeur pour débloquer uniquement ce dossier. '
                        'Il ne donne accès à aucun autre dossier et ne '
                        'révèle jamais votre mot de passe.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _editorUnlockBlob!),
                          );
                          _showMessage('Code éditeur copié');
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copier le code d\'assistance'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
