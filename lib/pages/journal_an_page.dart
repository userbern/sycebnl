import 'package:flutter/material.dart';
import '../services/exercice_service.dart';

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

  @override
  void initState() {
    super.initState();
    _future = ExerciceService.getAnPreview(widget.exerciceId);
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
            value: preview.totalDebit.toStringAsFixed(2),
          ),
          const SizedBox(width: 24),
          _StatTile(
            label: 'Total crédit',
            value: preview.totalCredit.toStringAsFixed(2),
          ),
          const SizedBox(width: 24),
          _StatTile(
            label: 'Compte d\'équilibrage',
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
                          : ligne.montantDebit.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      ligne.montantCredit == 0
                          ? '-'
                          : ligne.montantCredit.toStringAsFixed(2),
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
