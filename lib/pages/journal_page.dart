import 'package:flutter/material.dart';

import '../models/journal.dart';
import '../services/database_service.dart';
import 'journal_results_page.dart';

class JournalPage extends StatefulWidget {
  final bool showAppBar;

  const JournalPage({super.key, this.showAppBar = true});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  String _selectedCodeJournal = 'ALL';
  int? _moisDebut;
  int? _anneeDebut;
  int? _moisFin;
  int? _anneeFin;
  String _typeEtat = 'base';
  List<Journal> _journals = [];
  bool _isLoadingJournals = true;
  String? _journalsError;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
      final journalRows = await db.rawQuery('''
        SELECT *
        FROM journal
        ORDER BY code ASC
      ''');

      if (!mounted) {
        return;
      }

      setState(() {
        _journals = journalRows.map(Journal.fromMap).toList();
        _isLoadingJournals = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _journalsError = e.toString();
        _isLoadingJournals = false;
      });
    }
  }

  Future<void> _selectPeriod(bool isStart) async {
    final now = DateTime.now();
    final currentYear = now.year;

    final yearSelected = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Selectionner l annee'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var year = 2020; year <= currentYear + 1; year++)
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, year),
                      child: Text(year.toString()),
                    ),
                ],
              ),
            ),
          ),
    );

    if (yearSelected == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final monthSelected = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Selectionner le mois'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var month = 1; month <= 12; month++)
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, month),
                      child: Text(_getMonthLabel(month)),
                    ),
                ],
              ),
            ),
          ),
    );

    if (monthSelected == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _anneeDebut = yearSelected;
        _moisDebut = monthSelected;
      } else {
        _anneeFin = yearSelected;
        _moisFin = monthSelected;
      }
    });
  }

  String _getMonthLabel(int month) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aou',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /* String _getPeriodLabel() {
    if (_moisDebut != null &&
        _anneeDebut != null &&
        _moisFin != null &&
        _anneeFin != null) {
      return '${_getMonthLabel(_moisDebut!)}${_anneeDebut.toString().substring(2)} - ${_getMonthLabel(_moisFin!)}${_anneeFin.toString().substring(2)}';
    } else if (_moisDebut != null && _anneeDebut != null) {
      return 'De ${_getMonthLabel(_moisDebut!)}${_anneeDebut.toString().substring(2)}';
    } else if (_moisFin != null && _anneeFin != null) {
      return 'Jusqu a ${_getMonthLabel(_moisFin!)}${_anneeFin.toString().substring(2)}';
    }
    return 'Toutes periodes';
  } */

  Future<void> _searchResults() async {
    if (_moisDebut == null ||
        _anneeDebut == null ||
        _moisFin == null ||
        _anneeFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez selectionner une periode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => JournalResultsPage(
              codeJournal:
                  _selectedCodeJournal != 'ALL' ? _selectedCodeJournal : null,
              moisDebut: _moisDebut,
              anneeDebut: _anneeDebut,
              moisFin: _moisFin,
              anneeFin: _anneeFin,
              typeEtat: _typeEtat,
              showAppBar: true,
            ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCodeJournal = 'ALL';
      _moisDebut = null;
      _anneeDebut = null;
      _moisFin = null;
      _anneeFin = null;
      _typeEtat = 'base';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Journal'),
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
              )
              : null,
      body: SafeArea(
        child:
            _isLoadingJournals
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 24),
                      _buildFiltersCard(),
                      const SizedBox(height: 24),
                      _buildActionsRow(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                  child: Icon(Icons.receipt_long, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultation des ecritures comptables par journal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Le journal regroupe les ecritures valides par code journal puis par mois afin de faciliter la consultation, le controle et l impression.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.only(top: 16, left: 64, right: 64),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paramètres de recherche',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 24),
            _buildFilterGroup('1. Code journal', [
              DropdownButtonFormField<String>(
                value: _selectedCodeJournal,
                decoration: _fieldDecoration('Code journal'),
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('Tous les codes journaux'),
                  ),
                  ..._journals.map(
                    (journal) => DropdownMenuItem(
                      value: journal.code,
                      child: Text('${journal.code} - ${journal.intitule}'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _selectedCodeJournal = value);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildFilterGroup('2. Période', [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectPeriod(true),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Debut',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _moisDebut != null && _anneeDebut != null
                                  ? '${_getMonthLabel(_moisDebut!)} ${_anneeDebut.toString()}'
                                  : 'Non selectionnee',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    _moisDebut != null
                                        ? Colors.black87
                                        : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectPeriod(false),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _moisFin != null && _anneeFin != null
                                  ? '${_getMonthLabel(_moisFin!)} ${_anneeFin.toString()}'
                                  : 'Non selectionnee',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    _moisFin != null
                                        ? Colors.black87
                                        : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            _buildFilterGroup('3. Type d état', [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'base', label: Text('Base')),
                  ButtonSegment(value: 'tiers', label: Text('Tiers')),
                ],
                selected: {_typeEtat},
                onSelectionChanged: (selected) {
                  setState(() => _typeEtat = selected.first);
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _searchResults,
            icon: const Icon(Icons.search),
            label: const Text('Rechercher'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reinitialiser'),
          ),
        ),
      ],
    );
  }
}
