import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/form_enter_shortcut.dart';

class EntiteIdentificationPage extends StatefulWidget {
  final VoidCallback? onDataUpdated;

  const EntiteIdentificationPage({super.key, this.onDataUpdated});

  @override
  State<EntiteIdentificationPage> createState() =>
      _EntiteIdentificationPageState();
}

class _EntiteIdentificationPageState extends State<EntiteIdentificationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers pour tous les champs
  final _denominationController = TextEditingController();
  final _sigleController = TextEditingController();
  final _domaineController = TextEditingController();
  final _formeJuridiqueController = TextEditingController();
  final _ongTypeController = TextEditingController();
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
  final _infosComplementairesController = TextEditingController();
  final _currencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntiteData();
  }

  @override
  void dispose() {
    _denominationController.dispose();
    _sigleController.dispose();
    _domaineController.dispose();
    _formeJuridiqueController.dispose();
    _ongTypeController.dispose();
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
    _infosComplementairesController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadEntiteData() async {
    setState(() => _isLoading = true);

    try {
      final entite = await DatabaseService.getEntite();
      if (entite != null && mounted) {
        _denominationController.text = entite['denomination_sociale'] ?? '';
        _sigleController.text = entite['sigle_usuel'] ?? '';
        _domaineController.text = entite['domaine_intervention'] ?? '';
        _formeJuridiqueController.text = entite['forme_juridique'] ?? '';
        _ongTypeController.text = entite['ong_type'] ?? '';
        _paysController.text = entite['pays'] ?? '';
        _regionController.text = entite['region'] ?? '';
        _villeController.text = entite['ville'] ?? '';
        _quartierController.text = entite['quartier'] ?? '';
        _emailController.text = entite['email'] ?? '';
        _telephoneController.text = entite['telephone'] ?? '';
        _fixeFaxController.text = entite['fixe_fax'] ?? '';
        _numeroFiscalController.text = entite['numero_fiscal'] ?? '';
        _numeroCnssController.text = entite['numero_cnss'] ?? '';
        _numeroRecepisseController.text = entite['numero_recepisse'] ?? '';
        _infosComplementairesController.text =
            entite['informations_complementaires'] ?? '';
        _currencyController.text = entite['currency'] ?? 'XOF';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveEntiteData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await DatabaseService.updateEntite({
        'denomination_sociale': _denominationController.text,
        'sigle_usuel': _sigleController.text,
        'domaine_intervention': _domaineController.text,
        'forme_juridique': _formeJuridiqueController.text,
        'pays': _paysController.text,
        'region': _regionController.text,
        'ville': _villeController.text,
        'quartier': _quartierController.text,
        'email': _emailController.text,
        'telephone': _telephoneController.text,
        'fixe_fax': _fixeFaxController.text,
        'numero_fiscal': _numeroFiscalController.text,
        'numero_cnss': _numeroCnssController.text,
        'numero_recepisse': _numeroRecepisseController.text,
        'informations_complementaires': _infosComplementairesController.text,
        'currency': _currencyController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations enregistrées avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        // Appeler le callback pour mettre à jour la HomePage
        widget.onDataUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FormWithEnterShortcut(
        formKey: _formKey,
        onSubmit: _saveEntiteData,
        enabled: !_isSaving,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Icon(Icons.business, size: 32, color: Colors.blue.shade400),
                  const SizedBox(width: 12),
                  const Text(
                    'Identification de l\'entité',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Modifiez les informations de votre entité',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Informations générales
              _buildSection('Informations générales', Icons.info_outline, [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _denominationController,
                        label: 'Dénomination sociale *',
                        icon: Icons.business_center,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _sigleController,
                        label: 'Sigle usuel',
                        icon: Icons.short_text,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _domaineController,
                        label: 'Domaine d\'intervention',
                        icon: Icons.category,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _formeJuridiqueController,
                        label: 'Forme juridique',
                        icon: Icons.account_balance,
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 24),

              // Localisation
              _buildSection('Localisation', Icons.location_on, [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _paysController,
                        label: 'Pays',
                        icon: Icons.flag,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _regionController,
                        label: 'Région',
                        icon: Icons.map,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _villeController,
                        label: 'Ville',
                        icon: Icons.location_city,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _quartierController,
                        label: 'Quartier',
                        icon: Icons.home,
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 24),

              // Contact
              _buildSection('Coordonnées', Icons.contact_phone, [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _telephoneController,
                        label: 'Téléphone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                _buildTextField(
                  controller: _fixeFaxController,
                  label: 'Fixe / Fax',
                  icon: Icons.phone_in_talk,
                  keyboardType: TextInputType.phone,
                ),
              ]),

              const SizedBox(height: 24),

              // Informations administratives
              _buildSection(
                'Monnaie et informations complémentaires',
                Icons.description,
                [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _numeroFiscalController,
                          label: 'Numéro fiscal',
                          icon: Icons.receipt_long,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _numeroCnssController,
                          label: 'Numéro CNSS',
                          icon: Icons.badge,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _numeroRecepisseController,
                    label: 'Numéro de récépissé',
                    icon: Icons.document_scanner,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Autres informations
              _buildSection(
                'Monnaie et informations complémentaires',
                Icons.more_horiz,
                [
                  _buildTextField(
                    controller: _currencyController,
                    label: 'Monnaie',
                    icon: Icons.attach_money,
                  ),
                  _buildTextField(
                    controller: _infosComplementairesController,
                    label: 'Informations complémentaires',
                    icon: Icons.notes,
                    maxLines: 4,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Bouton Enregistrer
              Center(
                child: SizedBox(
                  width: 300,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveEntiteData,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Enregistrement...' : 'Enregistrer',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade400, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade400),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator:
            required
                ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est requis';
                  }
                  return null;
                }
                : null,
      ),
    );
  }
}
