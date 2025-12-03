import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/app_config_service.dart';
import '../services/database_service_new.dart';
import 'new_file_wizard_page.dart';
import 'password_login_page.dart';
import 'home_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  List<Map<String, dynamic>> _recentFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    setState(() => _isLoading = true);
    try {
      await AppConfigService.cleanupMissingFiles();
      final files = await AppConfigService.getRecentFiles();
      if (!mounted) return;
      setState(() {
        _recentFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  Future<void> _openExistingFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      dialogTitle: 'Ouvrir un fichier comptable',
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path!;
    await _openFile(filePath);
  }

  Future<void> _openFile(String filePath) async {
    try {
      // Vérifier si le fichier existe
      if (!await File(filePath).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le fichier n\'existe plus')),
        );
        await AppConfigService.removeRecentFile(filePath);
        await _loadRecentFiles();
        return;
      }

      // Vérifier si le fichier nécessite un mot de passe
      final requiresPassword = await DatabaseService.requiresPassword(filePath);

      if (requiresPassword) {
        // Rediriger vers la page de connexion avec mot de passe
        if (!mounted) return;
        final authenticated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PasswordLoginPage(filePath: filePath),
          ),
        );

        if (authenticated == true) {
          await _openFileSuccess(filePath);
        }
      } else {
        // Ouvrir directement le fichier
        await DatabaseService.openDatabase(filePath);
        await _openFileSuccess(filePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  Future<void> _openFileSuccess(String filePath) async {
    // Ajouter aux fichiers récents
    final fileName = filePath.split(Platform.pathSeparator).last;
    final requiresPassword = await DatabaseService.requiresPassword(filePath);

    await AppConfigService.addRecentFile(
      filePath: filePath,
      fileName: fileName.replaceAll('.db', ''),
      hasPassword: requiresPassword,
    );

    // Rediriger vers l'application
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  Future<void> _createNewFile() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const NewFileWizardPage()),
    );

    if (result != null) {
      await _openFileSuccess(result);
    }
  }

  Future<void> _removeRecentFile(String filePath) async {
    await AppConfigService.removeRecentFile(filePath);
    await _loadRecentFiles();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.9,
                maxHeight: screenHeight * 0.9,
              ),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // En-tête
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance,
                            size: 48,
                            color: Colors.blue.shade900,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'SYCEBNL Accounting',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Logiciel de gestion comptable des entités à but non lucratif',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Divider(height: 40),

                      // Boutons principaux
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _createNewFile,
                              icon: const Icon(
                                Icons.create_new_folder,
                                size: 28,
                              ),
                              label: const Text(
                                'Créer un nouveau fichier',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openExistingFile,
                              icon: const Icon(Icons.folder_open, size: 28),
                              label: const Text(
                                'Ouvrir un fichier existant',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(20),
                                side: BorderSide(
                                  color: Colors.blue.shade700,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Fichiers récents
                      Text(
                        'Fichiers récents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _recentFiles.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 64,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Aucun fichier récent',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _recentFiles.length,
                                  itemBuilder: (context, index) {
                                    final file = _recentFiles[index];
                                    final hasPassword =
                                        (file['has_password'] as int) == 1;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.description,
                                          size: 36,
                                          color: Colors.blue.shade700,
                                        ),
                                        title: Text(
                                          file['file_name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file['file_path'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (hasPassword) ...[
                                                  Icon(
                                                    Icons.lock,
                                                    size: 14,
                                                    color:
                                                        Colors.orange.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Protégé par mot de passe',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors
                                                              .orange
                                                              .shade700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _removeRecentFile(
                                              file['file_path'] as String,
                                            );
                                          },
                                          tooltip: 'Retirer de la liste',
                                        ),
                                        onTap: () {
                                          _openFile(
                                            file['file_path'] as String,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
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
