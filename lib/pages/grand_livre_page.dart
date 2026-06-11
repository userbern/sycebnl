import 'package:flutter/material.dart';

import '../models/exercice.dart';
import '../models/projet.dart';
import '../models/bailleur.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

enum _CompteFilterMode { single, range }

enum _GrandLivreType { general, tiers, analytique, tiersAnalytique }

class GrandLivreScreen extends StatefulWidget {
  final bool showAppBar;

  const GrandLivreScreen({super.key, this.showAppBar = true});

  @override
  State<GrandLivreScreen> createState() => _GrandLivreScreenState();
}

class _GrandLivreScreenState extends State<GrandLivreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  final _compteDebutController = TextEditingController();
  final _compteFinController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  Exercice? _exercice;
  List<Projet> _projets = [];
  List<Bailleur> _bailleurs = [];
  List<Bailleur> _bailleursProjet = [];

  DateTime? _dateDebut;
  DateTime? _dateFin;
  _GrandLivreType _type = _GrandLivreType.general;
  int? _projetId;
  final Set<int> _bailleurIds = {};

  bool get _isAnalytique =>
      _type == _GrandLivreType.analytique ||
      _type == _GrandLivreType.tiersAnalytique;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _compteDebutController.dispose();
    _compteFinController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
      final exerciceRows = await db.query(
        'exercice',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'date_debut DESC',
        limit: 1,
      );
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
        _isLoading = false;
      });
    }
  }

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
                compteMode: _CompteFilterMode.range,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Grand Livre - Filtres'),
                backgroundColor: Colors.blue.shade700,
                elevation: 0,
              )
              : null,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 32,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Grand Livre',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          _errorMessage != null
                              ? Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              )
                              : _buildFilters(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final exercice = _exercice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exercice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exercice actif : ${_formatDate(exercice.dateDebut)} → ${_formatDate(exercice.dateFin)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        _buildFormSection(
          title: '🔹 Type d\'état',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_GrandLivreType>(
                      title: const Text('Général'),
                      value: _GrandLivreType.general,
                      groupValue: _type,
                      activeColor: Colors.blue.shade700,
                      dense: true,
                      onChanged: (value) => setState(() {
                        _type = value!;
                        _projetId = null;
                        _bailleurIds.clear();
                        _bailleursProjet = [];
                      }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_GrandLivreType>(
                      title: const Text('Tiers'),
                      value: _GrandLivreType.tiers,
                      groupValue: _type,
                      activeColor: Colors.blue.shade700,
                      dense: true,
                      onChanged: (value) => setState(() {
                        _type = value!;
                        _projetId = null;
                        _bailleurIds.clear();
                        _bailleursProjet = [];
                      }),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_GrandLivreType>(
                      title: const Text('Analytique'),
                      value: _GrandLivreType.analytique,
                      groupValue: _type,
                      activeColor: Colors.blue.shade700,
                      dense: true,
                      onChanged: (value) => setState(() => _type = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_GrandLivreType>(
                      title: const Text('Tiers & Analytique'),
                      value: _GrandLivreType.tiersAnalytique,
                      groupValue: _type,
                      activeColor: Colors.blue.shade700,
                      dense: true,
                      onChanged: (value) => setState(() => _type = value!),
                    ),
                  ),
                ],
              ),
              if (_isAnalytique)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_projets.isEmpty)
                        const Text(
                          'Aucun projet disponible',
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: _projetId,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          decoration: InputDecoration(
                            labelText: 'Projet',
                            hintText: 'Sélectionnez un projet',
                            prefixIcon: const Icon(Icons.business_center),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.blue.shade700,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                          ),
                          items: _projets
                              .map(
                                (p) => DropdownMenuItem<int>(
                                  value: p.id,
                                  child: Text(
                                    '${p.code} - ${p.nom}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() => _projetId = value);
                            await _loadBailleursForProjet(value);
                          },
                          validator: (_) =>
                              _isAnalytique && _projetId == null
                                  ? 'Obligatoire'
                                  : null,
                        ),
                      if (_projetId != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Bailleurs :',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_bailleursProjet.isEmpty
                                  ? _bailleurs
                                  : _bailleursProjet)
                              .map(
                                (b) => FilterChip(
                                  label: Text(b.sigle),
                                  selected:
                                      b.id != null &&
                                      _bailleurIds.contains(b.id),
                                  selectedColor:
                                      Colors.blue.shade100,
                                  onSelected: (selected) {
                                    if (b.id == null) return;
                                    setState(() {
                                      selected
                                          ? _bailleurIds.add(b.id!)
                                          : _bailleurIds.remove(b.id);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 32, thickness: 1),

        _buildFormSection(
          title: '🔹 Période (OBLIGATOIRE)',
          child: Row(
            children: [
              Expanded(child: _dateField('Date début *', _dateDebutController, true)),
              const SizedBox(width: 16),
              Expanded(child: _dateField('Date fin *', _dateFinController, false)),
            ],
          ),
        ),

        const Divider(height: 32, thickness: 1),

        _buildFormSection(
          title: '🔹 Comptes',
          subtitle: 'Laisser vide pour inclure tous les comptes',
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _compteDebutController,
                  decoration: InputDecoration(
                    labelText: 'N° compte début',
                    hintText: 'Ex: 401',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _compteFinController,
                  decoration: InputDecoration(
                    labelText: 'N° compte fin',
                    hintText: 'Ex: 499',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _openResults,
            icon: const Icon(Icons.menu_book, size: 22),
            label: const Text(
              'Afficher le grand livre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller,
    bool isStart,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'jj/mm/aaaa',
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: () => setState(() {
            controller.clear();
            if (isStart) {
              _dateDebut = null;
            } else {
              _dateFin = null;
            }
          }),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
      ),
      onTap: () => _selectDate(isStart: isStart),
      validator: (value) =>
          value == null || value.isEmpty ? 'Obligatoire' : null,
    );
  }

  Widget _buildFormSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      final db = DatabaseService.database;
      final entiteRows = await db.query('entite', limit: 1);
      final rows = await db.rawQuery(_movementSql(), _movementArgs());
      final entries = rows.map(_GrandLivreRow.fromMap).toList();
      final groups = await _buildGroups(entries);

      if (!mounted) return;
      setState(() {
        _entite = entiteRows.isNotEmpty ? entiteRows.first : null;
        _groups = groups;
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
        jp.code_journal,
        e.numero_document,
        e.reference,
        e.libelle,
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
        date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) ASC,
        jp.code_journal ASC,
        e.numero_enregistrement ASC,
        e.id ASC
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        backgroundColor: Colors.blue.shade700,
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
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Text(
                      'GRAND LIVRE ${_typeLabel(_criteria.type)}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentHeader(),
                  const SizedBox(height: 12),
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
                    Column(
                      children: _groups
                          .map((g) => _buildAccountTable(g))
                          .toList(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final denSociale =
        _entite?['denomination_sociale']?.toString() ?? '-';
    final nif = _entite?['numero_fiscal']?.toString() ?? '-';
    final adresse = [
      _entite?['ville'],
      _entite?['quartier'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');
    final periode =
        '${_formatDate(_criteria.dateDebut)} - ${_formatDate(_criteria.dateFin)}';
    final type = _typeLabel(_criteria.type);

    return Table(
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
                _headerCell(denSociale),
                _headerCell('NIF', bold: true),
                _headerCell(nif),
                _headerCell('Adresse', bold: true),
                _headerCell(adresse),
                _headerCell('Période', bold: true),
                _headerCell(periode),
              ],
            ),
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _headerCell('GRAND LIVRE', bold: true),
                _headerCell(type),
                _headerCell(''),
                _headerCell('TYPE', bold: true),
                _headerCell(type),
                _headerCell(
                  _isAnalytique ? 'PROJET : ${_criteria.projetLabel}' : '',
                ),
                _headerCell(
                  _isAnalytique ? 'BAILLEUR' : '',
                  bold: _isAnalytique,
                ),
                _headerCell(
                  _isAnalytique ? _criteria.bailleursLabel : '',
                ),
              ],
            ),
          ],
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

  Widget _buildAccountTable(_CompteGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: Colors.blue.shade700,
          child: Text(
            'Compte ${group.numeroCompte} - ${group.intitule}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Table(
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
              ['Date', 'Journal', 'N enregis.', 'Libelle', 'Debit', 'Credit', 'Solde'],
              color: const Color(0xFFD8E7F1),
              bold: true,
            ),
            _tableRow(
              ['', '', '', 'Solde d\'ouverture', '', '', _formatAmount(group.openingBalance)],
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
                '', '', '',
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
      ],
    );
  }

  TableRow _tableRow(List<String> values, {Color? color, bool bold = false}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.white),
      children: values
          .asMap()
          .entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Text(
                entry.value,
                textAlign: entry.key >= 4 ? TextAlign.right : TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

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
}

class _GrandLivreRow {
  final int id;
  final String numeroCompte;
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
    required this.numeroEnregistrement,
    required this.debit,
    required this.credit,
  });

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
      numeroEnregistrement:
          (map['numero_enregistrement'] as num?)?.toInt() ?? 0,
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toExportMap() => {
    'date': dateComptable,
    'journal': codeJournal,
    'numero_enregistrement': numeroEnregistrement,
    'libelle': libelle,
    'debit': debit,
    'credit': credit,
    'solde': runningBalance,
  };
}

class _CompteGroup {
  final String numeroCompte;
  final String intitule;
  final List<_GrandLivreRow> rows = [];
  double openingBalance = 0;
  double totalDebit = 0;
  double totalCredit = 0;

  _CompteGroup({required this.numeroCompte, required this.intitule});

  void addRow(_GrandLivreRow row) {
    rows.add(row);
    totalDebit += row.debit;
    totalCredit += row.credit;
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
}
