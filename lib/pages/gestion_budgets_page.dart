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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icône
          SizedBox(
            width: 56,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.blue.shade200,
                size: 20,
              ),
            ),
          ),
          // Colonne PROJET
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => _showBudgetDetails(budget),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget['projet_designation'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
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
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => _showBudgetDetails(budget),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          budget['bailleur_sigle'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget['bailleur_designation'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_canUpdate)
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue.shade400,
                      ),
                      onPressed: () => _showBudgetDetails(budget),
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
                      onPressed: () => _deleteBudget(budget['id'] as int),
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
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.isControlPressed &&
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
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 56), // Espace pour l'icône
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
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
                                padding: const EdgeInsets.only(left: 16),
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
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _filteredBudgets.length,
                                    separatorBuilder:
                                        (context, index) => Divider(
                                          height: 1,
                                          color: Colors.grey.shade100,
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

  Widget _buildMontantCard(String title, double montant) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${montant.toStringAsFixed(2)} XOF',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosteHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: const Row(
        children: [
          SizedBox(width: 56),
          Expanded(
            flex: 3,
            child: Text(
              'INTITULÉ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'MONTANT',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPosteRow(Map<String, dynamic> poste) {
    final posteId = poste['id'] as int;
    final isSelected = _selectedPosteId == posteId;
    final montant = _postesMontants[posteId] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ListTile(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            Icons.folder,
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          poste['intitule'] as String,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.blue.shade800 : Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${montant.toStringAsFixed(2)} XOF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              isSelected ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey.shade600,
              size: 20,
            ),
            if (_canCreate) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed:
                    () => _editPoste(posteId, poste['intitule'] as String),
                tooltip: 'Modifier',
                color: Colors.blue.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
            if (_canDelete) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: () => _deletePoste(posteId),
                tooltip: 'Supprimer',
                color: Colors.red.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLignesHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: const Row(
        children: [
          SizedBox(width: 72),
          Expanded(
            flex: 2,
            child: Text(
              'CODE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'INTITULÉ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'MONTANT',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 100),
        ],
      ),
    );
  }

  Widget _buildLigneRow(Map<String, dynamic> ligne, {bool isFirst = false}) {
    final ligneId = ligne['id'] as int;
    final isExpanded = _expandedLignesIds.contains(ligneId);
    final sousRubriques = _lignesSousRubriques[ligneId] ?? [];
    final montant = _lignesMontants[ligneId] ?? 0.0;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isFirst ? Colors.transparent : Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: 72,
              right: 16,
              top: 8,
              bottom: sousRubriques.isNotEmpty && isExpanded ? 0 : 8,
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    ligne['code'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    ligne['intitule'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${montant.toStringAsFixed(2)} XOF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                if (_canCreate)
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: Colors.blue.shade600,
                    ),
                    onPressed:
                        () => _editLigne(
                          ligneId,
                          ligne['code'] as String,
                          ligne['intitule'] as String,
                        ),
                    tooltip: 'Modifier',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                if (_canCreate)
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.blue.shade600,
                    ),
                    onPressed: () => _createSousRubrique(ligneId),
                    tooltip: 'Ajouter une sous-rubrique',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                if (_canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      size: 18,
                      color: Colors.red.shade600,
                    ),
                    onPressed: () => _deleteLigne(ligneId),
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
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
        if (isExpanded && sousRubriques.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(left: 88, right: 16, bottom: 8),
            child: Column(
              children:
                  sousRubriques.map((sr) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sr['intitule'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${(sr['montant'] as num?)?.toStringAsFixed(2) ?? '0.00'} XOF',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_canCreate)
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              onPressed:
                                  () => _editSousRubrique(
                                    sr['id'] as int,
                                    sr['intitule'] as String,
                                    (sr['montant'] as num?)?.toDouble() ?? 0.0,
                                    ligneId,
                                  ),
                              tooltip: 'Modifier',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          if (_canDelete)
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: 16,
                                color: Colors.red.shade600,
                              ),
                              onPressed:
                                  () => _deleteSousRubrique(sr['id'] as int),
                              tooltip: 'Supprimer',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

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
              '${widget.budget['projet_code']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.budget['bailleur_sigle'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Postes budgétaires',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_postes.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
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
                      Column(
                        children: [
                          _buildPosteHeader(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _postes.length,
                              separatorBuilder:
                                  (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                              itemBuilder: (context, index) {
                                return _buildPosteRow(_postes[index]);
                              },
                            ),
                          ),
                        ],
                      ),

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
                        Column(
                          children: [
                            _buildLignesHeader(),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedPosteLignes.length,
                                separatorBuilder:
                                    (context, index) => const SizedBox.shrink(),
                                itemBuilder: (context, index) {
                                  return _buildLigneRow(
                                    _selectedPosteLignes[index],
                                    isFirst: index == 0,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
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
      ],
    );
  }
}
