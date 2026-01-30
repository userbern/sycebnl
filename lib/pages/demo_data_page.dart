import 'package:flutter/material.dart';
import '../utils/test_data.dart';

/// Page de démonstration avec données de test pré-chargées
/// Permet de tester rapidement sans saisie manuelle

class DemoDataPage extends StatefulWidget {
  const DemoDataPage({super.key});

  @override
  State<DemoDataPage> createState() => _DemoDataPageState();
}

class _DemoDataPageState extends State<DemoDataPage> {
  int _selectedProjetIndex = 0;
  int _selectedBailleurIndex = 0;
  List<int> _selectedBailleurs = [0];
  DateTime _dateDebut = DateTime(2024, 1, 1);
  DateTime _dateFin = DateTime(2024, 12, 31);
  String _typeEtat = 'general';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Données de Démonstration'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Projets
            _buildSection(
              title: 'Sélectionner un Projet',
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedProjetIndex,
                onChanged: (value) {
                  setState(() => _selectedProjetIndex = value!);
                },
                items:
                    TestData.projets.asMap().entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value['designation'] ?? 'Projet',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            _buildProjectCard(TestData.projets[_selectedProjetIndex]),
            const SizedBox(height: 24),

            // Section Bailleurs
            _buildSection(
              title: 'Sélectionner des Bailleurs',
              child: Column(
                children: List.generate(
                  TestData.bailleurs.length,
                  (index) => CheckboxListTile(
                    title: Text(TestData.bailleurs[index]['designation'] ?? ''),
                    value: _selectedBailleurs.contains(index),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedBailleurs.add(index);
                        } else {
                          _selectedBailleurs.remove(index);
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedBailleurs.isNotEmpty)
              ..._selectedBailleurs.map((index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildBailleurCard(TestData.bailleurs[index]),
                );
              }).toList(),
            const SizedBox(height: 24),

            // Section Dates
            _buildSection(
              title: 'Période',
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Date de début'),
                    subtitle: Text(
                      '${_dateDebut.year}-${_dateDebut.month.toString().padLeft(2, '0')}-${_dateDebut.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => _selectDate(context, true),
                  ),
                  ListTile(
                    title: const Text('Date de fin'),
                    subtitle: Text(
                      '${_dateFin.year}-${_dateFin.month.toString().padLeft(2, '0')}-${_dateFin.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => _selectDate(context, false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section Type d'état
            _buildSection(
              title: 'Type d\'état',
              child: DropdownButton<String>(
                isExpanded: true,
                value: _typeEtat,
                onChanged: (value) {
                  setState(() => _typeEtat = value!);
                },
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('GÉNÉRAL')),
                  DropdownMenuItem(
                    value: 'analytique',
                    child: Text('ANALYTIQUE'),
                  ),
                  DropdownMenuItem(value: 'tiers', child: Text('TIERS')),
                  DropdownMenuItem(
                    value: 'tiers_analytique',
                    child: Text('TIERS & ANALYTIQUE'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Section Comptes de test
            _buildSection(
              title: 'Comptes disponibles',
              child: Text(
                '${TestData.comptes.length} comptes pré-configurés',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Compte')),
                    DataColumn(label: Text('Intitulé')),
                    DataColumn(label: Text('Débit'), numeric: true),
                    DataColumn(label: Text('Crédit'), numeric: true),
                  ],
                  rows:
                      TestData.comptes
                          .take(5)
                          .map(
                            (compte) => DataRow(
                              cells: [
                                DataCell(Text(compte['numero'] ?? '')),
                                DataCell(
                                  Text(
                                    (compte['intitule'] ?? '').length > 20
                                        ? '${(compte['intitule'] ?? '').substring(0, 20)}...'
                                        : compte['intitule'] ?? '',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (compte['soldeDebit'] ?? 0)
                                        .toString()
                                        .replaceAllMapped(
                                          RegExp(
                                            r'(\d{1,3})(?=(\d{3})+(?!\d))',
                                          ),
                                          (m) => '${m[1]} ',
                                        ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (compte['soldeCredit'] ?? 0)
                                        .toString()
                                        .replaceAllMapped(
                                          RegExp(
                                            r'(\d{1,3})(?=(\d{3})+(?!\d))',
                                          ),
                                          (m) => '${m[1]} ',
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '... et ${TestData.comptes.length - 5} autres comptes',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 32),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier config'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printConfig,
                    icon: const Icon(Icons.info),
                    label: const Text('Afficher config'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> projet) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projet['designation'] ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Budget: ${(projet['budget'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Statut: ${projet['statut'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBailleurCard(Map<String, dynamic> bailleur) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bailleur['designation'] ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Montant: ${(bailleur['montantFinance'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isDebut) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? _dateDebut : _dateFin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  void _printConfig() {
    final config = {
      'projet': TestData.projets[_selectedProjetIndex]['designation'],
      'bailleurs':
          _selectedBailleurs
              .map((i) => TestData.bailleurs[i]['designation'])
              .toList(),
      'dateDebut': _dateDebut.toString().split(' ')[0],
      'dateFin': _dateFin.toString().split(' ')[0],
      'typeEtat': _typeEtat,
      'nombreComptes': TestData.comptes.length,
    };

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Configuration'),
            content: SingleChildScrollView(child: Text(config.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _copyToClipboard() {
    final config = '''
Projet: ${TestData.projets[_selectedProjetIndex]['designation']}
Bailleurs: ${_selectedBailleurs.map((i) => TestData.bailleurs[i]['designation']).join(', ')}
Période: ${_dateDebut.toString().split(' ')[0]} - ${_dateFin.toString().split(' ')[0]}
Type: $_typeEtat
Comptes: ${TestData.comptes.length}
''';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Configuration affichée'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}
