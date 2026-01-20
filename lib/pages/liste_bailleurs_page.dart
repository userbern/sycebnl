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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 32,
                        color: Colors.indigo.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Liste des bailleurs',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_canCreate)
                    ElevatedButton.icon(
                      onPressed: () => _showBailleurDialog(null),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau bailleur (Ctrl+N)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
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

              // Barre de recherche et filtres sur une ligne responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  const double spacing = 12;
                  const double resetWidth = 44;

                  final double dropdownWidth =
                      maxWidth >= 1080
                          ? 240
                          : maxWidth >= 900
                          ? 220
                          : maxWidth >= 720
                          ? 200
                          : maxWidth >= 520
                          ? 180
                          : maxWidth;

                  double searchWidth;
                  if (maxWidth >= 720) {
                    searchWidth =
                        maxWidth -
                        (dropdownWidth * 2 + resetWidth + spacing * 3);
                    searchWidth = searchWidth.clamp(320, maxWidth).toDouble();
                  } else {
                    searchWidth = maxWidth;
                  }

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          onChanged:
                              (value) => setState(() => _searchQuery = value),
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
                      ),
                      SizedBox(
                        width: dropdownWidth,
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          decoration: InputDecoration(
                            labelText: 'Trier',
                            prefixIcon: const Icon(Icons.sort),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'sigle',
                              child: Text(
                                'Sigle',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'designation',
                              child: Text(
                                'Désignation',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _sortBy = value ?? 'sigle');
                          },
                        ),
                      ),
                      SizedBox(
                        width: dropdownWidth,
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          decoration: InputDecoration(
                            labelText: 'Afficher',
                            prefixIcon: const Icon(Icons.filter_alt),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'actifs',
                              child: Text(
                                'Actifs',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'inactifs',
                              child: Text(
                                'Inactifs',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tous',
                              child: Text(
                                'Tous',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _filterStatus = value ?? 'actifs');
                          },
                        ),
                      ),
                      SizedBox(
                        width: resetWidth,
                        child: IconButton(
                          tooltip: 'Réinitialiser',
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _sortBy = 'sigle';
                              _filterStatus = 'actifs';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ],
                  );
                },
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
                        : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              // En-tête des colonnes
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade400,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Sigle',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                        ),
                                        child: Text(
                                          'Désignation',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Actions',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Cartes des bailleurs
                              ..._filteredBailleurs
                                  .map(
                                    (bailleur) => _buildBailleurCard(bailleur),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBailleurCard(Map<String, dynamic> bailleur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                bailleur['sigle'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      _isActive(bailleur)
                          ? Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  bailleur['designation'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _isActive(bailleur)
                            ? Colors.black87
                            : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Modifier',
                    child: IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: Colors.indigo.shade700,
                        size: 18,
                      ),
                      onPressed: () {
                        _showBailleurDialog(bailleur);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Supprimer',
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () {
                        _deleteBailleur(
                          bailleur['id'].toString(),
                          bailleur['sigle'] ?? '',
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    Future<void> _submit() async {
      if (formKey.currentState!.validate()) {
        try {
          if (isEdit) {
            await AuthService.updateBailleur(
              id: int.parse(bailleur['id'].toString()),
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
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(context);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AlertDialog(
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
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              // Focus sur le champ suivant
                              FocusScope.of(context).nextFocus();
                            },
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
                            maxLines: 1,
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
                            textInputAction: TextInputAction.go,
                            onFieldSubmitted: (_) {
                              // Ici, la touche Entrée déclenche la soumission
                              _submit();
                            },
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
                              id: int.parse(bailleur['id'].toString()),
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
              ),
            );
          },
        );
      },
    );
  }
}
