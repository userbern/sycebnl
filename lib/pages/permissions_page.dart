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
  int? get _currentUserId => int.tryParse(widget.userSession?.id ?? '');

  /// Base de données vide (aucun utilisateur) : aucune restriction, on doit
  /// pouvoir créer le premier compte administrateur.
  bool get _isBootstrap => widget.userSession == null && _users.isEmpty;
  bool get _canManage => _isAdmin || _isBootstrap;

  static const _sections = [
    ('Notre Entité',  ['identification']),
    ('Paramétrages',  ['plan_comptable', 'liste_tiers', 'codes_journaux',
                       'liste_bailleurs', 'liste_projets', 'gestion_budgets']),
    ('Traitements',   ['saisie_comptable', 'journaux_de_saisie', 'interrogations']),
    ('Édition',       ['balance_comptes', 'grand_livre', 'journal']),
    ('Exercices',     ['exercices']),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final users   = await AuthService.getAllUsers();
      final modules = await AuthService.getAllModules();

      final visibleUsers = _isAdmin
          ? users.where((u) => u['id'] != _currentUserId).toList()
          : users.where((u) => u['id'] == _currentUserId).toList();

      if (!mounted) return;
      setState(() {
        _users   = visibleUsers;
        _modules = modules;
        _isLoading = false;
      });

      if (_selectedUserId == null && visibleUsers.isNotEmpty) {
        await _selectUser(visibleUsers.first['id'] as int);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  /// Convertit les lignes brutes de `AuthService.getUserPermissions` en
  /// `Map<moduleId, {lecture/ajout/modification/suppression}>`, en
  /// complétant les modules absents avec des valeurs à false.
  Map<int, Map<String, bool>> _mapPermissionRows(List<Map<String, dynamic>> rows) {
    final map = <int, Map<String, bool>>{};
    for (final row in rows) {
      final moduleId = row['module_id'] as int;
      map[moduleId] = {
        'lecture':      row['lecture']      == 1 || row['lecture']      == true,
        'ajout':        row['ajout']        == 1 || row['ajout']        == true,
        'modification': row['modification'] == 1 || row['modification'] == true,
        'suppression':  row['suppression']  == 1 || row['suppression']  == true,
      };
    }
    for (final m in _modules) {
      final id = m['id'] as int;
      map.putIfAbsent(id, () => {
        'lecture': false, 'ajout': false,
        'modification': false, 'suppression': false,
      });
    }
    return map;
  }

  Future<void> _selectUser(int userId) async {
    setState(() { _selectedUserId = userId; _permissionsByModule.clear(); });
    try {
      final rows = await AuthService.getUserPermissions(userId);
      final map  = _mapPermissionRows(rows);
      if (!mounted) return;
      setState(() => _permissionsByModule.addAll(map));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _setAllPermissions(bool value) {
    setState(() {
      for (final m in _modules) {
        final id = m['id'] as int;
        _permissionsByModule[id] = {
          'lecture': value, 'ajout': value,
          'modification': value, 'suppression': value,
        };
      }
    });
  }

  Future<void> _showCopyPermissionsDialog() async {
    final otherUsers = _users.where((u) => u['id'] != _selectedUserId).toList();
    if (otherUsers.isEmpty) return;
    int? sourceUserId = otherUsers.first['id'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Copier les permissions'),
          content: SizedBox(
            width: 340,
            child: DropdownButtonFormField<int>(
              initialValue: sourceUserId,
              decoration: const InputDecoration(
                labelText: 'Copier depuis',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: otherUsers
                  .map((u) => DropdownMenuItem<int>(
                        value: u['id'] as int,
                        child: Text(u['login']?.toString() ?? ''),
                      ))
                  .toList(),
              onChanged: (v) => setDialogState(() => sourceUserId = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Copier'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || sourceUserId == null) return;
    try {
      final rows = await AuthService.getUserPermissions(sourceUserId!);
      final map  = _mapPermissionRows(rows);
      if (!mounted) return;
      setState(() {
        _permissionsByModule.clear();
        _permissionsByModule.addAll(map);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void _togglePermission(int moduleId, String key, bool value) {
    setState(() {
      _permissionsByModule[moduleId] = {
        ...(_permissionsByModule[moduleId] ?? {}),
        key: value,
      };
    });
  }

  Future<void> _save() async {
    if (_selectedUserId == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = _modules.map((m) {
        final id    = m['id'] as int;
        final perms = _permissionsByModule[id] ?? {};
        return {
          'moduleId':     id,
          'lecture':      perms['lecture']      == true,
          'ajout':        perms['ajout']        == true,
          'modification': perms['modification'] == true,
          'suppression':  perms['suppression']  == true,
        };
      }).toList();

      await AuthService.updatePermissions(_selectedUserId!, payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions enregistrées'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Vérifie l'unicité du login / email parmi les utilisateurs déjà chargés.
  /// `excludeUserId` permet d'ignorer l'utilisateur en cours de modification.
  String? _validateLoginAndEmailUniqueness({
    required String login,
    String? email,
    int? excludeUserId,
  }) {
    final loginLower = login.trim().toLowerCase();
    final emailLower = (email ?? '').trim().toLowerCase();
    for (final u in _users) {
      if (excludeUserId != null && u['id'] == excludeUserId) continue;
      final uLogin = (u['login']?.toString() ?? '').toLowerCase();
      final uEmail = (u['email']?.toString() ?? '').toLowerCase();
      if (uLogin == loginLower) return 'Ce login existe déjà';
      if (emailLower.isNotEmpty && uEmail == emailLower) return 'Cet email existe déjà';
    }
    return null;
  }

  /// Enregistre des permissions explicites à false sur tous les modules pour
  /// un nouvel utilisateur, afin d'éviter un état ambigu "aucune permission".
  Future<void> _initializeBaselinePermissions(int userId) async {
    final payload = _modules.map((m) => {
      'moduleId':     m['id'] as int,
      'lecture':      false,
      'ajout':        false,
      'modification': false,
      'suppression':  false,
    }).toList();
    await AuthService.updatePermissions(userId, payload);
  }

  Future<void> _showCreateUserDialog() async {
    final wasBootstrap = _isBootstrap;
    final loginCtrl    = TextEditingController();
    final nomCtrl      = TextEditingController();
    final prenomCtrl   = TextEditingController();
    final emailCtrl    = TextEditingController();
    final passCtrl     = TextEditingController();
    final confirmCtrl  = TextEditingController();
    final formKey      = GlobalKey<FormState>();
    String role        = wasBootstrap ? 'admin' : 'utilisateur';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouvel utilisateur'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _formField(prenomCtrl, 'Prénom'),
                const SizedBox(height: 12),
                _formField(nomCtrl, 'Nom'),
                const SizedBox(height: 12),
                _formField(loginCtrl, 'Login'),
                const SizedBox(height: 12),
                _formField(emailCtrl, 'Email', required: false),
                const SizedBox(height: 12),
                _formField(passCtrl, 'Mot de passe', obscure: true),
                const SizedBox(height: 12),
                _formField(confirmCtrl, 'Confirmer le mot de passe', obscure: true),
                if (!wasBootstrap) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Rôle',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'utilisateur', child: Text('Utilisateur')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                    ],
                    onChanged: (v) => setDialogState(() => role = v ?? 'utilisateur'),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (passCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final uniquenessError = _validateLoginAndEmailUniqueness(
                  login: loginCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                );
                if (uniquenessError != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(uniquenessError), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  final newUserId = await AuthService.createUser(
                    login:     loginCtrl.text.trim(),
                    password:  passCtrl.text,
                    nom:       nomCtrl.text.trim(),
                    prenom:    prenomCtrl.text.trim(),
                    email:     emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    role:      role,
                    createdBy: _currentUserId,
                  );
                  if (role != 'admin') {
                    await _initializeBaselinePermissions(newUserId);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                  if (wasBootstrap && mounted) {
                    // On vient de créer le premier admin en mode bootstrap.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Compte administrateur créé. Fermez puis rouvrez ce fichier pour vous connecter.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final uid = user['id'] as int;
    final isSelf = uid == _currentUserId;
    final loginCtrl  = TextEditingController(text: user['login']?.toString() ?? '');
    final nomCtrl    = TextEditingController(text: user['nom']?.toString() ?? '');
    final prenomCtrl = TextEditingController(text: user['prenom']?.toString() ?? '');
    final emailCtrl  = TextEditingController(text: user['email']?.toString() ?? '');
    final formKey    = GlobalKey<FormState>();
    String role = (user['role']?.toString() ?? 'utilisateur');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier l\'utilisateur'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _formField(prenomCtrl, 'Prénom'),
                const SizedBox(height: 12),
                _formField(nomCtrl, 'Nom'),
                const SizedBox(height: 12),
                _formField(loginCtrl, 'Login'),
                const SizedBox(height: 12),
                _formField(emailCtrl, 'Email', required: false),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'utilisateur', child: Text('Utilisateur')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                  ],
                  onChanged: isSelf ? null : (v) => setDialogState(() => role = v ?? role),
                ),
                if (isSelf) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Vous ne pouvez pas modifier votre propre rôle.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final uniquenessError = _validateLoginAndEmailUniqueness(
                  login: loginCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  excludeUserId: uid,
                );
                if (uniquenessError != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(uniquenessError), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await AuthService.updateUser(
                    id:     uid,
                    login:  loginCtrl.text.trim(),
                    nom:    nomCtrl.text.trim(),
                    prenom: prenomCtrl.text.trim(),
                    email:  emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    role:   isSelf ? null : role,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog(int userId, String login) async {
    final passCtrl    = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey     = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réinitialiser le mot de passe de « $login »'),
        content: SizedBox(
          width: 340,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _formField(passCtrl, 'Nouveau mot de passe', obscure: true),
              const SizedBox(height: 12),
              _formField(confirmCtrl, 'Confirmer le mot de passe', obscure: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (passCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await AuthService.resetPassword(userId: userId, newPassword: passCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe réinitialisé'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserActive(int userId, bool newIsActive) async {
    try {
      await AuthService.updateUser(id: userId, isActive: newIsActive);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDeleteUser(int userId, String login) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Supprimer « $login » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.deleteUser(userId);
      if (_selectedUserId == userId) setState(() => _selectedUserId = null);
      await _loadData();
    }
  }

  TextFormField _formField(TextEditingController ctrl, String label,
      {bool obscure = false, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Autorisations d\'accès'),
              backgroundColor: Colors.lightBlue.shade600,
              foregroundColor: Colors.white,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Row(
                  children: [
                    _buildUserPanel(),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildPermissionsPanel()),
                  ],
                ),
    );
  }

  Widget _buildUserPanel() {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Utilisateurs',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
                if (_canManage)
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined, size: 20),
                    tooltip: 'Nouvel utilisateur',
                    onPressed: _showCreateUserDialog,
                    color: Colors.blue.shade700,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _users.isEmpty
                ? Center(
                    child: Text(
                      'Aucun utilisateur',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final user      = _users[i];
                      final uid       = user['id'] as int;
                      final login     = user['login']?.toString() ?? '';
                      final nom       = user['nom']?.toString() ?? '';
                      final prenom    = user['prenom']?.toString() ?? '';
                      final fullName  = [prenom, nom].where((s) => s.isNotEmpty).join(' ');
                      final isSelected = uid == _selectedUserId;
                      final isActive  = user['is_active'] == null ||
                          user['is_active'] == 1 ||
                          user['is_active'] == true;

                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: Colors.blue.shade50,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isSelected
                              ? Colors.blue.shade200
                              : Colors.grey.shade200,
                          child: Text(
                            login.isNotEmpty ? login[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        title: Text(
                          login,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive ? null : Colors.grey.shade500,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (fullName.isNotEmpty) fullName,
                            if (!isActive) 'Inactif',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? null : Colors.red.shade300,
                          ),
                        ),
                        onTap: () => _selectUser(uid),
                        trailing: _canManage
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                tooltip: 'Actions',
                                onSelected: (action) {
                                  switch (action) {
                                    case 'edit':
                                      _showEditUserDialog(user);
                                      break;
                                    case 'reset_password':
                                      _showResetPasswordDialog(uid, login);
                                      break;
                                    case 'toggle_active':
                                      _toggleUserActive(uid, !isActive);
                                      break;
                                    case 'delete':
                                      _confirmDeleteUser(uid, login);
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                  const PopupMenuItem(
                                    value: 'reset_password',
                                    child: Text('Réinitialiser le mot de passe'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle_active',
                                    child: Text(isActive ? 'Désactiver' : 'Réactiver'),
                                  ),
                                  const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPanel() {
    if (_selectedUserId == null) {
      return Center(
        child: Text(
          'Sélectionnez un utilisateur',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final selectedUser = _users.firstWhere(
      (u) => u['id'] == _selectedUserId,
      orElse: () => {},
    );
    final login = selectedUser['login']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Permissions de « $login »',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              if (_canManage)
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Enregistrer'),
                ),
            ],
          ),
        ),
        if (_canManage)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _setAllPermissions(true),
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('Tout sélectionner'),
                ),
                TextButton.icon(
                  onPressed: () => _setAllPermissions(false),
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text('Tout désélectionner'),
                ),
                if (_users.length > 1)
                  TextButton.icon(
                    onPressed: _showCopyPermissionsDialog,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copier les permissions...'),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text('Sous-menu',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              _ColHeader(label: 'Lecture'),
              _ColHeader(label: 'Ajout'),
              _ColHeader(label: 'Modifier'),
              _ColHeader(label: 'Supprimer'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(children: _buildSections())),
      ],
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];

    for (final section in _sections) {
      final sectionLabel = section.$1;
      final sectionNoms  = section.$2;

      final sectionModules = sectionNoms
          .map((nom) => _modules.where((m) => m['nom'] == nom).firstOrNull)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (sectionModules.isEmpty) continue;

      widgets.add(
        Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          child: Text(
            sectionLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );

      for (int i = 0; i < sectionModules.length; i++) {
        final module   = sectionModules[i];
        final moduleId = module['id'] as int;
        final perms    = _permissionsByModule[moduleId] ?? {};

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatModuleName(module['nom']?.toString() ?? ''),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                _PermToggle(
                  value: perms['lecture'] == true,
                  onChanged: _canManage
                      ? (v) => _togglePermission(moduleId, 'lecture', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['ajout'] == true,
                  onChanged: _canManage
                      ? (v) => _togglePermission(moduleId, 'ajout', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['modification'] == true,
                  onChanged: _canManage
                      ? (v) => _togglePermission(moduleId, 'modification', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['suppression'] == true,
                  onChanged: _canManage
                      ? (v) => _togglePermission(moduleId, 'suppression', v)
                      : null,
                ),
              ],
            ),
          ),
        );

        if (i < sectionModules.length - 1) {
          widgets.add(const Divider(height: 1, indent: 20, endIndent: 20));
        }
      }

      widgets.add(const Divider(height: 1));
    }

    return widgets;
  }

  String _formatModuleName(String raw) {
    const names = {
      'identification':     'Identification',
      'plan_comptable':     'Plan comptable',
      'liste_tiers':        'Liste des tiers',
      'codes_journaux':     'Codes journaux',
      'liste_bailleurs':    'Liste des bailleurs',
      'liste_projets':      'Liste des projets',
      'gestion_budgets':    'Gestion des budgets',
      'saisie_comptable':   'Saisie comptable',
      'journaux_de_saisie': 'Journaux de saisie',
      'interrogations':     'Interrogations & Lettrages',
      'balance_comptes':    'Balance des comptes',
      'grand_livre':        'Grand livre',
      'journal':            'Journal',
      'exercices':          'Exercices',
    };
    return names[raw] ?? raw;
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  const _ColHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _PermToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _PermToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue.shade600,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
