import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_service.dart';
import '../services/auth_service_local.dart';
import '../services/dossier_crypto_service.dart';
import '../models/user_session.dart';
import 'dossier_recovery_page.dart';

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
  bool _isEncrypted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isEncrypted = await DossierCryptoService.isFileEncrypted(widget.filePath);
    if (_isEncrypted) {
      // Le fichier réel est chiffré : impossible de lire la liste des
      // utilisateurs avant d'avoir déchiffré avec le mot de passe. Le login
      // sera saisi manuellement (repli existant : voir _users vide ci-dessous).
      if (mounted) setState(() => _isLoadingUsers = false);
      return;
    }
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      // Ouvrir temporairement la base de données pour lire les utilisateurs
      await DatabaseService.initializeFfi();
      final db = await databaseFactoryFfi.openDatabase(widget.filePath);
      final users = await db.query(
        'utilisateur',
        where: 'is_active = 1 AND deleted_at IS NULL',
        orderBy: 'login ASC',
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
      String openPath = widget.filePath;

      if (_isEncrypted) {
        final decrypted = await DossierCryptoService.decryptToTemp(
          widget.filePath,
          _passwordController.text,
        );
        DossierCryptoService.registerOpenSession(
          tempPath: decrypted.tempPath,
          realPath: widget.filePath,
          password: _passwordController.text,
        );
        openPath = decrypted.tempPath;

        // La liste des utilisateurs n'a pu être chargée qu'après déchiffrement.
        if (_users.isEmpty) {
          await DatabaseService.initializeFfi();
          final db = await databaseFactoryFfi.openDatabase(openPath);
          _users = await db.query(
            'utilisateur',
            where: 'is_active = 1 AND deleted_at IS NULL',
            orderBy: 'login ASC',
          );
          await db.close();
        }
      }

      // Ouvrir la base de données
      await DatabaseService.openDatabase(openPath);

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
    } on WrongPasswordException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Mot de passe incorrect');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Erreur: ${e.toString()}');
    }
  }

  Future<void> _forgotPassword() async {
    final newPasswordSet = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DossierRecoveryPage(filePath: widget.filePath),
      ),
    );
    if (newPasswordSet == true && mounted) {
      // Le mot de passe a changé : réinitialiser le formulaire. Le dossier
      // reste chiffré, la liste des utilisateurs sera rechargée après le
      // prochain déchiffrement réussi dans _login().
      _passwordController.clear();
      setState(() {
        _users = [];
        _selectedLogin = null;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(RegExp(r'[/\\]')).last;

    if (_isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Connexion', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Connexion'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_outline, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fichier protégé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(fileName, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
              ),

              // Tableau de saisie
              Padding(
                padding: const EdgeInsets.all(28),
                child: Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Ligne Login
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: _label('Utilisateur', Icons.person_outline),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                          child: _users.isNotEmpty
                              ? DropdownButtonHideUnderline(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedLogin,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                    ),
                                    items: [
                                      ..._users.map((u) => DropdownMenuItem(value: u['login'] as String, child: Text(u['login'] as String, style: const TextStyle(fontSize: 13)))),
                                      const DropdownMenuItem(value: '__manual__', child: Text('Saisir manuellement…', style: TextStyle(fontSize: 13, color: Colors.grey))),
                                    ],
                                    onChanged: _isLoading ? null : (v) {
                                      setState(() {
                                        if (v == '__manual__') { _selectedLogin = null; _loginController.clear(); }
                                        else { _selectedLogin = v; _loginController.text = v!; }
                                      });
                                    },
                                  ),
                                )
                              : TextField(
                                  controller: _loginController,
                                  focusNode: _loginFocusNode,
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true, fillColor: Colors.white, isDense: true,
                                  ),
                                  enabled: !_isLoading,
                                ),
                        ),
                      ],
                    ),

                    // Séparateur
                    TableRow(children: [
                      Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                      Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                    ]),

                    // Ligne saisie manuelle (si sélectionné)
                    if (_selectedLogin == null && _users.isNotEmpty) ...[
                      TableRow(
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: _label('Login', Icons.edit_outlined),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                            child: TextField(
                              controller: _loginController,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Entrez votre login',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.orange.shade300)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.orange.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true, fillColor: Colors.white, isDense: true,
                              ),
                              enabled: !_isLoading,
                            ),
                          ),
                        ],
                      ),
                      TableRow(children: [
                        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                      ]),
                    ],

                    // Ligne Mot de passe
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: _label('Mot de passe', Icons.key_outlined),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _login(),
                            enabled: !_isLoading,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true, fillColor: Colors.white, isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bouton connexion
              Padding(
                padding: const EdgeInsets.only(left: 28, right: 28, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login, color: Colors.white, size: 18),
                    label: Text(_isLoading ? 'Connexion…' : 'Se connecter', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              if (_isEncrypted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('Mot de passe oublié ?'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
