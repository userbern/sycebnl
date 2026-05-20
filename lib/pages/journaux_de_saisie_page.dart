import 'package:flutter/material.dart';
import '../models/exercice.dart';
import '../models/journal.dart';
import '../models/saisie_comptable.dart';
import '../services/auth_service.dart';
import '../services/saisie_comptable_service.dart';
import 'saisie_ecriture_page.dart';

typedef _MonthOption = ({String id, String label, int mois, int annee});

class JournauxDeSaisiePage extends StatefulWidget {
  final bool showAppBar;
  final Future<bool> Function(JournalPeriode)? onOpenPeriode;

  const JournauxDeSaisiePage({
    super.key,
    this.showAppBar = true,
    this.onOpenPeriode,
  });

  @override
  State<JournauxDeSaisiePage> createState() => _JournauxDeSaisiePageState();
}

class _JournauxDeSaisiePageState extends State<JournauxDeSaisiePage> {
  bool _isLoading = true;
  bool _isPerformingAction = false;
  Exercice? _exerciceActif;
  List<Journal> _journaux = [];
  List<_JournalSaisieRow> _rows = [];
  Map<int, int> _entriesByPeriodeId = {};
  final TextEditingController _codeSearchController = TextEditingController();
  final TextEditingController _intituleSearchController =
      TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  String _codeQuery = '';
  String _intituleQuery = '';
  int? _selectedMonth;
  int? _selectedYear;
  String? _selectedMonthId;

  static const List<String> _monthShortLabels = [
    'janv',
    'fev',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'aout',
    'sept',
    'oct',
    'nov',
    'dec',
  ];
  static const List<String> _monthFullNames = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeSearchController.dispose();
    _intituleSearchController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final exercice = await AuthService.getExerciceActif();
      final journaux = await AuthService.getJournaux();
      final periodes =
          exercice != null && exercice.id != null
              ? await SaisieComptableService.getJournalPeriodes(
                  exerciceId: exercice.id!,
                )
              : <JournalPeriode>[];
      final entriesByPeriode =
          await SaisieComptableService.getEcritureCountsByPeriode();

      if (!mounted) return;

