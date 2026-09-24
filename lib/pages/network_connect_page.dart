import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/network/network_client.dart';
import '../services/network/network_connection_service.dart';
import '../services/network/accounting_server_service.dart';

/// Écran « Se connecter à une base réseau » : permet de rejoindre le
/// dossier comptable partagé par un autre poste (le « chef comptable », via
/// `NetworkShareDialog` / `AccountingServerService`) sans en faire de copie
/// locale. Saisie IP + port + identifiant + mot de passe, login réseau, puis
/// bascule l'application en mode distant (`RepositoryProvider` pointe vers
/// `RemoteRepository`).
class NetworkConnectPage extends StatefulWidget {
  const NetworkConnectPage({super.key});

  @override
  State<NetworkConnectPage> createState() => _NetworkConnectPageState();
}

class _NetworkConnectPageState extends State<NetworkConnectPage> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(
    text: AccountingServerService.port.toString(),
  );
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  String? _error;
  bool _serverUnavailable = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _error = null;
      _serverUnavailable = false;
    });

    try {
      await NetworkConnectionService.instance.connect(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );

      final userData = NetworkConnectionService.instance.currentUser!;
      final permissions = NetworkConnectionService.instance.permissions!;
      AuthService.setCurrentUser(userData);

      final userSession = UserSession(
        id: userData['id'].toString(),
        login: (userData['login'] ?? '').toString(),
        nom: (userData['nom'] ?? '').toString(),
        prenom: (userData['prenom'] ?? '').toString(),
        email: '',
        role: (userData['role'] ?? 'utilisateur').toString(),
        permissions: permissions,
      );

      if (!mounted) return;
      Navigator.of(context).pop(userSession);
    } on NetworkUnavailableException catch (e) {
      setState(() {
        _serverUnavailable = true;
        _error = e.message;
      });
    } on NetworkApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'Identifiant ou mot de passe incorrect'
            : e.message;
      });
    } catch (e) {
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Se connecter à une base réseau')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.wifi_tethering, size: 56, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    'Connectez-vous au dossier comptable partagé par un '
                    'autre poste sur le réseau local. Aucune copie de la '
                    'base n\'est effectuée : les données restent sur le '
                    'poste qui héberge le partage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_serverUnavailable) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Base réseau indisponible',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse IP du serveur',
                            hintText: '192.168.1.10',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Requis'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || int.tryParse(v.trim()) == null) {
                              return 'Invalide';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginController,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onFieldSubmitted: (_) => _connect(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 24),
                  // Authentifie l'utilisateur et retourne une UserSession vers HomePage ; ne charge pas encore les écritures.
                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _connect,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Se connecter'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
