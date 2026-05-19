import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sycebnl_accounting/models/entite.dart';
import 'package:sycebnl_accounting/models/user_session.dart';
import 'package:sycebnl_accounting/services/auth_service.dart';

class EntiteListPage extends StatefulWidget {
  final UserSession userSession;

  const EntiteListPage({super.key, required this.userSession});

  @override
  State<EntiteListPage> createState() => _EntiteListPageState();
}

class _EntiteListPageState extends State<EntiteListPage> {
  late List<Entite> _entites = [];
  late List<Entite> _filteredEntites = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadEntites();
    _searchController.addListener(_filterEntites);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Charger toutes les entités
  Future<void> _loadEntites() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final entites = await AuthService.getEntites();

      if (!mounted) return;

      setState(() {
        _entites = entites;
        _filteredEntites = entites;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtrer les entités selon la recherche
  void _filterEntites() {
    final query = _searchController.text.toLowerCase();

    if (!mounted) return;

    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEntites = _entites;
      } else {
        _filteredEntites =
            _entites
                .where(
                  (entite) =>
                      entite.denominationSociale.toLowerCase().contains(
                        query,
                      ) ||
                      (entite.sigleUsuel?.toLowerCase().contains(query) ??
                          false) ||
                      (entite.email?.toLowerCase().contains(query) ?? false),
                )
                .toList();
      }
    });
  }

  /// Ouvrir le formulaire pour créer une nouvelle entité (CTRL+N)
  void _openCreateForm() {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seuls les administrateurs peuvent créer des entités'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showEntiteDialog(null);
  }

  /// Ouvrir le formulaire pour modifier une entité
  void _openEditForm(Entite entite) {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seuls les administrateurs peuvent modifier les entités',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showEntiteDialog(entite);
  }

  /// Afficher le dialogue de création/modification d'entité
  void _showEntiteDialog(Entite? entite) {
    final formKey = GlobalKey<FormState>();
    final denominationController = TextEditingController(
      text: entite?.denominationSociale ?? '',
    );
    final sigleController = TextEditingController(
      text: entite?.sigleUsuel ?? '',
    );
    final domaineController = TextEditingController(
      text: entite?.domaineIntervention ?? '',
    );
    final formeJuridiqueController = TextEditingController(
      text: entite?.formeJuridique ?? '',
    );
    String? selectedOngType = entite?.ongType?.name;
    final paysController = TextEditingController(text: entite?.pays ?? '');
    final regionController = TextEditingController(text: entite?.region ?? '');
    final villeController = TextEditingController(text: entite?.ville ?? '');
    final quartierController = TextEditingController(
      text: entite?.quartier ?? '',
    );
    final emailController = TextEditingController(text: entite?.email ?? '');
    final telephoneController = TextEditingController(
      text: entite?.telephone ?? '',
    );
    final fixeFaxController = TextEditingController(
      text: entite?.fixeFax ?? '',
    );
    final numeroFiscalController = TextEditingController(
      text: entite?.numeroFiscal ?? '',
    );
    final numeroCnssController = TextEditingController(
      text: entite?.numeroCnss ?? '',
    );
    final numeroRecepisseController = TextEditingController(
      text: entite?.numeroRecepisse ?? '',
    );
    final currencyController = TextEditingController(
      text: entite?.currency ?? 'XOF',
    );
    final infosController = TextEditingController(
      text: entite?.informationsComplementaires ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                entite == null ? 'Nouvelle Entité' : 'Modifier Entité',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identification de l\'entité',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Section Identification
                        _buildSectionHeader('Identification'),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                controller: denominationController,
                                label: 'Dénomination sociale *',
                                icon: Icons.business,
                                isRequired: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Champ requis';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: sigleController,
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
                                controller: domaineController,
                                label: 'Domaine d\'intervention',
                                icon: Icons.category,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedOngType,
                                decoration: InputDecoration(
                                  labelText: 'Forme juridique',
                                  prefixIcon: const Icon(Icons.account_balance),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
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
                                items:
                                    OngType.values.map((type) {
                                      return DropdownMenuItem(
                                        value: type.name,
                                        child: Text(type.toLabel()),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedOngType = value;
                                  });
                                },
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
                                controller: paysController,
                                label: 'Pays',
                                icon: Icons.public,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: villeController,
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
                                controller: regionController,
                                label: 'Région',
                                icon: Icons.map,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: quartierController,
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
                                controller: telephoneController,
                                label: 'Téléphone',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: fixeFaxController,
                                label: 'Téléphone fixe / Fax',
                                icon: Icons.print,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        // Section Références de reconnaissance officielle
                        _buildSectionHeader(
                          'Référence de reconnaissance fiscale',
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: numeroFiscalController,
                                label:
                                    'N° d\'identification fiscal (NIF/IFU/NCC)',
                                icon: Icons.description,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: numeroRecepisseController,
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
                                controller: numeroCnssController,
                                label: 'N° CNSS',
                                icon: Icons.badge,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: formeJuridiqueController,
                                label: 'Autre référence',
                                icon: Icons.info_outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Section Monnaie
                        _buildSectionHeader(
                          'Monnaie et informations complémentaires',
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: currencyController,
                                label: 'Devise',
                                icon: Icons.account_balance_wallet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: infosController,
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      if (entite == null) {
                        // Créer
                        await AuthService.createEntite(
                          denominationSociale: denominationController.text,
                          sigleUsuel:
                              sigleController.text.isNotEmpty
                                  ? sigleController.text
                                  : null,
                          domaineIntervention:
                              domaineController.text.isNotEmpty
                                  ? domaineController.text
                                  : null,
                          formeJuridique:
                              formeJuridiqueController.text.isNotEmpty
                                  ? formeJuridiqueController.text
                                  : null,
                          ongType: selectedOngType,
                          pays:
                              paysController.text.isNotEmpty
                                  ? paysController.text
                                  : null,
                          region:
                              regionController.text.isNotEmpty
                                  ? regionController.text
                                  : null,
                          ville:
                              villeController.text.isNotEmpty
                                  ? villeController.text
                                  : null,
                          quartier:
                              quartierController.text.isNotEmpty
                                  ? quartierController.text
                                  : null,
                          email:
                              emailController.text.isNotEmpty
                                  ? emailController.text
                                  : null,
                          telephone:
                              telephoneController.text.isNotEmpty
                                  ? telephoneController.text
                                  : null,
                          fixeFax:
                              fixeFaxController.text.isNotEmpty
                                  ? fixeFaxController.text
                                  : null,
                          numeroFiscal:
                              numeroFiscalController.text.isNotEmpty
                                  ? numeroFiscalController.text
                                  : null,
                          numeroCnss:
                              numeroCnssController.text.isNotEmpty
                                  ? numeroCnssController.text
                                  : null,
                          numeroRecepisse:
                              numeroRecepisseController.text.isNotEmpty
                                  ? numeroRecepisseController.text
                                  : null,
                          informationsComplementaires:
                              infosController.text.isNotEmpty
                                  ? infosController.text
                                  : null,
                          currency: currencyController.text,
                        );
                      } else {
                        // Modifier
                        await AuthService.updateEntite(
                          id: int.parse(entite.id),
                          denominationSociale: denominationController.text,
                          sigleUsuel:
                              sigleController.text.isNotEmpty
                                  ? sigleController.text
                                  : null,
                          domaineIntervention:
                              domaineController.text.isNotEmpty
                                  ? domaineController.text
                                  : null,
                          formeJuridique:
                              formeJuridiqueController.text.isNotEmpty
                                  ? formeJuridiqueController.text
                                  : null,
                          ongType: selectedOngType,
                          pays:
                              paysController.text.isNotEmpty
                                  ? paysController.text
                                  : null,
                          region:
                              regionController.text.isNotEmpty
                                  ? regionController.text
                                  : null,
                          ville:
                              villeController.text.isNotEmpty
                                  ? villeController.text
                                  : null,
                          quartier:
                              quartierController.text.isNotEmpty
                                  ? quartierController.text
                                  : null,
                          email:
                              emailController.text.isNotEmpty
                                  ? emailController.text
                                  : null,
                          telephone:
                              telephoneController.text.isNotEmpty
                                  ? telephoneController.text
                                  : null,
                          fixeFax:
                              fixeFaxController.text.isNotEmpty
                                  ? fixeFaxController.text
                                  : null,
                          numeroFiscal:
                              numeroFiscalController.text.isNotEmpty
                                  ? numeroFiscalController.text
                                  : null,
                          numeroCnss:
                              numeroCnssController.text.isNotEmpty
                                  ? numeroCnssController.text
                                  : null,
                          numeroRecepisse:
                              numeroRecepisseController.text.isNotEmpty
                                  ? numeroRecepisseController.text
                                  : null,
                          informationsComplementaires:
                              infosController.text.isNotEmpty
                                  ? infosController.text
                                  : null,
                          currency: currencyController.text,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            entite == null
                                ? 'Entité créée avec succès'
                                : 'Entité modifiée avec succès',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadEntites();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(entite == null ? 'Créer' : 'Modifier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Supprimer une entité
  Future<void> _deleteEntite(String entiteId) async {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seuls les administrateurs peuvent supprimer les entités',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher une confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette entité ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    try {
      await AuthService.deleteEntite(int.parse(entiteId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entité supprimée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _loadEntites();
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            widget.userSession.isAdmin) {
          _openCreateForm();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identification'),
          backgroundColor: Colors.blue.shade400,
          elevation: 0,
        ),
        floatingActionButton:
            widget.userSession.isAdmin
                ? FloatingActionButton(
                  onPressed: _openCreateForm,
                  backgroundColor: Colors.blue.shade400,
                  tooltip: 'Créer une entité (Ctrl+N)',
                  child: const Icon(Icons.add),
                )
                : null,
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // 🔍 Barre de recherche
                    Container(
                      padding: EdgeInsets.all(screenHeight * 0.02),
                      color: Colors.grey.shade100,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Rechercher par dénomination, sigle ou email...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenHeight * 0.02,
                            vertical: screenHeight * 0.015,
                          ),
                        ),
                      ),
                    ),
                    // 📋 Liste des entités
                    Expanded(
                      child:
                          _filteredEntites.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.business,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    SizedBox(height: screenHeight * 0.02),
                                    Text(
                                      'Aucune entité trouvée',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.022,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: EdgeInsets.all(screenHeight * 0.02),
                                itemCount: _filteredEntites.length,
                                itemBuilder: (context, index) {
                                  final entite = _filteredEntites[index];

                                  return Card(
                                    margin: EdgeInsets.only(
                                      bottom: screenHeight * 0.015,
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.all(
                                        screenHeight * 0.015,
                                      ),
                                      title: Text(
                                        entite.denominationSociale,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: screenHeight * 0.02,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: screenHeight * 0.005,
                                          ),
                                          if (entite.sigleUsuel != null)
                                            Text(
                                              '📍 ${entite.sigleUsuel}',
                                              style: TextStyle(
                                                fontSize: screenHeight * 0.015,
                                              ),
                                            ),
                                          if (entite.email != null)
                                            Text(
                                              '📧 ${entite.email}',
                                              style: TextStyle(
                                                fontSize: screenHeight * 0.015,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          if (entite.ongType != null)
                                            Text(
                                              '🏢 ${entite.ongType!.toLabel()}',
                                              style: TextStyle(
                                                fontSize: screenHeight * 0.015,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing:
                                          widget.userSession.isAdmin
                                              ? PopupMenuButton(
                                                itemBuilder:
                                                    (context) => [
                                                      PopupMenuItem(
                                                        onTap: () {
                                                          Future.delayed(
                                                            const Duration(
                                                              milliseconds: 300,
                                                            ),
                                                            () => _openEditForm(
                                                              entite,
                                                            ),
                                                          );
                                                        },
                                                        child: const Row(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 10),
                                                            Text('Modifier'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        onTap: () {
                                                          Future.delayed(
                                                            const Duration(
                                                              milliseconds: 300,
                                                            ),
                                                            () => _deleteEntite(
                                                              entite.id,
                                                            ),
                                                          );
                                                        },
                                                        child: const Row(
                                                          children: [
                                                            Icon(
                                                              Icons.delete,
                                                              size: 18,
                                                              color: Colors.red,
                                                            ),
                                                            SizedBox(width: 10),
                                                            Text(
                                                              'Supprimer',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                              )
                                              : null,
                                      onTap: () {
                                        // Afficher les détails en lecture seule
                                      },
                                    ),
                                  );
                                },
                              ),
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
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: validator,
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
