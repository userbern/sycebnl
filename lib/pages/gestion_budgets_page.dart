import 'dart:math' as math;
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
  // ── Données ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _projets = [];
  List<Map<String, dynamic>> _filteredBudgets = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  // Montants chargés en arrière-plan
  final Map<int, double> _montantsTotaux = {};

  // Filtres
  String? _filterBailleur;
  String? _filterStatut;
  List<String> _bailleurs = [];

  // Sélection / panneau de détail
  Map<String, dynamic>? _selectedBudget;

  // Pagination
  int _itemsPerPage = 10;
  int _currentPage = 1;

  // ── Pagination ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _paginatedBudgets {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = math.min(start + _itemsPerPage, _filteredBudgets.length);
    if (start >= _filteredBudgets.length) return [];
    return _filteredBudgets.sublist(start, end);
  }

  int get _totalPages => math.max(1, (_filteredBudgets.length / _itemsPerPage).ceil());

  // ── Permissions ───────────────────────────────────────────────────────────
  bool get _canCreate =>
      widget.userSession == null ? true : widget.userSession!.canCreate('gestion_budgets');
  bool get _canDelete =>
      widget.userSession == null ? true : widget.userSession!.canDelete('gestion_budgets');

  // ── Cycle de vie ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers financiers ────────────────────────────────────────────────────
  double _getMontantTotal(Map<String, dynamic> b) =>
      _montantsTotaux[b['id'] as int? ?? -1] ?? 0.0;

  bool _hasMontant(Map<String, dynamic> b) =>
      _montantsTotaux.containsKey(b['id'] as int? ?? -1);

  // Pas d'API de dépenses sur la liste → placeholder 0 (rempli si disponible)
  double _getMontantRealise(Map<String, dynamic> b) => 0.0;

  double _getSolde(Map<String, dynamic> b) =>
      _getMontantTotal(b) - _getMontantRealise(b);

  double _getTaux(Map<String, dynamic> b) {
    final total = _getMontantTotal(b);
    if (total <= 0) return 0.0;
    return math.min(150, _getMontantRealise(b) / total * 100);
  }

  String _getStatut(Map<String, dynamic> b) {
    if (!_hasMontant(b)) return 'Chargement';
    final total = _getMontantTotal(b);
    if (total <= 0) return 'Non budgété';
    final taux = _getTaux(b);
    if (taux >= 100) return 'Exécuté';
    if (taux > 0) return 'En cours';
    return 'Non démarré';
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'Exécuté': return const Color(0xFF2E7D32);
      case 'En cours': return const Color(0xFF1565C0);
      case 'Non démarré': return const Color(0xFFE65100);
      case 'Non budgété': return Colors.grey.shade500;
      default: return Colors.grey.shade400;
    }
  }

  Color _getTauxColor(double taux) {
    if (taux > 100) return const Color(0xFFB71C1C);
    if (taux >= 80) return const Color(0xFF2E7D32);
    if (taux >= 40) return const Color(0xFF1565C0);
    if (taux > 0) return const Color(0xFFE65100);
    return Colors.grey.shade400;
  }

  // ── Formatage ─────────────────────────────────────────────────────────────
  String _fmt(double v) {
    if (v == 0) return '0 XOF';
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000000) {
      final s = abs.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
      return '$sign$s XOF';
    }
    final s = abs.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$sign$s XOF';
  }

  String _fmtShort(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000000000) return '$sign${(abs / 1000000000).toStringAsFixed(1)} Md';
    if (abs >= 1000000) return '$sign${(abs / 1000000).toStringAsFixed(1)} M';
    if (abs >= 1000) return '$sign${(abs / 1000).toStringAsFixed(0)} K';
    return '$sign${abs.toStringAsFixed(0)}';
  }

  // ── Stats globales ────────────────────────────────────────────────────────
  double get _grandTotalBudget =>
      _filteredBudgets.fold(0.0, (s, b) => s + _getMontantTotal(b));
  double get _grandTotalRealise =>
      _filteredBudgets.fold(0.0, (s, b) => s + _getMontantRealise(b));
  double get _grandSolde => _grandTotalBudget - _grandTotalRealise;
  double get _tauxGlobal => _grandTotalBudget > 0
      ? math.min(100, _grandTotalRealise / _grandTotalBudget * 100)
      : 0.0;

  // ── Chargement données ────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    if (widget.exerciceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun exercice sélectionné'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final budgets = await AuthService.getBudgetsWithDetails(exerciceId: widget.exerciceId!);
      final projets = await AuthService.getProjetsWithBailleur();
      if (!mounted) return;

      // Extraire les bailleurs uniques
      final bailleurSet = <String>{};
      for (final b in budgets) {
        final d = b['bailleur_designation'] as String?;
        if (d != null && d.isNotEmpty) bailleurSet.add(d);
      }

      setState(() {
        _budgets = budgets;
        _projets = projets;
        _filteredBudgets = budgets;
        _bailleurs = bailleurSet.toList()..sort();
        _isLoading = false;
      });

      _loadFinancialData(budgets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadFinancialData(List<Map<String, dynamic>> budgets) async {
    for (final budget in budgets) {
      final id = budget['id'] as int?;
      if (id == null) continue;
      try {
        final montant = await AuthService.getMontantBudget(id);
        if (mounted) setState(() => _montantsTotaux[id] = montant);
      } catch (_) {
        if (mounted) setState(() => _montantsTotaux[id] = 0.0);
      }
    }
  }

  // ── Filtrage ──────────────────────────────────────────────────────────────
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBudgets = _budgets.where((b) {
        final matchSearch = query.isEmpty ||
            (b['projet_code'] ?? '').toString().toLowerCase().contains(query) ||
            (b['projet_designation'] ?? '').toString().toLowerCase().contains(query) ||
            (b['bailleur_sigle'] ?? '').toString().toLowerCase().contains(query) ||
            (b['bailleur_designation'] ?? '').toString().toLowerCase().contains(query);
        final matchBailleur = _filterBailleur == null ||
            b['bailleur_designation'] == _filterBailleur;
        final matchStatut = _filterStatut == null ||
            _getStatut(b) == _filterStatut;
        return matchSearch && matchBailleur && matchStatut;
      }).toList();
      _currentPage = 1;
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _filterBailleur = null;
      _filterStatut = null;
      _filteredBudgets = _budgets;
      _currentPage = 1;
      _selectedBudget = null;
    });
  }

  // ── Suppression ───────────────────────────────────────────────────────────
  Future<void> _deleteBudget(int budgetId, String projetDesignation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          const Text('Confirmer la suppression'),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            children: [
              const TextSpan(text: 'Voulez-vous vraiment supprimer le budget '),
              TextSpan(text: '"$projetDesignation"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' ?\n\nCette action supprimera également tous les postes et lignes budgétaires associés.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever, size: 18, color: Colors.white),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          const SnackBar(content: Text('Budget supprimé'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateBudgetDialog() {
    if (widget.exerciceId == null) return;
    showDialog(
      context: context,
      builder: (context) => _CreateBudgetDialog(
        projets: _projets,
        exerciceId: widget.exerciceId!,
        onBudgetCreated: _loadData,
      ),
    );
  }

  void _openBudgetDetails(Map<String, dynamic> budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetDetailsPage(
          budget: budget,
          userSession: widget.userSession,
          onRefresh: _loadData,
        ),
      ),
    );
  }

  // ── Widgets UI ────────────────────────────────────────────────────────────

  Widget _buildStatsCards() {
    return LayoutBuilder(builder: (context, constraints) {
      final w = (constraints.maxWidth - 36) / 4;
      return Row(
        children: [
          _statCard(icon: Icons.account_balance_wallet, label: 'Budgets', value: '${_filteredBudgets.length}', sub: 'actifs', color: Colors.blue.shade700, width: w),
          const SizedBox(width: 12),
          _statCard(icon: Icons.payments_outlined, label: 'Budget Total', value: _fmtShort(_grandTotalBudget), sub: 'XOF', color: Colors.green.shade700, width: w),
          const SizedBox(width: 12),
          _statCard(icon: Icons.trending_up, label: 'Exécuté', value: _fmtShort(_grandTotalRealise), sub: '${_tauxGlobal.toStringAsFixed(0)}% du total', color: Colors.orange.shade700, width: w),
          const SizedBox(width: 12),
          _statCard(icon: Icons.account_balance, label: 'Solde', value: _fmtShort(_grandSolde), sub: 'disponible', color: _grandSolde >= 0 ? Colors.purple.shade700 : Colors.red.shade700, width: w),
        ],
      );
    });
  }

  Widget _statCard({required IconData icon, required String label, required String value, required String sub, required Color color, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final hasActiveFilters = _filterBailleur != null || _filterStatut != null || _searchController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Recherche
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher projet, bailleur…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Bailleur
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _filterBailleur != null ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filterBailleur != null ? Colors.blue.shade300 : Colors.grey.shade300),
                ),
                child: DropdownButton<String?>(
                  value: _filterBailleur,
                  hint: Text('Bailleur', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les bailleurs')),
                    ..._bailleurs.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) { setState(() => _filterBailleur = v); _applyFilters(); },
                ),
              ),
            ),
          ),
          // Statut
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _filterStatut != null ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filterStatut != null ? Colors.blue.shade300 : Colors.grey.shade300),
                ),
                child: DropdownButton<String?>(
                  value: _filterStatut,
                  hint: Text('Statut', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                    DropdownMenuItem(value: 'Non démarré', child: Text('Non démarré')),
                    DropdownMenuItem(value: 'En cours', child: Text('En cours')),
                    DropdownMenuItem(value: 'Exécuté', child: Text('Exécuté')),
                    DropdownMenuItem(value: 'Non budgété', child: Text('Non budgété')),
                  ],
                  onChanged: (v) { setState(() => _filterStatut = v); _applyFilters(); },
                ),
              ),
            ),
          ),
          // Reset
          if (hasActiveFilters)
            SizedBox(
              height: 36,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Réinitialiser', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          const Spacer(),
          // Nouveau budget
          if (_canCreate)
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _showCreateBudgetDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Nouveau budget'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_filteredBudgets.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty || _filterBailleur != null || _filterStatut != null
                    ? 'Aucun résultat pour ces filtres'
                    : 'Aucun budget enregistré',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 700) {
                return _buildDesktopTable(constraints);
              } else {
                return ListView.separated(
                  itemCount: _paginatedBudgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _buildMobileCard(_paginatedBudgets[i]),
                );
              }
            }),
          ),
          _buildDetailPanel(),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BoxConstraints constraints) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade700),
            headingRowHeight: 42,
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.3),
            dataRowMinHeight: 52,
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
              verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            dataRowMaxHeight: 64,
            columnSpacing: 16,
            horizontalMargin: 16,
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('PROJET')),
              DataColumn(label: Text('BAILLEUR')),
              DataColumn(label: Text('BUDGET TOTAL'), numeric: true),
              DataColumn(label: Text('DÉPENSES'), numeric: true),
              DataColumn(label: Text('SOLDE'), numeric: true),
              DataColumn(label: Text('TAUX D\'EXÉCUTION')),
              DataColumn(label: Text('STATUT')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: _paginatedBudgets.map((budget) {
              final isSelected = _selectedBudget?['id'] == budget['id'];
              final montantTotal = _getMontantTotal(budget);
              final realise = _getMontantRealise(budget);
              final solde = _getSolde(budget);
              final taux = _getTaux(budget);
              final statut = _getStatut(budget);
              final tauxColor = _getTauxColor(taux);
              final hasMontant = _hasMontant(budget);

              return DataRow(
                selected: isSelected,
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (isSelected) return Colors.blue.shade50;
                  if (states.contains(WidgetState.hovered)) return const Color(0xFFF0F6FF);
                  return Colors.white;
                }),
                onSelectChanged: (_) {
                  setState(() => _selectedBudget = isSelected ? null : budget);
                },
                cells: [
                  // Projet
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(budget['projet_designation'] ?? 'N/A',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                            overflow: TextOverflow.ellipsis, maxLines: 2),
                          if ((budget['projet_code'] ?? '').toString().isNotEmpty)
                            Text(budget['projet_code'].toString(),
                              style: TextStyle(fontSize: 10, color: Colors.blue.shade500)),
                        ],
                      ),
                    ),
                  ),
                  // Bailleur
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((budget['bailleur_sigle'] ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(budget['bailleur_sigle'].toString(),
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          Text(budget['bailleur_designation'] ?? 'N/A',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis, maxLines: 2),
                        ],
                      ),
                    ),
                  ),
                  // Budget total
                  DataCell(
                    hasMontant
                        ? Text(_fmt(montantTotal),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800))
                        : SizedBox(width: 60, child: LinearProgressIndicator(minHeight: 3, color: Colors.blue.shade200, backgroundColor: Colors.grey.shade100)),
                  ),
                  // Dépenses
                  DataCell(
                    Text(_fmt(realise),
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
                  ),
                  // Solde
                  DataCell(
                    Text(_fmt(solde),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: solde >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                  ),
                  // Taux
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: hasMontant
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('${taux.toStringAsFixed(1)}%',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tauxColor)),
                                    if (taux > 100) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.warning_amber, size: 13, color: Colors.red.shade700),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: math.min(1.0, taux / 100),
                                    backgroundColor: Colors.grey.shade100,
                                    color: tauxColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  // Statut
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatutColor(statut).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatutColor(statut).withValues(alpha: 0.3)),
                      ),
                      child: Text(statut,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getStatutColor(statut))),
                    ),
                  ),
                  // Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openBudgetDetails(budget),
                          icon: Icon(Icons.open_in_new, size: 13, color: Colors.blue.shade600),
                          label: Text('Détails', style: TextStyle(fontSize: 11, color: Colors.blue.shade600)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        if (_canDelete)
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                            onPressed: () => _deleteBudget(budget['id'] as int, budget['projet_designation'] ?? ''),
                            tooltip: 'Supprimer',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedBudget == null) return const SizedBox.shrink();
    final b = _selectedBudget!;
    final montant = _getMontantTotal(b);
    final realise = _getMontantRealise(b);
    final solde = _getSolde(b);
    final taux = _getTaux(b);
    final tauxColor = _getTauxColor(taux);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(6)),
                child: Text(b['bailleur_sigle'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(b['projet_designation'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: () => _openBudgetDetails(b),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Ouvrir'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
              ),
              if (_canDelete)
                TextButton.icon(
                  onPressed: () => _deleteBudget(b['id'] as int, b['projet_designation'] ?? ''),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                onPressed: () => setState(() => _selectedBudget = null),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _detailStatItem('Budget', _fmt(montant), Colors.blue.shade700),
              const SizedBox(width: 24),
              _detailStatItem('Dépenses', _fmt(realise), Colors.orange.shade700),
              const SizedBox(width: 24),
              _detailStatItem('Solde', _fmt(solde), solde >= 0 ? Colors.green.shade700 : Colors.red.shade700),
              const SizedBox(width: 24),
              _detailStatItem('Taux', '${taux.toStringAsFixed(1)}%', tauxColor),
              const Spacer(),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: math.min(1.0, taux / 100),
                backgroundColor: Colors.grey.shade100,
                color: tauxColor,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> budget) {
    final montant = _getMontantTotal(budget);
    final taux = _getTaux(budget);
    final tauxColor = _getTauxColor(taux);
    final statut = _getStatut(budget);

    return GestureDetector(
      onTap: () => setState(() => _selectedBudget = _selectedBudget?['id'] == budget['id'] ? null : budget),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _selectedBudget?['id'] == budget['id'] ? Colors.blue.shade300 : Colors.grey.shade200),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(budget['projet_designation'] ?? 'N/A',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(budget['bailleur_designation'] ?? 'N/A',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(_fmt(montant), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatutColor(statut).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statut, style: TextStyle(fontSize: 10, color: _getStatutColor(statut), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: math.min(1.0, taux / 100), backgroundColor: Colors.grey.shade100, color: tauxColor, minHeight: 4),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.open_in_new, size: 16, color: Colors.blue.shade600),
                    onPressed: () => _openBudgetDetails(budget),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  if (_canDelete)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                      onPressed: () => _deleteBudget(budget['id'] as int, budget['projet_designation'] ?? ''),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1 && _filteredBudgets.length <= _itemsPerPage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('Lignes/page:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: _itemsPerPage,
          isDense: true,
          items: [10, 15, 25, 50].map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { if (v != null) setState(() { _itemsPerPage = v; _currentPage = 1; }); },
          underline: const SizedBox.shrink(),
        ),
        const SizedBox(width: 16),
        Text('$_currentPage / $_totalPages', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        _pagBtn(Icons.chevron_left, _currentPage > 1, () => setState(() => _currentPage--)),
        const SizedBox(width: 4),
        _pagBtn(Icons.chevron_right, _currentPage < _totalPages, () => setState(() => _currentPage++)),
      ]),
    );
  }

  Widget _pagBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return SizedBox(
      width: 28, height: 28,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.blue.shade700 : Colors.grey.shade200,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            HardwareKeyboard.instance.isControlPressed &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            _canCreate) {
          _showCreateBudgetDialog();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Gestion des Budgets'),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); },
                ),
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 12),
                    _buildFilterBar(),
                    const SizedBox(height: 10),
                    // Titre + compteur
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Text(
                          '${_filteredBudgets.length} budget${_filteredBudgets.length != 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        if (_filteredBudgets.length < _budgets.length) ...[
                          const SizedBox(width: 6),
                          Text('(${_budgets.length} au total)', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ]),
                    ),
                    _buildMainContent(),
                  ],
                ),
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

  bool get _canCreate =>
      widget.userSession == null ? true : widget.userSession!.canCreate('gestion_budgets');
  bool get _canModify =>
      widget.userSession == null ? true : widget.userSession!.canModify('gestion_budgets');
  bool get _canDelete =>
      widget.userSession == null ? true : widget.userSession!.canDelete('gestion_budgets');

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
                                if (_canModify)
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
                              if (_canModify)
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
                                          if (_canModify)
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
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
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
              autofocus: true,
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
          icon: const Icon(Icons.add_circle, color: Colors.white),
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
