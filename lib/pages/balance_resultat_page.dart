import 'package:flutter/material.dart';
import '../models/exercice.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class BalanceResultatPage extends StatefulWidget {
  final String typeEtat; // 'general' ou 'analytique'
  final int? projetId;
  final List<int>? bailleursSelectionnes;
  final bool tousLesBailleurs;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int? exerciceId;
  final String? compteDebut;
  final String? compteFin;
  final bool inclureComptesSansMouvement;
  final Exercice? exercice;
  final bool showAppBar;

  const BalanceResultatPage({
    super.key,
    required this.typeEtat,
    this.projetId,
    this.bailleursSelectionnes,
    this.tousLesBailleurs = false,
    required this.dateDebut,
    required this.dateFin,
    this.exerciceId,
    this.compteDebut,
    this.compteFin,
    this.inclureComptesSansMouvement = false,
    this.exercice,
    this.showAppBar = true,
  });

  @override
  State<BalanceResultatPage> createState() => _BalanceResultatPageState();
}

class _BalanceResultatPageState extends State<BalanceResultatPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _comptes = [];
  String? _errorMessage;
  Map<String, dynamic>? _entite;
  String? _projetDesignation;
  String? _bailleursDesignation;
  double _soldeOuvertureDebit = 0.0;
  double _soldeOuvertureCredit = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }

      final db = DatabaseService.database;

      // Contraintes de dates — normalisées à minuit côté Dart,
      // la date de fin couvre toute la journée jusqu'à 23:59:59 en SQL.
      final dateDebutStr =
          '${widget.dateDebut.year.toString().padLeft(4, '0')}-'
          '${widget.dateDebut.month.toString().padLeft(2, '0')}-'
          '${widget.dateDebut.day.toString().padLeft(2, '0')}';
      final dateFinStr =
          '${widget.dateFin.year.toString().padLeft(4, '0')}-'
          '${widget.dateFin.month.toString().padLeft(2, '0')}-'
          '${widget.dateFin.day.toString().padLeft(2, '0')}';

      // La condition SQL couvre toute la journée de dateFin (jusqu'à 23:59:59)
      // en comparant la date seule avec substr() si date_comptable est un datetime,
      // ou directement si c'est un format DATE.

      final isTiers =
          widget.typeEtat == 'tiers' || widget.typeEtat == 'tiers_analytique';
      final isAnalytique =
          widget.typeEtat == 'analytique' ||
          widget.typeEtat == 'tiers_analytique';

      String query;
      final queryArgs = <dynamic>[];

      if (isTiers) {
        query = '''
          SELECT 
            e.numero_tiers AS numero_compte,
            COALESCE(t.intitule, 'Tiers') AS intitule,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) < date(?) OR (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_debit ELSE 0 END), 0) as ouverture_debit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) < date(?) OR (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_credit ELSE 0 END), 0) as ouverture_credit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) BETWEEN date(?) AND date(?) AND NOT (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_debit ELSE 0 END), 0) as mouvement_debit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) BETWEEN date(?) AND date(?) AND NOT (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_credit ELSE 0 END), 0) as mouvement_credit
          FROM ecritures e
          LEFT JOIN tiers t ON e.numero_tiers = t.numero_compte
          LEFT JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        ''';

        // Utiliser INNER JOIN pour les ventilations analytiques si filtrage actif
        if (isAnalytique &&
            (widget.projetId != null ||
                (!widget.tousLesBailleurs &&
                    widget.bailleursSelectionnes != null &&
                    widget.bailleursSelectionnes!.isNotEmpty))) {
          query += '''
          INNER JOIN ventilations_analytiques va ON e.id = va.ecriture_id AND va.deleted_at IS NULL
          ''';
        }

        query += '''
          WHERE e.numero_tiers IS NOT NULL
        ''';
      } else {
        query = '''
          SELECT 
            c.numero_compte,
            c.intitule,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) < date(?) OR (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_debit ELSE 0 END), 0) as ouverture_debit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) < date(?) OR (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_credit ELSE 0 END), 0) as ouverture_credit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) BETWEEN date(?) AND date(?) AND NOT (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_debit ELSE 0 END), 0) as mouvement_debit,
            COALESCE(SUM(CASE WHEN date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) BETWEEN date(?) AND date(?) AND NOT (date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) = date(?) AND jp.code_journal = 'AN') THEN e.montant_credit ELSE 0 END), 0) as mouvement_credit
          FROM compte c
          LEFT JOIN ecritures e ON c.numero_compte = e.numero_compte
          LEFT JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        ''';

        // Utiliser INNER JOIN pour les ventilations analytiques si filtrage actif
        if (isAnalytique &&
            (widget.projetId != null ||
                (!widget.tousLesBailleurs &&
                    widget.bailleursSelectionnes != null &&
                    widget.bailleursSelectionnes!.isNotEmpty))) {
          query += '''
          INNER JOIN ventilations_analytiques va ON e.id = va.ecriture_id AND va.deleted_at IS NULL
          ''';
        }

        query += '''
          WHERE 1=1
        ''';
      }

      queryArgs.addAll([
        dateDebutStr,
        dateDebutStr,
        dateDebutStr,
        dateDebutStr,
        dateDebutStr,
        dateFinStr,
        dateDebutStr,
        dateDebutStr,
        dateFinStr,
        dateDebutStr,
      ]);

      query +=
          ' AND (e.id IS NULL OR date(COALESCE(e.date_comptable, jp.annee || \'-\' || printf(\'%02d\', jp.mois) || \'-\' || printf(\'%02d\', e.jour))) <= date(?))';
      queryArgs.add(dateFinStr);

      if (widget.exerciceId != null) {
        query += ' AND (jp.exercice_id = ? OR jp.exercice_id IS NULL)';
        queryArgs.add(widget.exerciceId);
      }

      // Filtre analytique : projet et bailleurs
      if (isAnalytique) {
        if (widget.projetId != null) {
          query += ' AND va.id_projet = ?';
          queryArgs.add(widget.projetId);
        }

        // Si bailleurs sélectionnés (pas "tous")
        if (!widget.tousLesBailleurs &&
            widget.bailleursSelectionnes != null &&
            widget.bailleursSelectionnes!.isNotEmpty) {
          query +=
              ' AND va.id_bailleur IN (${widget.bailleursSelectionnes!.map((_) => '?').join(', ')})';
          queryArgs.addAll(widget.bailleursSelectionnes!);
        }
      }

      if (isTiers) {
        // Le filtre pour tiers (4%) est déjà dans le WHERE clause
      }

      query +=
          isTiers
              ? '''
        GROUP BY e.numero_tiers, t.intitule
        ORDER BY e.numero_tiers
      '''
              : '''
        GROUP BY c.numero_compte, c.intitule
        ORDER BY c.numero_compte
      ''';

      final results = await db.rawQuery(query, queryArgs);

      // Entité
      Map<String, dynamic>? entite;
      try {
        final rows = await db.query('entite', limit: 1);
        if (rows.isNotEmpty) entite = rows.first;
      } catch (_) {
        entite = null;
      }

      // Projet designation
      String? projetDesignation;
      if (widget.projetId != null) {
        try {
          final rows = await db.query(
            'projet',
            where: 'id = ?',
            whereArgs: [widget.projetId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            projetDesignation = rows.first['designation'] as String?;
          }
        } catch (_) {
          projetDesignation = null;
        }
      }

      // Bailleurs designations
      String? bailleursDesignation;
      if (widget.tousLesBailleurs) {
        bailleursDesignation = 'Tous';
      } else if (widget.bailleursSelectionnes != null &&
          widget.bailleursSelectionnes!.isNotEmpty) {
        try {
          final rows = await db.query(
            'bailleur',
            where:
                'id IN (${widget.bailleursSelectionnes!.map((_) => '?').join(', ')})',
            whereArgs: widget.bailleursSelectionnes,
          );
          if (rows.isNotEmpty) {
            final designations =
                rows.map((row) => row['designation'] as String).toList();
            bailleursDesignation = designations.join(', ');
          }
        } catch (_) {
          bailleursDesignation = null;
        }
      }

      if (!mounted) return;

      final comptes = <Map<String, dynamic>>[];
      for (final row in results) {
        final numeroCompte = (row['numero_compte'] as String?) ?? '';
        if (!_isCompteInPrefixRange(numeroCompte)) {
          continue;
        }

        // Comptes 1–5 = bilan (solde reporté), comptes 6–8 = gestion (repart à zéro)
        final firstDigit = int.tryParse(
          numeroCompte.trim().isNotEmpty ? numeroCompte.trim()[0] : '0',
        ) ?? 0;
        final isBilan = firstDigit >= 1 && firstDigit <= 5;

        final rawOuvertureDebit =
            (row['ouverture_debit'] as num?)?.toDouble() ?? 0.0;
        final rawOuvertureCredit =
            (row['ouverture_credit'] as num?)?.toDouble() ?? 0.0;
        final mouvementDebit =
            (row['mouvement_debit'] as num?)?.toDouble() ?? 0.0;
        final mouvementCredit =
            (row['mouvement_credit'] as num?)?.toDouble() ?? 0.0;
        // Ouverture nulle pour les comptes de gestion
        final ouvertureSolde = isBilan
            ? (rawOuvertureDebit - rawOuvertureCredit)
            : 0.0;
        final clotureSolde = ouvertureSolde + mouvementDebit - mouvementCredit;
        final soldeOuvertureDebit = ouvertureSolde > 0 ? ouvertureSolde : 0.0;
        final soldeOuvertureCredit = ouvertureSolde < 0 ? -ouvertureSolde : 0.0;
        final soldeClotureDebit = clotureSolde > 0 ? clotureSolde : 0.0;
        final soldeClotureCredit = clotureSolde < 0 ? -clotureSolde : 0.0;

        if (!widget.inclureComptesSansMouvement &&
            soldeOuvertureDebit == 0 &&
            soldeOuvertureCredit == 0 &&
            mouvementDebit == 0 &&
            mouvementCredit == 0 &&
            soldeClotureDebit == 0 &&
            soldeClotureCredit == 0) {
          continue;
        }

        comptes.add({
          'numero': numeroCompte,
          'intitule': row['intitule'] as String,
          'ouvertureDebit': soldeOuvertureDebit,
          'ouvertureCredit': soldeOuvertureCredit,
          'mouvementDebit': mouvementDebit,
          'mouvementCredit': mouvementCredit,
          'soldeDebit': soldeClotureDebit,
          'soldeCredit': soldeClotureCredit,
        });
      }

      // Solde d'ouverture : exercice précédent, comptes de bilan (classes 1–5)
      double soldeOuvDebit = 0.0;
      double soldeOuvCredit = 0.0;

      final currentStart = widget.exercice?.dateDebut;
      if (currentStart != null) {
        final currentStartStr =
            '${currentStart.year.toString().padLeft(4, '0')}-'
            '${currentStart.month.toString().padLeft(2, '0')}-'
            '${currentStart.day.toString().padLeft(2, '0')}';

        final prevExRows = await db.rawQuery(
          'SELECT id FROM exercice WHERE date(date_fin) < date(?) ORDER BY date_fin DESC LIMIT 1',
          [currentStartStr],
        );

        if (prevExRows.isNotEmpty) {
          final prevId = prevExRows.first['id'];
          final soldeRows = await db.rawQuery('''
            SELECT
              SUM(CASE WHEN net > 0 THEN net  ELSE 0 END) AS total_debit,
              SUM(CASE WHEN net < 0 THEN -net ELSE 0 END) AS total_credit
            FROM (
              SELECT
                e.numero_compte,
                COALESCE(SUM(e.montant_debit), 0) - COALESCE(SUM(e.montant_credit), 0) AS net
              FROM ecritures e
              JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
              JOIN compte c ON e.numero_compte = c.numero_compte
              WHERE jp.exercice_id = ?
                AND CAST(SUBSTR(TRIM(c.numero_compte), 1, 1) AS INTEGER) BETWEEN 1 AND 5
              GROUP BY e.numero_compte
            )
          ''', [prevId]);

          if (soldeRows.isNotEmpty) {
            soldeOuvDebit  = (soldeRows.first['total_debit']  as num?)?.toDouble() ?? 0.0;
            soldeOuvCredit = (soldeRows.first['total_credit'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      setState(() {
        _comptes = comptes;
        _entite = entite;
        _projetDesignation = projetDesignation;
        _bailleursDesignation = bailleursDesignation;
        _soldeOuvertureDebit = soldeOuvDebit;
        _soldeOuvertureCredit = soldeOuvCredit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _normalizeComptePrefix(String? value) {
    if (value == null) return null;

    final cleaned = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  bool _isCompteInPrefixRange(String numeroCompte) {
    final debutPrefix = _normalizeComptePrefix(widget.compteDebut);
    final finPrefix = _normalizeComptePrefix(widget.compteFin);

    if (debutPrefix == null && finPrefix == null) {
      return true;
    }

    final compteValue = _normalizeComptePrefix(numeroCompte);
    if (compteValue == null) {
      return false;
    }

    var maxLength = compteValue.length;
    if (debutPrefix != null && debutPrefix.length > maxLength) {
      maxLength = debutPrefix.length;
    }
    if (finPrefix != null && finPrefix.length > maxLength) {
      maxLength = finPrefix.length;
    }

    final normalizedCompte = compteValue.padRight(maxLength, '0');

    if (debutPrefix != null) {
      final lowerBound = debutPrefix.padRight(maxLength, '0');
      if (normalizedCompte.compareTo(lowerBound) < 0) {
        return false;
      }
    }

    if (finPrefix != null) {
      final upperBound = finPrefix.padRight(maxLength, '9');
      if (normalizedCompte.compareTo(upperBound) > 0) {
        return false;
      }
    }

    return true;
  }

  String _formatAddress() {
    final parts =
        [
          _entite?['pays'] as String?,
          _entite?['ville'] as String?,
          _entite?['quartier'] as String?,
        ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
    if (parts.isEmpty) return ' ';
    return parts.join(', ');
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

  String _typeLabel() {
    switch (widget.typeEtat) {
      case 'general':
        return 'GÉNÉRAL';
      case 'tiers':
        return 'TIERS';
      case 'tiers_analytique':
        return 'TIERS & ANALYTIQUE';
      default:
        return 'ANALYTIQUE';
    }
  }

  Widget _buildDocumentHeader(double tableWidth) {
    final denSociale = _entite?['denomination_sociale']?.toString() ?? '-';
    final nif = _entite?['numero_fiscal']?.toString() ?? '-';
    final periode =
        '${_formatDate(widget.dateDebut)} - ${_formatDate(widget.dateFin)}';
    final type = _typeLabel();

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
                _headerCell(denSociale),
                _headerCell('NIF', bold: true),
                _headerCell(nif),
                _headerCell('Adresse', bold: true),
                _headerCell(_formatAddress()),
                _headerCell('Période', bold: true),
                _headerCell(periode),
              ],
            ),
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _headerCell('BALANCE', bold: true),
                _headerCell(type),
                _headerCell(''),
                _headerCell('TYPE', bold: true),
                _headerCell(type),
                _headerCell(
                  widget.projetId != null
                      ? 'PROJET : ${_projetDesignation ?? ''}'
                      : '',
                ),
                _headerCell(
                  widget.projetId != null ? 'BAILLEUR' : '',
                  bold: widget.projetId != null,
                ),
                _headerCell(
                  widget.projetId != null
                      ? (_bailleursDesignation ?? '')
                      : '',
                ),
              ],
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Résultats de la Balance',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue.shade700,
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Tooltip(
                      message: 'Exporter en PDF',
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportToPDF,
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                        ),
                        label: const Text('PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Tooltip(
                      message: 'Exporter en Excel',
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportToExcel,
                        icon: const Icon(
                          Icons.table_chart,
                          color: Colors.white,
                        ),
                        label: const Text('Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  'Erreur: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'RÉSULTATS DE LA BALANCE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            _buildDocumentHeader(
                              constraints.maxWidth > 900
                                  ? constraints.maxWidth
                                  : 900.0,
                            ),
                      ),
                    ),
                    // Tableau des comptes
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Ligne de groupe (fusionnée via Row)
                            Container(
                              color: Colors.blue.shade100,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: const SizedBox(height: 26),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "SOLDE D'OUVERTURE",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'MOUVEMENTS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: SizedBox(
                                      height: 26,
                                      child: const Center(
                                        child: Text(
                                          'SOLDE DE CLOTURE',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table pour les lignes de données
                            Table(
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                                verticalInside: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                                top: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(1),
                                3: FlexColumnWidth(1),
                                4: FlexColumnWidth(1),
                                5: FlexColumnWidth(1),
                                6: FlexColumnWidth(1),
                                7: FlexColumnWidth(1),
                              },
                              children: [
                          // Ligne des intitulés de colonnes
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                            ),
                            children: [
                              _cell('N° COMPTE', bold: true),
                              _cell('INTITULES', bold: true),
                              _cell(
                                'DEBITEUR',
                                bold: true,
                                align: TextAlign.center,
                              ),
                              _cell(
                                'CREDITEUR',
                                bold: true,
                                align: TextAlign.center,
                              ),
                              _cell(
                                'DEBIT',
                                bold: true,
                                align: TextAlign.center,
                              ),
                              _cell(
                                'CREDIT',
                                bold: true,
                                align: TextAlign.center,
                              ),
                              _cell(
                                'DEBITEUR',
                                bold: true,
                                align: TextAlign.center,
                              ),
                              _cell(
                                'CREDITEUR',
                                bold: true,
                                align: TextAlign.center,
                              ),
                            ],
                          ),
                          // Ligne solde d'ouverture exercice précédent
                          _buildSoldeOuvertureTableRow(),
                          // Lignes des comptes
                          ..._comptes.asMap().entries.map((entry) {
                            final i = entry.key;
                            final c = entry.value;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: i % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.shade50,
                              ),
                              children: [
                                _cell(c['numero'], bold: true),
                                _cell(c['intitule']),
                                _cell(
                                  (c['ouvertureDebit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['ouvertureDebit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                                _cell(
                                  (c['ouvertureCredit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['ouvertureCredit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                                _cell(
                                  (c['mouvementDebit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['mouvementDebit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                                _cell(
                                  (c['mouvementCredit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['mouvementCredit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                                _cell(
                                  (c['soldeDebit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['soldeDebit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                                _cell(
                                  (c['soldeCredit'] as double? ?? 0) > 0
                                      ? _formatMontant(c['soldeCredit'])
                                      : '',
                                  align: TextAlign.right,
                                  color: Colors.indigo.shade700,
                                ),
                              ],
                            );
                          }),
                          // COMPTES DU BILAN
                          _buildTotalTableRow(
                            'COMPTES DU BILAN',
                            _comptes.where((c) {
                              final n = int.tryParse(
                                    c['numero'].toString().substring(0, 1),
                                  ) ??
                                  0;
                              return n >= 1 && n <= 5;
                            }).toList(),
                          ),
                          // COMPTES DE GESTION
                          _buildTotalTableRow(
                            'COMPTES DE GESTION',
                            _comptes.where((c) {
                              final n = int.tryParse(
                                    c['numero'].toString().substring(0, 1),
                                  ) ??
                                  0;
                              return n >= 6 && n <= 8;
                            }).toList(),
                          ),
                          // TOTAL DE LA BALANCE
                          _buildTotalTableRow(
                            'TOTAL DE LA BALANCE',
                            _comptes,
                            isTotalBalance: true,
                          ),
                              ],
                            ),
                            // NATURE DU RESULTAT (cellules fusionnées via Row)
                            _buildNatureResultatWidget(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
  Widget _cell(
    String text, {
    bool bold = false,
    bool italic = false,
    Color? color,
    TextAlign align = TextAlign.left,
    Widget? child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: child ??
          Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: color,
            ),
          ),
    );
  }

  TableRow _buildSoldeOuvertureTableRow() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.teal.shade50),
      children: [
        _cell(''),
        _cell("Solde d'ouverture", bold: true, italic: true),
        _cell(
          _soldeOuvertureDebit > 0 ? _formatMontant(_soldeOuvertureDebit) : '',
          align: TextAlign.right,
          color: Colors.teal.shade700,
          bold: true,
        ),
        _cell(
          _soldeOuvertureCredit > 0
              ? _formatMontant(_soldeOuvertureCredit)
              : '',
          align: TextAlign.right,
          color: Colors.teal.shade700,
          bold: true,
        ),
        _cell(''), _cell(''), _cell(''), _cell(''),
      ],
    );
  }

  TableRow _buildTotalTableRow(
    String label,
    List<Map<String, dynamic>> comptes, {
    bool isTotalBalance = false,
  }) {
    final oD = comptes.fold<double>(
      0.0, (s, c) => s + (c['ouvertureDebit'] as double? ?? 0));
    final oC = comptes.fold<double>(
      0.0, (s, c) => s + (c['ouvertureCredit'] as double? ?? 0));
    final mD = comptes.fold<double>(
      0.0, (s, c) => s + (c['mouvementDebit'] as double? ?? 0));
    final mC = comptes.fold<double>(
      0.0, (s, c) => s + (c['mouvementCredit'] as double? ?? 0));
    final sD = comptes.fold<double>(
      0.0, (s, c) => s + (c['soldeDebit'] as double? ?? 0));
    final sC = comptes.fold<double>(
      0.0, (s, c) => s + (c['soldeCredit'] as double? ?? 0));

    final diag = _cell(
      '',
      child: Center(
        child: CustomPaint(
          size: const Size(40, 16),
          painter: _DiagonalLinePainter(),
        ),
      ),
    );

    return TableRow(
      decoration: BoxDecoration(color: Colors.blue.shade50),
      children: [
        _cell(label, bold: true),
        _cell(''),
        _cell(oD > 0 ? _formatMontant(oD) : '',
            align: TextAlign.right, bold: true, color: Colors.indigo),
        _cell(oC > 0 ? _formatMontant(oC) : '',
            align: TextAlign.right, bold: true, color: Colors.indigo),
        _cell(_formatMontant(mD),
            align: TextAlign.right, bold: true, color: Colors.indigo),
        _cell(_formatMontant(mC),
            align: TextAlign.right, bold: true, color: Colors.indigo),
        isTotalBalance
            ? diag
            : _cell(sD > 0 ? _formatMontant(sD) : '',
                align: TextAlign.right, bold: true, color: Colors.indigo),
        isTotalBalance
            ? diag
            : _cell(sC > 0 ? _formatMontant(sC) : '',
                align: TextAlign.right, bold: true, color: Colors.indigo),
      ],
    );
  }

  Widget _buildNatureResultatWidget() {
    final gestion = _comptes.where((c) {
      final n = int.tryParse(c['numero'].toString().substring(0, 1)) ?? 0;
      return n >= 6 && n <= 8;
    });
    final tD = gestion.fold<double>(
      0.0, (s, c) => s + (c['mouvementDebit'] as double? ?? 0));
    final tC = gestion.fold<double>(
      0.0, (s, c) => s + (c['mouvementCredit'] as double? ?? 0));

    String nature = 'NUL';
    if (tC > tD) {
      nature = 'EXCEDENT';
    } else if (tC < tD) {
      nature = 'DEFICIT';
    }

    final col = nature == 'EXCEDENT'
        ? Colors.green.shade700
        : nature == 'DEFICIT'
        ? Colors.red.shade700
        : Colors.blue.shade700;

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Row(
        children: [
          // Label sur 2 colonnes (flex 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: const Text(
                'NATURE DU RESULTAT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          // Valeur sur les 6 colonnes restantes (flex 6)
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  nature,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: col,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    try {
      await ExportService.previewPDF(
        title: 'BALANCE DE VERIFICATION',
        entityName: _entite?['denomination_sociale'] ?? 'Non spécifiée',
        periodInfo:
            'Période: ${widget.dateDebut.toString().split(' ')[0]} au ${widget.dateFin.toString().split(' ')[0]}',
        comptes: _comptes,
        totals: null,
        context: context,
        entite: _entite,
        projetDesignation: _projetDesignation,
        bailleursDesignation: _bailleursDesignation,
        typeEtat: widget.typeEtat,
        dateDebut: widget.dateDebut,
        dateFin: widget.dateFin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      await ExportService.generateExcel(
        title: 'BALANCE DE VERIFICATION',
        entityName: _entite?['denomination_sociale'] ?? 'Non spécifiée',
        periodInfo:
            'Période: ${widget.dateDebut.toString().split(' ')[0]} au ${widget.dateFin.toString().split(' ')[0]}',
        comptes: _comptes,
        totals: null,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom Painter pour dessiner une ligne oblique
class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    // Dessiner une ligne de coin en bas à gauche vers le coin en haut à droite
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
