import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../services/database_service.dart';
import 'login_page.dart';

class DatabaseSetupPage extends StatefulWidget {
  const DatabaseSetupPage({super.key});

  @override
  State<DatabaseSetupPage> createState() => _DatabaseSetupPageState();
}

class _DatabaseSetupPageState extends State<DatabaseSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _databasePath;
  bool _isCreatingDatabase = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Obtenir le chemin par défaut de la base de données
  Future<String> _getDefaultDatabasePath() async {
    try {
      // Obtenir le répertoire Documents
      final documentsDir = await getApplicationDocumentsDirectory();

      // Créer le dossier SYCEBNL s'il n'existe pas
      final sycebnlDir = Directory(path.join(documentsDir.path, 'SYCEBNL'));
      if (!sycebnlDir.existsSync()) {
        sycebnlDir.createSync(recursive: true);
      }

      // Retourner le chemin complet vers la base de données
      return path.join(sycebnlDir.path, 'sycebnl_accounting.db');
    } catch (e) {
      // En cas d'erreur, utiliser le répertoire courant
      return path.join(
        Directory.current.path,
        'SYCEBNL',
        'sycebnl_accounting.db',
      );
    }
  }

  Future<void> _selectDatabaseLocation() async {
    try {
      if (_isCreatingDatabase) {
        // Sélectionner un emplacement pour créer une nouvelle base
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Choisir l\'emplacement du nouveau fichier comptable',
          fileName: 'sycebnl_accounting.db',
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (result != null) {
          setState(() {
            _databasePath = result;
          });
        }
      } else {
        // Sélectionner une base existante
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Sélectionner un fichier comptable existant',
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (result != null && result.files.single.path != null) {
          setState(() {
            _databasePath = result.files.single.path;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createDatabase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Utiliser le chemin sélectionné ou le chemin par défaut
      final dbPath = _databasePath ?? await _getDefaultDatabasePath();

      // Préparer les données par défaut (à améliorer avec un formulaire multi-étapes)
      final entiteData = {
        'denomination_sociale': 'Mon Organisation',
        'sigle_usuel': '',
        'domaine_intervention': '',
        'forme_juridique': '',
        'pays': '',
        'region': '',
        'ville': '',
        'quartier': '',
        'email': '',
        'telephone': '',
        'fixe_fax': '',
        'numero_fiscal': '',
        'numero_cnss': '',
        'numero_recepisse': '',
        'informations_complementaires': '',
        'currency': 'XOF',
      };

      final exerciceData = {
        'code': '2025',
        'date_debut': '2025-01-01',
        'date_fin': '2025-12-31',
      };

      final configData = {
        'longueur_compte_general': 6,
        'longueur_compte_tiers': 8,
      };

      await DatabaseService.createDatabase(
        dbPath,
        adminLogin:
            _loginController.text.isEmpty ? null : _loginController.text,
        adminPassword:
            _passwordController.text.isEmpty ? null : _passwordController.text,
        entiteData: entiteData,
        exerciceData: exerciceData,
        configData: configData,
      );

      if (!mounted) return;

      // Afficher un message avec l'emplacement de la base
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier comptable créé : $dbPath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDatabase() async {
    if (_databasePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un fichier comptable'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DatabaseService.connectToDatabase(_databasePath!);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
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
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(32),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.storage,
                      size: 64,
                      color: Colors.indigo.shade700,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Configuration du fichier comptable',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  'Créer un nouveau fichier comptable',
                                ),
                                icon: Icon(Icons.add_circle),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  'Ouvrir un fichier comptable existant',
                                ),
                                icon: Icon(Icons.folder_open),
                              ),
                            ],
                            selected: {_isCreatingDatabase},
                            onSelectionChanged: (Set<bool> selected) {
                              setState(() {
                                _isCreatingDatabase = selected.first;
                                _databasePath = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (_isCreatingDatabase) ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _loginController,
                              decoration: InputDecoration(
                                labelText: 'Login administrateur *',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Le login est requis';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe *',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Le mot de passe est requis';
                                }
                                if (value.length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe *',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Les mots de passe ne correspondent pas';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _selectDatabaseLocation,
                      icon: Icon(
                        _isCreatingDatabase
                            ? Icons.create_new_folder
                            : Icons.folder_open,
                      ),
                      label: Text(
                        _databasePath == null
                            ? (_isCreatingDatabase
                                ? 'Choisir l\'emplacement (optionnel)'
                                : 'Sélectionner le fichier comptable existant')
                            : 'Emplacement : ${_databasePath!.split(Platform.pathSeparator).last}',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (_databasePath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _databasePath!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_isCreatingDatabase && _databasePath == null) ...[
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _getDefaultDatabasePath(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Emplacement par défaut :',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          snapshot.data!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : (_isCreatingDatabase
                                  ? _createDatabase
                                  : _connectToDatabase),
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
                              : Icon(
                                _isCreatingDatabase
                                    ? Icons.create
                                    : Icons.login,
                              ),
                      label: Text(
                        _isCreatingDatabase
                            ? 'Créer le fichier comptable'
                            : 'Se connecter',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
