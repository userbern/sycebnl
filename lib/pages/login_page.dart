import 'package:flutter/material.dart';
import '../services/auth_service_local.dart';
import '../models/user_session.dart';
import '../utils/form_enter_shortcut.dart';
import '../widgets/app_logo.dart';
import 'home_page.dart';
import 'database_setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final loginResult = await AuthService.login(
        login: _loginController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Créer la session utilisateur
      final userData = loginResult['user'] as Map<String, dynamic>;
      final permissions = loginResult['permissions'] as List<dynamic>;

      final userSession = UserSession(
        id: userData['id'].toString(),
        login: userData['login'] ?? '',
        nom: userData['nom'] ?? '',
        prenom: userData['prenom'] ?? '',
        email: '',
        role: userData['role'] ?? 'utilisateur',
        permissions: permissions.cast<Map<String, dynamic>>(),
      );

      AuthService.setCurrentUser(userData);

      // Naviguer vers HomePage avec la session
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(userSession: userSession),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _changeDatabaseLocation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DatabaseSetupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade700, Colors.indigo.shade400],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(40),
              child: FormWithEnterShortcut(
                formKey: _formKey,
                onSubmit: _login,
                enabled: !_isLoading,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppLogo(size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'SYCEBNL Accounting',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connexion',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _loginController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Login',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir votre login';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir votre mot de passe';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.login),
                        label: const Text('Se connecter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _changeDatabaseLocation,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Changer de base de données'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
