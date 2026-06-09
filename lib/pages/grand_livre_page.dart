import 'package:flutter/material.dart';

import '../models/exercice.dart';
import '../services/database_service.dart';

class GrandLivreScreen extends StatefulWidget {
  final bool showAppBar;

  const GrandLivreScreen({super.key, this.showAppBar = true});

  @override
  State<GrandLivreScreen> createState() => _GrandLivreScreenState();
}

class _GrandLivreScreenState extends State<GrandLivreScreen> {
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
  final _compteDebutController = TextEditingController();
  final _compteFinController = TextEditingController();

  bool _isLoading = true;
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

  @override
  void initState() {
    super.initState();
    _loadHeaderData();
  }

  @override
  void dispose() {
    _compteDebutController.dispose();
    _compteFinController.dispose();
    super.dispose();
  }

  Future<void> _loadHeaderData() async {
    try {
      setState(() {
        _isLoadingExercice = true;
        _exerciceError = null;
      });

      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
      final entiteRows = await db.query('entite', limit: 1);
      final exerciceRows = await db.query(
        'exercice',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'date_debut DESC',
        limit: 1,
      );

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
        _isLoading = false;
      });
    }
  }

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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

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
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  (String, List<dynamic>) _buildQuery(DateTime startDate, DateTime endDate) {
    final query = StringBuffer('''
      SELECT
        e.id,
        e.numero_compte,
        c.intitule AS compte_intitule,
        jp.code_journal,
        e.numero_document,
        e.reference,
        e.libelle,
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
        date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) ASC,
        jp.code_journal ASC,
        e.numero_enregistrement ASC,
        e.id ASC
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
      ),
    );
  }

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
          ],
        ),
      ),
    );
  }

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
        ],
      ),
    );
  }

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
      ),
    );
  }

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
    );
  }
}

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
}

class _GrandLivreRow {
  final int id;
  final String numeroCompte;
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
    required this.numeroEnregistrement,
    required this.debit,
    required this.credit,
  });

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
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _CompteGroup {
  final String numeroCompte;
  final String intitule;
  final List<_GrandLivreRow> rows = [];
  double totalDebit = 0;
  double totalCredit = 0;
  double _runningBalance = 0;

  _CompteGroup({required this.numeroCompte, required this.intitule});

  void addRow(_GrandLivreRow row) {
    rows.add(row);
    totalDebit += row.debit;
    totalCredit += row.credit;
    _runningBalance += row.debit - row.credit;
  }

  double get runningBalance => _runningBalance;
}
