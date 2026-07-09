import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class ExportService {
  /// Génère et sauvegarde un PDF de la balance des résultats avec le même layout que l'interface
  static Future<void> generateAndPrintPDF({
    required String title,
    required String entityName,
    required String periodInfo,
    required List<Map<String, dynamic>> comptes,
    required Map<String, dynamic>? totals,
    required BuildContext context,
  }) async {
    try {
      final pdf = await _generatePDF(
        title: title,
        entityName: entityName,
        periodInfo: periodInfo,
        comptes: comptes,
        totals: totals,
      );

      final fileName =
          'balance_resultat_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: pdf,
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur lors de la génération du PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Génère un aperçu PDF et l'affiche
  static Future<void> previewPDF({
    required String title,
    required String entityName,
    required String periodInfo,
    required List<Map<String, dynamic>> comptes,
    required Map<String, dynamic>? totals,
    required BuildContext context,
    required Map<String, dynamic>? entite,
    required String? projetDesignation,
    required String? bailleursDesignation,
    required String typeEtat,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    try {
      final pdfData = await _generatePDF(
        title: title,
        entityName: entityName,
        periodInfo: periodInfo,
        comptes: comptes,
        totals: totals,
        entite: entite,
        projetDesignation: projetDesignation,
        bailleursDesignation: bailleursDesignation,
        typeEtat: typeEtat,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );

      if (context.mounted) {
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Aperçu PDF'),
                content: Text(
                  'PDF prêt:\n\n${pdfData.length ~/ 1024} KB\n\nVoulez-vous le télécharger?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _savePDF(pdfData, context, title);
                    },
                    child: const Text('Télécharger'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la prévisualisation du PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Crée le document PDF avec le layout exact de l'interface
  static Future<Uint8List> _generatePDF({
    required String title,
    required String entityName,
    required String periodInfo,
    required List<Map<String, dynamic>> comptes,
    required Map<String, dynamic>? totals,
    Map<String, dynamic>? entite,
    String? projetDesignation,
    String? bailleursDesignation,
    String typeEtat = 'general',
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        maxPages: 2000,
        footer: (context) => _pdfFooter(),
        build: (context) {
          return [
              // Titre
              pw.Center(
                child: pw.Text(
                  'RÉSULTATS DE LA BALANCE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Info card (Entité, NIF, Adresse, Période)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Column(
                  children: [
                    // Ligne 1: Dénomination, NIF, Adresse, Période
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoCell('Dénomination sociale', true),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            entite?['denomination_sociale'] as String? ?? ' ',
                            true,
                          ),
                        ),
                        pw.Expanded(child: _buildInfoCell('NIF', true)),
                        pw.Expanded(
                          child: _buildInfoCell(
                            entite?['numero_fiscal'] as String? ?? ' ',
                            false,
                            borderBottom: true,
                          ),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            'Adresse',
                            true,
                            borderBottom: true,
                          ),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            _formatAddress(entite),
                            false,
                            borderBottom: true,
                          ),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            'Période',
                            true,
                            borderBottom: true,
                          ),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            dateDebut != null && dateFin != null
                                ? '${dateDebut.toString().split(' ')[0]} - ${dateFin.toString().split(' ')[0]}'
                                : ' ',
                            false,
                            borderBottom: true,
                          ),
                        ),
                      ],
                    ),
                    // Ligne 2: Type, Projet, Bailleur
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildInfoCell('TYPE', true)),
                        pw.Expanded(
                          child: _buildInfoCell(_getTypeEtat(typeEtat), true),
                        ),
                        pw.Expanded(child: pw.SizedBox()),
                        pw.Expanded(
                          child: _buildInfoCell(
                            'PROJET',
                            true,
                            borderAll: true,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: _buildInfoCell(
                            projetDesignation ?? ' ',
                            false,
                            borderAll: true,
                          ),
                        ),
                        pw.Expanded(
                          child: _buildInfoCell(
                            'BAILLEUR',
                            true,
                            borderAll: true,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: _buildInfoCell(
                            bailleursDesignation ?? '—',
                            false,
                            borderAll: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Tableau des comptes
              _buildBalanceTable(comptes),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoCell(
    String text,
    bool isBold, {
    bool borderBottom = false,
    bool borderAll = false,
  }) {
    final borders =
        borderAll
            ? pw.Border.all(color: PdfColors.black, width: 0.5)
            : borderBottom
            ? pw.Border(
              bottom: const pw.BorderSide(color: PdfColors.black, width: 0.5),
            )
            : pw.Border.all(color: PdfColors.grey300, width: 0.5);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: pw.BoxDecoration(border: borders),
      child: pw.Text(
        _pdfSafe(text),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static String _formatAddress(Map<String, dynamic>? entite) {
    if (entite == null) return '—';
    final address = entite['adresse'] as String? ?? '';
    final ville = entite['ville'] as String? ?? '';
    if (address.isEmpty && ville.isEmpty) return ' ';
    return '$address ${ville.isNotEmpty ? ', $ville' : ''}'.trim();
  }

  static String _getTypeEtat(String typeEtat) {
    switch (typeEtat) {
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

  /// Construit le tableau de balance avec le layout exact
  static pw.Widget _buildBalanceTable(List<Map<String, dynamic>> comptes) {
    final comptesBilan =
        comptes.where((c) {
          final numero = c['numero']?.toString() ?? '';
          final first = int.tryParse(numero.isNotEmpty ? numero[0] : '') ?? 0;
          return first >= 1 && first <= 5;
        }).toList();

    final comptesGestion =
        comptes.where((c) {
          final numero = c['numero']?.toString() ?? '';
          final first = int.tryParse(numero.isNotEmpty ? numero[0] : '') ?? 0;
          return first >= 6 && first <= 8;
        }).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        children: [
          // En-tête du tableau - Titre
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              border: pw.Border(
                bottom: const pw.BorderSide(color: PdfColors.black, width: 1),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: const pw.BorderSide(
                          color: PdfColors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'SOLDE D\'OUVERTURE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: const pw.BorderSide(
                          color: PdfColors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'MOUVEMENTS',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: const pw.BorderSide(
                          color: PdfColors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'SOLDE DE CLOTURE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // En-têtes colonnes
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              border: pw.Border(
                bottom: const pw.BorderSide(color: PdfColors.black, width: 1),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        right: const pw.BorderSide(
                          color: PdfColors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'N° COMPTE',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        right: const pw.BorderSide(
                          color: PdfColors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'INTITULES',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // 8 colonnes pour les montants
                ..._buildHeaderColumns(),
              ],
            ),
          ),
          // Lignes de données
          ...comptes.map((compte) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: const pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          right: const pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: pw.Text(
                        _pdfSafe(compte['numero'] ?? '-'),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          right: const pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: pw.Text(
                        _pdfSafe(compte['intitule'] ?? ' '),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                  // 8 colonnes de montants
                  ..._buildDataColumns(compte),
                ],
              ),
            );
          }),
          _buildTotalSummaryRow(
            label: 'COMPTES DU BILAN',
            comptes: comptesBilan,
          ),
          _buildTotalSummaryRow(
            label: 'COMPTES DE GESTION',
            comptes: comptesGestion,
          ),
          _buildTotalSummaryRow(
            label: 'TOTAL DE LA BALANCE',
            comptes: comptes,
            isTotalBalance: true,
          ),
          _buildNatureResultatRow(comptesGestion),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalSummaryRow({
    required String label,
    required List<Map<String, dynamic>> comptes,
    bool isTotalBalance = false,
  }) {
    final mouvementDebit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + ((c['mouvementDebit'] as num?)?.toDouble() ?? 0.0),
    );
    final mouvementCredit = comptes.fold<double>(
      0.0,
      (sum, c) => sum + ((c['mouvementCredit'] as num?)?.toDouble() ?? 0.0),
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        border: pw.Border(
          top: const pw.BorderSide(color: PdfColors.black, width: 1),
          bottom: const pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: const pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildSummaryValueCell(''),
          _buildSummaryValueCell(''),
          _buildSummaryValueCell(_formatNumber(mouvementDebit)),
          _buildSummaryValueCell(_formatNumber(mouvementCredit)),
          _buildSummaryValueCell(
            isTotalBalance ? '/' : _formatNumber(mouvementDebit),
          ),
          _buildSummaryValueCell(
            isTotalBalance ? '/' : _formatNumber(mouvementCredit),
            hasRightBorder: false,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryValueCell(
    String value, {
    bool hasRightBorder = true,
  }) {
    return pw.Expanded(
      flex: 1,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: pw.BoxDecoration(
          border:
              hasRightBorder
                  ? pw.Border(
                    right: const pw.BorderSide(
                      color: PdfColors.black,
                      width: 1,
                    ),
                  )
                  : null,
        ),
        child: pw.Center(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildNatureResultatRow(
    List<Map<String, dynamic>> comptesGestion,
  ) {
    final totalDebit = comptesGestion.fold<double>(
      0.0,
      (sum, c) => sum + ((c['mouvementDebit'] as num?)?.toDouble() ?? 0.0),
    );
    final totalCredit = comptesGestion.fold<double>(
      0.0,
      (sum, c) => sum + ((c['mouvementCredit'] as num?)?.toDouble() ?? 0.0),
    );

    String natureResultat = 'NUL';
    if (totalCredit > totalDebit) {
      natureResultat = 'EXCEDENT';
    } else if (totalCredit < totalDebit) {
      natureResultat = 'DEFICIT';
    }

    final color =
        natureResultat == 'EXCEDENT'
            ? PdfColors.green700
            : natureResultat == 'DEFICIT'
            ? PdfColors.red700
            : PdfColors.blue700;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: const pw.BorderSide(color: PdfColors.black, width: 1),
          bottom: const pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: const pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Text(
                'NATURE DU RESULTAT',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: pw.Center(
                child: pw.Text(
                  natureResultat,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildHeaderColumns() {
    final headers = [
      'DEBITEUR',
      'CREDITEUR',
      'DEBIT',
      'CREDIT',
      'DEBITEUR',
      'CREDITEUR',
    ];

    return headers.map((header) {
      return pw.Expanded(
        flex: 1,
        child: pw.Container(
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: const pw.BorderSide(color: PdfColors.black, width: 0.5),
            ),
          ),
          child: pw.Center(
            child: pw.Text(
              header,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      );
    }).toList();
  }

  static List<pw.Widget> _buildDataColumns(Map<String, dynamic> compte) {
    final values = [
      '-', // Solde débit (ouverture)
      '-', // Solde crédit (ouverture)
      _formatNumber(compte['soldeDebit'] ?? 0),
      _formatNumber(compte['soldeCredit'] ?? 0),
      _formatNumber(compte['soldeDebit'] ?? 0),
      _formatNumber(compte['soldeCredit'] ?? 0),
    ];

    return values.map((value) {
      return pw.Expanded(
        flex: 1,
        child: pw.Container(
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: const pw.BorderSide(color: PdfColors.black, width: 0.5),
            ),
          ),
          child: pw.Center(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ),
      );
    }).toList();
  }

  static Future<void> _savePDF(
    Uint8List pdfData,
    BuildContext context,
    String title,
  ) async {
    final fileName =
        'balance_resultat_${DateTime.now().toString().split(' ')[0]}.pdf';
    await _saveBytesWithPicker(
      bytes: pdfData,
      suggestedFileName: fileName,
      context: context,
      label: 'PDF',
    );
  }

  /// Exporte la balance des résultats en vrai fichier Excel (.xlsx) formaté
  static Future<File?> generateExcel({
    required String title,
    required String entityName,
    required String periodInfo,
    required List<Map<String, dynamic>> comptes,
    required Map<String, dynamic>? totals,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Balance';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final titleStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final sectionStyle = CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Left,
      );

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      final dataTextStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final dataNumberStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final summaryStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E8EEF9'),
      );

      final natureStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
      );

      double toDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        return double.tryParse(value.toString()) ?? 0.0;
      }

      void setCell(int row, int col, dynamic value, {CellStyle? style}) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );

        if (value is num) {
          cell.value = DoubleCellValue(value.toDouble());
        } else {
          cell.value = TextCellValue((value ?? '').toString());
        }

        if (style != null) {
          cell.cellStyle = style;
        }
      }

      int row = 0;

      setCell(row, 0, title, style: titleStyle);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row),
      );
      row += 2;

      setCell(row, 0, 'Entité', style: sectionStyle);
      setCell(row, 1, entityName);
      row += 1;
      setCell(row, 0, 'Période', style: sectionStyle);
      setCell(row, 1, periodInfo);
      row += 1;
      setCell(row, 0, 'Date d\'export', style: sectionStyle);
      setCell(row, 1, DateTime.now().toString().split('.')[0]);
      row += 2;

      final headers = [
        'N° Compte',
        'Intitulé',
        'Solde Débit',
        'Solde Crédit',
        'Mouvement Débit',
        'Mouvement Crédit',
        'Solde Clôture Débit',
        'Solde Clôture Crédit',
      ];

      for (var col = 0; col < headers.length; col++) {
        setCell(row, col, headers[col], style: headerStyle);
      }
      row += 1;

      for (final compte in comptes) {
        setCell(row, 0, compte['numero'] ?? '-', style: dataTextStyle);
        setCell(row, 1, compte['intitule'] ?? '-', style: dataTextStyle);
        setCell(row, 2, toDouble(compte['soldeDebit']), style: dataNumberStyle);
        setCell(
          row,
          3,
          toDouble(compte['soldeCredit']),
          style: dataNumberStyle,
        );
        setCell(
          row,
          4,
          toDouble(compte['mouvementDebit']),
          style: dataNumberStyle,
        );
        setCell(
          row,
          5,
          toDouble(compte['mouvementCredit']),
          style: dataNumberStyle,
        );
        setCell(
          row,
          6,
          toDouble(compte['soldeClotureDebit']),
          style: dataNumberStyle,
        );
        setCell(
          row,
          7,
          toDouble(compte['soldeClotureCredit']),
          style: dataNumberStyle,
        );
        row += 1;
      }

      row += 1;

      int firstDigit(dynamic numero) {
        final text = (numero ?? '').toString().trim();
        if (text.isEmpty) return 0;
        return int.tryParse(text.substring(0, 1)) ?? 0;
      }

      List<Map<String, dynamic>> filterByClass(int min, int max) {
        return comptes.where((compte) {
          final digit = firstDigit(compte['numero']);
          return digit >= min && digit <= max;
        }).toList();
      }

      List<dynamic> summaryRow(String label, List<Map<String, dynamic>> rows) {
        final debit = rows.fold<double>(
          0.0,
          (sum, row) => sum + toDouble(row['mouvementDebit']),
        );
        final credit = rows.fold<double>(
          0.0,
          (sum, row) => sum + toDouble(row['mouvementCredit']),
        );

        return [label, '', '', '', debit, credit, debit, credit];
      }

      final comptesBilan = filterByClass(1, 5);
      final comptesGestion = filterByClass(6, 8);

      final totalGestionDebit = comptesGestion.fold<double>(
        0.0,
        (sum, row) => sum + toDouble(row['mouvementDebit']),
      );
      final totalGestionCredit = comptesGestion.fold<double>(
        0.0,
        (sum, row) => sum + toDouble(row['mouvementCredit']),
      );

      String natureResultat = 'NUL';
      if (totalGestionCredit > totalGestionDebit) {
        natureResultat = 'EXCEDENT';
      } else if (totalGestionCredit < totalGestionDebit) {
        natureResultat = 'DEFICIT';
      }

      final summaryRows = [
        summaryRow('COMPTES DU BILAN', comptesBilan),
        summaryRow('COMPTES DE GESTION', comptesGestion),
        summaryRow('TOTAL DE LA BALANCE', comptes),
      ];

      for (final values in summaryRows) {
        for (var col = 0; col < values.length; col++) {
          setCell(row, col, values[col], style: summaryStyle);
        }
        row += 1;
      }

      setCell(row, 0, 'NATURE DU RESULTAT', style: natureStyle);
      setCell(row, 1, natureResultat, style: natureStyle);
      for (var col = 2; col < 8; col++) {
        setCell(row, col, '', style: natureStyle);
      }
      row += 1;

      // Ajouter les totaux si disponibles
      if (totals != null) {
        row += 1;
        final totalValues = [
          'TOTAL',
          '',
          totals['totalSoldeDebit'] ?? 0,
          totals['totalSoldeCredit'] ?? 0,
          totals['totalMouvementDebit'] ?? 0,
          totals['totalMouvementCredit'] ?? 0,
          totals['totalSoldeClotureDebit'] ?? 0,
          totals['totalSoldeClotureCredit'] ?? 0,
        ];
        for (var col = 0; col < totalValues.length; col++) {
          setCell(row, col, totalValues[col], style: summaryStyle);
        }
      }

      sheet.setColumnWidth(0, 18);
      sheet.setColumnWidth(1, 40);
      sheet.setColumnWidth(2, 16);
      sheet.setColumnWidth(3, 16);
      sheet.setColumnWidth(4, 18);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 22);
      sheet.setColumnWidth(7, 22);

      final fileName =
          'balance_resultat_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Impossible de générer le fichier Excel');
      }
      return _saveBytesWithPicker(
        bytes: Uint8List.fromList(bytes),
        suggestedFileName: fileName,
        context: context,
        label: 'Excel',
      );
    } catch (e) {
      debugPrint('Erreur lors de la génération du fichier Excel: $e');
      rethrow;
    }
  }

  // ==================== EXPORT PLAN COMPTABLE ====================

  /// Exporte le plan comptable en PDF
  static Future<void> exportPlanComptablePDF({
    required List<Map<String, dynamic>> comptes,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
                _pdfEntiteHeader(entiteNom),
                // Titre
                pw.Center(
                  child: pw.Text(
                    'PLAN COMPTABLE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Date d\'export: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
                // Tableau
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.3),
                    1: pw.FlexColumnWidth(3.5),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // En-tête
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'N° Compte',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Intitulé',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Nature',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Type',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Données
                    ...comptes.map((compte) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(compte['numeroCompte'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(compte['intitule'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(compte['nature'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(compte['type'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
            ];
          },
        ),
      );

      final fileName =
          'plan_comptable_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte le plan comptable en Excel
  static Future<void> exportPlanComptableExcel({
    required List<Map<String, dynamic>> comptes,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Plan Comptable';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      final dataStyle = CellStyle(horizontalAlign: HorizontalAlign.Left);

      int row = 0;
      final headers = ['N° Compte', 'Intitulé', 'Nature', 'Type'];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      for (final compte in comptes) {
        final values = [
          compte['numeroCompte']?.toString() ?? '',
          compte['intitule']?.toString() ?? '',
          compte['nature']?.toString() ?? '',
          compte['type']?.toString() ?? '',
        ];

        for (int col = 0; col < values.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = dataStyle;
        }
        row++;
      }

      final fileName =
          'plan_comptable_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await _saveBytesWithPicker(
          bytes: Uint8List.fromList(bytes),
          suggestedFileName: fileName,
          context: context,
          label: 'Excel',
        );
      }
    } catch (e) {
      debugPrint('Erreur Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== EXPORT LISTE TIERS ====================

  /// Exporte la liste des tiers en PDF
  static Future<void> exportTiersPDF({
    required List<Map<String, dynamic>> tiers,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
                _pdfEntiteHeader(entiteNom),
                pw.Center(
                  child: pw.Text(
                    'LISTE DES TIERS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Date d\'export: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'N° Compte',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Intitulé',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Type',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'NIF',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...tiers.map((t) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(t['numeroCompte'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(t['intitule'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(t['type'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(t['nif'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
            ];
          },
        ),
      );

      final fileName =
          'liste_tiers_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte la liste des tiers en Excel
  static Future<void> exportTiersExcel({
    required List<Map<String, dynamic>> tiers,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Liste Tiers';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      final dataStyle = CellStyle(horizontalAlign: HorizontalAlign.Left);

      int row = 0;
      final headers = ['N° Compte', 'Intitulé', 'Type', 'NIF'];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      for (final t in tiers) {
        final values = [
          t['numeroCompte']?.toString() ?? '',
          t['intitule']?.toString() ?? '',
          t['type']?.toString() ?? '',
          t['nif']?.toString() ?? '',
        ];

        for (int col = 0; col < values.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = dataStyle;
        }
        row++;
      }

      final fileName =
          'liste_tiers_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await _saveBytesWithPicker(
          bytes: Uint8List.fromList(bytes),
          suggestedFileName: fileName,
          context: context,
          label: 'Excel',
        );
      }
    } catch (e) {
      debugPrint('Erreur Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== EXPORT LISTE BAILLEURS ====================

  /// Exporte la liste des bailleurs en PDF
  static Future<void> exportBailleursListPDF({
    required List<Map<String, dynamic>> bailleurs,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
                _pdfEntiteHeader(entiteNom),
                pw.Center(
                  child: pw.Text(
                    'LISTE DES BAILLEURS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Date d\'export: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Sigle',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Désignation',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...bailleurs.map((b) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(b['sigle'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(b['designation'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
            ];
          },
        ),
      );

      final fileName =
          'liste_bailleurs_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte la liste des bailleurs en Excel
  static Future<void> exportBailleursListExcel({
    required List<Map<String, dynamic>> bailleurs,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Liste Bailleurs';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      final dataStyle = CellStyle(horizontalAlign: HorizontalAlign.Left);

      int row = 0;
      final headers = ['Sigle', 'Désignation'];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      for (final b in bailleurs) {
        final values = [
          b['sigle']?.toString() ?? '',
          b['designation']?.toString() ?? '',
        ];

        for (int col = 0; col < values.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = dataStyle;
        }
        row++;
      }

      final fileName =
          'liste_bailleurs_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await _saveBytesWithPicker(
          bytes: Uint8List.fromList(bytes),
          suggestedFileName: fileName,
          context: context,
          label: 'Excel',
        );
      }
    } catch (e) {
      debugPrint('Erreur Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== EXPORT LISTE PROJETS ====================

  /// Exporte la liste des projets en PDF
  static Future<void> exportProjetsPDF({
    required List<Map<String, dynamic>> projets,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
                _pdfEntiteHeader(entiteNom),
                pw.Center(
                  child: pw.Text(
                    'LISTE DES PROJETS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Date d\'export: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Code',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Désignation',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Bailleur',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...projets.map((p) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(p['code'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(p['designation'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              _pdfSafe(p['bailleur'] ?? '-'),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
            ];
          },
        ),
      );

      final fileName =
          'liste_projets_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte la liste des projets en Excel
  static Future<void> exportProjetsExcel({
    required List<Map<String, dynamic>> projets,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Liste Projets';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      final dataStyle = CellStyle(horizontalAlign: HorizontalAlign.Left);

      int row = 0;
      final headers = ['Code', 'Désignation', 'Bailleur'];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      for (final p in projets) {
        final values = [
          p['code']?.toString() ?? '',
          p['designation']?.toString() ?? '',
          p['bailleur']?.toString() ?? '',
        ];

        for (int col = 0; col < values.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = dataStyle;
        }
        row++;
      }

      final fileName =
          'liste_projets_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await _saveBytesWithPicker(
          bytes: Uint8List.fromList(bytes),
          suggestedFileName: fileName,
          context: context,
          label: 'Excel',
        );
      }
    } catch (e) {
      debugPrint('Erreur Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte les résultats d'interrogation en PDF.
  static Future<void> exportInterrogationPDF({
    required List<Map<String, dynamic>> rows,
    required String numeroCompte,
    DateTime? dateDebut,
    DateTime? dateFin,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      final totalDebit = rows.fold<double>(
        0.0,
        (sum, row) => sum + ((row['debit'] as num?)?.toDouble() ?? 0.0),
      );
      final totalCredit = rows.fold<double>(
        0.0,
        (sum, row) => sum + ((row['credit'] as num?)?.toDouble() ?? 0.0),
      );
      final solde = totalDebit - totalCredit;

      final periodeText =
          (dateDebut != null && dateFin != null)
              ? '${dateDebut.toString().split(' ').first} au ${dateFin.toString().split(' ').first}'
              : 'Toutes periodes';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
              _pdfEntiteHeader(entiteNom),
              pw.Text(
                'Interrogation de compte',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Compte: $numeroCompte'),
              pw.Text('Periode: $periodeText'),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700, width: .5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children: [
                      _pdfCell('Date', bold: true),
                      _pdfCell('Numero de piece', bold: true),
                      _pdfCell('Numero de compte', bold: true),
                      _pdfCell('Montant debit', bold: true),
                      _pdfCell('Montant credit', bold: true),
                    ],
                  ),
                  ...rows.map(
                    (row) => pw.TableRow(
                      children: [
                        _pdfCell(row['date']?.toString() ?? '-'),
                        _pdfCell(row['numero_piece']?.toString() ?? '-'),
                        _pdfCell(row['numero_compte']?.toString() ?? '-'),
                        _pdfCell(_formatNumber(row['debit'])),
                        _pdfCell(_formatNumber(row['credit'])),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total debit: ${_formatNumber(totalDebit)}'),
                    pw.Text('Total credit: ${_formatNumber(totalCredit)}'),
                    pw.Text(
                      'Solde: ${_formatNumber(solde)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final fileName =
          'interrogation_compte_${numeroCompte}_${DateTime.now().toString().split(' ').first}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte les résultats d'interrogation en Excel.
  static Future<void> exportInterrogationExcel({
    required List<Map<String, dynamic>> rows,
    required String numeroCompte,
    DateTime? dateDebut,
    DateTime? dateFin,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Interrogation';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );
      final numberStyle = CellStyle(horizontalAlign: HorizontalAlign.Right);

      final periodeText =
          (dateDebut != null && dateFin != null)
              ? '${dateDebut.toString().split(' ').first} au ${dateFin.toString().split(' ').first}'
              : 'Toutes periodes';

      int row = 0;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Interrogation de compte');
      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Compte: $numeroCompte');
      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('Periode: $periodeText');
      row += 2;

      final headers = [
        'Date',
        'Numero de piece',
        'Numero de compte',
        'Montant debit',
        'Montant credit',
      ];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      double totalDebit = 0;
      double totalCredit = 0;

      for (final item in rows) {
        final debit = (item['debit'] as num?)?.toDouble() ?? 0;
        final credit = (item['credit'] as num?)?.toDouble() ?? 0;
        totalDebit += debit;
        totalCredit += credit;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(item['date']?.toString() ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(item['numero_piece']?.toString() ?? '-');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(item['numero_compte']?.toString() ?? '-');

        final debitCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        );
        debitCell.value = DoubleCellValue(debit);
        debitCell.cellStyle = numberStyle;

        final creditCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
        );
        creditCell.value = DoubleCellValue(credit);
        creditCell.cellStyle = numberStyle;

        row++;
      }

      row += 1;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue('Totaux');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = DoubleCellValue(totalDebit);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = DoubleCellValue(totalCredit);

      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue('Solde (Debit - Credit)');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = DoubleCellValue(totalDebit - totalCredit);

      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 22);
      sheet.setColumnWidth(2, 20);
      sheet.setColumnWidth(3, 18);
      sheet.setColumnWidth(4, 18);

      final fileName =
          'interrogation_compte_${numeroCompte}_${DateTime.now().toString().split(' ').first}.xlsx';
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Impossible de generer le fichier Excel');
      }
      await _saveBytesWithPicker(
        bytes: Uint8List.fromList(bytes),
        suggestedFileName: fileName,
        context: context,
        label: 'Excel',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== EXPORT JOURNAL (résultats) ====================

  /// Exporte les résultats de journal (mode BASE ou TIERS) en PDF, groupés
  /// par journal comme dans l'interface.
  static Future<void> exportJournalPDF({
    required Map<String, dynamic>? entite,
    required String periodeLabel,
    required String journalLabel,
    required String typeLabel,
    required List<Map<String, dynamic>> groups,
    required BuildContext context,
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(14),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build:
              (context) => [
                _pdfEntiteHeader(
                  entite?['denomination_sociale']?.toString(),
                ),
                pw.Center(
                  child: pw.Text(
                    'JOURNAL ($typeLabel)',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                _journalPdfHeader(
                  entite: entite,
                  periodeLabel: periodeLabel,
                  journalLabel: journalLabel,
                  typeLabel: typeLabel,
                ),
                pw.SizedBox(height: 12),
                ...groups.expand((group) {
                  final rows =
                      (group['rows'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();
                  return [
                    pw.Container(
                      width: double.infinity,
                      color: PdfColors.blue700,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Journal ${group['code']} - ${group['libelle']}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.black,
                        width: .5,
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.1),
                        1: pw.FlexColumnWidth(1.1),
                        2: pw.FlexColumnWidth(2.2),
                        3: pw.FlexColumnWidth(1.1),
                        4: pw.FlexColumnWidth(3.2),
                        5: pw.FlexColumnWidth(1.1),
                        6: pw.FlexColumnWidth(1.1),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            _pdfCell('Date', bold: true),
                            _pdfCell('N Compte', bold: true),
                            _pdfCell('Intitulé', bold: true),
                            _pdfCell('N Enreg.', bold: true),
                            _pdfCell('Libellé', bold: true),
                            _pdfCell('Débit', bold: true),
                            _pdfCell('Crédit', bold: true),
                          ],
                        ),
                        ...rows.map(
                          (row) => pw.TableRow(
                            children: [
                              _pdfCell(_formatDateCell(row['date'])),
                              _pdfCell(row['numeroCompte']?.toString() ?? ''),
                              _pdfCell(row['compteIntitule']?.toString() ?? ''),
                              _pdfCell(
                                row['numeroEnregistrement']?.toString() ?? '',
                              ),
                              _pdfCell(row['libelle']?.toString() ?? ''),
                              _pdfCell(_formatNumber(row['debit'])),
                              _pdfCell(_formatNumber(row['credit'])),
                            ],
                          ),
                        ),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(
                              'TOTAL (${rows.length} écritures)',
                              bold: true,
                            ),
                            _pdfCell(
                              _formatNumber(group['totalDebit']),
                              bold: true,
                            ),
                            _pdfCell(
                              _formatNumber(group['totalCredit']),
                              bold: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                  ];
                }),
              ],
        ),
      );

      final fileName =
          'journal_${DateTime.now().toString().split(' ').first}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exporte les résultats de journal en Excel, une feuille par journal.
  static Future<void> exportJournalExcel({
    required Map<String, dynamic>? entite,
    required String periodeLabel,
    required String journalLabel,
    required String typeLabel,
    required List<Map<String, dynamic>> groups,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );
      final totalStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Right,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      for (final group in groups) {
        final code = group['code']?.toString() ?? 'Journal';
        final sheetName = code.length > 31 ? code.substring(0, 31) : code;
        final sheet = excel[sheetName];
        var rowIndex = 0;

        _excelText(sheet, 0, rowIndex++, 'JOURNAL ($typeLabel)');
        _excelText(sheet, 0, rowIndex, 'Denomination sociale');
        _excelText(
          sheet,
          1,
          rowIndex,
          entite?['denomination_sociale']?.toString() ?? '',
        );
        _excelText(sheet, 2, rowIndex, 'NIF');
        _excelText(
          sheet,
          3,
          rowIndex,
          entite?['numero_fiscal']?.toString() ?? '',
        );
        _excelText(sheet, 4, rowIndex, 'Periode');
        _excelText(sheet, 5, rowIndex++, periodeLabel);
        _excelText(sheet, 0, rowIndex, 'Journal');
        _excelText(sheet, 1, rowIndex, journalLabel);
        _excelText(sheet, 2, rowIndex, 'Type');
        _excelText(sheet, 3, rowIndex++, typeLabel);
        rowIndex++;
        _excelText(
          sheet,
          0,
          rowIndex++,
          'Journal $code - ${group['libelle']}',
        );

        final headers = [
          'Date',
          'N Compte',
          'Intitulé',
          'N Enreg.',
          'Libellé',
          'Débit',
          'Crédit',
        ];
        for (var col = 0; col < headers.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          );
          cell.value = TextCellValue(headers[col]);
          cell.cellStyle = headerStyle;
        }
        rowIndex++;

        final rows =
            (group['rows'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        for (final item in rows) {
          _excelText(sheet, 0, rowIndex, _formatDateCell(item['date']));
          _excelText(
            sheet,
            1,
            rowIndex,
            item['numeroCompte']?.toString() ?? '',
          );
          _excelText(
            sheet,
            2,
            rowIndex,
            item['compteIntitule']?.toString() ?? '',
          );
          _excelText(
            sheet,
            3,
            rowIndex,
            item['numeroEnregistrement']?.toString() ?? '',
          );
          _excelText(sheet, 4, rowIndex, item['libelle']?.toString() ?? '');
          _excelNumber(
            sheet,
            5,
            rowIndex,
            (item['debit'] as num?)?.toDouble() ?? 0,
          );
          _excelNumber(
            sheet,
            6,
            rowIndex++,
            (item['credit'] as num?)?.toDouble() ?? 0,
          );
        }

        _excelText(sheet, 4, rowIndex, 'TOTAL (${rows.length} écritures)');
        _excelNumber(
          sheet,
          5,
          rowIndex,
          (group['totalDebit'] as num?)?.toDouble() ?? 0,
        );
        _excelNumber(
          sheet,
          6,
          rowIndex,
          (group['totalCredit'] as num?)?.toDouble() ?? 0,
        );
        for (var col = 4; col <= 6; col++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: col,
                  rowIndex: rowIndex,
                ),
              )
              .cellStyle = totalStyle;
        }

        sheet.setColumnWidth(0, 14);
        sheet.setColumnWidth(1, 14);
        sheet.setColumnWidth(2, 32);
        sheet.setColumnWidth(3, 14);
        sheet.setColumnWidth(4, 42);
        sheet.setColumnWidth(5, 16);
        sheet.setColumnWidth(6, 16);
      }

      final fileName =
          'journal_${DateTime.now().toString().split(' ').first}.xlsx';
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Impossible de generer le fichier Excel');
      }
      await _saveBytesWithPicker(
        bytes: Uint8List.fromList(bytes),
        suggestedFileName: fileName,
        context: context,
        label: 'Excel',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static pw.Widget _journalPdfHeader({
    required Map<String, dynamic>? entite,
    required String periodeLabel,
    required String journalLabel,
    required String typeLabel,
  }) {
    final adresse = [
      entite?['ville'],
      entite?['quartier'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(', ');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
      children: [
        pw.TableRow(
          children: [
            _pdfCell('Denomination sociale', bold: true),
            _pdfCell(entite?['denomination_sociale']?.toString() ?? ''),
            _pdfCell('NIF', bold: true),
            _pdfCell(entite?['numero_fiscal']?.toString() ?? ''),
            _pdfCell('Adresse', bold: true),
            _pdfCell(adresse),
            _pdfCell('Periode', bold: true),
            _pdfCell(periodeLabel),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell('JOURNAL', bold: true),
            _pdfCell(journalLabel),
            _pdfCell(''),
            _pdfCell('TYPE', bold: true),
            _pdfCell(typeLabel),
            _pdfCell(''),
            _pdfCell(''),
            _pdfCell(''),
          ],
        ),
      ],
    );
  }

  static Future<void> exportGrandLivrePDF({
    required Map<String, dynamic>? entite,
    required DateTime dateDebut,
    required DateTime dateFin,
    required String typeLabel,
    required String projetLabel,
    required String bailleursLabel,
    required List<Map<String, dynamic>> groups,
    required BuildContext context,
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(14),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build:
              (context) => [
                pw.Center(
                  child: pw.Text(
                    'GRAND LIVRE $typeLabel',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                _grandLivrePdfHeader(
                  entite: entite,
                  dateDebut: dateDebut,
                  dateFin: dateFin,
                  typeLabel: typeLabel,
                  projetLabel: projetLabel,
                  bailleursLabel: bailleursLabel,
                ),
                pw.SizedBox(height: 12),
                ...groups.expand((group) {
                  final rows =
                      (group['rows'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();
                  return [
                    pw.Container(
                      width: double.infinity,
                      color: PdfColors.blue700,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Compte ${group['numero']} - ${group['intitule']}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.black,
                        width: .5,
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.1),
                        1: pw.FlexColumnWidth(.8),
                        2: pw.FlexColumnWidth(1.1),
                        3: pw.FlexColumnWidth(3.4),
                        4: pw.FlexColumnWidth(1.1),
                        5: pw.FlexColumnWidth(1.1),
                        6: pw.FlexColumnWidth(1.2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            _pdfCell('Date', bold: true),
                            _pdfCell('Journal', bold: true),
                            _pdfCell('N enregis.', bold: true),
                            _pdfCell('Libelle', bold: true),
                            _pdfCell('Debit', bold: true),
                            _pdfCell('Credit', bold: true),
                            _pdfCell('Solde', bold: true),
                          ],
                        ),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100,
                          ),
                          children: [
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell('Solde d\'ouverture', bold: true),
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(_formatNumber(group['opening_balance'])),
                          ],
                        ),
                        ...rows.map(
                          (row) => pw.TableRow(
                            children: [
                              _pdfCell(_formatDateCell(row['date'])),
                              _pdfCell(row['journal']?.toString() ?? ''),
                              _pdfCell(
                                row['numero_enregistrement']?.toString() ?? '',
                              ),
                              _pdfCell(row['libelle']?.toString() ?? ''),
                              _pdfCell(_formatNumber(row['debit'])),
                              _pdfCell(_formatNumber(row['credit'])),
                              _pdfCell(_formatNumber(row['solde'])),
                            ],
                          ),
                        ),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(''),
                            _pdfCell(
                              'TOTAL COMPTE ${group['numero']}',
                              bold: true,
                            ),
                            _pdfCell(
                              _formatNumber(group['total_debit']),
                              bold: true,
                            ),
                            _pdfCell(
                              _formatNumber(group['total_credit']),
                              bold: true,
                            ),
                            _pdfCell(
                              _formatNumber(group['final_balance']),
                              bold: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                  ];
                }),
              ],
        ),
      );

      final fileName =
          'grand_livre_${DateTime.now().toString().split(' ').first}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> exportGrandLivreExcel({
    required Map<String, dynamic>? entite,
    required DateTime dateDebut,
    required DateTime dateFin,
    required String typeLabel,
    required String projetLabel,
    required String bailleursLabel,
    required List<Map<String, dynamic>> groups,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );
      final totalStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Right,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );

      for (final group in groups) {
        final numero = group['numero']?.toString() ?? 'Compte';
        final sheetName = numero.length > 31 ? numero.substring(0, 31) : numero;
        final sheet = excel[sheetName];
        var rowIndex = 0;

        _excelText(sheet, 0, rowIndex++, 'GRAND LIVRE $typeLabel');
        _excelText(sheet, 0, rowIndex, 'Denomination sociale');
        _excelText(
          sheet,
          1,
          rowIndex,
          entite?['denomination_sociale']?.toString() ?? '',
        );
        _excelText(sheet, 2, rowIndex, 'NIF');
        _excelText(sheet, 3, rowIndex, entite?['numero_fiscal']?.toString() ?? '');
        _excelText(sheet, 4, rowIndex, 'Periode');
        _excelText(
          sheet,
          5,
          rowIndex++,
          '${_formatDateCell(dateDebut)} - ${_formatDateCell(dateFin)}',
        );
        _excelText(sheet, 0, rowIndex, 'Projet');
        _excelText(sheet, 1, rowIndex, projetLabel);
        _excelText(sheet, 2, rowIndex, 'Bailleurs');
        _excelText(sheet, 3, rowIndex++, bailleursLabel);
        rowIndex++;
        _excelText(sheet, 0, rowIndex++, 'Compte $numero - ${group['intitule']}');

        final headers = [
          'Date',
          'Journal',
          'N enregis.',
          'Libelle',
          'Debit',
          'Credit',
          'Solde',
        ];
        for (var col = 0; col < headers.length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          );
          cell.value = TextCellValue(headers[col]);
          cell.cellStyle = headerStyle;
        }
        rowIndex++;

        _excelText(sheet, 3, rowIndex, 'Solde d\'ouverture');
        _excelNumber(
          sheet,
          6,
          rowIndex++,
          (group['opening_balance'] as num?)?.toDouble() ?? 0,
        );

        final rows =
            (group['rows'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        for (final item in rows) {
          _excelText(sheet, 0, rowIndex, _formatDateCell(item['date']));
          _excelText(sheet, 1, rowIndex, item['journal']?.toString() ?? '');
          _excelText(
            sheet,
            2,
            rowIndex,
            item['numero_enregistrement']?.toString() ?? '',
          );
          _excelText(sheet, 3, rowIndex, item['libelle']?.toString() ?? '');
          _excelNumber(
            sheet,
            4,
            rowIndex,
            (item['debit'] as num?)?.toDouble() ?? 0,
          );
          _excelNumber(
            sheet,
            5,
            rowIndex,
            (item['credit'] as num?)?.toDouble() ?? 0,
          );
          _excelNumber(
            sheet,
            6,
            rowIndex++,
            (item['solde'] as num?)?.toDouble() ?? 0,
          );
        }

        _excelText(sheet, 3, rowIndex, 'TOTAL COMPTE $numero');
        _excelNumber(sheet, 4, rowIndex, (group['total_debit'] as num?)?.toDouble() ?? 0);
        _excelNumber(sheet, 5, rowIndex, (group['total_credit'] as num?)?.toDouble() ?? 0);
        _excelNumber(sheet, 6, rowIndex, (group['final_balance'] as num?)?.toDouble() ?? 0);
        for (var col = 3; col <= 6; col++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: col,
                  rowIndex: rowIndex,
                ),
              )
              .cellStyle = totalStyle;
        }

        sheet.setColumnWidth(0, 14);
        sheet.setColumnWidth(1, 12);
        sheet.setColumnWidth(2, 14);
        sheet.setColumnWidth(3, 42);
        sheet.setColumnWidth(4, 16);
        sheet.setColumnWidth(5, 16);
        sheet.setColumnWidth(6, 16);
      }

      final fileName =
          'grand_livre_${DateTime.now().toString().split(' ').first}.xlsx';
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Impossible de generer le fichier Excel');
      }
      await _saveBytesWithPicker(
        bytes: Uint8List.fromList(bytes),
        suggestedFileName: fileName,
        context: context,
        label: 'Excel',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static pw.Widget _grandLivrePdfHeader({
    required Map<String, dynamic>? entite,
    required DateTime dateDebut,
    required DateTime dateFin,
    required String typeLabel,
    required String projetLabel,
    required String bailleursLabel,
  }) {
    final adresse = [
      entite?['ville'],
      entite?['quartier'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(', ');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
      children: [
        pw.TableRow(
          children: [
            _pdfCell('Denomination sociale', bold: true),
            _pdfCell(entite?['denomination_sociale']?.toString() ?? ''),
            _pdfCell('NIF', bold: true),
            _pdfCell(entite?['numero_fiscal']?.toString() ?? ''),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell('Adresse', bold: true),
            _pdfCell(adresse),
            _pdfCell('Periode', bold: true),
            _pdfCell('${_formatDateCell(dateDebut)} - ${_formatDateCell(dateFin)}'),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell('TYPE', bold: true),
            _pdfCell(typeLabel),
            _pdfCell('PROJET', bold: true),
            _pdfCell(projetLabel),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell('BAILLEUR', bold: true),
            _pdfCell(bailleursLabel),
            _pdfCell(''),
            _pdfCell(''),
          ],
        ),
      ],
    );
  }

  static void _excelText(Sheet sheet, int col, int row, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(value);
  }

  static void _excelNumber(Sheet sheet, int col, int row, double value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = DoubleCellValue(value);
  }

  static String _formatDateCell(dynamic value) {
    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value != null) {
      date = DateTime.tryParse(value.toString());
    }
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        _pdfSafe(text),
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Remplace les caractères typographiques (guillemets courbes, points de
  /// suspension, tirets longs, etc.) absents de la police PDF par défaut par
  /// leur équivalent ASCII, pour éviter les avertissements "Unable to find
  /// a font to draw" et les glyphes manquants à l'impression.
  static String _pdfSafe(dynamic value) {
    if (value == null) return '';
    var text = value.toString();
    const replacements = {
      '‘': "'", // '
      '’': "'", // '
      '‚': "'",
      '‛': "'",
      '“': '"', // "
      '”': '"', // "
      '„': '"',
      '–': '-', // –
      '—': '-', // —
      '…': '...', // …
      ' ': ' ',
    };
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text;
  }

  /// En-tête simple affichant la dénomination sociale en haut d'un PDF.
  static pw.Widget _pdfEntiteHeader(String? entiteNom) {
    if (entiteNom == null || entiteNom.isEmpty) {
      return pw.SizedBox();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Dénomination sociale : $entiteNom',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  /// Pied de page commun affiché en bas de chaque PDF exporté.
  static pw.Widget _pdfFooter() {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Center(
          child: pw.Text(
            'Imprimé depuis l\'application SYCEBNL ACCOUNTING',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  /// Demande à l'utilisateur où enregistrer un fichier puis écrit les octets fournis.
  /// Retourne le fichier créé, ou `null` si l'utilisateur a annulé.
  static Future<File?> _saveBytesWithPicker({
    required Uint8List bytes,
    required String suggestedFileName,
    required BuildContext context,
    required String label,
  }) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le fichier $label',
        fileName: suggestedFileName,
      );

      if (path == null) {
        return null;
      }

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label enregistré : ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return file;
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement du fichier: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ==================== EXPORT CODES JOURNAUX ====================

  /// Exporte la liste des codes journaux en PDF
  static Future<void> exportJournauxPDF({
    required List<Map<String, dynamic>> journaux,
    required BuildContext context,
    String? entiteNom,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          maxPages: 2000,
          footer: (context) => _pdfFooter(),
          build: (context) {
            return [
                _pdfEntiteHeader(entiteNom),
                pw.Center(
                  child: pw.Text(
                    'CODES JOURNAUX',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Date d\'export: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(2.5),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.5),
                    4: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        _pdfCell('Code', bold: true),
                        _pdfCell('Intitulé', bold: true),
                        _pdfCell('Type', bold: true),
                        _pdfCell('Compte Trésorerie', bold: true),
                        _pdfCell('Saisie Analytique', bold: true),
                      ],
                    ),
                    ...journaux.map((j) => pw.TableRow(
                      children: [
                        _pdfCell(j['code']?.toString() ?? '-'),
                        _pdfCell(j['intitule']?.toString() ?? '-'),
                        _pdfCell(j['type']?.toString() ?? '-'),
                        _pdfCell(j['compteTresorerie']?.toString() ?? '-'),
                        _pdfCell(j['saisieAnalytique'] == true ? 'Oui' : 'Non'),
                      ],
                    )),
                  ],
                ),
            ];
          },
        ),
      );

      final fileName = 'codes_journaux_${DateTime.now().toString().split(' ')[0]}.pdf';
      await _saveBytesWithPicker(
        bytes: await pdf.save(),
        suggestedFileName: fileName,
        context: context,
        label: 'PDF',
      );
    } catch (e) {
      debugPrint('Erreur PDF journaux: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Exporte la liste des codes journaux en Excel
  static Future<void> exportJournauxExcel({
    required List<Map<String, dynamic>> journaux,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Codes Journaux';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
      );
      final dataStyle = CellStyle(horizontalAlign: HorizontalAlign.Left);

      int row = 0;
      final headers = ['Code', 'Intitulé', 'Type', 'Compte Trésorerie', 'Saisie Analytique'];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }
      row++;

      for (final j in journaux) {
        final values = [
          j['code']?.toString() ?? '',
          j['intitule']?.toString() ?? '',
          j['type']?.toString() ?? '',
          j['compteTresorerie']?.toString() ?? '',
          (j['saisieAnalytique'] == true) ? 'Oui' : 'Non',
        ];
        for (int col = 0; col < values.length; col++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = dataStyle;
        }
        row++;
      }

      sheet.setColumnWidth(0, 12);
      sheet.setColumnWidth(1, 35);
      sheet.setColumnWidth(2, 18);
      sheet.setColumnWidth(3, 22);
      sheet.setColumnWidth(4, 18);

      final fileName = 'codes_journaux_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await _saveBytesWithPicker(
          bytes: Uint8List.fromList(bytes),
          suggestedFileName: fileName,
          context: context,
          label: 'Excel',
        );
      }
    } catch (e) {
      debugPrint('Erreur Excel journaux: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _formatNumber(dynamic value) {
    if (value == null || value == 0) return '-';
    final numValue = (value as num).toInt();
    return numValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
