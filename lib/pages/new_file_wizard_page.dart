import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../services/dossier_crypto_service.dart';
import 'recovery_key_display_page.dart';

class NewFileWizardPage extends StatefulWidget {
  const NewFileWizardPage({super.key});

  @override
  State<NewFileWizardPage> createState() => _NewFileWizardPageState();
}

class _NewFileWizardPageState extends State<NewFileWizardPage> {
  int _currentStep = 0;
  String? _selectedFilePath;

  // Formulaire entité
  final _denominationController = TextEditingController();
  final _sigleController = TextEditingController();
  final _domaineController = TextEditingController();
  String? _formeJuridique;
  final _paysController = TextEditingController();
  final _regionController = TextEditingController();
  final _villeController = TextEditingController();
  final _quartierController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _fixeFaxController = TextEditingController();
  final _numeroFiscalController = TextEditingController();
  final _numeroCnssController = TextEditingController();
  final _numeroRecepisseController = TextEditingController();
  final _autreReferenceController = TextEditingController();
  final _infosComplementairesController = TextEditingController();
  final _deviseController = TextEditingController(text: 'FCFA (XOF)');

  // Formulaire sécurité
  bool _usePassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _loginController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Paramètres comptables
  final _codeExerciceController = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  DateTime? _dateDebut = DateTime.now();
  DateTime? _dateFin = DateTime(DateTime.now().year, 12, 31);
  int _dureeMois = 0;
  final _longueurGeneralController = TextEditingController(text: '8');
  final _longueurTiersController = TextEditingController(text: '8');

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Calculer la durée initiale
    _calculateDuration();
  }

  @override
  void dispose() {
    _denominationController.dispose();
    _sigleController.dispose();
    _domaineController.dispose();
    _paysController.dispose();
    _regionController.dispose();
    _villeController.dispose();
    _quartierController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _fixeFaxController.dispose();
    _numeroFiscalController.dispose();
    _numeroCnssController.dispose();
    _numeroRecepisseController.dispose();
    _autreReferenceController.dispose();
    _infosComplementairesController.dispose();
    _deviseController.dispose();
    _codeExerciceController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _longueurGeneralController.dispose();
    _longueurTiersController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Créer un nouveau fichier comptable',
      fileName: 'comptabilite.db',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result;
      });
    }
  }

  void _calculateDuration() {
    if (_dateDebut != null && _dateFin != null) {
      final diff = _dateFin!.difference(_dateDebut!);
      setState(() {
        _dureeMois = (diff.inDays / 30).round();
      });
    }
  }

  Future<void> _createFile() async {
    // Validation finale
    if (_selectedFilePath == null) {
      _showError('Veuillez choisir un emplacement pour le fichier');
      return;
    }

    if (_denominationController.text.isEmpty) {
      _showError('La dénomination sociale est obligatoire');
      return;
    }

    if (_dateDebut == null || _dateFin == null) {
      _showError('Les dates d\'exercice sont obligatoires');
      return;
    }

    if (_dureeMois > 18) {
      _showError('La durée de l\'exercice ne peut pas dépasser 18 mois');
      return;
    }

    if (_usePassword) {
      if (_passwordController.text.isEmpty) {
        _showError('Veuillez saisir un mot de passe');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Les mots de passe ne correspondent pas');
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      // Préparer les données de l'entité
      final entiteData = {
        'denomination_sociale': _denominationController.text,
        'sigle_usuel':
            _sigleController.text.isEmpty ? null : _sigleController.text,
        'domaine_intervention':
            _domaineController.text.isEmpty ? null : _domaineController.text,
        'forme_juridique': _formeJuridique,
        'pays': _paysController.text.isEmpty ? null : _paysController.text,
        'region':
            _regionController.text.isEmpty ? null : _regionController.text,
        'ville': _villeController.text.isEmpty ? null : _villeController.text,
        'quartier':
            _quartierController.text.isEmpty ? null : _quartierController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'telephone':
            _telephoneController.text.isEmpty
                ? null
                : _telephoneController.text,
        'fixe_fax':
            _fixeFaxController.text.isEmpty ? null : _fixeFaxController.text,
        'numero_fiscal':
            _numeroFiscalController.text.isEmpty
                ? null
                : _numeroFiscalController.text,
        'numero_cnss':
            _numeroCnssController.text.isEmpty
                ? null
                : _numeroCnssController.text,
        'numero_recepisse':
            _numeroRecepisseController.text.isEmpty
                ? null
                : _numeroRecepisseController.text,
        'informations_complementaires':
            _infosComplementairesController.text.isEmpty
                ? null
                : _infosComplementairesController.text,
        'currency': _deviseController.text,
      };

      // Préparer les données de configuration (paramètres fixes)
      final configData = {
        'longueur_compte_general': int.parse(_longueurGeneralController.text),
        'longueur_compte_tiers': int.parse(_longueurTiersController.text),
      };

      // Préparer les données du premier exercice
      final exerciceData = {
        'code': _codeExerciceController.text,
        'date_debut': _dateDebut!.toIso8601String(),
        'date_fin': _dateFin!.toIso8601String(),
        'duree_mois': _dureeMois,
      };

      // Créer la base de données
      await DatabaseService.createDatabase(
        _selectedFilePath!,
        adminLogin: _usePassword ? _loginController.text : null,
        adminPassword: _usePassword ? _passwordController.text : null,
        entiteData: entiteData,
        configData: configData,
        exerciceData: exerciceData,
      );

      // Activer le chiffrement du dossier (module Sécurité) avec le même
      // mot de passe que l'utilisateur admin, et afficher la clé de
      // récupération une seule fois.
      if (_usePassword) {
        final (recoveryKey, dossierUuid) =
            await DatabaseService.enableDossierEncryption(
          _selectedFilePath!,
          _passwordController.text,
        );

        // enableDossierEncryption() ferme la base et chiffre le fichier :
        // il faut la rouvrir (comme le ferait password_login_page à la
        // prochaine connexion) pour que l'écran d'accueil qui suit dispose
        // d'une base de données connectée, exactement comme pour un dossier
        // créé sans mot de passe.
        final decrypted = await DossierCryptoService.decryptToTemp(
          _selectedFilePath!,
          _passwordController.text,
        );
        DossierCryptoService.registerOpenSession(
          tempPath: decrypted.tempPath,
          realPath: _selectedFilePath!,
          password: _passwordController.text,
        );
        await DatabaseService.openDatabase(decrypted.tempPath);

        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecoveryKeyDisplayPage(
              dossierUuid: dossierUuid,
              recoveryKey: recoveryKey,
              entiteNom: _denominationController.text,
            ),
          ),
        );
      }

      if (!mounted) return;

      // Retourner le chemin du fichier créé
      Navigator.pop(context, _selectedFilePath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showError('Erreur lors de la création du fichier: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un nouveau fichier comptable'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de progression personnalisée
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                _buildProgressStep(1, 'Fichier', _currentStep >= 0),
                Expanded(
                  child: Container(
                    height: 2,
                    color:
                        _currentStep >= 1
                            ? Colors.blue.shade400
                            : Colors.grey.shade300,
                  ),
                ),
                _buildProgressStep(2, 'Entité', _currentStep >= 1),
                Expanded(
                  child: Container(
                    height: 2,
                    color:
                        _currentStep >= 2
                            ? Colors.blue.shade400
                            : Colors.grey.shade300,
                  ),
                ),
                _buildProgressStep(3, 'Sécurité', _currentStep >= 2),
                Expanded(
                  child: Container(
                    height: 2,
                    color:
                        _currentStep >= 3
                            ? Colors.blue.shade400
                            : Colors.grey.shade300,
                  ),
                ),
                _buildProgressStep(4, 'Paramètres', _currentStep >= 3),
              ],
            ),
          ),
          // Contenu de l'étape actuelle
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          // Boutons de navigation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed:
                      _currentStep > 0
                          ? () => setState(() => _currentStep--)
                          : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_currentStep == 0 ? 'Annuler' : 'Précédent'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _handleContinue,
                  icon:
                      _isCreating
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
                          : Icon(
                            _currentStep == 3
                                ? Icons.check
                                : Icons.arrow_forward,
                              color: Colors.white,
                          ),
                  label: Text(
                    _currentStep == 3 ? 'Créer le fichier' : 'Suivant',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int stepNumber, String label, bool isActive) {
    final isCompleted = _currentStep > stepNumber - 1;
    final isCurrent = _currentStep == stepNumber - 1;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isCompleted || isCurrent
                    ? Colors.blue.shade400
                    : Colors.grey.shade300,
            border: Border.all(
              color: isCurrent ? Colors.blue.shade900 : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child:
                isCompleted && !isCurrent
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                      stepNumber.toString(),
                      style: TextStyle(
                        color:
                            isCompleted || isCurrent
                                ? Colors.white
                                : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Colors.blue.shade900 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  void _handleContinue() {
    if (_currentStep < 3) {
      if (_currentStep == 0 && _selectedFilePath == null) {
        _showError('Veuillez choisir un emplacement pour le fichier');
        return;
      }
      if (_currentStep == 1 && _denominationController.text.isEmpty) {
        _showError('La dénomination sociale est obligatoire');
        return;
      }
      if (_currentStep == 2 && _usePassword) {
        if (_passwordController.text.isEmpty) {
          _showError('Veuillez saisir un mot de passe');
          return;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          _showError('Les mots de passe ne correspondent pas');
          return;
        }
      }
      setState(() => _currentStep++);
    } else {
      _createFile();
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Emplacement du fichier',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choisissez l\'emplacement et le nom du fichier comptable',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _selectFile,
              icon: const Icon(Icons.folder_open, size: 32, color: Colors.white),
              label: const Text(
                'Choisir l\'emplacement',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
              ),
            ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fichier sélectionné',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedFilePath!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identification de l\'entité',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Section Identification
            _buildSectionHeader('Identification'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _denominationController,
                    label: 'Dénomination sociale *',
                    icon: Icons.business,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _sigleController,
                    label: 'Sigle usuel',
                    icon: Icons.short_text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _domaineController,
                    label: 'Domaine d\'intervention',
                    icon: Icons.category,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _formeJuridique,
                    decoration: InputDecoration(
                      labelText: 'Forme juridique',
                      prefixIcon: const Icon(Icons.account_balance),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade400,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.arrow_drop_down_circle,
                      color: Colors.blue.shade400,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ONG internationale',
                        child: Text('ONG internationale'),
                      ),
                      DropdownMenuItem(
                        value: 'Association',
                        child: Text('Association'),
                      ),
                      DropdownMenuItem(
                        value: 'ONG locale',
                        child: Text('ONG locale'),
                      ),
                      DropdownMenuItem(
                        value: 'Ordre professionnel',
                        child: Text('Ordre professionnel'),
                      ),
                      DropdownMenuItem(
                        value: 'Fondation',
                        child: Text('Fondation'),
                      ),
                      DropdownMenuItem(
                        value: 'Congrégation religieuse',
                        child: Text('Congrégation religieuse'),
                      ),
                      DropdownMenuItem(
                        value: 'Club sportif',
                        child: Text('Club sportif'),
                      ),
                      DropdownMenuItem(
                        value: 'Club services',
                        child: Text('Club services'),
                      ),
                      DropdownMenuItem(
                        value: 'Parti politique',
                        child: Text('Parti politique'),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() => _formeJuridique = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Section Localisation
            _buildSectionHeader('Localisation et contact'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _paysController,
                    label: 'Pays',
                    icon: Icons.public,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _villeController,
                    label: 'Ville',
                    icon: Icons.location_city,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _regionController,
                    label: 'Région',
                    icon: Icons.map,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _quartierController,
                    label: 'Quartier',
                    icon: Icons.pin_drop,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _telephoneController,
                    label: 'Téléphone',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _fixeFaxController,
                    label: 'Téléphone fixe / Fax',
                    icon: Icons.print,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Section Références de reconnaissance officielle
            _buildSectionHeader('Références de reconnaissance officielle'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _numeroFiscalController,
                    label: 'N° d\'identification fiscal (NIF/IFU/NCC)',
                    icon: Icons.description,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _numeroRecepisseController,
                    label: 'N° Récépissé',
                    icon: Icons.receipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _numeroCnssController,
                    label: 'N° CNSS',
                    icon: Icons.badge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _autreReferenceController,
                    label: 'Autre référence',
                    icon: Icons.info_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Section Monnaie
            _buildSectionHeader('Monnaie et informations complémentaires'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _deviseController,
                    label: 'Devise',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _infosComplementairesController,
                    label: 'Informations complémentaires',
                    icon: Icons.notes,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sécurité (optionnel)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _usePassword,
              onChanged: (value) => setState(() => _usePassword = value!),
              title: const Text(
                'Protéger ce fichier par mot de passe',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Un mot de passe sera demandé à l\'ouverture du fichier',
              ),
            ),
            if (_usePassword) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _loginController,
                decoration: InputDecoration(
                  labelText: 'Login',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_passwordController.text ==
                              _confirmPasswordController.text &&
                          _passwordController.text.isNotEmpty)
                        const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                      ),
                    ],
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep4() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paramètres comptables',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Premier exercice comptable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeExerciceController,
              decoration: InputDecoration(
                labelText: 'Code exercice (ex: 2024, 2025)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateDebut ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _dateDebut = date;
                          _calculateDuration();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date début',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dateDebut != null
                            ? '${_dateDebut!.day}/${_dateDebut!.month}/${_dateDebut!.year}'
                            : 'Sélectionner',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateFin ?? DateTime.now(),
                        firstDate: _dateDebut ?? DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _dateFin = date;
                          _calculateDuration();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date fin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dateFin != null
                            ? '${_dateFin!.day}/${_dateFin!.month}/${_dateFin!.year}'
                            : 'Sélectionner',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_dureeMois > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _dureeMois > 18
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  border: Border.all(
                    color:
                        _dureeMois > 18
                            ? Colors.red.shade200
                            : Colors.blue.shade200,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _dureeMois > 18 ? Icons.error : Icons.info,
                      color:
                          _dureeMois > 18
                              ? Colors.red.shade700
                              : Colors.blue.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Durée: $_dureeMois mois ${_dureeMois > 18 ? "(max: 18 mois)" : ""}',
                      style: TextStyle(
                        color:
                            _dureeMois > 18
                                ? Colors.red.shade700
                                : Colors.blue.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Longueur des comptes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _longueurGeneralController,
                    decoration: InputDecoration(
                      labelText: 'Comptes généraux',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: 'chiffres',
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longueurTiersController,
                    decoration: InputDecoration(
                      labelText: 'Comptes tiers',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: 'chiffres',
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }
}
