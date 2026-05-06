import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/database_service.dart';

class NouvelExercicePage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const NouvelExercicePage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<NouvelExercicePage> createState() => _NouvelExercicePageState();
}

class _NouvelExercicePageState extends State<NouvelExercicePage> {
  final _anneeController = TextEditingController();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  bool isLoading = false;
  bool reportSoldes = true;

  // Variables pour les dropdowns
  late int selectedDebutDay, selectedDebutMonth, selectedDebutYear;
  late int selectedFinDay, selectedFinMonth, selectedFinYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDebutDay = 1;
    selectedDebutMonth = 1;
    selectedDebutYear = now.year;
    selectedFinDay = 31;
    selectedFinMonth = 12;
    selectedFinYear = now.year;
  }

  @override
  void dispose() {
    _anneeController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  Future<void> _selectDateWithDropdown(
    BuildContext context,
    TextEditingController controller,
    bool isDebut,
  ) async {
    int day = isDebut ? selectedDebutDay : selectedFinDay;
    int month = isDebut ? selectedDebutMonth : selectedFinMonth;
    int year = isDebut ? selectedDebutYear : selectedFinYear;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    isDebut
                        ? 'Sélectionner la date de début'
                        : 'Sélectionner la date de fin',
                  ),
                  content: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Jour
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Jour',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: day,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(31, (i) => i + 1)
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d.toString().padLeft(2, '0'),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => day = value ?? day);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Mois
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Mois',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: month,
                                    underline: const SizedBox(),
                                    items:
                                        [
                                              'Jan',
                                              'Fév',
                                              'Mar',
                                              'Avr',
                                              'Mai',
                                              'Jun',
                                              'Jul',
                                              'Aoû',
                                              'Sep',
                                              'Oct',
                                              'Nov',
                                              'Déc',
                                            ]
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e.key + 1,
                                                child: Text(
                                                  e.value,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => month = value ?? month);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Année
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Année',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: year,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(101, (i) => 2000 + i)
                                            .map(
                                              (y) => DropdownMenuItem(
                                                value: y,
                                                child: Text(
                                                  y.toString(),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => year = value ?? year);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.pop(context, {
                            'day': day,
                            'month': month,
                            'year': year,
                          }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
          ),
    );

    if (result != null) {
      setState(() {
        if (isDebut) {
          selectedDebutDay = result['day']!;
          selectedDebutMonth = result['month']!;
          selectedDebutYear = result['year']!;
        } else {
          selectedFinDay = result['day']!;
          selectedFinMonth = result['month']!;
          selectedFinYear = result['year']!;
        }

        final formattedDay = result['day'].toString().padLeft(2, '0');
        final formattedMonth = result['month'].toString().padLeft(2, '0');
        controller.text = '$formattedDay/$formattedMonth/${result['year']}';
      });
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
    bool isDebut,
  ) async {
    _selectDateWithDropdown(context, controller, isDebut);
  }

  Future<void> _creerExercice() async {
    if (_anneeController.text.isEmpty ||
        _dateDebutController.text.isEmpty ||
        _dateFinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la création'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exercice: ${_anneeController.text}'),
                Text(
                  'Période: ${_dateDebutController.text} - ${_dateFinController.text}',
                ),
                if (reportSoldes)
                  const Text(
                    '\nLes soldes de l\'exercice précédent seront reportés.',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Créer'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        // Convertir les dates du format DD/MM/YYYY au format ISO
        final dateDebut = _parseDateToISO(_dateDebutController.text);
        final dateFin = _parseDateToISO(_dateFinController.text);

        // Calculer la durée en mois
        final debut = DateTime.parse(dateDebut);
        final fin = DateTime.parse(dateFin);
        final dureeMois =
            ((fin.year - debut.year) * 12 + (fin.month - debut.month) + 1);

        // Créer l'exercice
        await DatabaseService.createExercice(
          code: _anneeController.text,
          dateDebut: dateDebut,
          dateFin: dateFin,
          dureeMois: dureeMois,
          reportSoldes: reportSoldes,
        );

        if (!mounted) return;
        setState(() {
          isLoading = false;
          _anneeController.clear();
          _dateDebutController.clear();
          _dateFinController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nouvel exercice créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        // Retourner true pour signaler la création réussie
        if (widget.showAppBar && mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _parseDateToISO(String dateStr) {
    // Convertir DD/MM/YYYY en YYYY-MM-DD
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Nouvel exercice'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              )
              : null,
      body: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenHeight * 0.02),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade500, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_month,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouvel exercice',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Création d\'un nouvel exercice comptable',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenHeight * 0.02),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations de l\'exercice',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _anneeController,
                            decoration: InputDecoration(
                              labelText: 'Année de l\'exercice *',
                              hintText: 'Ex: 2025',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _dateDebutController,
                                  decoration: InputDecoration(
                                    labelText: 'Date de début *',
                                    hintText: 'JJ/MM/AAAA',
                                    prefixIcon: const Icon(Icons.event),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  readOnly: true,
                                  onTap:
                                      () => _selectDate(
                                        context,
                                        _dateDebutController,
                                        true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _dateFinController,
                                  decoration: InputDecoration(
                                    labelText: 'Date de fin *',
                                    hintText: 'JJ/MM/AAAA',
                                    prefixIcon: const Icon(Icons.event),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  readOnly: true,
                                  onTap:
                                      () => _selectDate(
                                        context,
                                        _dateFinController,
                                        false,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CheckboxListTile(
                            title: const Text(
                              'Reporter les soldes de l\'exercice précédent',
                            ),
                            subtitle: const Text(
                              'Les soldes des comptes seront automatiquement reportés',
                            ),
                            value: reportSoldes,
                            onChanged: (value) {
                              setState(() => reportSoldes = value ?? true);
                            },
                            activeColor: Colors.indigo,
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _anneeController.clear();
                                  _dateDebutController.clear();
                                  _dateFinController.clear();
                                  setState(() => reportSoldes = true);
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Réinitialiser'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: isLoading ? null : _creerExercice,
                                icon:
                                    isLoading
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.add_circle),
                                label: const Text('Créer l\'exercice'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade400,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Informations importantes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          _buildWarningItem(
                            'Période de l\'exercice',
                            'Un exercice comptable dure généralement 12 mois (du 01/01 au 31/12).',
                            Icons.calendar_view_month,
                          ),
                          const SizedBox(height: 12),
                          _buildWarningItem(
                            'Report des soldes',
                            'Le report des soldes transfert automatiquement les soldes de clôture de l\'exercice N vers l\'ouverture de l\'exercice N+1.',
                            Icons.swap_horiz,
                          ),
                          const SizedBox(height: 12),
                          _buildWarningItem(
                            'Validation',
                            'Une fois l\'exercice créé, assurez-vous de vérifier les comptes de bilan pour le report à nouveau.',
                            Icons.verified,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade400, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
