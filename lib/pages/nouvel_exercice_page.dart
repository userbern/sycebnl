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

  int get _dureeMois {
    final d = DateTime(selectedDebutYear, selectedDebutMonth, selectedDebutDay);
    final f = DateTime(selectedFinYear, selectedFinMonth, selectedFinDay);
    return (f.year - d.year) * 12 + (f.month - d.month) + 1;
  }

  static const _monthAbbr = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  String _fmtDate(int d, int m, int y) =>
      '${d.toString().padLeft(2, '0')} / ${_monthAbbr[m - 1]} / $y';

  void _resetForm() {
    final now = DateTime.now();
    setState(() {
      _anneeController.clear();
      _dateDebutController.clear();
      _dateFinController.clear();
      selectedDebutDay = 1;
      selectedDebutMonth = 1;
      selectedDebutYear = now.year;
      selectedFinDay = 31;
      selectedFinMonth = 12;
      selectedFinYear = now.year;
      reportSoldes = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        
        // Bandeau bleu
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.blue.shade100,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvel exercice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Création d\'un nouvel exercice comptable',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '$_dureeMois mois',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Contenu
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    // IDENTIFICATION
                    _buildSection(
                      icon: Icons.tag,
                      title: 'IDENTIFICATION',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Code de l\'exercice',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _anneeController,
                            decoration: InputDecoration(
                              hintText: 'Ex: 2025',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 13, color: Colors.blue.shade500),
                                const SizedBox(width: 5),
                                Text(
                                  'Durée calculée : $_dureeMois mois',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PÉRIODE
                    _buildSection(
                      icon: Icons.date_range,
                      title: 'PÉRIODE',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade500),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Un exercice dure généralement 12 mois. Il peut chevaucher deux années calendaires (ex : juin 2025 → mai 2026).',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateButton(
                                  label: 'Date de début',
                                  sublabel: 'Début',
                                  dateStr: _fmtDate(selectedDebutDay, selectedDebutMonth, selectedDebutYear),
                                  onTap: () => _selectDate(context, _dateDebutController, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateButton(
                                  label: 'Date de fin',
                                  sublabel: 'Fin',
                                  dateStr: _fmtDate(selectedFinDay, selectedFinMonth, selectedFinYear),
                                  onTap: () => _selectDate(context, _dateFinController, false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // OPTIONS
                    _buildSection(
                      icon: Icons.settings,
                      title: 'OPTIONS',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reporter les soldes',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Transfère les soldes de clôture N vers l\'ouverture N+1',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: reportSoldes,
                            activeColor: Colors.blue.shade500,
                            onChanged: (v) => setState(() => reportSoldes = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.refresh, size: 17),
                          label: const Text('Réinitialiser'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _creerExercice,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                            label: const Text('Créer l\'exercice'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              backgroundColor: Colors.blue.shade500,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Nouvel exercice'),
              backgroundColor: Colors.blue.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: body,
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required String sublabel,
    required String dateStr,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 15, color: Colors.blue.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sublabel,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
