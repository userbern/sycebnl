import 'package:flutter/material.dart';
import 'package:sycebnl_accounting/models/entite.dart';
import 'package:sycebnl_accounting/models/user_session.dart';
import 'package:sycebnl_accounting/services/auth_service.dart';

class EntiteFormPage extends StatefulWidget {
  final UserSession userSession;
  final Entite? entite;
  final Function(Entite) onSave;

  const EntiteFormPage({
    super.key,
    required this.userSession,
    this.entite,
    required this.onSave,
  });

  @override
  State<EntiteFormPage> createState() => _EntiteFormPageState();
}

class _EntiteFormPageState extends State<EntiteFormPage> {
  late TextEditingController _denominationSocialeController;
  late TextEditingController _domaineInterventionController;
  late TextEditingController _paysController;
  late TextEditingController _fixeFaxController;
  late TextEditingController _numeroFiscalController;
  late TextEditingController _sigleUsuelController;
  late TextEditingController _villeController;
  late TextEditingController _regionController;
  late TextEditingController _emailController;
  late TextEditingController _numeroCnssController;
  late TextEditingController _formeJuridiqueController;
  late TextEditingController _quartierController;
  late TextEditingController _telephoneController;
  late TextEditingController _numeroRecepisseController;
  late TextEditingController _informationsComplementairesController;

  OngType? _selectedOngType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  /// Initialiser les contrôleurs avec les données de l'entité si édition
  void _initializeControllers() {
    final entite = widget.entite;

    _denominationSocialeController = TextEditingController(
      text: entite?.denominationSociale ?? '',
    );
    _domaineInterventionController = TextEditingController(
      text: entite?.domaineIntervention ?? '',
    );
    _paysController = TextEditingController(text: entite?.pays ?? '');
    _fixeFaxController = TextEditingController(text: entite?.fixeFax ?? '');
    _numeroFiscalController = TextEditingController(
      text: entite?.numeroFiscal ?? '',
    );
    _sigleUsuelController = TextEditingController(
      text: entite?.sigleUsuel ?? '',
    );
    _villeController = TextEditingController(text: entite?.ville ?? '');
    _regionController = TextEditingController(text: entite?.region ?? '');
    _emailController = TextEditingController(text: entite?.email ?? '');
    _numeroCnssController = TextEditingController(
      text: entite?.numeroCnss ?? '',
    );
    _formeJuridiqueController = TextEditingController(
      text: entite?.formeJuridique ?? '',
    );
    _quartierController = TextEditingController(text: entite?.quartier ?? '');
    _telephoneController = TextEditingController(text: entite?.telephone ?? '');
    _numeroRecepisseController = TextEditingController(
      text: entite?.numeroRecepisse ?? '',
    );
    _informationsComplementairesController = TextEditingController(
      text: entite?.informationsComplementaires ?? '',
    );

    _selectedOngType = entite?.ongType;
  }

  @override
  void dispose() {
    _denominationSocialeController.dispose();
    _domaineInterventionController.dispose();
    _paysController.dispose();
    _fixeFaxController.dispose();
    _numeroFiscalController.dispose();
    _sigleUsuelController.dispose();
    _villeController.dispose();
    _regionController.dispose();
    _emailController.dispose();
    _numeroCnssController.dispose();
    _formeJuridiqueController.dispose();
    _quartierController.dispose();
    _telephoneController.dispose();
    _numeroRecepisseController.dispose();
    _informationsComplementairesController.dispose();
    super.dispose();
  }

