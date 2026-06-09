import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class GestionBudgetsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;
  final int? exerciceId;

  const GestionBudgetsPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
    this.exerciceId,
  });

  @override
  State<GestionBudgetsPage> createState() => _GestionBudgetsPageState();
}

class _GestionBudgetsPageState extends State<GestionBudgetsPage> {
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _projets = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredBudgets = [];

  bool get _canCreate => _hasPermission('creation');
  bool get _canUpdate => _hasPermission('modification');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'gestion_budgets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    _searchController.addListener(_filterBudgets);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterBudgets() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredBudgets = _budgets);
    } else {
      setState(() {
        _filteredBudgets =
            _budgets.where((budget) {
              final projetCode =
                  (budget['projet_code'] ?? '').toString().toLowerCase();
              final projetDesignation =
                  (budget['projet_designation'] ?? '').toString().toLowerCase();
              final bailleurSigle =
                  (budget['bailleur_sigle'] ?? '').toString().toLowerCase();
              return projetCode.contains(query) ||
                  projetDesignation.contains(query) ||
                  bailleurSigle.contains(query);
            }).toList();
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    if (widget.exerciceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun exercice sélectionné'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgets = await AuthService.getBudgetsWithDetails(
        exerciceId: widget.exerciceId!,
      );
      final projets = await AuthService.getProjetsWithBailleur();

      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _projets = projets;
        _filteredBudgets = budgets;
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

  Future<void> _deleteBudget(int budgetId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce budget ?',
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

    if (confirm == true) {
      try {
        await AuthService.deleteBudget(budgetId);
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget supprimé'),
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

  void _showCreateBudgetDialog() {
    if (widget.exerciceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun exercice sélectionné'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => _CreateBudgetDialog(
            projets: _projets,
            exerciceId: widget.exerciceId!,
            onBudgetCreated: () {
              _loadData();
            },
          ),
    );
  }

  Widget _buildBudgetRow(Map<String, dynamic> budget) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Colonne PROJET
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => _showBudgetDetails(budget),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /* Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        budget['projet_code'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ), */
                    Text(
                      budget['projet_designation'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Colonne BAILLEUR
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => _showBudgetDetails(budget),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      /* children: [
                        Text(
                          budget['bailleur_sigle'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ], */
                    ),

                    Text(
                      budget['bailleur_designation'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Colonne ACTIONS
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_canUpdate)
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.blue.shade400,
                      ),
                      key: const Key('Ajouter poste'),
                      onPressed: () => _showBudgetDetails(budget),
                      tooltip: 'ajouter un poste budgetaire',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                    ),

                  SizedBox(width: 5),

                  if (_canDelete)
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteBudget(budget['id'] as int),
                      tooltip: 'Supprimer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 60,
                  color: Colors.blue.shade300,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Aucun budget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Créez votre premier budget pour commencer',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_canCreate)
                ElevatedButton.icon(
                  onPressed: _showCreateBudgetDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Créer un budget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (HardwareKeyboard.instance.isControlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyN &&
              _canCreate) {
            _showCreateBudgetDialog();
          }
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Gestion des Budgets'),
                  backgroundColor: Colors.blue.shade400,
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: 28,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Budgets',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_budgets.length} budget${_budgets.length > 1 ? 's' : ''} disponible${_budgets.length > 1 ? 's' : ''}',
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
                                onPressed: _showCreateBudgetDialog,
                                icon: const Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                label: const Text('Nouveau budget'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade400,
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
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Rechercher un budget...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: 'Rafraîchir',
                              child: IconButton(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // En-tête du tableau
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 56), // Espace pour l'icône
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text(
                                  'PROJET',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text(
                                  'BAILLEUR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                'ACTIONS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Liste des budgets sous forme de tableau
                      Expanded(
                        child:
                            _budgets.isEmpty
                                ? _buildEmptyState()
                                : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(0),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _filteredBudgets.length,
                                    separatorBuilder:
                                        (context, index) => Divider(
                                          height: 1,
                                          color: Colors.grey.shade800,
                                        ),
                                    itemBuilder: (context, index) {
                                      return _buildBudgetRow(
                                        _filteredBudgets[index],
                                      );
                                    },
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  void _showBudgetDetails(Map<String, dynamic> budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BudgetDetailsPage(
              budget: budget,
              userSession: widget.userSession,
              onRefresh: _loadData,
            ),
      ),
    );
  }
}

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;
  final UserSession? userSession;
  final VoidCallback onRefresh;

  const BudgetDetailsPage({
    super.key,
    required this.budget,
    this.userSession,
    required this.onRefresh,
  });

  @override
  State<BudgetDetailsPage> createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> {
  List<Map<String, dynamic>> _postes = [];
  final Map<int, double> _postesMontants = {};
  bool _isLoading = false;
  double _montantTotal = 0.0;

  // Variables pour la gestion de la sélection hiérarchique
  int? _selectedPosteId;
  List<Map<String, dynamic>> _selectedPosteLignes = [];
  final Map<int, List<Map<String, dynamic>>> _lignesSousRubriques = {};
  final Map<int, double> _lignesMontants = {};
  bool _isLoadingLignes = false;
  final Set<int> _expandedLignesIds = {};

  bool get _canCreate => _hasPermission('creation');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'gestion_budgets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadPostes();
  }

  Future<void> _loadPostes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final postes = await AuthService.getPostesBudgetaires(
        widget.budget['id'] as int,
      );
      final montant = await AuthService.getMontantBudget(
        widget.budget['id'] as int,
      );

      if (!mounted) return;
      setState(() {
        _postes = postes;
        _montantTotal = montant;
        _isLoading = false;
      });

      // Charger les montants de chaque poste en arrière-plan
      for (final poste in postes) {
        final montantPoste = await AuthService.getMontantPosteBudgetaire(
          poste['id'] as int,
        );
        if (mounted) {
          setState(() {
            _postesMontants[poste['id'] as int] = montantPoste;
          });
        }
      }
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

  Future<void> _loadLignesForPoste(int posteId) async {
    setState(() => _isLoadingLignes = true);

    try {
      final lignes = await AuthService.getLignesBudgetaires(posteId);

      if (!mounted) return;
      setState(() {
        _selectedPosteLignes = lignes;
        _expandedLignesIds.clear();
        _lignesSousRubriques.clear();
        _lignesMontants.clear();
        _isLoadingLignes = false;
      });

      // Charger les montants de chaque ligne en arrière-plan
      for (final ligne in lignes) {
        final ligneId = ligne['id'] as int;
        try {
          final sousRubriques = await AuthService.getSousRubriques(ligneId);
          final montantTotal = sousRubriques.fold<double>(
            0.0,
            (sum, sr) => sum + ((sr['montant'] as num?)?.toDouble() ?? 0.0),
          );
          if (mounted) {
            setState(() {
              _lignesMontants[ligneId] = montantTotal;
            });
          }
        } catch (e) {
          // Erreur silencieuse pour ne pas bloquer l'interface
          if (mounted) {
            setState(() {
              _lignesMontants[ligneId] = 0.0;
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLignes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSousRubriquesForLigne(int ligneId) async {
    try {
      final sousRubriques = await AuthService.getSousRubriques(ligneId);

      if (!mounted) return;
      setState(() {
        _lignesSousRubriques[ligneId] = sousRubriques;
      });
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

  String _formatAmount(dynamic value) {
    final numVal =
        (value is num)
            ? value.toDouble()
            : (value == null ? 0.0 : double.tryParse(value.toString()) ?? 0.0);
    final parts = numVal.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    final intWithSep = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '$intWithSep.$decPart XOF';
  }

  Widget _buildMontantCard(String title, double montant) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatAmount(montant),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*   Widget _buildPosteHeader() {
    // Remplacé par le tableau unifié dans _buildPostesTable
    return const SizedBox.shrink();
  } */

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
    double size = 18,
  }) {
    return IconButton(
      icon: Icon(icon, size: size, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 20,
    );
  }

  Widget _buildPostesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // En-tête moderne
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  flex: 4,
                  child: Text(
                    'INTITULÉ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MONTANT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 100),
              ],
            ),
          ),
          // Corps du tableau
          ..._postes.asMap().entries.map((entry) {
            final index = entry.key;
            final poste = entry.value;
            final posteId = poste['id'] as int;
            final isSelected = _selectedPosteId == posteId;
            final montant = _postesMontants[posteId] ?? 0.0;

            return Column(
              children: [
                if (index > 0) const Divider(height: 1, thickness: 1),
                Material(
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        setState(() => _selectedPosteId = posteId);
                        _loadLignesForPoste(posteId);
                      } else {
                        setState(() {
                          _selectedPosteId = null;
                          _selectedPosteLignes = [];
                          _expandedLignesIds.clear();
                          _lignesSousRubriques.clear();
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          // Icône
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSelected ? Icons.folder_open : Icons.folder,
                              size: 18,
                              color:
                                  isSelected
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Intitulé
                          Expanded(
                            flex: 4,
                            child: Text(
                              poste['intitule'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                color:
                                    isSelected
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          // Montant
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatAmount(montant),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                          // Actions
                          SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_canCreate)
                                  _buildActionButton(
                                    icon: Icons.edit,
                                    color: Colors.blue.shade400,
                                    onPressed:
                                        () => _editPoste(
                                          posteId,
                                          poste['intitule'] as String,
                                        ),
                                    tooltip: 'Modifier',
                                  ),
                                if (_canDelete)
                                  _buildActionButton(
                                    icon: Icons.delete,
                                    color: Colors.red.shade400,
                                    onPressed: () => _deletePoste(posteId),
                                    tooltip: 'Supprimer',
                                  ),
                                _buildActionButton(
                                  icon:
                                      isSelected
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade500,
                                  onPressed: () {
                                    if (!isSelected) {
                                      setState(
                                        () => _selectedPosteId = posteId,
                                      );
                                      _loadLignesForPoste(posteId);
                                    } else {
                                      setState(() {
                                        _selectedPosteId = null;
                                        _selectedPosteLignes = [];
                                        _expandedLignesIds.clear();
                                        _lignesSousRubriques.clear();
                                      });
                                    }
                                  },
                                  tooltip:
                                      isSelected ? 'Réduire' : 'Développer',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Remplacer la méthode _buildLignesTable() par :

  Widget _buildLignesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // En-tête moderne
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 80),
                Expanded(
                  flex: 4,
                  child: Text(
                    'INTITULÉ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MONTANT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 130),
              ],
            ),
          ),
          // Corps : lignes + sous-rubriques
          ..._selectedPosteLignes.asMap().entries.map((entry) {
            final index = entry.key;
            final ligne = entry.value;
            final ligneId = ligne['id'] as int;
            final isExpanded = _expandedLignesIds.contains(ligneId);
            final sousRubriques = _lignesSousRubriques[ligneId] ?? [];
            final montant = _lignesMontants[ligneId] ?? 0.0;

            return Column(
              children: [
                if (index > 0) const Divider(height: 1, thickness: 1),
                // Ligne principale
                Material(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Badge code
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            ligne['code'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Intitulé
                        Expanded(
                          flex: 4,
                          child: Text(
                            ligne['intitule'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        // Montant
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatAmount(montant),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                        // Actions
                        SizedBox(
                          width: 130,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_canCreate)
                                _buildActionButton(
                                  icon: Icons.edit,
                                  color: Colors.blue.shade400,
                                  onPressed:
                                      () => _editLigne(
                                        ligneId,
                                        ligne['code'] as String,
                                        ligne['intitule'] as String,
                                      ),
                                  tooltip: 'Modifier',
                                ),
                              if (_canCreate)
                                _buildActionButton(
                                  icon: Icons.add,
                                  color: Colors.green.shade600,
                                  onPressed: () => _createSousRubrique(ligneId),
                                  tooltip: 'Ajouter sous-rubrique',
                                ),
                              if (_canDelete)
                                _buildActionButton(
                                  icon: Icons.delete,
                                  color: Colors.red.shade400,
                                  onPressed: () => _deleteLigne(ligneId),
                                  tooltip: 'Supprimer',
                                ),
                              _buildActionButton(
                                icon:
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                color: Colors.grey.shade500,
                                onPressed: () {
                                  if (!isExpanded) {
                                    _loadSousRubriquesForLigne(ligneId);
                                  }
                                  setState(() {
                                    if (_expandedLignesIds.contains(ligneId)) {
                                      _expandedLignesIds.remove(ligneId);
                                    } else {
                                      _expandedLignesIds.add(ligneId);
                                    }
                                  });
                                },
                                tooltip: isExpanded ? 'Réduire' : 'Développer',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sous-rubriques
                if (isExpanded && sousRubriques.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(
                      left: 80,
                      right: 20,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        // En-tête sous-rubriques
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'SOUS-RUBRIQUES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'MONTANT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 72),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        ...sousRubriques.asMap().entries.map((srEntry) {
                          final srIndex = srEntry.key;
                          final sr = srEntry.value;

                          return Column(
                            children: [
                              if (srIndex > 0) const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Indentation
                                    Container(
                                      width: 4,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Intitulé
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        sr['intitule'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Montant
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatAmount(
                                          (sr['montant'] as num?)?.toDouble(),
                                        ),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    // Actions
                                    SizedBox(
                                      width: 72,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (_canCreate)
                                            _buildActionButton(
                                              icon: Icons.edit,
                                              size: 16,
                                              color: Colors.blue.shade400,
                                              onPressed:
                                                  () => _editSousRubrique(
                                                    sr['id'] as int,
                                                    sr['intitule'] as String,
                                                    (sr['montant'] as num?)
                                                            ?.toDouble() ??
                                                        0.0,
                                                    ligneId,
                                                  ),
                                              tooltip: 'Modifier',
                                            ),
                                          if (_canDelete)
                                            _buildActionButton(
                                              icon: Icons.delete,
                                              size: 16,
                                              color: Colors.red.shade400,
                                              onPressed:
                                                  () => _deleteSousRubrique(
                                                    sr['id'] as int,
                                                  ),
                                              tooltip: 'Supprimer',
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /*  Widget _buildLignesHeader() {
    // Remplacé par le tableau unifié dans _buildLignesTable
    return const SizedBox.shrink();
  }

  Widget _buildLigneRow(Map<String, dynamic> ligne, {bool isFirst = false}) {
    // Remplacé par _buildLignesTable - stub conservé pour compatibilité
    return const SizedBox.shrink();
  } */

  Future<void> _createPoste() async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Nouveau poste budgétaire'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Intitulé *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Ex: Frais de personnel',
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          controller.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Créer'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true && controller.text.isNotEmpty) {
      try {
        await AuthService.createPosteBudgetaire(
          budgetId: widget.budget['id'] as int,
          intitule: controller.text,
        );
        _loadPostes();
        widget.onRefresh();
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

  Future<void> _editPoste(int posteId, String currentIntitule) async {
    final controller = TextEditingController(text: currentIntitule);

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Modifier le poste budgétaire'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Intitulé *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          controller.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true && controller.text.isNotEmpty) {
      try {
        await AuthService.updatePosteBudgetaire(
          posteId: posteId,
          intitule: controller.text,
        );
        _loadPostes();
        widget.onRefresh();
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

  Future<void> _createLigne(int posteId) async {
    final codeController = TextEditingController();
    final intituleController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Nouvelle ligne budgétaire'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Code *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Ex: 601000',
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: intituleController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Intitulé *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Ex: Salaires du personnel permanent',
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          codeController.text.isNotEmpty &&
                                  intituleController.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Créer'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true) {
      try {
        await AuthService.createLigneBudgetaire(
          posteBudgetaireId: posteId,
          code: codeController.text,
          intitule: intituleController.text,
        );
        await _loadLignesForPoste(posteId);
        widget.onRefresh();
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

  Future<void> _editLigne(
    int ligneId,
    String currentCode,
    String currentIntitule,
  ) async {
    final codeController = TextEditingController(text: currentCode);
    final intituleController = TextEditingController(text: currentIntitule);

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Modifier la ligne budgétaire'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Code *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: intituleController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Intitulé *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          codeController.text.isNotEmpty &&
                                  intituleController.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true) {
      try {
        await AuthService.updateLigneBudgetaire(
          ligneId: ligneId,
          code: codeController.text,
          intitule: intituleController.text,
        );
        await _loadLignesForPoste(_selectedPosteId!);
        widget.onRefresh();
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

  Future<void> _createSousRubrique(int ligneId) async {
    final intituleController = TextEditingController();
    final montantController = TextEditingController();
    Map<String, dynamic>? selectedCompte;
    List<Map<String, dynamic>> comptes = [];
    bool isLoadingComptes = true;

    // Charger les comptes au démarrage du dialog
    try {
      final comptesObjects = await AuthService.getComptes();
      comptes =
          comptesObjects
              .map(
                (c) => {
                  'id': c.id,
                  'numeroCompte': c.numeroCompte,
                  'intitule': c.intitule,
                },
              )
              .toList();
      isLoadingComptes = false;
    } catch (e) {
      isLoadingComptes = false;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Nouvelle sous-rubrique'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: intituleController,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'Ex: Chef de projet',
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: montantController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Montant',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: '0.00',
                            prefixText: 'XOF ',
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isLoadingComptes)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedCompte,
                            hint: const Text('Sélectionner un compte'),
                            items:
                                comptes
                                    .map(
                                      (compte) => DropdownMenuItem(
                                        value: compte,
                                        child: Text(
                                          '${compte['numeroCompte']} - ${compte['intitule']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() => selectedCompte = value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Compte',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          intituleController.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Créer'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true) {
      try {
        final montant =
            montantController.text.isEmpty
                ? 0.0
                : double.parse(montantController.text);
        final compteId =
            selectedCompte != null
                ? int.tryParse(selectedCompte!['id'].toString())
                : null;

        await AuthService.createSousRubrique(
          ligneBudgetaireId: ligneId,
          intitule: intituleController.text,
          montant: montant,
          compteId: compteId,
        );
        await _loadSousRubriquesForLigne(ligneId);

        // Recalculer le montant total de la ligne
        final sousRubriques = await AuthService.getSousRubriques(ligneId);
        final montantTotal = sousRubriques.fold<double>(
          0.0,
          (sum, sr) => sum + ((sr['montant'] as num?)?.toDouble() ?? 0.0),
        );
        if (mounted) {
          setState(() {
            _lignesMontants[ligneId] = montantTotal;
          });
        }

        widget.onRefresh();
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

  Future<void> _editSousRubrique(
    int sousRubriqueId,
    String currentIntitule,
    double currentMontant,
    int ligneId,
  ) async {
    final intituleController = TextEditingController(text: currentIntitule);
    final montantController = TextEditingController(
      text: currentMontant.toString(),
    );

    // Charger les comptes au démarrage du dialog
    try {
      await AuthService.getComptes();
    } catch (e) {
      // Erreur lors du chargement des comptes
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Modifier la sous-rubrique'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: intituleController,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: montantController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Montant *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          intituleController.text.isNotEmpty &&
                                  montantController.text.isNotEmpty
                              ? () => Navigator.pop(context, true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
          ),
    );

    if (confirm == true && intituleController.text.isNotEmpty) {
      try {
        final montant =
            montantController.text.isEmpty
                ? 0.0
                : double.parse(montantController.text);

        await AuthService.updateSousRubrique(
          sousRubriqueId: sousRubriqueId,
          intitule: intituleController.text,
          montant: montant,
        );

        // Charger les sous-rubriques mises à jour pour recalculer
        await _loadSousRubriquesForLigne(ligneId);

        // Recalculer le montant total de la ligne
        final sousRubriques = await AuthService.getSousRubriques(ligneId);
        final montantTotal = sousRubriques.fold<double>(
          0.0,
          (sum, sr) => sum + ((sr['montant'] as num?)?.toDouble() ?? 0.0),
        );
        if (mounted) {
          setState(() {
            _lignesMontants[ligneId] = montantTotal;
          });
        }

        widget.onRefresh();
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

  Future<void> _deletePoste(int posteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce poste ?',
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

    if (confirm == true) {
      try {
        await AuthService.deletePosteBudgetaire(posteId);
        _loadPostes();
        widget.onRefresh();
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

  Future<void> _deleteLigne(int ligneId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette ligne ?',
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

    if (confirm == true) {
      try {
        await AuthService.deleteLigneBudgetaire(ligneId);
        if (_selectedPosteId != null) {
          await _loadLignesForPoste(_selectedPosteId!);
        }
        widget.onRefresh();
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

  Future<void> _deleteSousRubrique(int sousRubriqueId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette sous-rubrique ?',
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

    if (confirm == true) {
      try {
        await AuthService.deleteSousRubrique(sousRubriqueId);

        // Recalculer les montants de toutes les lignes étendues
        for (final ligneId in _expandedLignesIds) {
          try {
            final sousRubriques = await AuthService.getSousRubriques(ligneId);
            final montantTotal = sousRubriques.fold<double>(
              0.0,
              (sum, sr) => sum + ((sr['montant'] as num?)?.toDouble() ?? 0.0),
            );
            if (mounted) {
              setState(() {
                _lignesMontants[ligneId] = montantTotal;
                _lignesSousRubriques[ligneId] = sousRubriques;
              });
            }
          } catch (e) {
            // Erreur silencieuse
          }
        }

        widget.onRefresh();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.budget['projet_designation']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              widget.budget['bailleur_designation'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPostes,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistiques
                    Row(
                      children: [
                        Expanded(
                          child: _buildMontantCard(
                            'Montant total',
                            _montantTotal,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Postes budgétaires',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_postes.length}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Section Postes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Postes Budgétaires',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        if (_canCreate)
                          ElevatedButton.icon(
                            onPressed: _createPoste,
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text('Nouveau poste'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_postes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun poste budgétaire',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajoutez votre premier poste budgétaire',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildPostesTable(),

                    // Section Lignes
                    if (_selectedPosteId != null) ...[
                      const SizedBox(height: 40),
                      const Divider(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lignes Budgétaires',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                          if (_canCreate)
                            ElevatedButton.icon(
                              onPressed: () => _createLigne(_selectedPosteId!),
                              icon: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text('Nouvelle ligne'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_isLoadingLignes)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_selectedPosteLignes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune ligne budgétaire',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez votre première ligne budgétaire',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildLignesTable(),
                    ],
                  ],
                ),
              ),
    );
  }
}

class _CreateBudgetDialog extends StatefulWidget {
  final List<Map<String, dynamic>> projets;
  final int exerciceId;
  final VoidCallback onBudgetCreated;

  const _CreateBudgetDialog({
    required this.projets,
    required this.exerciceId,
    required this.onBudgetCreated,
  });

  @override
  State<_CreateBudgetDialog> createState() => __CreateBudgetDialogState();
}

class __CreateBudgetDialogState extends State<_CreateBudgetDialog> {
  int? selectedProjetId;
  int? selectedBailleurId;
  List<Map<String, dynamic>> bailleursFiltres = [];
  bool isLoadingBailleurs = false;

  Future<void> _loadBailleurs(int projetId) async {
    setState(() => isLoadingBailleurs = true);

    try {
      final bailleurs = await AuthService.getBailleursForProjet(projetId);

      if (mounted) {
        setState(() {
          bailleursFiltres = bailleurs;
          selectedBailleurId = null;
          isLoadingBailleurs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingBailleurs = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createBudgetAndContinue() async {
    if (selectedProjetId == null || selectedBailleurId == null) {
      return;
    }

    try {
      await AuthService.createBudget(
        projetId: selectedProjetId!,
        bailleurId: selectedBailleurId!,
        exerciceId: widget.exerciceId,
      );
      if (mounted) {
        widget.onBudgetCreated();

        // Réinitialiser les champs
        setState(() {
          selectedProjetId = null;
          selectedBailleurId = null;
          bailleursFiltres = [];
          isLoadingBailleurs = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget créé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Vérifier si c'est une erreur de contrainte UNIQUE
        final errorMessage = e.toString();
        String displayMessage = 'Erreur: $e';

        if (errorMessage.contains('existe déjà pour cette combinaison')) {
          displayMessage =
              'Un budget existe déjà pour cette combinaison projet + bailleur + exercice.\n'
              'Rafraîchissez la page pour voir les budgets à jour.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _createBudget() async {
    if (selectedProjetId == null || selectedBailleurId == null) {
      return;
    }

    try {
      await AuthService.createBudget(
        projetId: selectedProjetId!,
        bailleurId: selectedBailleurId!,
        exerciceId: widget.exerciceId,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onBudgetCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Vérifier si c'est une erreur de contrainte UNIQUE
        final errorMessage = e.toString();
        String displayMessage = 'Erreur: $e';

        if (errorMessage.contains('existe déjà pour cette combinaison')) {
          displayMessage =
              'Un budget existe déjà pour cette combinaison projet + bailleur + exercice.\n'
              'Rafraîchissez la page pour voir les budgets à jour.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un nouveau budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: selectedProjetId,
              hint: const Text('Sélectionner un projet'),
              items:
                  widget.projets
                      .where((p) => p['deleted_at'] == null)
                      .map(
                        (p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(
                            '${p['code']} - ${p['designation']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() => selectedProjetId = value);
                  await _loadBailleurs(value);
                } else {
                  setState(() {
                    selectedProjetId = null;
                    selectedBailleurId = null;
                    bailleursFiltres = [];
                  });
                }
              },
              decoration: InputDecoration(
                labelText: 'Projet *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            if (isLoadingBailleurs)
              const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              DropdownButtonFormField<int>(
                value: selectedBailleurId,
                hint: const Text('Sélectionner un bailleur'),
                items:
                    bailleursFiltres
                        .map(
                          (b) => DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(
                              '${b['sigle']} - ${b['designation']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() => selectedBailleurId = value);
                },
                decoration: InputDecoration(
                  labelText: 'Bailleur *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                isExpanded: true,
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
          onPressed:
              selectedProjetId != null && selectedBailleurId != null
                  ? _createBudget
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Créer'),
        ),
        ElevatedButton.icon(
          onPressed:
              selectedProjetId != null && selectedBailleurId != null
                  ? _createBudgetAndContinue
                  : null,
          icon: const Icon(Icons.add_circle),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          label: const Text('Ajouter et continuer'),
        ),
      ],
    );
  }
}
