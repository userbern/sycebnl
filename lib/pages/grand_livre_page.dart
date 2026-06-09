import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../models/bailleur.dart';
import '../models/exercice.dart';
import '../models/projet.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

enum _CompteFilterMode { all, single, range }
enum _GrandLivreType { general, tiers, analytique, tiersAnalytique }
=======
import '../models/exercice.dart';
import '../services/database_service.dart';
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf

class GrandLivreScreen extends StatefulWidget {
  final bool showAppBar;

  const GrandLivreScreen({super.key, this.showAppBar = true});

  @override
  State<GrandLivreScreen> createState() => _GrandLivreScreenState();
}

class _GrandLivreScreenState extends State<GrandLivreScreen> {
<<<<<<< HEAD
  final _formKey = GlobalKey<FormState>();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
=======
  static const List<String> _monthLabels = [
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

  final _formKey = GlobalKey<FormState>();
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
  final _compteDebutController = TextEditingController();
  final _compteFinController = TextEditingController();

  bool _isLoading = true;
<<<<<<< HEAD
  String? _errorMessage;

  Exercice? _exercice;
  List<Projet> _projets = [];
  List<Bailleur> _bailleurs = [];
  List<Bailleur> _bailleursProjet = [];

  DateTime? _dateDebut;
  DateTime? _dateFin;
  _CompteFilterMode _compteMode = _CompteFilterMode.all;
  _GrandLivreType _type = _GrandLivreType.general;
  int? _projetId;
  final Set<int> _bailleurIds = {};

  bool get _isAnalytique =>
      _type == _GrandLivreType.analytique ||
      _type == _GrandLivreType.tiersAnalytique;
=======
  bool _isLoadingExercice = true;
  String? _errorMessage;
  String? _exerciceError;
  Exercice? _exercice;
  Map<String, dynamic>? _entite;
  List<_GrandLivreRow> _rows = [];
  List<_CompteGroup> _groups = [];

  int? _moisDebut;
  int? _moisFin;
  String _compteMode = 'all';
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadInitialData();
=======
    _loadHeaderData();
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _dateDebutController.dispose();
    _dateFinController.dispose();
=======
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
    _compteDebutController.dispose();
    _compteFinController.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  Future<void> _loadInitialData() async {
    try {
=======
  Future<void> _loadHeaderData() async {
    try {
      setState(() {
        _isLoadingExercice = true;
        _exerciceError = null;
      });

>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
<<<<<<< HEAD
=======
      final entiteRows = await db.query('entite', limit: 1);
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      final exerciceRows = await db.query(
        'exercice',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'date_debut DESC',
        limit: 1,
      );
<<<<<<< HEAD
      final projets = await AuthService.getProjets();
      final bailleurs = await AuthService.getBailleurs();

      final exercice =
          exerciceRows.isNotEmpty ? Exercice.fromMap(exerciceRows.first) : null;
      if (exercice == null) {
        throw Exception('Aucun exercice actif trouve');
      }

      if (!mounted) return;
      setState(() {
        _exercice = exercice;
        _dateDebut = exercice.dateDebut;
        _dateFin = exercice.dateFin;
        _dateDebutController.text = _formatDate(exercice.dateDebut);
        _dateFinController.text = _formatDate(exercice.dateFin);
        _projets = projets;
        _bailleurs = bailleurs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
=======

      if (!mounted) {
        return;
      }

      setState(() {
        _entite = entiteRows.isNotEmpty ? entiteRows.first : null;
        _exercice =
            exerciceRows.isNotEmpty
                ? Exercice.fromMap(exerciceRows.first)
                : null;
        _isLoadingExercice = false;
        _moisDebut = _exerciseMonthRange().first;
        _moisFin = null;
      });

      if (_exercice == null) {
        _exerciceError = 'Aucun exercice actif trouve';
      }

      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingExercice = false;
        _exerciceError = e.toString();
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
        _isLoading = false;
      });
    }
  }

<<<<<<< HEAD
  Future<void> _loadBailleursForProjet(int? projetId) async {
    _bailleurIds.clear();
    _bailleursProjet = [];
    if (projetId == null) return;

    final rows = await AuthService.getBailleursForProjet(projetId);
    final byId = {for (final bailleur in _bailleurs) bailleur.id: bailleur};
    setState(() {
      _bailleursProjet =
          rows
              .map((row) => byId[(row['id'] as num?)?.toInt()])
              .whereType<Bailleur>()
              .toList();
    });
  }

  Future<void> _selectDate({required bool isStart}) async {
    final exercice = _exercice;
    if (exercice == null) return;

    final current = isStart ? _dateDebut : _dateFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(current ?? exercice.dateDebut),
      firstDate: exercice.dateDebut,
      lastDate: exercice.dateFin,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _dateDebut = picked;
        _dateDebutController.text = _formatDate(picked);
        if (_dateFin != null && _dateFin!.isBefore(picked)) {
          _dateFin = picked;
          _dateFinController.text = _formatDate(picked);
        }
      } else {
        _dateFin = picked;
        _dateFinController.text = _formatDate(picked);
      }
    });
  }

