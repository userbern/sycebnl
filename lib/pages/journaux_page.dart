import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/database_service_new.dart' as db_service;
import '../models/journal.dart';
import '../models/compte.dart';
import '../models/user_session.dart';

class JournauxPage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const JournauxPage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<JournauxPage> createState() => _JournauxPageState();
}

class _JournauxPageState extends State<JournauxPage> {
  List<Journal> journaux = [];
  List<Compte> comptes = [];
  String searchQuery = '';
  String? _selectedType; // null = tous, 'financier', 'non_financier'
  String _filterStatus = 'actifs'; // 'actifs', 'inactifs', 'tous'
  bool isLoading = true;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      _focusNode.requestFocus();
    });
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final result = await AuthService.getJournaux();
      final comptesList = await db_service.DatabaseService.getAllComptes();
      if (!mounted) return;
      setState(() {
        journaux = result;
        comptes = comptesList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      setState(() => isLoading = false);
    }
  }

  List<Journal> get _filteredJournaux {
    var filtered = journaux;

    // Filtrer par texte de recherche
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered =
          filtered.where((j) {
            return j.code.toLowerCase().contains(query) ||
                j.intitule.toLowerCase().contains(query);
          }).toList();
    }

    // Filtrer par type
    if (_selectedType != null) {
      final typeFilter =
          _selectedType == 'financier'
              ? TypeJournal.financier
              : TypeJournal.nonFinancier;
      filtered = filtered.where((j) => j.type == typeFilter).toList();
    }

    // Filtrer par statut
    if (_filterStatus == 'actifs') {
      filtered = filtered.where((j) => j.isActive).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((j) => !j.isActive).toList();
    }

    return filtered;
  }

  Future<void> _deleteJournal(String id, String intitule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Êtes-vous sûr de supprimer "$intitule"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await AuthService.deleteJournal(int.parse(id));
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Journal supprimé')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Color _getTypeColor(TypeJournal type) {
    switch (type) {
      case TypeJournal.financier:
        return Colors.green;
      case TypeJournal.nonFinancier:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showJournalDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Journaux comptables'),
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
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // En-tête avec recherche et bouton nouveau
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() => searchQuery = value);
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        'Rechercher par code ou intitulé...',
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
                              ElevatedButton.icon(
                                onPressed: () => _showJournalDialog(null),
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
                          // Filtres par type et statut
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: 'Type de journal',
                                    prefixIcon: const Icon(Icons.category),
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
                                      value: null,
                                      child: Text('Tous les types'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'financier',
                                      child: Text('Financier'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'non_financier',
                                      child: Text('Non Financier'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedType = value);
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
                                      child: Text('Journaux actifs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactifs',
                                      child: Text('Journaux inactifs'),
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
                                    searchQuery = '';
                                    _selectedType = null;
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
                    // Tableau des journaux
                    Expanded(
                      child:
                          _filteredJournaux.isEmpty
                              ? Center(
                                child: Text(
                                  searchQuery.isEmpty
                                      ? 'Aucun journal. Cliquez sur "Nouveau" ou Ctrl+N'
                                      : 'Aucun journal trouvé',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 2500,
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 72,
                                      horizontalMargin: 48,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'Code',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Intitulé',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Type',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Saisie Analytique',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows:
                                          _filteredJournaux
                                              .map(
                                                (j) => DataRow(
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        j.code,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Text(j.intitule)),
                                                    DataCell(
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: _getTypeColor(
                                                            j.type,
                                                          ).withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                _getTypeColor(
                                                                  j.type,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          j.type.toLabel(),
                                                          style: TextStyle(
                                                            color:
                                                                _getTypeColor(
                                                                  j.type,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      j.saisieAnalytique
                                                          ? const Icon(
                                                            Icons.check_circle,
                                                            color: Colors.green,
                                                          )
                                                          : const Icon(
                                                            Icons.cancel,
                                                            color: Colors.red,
                                                          ),
                                                    ),
                                                    DataCell(
                                                      PopupMenuButton(
                                                        itemBuilder:
                                                            (context) => [
                                                              PopupMenuItem(
                                                                onTap:
                                                                    () =>
                                                                        _showJournalDialog(
                                                                          j,
                                                                        ),
                                                                child: const Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 16,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text(
                                                                      'Modifier',
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              PopupMenuItem(
                                                                onTap:
                                                                    () => _deleteJournal(
                                                                      j.id,
                                                                      j.intitule,
                                                                    ),
                                                                child: const Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .delete,
                                                                      size: 16,
                                                                      color:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
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
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
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

  void _showJournalDialog(Journal? journal) {
    showDialog(
      context: context,
      builder:
          (context) => JournalDialog(
            journal: journal,
            comptes: comptes,
            onSave: (updatedJournal) {
              _loadData();
              Navigator.pop(context);
            },
          ),
    );
  }
}

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class JournalDialog extends StatefulWidget {
  final Journal? journal;
  final List<Compte> comptes;
  final Function(Journal) onSave;

  const JournalDialog({
    super.key,
    this.journal,
    required this.comptes,
    required this.onSave,
  });

  @override
  State<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends State<JournalDialog> {
  late TextEditingController _codeController;
  late TextEditingController _intituleController;
  late TextEditingController _compteFresorerieController;
  TypeJournal? _selectedType;
  Compte? _selectedCompteFresorerie;
  bool _saisieAnalytique = false;
  bool _isSaving = false;
  String? _compteError;
  final _formKey = GlobalKey<FormState>();
  Timer? _debounceTimer;
  bool _compteFieldInitialized = false;

  @override
  void initState() {
    super.initState();
    final journal = widget.journal;
    _codeController = TextEditingController(text: journal?.code ?? '');
    _intituleController = TextEditingController(text: journal?.intitule ?? '');
    _compteFresorerieController = TextEditingController();
    _selectedType = journal?.type ?? TypeJournal.financier;
    _saisieAnalytique = journal?.saisieAnalytique ?? false;

    // DEBUG
    print('📝 DEBUG initState - Journal: ${journal?.code}');
    print('📝 DEBUG - compteFresorerie value: "${journal?.compteFresorerie}"');
    print(
      '📝 DEBUG - compteFresorerie null: ${journal?.compteFresorerie == null}',
    );
    print(
      '📝 DEBUG - compteFresorerie empty: ${journal?.compteFresorerie?.isEmpty}',
    );

    // Chercher le compte de trésorerie si édition
    if (journal?.compteFresorerie != null &&
        journal!.compteFresorerie!.isNotEmpty) {
      try {
        print('📝 DEBUG - Cherchant compte: "${journal.compteFresorerie}"');
        _selectedCompteFresorerie = widget.comptes.firstWhere(
          (c) => c.numeroCompte == journal.compteFresorerie,
        );
        print(
          '📝 DEBUG - Compte trouvé: ${_selectedCompteFresorerie!.numeroCompte}',
        );
        _compteFresorerieController.text =
            '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
      } catch (e) {
        // Compte non trouvé
        print('📝 DEBUG - Compte non trouvé: $e');
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _intituleController.dispose();
    _compteFresorerieController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _searchCompteFresorerie(String input) {
    if (input.isEmpty) {
      setState(() {
        _selectedCompteFresorerie = null;
        _compteError = null;
      });
      return;
    }

    final comptesFresorerie = _getFilteredComptes();
    final matching =
        comptesFresorerie
            .where((c) => c.numeroCompte.startsWith(input))
            .toList();

    setState(() {
      if (matching.isEmpty) {
        _selectedCompteFresorerie = null;
        _compteError = 'Compte "$input" non trouvé dans le plan comptable';
      } else if (matching.length == 1) {
        _selectedCompteFresorerie = matching.first;
        _compteError = null;
      } else {
        _selectedCompteFresorerie = null;
        _compteError = 'Plusieurs comptes trouvés, soyez plus précis';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation supplémentaire
    if (_codeController.text.isEmpty ||
        _intituleController.text.isEmpty ||
        _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les champs obligatoires doivent être remplis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Si type financier, vérifier que compte de trésorerie est sélectionné
    if (_selectedType == TypeJournal.financier &&
        _selectedCompteFresorerie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte de trésorerie requis pour journal financier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.journal == null) {
        // Créer
        await AuthService.createJournal(
          code: _codeController.text,
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
          saisieAnalytique: _saisieAnalytique,
        );
      } else {
        // Modifier
        await AuthService.updateJournal(
          id: int.parse(widget.journal!.id),
          code: _codeController.text,
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
          saisieAnalytique: _saisieAnalytique,
        );
      }

      if (!mounted) return;
      widget.onSave(
        widget.journal ??
            Journal(
              id: '',
              code: _codeController.text,
              intitule: _intituleController.text,
              type: _selectedType!,
              compteFresorerie: _selectedCompteFresorerie?.numeroCompte,
              saisieAnalytique: _saisieAnalytique,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );
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
    final isEditing = widget.journal != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.add_circle,
            color: Colors.indigo.shade700,
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Modifier le journal' : 'Nouveau journal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code et Intitulé
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: 'Code *',
                          prefixIcon: const Icon(Icons.code),
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
                              color: Colors.indigo.shade700,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        enabled: !_isSaving,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Champ requis';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _intituleController,
                        decoration: InputDecoration(
                          labelText: 'Intitulé *',
                          prefixIcon: const Icon(Icons.title),
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
                              color: Colors.indigo.shade700,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        enabled: !_isSaving,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Champ requis';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Type de Journal
                DropdownButtonFormField<TypeJournal>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type *',
                    prefixIcon: const Icon(Icons.category),
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
                        color: Colors.indigo.shade700,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  dropdownColor: Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down_circle,
                    color: Colors.indigo.shade700,
                  ),
                  items:
                      TypeJournal.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toLabel()),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _isSaving
                          ? null
                          : (value) {
                            setState(() => _selectedType = value);
                          },
                  validator: (value) {
                    if (value == null) {
                      return 'Sélectionnez un type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Compte de Trésorerie (seulement si financier)
                if (_selectedType == TypeJournal.financier)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Autocomplete<Compte>(
                              optionsBuilder: (
                                TextEditingValue textEditingValue,
                              ) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Compte>.empty();
                                }
                                final comptesFresorerie = _getFilteredComptes();
                                return comptesFresorerie.where(
                                  (c) =>
                                      c.numeroCompte.toLowerCase().startsWith(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                );
                              },
                              onSelected: (Compte selection) {
                                setState(() {
                                  _selectedCompteFresorerie = selection;
                                  _compteFresorerieController.text =
                                      '${selection.numeroCompte} - ${selection.intitule}';
                                  _compteError = null;
                                });
                              },
                              fieldViewBuilder: (
                                BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Initialiser le texte la première fois si on a un compte sélectionné
                                if (!_compteFieldInitialized &&
                                    _selectedCompteFresorerie != null) {
                                  _compteFieldInitialized = true;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    textEditingController.text =
                                        '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                                  });
                                }

                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  onChanged: (String value) {
                                    _searchCompteFresorerie(value);
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Compte de Trésorerie *',
                                    hintText: 'Tapez le numéro de compte...',
                                    prefixIcon: const Icon(
                                      Icons.account_balance,
                                    ),
                                    errorText: _compteError,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            _compteError != null
                                                ? Colors.red
                                                : (_selectedCompteFresorerie !=
                                                        null
                                                    ? Colors.green
                                                    : Colors.grey.shade400),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.indigo.shade700,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  enabled: !_isSaving,
                                  validator: (value) {
                                    if (_selectedType ==
                                            TypeJournal.financier &&
                                        _selectedCompteFresorerie == null) {
                                      return _compteError ??
                                          'Sélectionnez un compte de trésorerie valide';
                                    }
                                    return null;
                                  },
                                );
                              },
                              optionsViewBuilder: (
                                BuildContext context,
                                AutocompleteOnSelected<Compte> onSelected,
                                Iterable<Compte> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: SizedBox(
                                      width: 400,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          final Compte option = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Container(
                                              color:
                                                  index.isEven
                                                      ? Colors.grey.shade50
                                                      : Colors.white,
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    option.numeroCompte,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    option.intitule,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isSaving
                                      ? null
                                      : _showCompteCreationDialogForTresorerie,
                              icon: const Icon(Icons.add_circle),
                              label: const Text('Créer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                // Saisie Analytique
                CheckboxListTile(
                  title: const Text('Saisie Analytique'),
                  value: _saisieAnalytique,
                  onChanged:
                      _isSaving
                          ? null
                          : (value) {
                            setState(() => _saisieAnalytique = value ?? false);
                          },
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.indigo.shade700,
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
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                  : Text(isEditing ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }

  NatureCompte _calculateNatureFromNumero(String numero) {
    if (numero.isEmpty) return NatureCompte.bilanBanque;

    // Extraire les 2 premiers chiffres pour les cas spéciaux
    String twoDigitPrefix = '';
    if (numero.length >= 2) {
      twoDigitPrefix = numero.substring(0, 2);
    }

    // Cas spécifiques 2 chiffres
    switch (twoDigitPrefix) {
      case '40':
        return NatureCompte.bilanFournisseurs;
      case '41':
        return NatureCompte.bilanAdherentsClientsUsagers;
      case '42':
        return NatureCompte.bilanPersonnel;
      case '43':
        return NatureCompte.bilanOrganismesSociaux;
      case '44':
        return NatureCompte.bilanEtatCollectivitesPubliques;
      case '45':
      case '46':
      case '47':
      case '48':
      case '49':
        return NatureCompte.bilanAutresTiers;
      case '50':
      case '51':
      case '53':
      case '55':
      case '56':
      case '58':
      case '59':
        return NatureCompte.bilanBanque;
      case '52':
      case '57':
        return NatureCompte.bilanCaisse;
      case '80':
      case '82':
      case '84':
      case '86':
      case '88':
        return NatureCompte.produitsHAO;
      case '81':
      case '83':
      case '85':
      case '87':
      case '89':
        return NatureCompte.chargesHAO;
    }

    // Fallback sur 1er chiffre
    final firstDigit = numero[0];
    switch (firstDigit) {
      case '1':
        return NatureCompte.bilanRessourcesDurables;
      case '2':
        return NatureCompte.bilanActifImmobilise;
      case '3':
        return NatureCompte.bilanStocks;
      case '5':
        return NatureCompte.bilanBanque;
      case '6':
        return NatureCompte.chargesAO;
      case '7':
        return NatureCompte.produitsAO;
      case '8':
        // Pour '8X', vérifier la parité du 2ème chiffre
        if (numero.length >= 2) {
          final secondDigit = int.tryParse(numero[1]) ?? 0;
          if (secondDigit % 2 == 0) {
            return NatureCompte.produitsHAO;
          } else {
            return NatureCompte.chargesHAO;
          }
        }
        return NatureCompte.chargesHAO;
      case '9':
        return NatureCompte.engagementsHorsBilan;
      default:
        return NatureCompte.bilanBanque;
    }
  }

  void _showCompteSelectionDialog([String? prefilledNumero]) {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              TextEditingController searchController = TextEditingController(
                text: prefilledNumero ?? '',
              );
              List<Compte> filteredComptes = _getFilteredComptes();

              return AlertDialog(
                title: const Text('Sélectionner un compte de trésorerie'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Ex: 41101AB ou 5210',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setDialogState(() {
                                          searchController.clear();
                                        });
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: _buildCompteSelectionList(
                            searchController.text,
                            filteredComptes,
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ],
              );
            },
          ),
    );
  }

  List<Compte> _getFilteredComptes() {
    return widget.comptes.where((c) {
      return [
        '52',
        '57',
        '50',
        '51',
        '53',
        '55',
        '56',
        '58',
        '59',
      ].any((prefix) => c.numeroCompte.startsWith(prefix));
    }).toList();
  }

  Widget _buildCompteSelectionList(
    String searchText,
    List<Compte> filteredComptes,
    Function(VoidCallback) setDialogState,
  ) {
    final numericSearch = _extractNumericPrefix(searchText);

    List<Compte> matchingComptes =
        filteredComptes.where((c) {
          if (numericSearch.isEmpty) return true;
          return c.numeroCompte.startsWith(numericSearch);
        }).toList();

    return Column(
      children: [
        Expanded(
          child:
              matchingComptes.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aucun compte trouvé',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        if (numericSearch.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _showCompteCreationDialog(numericSearch);
                              },
                              icon: const Icon(Icons.add),
                              label: Text('Créer compte $numericSearch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: matchingComptes.length,
                    itemBuilder: (context, index) {
                      final compte = matchingComptes[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.indigo,
                        ),
                        title: Text(compte.numeroCompte),
                        subtitle: Text(compte.intitule),
                        trailing: const Icon(Icons.check_circle_outline),
                        onTap: () {
                          setState(() {
                            _selectedCompteFresorerie = compte;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  String _extractNumericPrefix(String input) {
    final regex = RegExp(r'^(\d+)');
    final match = regex.firstMatch(input);
    return match?.group(1) ?? '';
  }

  Future<void> _showCompteCreationDialog(String numeroCompte) async {
    final intituleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Nouveau compte de trésorerie',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: numeroCompte,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'N° Compte',
                            prefixIcon: const Icon(Icons.numbers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            prefixIcon: const Icon(Icons.label),
                            hintText: 'Ex: Banque principale',
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
                                color: Colors.indigo.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'L\'intitulé est requis';
                            }
                            return null;
                          },
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
                    if (formKey.currentState!.validate()) {
                      try {
                        final nature = _calculateNatureFromNumero(numeroCompte);
                        await db_service.DatabaseService.createCompte(
                          numeroCompte: numeroCompte,
                          intitule: intituleController.text,
                          type: TypeCompte.detail.toDbString(),
                          nature: nature.toDbString(),
                          liaisonTiers: false,
                          description: '',
                        );

                        final allComptes =
                            await db_service.DatabaseService.getAllComptes();
                        final compte = allComptes.firstWhere(
                          (c) => c.numeroCompte == numeroCompte,
                        );

                        if (!mounted) return;

                        setState(() {
                          _selectedCompteFresorerie = compte;
                          widget.comptes.add(compte);
                        });

                        if (!mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Compte $numeroCompte créé avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCompteCreationDialogForTresorerie() {
    TextEditingController numeroController = TextEditingController();
    TextEditingController intituleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Créer un nouveau compte'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro du compte',
                    hintText: 'Ex: 52100',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: intituleController,
                  decoration: const InputDecoration(
                    labelText: 'Intitulé du compte',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String numero = numeroController.text.trim();
                final String intitule = intituleController.text.trim();

                if (numero.isEmpty || intitule.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez remplir tous les champs'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Récupérer la longueur de compte depuis la config
                  final config = await db_service.DatabaseService.getConfig();
                  final longueurCompte =
                      config?['longueur_compte_general'] as int? ?? 8;

                  // Compléter le numéro avec des zéros à la fin
                  final numeroPadded = numero.padRight(longueurCompte, '0');

                  final nature = calculateNatureFromNumeroCompte(numeroPadded);
                  if (nature == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Impossible de déterminer la nature du compte',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  await AuthService.createCompte(
                    numeroCompte: numeroPadded,
                    intitule: intitule,
                    type: TypeCompte.detail.toDbString(),
                    nature: nature.toDbString(),
                  );

                  // Récupérer les comptes mis à jour
                  final updatedComptes = await AuthService.getComptes();

                  setState(() {
                    widget.comptes.clear();
                    widget.comptes.addAll(updatedComptes);
                    _selectedCompteFresorerie = updatedComptes.firstWhere(
                      (c) => c.numeroCompte == numeroPadded,
                      orElse: () => updatedComptes.first,
                    );
                    _compteFresorerieController.text =
                        '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                  });

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Compte $numeroPadded créé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }
}
