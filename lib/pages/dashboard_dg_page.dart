import 'package:flutter/material.dart';

import '../models/kpi.dart';
import '../models/compte.dart';
import '../models/exercice.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/kpi_service.dart';
import '../services/local_repository.dart';
import '../widgets/simple_charts.dart';

/// Dashboard KPI destiné au DG : indicateurs calculés automatiquement à
/// partir des soldes comptables (aucune saisie manuelle de KPI), avec
/// drill-down Classe → Groupe → Compte → Écritures sur chaque indicateur
/// adossé à un périmètre de comptes.
class DashboardDgPage extends StatefulWidget {
  final int? exerciceId;
  final bool showAppBar;

  const DashboardDgPage({super.key, this.exerciceId, this.showAppBar = true});

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

enum _DrillLevel { grid, groupes, comptes, ecritures }

class _DashboardDgPageState extends State<DashboardDgPage> {
  static const _kpiDefs = <_KpiDef>[
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
      code: 'resultat',
      libelle: 'Résultat',
      icon: Icons.balance,
      color: Color(0xFF6A1B9A),
      classePrefixes: ['6', '7', '8'],
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

  Exercice? _exercice;
  bool _isLoading = true;
  String? _error;

  Map<String, KpiResult> _kpis = {};
  List<SoldeCompte> _soldes = [];
  BudgetConsommeResult? _budget;
  List<ChartPoint> _evolutionProduits = [];
  List<ChartPoint> _evolutionCharges = [];
  List<ChartPoint> _evolutionTresorerie = [];

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
    _load();
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

      if (!mounted) return;
      setState(() {
        _exercice = exercice;
        _kpis = kpis;
        _soldes = soldes;
        _budget = budget;
        _evolutionProduits = _toChartPoints(evoProduits, credit: true);
        _evolutionCharges = _toChartPoints(evoCharges, credit: false);
        _evolutionTresorerie = _toChartPoints(evoTresorerie, credit: false);
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
  }

  void _openGroupe(String prefixe) {
    setState(() {
      _currentGroupePrefixe = prefixe;
      _level = _DrillLevel.comptes;
    });
  }

  Future<void> _openCompte(SoldeCompte compte) async {
    setState(() {
      _currentCompte = compte;
      _level = _DrillLevel.ecritures;
      _isLoadingEcritures = true;
      _ecritures = [];
    });
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
  }

  void _backToGroupes() {
    setState(() {
      _level = _DrillLevel.groupes;
      _currentGroupePrefixe = null;
      _currentCompte = null;
    });
  }

  void _backToComptes() {
    setState(() {
      _level = _DrillLevel.comptes;
      _currentCompte = null;
    });
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
  // Niveau 0 : grille des KPI
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.dashboard, size: 24, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tableau de bord comptable — Exercice ${_exercice?.code ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Indicateurs calculés automatiquement à partir des écritures comptables. '
                'Cliquez sur un indicateur pour voir le détail par classe, groupe, compte et écriture.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartsSection(),
            const SizedBox(height: 24),
            const Text(
              'Détail par indicateur',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth ~/ 260;
                return GridView.count(
                  crossAxisCount: crossAxisCount.clamp(1, 5),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.6,
                  children: [
                    for (final def in _kpiDefs)
                      _buildKpiCard(def, _kpis[def.code]),
                    _buildNombreEcrituresCard(),
                    _buildBudgetCard(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
          children: [
            DashboardPanel(
              title: 'Répartition de l\'actif',
              child: MiniPieChart(
                segments: _repartitionActif(),
                valueFormatter: (v) => '${_formatMontant(v)} FCFA',
              ),
            ),
            DashboardPanel(
              title: 'Évolution des produits',
              child: BarTrendChart(
                points: _evolutionProduits,
                barColor: const Color(0xFF1565C0),
                referenceLine: _moyenne(_evolutionProduits),
                valueFormatter: (v) => _formatMontant(v),
              ),
            ),
            DashboardPanel(
              title: 'Évolution des charges',
              child: BarTrendChart(
                points: _evolutionCharges,
                barColor: const Color(0xFFEF6C00),
                referenceLine: _moyenne(_evolutionCharges),
                valueFormatter: (v) => _formatMontant(v),
              ),
            ),
            DashboardPanel(
              title: 'Évolution de la trésorerie',
              child: BarTrendChart(
                points: _evolutionTresorerie,
                barColor: const Color(0xFF2E7D32),
                referenceLine: _moyenne(_evolutionTresorerie),
                valueFormatter: (v) => _formatMontant(v),
              ),
            ),
          ],
        );
      },
    );
  }

  double? _moyenne(List<ChartPoint> points) {
    if (points.isEmpty) return null;
    return points.fold<double>(0, (s, p) => s + p.value) / points.length;
  }

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
          const Spacer(),
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
