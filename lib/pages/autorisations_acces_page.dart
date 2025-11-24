import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class AutorisationsAccesPage extends StatefulWidget {
  final UserSession userSession;

  const AutorisationsAccesPage({super.key, required this.userSession});

  @override
  State<AutorisationsAccesPage> createState() => _AutorisationsAccesPageState();
}

class _AutorisationsAccesPageState extends State<AutorisationsAccesPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _modules = [];
  final Map<String, Map<int, Map<String, bool>>> _userPermissions = {};
  final Map<String, Map<int, Map<String, bool>>> _originalPermissions = {};
  bool _isLoading = true;
  String? _selectedUserId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Vérifier si l'utilisateur a des changements non sauvegardés
  bool _hasChanges() {
    if (_selectedUserId == null) return false;

    final current = _userPermissions[_selectedUserId];
    final original = _originalPermissions[_selectedUserId];

    if (current == null || original == null) return false;

    for (var moduleId in current.keys) {
      for (var permission in [
        'lecture',
        'ajout',
        'modification',
        'suppression',
      ]) {
        if (current[moduleId]![permission] != original[moduleId]![permission]) {
          return true;
        }
      }
    }
    return false;
  }

  /// Charger tous les utilisateurs et leurs permissions
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await AuthService.getAllUsers();
      final modules = await AuthService.getAllModules();

      if (!mounted) return;

      _users = users;
      _modules = modules;

      // Charger les permissions pour chaque utilisateur
      for (var user in _users) {
        final userId = user['id'] as String;
        final permissions = await AuthService.getUserPermissions(userId);

        if (!mounted) return;

        _userPermissions[userId] = {};
        for (var module in _modules) {
          final moduleId = module['id'] as int;
          _userPermissions[userId]![moduleId] = {
            'lecture': false,
            'ajout': false,
            'modification': false,
            'suppression': false,
          };
        }

        // Remplir avec les vraies données
        for (var perm in permissions) {
          final moduleId = perm['module_id'] as int;
          _userPermissions[userId]![moduleId] = {
            'lecture': perm['lecture'] ?? false,
            'ajout': perm['ajout'] ?? false,
            'modification': perm['modification'] ?? false,
            'suppression': perm['suppression'] ?? false,
          };
        }
      }

      // Sauvegarder une copie des permissions originales
      _originalPermissions.clear();
      for (var userId in _userPermissions.keys) {
        _originalPermissions[userId] = {};
        for (var moduleId in _userPermissions[userId]!.keys) {
          _originalPermissions[userId]![moduleId] = {
            'lecture': _userPermissions[userId]![moduleId]!['lecture']!,
            'ajout': _userPermissions[userId]![moduleId]!['ajout']!,
            'modification':
                _userPermissions[userId]![moduleId]!['modification']!,
            'suppression': _userPermissions[userId]![moduleId]!['suppression']!,
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Mettre à jour une permission LOCALEMENT (pas en base de données)
  void _updatePermissionLocally(
    String userId,
    int moduleId,
    String permission,
    bool value,
  ) {
    setState(() {
      _userPermissions[userId]![moduleId]![permission] = value;
    });
  }

  /// ENREGISTRER tous les changements en base de données
  Future<void> _saveChanges() async {
    if (_selectedUserId == null) return;

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      // Préparer la liste des mises à jour
      final updates = <Map<String, dynamic>>[];
      for (var moduleId in _userPermissions[_selectedUserId]!.keys) {
        updates.add({
          'moduleId': moduleId,
          'lecture': _userPermissions[_selectedUserId]![moduleId]!['lecture'],
          'ajout': _userPermissions[_selectedUserId]![moduleId]!['ajout'],
          'modification':
              _userPermissions[_selectedUserId]![moduleId]!['modification'],
          'suppression':
              _userPermissions[_selectedUserId]![moduleId]!['suppression'],
        });
      }

      // Appeler la méthode de mise à jour en masse
      await AuthService.updatePermissions(_selectedUserId!, updates);

      // Mettre à jour les permissions originales pour pouvoir tracker les changements
      _originalPermissions[_selectedUserId!] = {};
      for (var moduleId in _userPermissions[_selectedUserId]!.keys) {
        _originalPermissions[_selectedUserId!]![moduleId] = {
          'lecture': _userPermissions[_selectedUserId]![moduleId]!['lecture']!,
          'ajout': _userPermissions[_selectedUserId]![moduleId]!['ajout']!,
          'modification':
              _userPermissions[_selectedUserId]![moduleId]!['modification']!,
          'suppression':
              _userPermissions[_selectedUserId]![moduleId]!['suppression']!,
        };
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions enregistrées avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateUserDialog() {
    final emailController = TextEditingController();
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool passwordsMatch = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Créer un nouvel utilisateur'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: prenomController,
                          decoration: const InputDecoration(
                            labelText: 'Prénom',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nomController,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          onChanged: (_) {
                            setDialogState(() {
                              passwordsMatch =
                                  passwordController.text ==
                                      confirmPasswordController.text &&
                                  passwordController.text.isNotEmpty;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            border: const OutlineInputBorder(),
                            suffixIcon:
                                passwordsMatch
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : (confirmPasswordController.text.isEmpty
                                        ? null
                                        : const Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                        )),
                          ),
                          obscureText: true,
                          onChanged: (_) {
                            setDialogState(() {
                              passwordsMatch =
                                  passwordController.text ==
                                      confirmPasswordController.text &&
                                  passwordController.text.isNotEmpty;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          passwordsMatch
                              ? () async {
                                try {
                                  await AuthService.createUser(
                                    email: emailController.text,
                                    password: passwordController.text,
                                    prenom: prenomController.text,
                                    nom: nomController.text,
                                  );

                                  if (mounted && context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Utilisateur créé avec succès',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadData();
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Erreur: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                              : null,
                      child: const Text('Créer'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ❌ SI PAS ADMIN : AFFICHER ACCÈS REFUSÉ
    if (!widget.userSession.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Autorisations d\'accès'),
          backgroundColor: Colors.blue.shade900,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 20),
              Text(
                'Accès refusé',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Seuls les administrateurs peuvent gérer\nles autorisations d\'accès',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorisations d\'accès'),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        backgroundColor: Colors.blue.shade900,
        child: const Icon(Icons.person_add),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📌 Liste des utilisateurs
                      Container(
                        margin: EdgeInsets.all(screenHeight * 0.02),
                        padding: EdgeInsets.all(screenHeight * 0.02),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Liste des utilisateurs',
                              style: TextStyle(
                                fontSize: screenHeight * 0.02,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            ..._users.map((user) {
                              final userId = user['id'] as String;
                              final isSelected = _selectedUserId == userId;

                              return Card(
                                margin: EdgeInsets.only(
                                  bottom: screenHeight * 0.01,
                                ),
                                elevation: isSelected ? 4 : 1,
                                color:
                                    isSelected
                                        ? Colors.blue.shade100
                                        : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedUserId = userId;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      screenHeight * 0.015,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              isSelected
                                                  ? Colors.blue.shade700
                                                  : Colors.grey.shade400,
                                          child: Text(
                                            '${user['prenom']?[0] ?? ''}${user['nom']?[0] ?? ''}'
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${user['prenom']} ${user['nom']}',
                                                style: TextStyle(
                                                  fontSize:
                                                      screenHeight * 0.018,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                  color:
                                                      isSelected
                                                          ? Colors.blue.shade900
                                                          : Colors.black87,
                                                ),
                                              ),
                                              SizedBox(
                                                height: screenHeight * 0.003,
                                              ),
                                              Text(
                                                user['email'] ?? '',
                                                style: TextStyle(
                                                  fontSize:
                                                      screenHeight * 0.014,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.blue.shade700,
                                            size: screenHeight * 0.025,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      // 📋 Matrice de permissions
                      if (_selectedUserId != null) ...[
                        Container(
                          margin: EdgeInsets.all(screenHeight * 0.02),
                          padding: EdgeInsets.all(screenHeight * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permissions - ${_users.firstWhere((u) => u['id'] == _selectedUserId)['prenom']} ${_users.firstWhere((u) => u['id'] == _selectedUserId)['nom']}',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.022,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Module')),
                                    DataColumn(label: Text('Lecture')),
                                    DataColumn(label: Text('Créer')),
                                    DataColumn(label: Text('Modifier')),
                                    DataColumn(label: Text('Supprimer')),
                                  ],
                                  rows:
                                      _modules.map((module) {
                                        final moduleId = module['id'] as int;
                                        final perms =
                                            _userPermissions[_selectedUserId]![moduleId]!;

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(module['nom'] as String),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: perms['lecture'],
                                                onChanged: (value) {
                                                  _updatePermissionLocally(
                                                    _selectedUserId!,
                                                    moduleId,
                                                    'lecture',
                                                    value ?? false,
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: perms['ajout'],
                                                onChanged: (value) {
                                                  _updatePermissionLocally(
                                                    _selectedUserId!,
                                                    moduleId,
                                                    'ajout',
                                                    value ?? false,
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: perms['modification'],
                                                onChanged: (value) {
                                                  _updatePermissionLocally(
                                                    _selectedUserId!,
                                                    moduleId,
                                                    'modification',
                                                    value ?? false,
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: perms['suppression'],
                                                onChanged: (value) {
                                                  _updatePermissionLocally(
                                                    _selectedUserId!,
                                                    moduleId,
                                                    'suppression',
                                                    value ?? false,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 💾 Bouton Enregistrer (activé si changements)
                        Padding(
                          padding: EdgeInsets.all(screenHeight * 0.02),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Indicateur de changements
                              if (_hasChanges())
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Changements non enregistrés',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tout à jour',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed:
                                    _hasChanges() && !_isSaving
                                        ? _saveChanges
                                        : null,
                                icon:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.save),
                                label: Text(
                                  _isSaving
                                      ? 'Enregistrement...'
                                      : 'Enregistrer',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
