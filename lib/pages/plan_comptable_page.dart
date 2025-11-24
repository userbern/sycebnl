import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../models/compte.dart';
import '../services/auth_service.dart';

class PlanComptablePage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const PlanComptablePage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<PlanComptablePage> createState() => _PlanComptablePageState();
}

class _PlanComptablePageState extends State<PlanComptablePage> {
  List<Compte> comptes = [];
  bool isLoading = true;
  String searchQuery = '';
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      _focusNode.requestFocus();
    });
    _loadComptes();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComptes() async {
    try {
      final data = await AuthService.getComptes();
      if (!mounted) return;
      setState(() {
        comptes = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteCompte(Compte compte) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer le compte?'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer le compte ${compte.numeroCompte}?',
            ),
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

    if (confirmed != true) return;

    try {
      await AuthService.deleteCompte(compte.id);
      if (!mounted) return;
      _loadComptes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte supprimé'),
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    if (!widget.userSession.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Plan comptable'),
          backgroundColor: Colors.indigo,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[400]),
              SizedBox(height: screenHeight * 0.02),
              const Text(
                'Accès refusé',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              const Text(
                'Seuls les administrateurs peuvent configurer le plan comptable',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Filtrer les comptes selon la recherche
    final filteredComptes =
        comptes
            .where(
              (c) =>
                  c.numeroCompte.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  c.intitule.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showCompteDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Plan comptable'),
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
                    // Barre de recherche
                    Padding(
                      padding: EdgeInsets.all(screenHeight * 0.015),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un compte...',
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
                    // Tableau des comptes
                    Expanded(
                      child:
                          filteredComptes.isEmpty
                              ? Center(
                                child: Text(
                                  searchQuery.isEmpty
                                      ? 'Aucun compte. Cliquez sur + ou Ctrl+N'
                                      : 'Aucun compte trouvé',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 20,
                                    dataRowHeight: 56,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'N° Compte',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Intitulés',
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
                                          'Nature',
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
                                        filteredComptes
                                            .map(
                                              (compte) => DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      compte.numeroCompte,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(compte.intitule),
                                                  ),
                                                  DataCell(
                                                    Chip(
                                                      label: Text(
                                                        compte.type.toLabel(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          _getTypeColor(
                                                            compte.type,
                                                          ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      compte.nature.toLabel(),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      children: [
                                                        Tooltip(
                                                          message: 'Modifier',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Colors.blue,
                                                              size: 20,
                                                            ),
                                                            onPressed: () {
                                                              _showCompteDialog(
                                                                compte,
                                                              );
                                                            },
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                          ),
                                                        ),
                                                        Tooltip(
                                                          message: 'Supprimer',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                            onPressed: () {
                                                              _deleteCompte(
                                                                compte,
                                                              );
                                                            },
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
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
                  ],
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCompteDialog(null),
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Color _getTypeColor(TypeCompte type) {
    switch (type) {
      case TypeCompte.detail:
        return Colors.blue;
      case TypeCompte.total:
        return Colors.green;
    }
  }

  void _showCompteDialog(Compte? compte) {
    showDialog(
      context: context,
      builder:
          (context) => CompteDialog(
            compte: compte,
            onSave: (updatedCompte) {
              _loadComptes();
              Navigator.pop(context);
            },
          ),
    );
  }
}

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class CompteDialog extends StatefulWidget {
  final Compte? compte;
  final Function(Compte) onSave;

  const CompteDialog({super.key, this.compte, required this.onSave});

  @override
  State<CompteDialog> createState() => _CompteDialogState();
}

class _CompteDialogState extends State<CompteDialog> {
  late TextEditingController _numeroController;
  late TextEditingController _intituleController;
  late TextEditingController _descriptionController;
  TypeCompte? _selectedType;
  NatureCompte? _selectedNature;
  bool _liaisonTiers = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final compte = widget.compte;
    _numeroController = TextEditingController(text: compte?.numeroCompte ?? '');
    _intituleController = TextEditingController(text: compte?.intitule ?? '');
    _descriptionController = TextEditingController(
      text: compte?.description ?? '',
    );
    _selectedType = compte?.type ?? TypeCompte.detail; // Default to detail
    _selectedNature = compte?.nature;
    _liaisonTiers = compte?.liaisonTiers ?? false;

    // Calculer la nature automatiquement si elle n'existe pas
    if (_selectedNature == null && _numeroController.text.isNotEmpty) {
      _selectedNature = calculateNatureFromNumeroCompte(_numeroController.text);
    }
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _intituleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_numeroController.text.isEmpty ||
        _intituleController.text.isEmpty ||
        _selectedType == null ||
        _selectedNature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les champs obligatoires doivent être remplis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.compte == null) {
        // Créer
        await AuthService.createCompte(
          numeroCompte: _numeroController.text,
          intitule: _intituleController.text,
          type: _selectedType!.toDbString(),
          nature: _selectedNature!.toDbString(),
          liaisonTiers: _liaisonTiers,
          description:
              _descriptionController.text.isEmpty
                  ? null
                  : _descriptionController.text,
        );
      } else {
        // Modifier
        await AuthService.updateCompte(
          id: widget.compte!.id,
          numeroCompte: _numeroController.text,
          intitule: _intituleController.text,
          type: _selectedType!.toDbString(),
          nature: _selectedNature!.toDbString(),
          liaisonTiers: _liaisonTiers,
          description:
              _descriptionController.text.isEmpty
                  ? null
                  : _descriptionController.text,
        );
      }

      if (!mounted) return;
      widget.onSave(
        widget.compte ??
            Compte(
              id: '',
              numeroCompte: _numeroController.text,
              intitule: _intituleController.text,
              type: _selectedType!,
              nature: _selectedNature!,
              liaisonTiers: _liaisonTiers,
              description: _descriptionController.text,
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
    final isEditing = widget.compte != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifier le compte' : 'Nouveau compte'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _numeroController,
                decoration: const InputDecoration(
                  labelText: 'N° Compte *',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
                onChanged: (value) {
                  final nature = calculateNatureFromNumeroCompte(value);
                  if (nature != null) {
                    setState(() => _selectedNature = nature);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _intituleController,
                decoration: const InputDecoration(
                  labelText: 'Intitulé *',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TypeCompte>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
                ),
                items:
                    TypeCompte.values
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NatureCompte>(
                value: _selectedNature,
                decoration: const InputDecoration(
                  labelText: 'Nature *',
                  border: OutlineInputBorder(),
                ),
                items:
                    NatureCompte.values
                        .map(
                          (nature) => DropdownMenuItem(
                            value: nature,
                            child: Text(nature.toLabel()),
                          ),
                        )
                        .toList(),
                onChanged:
                    _isSaving
                        ? null
                        : (value) {
                          setState(() => _selectedNature = value);
                        },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Liaison de tiers'),
                value: _liaisonTiers,
                onChanged:
                    _isSaving
                        ? null
                        : (value) {
                          setState(() => _liaisonTiers = value ?? false);
                        },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isSaving,
              ),
            ],
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
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(isEditing ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }
}
