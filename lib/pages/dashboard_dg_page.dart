import 'package:flutter/material.dart';

import '../models/kpi.dart';
import '../models/compte.dart';
import '../models/exercice.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/kpi_service.dart';
import '../services/local_repository.dart';
import '../widgets/simple_charts.dart';

/// Contrôleur exposant l'état de navigation interne (drill-down) de
/// [DashboardDgPage] à un parent (ex. le bouton « précédent » global de
/// `HomePage`) : permet de remonter d'un niveau de détail avant de changer
/// de page, plutôt que de perdre cet état d'un coup. Notifie ses auditeurs
/// à chaque changement de niveau pour que le parent puisse rafraîchir
/// l'état (activé/désactivé) de son propre bouton « précédent ».
class DashboardDgController extends ChangeNotifier {
  bool Function()? _isAtRoot;
  VoidCallback? _popLevel;

  /// `true` si la page est à la grille des indicateurs (aucun détail
  /// ouvert). `true` par défaut si le contrôleur n'est rattaché à aucune
  /// page (permet à l'appelant de rester permissif tant que la page n'est
  /// pas montée).
  bool get isAtRoot => _isAtRoot?.call() ?? true;

  /// Remonte d'un niveau de détail (écritures → comptes → groupes → grille).
  /// Retourne `true` si un niveau a été remonté (l'appelant ne doit alors
  /// pas changer de page), `false` si la page était déjà à la racine (ou non
  /// montée) : l'appelant doit alors traiter sa propre navigation.
  bool popLevel() {
    if (isAtRoot) return false;
    _popLevel?.call();
    return true;
  }

  void _attach({
    required bool Function() isAtRoot,
    required VoidCallback popLevel,
  }) {
    _isAtRoot = isAtRoot;
    _popLevel = popLevel;
  }

  void _detach() {
    _isAtRoot = null;
    _popLevel = null;
  }

  void _notify() => notifyListeners();
}

/// Dashboard KPI destiné au DG : indicateurs calculés automatiquement à
/// partir des soldes comptables (aucune saisie manuelle de KPI), avec
/// drill-down Classe → Groupe → Compte → Écritures sur chaque indicateur
/// adossé à un périmètre de comptes.
class DashboardDgPage extends StatefulWidget {
  final int? exerciceId;
  final bool showAppBar;

  /// Optionnel : permet à un parent (ex. `HomePage`) de connaître et de
  /// piloter la navigation interne (drill-down) de cette page, pour que son
  /// propre bouton « précédent » remonte d'abord les niveaux de détail avant
  /// de quitter la page. Sans effet sur le fonctionnement de la page si
  /// omis.
  final DashboardDgController? controller;

  const DashboardDgPage({
    super.key,
    this.exerciceId,
    this.showAppBar = true,
    this.controller,
  });

  @override
  State<DashboardDgPage> createState() => _DashboardDgPageState();
}

/// Définition statique d'un KPI adossé à un périmètre de comptes : préfixes
/// de classe à explorer et, pour les KPI dérivés d'un signe de solde
/// (créances/dettes), le filtre de signe appliqué au niveau "compte".
class _KpiDef {
  final String code;
  final String libelle;
  final IconData icon;
  final Color color;
  final List<String> classePrefixes;
  final int? filtreSigne; // 1 = solde > 0 uniquement, -1 = solde < 0 uniquement

  const _KpiDef({
    required this.code,
    required this.libelle,
    required this.icon,
    required this.color,
    required this.classePrefixes,
    this.filtreSigne,
  });
}

/// Une ligne de répartition affichée sous une carte "Détail par indicateur"
/// (ex. Trésorerie → Comptes bancaires / Caisses / Autres disponibilités).
/// Toujours dérivée de [SoldeCompte.nature], jamais d'une valeur inventée.
class _BreakdownItem {
  final String label;
  final double valeur;
  const _BreakdownItem(this.label, this.valeur);
}

enum _DrillLevel { grid, groupes, comptes, ecritures }

