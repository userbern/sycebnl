import 'package:flutter/material.dart';

import '../models/exercice.dart';
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
  Exercice? _currentExercice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
      final journalRows = await db.rawQuery(
        'SELECT * FROM journal ORDER BY code ASC',
      );
      final exerciceRows = await db.rawQuery(
        'SELECT * FROM exercice WHERE is_active = 1 AND is_cloture = 0 LIMIT 1',
      );

      if (!mounted) return;

      setState(() {
        _journals = journalRows.map(Journal.fromMap).toList();
        if (exerciceRows.isNotEmpty) {
          _currentExercice = Exercice.fromMap(exerciceRows.first);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Ouvre un dialog avec champ de recherche intégré pour choisir le code journal
  Future<void> _pickCodeJournal() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _JournalSearchDialog(journals: _journals, selected: _selectedCodeJournal),
    );
    if (result != null) {
      setState(() => _selectedCodeJournal = result);
    }
  }

  List<DateTime> _exerciceMonths() {
    if (_currentExercice == null) return [];
    final months = <DateTime>[];
    var cursor = DateTime(
      _currentExercice!.dateDebut.year,
      _currentExercice!.dateDebut.month,
    );
    final end = DateTime(
      _currentExercice!.dateFin.year,
      _currentExercice!.dateFin.month,
    );
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  Widget _buildPeriodDropdown({required bool isStart}) {
    final months = _exerciceMonths();
    final selectedMonth = isStart
        ? (_moisDebut != null && _anneeDebut != null
            ? DateTime(_anneeDebut!, _moisDebut!)
            : null)
        : (_moisFin != null && _anneeFin != null
            ? DateTime(_anneeFin!, _moisFin!)
            : null);

    // S'assurer que la valeur sélectionnée existe dans la liste
    final validValue = months.any(
      (m) => m.year == selectedMonth?.year && m.month == selectedMonth?.month,
    )
        ? selectedMonth
        : null;

    return DropdownButtonFormField<DateTime>(
      value: validValue,
      decoration: _fieldDecoration(isStart ? 'Debut' : 'Fin'),
      hint: const Text('Selectionner'),
      items: months
          .map(
            (m) => DropdownMenuItem<DateTime>(
              value: m,
              child: Text('${_getMonthLabel(m.month)} ${m.year}'),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          if (isStart) {
            _moisDebut = value.month;
            _anneeDebut = value.year;
          } else {
            _moisFin = value.month;
            _anneeFin = value.year;
          }
        });
      },
    );
  }

  String _getMonthLabel(int month) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  String _journalLabel(String code) {
    if (code == 'ALL') return 'Tous les codes journaux';
    final j = _journals.where((j) => j.code == code).firstOrNull;
    return j != null ? '${j.code} - ${j.intitule}' : code;
  }

  Future<void> _searchResults() async {
    if (_moisDebut == null || _anneeDebut == null || _moisFin == null || _anneeFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez selectionner une periode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalResultsPage(
          codeJournal: _selectedCodeJournal != 'ALL' ? _selectedCodeJournal : null,
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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Journal'),
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: _isLoading
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
        child: Row(
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
                    style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.only(top: 16, left: 96, right: 96),
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
              // Champ cliquable qui ouvre le dialog de recherche
              InkWell(
                onTap: _pickCodeJournal,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _fieldDecoration('Code journal'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _journalLabel(_selectedCodeJournal),
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildFilterGroup('2. Période', [
              Row(
                children: [
                  Expanded(child: _buildPeriodDropdown(isStart: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPeriodDropdown(isStart: false)),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            _buildFilterGroup('3. Type d etat', [
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
          (child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
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

// Dialog de sélection du code journal avec champ de recherche intégré
class _JournalSearchDialog extends StatefulWidget {
  final List<Journal> journals;
  final String selected;

  const _JournalSearchDialog({required this.journals, required this.selected});

  @override
  State<_JournalSearchDialog> createState() => _JournalSearchDialogState();
}

class _JournalSearchDialogState extends State<_JournalSearchDialog> {
  final _searchController = TextEditingController();
  List<Journal> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.journals;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.journals.where((j) {
        return j.code.toLowerCase().contains(q) ||
            j.intitule.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Code journal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  // Option "Tous"
                  ListTile(
                    leading: Icon(
                      Icons.all_inclusive,
                      color: widget.selected == 'ALL' ? Colors.blue : Colors.black38,
                    ),
                    title: const Text('Tous les codes journaux'),
                    selected: widget.selected == 'ALL',
                    selectedTileColor: Colors.blue.shade50,
                    onTap: () => Navigator.pop(context, 'ALL'),
                  ),
                  const Divider(height: 1),
                  ..._filtered.map(
                    (j) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: widget.selected == j.code
                            ? Colors.blue.shade100
                            : Colors.grey.shade100,
                        child: Text(
                          j.code.length > 2 ? j.code.substring(0, 2) : j.code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.selected == j.code
                                ? Colors.blue.shade700
                                : Colors.black54,
                          ),
                        ),
                      ),
                      title: Text(j.code),
                      subtitle: Text(j.intitule, style: const TextStyle(fontSize: 12)),
                      selected: widget.selected == j.code,
                      selectedTileColor: Colors.blue.shade50,
                      onTap: () => Navigator.pop(context, j.code),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
