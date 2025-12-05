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

  Widget _buildProjetCard(Map<String, dynamic> projet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Code
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _showProjetDialog(projet),
                child: Text(
                  projet['code'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Désignation
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: GestureDetector(
                  onTap: () => _showProjetDialog(projet),
                  child: Text(
                    projet['designation'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // Bailleurs
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: GestureDetector(
                  onTap: () => _showProjetDialog(projet),
                  child: Text(
                    _getBailleursString(projet),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_canUpdate)
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.indigo.shade700,
                        ),
                        onPressed: () => _showProjetDialog(projet),
                        tooltip: 'Modifier',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    if (_canDelete)
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteProjet(projet),
                        tooltip: 'Supprimer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header avec statistiques
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_open,
                                size: 28,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Projets',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.indigo.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_filteredProjets.length} projet${_filteredProjets.length > 1 ? 's' : ''} disponible${_filteredProjets.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_canCreate)
                              ElevatedButton.icon(
                                onPressed: () => _showProjetDialog(null),
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Nouveau projet'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Barre de recherche et filtres
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            TextField(
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
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: DropdownButtonFormField<String>(
                                      value: _sortBy,
                                      decoration: InputDecoration(
                                        labelText: 'Trier par',
                                        prefixIcon: const Icon(Icons.sort),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                        setState(
                                          () => _sortBy = value ?? 'code',
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 200,
                                    child: DropdownButtonFormField<String>(
                                      value: _filterStatus,
                                      decoration: InputDecoration(
                                        labelText: 'Statut',
                                        prefixIcon: const Icon(
                                          Icons.filter_alt,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                          () =>
                                              _filterStatus = value ?? 'actifs',
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // En-tête des colonnes
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade700,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Code header
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Code',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Désignation header
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Désignation',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Bailleurs header
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Bailleurs',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Actions header
                            SizedBox(
                              width: 120,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Actions',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Liste des projets
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
                                : ListView.builder(
                                  itemCount: _filteredProjets.length,
                                  itemBuilder: (context, index) {
                                    final projet = _filteredProjets[index];
                                    return _buildProjetCard(projet);
                                  },
                                ),
                      ),
                    ],
                  ),
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

  // Variables pour le date picker avec dropdowns
  late int _debutDay, _debutMonth, _debutYear;
  late int _finDay, _finMonth, _finYear;

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

    // Initialiser les dropdowns de date
    final debutDate =
        _dateDebutController.text.isNotEmpty
            ? DateTime.parse(_dateDebutController.text)
            : DateTime.now();
    final finDate =
        _dateFinController.text.isNotEmpty
            ? DateTime.parse(_dateFinController.text)
            : DateTime.now().add(const Duration(days: 365));

    _debutDay = debutDate.day;
    _debutMonth = debutDate.month;
    _debutYear = debutDate.year;
    _finDay = finDate.day;
    _finMonth = finDate.month;
    _finYear = finDate.year;

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
    final isDebut = controller == _dateDebutController;
    int day = isDebut ? _debutDay : _finDay;
    int month = isDebut ? _debutMonth : _finMonth;
    int year = isDebut ? _debutYear : _finYear;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    isDebut
                        ? 'Sélectionner la date de début'
                        : 'Sélectionner la date de fin',
                  ),
                  content: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Jour
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Jour',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: day,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(31, (i) => i + 1)
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d.toString().padLeft(2, '0'),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => day = value ?? day);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Mois
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Mois',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: month,
                                    underline: const SizedBox(),
                                    items:
                                        [
                                              'Jan',
                                              'Fév',
                                              'Mar',
                                              'Avr',
                                              'Mai',
                                              'Jun',
                                              'Jul',
                                              'Aoû',
                                              'Sep',
                                              'Oct',
                                              'Nov',
                                              'Déc',
                                            ]
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e.key + 1,
                                                child: Text(
                                                  e.value,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => month = value ?? month);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Année
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Année',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: year,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(101, (i) => 2000 + i)
                                            .map(
                                              (y) => DropdownMenuItem(
                                                value: y,
                                                child: Text(
                                                  y.toString(),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => year = value ?? year);
                                    },
                                  ),
                                ),
                              ],
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
                    ElevatedButton(
                      onPressed:
                          () => Navigator.pop(context, {
                            'day': day,
                            'month': month,
                            'year': year,
                          }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
          ),
    );

    if (result != null) {
      setState(() {
        if (isDebut) {
          _debutDay = result['day']!;
          _debutMonth = result['month']!;
          _debutYear = result['year']!;
        } else {
          _finDay = result['day']!;
          _finMonth = result['month']!;
          _finYear = result['year']!;
        }

        final formattedDay = result['day'].toString().padLeft(2, '0');
        final formattedMonth = result['month'].toString().padLeft(2, '0');
        final formattedDate = '${result['year']}-$formattedMonth-$formattedDay';
        controller.text = formattedDate;
      });
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