class _DashboardDgPageState extends State<DashboardDgPage> {
  static const _kpiDefs = <_KpiDef>[
    _KpiDef(
      code: 'resultat',
      libelle: 'Résultat de l\'exercice',
      icon: Icons.balance,
      color: Color(0xFF6A1B9A),
      classePrefixes: ['6', '7', '8'],
    ),
    _KpiDef(
      code: 'tresorerie',
      libelle: 'Trésorerie',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF2E7D32),
      classePrefixes: ['5'],
    ),
    _KpiDef(
      code: 'produits',
      libelle: 'Total des produits',
      icon: Icons.trending_up,
      color: Color(0xFF1565C0),
      classePrefixes: ['7'],
    ),
    _KpiDef(
      code: 'charges',
      libelle: 'Total des charges',
      icon: Icons.trending_down,
      color: Color(0xFFC62828),
      classePrefixes: ['6'],
    ),
    _KpiDef(
      code: 'creances',
      libelle: 'Créances',
      icon: Icons.arrow_circle_down,
      color: Color(0xFF00838F),
      classePrefixes: ['4'],
      filtreSigne: 1,
    ),
    _KpiDef(
      code: 'dettes',
      libelle: 'Dettes',
      icon: Icons.arrow_circle_up,
      color: Color(0xFFEF6C00),
      classePrefixes: ['4'],
      filtreSigne: -1,
    ),
    _KpiDef(
      code: 'immobilisations',
      libelle: 'Immobilisations',
      icon: Icons.domain,
      color: Color(0xFF4527A0),
      classePrefixes: ['2'],
    ),
    _KpiDef(
      code: 'stocks',
      libelle: 'Stocks',
      icon: Icons.inventory_2,
      color: Color(0xFF00695C),
      classePrefixes: ['3'],
    ),
    _KpiDef(
      code: 'fonds_propres',
      libelle: 'Fonds propres',
      icon: Icons.savings,
      color: Color(0xFF283593),
      classePrefixes: ['1'],
    ),
  ];

  /// Ordre d'affichage des 8 indicateurs clés en tête de page.
  static const _topKpiOrder = <String>[
    'resultat',
    'tresorerie',
    'produits',
    'charges',
    'creances',
    'dettes',
    'immobilisations',
  ];

  /// Indicateurs détaillés avec répartition par nature de compte.
  static const _detailKpiOrder = <String>[
    'tresorerie',
    'produits',
    'charges',
    'creances',
    'dettes',
  ];

  Exercice? _exercice;
  bool _isLoading = true;
  String? _error;

  Map<String, KpiResult> _kpis = {};
  List<SoldeCompte> _soldes = [];
  BudgetConsommeResult? _budget;
  List<ChartPoint> _evolutionProduits = [];
  List<ChartPoint> _evolutionCharges = [];
  List<ChartPoint> _evolutionTresorerie = [];
  List<ChartPoint> _evolutionCreances = [];
  List<ChartPoint> _evolutionDettes = [];
  Map<String, int> _controles = {};
  List<Map<String, dynamic>> _ecrituresRecentes = [];

  static const _moisAbrege = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  // --- Navigation de drill-down ---
  _DrillLevel _level = _DrillLevel.grid;
  _KpiDef? _currentKpi;
  String? _currentGroupePrefixe;
  SoldeCompte? _currentCompte;
  List<Map<String, dynamic>> _ecritures = [];
  bool _isLoadingEcritures = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(
      isAtRoot: () => _level == _DrillLevel.grid,
      popLevel: _popOneLevel,
    );
    _load();
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  /// Remonte d'un seul niveau de détail (utilisé par [DashboardDgController]
  /// pour un parent qui veut "reculer" progressivement dans le drill-down).
  void _popOneLevel() {
    switch (_level) {
      case _DrillLevel.ecritures:
        _backToComptes();
        break;
      case _DrillLevel.comptes:
        _backToGroupes();
        break;
      case _DrillLevel.groupes:
        _backToGrid();
        break;
      case _DrillLevel.grid:
        break;
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }

      Exercice? exercice;
      if (widget.exerciceId != null) {
        final results = await const LocalRepository().query(
          'exercice',
          where: 'id = ?',
          whereArgs: [widget.exerciceId],
          limit: 1,
        );
        if (results.isNotEmpty) {
          exercice = Exercice.fromMap(results.first);
        }
      }
      exercice ??= await AuthService.getExerciceActif();

      if (exercice == null || exercice.id == null) {
        setState(() {
          _error = 'Aucun exercice actif.';
          _isLoading = false;
        });
        return;
      }

      final kpis = await KpiService.getDashboardKpis(exercice.id!);
      final soldes = await KpiService.getSoldesComptes(exercice.id!);
      final budget = await KpiService.getBudgetConsomme(exercice.id!);
      final evoProduits = await KpiService.getEvolutionMensuelle(
        exercice.id!,
        ['7'],
      );
      final evoCharges = await KpiService.getEvolutionMensuelle(
        exercice.id!,
        ['6'],
      );
      final evoTresorerie = await KpiService.getEvolutionMensuelle(
        exercice.id!,
        ['5'],
      );
      final creancesComptes = soldes
          .where((s) => s.numeroCompte.startsWith('4') && s.solde > 0)
          .map((s) => s.numeroCompte)
          .toList();
      final dettesComptes = soldes
          .where((s) => s.numeroCompte.startsWith('4') && s.solde < 0)
          .map((s) => s.numeroCompte)
          .toList();
      final evoCreances = await KpiService.getEvolutionMensuelleParComptes(
        exercice.id!,
        creancesComptes,
      );
      final evoDettes = await KpiService.getEvolutionMensuelleParComptes(
        exercice.id!,
        dettesComptes,
      );
      final controles = await KpiService.getControlesComptables(
        exercice.id!,
      );
      final ecrituresRecentes = await KpiService.getEcrituresRecentes(
        exercice.id!,
      );

      if (!mounted) return;
      setState(() {
        _exercice = exercice;
        _kpis = kpis;
        _soldes = soldes;
        _budget = budget;
        _evolutionProduits = _toChartPoints(evoProduits, credit: true);
        _evolutionCharges = _toChartPoints(evoCharges, credit: false);
        _evolutionTresorerie = _toChartPoints(evoTresorerie, credit: false);
        _evolutionCreances = _toChartPoints(evoCreances, credit: true);
        _evolutionDettes = _toChartPoints(evoDettes, credit: false);
        _controles = controles;
        _ecrituresRecentes = ecrituresRecentes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors du chargement des KPI : $e';
        _isLoading = false;
      });
    }
  }

  /// Convertit les lignes mensuelles brutes de [KpiService.getEvolutionMensuelle]
  /// en points de graphique : solde du mois, créditeur normal ([credit] =
  /// true, ex. produits) ou débiteur normal (charges, trésorerie).
  List<ChartPoint> _toChartPoints(
    List<Map<String, dynamic>> rows, {
    required bool credit,
  }) {
    return rows.map((r) {
      final debit = (r['total_debit'] as num?)?.toDouble() ?? 0;
      final creditVal = (r['total_credit'] as num?)?.toDouble() ?? 0;
      final mois = (r['mois'] as num).toInt();
      final valeur = credit ? creditVal - debit : debit - creditVal;
      return ChartPoint(_moisAbrege[(mois - 1).clamp(0, 11)], valeur);
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Navigation drill-down (aucune nouvelle requête tant qu'on reste au
  // niveau classe/groupe/compte : tout est dérivé de [_soldes] en mémoire).
  // ---------------------------------------------------------------------

  void _openKpi(_KpiDef def) {
    setState(() {
      _currentKpi = def;
      _currentGroupePrefixe = null;
      _currentCompte = null;
      _level = _DrillLevel.groupes;
    });
    widget.controller?._notify();
  }

  void _openGroupe(String prefixe) {
    setState(() {
      _currentGroupePrefixe = prefixe;
      _level = _DrillLevel.comptes;
    });
    widget.controller?._notify();
  }

  Future<void> _openCompte(SoldeCompte compte) async {
    setState(() {
      _currentCompte = compte;
      _level = _DrillLevel.ecritures;
      _isLoadingEcritures = true;
      _ecritures = [];
    });
    widget.controller?._notify();
    try {
      final ecritures = await KpiService.getEcrituresCompte(
        compte.numeroCompte,
        _exercice!.id!,
      );
      if (!mounted) return;
      setState(() {
        _ecritures = ecritures;
        _isLoadingEcritures = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingEcritures = false;
      });
    }
  }

  void _backToGrid() {
    setState(() {
      _level = _DrillLevel.grid;
      _currentKpi = null;
      _currentGroupePrefixe = null;
      _currentCompte = null;
    });
    widget.controller?._notify();
  }

  void _backToGroupes() {
    setState(() {
      _level = _DrillLevel.groupes;
      _currentGroupePrefixe = null;
      _currentCompte = null;
    });
    widget.controller?._notify();
  }

  void _backToComptes() {
    setState(() {
      _level = _DrillLevel.comptes;
      _currentCompte = null;
    });
    widget.controller?._notify();
  }

  List<SoldeCompte> get _soldesDuPerimetre {
    final def = _currentKpi;
    if (def == null) return const [];
    final comptes = _soldes.where(
      (s) => def.classePrefixes.any((p) => s.numeroCompte.startsWith(p)),
    );
    if (def.filtreSigne == 1) return comptes.where((s) => s.solde > 0).toList();
    if (def.filtreSigne == -1) {
      return comptes.where((s) => s.solde < 0).toList();
    }
    return comptes.toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildBody();
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord DG')),
      body: content,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    switch (_level) {
      case _DrillLevel.grid:
        return _buildGrid();
      case _DrillLevel.groupes:
        return _buildGroupes();
      case _DrillLevel.comptes:
        return _buildComptes();
      case _DrillLevel.ecritures:
        return _buildEcritures();
    }
  }

  // ---------------------------------------------------------------------
  // Niveau 0 : vue d'ensemble des indicateurs
  // ---------------------------------------------------------------------

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBanner(),
            const SizedBox(height: 20),
            _buildChartsSection(),
            const SizedBox(height: 28),
            _buildTopKpiRow(),
            const SizedBox(height: 28),
            _sectionTitle('Situation financière'),
            const SizedBox(height: 12),
            _buildSituationFinanciereSection(),
            const SizedBox(height: 20),
            SizedBox(width: 260, child: _buildBudgetCard()),
            const SizedBox(height: 28),
            _sectionTitle('Contrôles comptables'),
            const SizedBox(height: 12),
            _buildControlesComptablesSection(),
            const SizedBox(height: 28),
            _sectionTitle('Activité comptable'),
            const SizedBox(height: 12),
            _buildActiviteComptableSection(),
            const SizedBox(height: 28),
            _sectionTitle('Détail par indicateur'),
            const SizedBox(height: 4),
            Text(
              'Cliquez sur un indicateur pour voir le détail par classe, groupe, compte et écriture.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildDetailParIndicateurSection(),
            const SizedBox(height: 28),
            _sectionTitle('Activité récente'),
            const SizedBox(height: 12),
            _buildActiviteRecenteSection(),
            const SizedBox(height: 28),
            _sectionTitle('Résumé de l\'exercice'),
            const SizedBox(height: 12),
            _buildResumeExerciceSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights, size: 26, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indicateurs de performance — Exercice ${_exercice?.code ?? ''}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Indicateurs calculés automatiquement à partir des écritures comptables. '
                  'Cliquez sur un indicateur pour voir le détail par classe, groupe, compte et écriture.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: Colors.blueGrey.shade800,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Indicateurs clés (8 cartes)
  // ---------------------------------------------------------------------

  Widget _buildTopKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 220).clamp(1, 8);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
          children: [
            for (final code in _topKpiOrder)
              _buildKpiCard(
                _kpiDefs.firstWhere((d) => d.code == code),
                _kpis[code],
              ),
            _buildNombreEcrituresCard(),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiDef def, KpiResult? result) {
    final valeur = result?.valeur ?? 0;
    final evolution = result?.evolutionPct;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openKpi(def),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(def.icon, color: def.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    def.libelle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${_formatMontant(valeur)} FCFA',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: def.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            _buildEvolutionBadge(evolution),
          ],
        ),
      ),
    );
  }

  Widget _buildNombreEcrituresCard() {
    final result = _kpis['nombre_ecritures'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blueGrey.shade600, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Nombre d'écritures",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${(result?.valeur ?? 0).toInt()}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final budget = _budget;
    final pct = budget?.pctConsommation;
    final alerte = pct != null && pct > 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alerte ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: alerte ? Colors.red.shade600 : Colors.teal.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Budget consommé',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (alerte)
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          if (budget == null || pct == null)
            const Text('Aucun budget défini', style: TextStyle(fontSize: 12, color: Colors.grey))
          else ...[
            Text(
              '${pct.toStringAsFixed(1)} %',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: alerte ? Colors.red.shade700 : Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatMontant(budget.montantRealise)} / ${_formatMontant(budget.montantPrevu)} FCFA',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvolutionBadge(double? evolutionPct) {
    if (evolutionPct == null) {
      return Text(
        'vs exercice précédent : N/A',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      );
    }
    final positive = evolutionPct >= 0;
    final color = positive ? Colors.green.shade700 : Colors.red.shade700;
    return Row(
      children: [
        Icon(
          positive ? Icons.arrow_upward : Icons.arrow_downward,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '${evolutionPct.abs().toStringAsFixed(1)} % vs exercice précédent',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Situation financière
  // ---------------------------------------------------------------------

  Widget _buildSituationFinanciereSection() {
    final actifTotal = KpiService.getActifTotal(_soldes);
    final passifTotal = KpiService.getPassifTotal(_soldes);
    final fondsPropres = KpiService.getFondsPropres(_soldes);
    final fondsDeRoulement = KpiService.getFondsDeRoulement(_soldes);
    final bfr = KpiService.getBesoinFondsRoulement(_soldes);
    final tresorerieNette = KpiService.getTresorerie(_soldes);
    final tauxEndettement = KpiService.getTauxEndettement(_soldes);
    final couvertureCharges = KpiService.getCouvertureCharges(_soldes);

    final tiles = <Widget>[
      _situationTile('Actif total', '${_formatMontant(actifTotal)} FCFA'),
      _situationTile('Passif total', '${_formatMontant(passifTotal)} FCFA'),
      _situationTile('Fonds propres', '${_formatMontant(fondsPropres)} FCFA'),
      _situationTile(
        'Fonds de roulement',
        '${_formatMontant(fondsDeRoulement)} FCFA',
      ),
      _situationTile(
        'Besoin en fonds de roulement',
        '${_formatMontant(bfr)} FCFA',
      ),
      _situationTile(
        'Trésorerie nette',
        '${_formatMontant(tresorerieNette)} FCFA',
      ),
      _situationTile(
        'Taux d\'endettement',
        tauxEndettement == null
            ? 'Donnée non disponible'
            : '${tauxEndettement.toStringAsFixed(1)} %',
      ),
      _situationTile(
        'Couverture des charges par les produits',
        couvertureCharges == null
            ? 'Donnée non disponible'
            : '${couvertureCharges.toStringAsFixed(1)} %',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth ~/ 210).clamp(1, 4);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.6,
            children: tiles,
          );
        },
      ),
    );
  }

  Widget _situationTile(String label, String value) {
    final indisponible = value == 'Donnée non disponible';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: indisponible ? Colors.grey.shade400 : Colors.blueGrey.shade900,
            fontStyle: indisponible ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Graphiques
  // ---------------------------------------------------------------------

  Widget _buildChartsSection() {
    final repartition = AssetRepartitionPanel(
      subtitle: 'Structure de l\'actif au ${_fmtDateCourte(DateTime.now())}',
      segments: _repartitionActif(),
      valueFormatter: (v) => _formatMontant(v),
    );
    final produits = EvolutionPanel(
      title: 'Évolution des produits',
      subtitle: 'Évolution mensuelle des produits',
      seriesLabel: 'Produits',
      color: const Color(0xFF1565C0),
      points: _evolutionProduits,
      valueFormatter: (v) => _formatMontant(v),
      onTap: () => _openKpi(_kpiDefs.firstWhere((d) => d.code == 'produits')),
    );
    final charges = EvolutionPanel(
      title: 'Évolution des charges',
      subtitle: 'Évolution mensuelle des charges',
      seriesLabel: 'Charges',
      color: const Color(0xFFEF6C00),
      points: _evolutionCharges,
      valueFormatter: (v) => _formatMontant(v),
      onTap: () => _openKpi(_kpiDefs.firstWhere((d) => d.code == 'charges')),
    );
    final tresorerie = EvolutionPanel(
      title: 'Évolution de la trésorerie',
      subtitle: 'Évolution mensuelle de la trésorerie',
      seriesLabel: 'Trésorerie',
      color: const Color(0xFF2E7D32),
      points: _evolutionTresorerie,
      valueFormatter: (v) => _formatMontant(v),
      onTap: () => _openKpi(_kpiDefs.firstWhere((d) => d.code == 'tresorerie')),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Évolution et répartition'),
        const SizedBox(height: 4),
        Text(
          'Visualisez la répartition de vos actifs et l\'évolution mensuelle de vos produits, charges et trésorerie.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const panelHeight = 420.0;
            if (constraints.maxWidth > 900) {
              return Column(
                children: [
                  SizedBox(
                    height: panelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: repartition),
                        const SizedBox(width: 16),
                        Expanded(child: produits),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: panelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: charges),
                        const SizedBox(width: 16),
                        Expanded(child: tresorerie),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: panelHeight, child: repartition),
                const SizedBox(height: 16),
                SizedBox(height: panelHeight, child: produits),
                const SizedBox(height: 16),
                SizedBox(height: panelHeight, child: charges),
                const SizedBox(height: 16),
                SizedBox(height: panelHeight, child: tresorerie),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cliquez sur un graphique d\'évolution pour explorer le détail de l\'indicateur '
                  '(comptes et écritures).',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDateCourte(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<PieSegment> _repartitionActif() {
    double sumPrefixe(String prefixe) => _soldes
        .where((s) => s.numeroCompte.startsWith(prefixe))
        .fold<double>(0, (s, c) => s + c.solde.abs());

    final creances = _soldes
        .where((s) => s.numeroCompte.startsWith('4') && s.solde > 0)
        .fold<double>(0, (s, c) => s + c.solde);

    return [
      PieSegment('Trésorerie', sumPrefixe('5'), const Color(0xFF2E7D32)),
      PieSegment('Créances', creances, const Color(0xFF00838F)),
      PieSegment('Stocks', sumPrefixe('3'), const Color(0xFF00695C)),
      PieSegment(
        'Immobilisations',
        sumPrefixe('2'),
        const Color(0xFF4527A0),
      ),
    ].where((s) => s.value > 0).toList();
  }

  // ---------------------------------------------------------------------
  // Contrôles comptables
  // ---------------------------------------------------------------------

  Widget _buildControlesComptablesSection() {
    final totalDebit = _soldes.fold<double>(0, (s, c) => s + c.totalDebit);
    final totalCredit = _soldes.fold<double>(0, (s, c) => s + c.totalCredit);
    final ecart = totalDebit - totalCredit;
    final equilibre = ecart.abs() < 1;
    final sansPiece = _controles['ecritures_sans_piece'] ?? 0;
    final lettrees = _controles['ecritures_lettrees'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 220).clamp(1, 5);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: [
            _controleTile(
              'Écritures équilibrées',
              ok: equilibre,
              statusText: equilibre
                  ? 'OK'
                  : 'Écart de ${_formatMontant(ecart.abs())} FCFA',
            ),
            _controleTile(
              'Écritures en brouillon',
              disponible: false,
            ),
            _controleTile(
              'Écritures sans pièce',
              ok: sansPiece == 0,
              statusText: '$sansPiece',
            ),
            _controleTile(
              'Comptes avec anomalie',
              disponible: false,
            ),
            _controleTile(
              'Rapprochements (lettrage)',
              ok: true,
              neutral: true,
              statusText: '$lettrees ligne(s)',
            ),
          ],
        );
      },
    );
  }

  Widget _controleTile(
    String label, {
    bool disponible = true,
    bool ok = true,
    bool neutral = false,
    String statusText = '',
  }) {
    final color = !disponible
        ? Colors.grey.shade400
        : neutral
            ? Colors.blueGrey.shade600
            : (ok ? Colors.green.shade700 : Colors.red.shade700);
    final icon = !disponible
        ? Icons.remove_circle_outline
        : neutral
            ? Icons.link
            : (ok ? Icons.check_circle : Icons.warning_amber_rounded);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  disponible ? statusText : 'Donnée non disponible',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: disponible ? 13 : 11.5,
                    fontStyle: disponible ? FontStyle.normal : FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Activité comptable
  // ---------------------------------------------------------------------

  Widget _buildActiviteComptableSection() {
    final totalDebit = _soldes.fold<double>(0, (s, c) => s + c.totalDebit);
    final totalCredit = _soldes.fold<double>(0, (s, c) => s + c.totalCredit);
    final ecart = totalDebit - totalCredit;
    final nombreEcritures = (_kpis['nombre_ecritures']?.valeur ?? 0).toInt();
    final journauxUtilises = _controles['journaux_utilises'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth ~/ 180).clamp(1, 6);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.0,
            children: [
              _situationTile('Écritures totales', '$nombreEcritures'),
              _situationTile('Écritures validées', 'Donnée non disponible'),
              _situationTile('Écritures brouillon', 'Donnée non disponible'),
              _situationTile('Journaux utilisés', '$journauxUtilises'),
              _situationTile('Comptes mouvementés', '${_soldes.length}'),
              _situationTile('Total débit', '${_formatMontant(totalDebit)} FCFA'),
              _situationTile('Total crédit', '${_formatMontant(totalCredit)} FCFA'),
              _situationTile(
                'Équilibre débit/crédit',
                ecart.abs() < 1
                    ? 'Équilibré'
                    : 'Écart ${_formatMontant(ecart.abs())} FCFA',
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Détail par indicateur (avec répartition par nature de compte)
  // ---------------------------------------------------------------------

  double _sumSoldeNature(NatureCompte nature) => _soldes
      .where((s) => s.nature == nature)
      .fold<double>(0, (s, c) => s + c.solde);

  double _sumMouvementNature(NatureCompte nature, {required bool credit}) {
    final comptes = _soldes.where((s) => s.nature == nature);
    final debit = comptes.fold<double>(0, (s, c) => s + c.totalDebit);
    final creditVal = comptes.fold<double>(0, (s, c) => s + c.totalCredit);
    return credit ? creditVal - debit : debit - creditVal;
  }

  List<_BreakdownItem> _breakdownPour(String code) {
    switch (code) {
      case 'tresorerie':
        return [
          _BreakdownItem('Comptes bancaires', _sumSoldeNature(NatureCompte.bilanBanque)),
          _BreakdownItem('Caisses', _sumSoldeNature(NatureCompte.bilanCaisse)),
          _BreakdownItem(
            'Autres disponibilités',
            _sumSoldeNature(NatureCompte.bilanAutresTresoreries),
          ),
        ];
      case 'produits':
        return [
          _BreakdownItem(
            'Produits d\'activités ordinaires',
            _sumMouvementNature(NatureCompte.produitsAO, credit: true),
          ),
          _BreakdownItem(
            'Produits H.A.O.',
            _sumMouvementNature(NatureCompte.produitsHAO, credit: true),
          ),
        ];
      case 'charges':
        return [
          _BreakdownItem(
            'Charges d\'activités ordinaires',
            _sumMouvementNature(NatureCompte.chargesAO, credit: false),
          ),
          _BreakdownItem(
            'Charges H.A.O.',
            _sumMouvementNature(NatureCompte.chargesHAO, credit: false),
          ),
        ];
      case 'creances':
        final clients = _soldes
            .where((s) =>
                s.nature == NatureCompte.bilanAdherentsClientsUsagers &&
                s.solde > 0)
            .fold<double>(0, (s, c) => s + c.solde);
        final autres = _soldes
            .where((s) =>
                s.numeroCompte.startsWith('4') &&
                s.nature != NatureCompte.bilanAdherentsClientsUsagers &&
                s.solde > 0)
            .fold<double>(0, (s, c) => s + c.solde);
        return [
          _BreakdownItem('Adhérents / clients usagers', clients),
          _BreakdownItem('Autres créances', autres),
        ];
      case 'dettes':
        final fournisseurs = _soldes
            .where((s) => s.nature == NatureCompte.bilanFournisseurs && s.solde < 0)
            .fold<double>(0, (s, c) => s - c.solde);
        final fiscalesSociales = _soldes
            .where((s) =>
                (s.nature == NatureCompte.bilanEtatCollectivitesPubliques ||
                    s.nature == NatureCompte.bilanOrganismesSociaux ||
                    s.nature == NatureCompte.bilanPersonnel) &&
                s.solde < 0)
            .fold<double>(0, (s, c) => s - c.solde);
        final autres = _soldes
            .where((s) =>
                s.numeroCompte.startsWith('4') &&
                s.nature != NatureCompte.bilanFournisseurs &&
                s.nature != NatureCompte.bilanEtatCollectivitesPubliques &&
                s.nature != NatureCompte.bilanOrganismesSociaux &&
                s.nature != NatureCompte.bilanPersonnel &&
                s.solde < 0)
            .fold<double>(0, (s, c) => s - c.solde);
        return [
          _BreakdownItem('Fournisseurs', fournisseurs),
          _BreakdownItem('Dettes fiscales et sociales', fiscalesSociales),
          _BreakdownItem('Autres dettes', autres),
        ];
      default:
        return const [];
    }
  }

  Widget _buildDetailParIndicateurSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 300).clamp(1, 5);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            for (final code in _detailKpiOrder)
              _buildDetailIndicatorCard(
                _kpiDefs.firstWhere((d) => d.code == code),
                _kpis[code],
              ),
          ],
        );
      },
    );
  }

  List<ChartPoint> _evolutionPour(String code) {
    switch (code) {
      case 'tresorerie':
        return _evolutionTresorerie;
      case 'produits':
        return _evolutionProduits;
      case 'charges':
        return _evolutionCharges;
      case 'creances':
        return _evolutionCreances;
      case 'dettes':
        return _evolutionDettes;
      default:
        return const [];
    }
  }

  Widget _buildDetailIndicatorCard(_KpiDef def, KpiResult? result) {
    final valeur = result?.valeur ?? 0;
    final breakdown = _breakdownPour(def.code);
    final evolution = _evolutionPour(def.code);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openKpi(def),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(def.icon, color: def.color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    def.libelle,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${_formatMontant(valeur)} FCFA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: def.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (evolution.length >= 2) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 86,
                    height: 38,
                    child: Sparkline(points: evolution, color: def.color),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            _buildEvolutionBadge(result?.evolutionPct),
            const Divider(height: 20),
            for (final item in breakdown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_formatMontant(item.valeur)} FCFA',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Activité récente
  // ---------------------------------------------------------------------

  Widget _buildActiviteRecenteSection() {
    if (_ecrituresRecentes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Aucune écriture récente.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Date', style: _headerStyle)),
                Expanded(flex: 4, child: Text('Libellé', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Journal', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Catégorie', style: _headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text('Montant', style: _headerStyle, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (final e in _ecrituresRecentes) _buildActiviteRecenteRow(e),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
  );

  Widget _buildActiviteRecenteRow(Map<String, dynamic> e) {
    final debit = (e['montant_debit'] as num?)?.toDouble() ?? 0;
    final credit = (e['montant_credit'] as num?)?.toDouble() ?? 0;
    final numeroCompte = (e['numero_compte'] ?? '') as String;
    final categorie =
        calculateNatureFromNumeroCompte(numeroCompte)?.toLabel() ?? '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${e['date_comptable'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${e['libelle'] ?? ''}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${e['code_journal'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              categorie,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              debit > 0
                  ? '${_formatMontant(debit)} D'
                  : '${_formatMontant(credit)} C',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Résumé de l'exercice
  // ---------------------------------------------------------------------

  Widget _buildResumeExerciceSection() {
    final exercice = _exercice;
    if (exercice == null) {
      return Text(
        'Donnée non disponible',
        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
      );
    }

    final totalJours = exercice.dateFin.difference(exercice.dateDebut).inDays + 1;
    final aujourdHui = DateTime.now();
    final joursEcoules = aujourdHui
        .difference(exercice.dateDebut)
        .inDays
        .clamp(0, totalJours);
    final joursRestants = (totalJours - joursEcoules).clamp(0, totalJours);
    final progression = totalJours > 0 ? joursEcoules / totalJours : 0.0;

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resumeRow('Période', '${fmtDate(exercice.dateDebut)} - ${fmtDate(exercice.dateFin)}'),
          _resumeRow('Durée de l\'exercice', '$totalJours jours'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progression.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 10),
          _resumeRow('Progression', '${(progression * 100).clamp(0, 100).toStringAsFixed(0)} %'),
          _resumeRow('Jours écoulés', '$joursEcoules jours'),
          _resumeRow('Jours restants', '$joursRestants jours'),
        ],
      ),
    );
  }

  Widget _resumeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Niveau 1 : groupes de comptes (2 premiers chiffres)
  // ---------------------------------------------------------------------

  Widget _buildGroupes() {
    final def = _currentKpi!;
    final perimetre = _soldesDuPerimetre;
    final groupes = KpiService.regrouperParPrefixe(perimetre, 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb([
          _Crumb('Tableau de bord', _backToGrid),
          _Crumb(def.libelle, null),
        ]),
        Expanded(
          child: groupes.isEmpty
              ? const Center(child: Text('Aucun compte mouvementé.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final g = groupes[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: def.color.withValues(alpha: 0.1),
                        child: Text(
                          g.prefixe,
                          style: TextStyle(
                            color: def.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text('Classe ${g.prefixe}'),
                      subtitle: Text('${g.nombreComptes} compte(s)'),
                      trailing: Text(
                        '${_formatMontant(g.solde.abs())} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _openGroupe(g.prefixe),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Niveau 2 : comptes du groupe sélectionné
  // ---------------------------------------------------------------------

  Widget _buildComptes() {
    final def = _currentKpi!;
    final perimetre = _soldesDuPerimetre;
    final groupePrefixe = _currentGroupePrefixe;
    final comptes = groupePrefixe == null
        ? (perimetre..sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte)))
        : KpiService.comptesDuPrefixe(perimetre, groupePrefixe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb([
          _Crumb('Tableau de bord', _backToGrid),
          _Crumb(def.libelle, groupePrefixe == null ? null : _backToGroupes),
          if (groupePrefixe != null) _Crumb('Classe $groupePrefixe', null),
        ]),
        Expanded(
          child: comptes.isEmpty
              ? const Center(child: Text('Aucun compte mouvementé.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comptes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = comptes[i];
                    return ListTile(
                      leading: Icon(Icons.description_outlined, color: def.color),
                      title: Text('${c.numeroCompte} — ${c.intitule}'),
                      subtitle: Text(c.nature.toLabel()),
                      trailing: Text(
                        '${_formatMontant(c.solde.abs())} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _openCompte(c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Niveau 3 : écritures du compte sélectionné
  // ---------------------------------------------------------------------

  Widget _buildEcritures() {
    final def = _currentKpi!;
    final compte = _currentCompte!;
    final groupePrefixe = _currentGroupePrefixe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb([
          _Crumb('Tableau de bord', _backToGrid),
          _Crumb(def.libelle, _backToGroupes),
          if (groupePrefixe != null)
            _Crumb('Classe $groupePrefixe', _backToComptes)
          else
            _Crumb('Comptes', _backToComptes),
          _Crumb(compte.numeroCompte, null),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${compte.numeroCompte} — ${compte.intitule}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingEcritures
              ? const Center(child: CircularProgressIndicator())
              : _ecritures.isEmpty
                  ? const Center(child: Text('Aucune écriture.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ecritures.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _ecritures[i];
                        final debit = (e['montant_debit'] as num?)?.toDouble() ?? 0;
                        final credit = (e['montant_credit'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          dense: true,
                          title: Text((e['libelle'] ?? '') as String),
                          subtitle: Text(
                            '${e['date_comptable'] ?? ''} · ${e['code_journal'] ?? ''} · '
                            '${e['numero_document'] ?? ''}',
                          ),
                          trailing: Text(
                            debit > 0
                                ? '${_formatMontant(debit)} D'
                                : '${_formatMontant(credit)} C',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(List<_Crumb> crumbs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
              ),
            InkWell(
              onTap: crumbs[i].onTap,
              child: Text(
                crumbs[i].label,
                style: TextStyle(
                  fontSize: 13,
                  color: crumbs[i].onTap == null ? Colors.black87 : Colors.blue.shade700,
                  fontWeight: crumbs[i].onTap == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMontant(double montant) {
    return montant
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }
}

class _Crumb {
  final String label;
  final VoidCallback? onTap;
  const _Crumb(this.label, this.onTap);
}
