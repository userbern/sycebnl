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
  final _anneeController = TextEditingController();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  String? _databasePath;
  bool _isCreatingDatabase = true;
  bool _isLoading = false;

  DateTime? _selectedDateDebut;
  DateTime? _selectedDateFin;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateDebut = DateTime(now.year, 1, 1);
    _selectedDateFin = DateTime(now.year, 12, 31);
    _anneeController.text = now.year.toString();
    _updateDateControllers();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _anneeController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    if (_selectedDateDebut != null) {
      _dateDebutController.text = _formatDate(_selectedDateDebut!);
    }
    if (_selectedDateFin != null) {
      _dateFinController.text = _formatDate(_selectedDateFin!);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDateWithDropdown(
    BuildContext context,
    bool isDebut,
  ) async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => _DatePickerDialog(
            isDebut: isDebut,
            initialDate: isDebut ? _selectedDateDebut : _selectedDateFin,
            onDateSelected: (selectedDate) {
              setState(() {
                if (isDebut) {
                  _selectedDateDebut = selectedDate;
                } else {
                  _selectedDateFin = selectedDate;
                }
                _updateDateControllers();
              });
            },
          ),
    );
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

    if (_selectedDateDebut == null || _selectedDateFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les dates'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Utiliser le chemin sélectionné ou le chemin par défaut
      final dbPath = _databasePath ?? await _getDefaultDatabasePath();

      // Préparer les données par défaut
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
        'code': _anneeController.text.trim(),
        'date_debut': _selectedDateDebut!.toIso8601String(),
        'date_fin': _selectedDateFin!.toIso8601String(),
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

  Widget _buildDateField({
    required TextEditingController controller,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: enabled ? Colors.white : Colors.grey.shade50,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.text.isEmpty
                      ? 'Sélectionner une date'
                      : controller.text,
                  style: TextStyle(
                    color:
                        controller.text.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                                  'Créer un nouveau fichier comptable', style: TextStyle(color: Colors.white),
                                ),
                                icon: Icon(Icons.add_circle),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  'Ouvrir un fichier comptable existant',
                                  style: TextStyle(color: Colors.white),
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
                            // Premier exercice comptable
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Premier exercice comptable',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _anneeController,
                                    decoration: InputDecoration(
                                      labelText: 'Code exercice',
                                      hintText: '2025',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    enabled: !_isLoading,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Le code d\'exercice est requis';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Date début',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildDateField(
                                              controller: _dateDebutController,
                                              onTap:
                                                  () => _selectDateWithDropdown(
                                                    context,
                                                    true,
                                                  ),
                                              enabled: !_isLoading,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Date fin',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildDateField(
                                              controller: _dateFinController,
                                              onTap:
                                                  () => _selectDateWithDropdown(
                                                    context,
                                                    false,
                                                  ),
                                              enabled: !_isLoading,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                          color: Colors.white,
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
                                    color: Colors.blue,
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
                                            color: Colors.blue,
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
                        backgroundColor: Colors.blue.shade400,
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

class _DatePickerDialog extends StatefulWidget {
  final bool isDebut;
  final DateTime? initialDate;
  final Function(DateTime) onDateSelected;

  const _DatePickerDialog({
    required this.isDebut,
    this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late int selectedDay;
  late int selectedMonth;
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    selectedDay = date.day;
    selectedMonth = date.month;
    selectedYear = date.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDebut ? 'Date de début' : 'Date de fin'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Jour
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Jour',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedDay,
                          underline: const SizedBox(),
                          items:
                              List.generate(31, (i) => i + 1)
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() => selectedDay = value ?? selectedDay);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Mois
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Mois',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedMonth,
                          underline: const SizedBox(),
                          items:
                              List.generate(12, (i) => i + 1)
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(
                              () => selectedMonth = value ?? selectedMonth,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Année
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Année',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedYear,
                          underline: const SizedBox(),
                          items:
                              List.generate(
                                    20,
                                    (i) => DateTime.now().year - 10 + i,
                                  )
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(y.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(
                              () => selectedYear = value ?? selectedYear,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            widget.onDateSelected(
              DateTime(selectedYear, selectedMonth, selectedDay),
            );
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
