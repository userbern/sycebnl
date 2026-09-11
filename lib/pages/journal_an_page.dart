import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/exercice_service.dart';
import '../services/export_service.dart';
import '../services/local_repository.dart';
import '../widgets/download_button.dart';
import '../utils/format_utils.dart';

/// Visualiseur du journal des A-Nouveaux généré à la clôture d'un exercice :
/// comptes reportés, total global, et compte d'équilibrage utilisé.
class JournalAnPage extends StatefulWidget {
  final int exerciceId;

  const JournalAnPage({super.key, required this.exerciceId});

  @override
  State<JournalAnPage> createState() => _JournalAnPageState();
}

class _JournalAnPageState extends State<JournalAnPage> {
  late Future<AnPreview?> _future;
  Map<String, dynamic>? _entite;
  String? _exerciceCode;
  Map<String, String> _journalLibelles = {};

  @override
  void initState() {
    super.initState();
    _future = ExerciceService.getAnPreview(widget.exerciceId);
    _loadEntite();
    _loadExercice();
    _loadJournaux();
  }

  Future<void> _loadJournaux() async {
    try {
      if (!DatabaseService.isConnected) return;
      final rows = await const LocalRepository().query('journal');
      if (!mounted) return;
      setState(() {
        _journalLibelles = {
          for (final r in rows)
            r['code'].toString(): r['libelle']?.toString() ?? '',
        };
      });
    } catch (_) {}
  }

  /// Nom lisible du journal utilisé pour le report (code + libellé), ou
  /// juste le code si son libellé n'a pas pu être retrouvé. Utilise un
  /// tiret simple pour rester lisible dans les polices PDF/Excel.
  String? _journalLabelFor(String? code) {
    if (code == null || code.isEmpty) return null;
    final libelle = _journalLibelles[code];
    return (libelle != null && libelle.isNotEmpty) ? '$code - $libelle' : code;
  }

  Future<void> _loadEntite() async {
    try {
      if (!DatabaseService.isConnected) return;
      final rows = await const LocalRepository().query('entite', limit: 1);
      if (!mounted) return;
      setState(() => _entite = rows.isNotEmpty ? rows.first : null);
    } catch (_) {}
  }

  Future<void> _loadExercice() async {
    try {
      if (!DatabaseService.isConnected) return;
      final rows = await const LocalRepository().query(
        'exercice',
        where: 'id = ?',
        whereArgs: [widget.exerciceId],
        limit: 1,
      );
      if (!mounted) return;
      setState(
        () => _exerciceCode =
            rows.isNotEmpty ? rows.first['code']?.toString() : null,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Journal des A-Nouveaux'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          FutureBuilder<AnPreview?>(
            future: _future,
            builder: (context, snapshot) {
              final preview = snapshot.data;
              final hasData = preview != null && preview.lignes.isNotEmpty;
              return Row(
                children: [
                  DownloadTooltip.pdf(
                    verticalOffset: 28,
                    child: IconButton(
                      icon: const DownloadIcon(
                        Icons.picture_as_pdf_outlined,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: kDownloadPdfColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: hasData
                          ? () => ExportService.exportAnPreviewPDF(
                                preview: preview,
                                entite: _entite,
                                context: context,
                                exerciceLabel: _exerciceCode,
                                journalLabel:
                                    _journalLabelFor(preview.codeJournal),
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DownloadTooltip.excel(
                    verticalOffset: 28,
                    child: IconButton(
                      icon: const DownloadIcon(
                        Icons.table_chart_outlined,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: kDownloadExcelColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: hasData
                          ? () => ExportService.exportAnPreviewExcel(
                                preview: preview,
                                context: context,
                                entiteNom: _entite?['denomination_sociale']
                                    ?.toString(),
                                exerciceLabel: _exerciceCode,
                                journalLabel:
                                    _journalLabelFor(preview.codeJournal),
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<AnPreview?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final preview = snapshot.data;
          if (preview == null || preview.lignes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun journal AN pour cet exercice',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryBar(preview: preview),
                const SizedBox(height: 16),
                _AnTable(preview: preview),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final AnPreview preview;

  const _SummaryBar({required this.preview});

  @override
  Widget build(BuildContext context) {
    final equilibre = preview.isEquilibre;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _StatTile(
            label: 'Total débit',
            value: formatMontant(preview.totalDebit),
          ),
          const SizedBox(width: 24),
          _StatTile(
            label: 'Total crédit',
            value: formatMontant(preview.totalCredit),
          ),
          const SizedBox(width: 24),
          _StatTile(
            label: 'Compte d\'équilibre',
            value: preview.compteEquilibrage ?? '-',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: equilibre ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: equilibre ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  equilibre ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16,
                  color: equilibre ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  equilibre ? 'Équilibré' : 'Déséquilibré',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        equilibre ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AnTable extends StatelessWidget {
  final AnPreview preview;

  const _AnTable({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                    flex: 2,
                    child: Text('Compte',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 4,
                    child: Text('Intitulé',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 2,
                    child: Text('Débit',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 2,
                    child: Text('Crédit',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          ...preview.lignes.map((ligne) {
            final estEquilibrage = ligne.numeroCompte.startsWith('121') ||
                ligne.numeroCompte.startsWith('129');
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                color: estEquilibrage ? Colors.blue.shade50 : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(ligne.numeroCompte,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(ligne.intitule,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      ligne.montantDebit == 0
                          ? '-'
                          : formatMontant(ligne.montantDebit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      ligne.montantCredit == 0
                          ? '-'
                          : formatMontant(ligne.montantCredit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