  DateTime _clampDate(DateTime date) {
    final exercice = _exercice;
    if (exercice == null) return date;
    if (date.isBefore(exercice.dateDebut)) return exercice.dateDebut;
    if (date.isAfter(exercice.dateFin)) return exercice.dateFin;
    return date;
  }

  Future<void> _openResults() async {
    if (_exercice == null || _dateDebut == null || _dateFin == null) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;

    if (_dateDebut!.isAfter(_dateFin!)) {
      _showMessage('La date de debut doit etre avant la date de fin');
      return;
    }

    if (_isAnalytique && _projetId == null) {
      _showMessage('Veuillez selectionner un projet');
      return;
    }

    if (_isAnalytique && _bailleurIds.isEmpty) {
      _showMessage('Veuillez selectionner au moins un bailleur');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _GrandLivreResultPage(
              criteria: _GrandLivreCriteria(
                exercice: _exercice!,
                dateDebut: _dateDebut!,
                dateFin: _dateFin!,
                compteMode: _compteMode,
                compteDebut: _compteDebutController.text.trim(),
                compteFin: _compteFinController.text.trim(),
                type: _type,
                projetId: _projetId,
                projetLabel: _selectedProjetLabel(),
                bailleurIds: _bailleurIds.toList(),
                bailleursLabel: _selectedBailleursLabel(),
              ),
            ),
      ),
    );
  }

  String _selectedProjetLabel() {
    if (!_isAnalytique || _projetId == null) return '';
    for (final projet in _projets) {
      if (projet.id == _projetId) {
        return '${projet.code} - ${projet.nom}';
      }
    }
    return '';
  }

  String _selectedBailleursLabel() {
    if (!_isAnalytique) return '';
    return _bailleurs
        .where((b) => b.id != null && _bailleurIds.contains(b.id))
        .map((b) => b.sigle)
        .join(', ');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _typeLabel(_GrandLivreType type) {
    switch (type) {
      case _GrandLivreType.general:
        return 'GENERAL';
      case _GrandLivreType.tiers:
        return 'TIERS';
      case _GrandLivreType.analytique:
        return 'ANALYTIQUE';
      case _GrandLivreType.tiersAnalytique:
        return 'TIERS & ANALYTIQUE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Grand Livre - Filtres'),
                backgroundColor: Colors.lightBlue.shade600,
                foregroundColor: Colors.white,
              )
              : null,
      backgroundColor: const Color(0xFFE9E4DA),
      body: SafeArea(
        child:
            _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Text(
                        'GRAND LIVRE ${_typeLabel(_type)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildFilters(),
                  ],
                ),
      ),
    );
  }

  Widget _buildFilters() {
    final exercice = _exercice;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exercice != null)
                Text(
                  'Exercice en cours : ${_formatDate(exercice.dateDebut)} - ${_formatDate(exercice.dateFin)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _dateField('Date debut', _dateDebutController, true),
                  _dateField('Date fin', _dateFinController, false),
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<_GrandLivreType>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: _GrandLivreType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          _type = value;
                          if (!_isAnalytique) {
                            _projetId = null;
                            _bailleurIds.clear();
                            _bailleursProjet = [];
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _compteMode == _CompteFilterMode.all,
                    onSelected: (_) => setState(() {
                      _compteMode = _CompteFilterMode.all;
                      _compteDebutController.clear();
                      _compteFinController.clear();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Un seul'),
                    selected: _compteMode == _CompteFilterMode.single,
                    onSelected: (_) => setState(() {
                      _compteMode = _CompteFilterMode.single;
                      _compteFinController.clear();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Plage'),
                    selected: _compteMode == _CompteFilterMode.range,
                    onSelected: (_) => setState(() => _compteMode = _CompteFilterMode.range),
                  ),
                  if (_compteMode != _CompteFilterMode.all)
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _compteDebutController,
                        decoration: InputDecoration(
                          labelText: _compteMode == _CompteFilterMode.single ? 'Compte' : 'Compte debut',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_compteMode == _CompteFilterMode.single &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Obligatoire';
                          }
                          return null;
                        },
                      ),
                    ),
                  if (_compteMode == _CompteFilterMode.range)
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _compteFinController,
                        decoration: const InputDecoration(labelText: 'Compte fin', border: OutlineInputBorder()),
                      ),
                    ),
                ],
              ),
              if (_isAnalytique) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 360,
                      child: DropdownButtonFormField<int>(
                        value: _projetId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Projet', border: OutlineInputBorder()),
                        items: _projets
                            .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.code} - ${p.nom}')))
                            .toList(),
                        onChanged: (value) async {
                          setState(() => _projetId = value);
                          await _loadBailleursForProjet(value);
                        },
                        validator: (_) => _isAnalytique && _projetId == null ? 'Obligatoire' : null,
                      ),
                    ),
                    SizedBox(
                      width: 520,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_bailleursProjet.isEmpty ? _bailleurs : _bailleursProjet)
                            .map(
                              (b) => FilterChip(
                                label: Text(b.sigle),
                                selected: b.id != null && _bailleurIds.contains(b.id),
                                onSelected: (selected) {
                                  if (b.id == null) return;
                                  setState(() {
                                    selected ? _bailleurIds.add(b.id!) : _bailleurIds.remove(b.id);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _openResults,
                  icon: const Icon(Icons.search),
                  label: const Text('Afficher les resultats'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller, bool isStart) {
    return SizedBox(
      width: 200,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () => _selectDate(isStart: isStart),
        validator: (value) => value == null || value.isEmpty ? 'Obligatoire' : null,
      ),
    );
  }
}

class _GrandLivreResultPage extends StatefulWidget {
  final _GrandLivreCriteria criteria;

  const _GrandLivreResultPage({required this.criteria});

  @override
  State<_GrandLivreResultPage> createState() => _GrandLivreResultPageState();
}

class _GrandLivreResultPageState extends State<_GrandLivreResultPage> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  Map<String, dynamic>? _entite;
  List<_CompteGroup> _groups = [];

  _GrandLivreCriteria get _criteria => widget.criteria;

  bool get _isAnalytique =>
      _criteria.type == _GrandLivreType.analytique ||
      _criteria.type == _GrandLivreType.tiersAnalytique;

  bool get _isTiers =>
      _criteria.type == _GrandLivreType.tiers ||
      _criteria.type == _GrandLivreType.tiersAnalytique;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
=======
  List<int> _exerciseMonthRange() {
    final exercice = _exercice;
    if (exercice == null) {
      return List<int>.generate(12, (index) => index + 1);
    }

    final months = <int>[];
    var current = DateTime(exercice.dateDebut.year, exercice.dateDebut.month);
    final end = DateTime(exercice.dateFin.year, exercice.dateFin.month);

    while (!current.isAfter(end)) {
      months.add(current.month);
      current = DateTime(current.year, current.month + 1);
      if (months.length > 24) {
        break;
      }
    }

    if (months.isEmpty) {
      return List<int>.generate(12, (index) => index + 1);
    }

    return months;
  }

  DateTime _monthStart(int month, {int? year}) {
    final exercice = _exercice;
    final resolvedYear =
        year ?? exercice?.dateDebut.year ?? DateTime.now().year;
    return DateTime(resolvedYear, month, 1);
  }

  DateTime _monthEnd(int month, {int? year}) {
    final start = _monthStart(month, year: year);
    return DateTime(start.year, start.month + 1, 0, 23, 59, 59, 999);
  }

  DateTime? _getStartDate() {
    if (_moisDebut == null) {
      return null;
    }
    return _monthStart(_moisDebut!);
  }

  DateTime? _getEndDate() {
    final exercice = _exercice;
    if (exercice == null || _moisDebut == null) {
      return null;
    }

    if (_moisFin != null) {
      return _monthEnd(_moisFin!);
    }

    return exercice.dateFin;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatAmount(double value) {
    final isNegative = value < 0;
    final absolute = value.abs().toStringAsFixed(0);
    final buffer = StringBuffer();

    for (var i = 0; i < absolute.length; i++) {
      buffer.write(absolute[i]);
      final remaining = absolute.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
    }

    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }

  String _monthLabel(int month) => _monthLabels[month - 1];

  String _periodLabel() {
    if (_moisDebut == null) {
      return '-';
    }

    final start = _monthLabel(_moisDebut!);
    if (_moisFin != null) {
      return '$start - ${_monthLabel(_moisFin!)}';
    }

    return start;
  }

  Future<void> _loadData() async {
    if (_exercice == null) {
      return;
    }

    final formState = _formKey.currentState;
    if (formState != null && !formState.validate()) {
      return;
    }

    final startDate = _getStartDate();
    final endDate = _getEndDate();
    if (startDate == null || endDate == null) {
      return;
    }

>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

<<<<<<< HEAD
      final db = DatabaseService.database;
      final entiteRows = await db.query('entite', limit: 1);
      final rows = await db.rawQuery(_movementSql(), _movementArgs());
      final entries = rows.map(_GrandLivreRow.fromMap).toList();
      final groups = await _buildGroups(entries);

      if (!mounted) return;
      setState(() {
        _entite = entiteRows.isNotEmpty ? entiteRows.first : null;
=======
      final queryData = _buildQuery(startDate, endDate);
      final rows = await DatabaseService.database.rawQuery(
        queryData.$1,
        queryData.$2,
      );

      if (!mounted) {
        return;
      }

      final entries = rows.map(_GrandLivreRow.fromMap).toList();
      final groups = _groupRows(entries);

      setState(() {
        _rows = entries;
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
<<<<<<< HEAD
      if (!mounted) return;
=======
      if (!mounted) {
        return;
      }
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

<<<<<<< HEAD
  Future<List<_CompteGroup>> _buildGroups(List<_GrandLivreRow> rows) async {
    final grouped = <String, _CompteGroup>{};
    for (final row in rows) {
      final key =
          _isTiers ? (row.numeroTiers ?? row.numeroCompte) : row.numeroCompte;
      final intitule =
          _isTiers
              ? (row.tiersIntitule.isNotEmpty ? row.tiersIntitule : key)
              : row.compteIntitule;
      final group = grouped.putIfAbsent(
        key,
        () => _CompteGroup(numeroCompte: key, intitule: intitule),
      );
      group.addRow(row);
    }

    for (final group in grouped.values) {
      group.openingBalance = await _openingBalance(group.numeroCompte);
      group.recomputeRunningBalance();
    }

    return grouped.values.toList()
      ..sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));
  }

  Future<double> _openingBalance(String accountOrTiers) async {
    if (_isTiers) return 0;

    final first = accountOrTiers.isEmpty ? '' : accountOrTiers[0];
    if (!['1', '2', '3', '4', '5'].contains(first)) return 0;

    final args = <dynamic>[
      _formatSqlDate(_criteria.exercice.dateDebut),
      _formatSqlDate(_criteria.dateDebut.subtract(const Duration(days: 1))),
      accountOrTiers,
    ];
    final where = StringBuffer('''
      date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)))
        BETWEEN date(?) AND date(?)
      AND e.numero_compte = ?
    ''');

    _appendAnalyticWhere(where, args);
    final rows = await DatabaseService.database.rawQuery('''
      SELECT COALESCE(SUM(e.montant_debit), 0) AS debit,
             COALESCE(SUM(e.montant_credit), 0) AS credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      ${_isAnalytique ? 'JOIN ventilations_analytiques va ON va.ecriture_id = e.id AND va.deleted_at IS NULL' : ''}
      WHERE $where
    ''', args);

    final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    return ((row['debit'] as num?)?.toDouble() ?? 0) -
        ((row['credit'] as num?)?.toDouble() ?? 0);
  }

  String _movementSql() {
    final where = StringBuffer('''
      date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)))
        BETWEEN date(?) AND date(?)
    ''');
    final args = _movementArgs();
    _appendAccountWhere(where, args, mutate: false);
    _appendAnalyticWhere(where, args, mutate: false);

    return '''
      SELECT
        e.id,
        e.numero_compte,
        e.numero_tiers,
        COALESCE(c.intitule, '') AS compte_intitule,
        COALESCE(t.intitule, '') AS tiers_intitule,
=======
  (String, List<dynamic>) _buildQuery(DateTime startDate, DateTime endDate) {
    final query = StringBuffer('''
      SELECT
        e.id,
        e.numero_compte,
        c.intitule AS compte_intitule,
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
        jp.code_journal,
        e.numero_document,
        e.reference,
        e.libelle,
<<<<<<< HEAD
        COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)) AS date_comptable,
        e.jour,
        e.numero_enregistrement,
        e.montant_debit,
        e.montant_credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      LEFT JOIN compte c ON c.numero_compte = e.numero_compte
      LEFT JOIN tiers t ON t.numero_compte = e.numero_tiers
      ${_isAnalytique ? 'JOIN ventilations_analytiques va ON va.ecriture_id = e.id AND va.deleted_at IS NULL' : ''}
      WHERE $where
      ${_isTiers ? "AND e.numero_tiers IS NOT NULL AND TRIM(e.numero_tiers) <> ''" : ''}
      ORDER BY ${_isTiers ? 'e.numero_tiers' : 'e.numero_compte'} ASC,
=======
        e.lettrage_code,
        e.date_comptable,
        e.jour,
        e.numero_enregistrement,
        e.montant_debit,
        e.montant_credit,
        jp.annee,
        jp.mois
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      LEFT JOIN compte c ON c.numero_compte = e.numero_compte
      WHERE date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) BETWEEN date(?) AND date(?)
    ''');

    final args = <dynamic>[
      startDate.toIso8601String().substring(0, 10),
      endDate.toIso8601String().substring(0, 10),
    ];

    final compteDebut = _compteDebutController.text.trim();
    final compteFin = _compteFinController.text.trim();

    if (_compteMode == 'single' && compteDebut.isNotEmpty) {
      query.write(' AND e.numero_compte = ?');
      args.add(compteDebut);
    } else {
      if (compteDebut.isNotEmpty) {
        query.write(' AND e.numero_compte >= ?');
        args.add(compteDebut);
      }
      if (compteFin.isNotEmpty) {
        query.write(' AND e.numero_compte <= ?');
        args.add(compteFin);
      }
    }

    query.write('''
      ORDER BY
        e.numero_compte ASC,
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
        date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) ASC,
        jp.code_journal ASC,
        e.numero_enregistrement ASC,
        e.id ASC
<<<<<<< HEAD
    ''';
  }

  List<dynamic> _movementArgs() {
    final args = <dynamic>[
      _formatSqlDate(_criteria.dateDebut),
      _formatSqlDate(_criteria.dateFin),
    ];
    final where = StringBuffer();
    _appendAccountWhere(where, args);
    _appendAnalyticWhere(where, args);
    return args;
  }

  void _appendAccountWhere(
    StringBuffer where,
    List<dynamic> args, {
    bool mutate = true,
  }) {
    if (_criteria.compteMode == _CompteFilterMode.single &&
        _criteria.compteDebut.isNotEmpty) {
      where.write(' AND e.numero_compte = ?');
      if (mutate) args.add(_criteria.compteDebut);
    } else if (_criteria.compteMode == _CompteFilterMode.range) {
      if (_criteria.compteDebut.isNotEmpty) {
        where.write(' AND e.numero_compte >= ?');
        if (mutate) args.add(_criteria.compteDebut);
      }
      if (_criteria.compteFin.isNotEmpty) {
        where.write(' AND e.numero_compte <= ?');
        if (mutate) args.add(_criteria.compteFin);
      }
    }
  }

  void _appendAnalyticWhere(
    StringBuffer where,
    List<dynamic> args, {
    bool mutate = true,
  }) {
    if (!_isAnalytique) return;
    where.write(' AND va.id_projet = ?');
    if (mutate) args.add(_criteria.projetId);

    if (_criteria.bailleurIds.isNotEmpty) {
      where.write(
        ' AND va.id_bailleur IN (${_criteria.bailleurIds.map((_) => '?').join(', ')})',
      );
      if (mutate) args.addAll(_criteria.bailleurIds);
    }
  }

  Future<void> _exportPdf() async {
    await _export(() async {
      await ExportService.exportGrandLivrePDF(
        entite: _entite,
        dateDebut: _criteria.dateDebut,
        dateFin: _criteria.dateFin,
        typeLabel: _typeLabel(_criteria.type),
        projetLabel: _criteria.projetLabel,
        bailleursLabel: _criteria.bailleursLabel,
        groups: _groups.map((g) => g.toExportMap()).toList(),
        context: context,
      );
    });
  }

  Future<void> _exportExcel() async {
    await _export(() async {
      await ExportService.exportGrandLivreExcel(
        entite: _entite,
        dateDebut: _criteria.dateDebut,
        dateFin: _criteria.dateFin,
        typeLabel: _typeLabel(_criteria.type),
        projetLabel: _criteria.projetLabel,
        bailleursLabel: _criteria.bailleursLabel,
        groups: _groups.map((g) => g.toExportMap()).toList(),
        context: context,
      );
    });
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_groups.isEmpty) {
      _showMessage('Aucun resultat a exporter');
      return;
    }
    setState(() => _isExporting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatSqlDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatAmount(double value) {
    if (value.abs() < 0.005) return '';
    final sign = value < 0 ? '-' : '';
    final raw = value.abs().toStringAsFixed(0);
    return '$sign${raw.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}';
  }

  String _typeLabel(_GrandLivreType type) {
    switch (type) {
      case _GrandLivreType.general:
        return 'GENERAL';
      case _GrandLivreType.tiers:
        return 'TIERS';
      case _GrandLivreType.analytique:
        return 'ANALYTIQUE';
      case _GrandLivreType.tiersAnalytique:
        return 'TIERS & ANALYTIQUE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grand Livre ${_typeLabel(_criteria.type)}'),
        backgroundColor: Colors.lightBlue.shade600,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _isExporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('PDF', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: _isExporting ? null : _exportExcel,
            icon: const Icon(Icons.table_view, color: Colors.white),
            label: const Text('Excel', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: const Color(0xFFE9E4DA),
      body: SafeArea(
        child:
            _errorMessage != null
                ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Text(
                        'GRAND LIVRE ${_typeLabel(_criteria.type)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildDocumentHeader(),
                    const SizedBox(height: 18),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_groups.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucune ecriture ne correspond aux filtres.',
                          ),
                        ),
                      )
                    else
                      ..._groups.map(_buildAccountTable),
                  ],
                ),
=======
    ''');

    return (query.toString(), args);
  }

  List<_CompteGroup> _groupRows(List<_GrandLivreRow> rows) {
    final groups = <String, _CompteGroup>{};

    for (final row in rows) {
      final group = groups.putIfAbsent(
        row.numeroCompte,
        () => _CompteGroup(
          numeroCompte: row.numeroCompte,
          intitule: row.compteIntitule,
        ),
      );
      group.addRow(row);
    }

    final ordered =
        groups.values.toList()
          ..sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));
    return ordered;
  }

  void _applyQuickFilter(String mode) {
    setState(() {
      _compteMode = mode;
      if (mode == 'all') {
        _compteDebutController.clear();
        _compteFinController.clear();
      }
      if (mode == 'single') {
        _compteFinController.clear();
      }
    });
  }

  Widget _buildMonthDropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    final months = _exerciseMonthRange();

    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          months
              .map(
                (month) => DropdownMenuItem<int>(
                  value: month,
                  child: Text(_monthLabel(month)),
                ),
              )
              .toList(),
      onChanged: onChanged,
      validator: (selected) {
        if (selected == null) {
          return 'Champ obligatoire';
        }
        return null;
      },
    );
  }

  Widget _buildFilterCard() {
    final exercice = _exercice;
    final periodeTexte =
        exercice == null
            ? '-'
            : '${_formatDate(exercice.dateDebut)} au ${_formatDate(exercice.dateFin)}';

    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _entite?['name']?.toString().trim().isNotEmpty == true
                              ? _entite!['name'].toString().trim()
                              : 'Grand livre des comptes',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Période de référence: $periodeTexte',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoadingExercice)
                const LinearProgressIndicator()
              else if (_exerciceError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _exerciceError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _buildMonthDropdown(
                        label: 'Période début',
                        value: _moisDebut,
                        onChanged: (value) {
                          setState(() {
                            _moisDebut = value;
                            if (_moisFin != null &&
                                value != null &&
                                _moisFin! < value) {
                              _moisFin = null;
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<int?>(
                        value: _moisFin,
                        decoration: const InputDecoration(
                          labelText: 'Période fin (optionnelle)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Jusqu’à la fin de l’exercice'),
                          ),
                          ..._exerciseMonthRange().map(
                            (month) => DropdownMenuItem<int?>(
                              value: month,
                              child: Text(_monthLabel(month)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _moisFin = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Text(
                'Comptes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('Tous les comptes'),
                    selected: _compteMode == 'all',
                    onSelected: (_) => _applyQuickFilter('all'),
                  ),
                  ChoiceChip(
                    label: const Text('Compte spécifique'),
                    selected: _compteMode == 'single',
                    onSelected: (_) => _applyQuickFilter('single'),
                  ),
                  ChoiceChip(
                    label: const Text('Plage de comptes'),
                    selected: _compteMode == 'range',
                    onSelected: (_) => _applyQuickFilter('range'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_compteMode == 'single')
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _compteDebutController,
                    decoration: const InputDecoration(
                      labelText: 'N° compte',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (_compteMode == 'single' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Saisir un compte';
                      }
                      return null;
                    },
                  ),
                )
              else if (_compteMode == 'range')
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _compteDebutController,
                        decoration: const InputDecoration(
                          labelText: 'N° compte début',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _compteFinController,
                        decoration: const InputDecoration(
                          labelText: 'N° compte fin (optionnel)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(Icons.search),
                  label: const Text('Afficher le grand livre'),
                ),
              ),
            ],
          ),
        ),
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildDocumentHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _infoBox(
              'Denomination sociale',
              _entite?['denomination_sociale']?.toString() ?? '-',
            ),
            _infoBox('NIF', _entite?['numero_fiscal']?.toString() ?? '-'),
            _infoBox(
              'Adresse',
              [
                _entite?['ville'],
                _entite?['quartier'],
              ].where((v) => v != null && v.toString().isNotEmpty).join(', '),
            ),
            _infoBox(
              'Periode',
              '${_formatDate(_criteria.dateDebut)} - ${_formatDate(_criteria.dateFin)}',
              highlight: true,
            ),
            _infoBox('TYPE', _typeLabel(_criteria.type)),
            if (_isAnalytique) _infoBox('PROJET', _criteria.projetLabel),
            if (_isAnalytique)
              _infoBox('BAILLEUR', _criteria.bailleursLabel, highlight: true),
=======
  Widget _buildHeaderCard() {
    final entiteName =
        _entite?['name']?.toString().trim().isNotEmpty == true
            ? _entite!['name'].toString().trim()
            : 'Société';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entiteName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Impression provisoire'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    'Grand-livre des comptes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text('Complet'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Période du ${_formatDate(_getStartDate())} au ${_formatDate(_getEndDate())}',
                  ),
                  const SizedBox(height: 4),
                  const Text('Tenue de compte : FCFA'),
                ],
              ),
            ),
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _infoBox(String label, String value, {bool highlight = false}) {
    return SizedBox(
      width: 370,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFFFFF8BE) : Colors.white,
              border: Border.all(color: Colors.blueGrey.shade100),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
=======
  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: const [
          _HeaderCell(label: 'Date', flex: 1),
          _HeaderCell(label: 'CJ', flex: 1),
          _HeaderCell(label: 'N° pièce', flex: 1),
          _HeaderCell(label: 'Libellé écriture', flex: 3),
          _HeaderCell(label: 'Let', flex: 1),
          _HeaderCell(label: 'Mouvement débit', flex: 2),
          _HeaderCell(label: 'Mouvement crédit', flex: 2),
          _HeaderCell(label: 'Solde progressif', flex: 2),
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildAccountTable(_CompteGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Text(
              'Compte ${group.numeroCompte} - ${group.intitule}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1220),
              child: Table(
                border: TableBorder.all(color: Colors.black, width: 0.8),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(.9),
                  2: FlexColumnWidth(1.3),
                  3: FlexColumnWidth(3.2),
                  4: FlexColumnWidth(1.2),
                  5: FlexColumnWidth(1.2),
                  6: FlexColumnWidth(1.3),
                },
                children: [
                  _tableRow(
                    [
                      'Date',
                      'Journal',
                      'N enregis.',
                      'Libelle',
                      'Debit',
                      'Credit',
                      'Solde',
                    ],
                    color: const Color(0xFFD8E7F1),
                    bold: true,
                  ),
                  _tableRow(
                    [
                      '',
                      '',
                      '',
                      'Solde d\'ouverture',
                      '',
                      '',
                      _formatAmount(group.openingBalance),
                    ],
                    color: const Color(0xFFEEF6FB),
                    bold: true,
                  ),
                  ...group.rows.map(
                    (row) => _tableRow([
                      row.dateComptable == null
                          ? '-'
                          : _formatDate(row.dateComptable!),
                      row.codeJournal,
                      row.numeroEnregistrement.toString().padLeft(3, '0'),
                      row.libelle,
                      _formatAmount(row.debit),
                      _formatAmount(row.credit),
                      _formatAmount(row.runningBalance),
                    ]),
                  ),
                  _tableRow(
                    [
                      '',
                      '',
                      '',
                      'TOTAL COMPTE ${group.numeroCompte}',
                      _formatAmount(group.totalDebit),
                      _formatAmount(group.totalCredit),
                      _formatAmount(group.finalBalance),
                    ],
                    color: const Color(0xFFD8E7F1),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
=======
  Widget _buildResultsTable() {
    if (_groups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune écriture ne correspond aux critères choisis.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1220),
          child: Column(
            children: [
              _buildTableHeader(),
              ..._groups.expand((group) => _buildGroupRows(group)),
            ],
          ),
        ),
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      ),
    );
  }

<<<<<<< HEAD
  TableRow _tableRow(List<String> values, {Color? color, bool bold = false}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.white),
      children:
          values
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text(
                    entry.value,
                    textAlign:
                        entry.key >= 4 ? TextAlign.right : TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                    ),
                  ),
                ),
              )
              .toList(),
=======
  List<Widget> _buildGroupRows(_CompteGroup group) {
    final rows = <Widget>[];

    rows.add(
      Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: const Border(
            bottom: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  group.numeroCompte,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  group.intitule,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    for (var index = 0; index < group.rows.length; index++) {
      final row = group.rows[index];
      final isEven = index % 2 == 0;
      rows.add(
        Container(
          decoration: BoxDecoration(
            color: isEven ? Colors.white : Colors.grey.shade50,
            border: const Border(
              bottom: BorderSide(color: Colors.black, width: 0.6),
            ),
          ),
          child: Row(
            children: [
              _BodyCell(label: _formatDate(row.dateComptable), flex: 1),
              _BodyCell(label: row.codeJournal, flex: 1),
              _BodyCell(label: row.numeroPiece, flex: 1),
              _BodyCell(label: row.libelle, flex: 3, alignLeft: true),
              _BodyCell(
                label: row.lettrage.isEmpty ? '-' : row.lettrage,
                flex: 1,
              ),
              _BodyCell(
                label: row.debit > 0 ? _formatAmount(row.debit) : '',
                flex: 2,
              ),
              _BodyCell(
                label: row.credit > 0 ? _formatAmount(row.credit) : '',
                flex: 2,
              ),
              _BodyCell(
                label: _formatAmount(row.runningBalance),
                flex: 2,
                bold: true,
              ),
            ],
          ),
        ),
      );
    }

    rows.add(
      Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: const Border(
            bottom: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  'Total compte ${group.numeroCompte}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  group.rows.isNotEmpty
                      ? _formatDate(group.rows.first.dateComptable)
                      : '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  _formatAmount(group.totalDebit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Text(
                  _formatAmount(group.totalCredit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  _formatAmount(group.runningBalance),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final startDate = _getStartDate();
    final endDate = _getEndDate();

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Grand livre des comptes'),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              )
              : null,
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFilterCard(),
                      const SizedBox(height: 16),
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      if (startDate != null && endDate != null)
                        Text(
                          'Résultats: ${_formatDate(startDate)} au ${_formatDate(endDate)} - Comptes: ${_compteMode == 'all'
                              ? 'tous'
                              : _compteMode == 'single'
                              ? _compteDebutController.text.trim()
                              : '${_compteDebutController.text.trim()}${_compteFinController.text.trim().isNotEmpty ? ' à ${_compteFinController.text.trim()}' : ''}'}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_isLoadingExercice)
                        const LinearProgressIndicator()
                      else if (_groups.isNotEmpty)
                        _buildResultsTable()
                      else if (_isLoading)
                        const LinearProgressIndicator()
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aucune écriture ne correspond aux critères choisis.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
    );
  }
}

<<<<<<< HEAD
class _GrandLivreCriteria {
  final Exercice exercice;
  final DateTime dateDebut;
  final DateTime dateFin;
  final _CompteFilterMode compteMode;
  final String compteDebut;
  final String compteFin;
  final _GrandLivreType type;
  final int? projetId;
  final String projetLabel;
  final List<int> bailleurIds;
  final String bailleursLabel;

  const _GrandLivreCriteria({
    required this.exercice,
    required this.dateDebut,
    required this.dateFin,
    required this.compteMode,
    required this.compteDebut,
    required this.compteFin,
    required this.type,
    required this.projetId,
    required this.projetLabel,
    required this.bailleurIds,
    required this.bailleursLabel,
  });
=======
class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;

  const _HeaderCell({required this.label, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool bold;
  final bool alignLeft;

  const _BodyCell({
    required this.label,
    required this.flex,
    this.bold = false,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Text(
          label,
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
}

class _GrandLivreRow {
  final int id;
  final String numeroCompte;
<<<<<<< HEAD
  final String? numeroTiers;
  final String compteIntitule;
  final String tiersIntitule;
  final String codeJournal;
  final String numeroDocument;
  final String libelle;
  final DateTime? dateComptable;
  final int numeroEnregistrement;
  final double debit;
  final double credit;
  double runningBalance = 0;

  _GrandLivreRow({
    required this.id,
    required this.numeroCompte,
    required this.numeroTiers,
    required this.compteIntitule,
    required this.tiersIntitule,
    required this.codeJournal,
    required this.numeroDocument,
    required this.libelle,
    required this.dateComptable,
=======
  final String compteIntitule;
  final String codeJournal;
  final String numeroPiece;
  final String libelle;
  final String lettrage;
  final DateTime? dateComptable;
  final int jour;
  final int numeroEnregistrement;
  final double debit;
  final double credit;

  const _GrandLivreRow({
    required this.id,
    required this.numeroCompte,
    required this.compteIntitule,
    required this.codeJournal,
    required this.numeroPiece,
    required this.libelle,
    required this.lettrage,
    required this.dateComptable,
    required this.jour,
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
    required this.numeroEnregistrement,
    required this.debit,
    required this.credit,
  });

<<<<<<< HEAD
  factory _GrandLivreRow.fromMap(Map<String, dynamic> map) {
    return _GrandLivreRow(
      id: (map['id'] as num?)?.toInt() ?? 0,
      numeroCompte: map['numero_compte']?.toString() ?? '',
      numeroTiers: map['numero_tiers']?.toString(),
      compteIntitule: map['compte_intitule']?.toString() ?? '',
      tiersIntitule: map['tiers_intitule']?.toString() ?? '',
      codeJournal: map['code_journal']?.toString() ?? '',
      numeroDocument: map['numero_document']?.toString() ?? '',
      libelle: map['libelle']?.toString() ?? '',
      dateComptable: DateTime.tryParse(map['date_comptable']?.toString() ?? ''),
      numeroEnregistrement: (map['numero_enregistrement'] as num?)?.toInt() ?? 0,
=======
  double get runningBalance => debit - credit;

  factory _GrandLivreRow.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      return DateTime.tryParse(value.toString());
    }

    return _GrandLivreRow(
      id: (map['id'] as num?)?.toInt() ?? 0,
      numeroCompte: (map['numero_compte'] ?? '').toString(),
      compteIntitule: (map['compte_intitule'] ?? '').toString(),
      codeJournal: (map['code_journal'] ?? '').toString(),
      numeroPiece: (map['numero_document'] ?? '').toString(),
      libelle: (map['libelle'] ?? '').toString(),
      lettrage: (map['lettrage_code'] ?? '').toString(),
      dateComptable: parseDate(map['date_comptable']),
      jour: (map['jour'] as num?)?.toInt() ?? 0,
      numeroEnregistrement:
          (map['numero_enregistrement'] as num?)?.toInt() ?? 0,
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }
<<<<<<< HEAD

  Map<String, dynamic> toExportMap() => {
    'date': dateComptable,
    'journal': codeJournal,
    'numero_enregistrement': numeroEnregistrement,
    'libelle': libelle,
    'debit': debit,
    'credit': credit,
    'solde': runningBalance,
  };
=======
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
}

class _CompteGroup {
  final String numeroCompte;
  final String intitule;
  final List<_GrandLivreRow> rows = [];
<<<<<<< HEAD
  double openingBalance = 0;
  double totalDebit = 0;
  double totalCredit = 0;
=======
  double totalDebit = 0;
  double totalCredit = 0;
  double _runningBalance = 0;
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf

  _CompteGroup({required this.numeroCompte, required this.intitule});

  void addRow(_GrandLivreRow row) {
    rows.add(row);
    totalDebit += row.debit;
    totalCredit += row.credit;
<<<<<<< HEAD
  }

  void recomputeRunningBalance() {
    var balance = openingBalance;
    for (final row in rows) {
      balance += row.debit - row.credit;
      row.runningBalance = balance;
    }
  }

  double get finalBalance => openingBalance + totalDebit - totalCredit;

  Map<String, dynamic> toExportMap() => {
    'numero': numeroCompte,
    'intitule': intitule,
    'opening_balance': openingBalance,
    'total_debit': totalDebit,
    'total_credit': totalCredit,
    'final_balance': finalBalance,
    'rows': rows.map((r) => r.toExportMap()).toList(),
  };
=======
    _runningBalance += row.debit - row.credit;
  }

  double get runningBalance => _runningBalance;
>>>>>>> fdfbe506bd0a646aa4f104eb94b9f8da607afdcf
}
