import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class ListeProjetsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeProjetsPage({super.key, this.showAppBar = true, this.userSession});

  @override
  State<ListeProjetsPage> createState() => _ListeProjetsPageState();
}

class _ListeProjetsPageState extends State<ListeProjetsPage> {
  List<Map<String, dynamic>> _projets = [];
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'code';
  String _filterStatus = 'actifs';
  late FocusNode _focusNode;

  bool get _canCreate => _hasPermission('creation');
  bool get _canUpdate => _hasPermission('modification');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'liste_projets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      if (mounted) _focusNode.requestFocus();
    });
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final projets = await AuthService.getProjetsWithBailleur();
      final bailleurs = await AuthService.getBailleurs();

      if (!mounted) return;
      setState(() {
        _projets = projets;
        _bailleurs =
            bailleurs
                .map(
                  (b) => {
                    'id': b.id,
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredProjets {
    var filtered = _projets;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((projet) {
            return (projet['code'] ?? '').toString().toLowerCase().contains(
                  query,
                ) ||
                (projet['designation'] ?? '').toString().toLowerCase().contains(
                  query,
                );
          }).toList();
    }

    if (_filterStatus == 'actifs') {
      filtered = filtered.where((p) => p['deleted_at'] == null).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((p) => p['deleted_at'] != null).toList();
    }

    if (_sortBy == 'code') {
      filtered.sort(
        (a, b) => (a['code'] ?? '').toString().compareTo(
          (b['code'] ?? '').toString(),
        ),
      );
    } else if (_sortBy == 'designation') {
      filtered.sort(
        (a, b) => (a['designation'] ?? '').toString().compareTo(
          (b['designation'] ?? '').toString(),
        ),
      );
    }

    return filtered;
  }

  bool _isActive(Map<String, dynamic> projet) {
    return projet['deleted_at'] == null;
  }

  String _getBailleursString(Map<String, dynamic> projet) {
    final bailleurs = projet['bailleurs'];
    if (bailleurs == null || bailleurs.isEmpty) return 'Aucun';
    return bailleurs.toString();
  }

  Future<void> _deleteProjet(Map<String, dynamic> projet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le projet "${projet['code']}" ?',
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

    if (confirm == true) {
      try {
        await AuthService.deleteProjet(int.parse(projet['id'].toString()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projet supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showProjetDialog(Map<String, dynamic>? projet) {
    showDialog(
      context: context,
      builder:
          (context) => _ProjetDialog(
            projet: projet,
            bailleurs: _bailleurs,
            onSave: (_) {
              _loadData();
              Navigator.pop(context);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showProjetDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Projets'),
                  backgroundColor: Colors.indigo,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                )
                : null,
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() => _searchQuery = value);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Rechercher un projet...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (_canCreate)
                                ElevatedButton.icon(
                                  onPressed: () => _showProjetDialog(null),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Nouveau (Ctrl+N)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _sortBy,
                                  decoration: InputDecoration(
                                    labelText: 'Trier par',
                                    prefixIcon: const Icon(Icons.sort),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'code',
                                      child: Text('Code'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'designation',
                                      child: Text('Désignation'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _sortBy = value ?? 'code');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Statut',
                                    prefixIcon: const Icon(Icons.filter_alt),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'actifs',
                                      child: Text('Actifs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactifs',
                                      child: Text('Inactifs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'tous',
                                      child: Text('Tous'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStatus = value ?? 'actifs',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _sortBy = 'code';
                                    _filterStatus = 'actifs';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Réinitialiser'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _filteredProjets.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'Aucun projet'
                                          : 'Aucun projet trouvé',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : SingleChildScrollView(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 2500,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              Colors.indigo.shade700,
                                            ),
                                        headingTextStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 72,
                                        columnSpacing: 48,
                                        horizontalMargin: 32,
                                        columns: const [
                                          DataColumn(label: Text('Code')),
                                          DataColumn(
                                            label: Text('Désignation'),
                                          ),
                                          DataColumn(label: Text('Bailleurs')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows:
                                            _filteredProjets.map((projet) {
                                              return DataRow(
                                                color: WidgetStateProperty.all(
                                                  _isActive(projet)
                                                      ? Colors.white
                                                      : Colors.grey.shade50,
                                                ),
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      projet['code'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            _isActive(projet)
                                                                ? Colors.black87
                                                                : Colors
                                                                    .grey
                                                                    .shade500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      projet['designation'] ??
                                                          '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color:
                                                            _isActive(projet)
                                                                ? Colors.black87
                                                                : Colors
                                                                    .grey
                                                                    .shade500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      _getBailleursString(
                                                        projet,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            _isActive(projet)
                                                                ? Colors.black87
                                                                : Colors
                                                                    .grey
                                                                    .shade500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      children: [
                                                        if (_canUpdate)
                                                          Tooltip(
                                                            message: 'Modifier',
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.edit,
                                                                color:
                                                                    Colors
                                                                        .indigo
                                                                        .shade700,
                                                                size: 20,
                                                              ),
                                                              onPressed: () {
                                                                _showProjetDialog(
                                                                  projet,
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        if (_canDelete)
                                                          Tooltip(
                                                            message:
                                                                'Supprimer',
                                                            child: IconButton(
                                                              icon: const Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red,
                                                                size: 20,
                                                              ),
                                                              onPressed: () {
                                                                _deleteProjet(
                                                                  projet,
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _ProjetDialog extends StatefulWidget {
  final Map<String, dynamic>? projet;
  final List<Map<String, dynamic>> bailleurs;
  final Function(Map<String, dynamic>) onSave;

  const _ProjetDialog({
    required this.projet,
    required this.bailleurs,
    required this.onSave,
  });

  @override
  State<_ProjetDialog> createState() => _ProjetDialogState();
}

class _ProjetDialogState extends State<_ProjetDialog> {
  late TextEditingController _codeController;
  late TextEditingController _designationController;
  late TextEditingController _dateDebutController;
  late TextEditingController _dateFinController;
  List<Map<String, dynamic>> _availableBailleurs = [];
  List<Map<String, dynamic>> _selectedBailleurs = [];
  bool _isSaving = false;
  bool _loadingBailleurs = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.projet?['code'] ?? '');
    _designationController = TextEditingController(
      text: widget.projet?['designation'] ?? '',
    );
    _dateDebutController = TextEditingController(
      text: widget.projet?['date_debut'] ?? '',
    );
    _dateFinController = TextEditingController(
      text: widget.projet?['date_fin'] ?? '',
    );

    _initializeBailleurs();
  }

  Future<void> _initializeBailleurs() async {
    try {
      // Charger la liste des bailleurs disponibles
      final availableList =
          widget.bailleurs.isNotEmpty
              ? widget.bailleurs
              : (await AuthService.getBailleurs())
                  .map(
                    (b) => {
                      'id': b.id,
                      'sigle': b.sigle,
                      'designation': b.designation,
                    },
                  )
                  .toList();

      setState(() {
        _availableBailleurs = availableList;
        _loadingBailleurs = false;
      });

      // Si on édite un projet, charger ses bailleurs
      if (widget.projet != null) {
        await _loadProjectBailleurs();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des bailleurs: $e');
      setState(() => _loadingBailleurs = false);
    }
  }

  Future<void> _loadProjectBailleurs() async {
    try {
      if (widget.projet != null) {
        final bailleurs = await AuthService.getBailleursForProjet(
          widget.projet!['id'] as int,
        );
        setState(() {
          _selectedBailleurs = List<Map<String, dynamic>>.from(bailleurs);
        });
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _designationController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          controller.text.isNotEmpty
              ? DateTime.parse(controller.text)
              : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () =>
            controller.text =
                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBailleurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un bailleur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.projet == null) {
        await AuthService.createProjet(
          code: _codeController.text,
          designation: _designationController.text,
          bailleurIds: _selectedBailleurs.map((b) => b['id'] as int).toList(),
          dateDebut:
              _dateDebutController.text.isNotEmpty
                  ? DateTime.parse(_dateDebutController.text)
                  : null,
          dateFin:
              _dateFinController.text.isNotEmpty
                  ? DateTime.parse(_dateFinController.text)
                  : null,
        );
      } else {
        await AuthService.updateProjet(
          id: widget.projet!['id'] as int,
          code: _codeController.text,
          designation: _designationController.text,
          bailleurIds: _selectedBailleurs.map((b) => b['id'] as int).toList(),
          dateDebut:
              _dateDebutController.text.isNotEmpty
                  ? DateTime.parse(_dateDebutController.text)
                  : null,
          dateFin:
              _dateFinController.text.isNotEmpty
                  ? DateTime.parse(_dateFinController.text)
                  : null,
        );
      }
      if (!mounted) return;
      widget.onSave({});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.projet == null ? 'Nouveau projet' : 'Modifier le projet',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true ? 'Le code est requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _designationController,
                  decoration: InputDecoration(
                    labelText: 'Désignation *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'La désignation est requise'
                              : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateDebutController,
                        decoration: InputDecoration(
                          labelText: 'Date début *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(_dateDebutController),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true
                                    ? 'La date début est requise'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dateFinController,
                        decoration: InputDecoration(
                          labelText: 'Date fin *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(_dateFinController),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true
                                    ? 'La date fin est requise'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bailleurs *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _loadingBailleurs
                    ? const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    )
                    : _availableBailleurs.isEmpty
                    ? Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Aucun bailleur disponible',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Champ d'autocomplete
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _availableBailleurs
                                  .where(
                                    (b) =>
                                        !_selectedBailleurs.any(
                                          (sb) => sb['id'] == b['id'],
                                        ),
                                  )
                                  .toList();
                            }
                            final query = textEditingValue.text.toLowerCase();
                            return _availableBailleurs
                                .where(
                                  (b) =>
                                      !_selectedBailleurs.any(
                                        (sb) => sb['id'] == b['id'],
                                      ) &&
                                      ((b['sigle'] ?? '')
                                              .toString()
                                              .toLowerCase()
                                              .contains(query) ||
                                          (b['designation'] ?? '')
                                              .toString()
                                              .toLowerCase()
                                              .contains(query)),
                                )
                                .toList();
                          },
                          onSelected: (Map<String, dynamic> selection) {
                            setState(() {
                              final newList = List<Map<String, dynamic>>.from(
                                _selectedBailleurs,
                              );
                              newList.add(selection);
                              _selectedBailleurs = newList;
                            });
                          },
                          displayStringForOption:
                              (option) =>
                                  '${option['sigle']} - ${option['designation']}',
                          fieldViewBuilder: (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Chercher et ajouter un bailleur...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    textEditingController.text.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            textEditingController.clear();
                                            focusNode.requestFocus();
                                          },
                                        )
                                        : null,
                              ),
                            );
                          },
                          optionsViewBuilder: (
                            BuildContext context,
                            AutocompleteOnSelected<Map<String, dynamic>>
                            onSelected,
                            Iterable<Map<String, dynamic>> options,
                          ) {
                            return Material(
                              elevation: 4,
                              child: SizedBox(
                                width: 400,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (
                                    BuildContext context,
                                    int index,
                                  ) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option['sigle'] ?? ''),
                                      subtitle: Text(
                                        option['designation'] ?? '',
                                      ),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Afficher les bailleurs sélectionnés comme chips
                        if (_selectedBailleurs.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _selectedBailleurs.map((bailleur) {
                                  return Chip(
                                    label: Text(
                                      '${bailleur['sigle']} - ${bailleur['designation']}',
                                    ),
                                    deleteIcon: const Icon(Icons.close),
                                    onDeleted: () {
                                      setState(() {
                                        final newList =
                                            List<Map<String, dynamic>>.from(
                                              _selectedBailleurs,
                                            );
                                        newList.removeWhere(
                                          (b) => b['id'] == bailleur['id'],
                                        );
                                        _selectedBailleurs = newList;
                                      });
                                    },
                                    backgroundColor: Colors.indigo.withValues(
                                      alpha: 0.2,
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.indigo.shade700,
                                    ),
                                  );
                                }).toList(),
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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
