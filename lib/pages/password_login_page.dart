import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_service.dart';
import '../services/auth_service_local.dart';
import '../models/user_session.dart';

class PasswordLoginPage extends StatefulWidget {
  final String filePath;

  const PasswordLoginPage({super.key, required this.filePath});

  @override
  State<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends State<PasswordLoginPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  List<Map<String, dynamic>> _users = [];
  String? _selectedLogin;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      // Ouvrir temporairement la base de données pour lire les utilisateurs
      await DatabaseService.initializeFfi();
      final db = await databaseFactoryFfi.openDatabase(widget.filePath);
      final users = await db.query(
        'users',
        where: 'is_active = 1',
        orderBy: 'nom ASC',
      );
      await db.close();

      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
          if (_users.isNotEmpty) {
            _selectedLogin = _users.first['login'] as String;
            _loginController.text = _selectedLogin!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _loginFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginController.text.isEmpty) {
      _showError('Veuillez saisir ou sélectionner un login');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Veuillez saisir le mot de passe');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ouvrir la base de données
      await DatabaseService.openDatabase(widget.filePath);

      // Vérifier le login, mot de passe et récupérer les permissions
      final loginResult = await AuthService.login(
        login: _loginController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Connexion réussie - retourner la session complète
      final userData = loginResult['user'] as Map<String, dynamic>;
      final permissions = loginResult['permissions'] as List<dynamic>;

      final userSession = UserSession(
        id: userData['id'].toString(),
        login: userData['login'] ?? '',
        nom: (userData['nom'] ?? '').toString(),
        prenom: (userData['prenom'] ?? '').toString(),
        email: '',
        role: (userData['role'] ?? 'utilisateur').toString(),
        permissions: permissions.cast<Map<String, dynamic>>(),
      );

      AuthService.setCurrentUser(userData);

      Navigator.pop(context, userSession);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Erreur: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(RegExp(r'[/\\]')).last;

    if (_isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Connexion'),
          backgroundColor: Colors.blue.shade900,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Fichier protégé',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Champ Login avec liste déroulante et saisie manuelle
                  if (_users.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedLogin,
                      decoration: const InputDecoration(
                        labelText: 'Login',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      isExpanded: true,
                      items: [
                        ..._users.map((user) {
                          return DropdownMenuItem<String>(
                            value: user['login'] as String,
                            child: Text(
                              user['login'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: '__manual__',
                          child: Text(
                            '✏️ Saisir manuellement...',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged:
                          _isLoading
                              ? null
                              : (value) {
                                setState(() {
                                  if (value == '__manual__') {
                                    _selectedLogin = null;
                                    _loginController.clear();
                                  } else {
                                    _selectedLogin = value;
                                    _loginController.text = value!;
                                  }
                                });
                              },
                    )
                  else
                    TextField(
                      controller: _loginController,
                      focusNode: _loginFocusNode,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Login',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !_isLoading,
                    ),

                  // Champ de saisie manuelle si "Saisir manuellement" sélectionné
                  if (_selectedLogin == null && _users.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _loginController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Entrez votre login',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                      enabled: !_isLoading,
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _login(),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon:
                        _isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.login),
                    label: const Text(
                      'Se connecter',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
