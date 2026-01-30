import 'package:flutter/material.dart';

import '../services/auth_service_local.dart';

class PermissionsPage extends StatefulWidget {
  final bool showAppBar;

  const PermissionsPage({super.key, this.showAppBar = true});

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await AuthService.getAllUsers();
      final modules = await AuthService.getAllModules();

      if (users.isEmpty) {
        setState(() {
          _users = [];
          _modules = modules;
          _selectedUserId = null;
          _permissionsByModule.clear();
          _isLoading = false;
        });
        return;
      }

      final selectedId = _selectedUserId ?? users.first['id'] as int;
      setState(() {
        _users = users;
        _modules = modules;
        _selectedUserId = selectedId;
      });

      await _loadPermissions(selectedId);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPermissions(int userId) async {
    try {
      final rawPerms = await AuthService.getUserPermissions(userId);

      // Initialise toutes les permissions à false pour chaque module
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
          'lecture': (perm['lecture'] == 1) || (perm['lecture'] == true),
          'ajout': (perm['ajout'] == 1) || (perm['ajout'] == true),
          'modification':
              (perm['modification'] == 1) || (perm['modification'] == true),
          'suppression':
              (perm['suppression'] == 1) || (perm['suppression'] == true),
        };
      }

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

  Future<void> _save() async {
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Autorisations d\'accès'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
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
                child: Row(
                  children: [
                    SizedBox(width: 260, child: _buildUserList()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPermissionsTable()),
                  ],
                ),
              ),
      floatingActionButton:
          (!_isLoading && _users.isNotEmpty)
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
                                (v) =>
                                    _togglePermission(moduleId, 'lecture', v),
                          ),
                          _PermissionToggle(
                            value: perms['ajout'] == true,
                            onChanged:
                                (v) => _togglePermission(moduleId, 'ajout', v),
                          ),
                          _PermissionToggle(
                            value: perms['modification'] == true,
                            onChanged:
                                (v) => _togglePermission(
                                  moduleId,
                                  'modification',
                                  v,
                                ),
                          ),
                          _PermissionToggle(
                            value: perms['suppression'] == true,
                            onChanged:
                                (v) => _togglePermission(
                                  moduleId,
                                  'suppression',
                                  v,
                                ),
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
  final ValueChanged<bool> onChanged;

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
