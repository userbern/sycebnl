import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class ListeBailleursPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeBailleursPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
  });

  @override
  State<ListeBailleursPage> createState() => _ListeBailleursPageState();
}

class _ListeBailleursPageState extends State<ListeBailleursPage> {
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'sigle'; // 'sigle' ou 'designation'
  String _filterStatus = 'actifs'; // 'actifs', 'inactifs', 'tous'
  late FocusNode _focusNode;

  // Permissions
  bool get _canCreate => _hasPermission('creation');

  bool _hasPermission(String type) {
    if (userSession == null) return true;
    final permission = userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'liste_bailleurs',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  UserSession? get userSession => widget.userSession;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      if (mounted) _focusNode.requestFocus();
    });
    _loadBailleurs();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBailleurs() async {
    setState(() => _isLoading = true);
    try {
      final bailleurs = await AuthService.getBailleurs();
      setState(() {
        // Filtrer les bailleurs actifs (deleted_at == null)
        _bailleurs =
            bailleurs
                .where((b) => b.isActive)
                .map(
                  (b) => {
                    'id': (b.id ?? 0).toString(),
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  List<Map<String, dynamic>> get _filteredBailleurs {
    var filtered = _bailleurs;

    // Filtrer par texte de recherche
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((bailleur) {
            final query = _searchQuery.toLowerCase();
            return (bailleur['sigle'] ?? '').toString().toLowerCase().contains(
                  query,
                ) ||
                (bailleur['designation'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query);
          }).toList();
    }

    // Filtrer par statut (actif/inactif)
    if (_filterStatus == 'actifs') {
      filtered = filtered.where((b) => b['deleted_at'] == null).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((b) => b['deleted_at'] != null).toList();
    }

    // Trier
    if (_sortBy == 'sigle') {
      filtered.sort(
        (a, b) => (a['sigle'] ?? '').toString().compareTo(
          (b['sigle'] ?? '').toString(),
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

  bool _isActive(Map<String, dynamic> bailleur) {
    return bailleur['deleted_at'] == null;
  }

  Future<void> _deleteBailleur(String id, String sigle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Êtes-vous sûr de supprimer "$sigle"?'),
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
        await AuthService.deleteBailleur(int.parse(id));
        if (!mounted) return;
        _loadBailleurs();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bailleur supprimé')));
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
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showBailleurDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(title: const Text('Liste des Bailleurs'))
                : null,
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Icon(Icons.business, size: 32, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Liste des bailleurs',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_canCreate)
                    ElevatedButton.icon(
                      onPressed: () => _showBailleurDialog(null),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau bailleur (Ctrl+N)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Barre de recherche
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  labelText: 'Rechercher un bailleur',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Filtres et tri
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: InputDecoration(
                        labelText: 'Trier par',
                        prefixIcon: const Icon(Icons.sort),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'sigle', child: Text('Sigle')),
                        DropdownMenuItem(
                          value: 'designation',
                          child: Text('Désignation'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value ?? 'sigle');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterStatus,
                      decoration: InputDecoration(
                        labelText: 'Afficher',
                        prefixIcon: const Icon(Icons.filter_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'actifs',
                          child: Text('Bailleurs actifs'),
                        ),
                        DropdownMenuItem(
                          value: 'inactifs',
                          child: Text('Bailleurs inactifs'),
                        ),
                        DropdownMenuItem(
                          value: 'tous',
                          child: Text('Tous les bailleurs'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _filterStatus = value ?? 'actifs');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _sortBy = 'sigle';
                        _filterStatus = 'actifs';
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tableau
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredBailleurs.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.business_center_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun bailleur trouvé',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 2500),
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
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
                                      DataColumn(label: Text('Sigle')),
                                      DataColumn(label: Text('Désignation')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows:
                                        _filteredBailleurs.map((bailleur) {
                                          return DataRow(
                                            color: WidgetStateProperty.all(
                                              _isActive(bailleur)
                                                  ? Colors.white
                                                  : Colors.grey.shade50,
                                            ),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  bailleur['sigle'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        _isActive(bailleur)
                                                            ? Colors.black87
                                                            : Colors
                                                                .grey
                                                                .shade500,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  bailleur['designation'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color:
                                                        _isActive(bailleur)
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
                                                          _showBailleurDialog(
                                                            bailleur,
                                                          );
                                                        },
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
                                                          _deleteBailleur(
                                                            bailleur['id']
                                                                .toString(),
                                                            bailleur['sigle'] ??
                                                                '',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBailleurDialog(Map<String, dynamic>? bailleur) {
    final isEdit = bailleur != null;
    final sigleController = TextEditingController(
      text: bailleur?['sigle'] ?? '',
    );
    final designationController = TextEditingController(
      text: bailleur?['designation'] ?? '',
    );
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
                  Icon(
                    isEdit ? Icons.edit : Icons.add_circle,
                    color: Colors.indigo.shade700,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Modifier le bailleur' : 'Nouveau bailleur',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                        // Sigle
                        TextFormField(
                          controller: sigleController,
                          decoration: InputDecoration(
                            labelText: 'Sigle *',
                            prefixIcon: const Icon(Icons.label),
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
                              return 'Le sigle est requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Désignation
                        TextFormField(
                          controller: designationController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Désignation *',
                            prefixIcon: const Icon(Icons.description),
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
                              return 'La désignation est requise';
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
                        if (isEdit) {
                          await AuthService.updateBailleur(
                            id: int.parse(bailleur!['id'].toString()),
                            code: sigleController.text.trim(),
                            nom: designationController.text.trim(),
                          );
                        } else {
                          await AuthService.createBailleur(
                            code: sigleController.text.trim(),
                            nom: designationController.text.trim(),
                          );
                        }

                        if (!mounted) return;
                        _loadBailleurs();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? 'Bailleur modifié avec succès'
                                  : 'Bailleur créé avec succès',
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
                  child: Text(isEdit ? 'Modifier' : 'Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
