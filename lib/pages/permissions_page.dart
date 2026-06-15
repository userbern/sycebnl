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

  Future<void> _selectUser(int userId) async {
    setState(() { _selectedUserId = userId; _permissionsByModule.clear(); });
    try {
      final rows = await AuthService.getUserPermissions(userId);
      final map  = <int, Map<String, bool>>{};
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
      if (!mounted) return;
      setState(() => _permissionsByModule.addAll(map));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  Future<void> _showCreateUserDialog() async {
    final loginCtrl  = TextEditingController();
    final nomCtrl    = TextEditingController();
    final prenomCtrl = TextEditingController();
    final passCtrl   = TextEditingController();
    final formKey    = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              _formField(passCtrl, 'Mot de passe', obscure: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await AuthService.createUser(
                  login:     loginCtrl.text.trim(),
                  password:  passCtrl.text,
                  nom:       nomCtrl.text.trim(),
                  prenom:    prenomCtrl.text.trim(),
                  createdBy: _currentUserId,
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
            child: const Text('Créer'),
          ),
        ],
      ),
    );
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
      {bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
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
                if (_isAdmin)
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
                        title: Text(login,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: fullName.isNotEmpty
                            ? Text(fullName, style: const TextStyle(fontSize: 11))
                            : null,
                        onTap: () => _selectUser(uid),
                        trailing: _isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: Colors.red.shade300,
                                tooltip: 'Supprimer',
                                onPressed: () => _confirmDeleteUser(uid, login),
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
              if (_isAdmin)
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
                  onChanged: _isAdmin
                      ? (v) => _togglePermission(moduleId, 'lecture', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['ajout'] == true,
                  onChanged: _isAdmin
                      ? (v) => _togglePermission(moduleId, 'ajout', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['modification'] == true,
                  onChanged: _isAdmin
                      ? (v) => _togglePermission(moduleId, 'modification', v)
                      : null,
                ),
                _PermToggle(
                  value: perms['suppression'] == true,
                  onChanged: _isAdmin
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
