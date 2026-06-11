import 'package:flutter/material.dart';
import '../services/database_service.dart';

class JournalResultsPage extends StatefulWidget {
  final String? codeJournal;
  final int? moisDebut;
  final int? anneeDebut;
  final int? moisFin;
  final int? anneeFin;
  final String typeEtat;
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
  List<_JournalEntry> _entries = [];
  Map<String, dynamic>? _entite;

  bool get _isAll => widget.codeJournal == null || widget.codeJournal!.isEmpty;

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

      if (!DatabaseService.isConnected) throw Exception('Base de donnees non connectee');

      final db = DatabaseService.database;
      final entiteRows = await db.query('entite', limit: 1);
      final rows = await db.rawQuery(_buildQuery(), _buildArgs());

      if (!mounted) return;
      setState(() {
        _entite = entiteRows.isNotEmpty ? entiteRows.first : null;
        _entries = rows.map(_JournalEntry.fromMap).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _buildQuery() {
    final isTiers = widget.typeEtat == 'tiers';
    final q = StringBuffer();

    if (isTiers) {
      q.write('''
        SELECT
          e.id,
          jp.code_journal,
          COALESCE(j.libelle, jp.code_journal) AS journal_libelle,
          jp.annee,
          jp.mois,
          e.numero_enregistrement,
          e.date_comptable,
          e.jour,
          e.numero_tiers AS numero_compte,
          COALESCE(t.intitule, e.numero_tiers, '') AS compte_intitule,
          e.libelle,
          e.montant_debit,
          e.montant_credit
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        LEFT JOIN journal j ON j.code = jp.code_journal
        LEFT JOIN tiers t ON t.numero_compte = e.numero_tiers
        WHERE e.numero_tiers IS NOT NULL AND TRIM(COALESCE(e.numero_tiers,'')) != ''
      ''');
    } else {
      q.write('''
        SELECT
          e.id,
          jp.code_journal,
          COALESCE(j.libelle, jp.code_journal) AS journal_libelle,
          jp.annee,
          jp.mois,
          e.numero_enregistrement,
          e.date_comptable,
          e.jour,
          e.numero_compte,
          COALESCE(c.intitule, '') AS compte_intitule,
          e.libelle,
          e.montant_debit,
          e.montant_credit
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        LEFT JOIN journal j ON j.code = jp.code_journal
        LEFT JOIN compte c ON c.numero_compte = e.numero_compte
        WHERE 1 = 1
      ''');
    }

    if (!_isAll) q.write(' AND jp.code_journal = ?');

    if (widget.moisDebut != null && widget.anneeDebut != null) {
      q.write(' AND (jp.annee > ? OR (jp.annee = ? AND jp.mois >= ?))');
    }
    if (widget.moisFin != null && widget.anneeFin != null) {
      q.write(' AND (jp.annee < ? OR (jp.annee = ? AND jp.mois <= ?))');
    }

    q.write('''
      ORDER BY
        jp.code_journal ASC,
        jp.annee ASC,
        jp.mois ASC,
        substr(COALESCE(e.date_comptable,''), 1, 10) ASC,
        e.numero_enregistrement ASC,
        e.id ASC
    ''');

    return q.toString();
  }

  List<dynamic> _buildArgs() {
    final args = <dynamic>[];
    if (!_isAll) args.add(widget.codeJournal);
    if (widget.moisDebut != null && widget.anneeDebut != null) {
      args.addAll([widget.anneeDebut, widget.anneeDebut, widget.moisDebut]);
    }
    if (widget.moisFin != null && widget.anneeFin != null) {
      args.addAll([widget.anneeFin, widget.anneeFin, widget.moisFin]);
    }
    return args;
  }

  // ───────────── helpers ─────────────

  String _fmt(double v) {
    if (v == 0) return '';
    final raw = v.toStringAsFixed(0);
    return raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _monthName(int m) {
    const n = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
    ];
    return n[m - 1];
  }

  String get _periodeLabel {
    if (widget.moisDebut == null) return 'Toutes periodes';
    return '${_monthName(widget.moisDebut!)} ${widget.anneeDebut}'
        ' - ${_monthName(widget.moisFin!)} ${widget.anneeFin}';
  }

  // ───────────── build ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                widget.typeEtat == 'tiers' ? 'Journal - Tiers' : 'Journal',
              ),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text('PDF', style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _exportExcel,
                  icon: const Icon(Icons.table_view, color: Colors.white),
                  label: const Text('Excel', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildError()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'JOURNAL${_isAll ? '' : ' - ${widget.codeJournal}'}'
                          ' (${widget.typeEtat == 'tiers' ? 'TIERS' : 'BASE'})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            _buildDocumentHeader(
                              constraints.maxWidth > 900
                                  ? constraints.maxWidth
                                  : 900.0,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_entries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Aucune ecriture ne correspond aux criteres choisis.'),
                          ),
                        )
                      else if (_isAll)
                        ..._buildGroupedTables()
                      else
                        _buildSingleTable(_entries),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
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

  // ───────────── en-tête document (style grand livre) ─────────────

  Widget _buildDocumentHeader(double tableWidth) {
    final entite = _entite?['denomination_sociale']?.toString() ?? '-';
    final nif = _entite?['numero_fiscal']?.toString() ?? '-';
    final adresse = [_entite?['ville'], _entite?['quartier']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');
    final journal = _isAll ? 'Tous les journaux' : widget.codeJournal!;
    final type = widget.typeEtat == 'tiers' ? 'TIERS' : 'BASE';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Table(
          border: TableBorder.all(color: Colors.black54, width: 0.7),
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(0.7),
            3: FlexColumnWidth(1.4),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(1.6),
            6: FlexColumnWidth(0.8),
            7: FlexColumnWidth(1.6),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _headerCell('Dénomination sociale', bold: true),
                _headerCell(entite),
                _headerCell('NIF', bold: true),
                _headerCell(nif),
                _headerCell('Adresse', bold: true),
                _headerCell(adresse.isEmpty ? '-' : adresse),
                _headerCell('Période', bold: true),
                _headerCell(_periodeLabel),
              ],
            ),
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _headerCell('JOURNAL', bold: true),
                _headerCell(journal),
                _headerCell(''),
                _headerCell('TYPE', bold: true),
                _headerCell(type),
                _headerCell(''),
                _headerCell(''),
                _headerCell(''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ───────────── tables ─────────────

  /// Mode ALL : un bloc par journal
  List<Widget> _buildGroupedTables() {
    // Grouper par code_journal
    final grouped = <String, _JournalGroup>{};
    for (final e in _entries) {
      final g = grouped.putIfAbsent(
        e.codeJournal,
        () => _JournalGroup(code: e.codeJournal, libelle: e.journalLibelle),
      );
      g.entries.add(e);
      g.totalDebit += e.debit;
      g.totalCredit += e.credit;
    }

    final sortedGroups = grouped.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return sortedGroups.map((g) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: Colors.blue.shade700,
            child: Text(
              'Journal ${g.code} - ${g.libelle}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          _buildTable(g.entries, showJournalTotals: true, journalGroup: g),
        ],
      );
    }).toList();
  }

  /// Mode code unique : table directe
  Widget _buildSingleTable(List<_JournalEntry> entries) {
    final totalDebit = entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = entries.fold<double>(0, (s, e) => s + e.credit);
    final g = _JournalGroup(
      code: widget.codeJournal ?? '',
      libelle: entries.isNotEmpty ? entries.first.journalLibelle : '',
    )
      ..totalDebit = totalDebit
      ..totalCredit = totalCredit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: Colors.blue.shade700,
          child: Text(
            'Journal ${g.code} - ${g.libelle}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        _buildTable(entries, showJournalTotals: true, journalGroup: g),
      ],
    );
  }

