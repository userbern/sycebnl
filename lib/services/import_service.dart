import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/auth_service_local.dart';
import '../models/compte.dart';

class ImportResult {
  final int inserted;
  final int skipped;
  final List<String> errors;

  const ImportResult({
    required this.inserted,
    required this.skipped,
    required this.errors,
  });
}

class ImportService {
  // ==================== IMPORT PLAN COMPTABLE ====================

  static Future<void> importPlanComptable({
    required BuildContext context,
    required VoidCallback onSuccess,
  }) async {
    final result = await _pickExcelFile(context);
    if (result == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Import en cours…'),
            ],
          ),
        ),
      );
    }

    try {
      final importResult = await _processImportPlanComptable(result);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showResultDialog(context, importResult);
        if (importResult.inserted > 0) onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, e.toString());
      }
    }
  }

  static Future<ImportResult> _processImportPlanComptable(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return const ImportResult(inserted: 0, skipped: 0, errors: []);

    // Détection des colonnes depuis la première ligne
    final headers = rows.first
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    final colNumero   = _findCol(headers, ['n° compte', 'numero compte', 'numero_compte', 'n°compte', 'numero']);
    final colIntitule = _findCol(headers, ['intitulé', 'intitule', 'libellé', 'libelle']);
    final colNature   = _findCol(headers, ['nature']);
    final colType     = _findCol(headers, ['type']);

    if (colNumero == -1 || colIntitule == -1) {
      throw Exception('Colonnes requises introuvables : "N° Compte" et "Intitulé"');
    }

    // Charger les numéros existants pour détecter les doublons
    final existing = await AuthService.getComptes();
    final existingNums = existing.map((c) => c.numeroCompte.trim()).toSet();

    int inserted = 0;
    int skipped  = 0;
    final errors = <String>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final lineNum = i + 1;

      final numero   = _cell(row, colNumero).trim();
      final intitule = _cell(row, colIntitule).trim();

      if (numero.isEmpty && intitule.isEmpty) continue; // ligne vide

      if (numero.isEmpty) {
        errors.add('Ligne $lineNum : N° Compte manquant');
        continue;
      }
      if (intitule.isEmpty) {
        errors.add('Ligne $lineNum : Intitulé manquant');
        continue;
      }

      if (existingNums.contains(numero)) {
        skipped++;
        continue;
      }

      // Nature : depuis la cellule ou auto-calculée
      String nature = 'bilan_ressources_durables';
      if (colNature != -1) {
        final rawNature = _cell(row, colNature).trim();
        final parsed   = _parseNatureCompte(rawNature, numero);
        if (parsed != null) nature = parsed;
      } else {
        final calc = calculateNatureFromNumeroCompte(numero);
        if (calc != null) nature = calc.toDbString();
      }

      // Type : depuis la cellule ou défaut 'detail'
      String type = 'detail';
      if (colType != -1) {
        final rawType = _cell(row, colType).trim().toLowerCase();
        if (rawType == 'total' || rawType == 'total') type = 'total';
      }

      try {
        await AuthService.createCompte(
          numeroCompte: numero,
          intitule:     intitule,
          type:         type,
          nature:       nature,
        );
        existingNums.add(numero);
        inserted++;
      } catch (e) {
        errors.add('Ligne $lineNum ($numero) : ${e.toString()}');
      }
    }

    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ==================== IMPORT CODES JOURNAUX ====================

  static Future<void> importJournaux({
    required BuildContext context,
    required VoidCallback onSuccess,
  }) async {
    final result = await _pickExcelFile(context);
    if (result == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Import en cours…'),
            ],
          ),
        ),
      );
    }

    try {
      final importResult = await _processImportJournaux(result);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showResultDialog(context, importResult);
        if (importResult.inserted > 0) onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, e.toString());
      }
    }
  }

  static Future<ImportResult> _processImportJournaux(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets.values.first;
    final rows  = sheet.rows;
    if (rows.isEmpty) return const ImportResult(inserted: 0, skipped: 0, errors: []);

    final headers = rows.first
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    final colCode     = _findCol(headers, ['code']);
    final colIntitule = _findCol(headers, ['intitulé', 'intitule', 'libellé', 'libelle']);
    final colType     = _findCol(headers, ['type']);
    final colCompte   = _findCol(headers, ['compte trésorerie', 'compte tresorerie', 'compte_tresorerie']);
    final colAnalyt   = _findCol(headers, ['saisie analytique', 'saisie_analytique', 'analytique']);

    if (colCode == -1 || colIntitule == -1) {
      throw Exception('Colonnes requises introuvables : "Code" et "Intitulé"');
    }

    final existing    = await AuthService.getJournaux();
    final existingCodes = existing.map((j) => j.code.trim().toUpperCase()).toSet();

    int inserted = 0;
    int skipped  = 0;
    final errors = <String>[];

    for (int i = 1; i < rows.length; i++) {
      final row    = rows[i];
      final lineNum = i + 1;

      final code     = _cell(row, colCode).trim().toUpperCase();
      final intitule = _cell(row, colIntitule).trim();

      if (code.isEmpty && intitule.isEmpty) continue;

      if (code.isEmpty) {
        errors.add('Ligne $lineNum : Code manquant');
        continue;
      }
      if (intitule.isEmpty) {
        errors.add('Ligne $lineNum : Intitulé manquant');
        continue;
      }

      if (existingCodes.contains(code)) {
        skipped++;
        continue;
      }

      // Type
      String type = 'financier';
      if (colType != -1) {
        final rawType = _cell(row, colType).trim().toLowerCase();
        if (rawType.contains('non') || rawType == 'non_financier') {
          type = 'non_financier';
        }
      }

      // Validation type
      if (type != 'financier' && type != 'non_financier') {
        errors.add('Ligne $lineNum ($code) : Type invalide — doit être "Financier" ou "Non Financier"');
        continue;
      }

      final compteTresorerie = colCompte != -1
          ? _cell(row, colCompte).trim().isEmpty ? null : _cell(row, colCompte).trim()
          : null;

      bool saisieAnalytique = false;
      if (colAnalyt != -1) {
        final raw = _cell(row, colAnalyt).trim().toLowerCase();
        saisieAnalytique = raw == 'oui' || raw == 'true' || raw == '1';
      }

      try {
        await AuthService.createJournal(
          code:                    code,
          libelle:                 intitule,
          type:                    type,
          numeroCompteFresorerie:  compteTresorerie,
          saisieAnalytique:        saisieAnalytique,
        );
        existingCodes.add(code);
        inserted++;
      } catch (e) {
        errors.add('Ligne $lineNum ($code) : ${e.toString()}');
      }
    }

    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ==================== UTILITAIRES ====================

  static Future<List<int>?> _pickExcelFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    return File(path).readAsBytesSync();
  }

  static int _findCol(List<String> headers, List<String> candidates) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      for (final c in candidates) {
        if (h == c || h.contains(c) || c.contains(h)) return i;
      }
    }
    return -1;
  }

  static String _cell(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    return row[col]?.value?.toString() ?? '';
  }

  /// Convertit un label ou un DB string de nature en DB string.
  /// Si rien ne correspond, calcule depuis le numéro de compte.
  static String? _parseNatureCompte(String raw, String numeroCompte) {
    const labelToDb = {
      'bilan (ressources durables)':             'bilan_ressources_durables',
      'bilan (actif immobilisé)':                'bilan_actif_immobilise',
      'bilan (stocks)':                          'bilan_stocks',
      'bilan (fournisseurs)':                    'bilan_fournisseurs',
      'bilan (adhérents - clients usagers)':     'bilan_adherents_clients_usagers',
      'bilan (personnel)':                       'bilan_personnel',
      'bilan (organismes sociaux)':              'bilan_organismes_sociaux',
      'bilan (etat et collectivités publiques)': 'bilan_etat_collectivites_publiques',
      'bilan (autres tiers)':                    'bilan_autres_tiers',
      'bilan (banque)':                          'bilan_banque',
      'bilan (caisse)':                          'bilan_caisse',
      'bilan (autres trésoreries)':              'bilan_autres_tresoreries',
      'engagements hors bilan':                  'engagements_hors_bilan',
      'charges a.o.':                            'charges_ao',
      'charges h.a.o.':                          'charges_hao',
      'produits a.o.':                           'produits_ao',
      'produits h.a.o.':                         'produits_hao',
    };

    const validDb = {
      'bilan_ressources_durables', 'bilan_actif_immobilise', 'bilan_stocks',
      'bilan_fournisseurs', 'bilan_adherents_clients_usagers', 'bilan_personnel',
      'bilan_organismes_sociaux', 'bilan_etat_collectivites_publiques',
      'bilan_autres_tiers', 'bilan_banque', 'bilan_caisse', 'bilan_autres_tresoreries',
      'engagements_hors_bilan', 'charges_ao', 'charges_hao', 'produits_ao', 'produits_hao',
    };

    final lower = raw.toLowerCase();

    if (validDb.contains(lower)) return lower;
    if (labelToDb.containsKey(lower)) return labelToDb[lower];

    // Fallback : calcul automatique
    final calc = calculateNatureFromNumeroCompte(numeroCompte);
    return calc?.toDbString();
  }

  static void _showResultDialog(BuildContext context, ImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résultat de l\'import'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _resultLine(Icons.check_circle, Colors.green,
                    '${result.inserted} ligne(s) importée(s)'),
                if (result.skipped > 0)
                  _resultLine(Icons.skip_next, Colors.orange,
                      '${result.skipped} ignorée(s) (doublon)'),
                if (result.errors.isNotEmpty) ...[
                  _resultLine(Icons.error, Colors.red,
                      '${result.errors.length} erreur(s) :'),
                  const SizedBox(height: 8),
                  ...result.errors.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $e',
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Widget _resultLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $message'), backgroundColor: Colors.red),
    );
  }
}