  /// Sauvegarder l'entité
  Future<void> _saveEntite() async {
    // Validation
    if (_denominationSocialeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La dénomination sociale est obligatoire'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.entite == null) {
        // Créer une nouvelle entité
        final newEntite = await AuthService.createEntite(
          denominationSociale: _denominationSocialeController.text,
          domaineIntervention:
              _domaineInterventionController.text.isEmpty
                  ? null
                  : _domaineInterventionController.text,
          pays: _paysController.text.isEmpty ? null : _paysController.text,
          fixeFax:
              _fixeFaxController.text.isEmpty ? null : _fixeFaxController.text,
          numeroFiscal:
              _numeroFiscalController.text.isEmpty
                  ? null
                  : _numeroFiscalController.text,
          sigleUsuel:
              _sigleUsuelController.text.isEmpty
                  ? null
                  : _sigleUsuelController.text,
          ville: _villeController.text.isEmpty ? null : _villeController.text,
          region:
              _regionController.text.isEmpty ? null : _regionController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          numeroCnss:
              _numeroCnssController.text.isEmpty
                  ? null
                  : _numeroCnssController.text,
          formeJuridique:
              _formeJuridiqueController.text.isEmpty
                  ? null
                  : _formeJuridiqueController.text,
          quartier:
              _quartierController.text.isEmpty
                  ? null
                  : _quartierController.text,
          telephone:
              _telephoneController.text.isEmpty
                  ? null
                  : _telephoneController.text,
          numeroRecepisse:
              _numeroRecepisseController.text.isEmpty
                  ? null
                  : _numeroRecepisseController.text,
          informationsComplementaires:
              _informationsComplementairesController.text.isEmpty
                  ? null
                  : _informationsComplementairesController.text,
          ongType: _selectedOngType?.toDbString(),
        );

        if (!mounted) return;

        widget.onSave(newEntite);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entité créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        // Modifier une entité existante
        final updatedEntite = await AuthService.updateEntite(
          id: widget.entite!.id,
          denominationSociale: _denominationSocialeController.text,
          domaineIntervention:
              _domaineInterventionController.text.isEmpty
                  ? null
                  : _domaineInterventionController.text,
          pays: _paysController.text.isEmpty ? null : _paysController.text,
          fixeFax:
              _fixeFaxController.text.isEmpty ? null : _fixeFaxController.text,
          numeroFiscal:
              _numeroFiscalController.text.isEmpty
                  ? null
                  : _numeroFiscalController.text,
          sigleUsuel:
              _sigleUsuelController.text.isEmpty
                  ? null
                  : _sigleUsuelController.text,
          ville: _villeController.text.isEmpty ? null : _villeController.text,
          region:
              _regionController.text.isEmpty ? null : _regionController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          numeroCnss:
              _numeroCnssController.text.isEmpty
                  ? null
                  : _numeroCnssController.text,
          formeJuridique:
              _formeJuridiqueController.text.isEmpty
                  ? null
                  : _formeJuridiqueController.text,
          quartier:
              _quartierController.text.isEmpty
                  ? null
                  : _quartierController.text,
          telephone:
              _telephoneController.text.isEmpty
                  ? null
                  : _telephoneController.text,
          numeroRecepisse:
              _numeroRecepisseController.text.isEmpty
                  ? null
                  : _numeroRecepisseController.text,
          informationsComplementaires:
              _informationsComplementairesController.text.isEmpty
                  ? null
                  : _informationsComplementairesController.text,
          ongType: _selectedOngType?.toDbString(),
        );

        if (!mounted) return;

        widget.onSave(updatedEntite);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entité modifiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isEditing = widget.entite != null;

    // Déterminer la largeur max du contenu pour desktop
    final maxContentWidth = screenWidth > 900 ? 700.0 : double.infinity;
    final horizontalPadding =
        screenWidth > 900 ? (screenWidth - maxContentWidth) / 2 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier une entité' : 'Créer une entité'),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
      ),
      body:
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: screenHeight * 0.02,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📌 Dénomination sociale
                      _buildTextField(
                        controller: _denominationSocialeController,
                        label: 'Dénomination sociale *',
                        icon: Icons.business,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📌 Domaine d'intervention
                      _buildTextField(
                        controller: _domaineInterventionController,
                        label: 'Domaine d\'intervention',
                        icon: Icons.category,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📌 Sigle usuel
                      _buildTextField(
                        controller: _sigleUsuelController,
                        label: 'Sigle usuel',
                        icon: Icons.short_text,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📌 Type ONG (Liste déroulante)
                      _buildOngTypeDropdown(screenHeight),
                      SizedBox(height: screenHeight * 0.015),

                      // 📍 Localisation
                      _buildSectionHeader('Localisation', screenHeight),
                      _buildTextField(
                        controller: _paysController,
                        label: 'Pays',
                        icon: Icons.public,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _villeController,
                        label: 'Ville',
                        icon: Icons.location_city,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _regionController,
                        label: 'Région',
                        icon: Icons.map,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _quartierController,
                        label: 'Quartier',
                        icon: Icons.pin_drop,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📞 Contacts
                      _buildSectionHeader('Contacts', screenHeight),
                      _buildTextField(
                        controller: _telephoneController,
                        label: 'Téléphone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _fixeFaxController,
                        label: 'Téléphone fixe / Fax',
                        icon: Icons.print,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📋 Documents et numéros
                      _buildSectionHeader('Documents et numéros', screenHeight),
                      _buildTextField(
                        controller: _numeroFiscalController,
                        label: 'Numéro fiscal',
                        icon: Icons.description,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _numeroCnssController,
                        label: 'N° CNSS',
                        icon: Icons.badge,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildTextField(
                        controller: _numeroRecepisseController,
                        label: 'N° Récépissé',
                        icon: Icons.receipt,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📝 Informations juridiques
                      _buildSectionHeader(
                        'Informations juridiques',
                        screenHeight,
                      ),
                      _buildTextField(
                        controller: _formeJuridiqueController,
                        label: 'Forme juridique',
                        icon: Icons.gavel,
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // 📝 Informations complémentaires
                      _buildTextField(
                        controller: _informationsComplementairesController,
                        label: 'Informations complémentaires',
                        icon: Icons.notes,
                        maxLines: 4,
                      ),
                      SizedBox(height: screenHeight * 0.03),

                      // Boutons d'action
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Annuler'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenHeight * 0.02),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveEntite,
                              icon: const Icon(Icons.save),
                              label: Text(isEditing ? 'Modifier' : 'Créer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  /// Construire un champ de texte
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

  /// Construire le dropdown pour le type ONG
  Widget _buildOngTypeDropdown(double screenHeight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<OngType>(
        value: _selectedOngType,
        hint: const Text('Sélectionner un type ONG'),
        isExpanded: true,
        underline: const SizedBox(),
        items:
            OngType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
                  child: Text(type.toLabel()),
                ),
              );
            }).toList(),
        onChanged: (value) {
          if (!mounted) return;
          setState(() {
            _selectedOngType = value;
          });
        },
      ),
    );
  }

  /// Construire un en-tête de section
  Widget _buildSectionHeader(String title, double screenHeight) {
    return Padding(
      padding: EdgeInsets.only(top: screenHeight * 0.02),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenHeight * 0.022,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }
}