  Widget _buildTable(
    List<_JournalEntry> entries, {
    bool showJournalTotals = false,
    _JournalGroup? journalGroup,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minW = constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minW),
            child: Table(
          border: TableBorder.all(color: Colors.black, width: 0.8),
          columnWidths: const {
            0: FlexColumnWidth(1.2), // Date
            1: FlexColumnWidth(1.1), // N° Compte
            2: FlexColumnWidth(2.5), // Intitulé
            3: FlexColumnWidth(1.2), // N° Enregistrement
            4: FlexColumnWidth(3.5), // Libellé écriture
            5: FlexColumnWidth(1.3), // Débit
            6: FlexColumnWidth(1.3), // Crédit
          },
          children: [
            // En-tête colonnes
            _tableRow(
              ['Date', 'N Compte', 'Intitule', 'N Enreg.', 'Libelle', 'Debit', 'Credit'],
              color: const Color(0xFFD8E7F1),
              bold: true,
            ),
            // Lignes
            ...entries.map(
              (e) => _tableRow([
                _fmtDate(e.dateComptable),
                e.numeroCompte,
                e.compteIntitule,
                e.numeroEnregistrement > 0
                    ? e.numeroEnregistrement.toString().padLeft(3, '0')
                    : '-',
                e.libelle,
                _fmt(e.debit),
                _fmt(e.credit),
              ]),
            ),
            // Ligne totaux
            if (showJournalTotals && journalGroup != null)
              _tableRow(
                [
                  '',
                  '',
                  '',
                  '',
                  'TOTAL  (${entries.length} ecritures)',
                  _fmt(journalGroup.totalDebit),
                  _fmt(journalGroup.totalCredit),
                ],
                color: const Color(0xFFD8E7F1),
                bold: true,
              ),
          ],
        ),
          ),
        );
      },
    );
  }

  TableRow _tableRow(List<String> values, {Color? color, bool bold = false}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.white),
      children: values.asMap().entries.map((entry) {
        final isAmount = entry.key >= 5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Text(
            entry.value,
            textAlign: isAmount ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ───────────── exports (placeholder) ─────────────

  Future<void> _exportPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export PDF en cours de developpement')),
    );
  }

  Future<void> _exportExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export Excel en cours de developpement')),
    );
  }
}

