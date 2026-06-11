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

        final ouvertureDebit =
            (row['ouverture_debit'] as num?)?.toDouble() ?? 0.0;
        final ouvertureCredit =
            (row['ouverture_credit'] as num?)?.toDouble() ?? 0.0;
        final mouvementDebit =
            (row['mouvement_debit'] as num?)?.toDouble() ?? 0.0;
        final mouvementCredit =
            (row['mouvement_credit'] as num?)?.toDouble() ?? 0.0;
        final ouvertureSolde = ouvertureDebit - ouvertureCredit;
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

      setState(() {
        _comptes = comptes;
        _entite = entite;
        _projetDesignation = projetDesignation;
        _bailleursDesignation = bailleursDesignation;
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
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: Column(
                        children: [
                          // Première ligne d'en-tête (titres)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // N° Compte et Intitulé
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 2,
                                    ),
                                    child: const SizedBox(),
                                  ),
                                ),
                                // SOLDE D'OUVERTURE
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'SOLDE D\'OUVERTURE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // MOUVEMENTS
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'MOUVEMENTS',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // SOLDE DE CLOTURE
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'SOLDE DE CLOTURE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Deuxième ligne d'en-têtes (colonnes)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // N° Compte
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.black,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'N° COMPTE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                // Intitulé
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.black,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'INTITULES',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                // Solde d'ouverture - Débiteur
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        'DEBITEUR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Solde d'ouverture - Créditeur
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        'CREDITEUR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Mouvements - Débit
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        'DEBIT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Mouvements - Crédit
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        'CREDIT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Solde de clôture - Débiteur
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        'DEBITEUR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Solde de clôture - Créditeur
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'CREDITEUR',
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
                          // Lignes des comptes
                          ..._comptes.asMap().entries.map((entry) {
                            final index = entry.key;
                            final compte = entry.value;
                            final isEvenRow = index % 2 == 0;

                            return Container(
                              decoration: BoxDecoration(
                                color:
                                    isEvenRow
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // N° Compte
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        compte['numero'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Intitulé
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(compte['intitule']),
                                    ),
                                  ),
                                  // Solde d'ouverture - Débiteur
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['ouvertureDebit']
                                                          as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['ouvertureDebit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Solde d'ouverture - Créditeur
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['ouvertureCredit']
                                                          as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['ouvertureCredit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Mouvements - Débit
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['soldeDebit'] as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['soldeDebit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Mouvements - Crédit
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['soldeCredit'] as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['soldeCredit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Solde de clôture - Débiteur
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['mouvementDebit']
                                                          as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['mouvementDebit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Solde de clôture - Créditeur
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (compte['mouvementCredit']
                                                          as double? ??
                                                      0) >
                                                  0
                                              ? _formatMontant(
                                                compte['mouvementCredit'],
                                              )
                                              : '',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Ligne COMPTES DU BILAN (1-5)
                          _buildTotalRow(
                            label: 'COMPTES DU BILAN',
                            comptes:
                                _comptes.where((c) {
                                  final num =
                                      int.tryParse(
                                        c['numero'].toString().substring(0, 1),
                                      ) ??
                                      0;
                                  return num >= 1 && num <= 5;
                                }).toList(),
                          ),
                          // Ligne COMPTES DE GESTION (6-8)
                          _buildTotalRow(
                            label: 'COMPTES DE GESTION',
                            comptes:
                                _comptes.where((c) {
                                  final num =
                                      int.tryParse(
                                        c['numero'].toString().substring(0, 1),
                                      ) ??
                                      0;
                                  return num >= 6 && num <= 8;
                                }).toList(),
                          ),
                          // Ligne TOTAL DE LA BALANCE
                          _buildTotalRow(
                            label: 'TOTAL DE LA BALANCE',
                            comptes: _comptes,
                            isTotalBalance: true,
                          ),
                          // Ligne NATURE DU RESULTAT
                          _buildNatureResultatRow(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTotalRow({
    required String label,
    required List<Map<String, dynamic>> comptes,
    bool isTotalBalance = false,
  }) {
    final ouvertureDebit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['ouvertureDebit'] as double? ?? 0),
    );
    final ouvertureCredit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['ouvertureCredit'] as double? ?? 0),
    );
    final mouvementDebit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['mouvementDebit'] as double? ?? 0),
    );
    final mouvementCredit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['mouvementCredit'] as double? ?? 0),
    );
    final soldeDebit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['soldeDebit'] as double? ?? 0),
    );
    final soldeCredit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + (c['soldeCredit'] as double? ?? 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          top: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Solde d'ouverture - Débiteur
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  ouvertureDebit > 0 ? _formatMontant(ouvertureDebit) : '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Solde d'ouverture - Créditeur
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  ouvertureCredit > 0 ? _formatMontant(ouvertureCredit) : '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Mouvements - Débit
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  _formatMontant(mouvementDebit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Mouvements - Crédit
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  _formatMontant(mouvementCredit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Solde de clôture - Débiteur (ligne oblique si Total de la Balance)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Center(
                child:
                    isTotalBalance
                        ? CustomPaint(
                          size: const Size(40, 20),
                          painter: _DiagonalLinePainter(),
                        )
                        : Text(
                          soldeDebit > 0 ? _formatMontant(soldeDebit) : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                            fontSize: 14,
                          ),
                        ),
              ),
            ),
          ),
          // Solde de clôture - Créditeur (ligne oblique si Total de la Balance)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child:
                    isTotalBalance
                        ? CustomPaint(
                          size: const Size(40, 20),
                          painter: _DiagonalLinePainter(),
                        )
                        : Text(
                          soldeCredit > 0 ? _formatMontant(soldeCredit) : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                            fontSize: 14,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNatureResultatRow() {
    final comptesGestion = _comptes.where((c) {
      final num = int.tryParse(c['numero'].toString().substring(0, 1)) ?? 0;
      return num >= 6 && num <= 8;
    });

    final totalDebit = comptesGestion.fold<double>(
      0.0,
      (sum, c) => sum + (c['mouvementDebit'] as double? ?? 0),
    );
    final totalCredit = comptesGestion.fold<double>(
      0.0,
      (sum, c) => sum + (c['mouvementCredit'] as double? ?? 0),
    );

    String natureResultat = 'NUL';
    if (totalCredit > totalDebit) {
      natureResultat = 'EXCEDENT';
    } else if (totalCredit < totalDebit) {
      natureResultat = 'DEFICIT';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: const Text(
                'NATURE DU RESULTAT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          // Les 6 dernières cellules fusionnées en une
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Center(
                child: Text(
                  natureResultat,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color:
                        natureResultat == 'EXCEDENT'
                            ? Colors.green.shade700
                            : natureResultat == 'DEFICIT'
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
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
      final file = await ExportService.generateExcel(
        title: 'BALANCE DE VERIFICATION',
        entityName: _entite?['denomination_sociale'] ?? 'Non spécifiée',
        periodInfo:
            'Période: ${widget.dateDebut.toString().split(' ')[0]} au ${widget.dateFin.toString().split(' ')[0]}',
        comptes: _comptes,
        totals: null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fichier Excel créé: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
