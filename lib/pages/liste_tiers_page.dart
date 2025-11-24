import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/tiers.dart';
import '../models/user_session.dart';

class ListeTiersPage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const ListeTiersPage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<ListeTiersPage> createState() => _ListeTiersPageState();
}

class _ListeTiersPageState extends State<ListeTiersPage> {
  List<Tiers> tiers = [];
  String searchQuery = '';
  bool isLoading = true;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      _focusNode.requestFocus();
    });
    _loadTiers();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTiers() async {
    try {
      final result = await AuthService.getTiers();
      if (!mounted) return;
      setState(() {
        tiers = result;
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

  Future<void> _deleteTiers(String id, String intitule) async {
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
        await AuthService.deleteTiers(id);
        if (!mounted) return;
        _loadTiers();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tiers supprimé')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        tiers
            .where(
              (t) =>
                  t.numeroCompte.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  t.intitule.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showTiersDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Liste des tiers'),
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
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un tiers...',
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
                    // Tableau des tiers
                    Expanded(
                      child:
                          filtered.isEmpty
                              ? Center(
                                child: Text(
                                  searchQuery.isEmpty
                                      ? 'Aucun tiers. Cliquez sur + ou Ctrl+N'
                                      : 'Aucun tiers trouvé',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('N° Compte')),
                                    DataColumn(label: Text('Intitulés')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Compte Collectif')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows:
                                      filtered
                                          .map(
                                            (t) => DataRow(
                                              cells: [
                                                DataCell(Text(t.numeroCompte)),
                                                DataCell(Text(t.intitule)),
                                                DataCell(
                                                  Chip(
                                                    label: Text(
                                                      t.type.toLabel(),
                                                    ),
                                                    backgroundColor:
                                                        Colors.blue[100],
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(t.compteCollectif),
                                                ),
                                                DataCell(
                                                  PopupMenuButton(
                                                    itemBuilder:
                                                        (context) => [
                                                          PopupMenuItem(
                                                            onTap:
                                                                () =>
                                                                    _showTiersDialog(
                                                                      t,
                                                                    ),
                                                            child: const Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.edit,
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
                                                                () =>
                                                                    _deleteTiers(
                                                                      t.id,
                                                                      t.intitule,
                                                                    ),
                                                            child: const Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.delete,
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
                                                                        Colors
                                                                            .red,
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
                  ],
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showTiersDialog(null),
          tooltip: 'Nouveau tiers (Ctrl+N)',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showTiersDialog(Tiers? tiers) {
    showDialog(
      context: context,
      builder:
          (context) => TiersDialog(
            tiers: tiers,
            onSave: (updatedTiers) {
              _loadTiers();
              Navigator.pop(context);
            },
          ),
    );
  }
}

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class TiersDialog extends StatefulWidget {
  final Tiers? tiers;
  final Function(Tiers) onSave;

  const TiersDialog({super.key, this.tiers, required this.onSave});

  @override
  State<TiersDialog> createState() => _TiersDialogState();
}

class _TiersDialogState extends State<TiersDialog> {
  late TextEditingController _numeroController;
  late TextEditingController _intituleController;
  late TextEditingController _typeController;
  late TextEditingController _compteCollectifController;
  late TextEditingController _nifController;
  late TextEditingController _adresseController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tiers = widget.tiers;
    _numeroController = TextEditingController(text: tiers?.numeroCompte ?? '');
    _intituleController = TextEditingController(text: tiers?.intitule ?? '');
    _typeController = TextEditingController(text: tiers?.type.toLabel() ?? '');
    _compteCollectifController = TextEditingController(
      text: tiers?.compteCollectif ?? '',
    );
    _nifController = TextEditingController(text: tiers?.nif ?? '');
    _adresseController = TextEditingController(text: tiers?.adresse ?? '');
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _intituleController.dispose();
    _typeController.dispose();
    _compteCollectifController.dispose();
    _nifController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_numeroController.text.isEmpty ||
        _intituleController.text.isEmpty ||
        _typeController.text.isEmpty ||
        _compteCollectifController.text.isEmpty) {
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
      if (widget.tiers == null) {
        // Créer
        await AuthService.createTiers(
          numeroCompte: _numeroController.text,
          intitule: _intituleController.text,
          type: _typeController.text,
          compteCollectif: _compteCollectifController.text,
          nif: _nifController.text.isEmpty ? null : _nifController.text,
          adresse:
              _adresseController.text.isEmpty ? null : _adresseController.text,
        );
      } else {
        // Modifier
        await AuthService.updateTiers(
          id: widget.tiers!.id,
          numeroCompte: _numeroController.text,
          intitule: _intituleController.text,
          type: _typeController.text,
          compteCollectif: _compteCollectifController.text,
          nif: _nifController.text.isEmpty ? null : _nifController.text,
          adresse:
              _adresseController.text.isEmpty ? null : _adresseController.text,
        );
      }

      if (!mounted) return;
      widget.onSave(
        widget.tiers ??
            Tiers(
              id: '',
              numeroCompte: _numeroController.text,
              intitule: _intituleController.text,
              type: stringToTypeTiers(_typeController.text),
              compteCollectif: _compteCollectifController.text,
              nif: _nifController.text,
              adresse: _adresseController.text,
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
    final isEditing = widget.tiers != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifier le tiers' : 'Nouveau tiers'),
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
              TextField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Client, Fournisseur, Employé...',
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _compteCollectifController,
                decoration: const InputDecoration(
                  labelText: 'Compte Collectif *',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nifController,
                decoration: const InputDecoration(
                  labelText: 'NIF',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
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