      setState(() {
        _exerciceActif = exercice;
        _journaux = journaux;
        _rows =
            exercice != null ? _buildRows(exercice, journaux, periodes) : [];
        _entriesByPeriodeId = entriesByPeriode;
        _isLoading = false;

        final monthOptions = _availableMonthOptions;
        if (_selectedMonthId != null &&
            !monthOptions.any((option) => option.id == _selectedMonthId)) {
          _selectedMonthId = null;
          _selectedMonth = null;
        }

        final availableYears = _availableYears;
        if (_selectedYear != null && !availableYears.contains(_selectedYear)) {
          _selectedYear = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _entriesByPeriodeId = {};
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  List<_JournalSaisieRow> _buildRows(
    Exercice exercice,
    List<Journal> journaux,
    List<JournalPeriode> periodes,
  ) {
    if (journaux.isEmpty) return [];

    final periodLookup = <String, JournalPeriode>{
      for (final periode in periodes)
        _periodeKey(periode.codeJournal, periode.annee, periode.mois): periode,
    };

    final sortedJournaux = [...journaux]
      ..sort((a, b) => a.code.toUpperCase().compareTo(b.code.toUpperCase()));

    final rows = <_JournalSaisieRow>[];
    DateTime cursor = DateTime(
      exercice.dateDebut.year,
      exercice.dateDebut.month,
    );
    final DateTime end = DateTime(
      exercice.dateFin.year,
      exercice.dateFin.month,
    );

    while (!cursor.isAfter(end)) {
      for (final journal in sortedJournaux) {
        final key = _periodeKey(journal.code, cursor.year, cursor.month);
        rows.add(
          _JournalSaisieRow(
            position: rows.length + 1,
            journal: journal,
            annee: cursor.year,
            mois: cursor.month,
            periode: periodLookup[key],
          ),
        );
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return rows;
  }

  String _periodeKey(String codeJournal, int annee, int mois) {
    final normalizedCode = codeJournal.trim().toUpperCase();
    final paddedMonth = mois.toString().padLeft(2, '0');
    return '$normalizedCode-$annee-$paddedMonth';
  }

  bool get _hasActiveFilters =>
      _codeQuery.isNotEmpty ||
      _intituleQuery.isNotEmpty ||
      _selectedMonthId != null ||
      _selectedYear != null;

  List<_JournalSaisieRow> get _filteredRows {
    if (!_hasActiveFilters) {
      return _rows;
    }

    return _rows.where((row) {
      final codeLower = row.journal.code.toLowerCase();
      final nameLower = row.journal.intitule.toLowerCase();
      final codeQuery = _codeQuery.toLowerCase();
      final nameQuery = _intituleQuery.toLowerCase();

      if (codeQuery.isNotEmpty && !codeLower.contains(codeQuery)) {
        return false;
      }

      if (nameQuery.isNotEmpty && !nameLower.contains(nameQuery)) {
        return false;
      }

      if (_selectedMonth != null && row.mois != _selectedMonth) {
        return false;
      }

      if (_selectedYear != null && row.annee != _selectedYear) {
        return false;
      }

      return true;
    }).toList();
  }

  String? _selectedMonthValue(List<_MonthOption> monthOptions) {
    final selectedId = _selectedMonthId;
    return monthOptions.any((option) => option.id == selectedId)
        ? selectedId
        : null;
  }

  void _applyMonthSelection(
    String? selectedId,
    List<_MonthOption> monthOptions,
  ) {
    setState(() {
      _selectedMonthId = selectedId;
      if (selectedId == null) {
        _selectedMonth = null;
      } else {
        final selectedOption = monthOptions.firstWhere(
          (option) => option.id == selectedId,
          orElse: () => monthOptions.first,
        );
        _selectedMonth = selectedOption.mois;
        _selectedYear = selectedOption.annee;
      }
    });
  }

  void _applyYearSelection(int? value) {
    if (value == null) return;
    setState(() => _selectedYear = value == 0 ? null : value);
  }

  void _clearSearchControllers() {
    _codeSearchController.clear();
    _intituleSearchController.clear();
  }

  List<_MonthOption> get _availableMonthOptions {
    if (_rows.isEmpty) return [];

    final options = <String, _MonthOption>{};

    for (final row in _rows) {
      final id = '${row.annee}-${row.mois.toString().padLeft(2, '0')}';
      if (options.containsKey(id)) continue;

      final monthIndex =
          (row.mois - 1).clamp(0, _monthFullNames.length - 1).toInt();
      final label = '${_monthFullNames[monthIndex]} ${row.annee}';

      options[id] = (id: id, label: label, mois: row.mois, annee: row.annee);
    }

    final list =
        options.values.toList()..sort((a, b) {
          final dateA = DateTime(a.annee, a.mois);
          final dateB = DateTime(b.annee, b.mois);
          return dateA.compareTo(dateB);
        });

    return list;
  }

  List<int> get _availableYears {
    final years = <int>{};
    for (final row in _rows) {
      years.add(row.annee);
    }
    final result = years.toList()..sort();
    return result;
  }

  String _formatMonthLabel(int mois, int annee) {
    final safeMonth = mois.clamp(1, _monthShortLabels.length).toInt();
    final label = _monthShortLabels[safeMonth - 1];
    final yearString = annee.toString();
    final suffix =
        yearString.length > 2
            ? yearString.substring(yearString.length - 2)
            : yearString;
    return '$label-$suffix';
  }

  String _formatHeaderLabel(DateTime date) {
    final safeMonth = date.month.clamp(1, _monthShortLabels.length).toInt();
    final label = _monthShortLabels[safeMonth - 1];
    return '$label ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                  title: const Text('Journaux de saisie'),
                  backgroundColor: Colors.blue.shade200,
                  elevation: 0,
                )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_buildHeader(), Expanded(child: _buildBody())],
                ),
    );
  }

  Widget _buildHeader() {
    final exercice = _exerciceActif;
    final subtitle =
        exercice == null
            ? 'Aucun exercice actif'
            : 'Exercice ${exercice.code} • ${_formatHeaderLabel(exercice.dateDebut)} - ${_formatHeaderLabel(exercice.dateFin)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Journaux de saisie',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
          if (exercice != null)
            Builder(
              builder: (context) {
                final total = _rows.length;
                final filtered = _filteredRows.length;
                final infoText =
                    _hasActiveFilters
                        ? '$filtered / $total'
                        : '$total entrées';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    infoText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_exerciceActif == null) {
      return _buildNoExercice();
    }

    if (_journaux.isEmpty) {
      return _buildNoJournal();
    }

    if (_rows.isEmpty) {
      return _buildEmptyState();
    }

    final filteredRows = _filteredRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(),
        _buildLegend(),
        Expanded(
          child:
              filteredRows.isEmpty
                  ? _buildNoFilteredResults()
                  : _buildTable(filteredRows),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    final items = [
      _RowStatus(
        label: 'Aucune écriture',
        backgroundColor: Colors.grey.shade100,
        badgeColor: Colors.grey.shade200,
        textColor: Colors.grey.shade700,
      ),
      _RowStatus(
        label: 'Avec écritures',
        backgroundColor: Colors.green.shade50,
        badgeColor: Colors.green.shade100,
        textColor: Colors.green.shade700,
      ),
      _RowStatus(
        label: 'Part. clôturé',
        backgroundColor: Colors.orange.shade50,
        badgeColor: Colors.orange.shade100,
        textColor: Colors.orange.shade800,
      ),
      _RowStatus(
        label: 'Clôturé',
        backgroundColor: Colors.red.shade50,
        badgeColor: Colors.red.shade100,
        textColor: Colors.red.shade700,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'Légende : ',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children:
                  items.map((item) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.backgroundColor,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: item.textColor,
                              width: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.label,
                          style: TextStyle(fontSize: 10, color: item.textColor),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final monthOptions = _availableMonthOptions;
    final years = _availableYears;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isNarrow ? constraints.maxWidth : 160,
                height: 36,
                child: TextField(
                  controller: _codeSearchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Code journal',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.blue.shade500,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  onChanged:
                      (value) => setState(() => _codeQuery = value.trim()),
                ),
              ),
              SizedBox(
                width: isNarrow ? constraints.maxWidth : 180,
                height: 36,
                child: TextField(
                  controller: _intituleSearchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Intitulé',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.blue.shade500,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  onChanged:
                      (value) => setState(() => _intituleQuery = value.trim()),
                ),
              ),
              if (monthOptions.isNotEmpty)
                SizedBox(
                  width: isNarrow ? constraints.maxWidth : 170,
                  height: 36,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedMonthValue(monthOptions),
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Mois',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.blue.shade500,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    hint: Text(
                      'Tous les mois',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Tous les mois',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...monthOptions.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option.id,
                          child: Text(
                            option.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => _applyMonthSelection(value, monthOptions),
                  ),
                ),
              if (years.isNotEmpty)
                SizedBox(
                  width: isNarrow ? constraints.maxWidth : 130,
                  height: 36,
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear ?? 0,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.blue.shade500,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text(
                          'Toutes années',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...years.map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(
                            year.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        _selectedMonthId != null ? null : _applyYearSelection,
                  ),
                ),
              SizedBox(
                height: 36,
                child: Tooltip(
                  message: 'Réinitialiser les filtres',
                  child: OutlinedButton.icon(
                    onPressed: _hasActiveFilters ? _resetFilters : null,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(
                        color:
                            _hasActiveFilters
                                ? Colors.blue.shade400
                                : Colors.grey.shade300,
                      ),
                      foregroundColor:
                          _hasActiveFilters
                              ? Colors.blue.shade700
                              : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _codeQuery = '';
      _intituleQuery = '';
      _selectedMonthId = null;
      _selectedMonth = null;
      _selectedYear = null;
      _clearSearchControllers();
    });
  }

  Widget _buildNoExercice() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.event_busy, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucun exercice actif trouvé'),
          SizedBox(height: 4),
          Text('Créez ou activez un exercice pour générer les périodes'),
        ],
      ),
    );
  }

  Widget _buildNoJournal() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.book_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucun journal actif'),
          SizedBox(height: 4),
          Text('Ajoutez des journaux dans le module Paramétrages'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.table_rows_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucune combinaison journal/période disponible'),
          SizedBox(height: 4),
          Text('Vérifiez la configuration de l’exercice courant'),
        ],
      ),
    );
  }

