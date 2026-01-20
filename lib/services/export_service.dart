import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

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

      // Sauvegarder le PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'balance_resultat_${DateTime.now().toString().split(' ')[0]}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdf);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF généré: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
  }) async {
    try {
      final pdfData = await _generatePDF(
        title: title,
        entityName: entityName,
        periodInfo: periodInfo,
        comptes: comptes,
        totals: totals,
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
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Entité: $entityName',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(periodInfo, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              // Tableau avec le même layout que l'interface
              _buildBalanceTable(comptes),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Construit le tableau de balance avec le layout exact
  static pw.Widget _buildBalanceTable(List<Map<String, dynamic>> comptes) {
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
                        compte['numero'] ?? '-',
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
                        compte['intitule'] ?? '-',
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
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'balance_resultat_${DateTime.now().toString().split(' ')[0]}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF téléchargé: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du PDF: $e');
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

  /// Exporte la balance des résultats en Excel (format TSV)
  static Future<File> generateExcel({
    required String title,
    required String entityName,
    required String periodInfo,
    required List<Map<String, dynamic>> comptes,
    required Map<String, dynamic>? totals,
  }) async {
    try {
      final buffer = StringBuffer();

      // En-têtes informatifs
      buffer.writeln(title);
      buffer.writeln('');
      buffer.writeln('Entité:\t$entityName');
      buffer.writeln('Période:\t$periodInfo');
      buffer.writeln('');
      buffer.writeln(
        'Date d\'export:\t${DateTime.now().toString().split('.')[0]}',
      );
      buffer.writeln('');

      // En-têtes du tableau
      buffer.writeln(
        'N° Compte\tIntitulé\tSolde Débit\tSolde Crédit\tMouvement Débit\tMouvement Crédit\tSolde Clôture Débit\tSolde Clôture Crédit',
      );

      // Ajouter les données
      for (final compte in comptes) {
        buffer.writeln(
          '${compte['numero'] ?? '-'}\t${compte['intitule'] ?? '-'}\t${compte['soldeDebit'] ?? 0}\t${compte['soldeCredit'] ?? 0}\t${compte['mouvementDebit'] ?? 0}\t${compte['mouvementCredit'] ?? 0}\t${compte['soldeClotureDebit'] ?? 0}\t${compte['soldeClotureCredit'] ?? 0}',
        );
      }

      // Ajouter les totaux si disponibles
      if (totals != null) {
        buffer.writeln('');
        buffer.writeln(
          'TOTAL\t\t${totals['totalSoldeDebit'] ?? 0}\t${totals['totalSoldeCredit'] ?? 0}\t${totals['totalMouvementDebit'] ?? 0}\t${totals['totalMouvementCredit'] ?? 0}\t${totals['totalSoldeClotureDebit'] ?? 0}\t${totals['totalSoldeClotureCredit'] ?? 0}',
        );
      }

      // Sauvegarder le fichier
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'balance_resultat_${DateTime.now().toString().split(' ')[0]}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      debugPrint('Erreur lors de la génération du fichier Excel: $e');
      rethrow;
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
