import 'package:flutter/material.dart';
import '../services/database_service.dart';


class JournalResultsPage extends StatefulWidget {
  final String? codeJournal; // null = tous
  final int? moisDebut; // 1-12
  final int? anneeDebut;
  final int? moisFin; // 1-12
  final int? anneeFin;
  final String typeEtat; // 'base' ou 'tiers'
  final bool showAppBar;

  const JournalResultsPage({
    super.key,
    this.codeJournal,
    this.moisDebut,
    this.anneeDebut,
    this.moisFin,
    this.anneeFin,
    this.typeEtat = 'base',
    this.showAppBar = true,
  });

  @override
  State<JournalResultsPage> createState() => _JournalResultsPageState();
}

class _JournalResultsPageState extends State<JournalResultsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_JournalEntryRow> _entries = [];
  Map<String, dynamic>? _entite;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;

      final entiteRows = await db.query('entite', limit: 1);
      final entite = entiteRows.isNotEmpty ? entiteRows.first : null;

      final entries = await db.rawQuery(_buildQuery(), _buildQueryArgs());

      if (!mounted) {
        return;
      }

      setState(() {
        _entite = entite;
        _entries = entries.map(_JournalEntryRow.fromMap).toList();
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

  String _buildQuery() {
    final isTiers = widget.typeEtat == 'tiers';
    final query = StringBuffer();

    if (isTiers) {
      query.write('''
        SELECT
          e.id,
          jp.code_journal,
          COALESCE(j.libelle, jp.code_journal) AS journal_libelle,
          jp.annee,
          jp.mois,
          e.numero_enregistrement,
          e.jour,
          e.date_comptable,
          e.numero_document,
          e.numero_tiers,
          COALESCE(t.intitule, e.numero_tiers) AS libelle,
          e.reference,
          e.montant_debit,
          e.montant_credit,
          e.created_at
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        LEFT JOIN journal j ON j.code = jp.code_journal
        LEFT JOIN tiers t ON e.numero_tiers = t.numero_compte
        WHERE e.numero_tiers IS NOT NULL
      ''');
    } else {
      query.write('''
        SELECT
          e.id,
          jp.code_journal,
          COALESCE(j.libelle, jp.code_journal) AS journal_libelle,
          jp.annee,
          jp.mois,
          e.numero_enregistrement,
          e.jour,
          e.date_comptable,
          e.numero_document,
          e.numero_compte AS numero_tiers,
          e.libelle,
          e.reference,
          e.montant_debit,
          e.montant_credit,
          e.created_at
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        LEFT JOIN journal j ON j.code = jp.code_journal
        WHERE 1 = 1
      ''');
    }

    if (widget.codeJournal != null && widget.codeJournal!.isNotEmpty) {
      query.write(' AND jp.code_journal = ?');
    }

    if (widget.moisDebut != null && widget.anneeDebut != null) {
      query.write(' AND (jp.annee > ? OR (jp.annee = ? AND jp.mois >= ?))');
    }

    if (widget.moisFin != null && widget.anneeFin != null) {
      query.write(' AND (jp.annee < ? OR (jp.annee = ? AND jp.mois <= ?))');
    }

    query.write('''
      ORDER BY
        jp.code_journal ASC,
        jp.annee ASC,
        jp.mois ASC,
        substr(e.date_comptable, 1, 10) ASC,
        e.numero_enregistrement ASC,
        e.id ASC
    ''');

    return query.toString();
  }

  List<dynamic> _buildQueryArgs() {
    final args = <dynamic>[];

    if (widget.codeJournal != null && widget.codeJournal!.isNotEmpty) {
      args.add(widget.codeJournal);
    }

    if (widget.moisDebut != null && widget.anneeDebut != null) {
      args.addAll([widget.anneeDebut, widget.anneeDebut, widget.moisDebut]);
    }

    if (widget.moisFin != null && widget.anneeFin != null) {
      args.addAll([widget.anneeFin, widget.anneeFin, widget.moisFin]);
    }

    return args;
  }

  String _formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    final buffer = StringBuffer();

    for (var i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final remaining = integerPart.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
    }

    return '${buffer.toString()}.$decimalPart';
  }

  String _formatDateDisplay(DateTime? date) {
    if (date == null) {
      return '-';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().padLeft(4, '0')}';
  }

  String _monthLabel(int month, int year) {
    const months = [
      'janvier',
      'fevrier',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'aout',
      'septembre',
      'octobre',
      'novembre',
      'decembre',
    ];

    return '${months[month - 1]} $year';
  }

  String get _pageTitle =>
      widget.typeEtat == 'tiers' ? 'Journal - Tiers' : 'Journal';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text(_pageTitle),
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Telecharger PDF',
                    onPressed: _isLoading ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                  ),
                  IconButton(
                    tooltip: 'Telecharger Excel',
                    onPressed: _isLoading ? null : _exportExcel,
                    icon: const Icon(Icons.table_chart),
                  ),
                ],
              )
              : null,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      if (_entries.isNotEmpty)
                        _buildResultsTable()
                      else
                        _buildNoDataCard(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les resultats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.blue.shade200),
            const SizedBox(height: 16),
            const Text(
              'Aucune ecriture ne correspond aux criteres choisis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final entiteName =
        (_entite?['name']?.toString() ?? 'Entite').replaceAll('"', '').trim();
    final journal =
        (widget.codeJournal != null && widget.codeJournal!.isNotEmpty)
            ? widget.codeJournal!
            : 'Tous les journaux';
    final periode =
        widget.moisDebut != null && widget.anneeDebut != null
            ? '${_monthLabel(widget.moisDebut!, widget.anneeDebut!)} a ${_monthLabel(widget.moisFin!, widget.anneeFin!)}'
            : 'Toutes periodes';

    return Card(
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
                        entiteName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pageTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildHeaderInfo('Journal', journal),
                _buildHeaderInfo('Periode', periode),
                _buildHeaderInfo(
                  'Type',
                  widget.typeEtat == 'tiers' ? 'Tiers' : 'Base',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalDebit = _entries.fold<double>(0, (sum, row) => sum + row.debit);
    final totalCredit = _entries.fold<double>(
      0,
      (sum, row) => sum + row.credit,
    );
    final solde = totalDebit - totalCredit;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              'Ecritures',
              _entries.length.toString(),
              Icons.list_alt,
              Colors.blue,
            ),
            _buildStatCard(
              'Debit',
              _formatAmount(totalDebit),
              Icons.call_made,
              Colors.green,
            ),
            _buildStatCard(
              'Credit',
              _formatAmount(totalCredit),
              Icons.call_received,
              Colors.red,
            ),
            _buildStatCard(
              'Solde',
              _formatAmount(solde),
              Icons.balance,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    final grouped = _groupEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resultats',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildJournalGroupCard(entry.value),
          ),
        ),
      ],
    );
  }

  Map<String, _JournalGroup> _groupEntries() {
    final groups = <String, _JournalGroup>{};

    for (final row in _entries) {
      final journalGroup = groups.putIfAbsent(
        row.codeJournal,
        () => _JournalGroup(
          codeJournal: row.codeJournal,
          journalLibelle: row.journalLibelle,
        ),
      );
      journalGroup.addRow(row);
    }

    final sortedEntries =
        groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sortedEntries);
  }

  Widget _buildJournalGroupCard(_JournalGroup group) {
    final months =
        group.months.entries.toList()
          ..sort((a, b) => a.value.sortKey.compareTo(b.value.sortKey));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          '${group.codeJournal} - ${group.journalLibelle}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${group.monthCount} mois - ${group.entryCount} ecritures - Debit ${_formatAmount(group.totalDebit)} / Credit ${_formatAmount(group.totalCredit)}',
        ),
        children: [
          ...months.map(
            (monthEntry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildMonthCard(monthEntry.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(_JournalMonthGroup group) {
    return Card(
      color: Colors.grey.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: group.entries.length <= 25,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          _monthLabel(group.month, group.year),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${group.entries.length} ecritures - Debit ${_formatAmount(group.totalDebit)} / Credit ${_formatAmount(group.totalCredit)}',
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith(
                (states) => Colors.blue.shade50,
              ),
              columns: const [
                DataColumn(label: Text('Date ecriture')),
                DataColumn(label: Text('N° piece')),
                DataColumn(label: Text('Num./Compte')),
                DataColumn(label: Text('Libelle')),
                DataColumn(label: Text('Debit')),
                DataColumn(label: Text('Credit')),
                DataColumn(label: Text('Reference')),
              ],
              rows:
                  group.entries.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_formatDateDisplay(row.dateEcriture))),
                        DataCell(Text(row.numeroDocument)),
                        DataCell(Text(row.numeroTiers)),
                        DataCell(
                          SizedBox(
                            width: 300,
                            child: Text(
                              row.libelle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(_formatAmount(row.debit))),
                        DataCell(Text(_formatAmount(row.credit))),
                        DataCell(
                          Text(
                            row.reference?.isNotEmpty == true
                                ? row.reference!
                                : '-',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Solde mois: ${_formatAmount(group.totalDebit - group.totalCredit)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export PDF en cours de developpement')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export Excel en cours de developpement')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _JournalEntryRow {
  final int id;
  final String codeJournal;
  final String journalLibelle;
  final int annee;
  final int mois;
  final DateTime? dateEcriture;
  final String numeroDocument;
  final String numeroTiers;
  final String libelle;
  final String? reference;
  final double debit;
  final double credit;

  const _JournalEntryRow({
    required this.id,
    required this.codeJournal,
    required this.journalLibelle,
    required this.annee,
    required this.mois,
    required this.dateEcriture,
    required this.numeroDocument,
    required this.numeroTiers,
    required this.libelle,
    required this.reference,
    required this.debit,
    required this.credit,
  });

  factory _JournalEntryRow.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }

      final raw = value.toString();
      if (raw.isEmpty) {
        return null;
      }

      return DateTime.tryParse(raw);
    }

    return _JournalEntryRow(
      id: (map['id'] as num?)?.toInt() ?? 0,
      codeJournal: (map['code_journal'] ?? '').toString(),
      journalLibelle:
          (map['journal_libelle'] ?? map['code_journal'] ?? '').toString(),
      annee: (map['annee'] as num?)?.toInt() ?? 0,
      mois: (map['mois'] as num?)?.toInt() ?? 0,
      dateEcriture: parseDate(map['date_comptable']),
      numeroDocument: (map['numero_document'] ?? '').toString(),
      numeroTiers: (map['numero_tiers'] ?? '').toString(),
      libelle: (map['libelle'] ?? '').toString(),
      reference: map['reference']?.toString(),
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _JournalGroup {
  final String codeJournal;
  final String journalLibelle;
  final Map<String, _JournalMonthGroup> months = {};
  int entryCount = 0;
  double totalDebit = 0;
  double totalCredit = 0;

  _JournalGroup({required this.codeJournal, required this.journalLibelle});

  void addRow(_JournalEntryRow row) {
    entryCount += 1;
    totalDebit += row.debit;
    totalCredit += row.credit;

    final monthGroup = months.putIfAbsent(
      row.monthKey,
      () => _JournalMonthGroup(year: row.annee, month: row.mois),
    );
    monthGroup.addRow(row);
  }

  int get monthCount => months.length;
}

class _JournalMonthGroup {
  final int year;
  final int month;
  final List<_JournalEntryRow> entries = [];
  double totalDebit = 0;
  double totalCredit = 0;

  _JournalMonthGroup({required this.year, required this.month});

  void addRow(_JournalEntryRow row) {
    entries.add(row);
    totalDebit += row.debit;
    totalCredit += row.credit;
  }

  String get sortKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}

extension on _JournalEntryRow {
  String get monthKey =>
      '${annee.toString().padLeft(4, '0')}-${mois.toString().padLeft(2, '0')}';
}