  Widget _buildNoFilteredResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucun résultat ne correspond à la recherche'),
          SizedBox(height: 4),
          Text('Ajustez les filtres ou réinitialisez-les'),
        ],
      ),
    );
  }

  // ========== TABLEAU VERSION DataTable (moderne) ==========
  Widget _buildTable(List<_JournalSaisieRow> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.resolveWith(
            (states) => Colors.blue.shade300,
          ),
          dataRowMinHeight: 8,
          dataRowMaxHeight: 14,
          horizontalMargin: 0,
          columnSpacing: 10,
          columns: const [
            DataColumn(
              label: Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('Période', style: TextStyle(color: Colors.white)),
              ),
            ),
            DataColumn(
              label: Text('Code', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text(
                'Intitulé du journal',
                style: TextStyle(color: Colors.white),
              ),
            ),
            DataColumn(
              label: Text(
                'Statut',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
          rows: rows.map(_buildDataRow).toList(),
        );

        return Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: table,
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(_JournalSaisieRow row) {
    final status = _resolveStatus(row);

    return DataRow(
      onSelectChanged: (_) => _handleRowTap(row),
      color: MaterialStateProperty.resolveWith((_) => status.backgroundColor),
      cells: [
        DataCell(
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              _formatMonthLabel(row.mois, row.annee),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        DataCell(
          Text(
            row.journal.code.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
        ),
        DataCell(
          Text(row.journal.intitule, style: const TextStyle(fontSize: 10)),
        ),
        DataCell(_buildStatusChip(status)),
      ],
    );
  }

  Widget _buildStatusChip(_RowStatus status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: status.badgeColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status.label,
          style: TextStyle(color: status.textColor, fontSize: 10),
        ),
      ),
    );
  }

  _RowStatus _resolveStatus(_JournalSaisieRow row) {
    final periode = row.periode;
    int entryCount = 0;
    if (periode != null) {
      entryCount = _entriesByPeriodeId[periode.id] ?? periode.nombreEcritures;
    }
    final hasEntries = entryCount > 0;

    final closureStatus = periode?.closureStatus ?? 0;

    if (closureStatus == 2) {
      return _RowStatus(
        label: 'Clôturé',
        backgroundColor: Colors.red.shade50,
        badgeColor: Colors.red.shade100,
        textColor: Colors.red.shade700,
      );
    }

    if (closureStatus == 1) {
      return _RowStatus(
        label: 'Partiellement clôturé',
        backgroundColor: Colors.orange.shade50,
        badgeColor: Colors.orange.shade100,
        textColor: Colors.orange.shade800,
      );
    }

    if (hasEntries) {
      final String entryLabel =
          entryCount == 1
              ? 'Actif (1 écriture)'
              : 'Actif ($entryCount écritures)';
      return _RowStatus(
        label: entryLabel,
        backgroundColor: Colors.green.shade50,
        badgeColor: Colors.green.shade100,
        textColor: Colors.green.shade700,
      );
    }

    return _RowStatus(
      label: 'Actif (aucune écriture)',
      backgroundColor: Colors.grey.shade100,
      badgeColor: Colors.grey.shade200,
      textColor: Colors.grey.shade800,
    );
  }

  Future<void> _handleRowTap(_JournalSaisieRow row) async {
    if (_isPerformingAction) return;

    setState(() => _isPerformingAction = true);

    try {
      final exerciceId = _exerciceActif?.id;
      if (exerciceId == null) {
        throw Exception('Aucun exercice actif sélectionné');
      }

      JournalPeriode? periode = row.periode;
      periode ??= await SaisieComptableService.createJournalPeriode(
        codeJournal: row.journal.code,
        annee: row.annee,
        mois: row.mois,
        exerciceId: exerciceId,
      );

      if (periode == null) {
        throw Exception('Impossible de préparer la période demandée');
      }

      final JournalPeriode journalPeriode = periode;

      if (widget.onOpenPeriode != null) {
        final shouldRefresh = await widget.onOpenPeriode!(journalPeriode);
        if (shouldRefresh && mounted) {
          await _loadData();
        }
      } else {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SaisieEcriturePage(journalPeriode: journalPeriode),
          ),
        );

        if (mounted) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }
}

class _JournalSaisieRow {
  final int position;
  final Journal journal;
  final int annee;
  final int mois;
  final JournalPeriode? periode;

  const _JournalSaisieRow({
    required this.position,
    required this.journal,
    required this.annee,
    required this.mois,
    this.periode,
  });
}

class _RowStatus {
  final String label;
  final Color textColor;
  final Color badgeColor;
  final Color backgroundColor;

  const _RowStatus({
    required this.label,
    required this.textColor,
    required this.badgeColor,
    required this.backgroundColor,
  });
}