// ═══════════════════════════ Modèles ═══════════════════════════

class _JournalEntry {
  final int id;
  final String codeJournal;
  final String journalLibelle;
  final int annee;
  final int mois;
  final int numeroEnregistrement;
  final DateTime? dateComptable;
  final String numeroCompte;
  final String compteIntitule;
  final String libelle;
  final double debit;
  final double credit;

  const _JournalEntry({
    required this.id,
    required this.codeJournal,
    required this.journalLibelle,
    required this.annee,
    required this.mois,
    required this.numeroEnregistrement,
    required this.dateComptable,
    required this.numeroCompte,
    required this.compteIntitule,
    required this.libelle,
    required this.debit,
    required this.credit,
  });

  factory _JournalEntry.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return _JournalEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      codeJournal: map['code_journal']?.toString() ?? '',
      journalLibelle: (map['journal_libelle'] ?? map['code_journal'] ?? '').toString(),
      annee: (map['annee'] as num?)?.toInt() ?? 0,
      mois: (map['mois'] as num?)?.toInt() ?? 0,
      numeroEnregistrement: (map['numero_enregistrement'] as num?)?.toInt() ?? 0,
      dateComptable: parseDate(map['date_comptable']),
      numeroCompte: map['numero_compte']?.toString() ?? '',
      compteIntitule: map['compte_intitule']?.toString() ?? '',
      libelle: map['libelle']?.toString() ?? '',
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _JournalGroup {
  final String code;
  final String libelle;
  final List<_JournalEntry> entries = [];
  double totalDebit = 0;
  double totalCredit = 0;

  _JournalGroup({required this.code, required this.libelle});
}
