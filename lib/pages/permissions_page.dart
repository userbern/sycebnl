import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/auth_service_local.dart';

class PermissionsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const PermissionsPage({super.key, this.showAppBar = true, this.userSession});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final Map<int, Map<String, bool>> _permissionsByModule = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _modules = [];
  int? _selectedUserId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool get _isAdmin => widget.userSession?.isAdmin == true;
  String get _currentLogin => widget.userSession?.login ?? '';
  int? get _currentUserId => int.tryParse(widget.userSession?.id ?? '');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await AuthService.getAllUsers();
      final modules = await AuthService.getAllModules();

      final visibleUsers =
          _isAdmin || _currentUserId == null
              ? users
              : users.where((user) => user['id'] == _currentUserId).toList();

      if (!mounted) return;

      if (visibleUsers.isEmpty) {
        setState(() {
          _users = [];
          _modules = modules;
          _selectedUserId = null;
          _permissionsByModule.clear();
          _isLoading = false;
        });
        return;
      }

      final selectedId =
          _isAdmin
              ? (_selectedUserId ?? visibleUsers.first['id'] as int)
              : (_currentUserId ?? visibleUsers.first['id'] as int);

      setState(() {
        _users = visibleUsers;
        _modules = modules;
        _selectedUserId = selectedId;
      });

      await _loadPermissions(selectedId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPermissions(int userId) async {
    try {
      final rawPerms = await AuthService.getUserPermissions(userId);

      final Map<int, Map<String, bool>> perms = {
        for (final module in _modules)
          module['id'] as int: {
            'lecture': false,
            'ajout': false,
            'modification': false,
            'suppression': false,
          },
      };

      for (final perm in rawPerms) {
        final moduleId = perm['module_id'] as int?;
        if (moduleId == null) continue;
        perms[moduleId] = {
          'lecture': perm['lecture'] == 1 || perm['lecture'] == true,
          'ajout': perm['ajout'] == 1 || perm['ajout'] == true,
          'modification':
              perm['modification'] == 1 || perm['modification'] == true,
          'suppression':
              perm['suppression'] == 1 || perm['suppression'] == true,
        };
      }

      if (!mounted) return;
      setState(() {
        _permissionsByModule
          ..clear()
          ..addAll(perms);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _togglePermission(int moduleId, String field, bool value) {
    if (!_isAdmin) return;
    setState(() {
      _permissionsByModule[moduleId] ??= {
        'lecture': false,
        'ajout': false,
        'modification': false,
        'suppression': false,
      };
      _permissionsByModule[moduleId]![field] = value;
    });
  }

  Future<void> _showChangePasswordDialog() async {
    final targetUserId = _isAdmin ? _selectedUserId : _currentUserId;
    if (targetUserId == null) return;

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              _isAdmin ? 'Changer le mot de passe' : 'Changer mon mot de passe',
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isAdmin) ...[
                      TextField(
                        controller: oldPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Ancien mot de passe *',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe *',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newPassword = newPasswordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();
                  final oldPassword = oldPasswordController.text.trim();

                  if (newPassword.isEmpty || confirmPassword.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Le nouveau mot de passe est obligatoire',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Les mots de passe ne correspondent pas'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    await AuthService.changePassword(
                      userId: targetUserId,
                      oldPassword: _isAdmin ? null : oldPassword,
                      newPassword: newPassword,
                      isAdmin: _isAdmin,
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Mot de passe mis à jour'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    if (!_isAdmin) return;
    final loginController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'utilisateur';
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Nouvel utilisateur'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: loginController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Login *',
                            hintText: 'Ex: jdoe',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(labelText: 'Rôle'),
                          items: const [
                            DropdownMenuItem(
                              value: 'utilisateur',
                              child: Text('utilisateur'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => role = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final login = loginController.text.trim();
                      final password = passwordController.text.trim();

                      if (login.isEmpty || password.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Le login et le mot de passe sont obligatoires',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      try {
                        final newId = await AuthService.createUser(
                          login: login,
                          password: password,
                          nom: '',
                          prenom: '',
                          role: role,
                        );

                        if (role != 'admin') {
                          final modules = await AuthService.getAllModules();
                          for (final module in modules) {
                            final moduleId = module['id'] as int;
                            final moduleNom = module['nom'] as String;
                            await AuthService.updatePermission(
                              utilisateurId: newId,
                              moduleId: moduleId,
                              lecture: moduleNom == 'notre_entite',
                              ajout: false,
                              modification: false,
                              suppression: false,
                            );
                          }
                        }

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadData();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Utilisateur créé avec succès'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Création impossible: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Créer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    if (!_isAdmin) return;
    final loginController = TextEditingController(
      text: (user['login'] ?? '').toString(),
    );
    final passwordController = TextEditingController();
    String role = (user['role'] ?? 'utilisateur').toString();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Modifier ${user['login'] ?? 'utilisateur'}'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: loginController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Login *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            helperText:
                                'Laisser vide pour conserver le mot de passe',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(labelText: 'Rôle'),
                          items: const [
                            DropdownMenuItem(
                              value: 'utilisateur',
                              child: Text('utilisateur'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => role = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final login = loginController.text.trim();
                      final newPassword = passwordController.text.trim();

                      if (login.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Le login est obligatoire'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      try {
                        await AuthService.updateUser(
                          id: user['id'] as int,
                          login: login,
                          role: role,
                          password: newPassword.isEmpty ? null : newPassword,
                        );

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadData();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Utilisateur mis à jour'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Mise à jour impossible: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    if (!_isAdmin) return;
    if (_users.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer le dernier utilisateur'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Supprimer utilisateur'),
            content: Text(
              'Confirmer la suppression de "${user['login'] ?? ''}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete),
                label: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.deleteUser(user['id'] as int);
      if (!mounted) return;

      if (_selectedUserId == user['id']) {
        final remaining = _users.where((u) => u['id'] != user['id']).toList();
        _selectedUserId =
            remaining.isNotEmpty ? remaining.first['id'] as int : null;
      }

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Utilisateur supprimé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suppression impossible: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_isAdmin) return;
    final userId = _selectedUserId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final payload =
          _modules.map((module) {
            final moduleId = module['id'] as int;
            final perms = _permissionsByModule[moduleId] ?? {};
            return {
              'moduleId': moduleId,
              'lecture': perms['lecture'] == true,
              'ajout': perms['ajout'] == true,
              'modification': perms['modification'] == true,
              'suppression': perms['suppression'] == true,
            };
          }).toList();

      await AuthService.updatePermissions(userId, payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions mises à jour'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text(
                  _currentLogin.isEmpty
                      ? 'Autorisations d\'accès'
                      : 'Autorisations d\'accès - $_currentLogin',
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                actions: [
                  IconButton(
                    tooltip:
                        _isAdmin
                            ? 'Changer le mot de passe'
                            : 'Changer mon mot de passe',
                    onPressed: _showChangePasswordDialog,
                    icon: const Icon(Icons.lock_reset),
                  ),
                ],
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _users.isEmpty
              ? _buildEmpty()
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isAdmin
                                  ? 'Gestion des utilisateurs et des permissions'
                                  : 'Mon compte et mes permissions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_isAdmin)
                            ElevatedButton.icon(
                              onPressed: _showCreateUserDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Ajouter utilisateur'),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('Changer mon mot de passe'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(width: 280, child: _buildUserList()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildPermissionsTable()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      floatingActionButton:
          (!_isLoading && _users.isNotEmpty && _isAdmin)
              ? FloatingActionButton.extended(
                onPressed: _isSaving ? null : _save,
                icon:
                    _isSaving
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              )
              : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Aucun utilisateur disponible'),
          const SizedBox(height: 6),
          Text(
            'Créez un premier utilisateur pour configurer les autorisations.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed:
                _isAdmin ? _showCreateUserDialog : _showChangePasswordDialog,
            icon: Icon(_isAdmin ? Icons.person_add : Icons.lock_reset),
            label: Text(
              _isAdmin
                  ? 'Créer le premier utilisateur'
                  : 'Changer mon mot de passe',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Utilisateurs',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isActive = user['id'] == _selectedUserId;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedUserId = user['id'] as int);
                    _loadPermissions(user['id'] as int);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue.shade50 : Colors.white,
                      border: Border(
                        left: BorderSide(
                          color: isActive ? Colors.blue.shade400 : Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            (user['login'] as String?)
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                '?',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (user['login'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (user['role'] ?? 'utilisateur').toString(),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue.shade400,
                            size: 18,
                          ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Modifier',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showEditUserDialog(user),
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDeleteUser(user),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.red.shade400,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTable() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Permissions par module',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (_selectedUserId != null)
                  Chip(
                    label: Text('Utilisateur #$_selectedUserId'),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade800),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Module',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                _HeaderCell(label: 'Lecture'),
                _HeaderCell(label: 'Créer'),
                _HeaderCell(label: 'Modifier'),
                _HeaderCell(label: 'Supprimer'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _modules.length,
              itemBuilder: (context, index) {
                final module = _modules[index];
                final moduleId = module['id'] as int;
                final perms = _permissionsByModule[moduleId] ?? {};
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatModuleName(
                                module['nom']?.toString() ?? '',
                              ),
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          _PermissionToggle(
                            value: perms['lecture'] == true,
                            onChanged:
                                _isAdmin
                                    ? (v) => _togglePermission(
                                      moduleId,
                                      'lecture',
                                      v,
                                    )
                                    : null,
                          ),
                          _PermissionToggle(
                            value: perms['ajout'] == true,
                            onChanged:
                                _isAdmin
                                    ? (v) =>
                                        _togglePermission(moduleId, 'ajout', v)
                                    : null,
                          ),
                          _PermissionToggle(
                            value: perms['modification'] == true,
                            onChanged:
                                _isAdmin
                                    ? (v) => _togglePermission(
                                      moduleId,
                                      'modification',
                                      v,
                                    )
                                    : null,
                          ),
                          _PermissionToggle(
                            value: perms['suppression'] == true,
                            onChanged:
                                _isAdmin
                                    ? (v) => _togglePermission(
                                      moduleId,
                                      'suppression',
                                      v,
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    if (index < _modules.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatModuleName(String raw) {
    switch (raw) {
      case 'notre_entite':
        return 'Notre entité';
      case 'parametrages':
        return 'Paramétrages';
      case 'traitements':
        return 'Traitements';
      case 'edition':
        return 'Édition';
      default:
        return raw;
    }
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PermissionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }
}
