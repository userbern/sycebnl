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
  final _anneeFocusNode = FocusNode();
  bool isLoading = false;
  bool reportSoldes = true;
  List<Map<String, dynamic>> _exercices = [];

  late int selectedDebutDay, selectedDebutMonth, selectedDebutYear;
  late int selectedFinDay, selectedFinMonth, selectedFinYear;

  static const _monthAbbr = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

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
    _loadExercices();
    // Force le focus dès l'arrivée sur la page, sinon le champ ne réagit
    // pas instantanément au clavier (le focus est resté sur le widget
    // précédent, ex: le bouton cliqué pour naviguer jusqu'ici).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anneeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _anneeController.dispose();
    _anneeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExercices() async {
    try {
      final exs = await DatabaseService.getExercices();
      if (mounted) setState(() => _exercices = exs);
    } catch (_) {}
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  String get _dateDebutISO =>
      '$selectedDebutYear-${selectedDebutMonth.toString().padLeft(2, '0')}-${selectedDebutDay.toString().padLeft(2, '0')}';

  String get _dateFinISO =>
      '$selectedFinYear-${selectedFinMonth.toString().padLeft(2, '0')}-${selectedFinDay.toString().padLeft(2, '0')}';

  int get _dureeMois {
    final d = DateTime(selectedDebutYear, selectedDebutMonth, selectedDebutDay);
    final f = DateTime(selectedFinYear, selectedFinMonth, selectedFinDay);
    final m = (f.year - d.year) * 12 + (f.month - d.month) + 1;
    return m < 1 ? 1 : m;
  }

  String get _typeExercice {
    final duree = _dureeMois;
    final debutJan = selectedDebutMonth == 1 && selectedDebutDay == 1;
    final finDec = selectedFinMonth == 12 && selectedFinDay == 31;
    if (duree == 12 && debutJan && finDec) return 'Standard calendaire';
    if (duree == 12) return 'Standard décalé';
    if (duree < 12) return 'Exercice court';
    return 'Exercice long';
  }

  Map<String, dynamic>? get _exercicePrecedent {
    final debut = DateTime.tryParse(_dateDebutISO);
    if (debut == null) return null;
    Map<String, dynamic>? best;
    DateTime? bestDate;
    for (final ex in _exercices) {
      final fin = DateTime.tryParse(ex['date_fin']?.toString() ?? '');
      if (fin == null) continue;
      if (fin.isBefore(debut)) {
        if (bestDate == null || fin.isAfter(bestDate)) {
          bestDate = fin;
          best = ex;
        }
      }
    }
    return best;
  }


  String _fmtDate(int d, int m, int y) =>
      '${d.toString().padLeft(2, '0')} ${_monthAbbr[m - 1]} $y';


  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context, bool isDebut) async {
    int day = isDebut ? selectedDebutDay : selectedFinDay;
    int month = isDebut ? selectedDebutMonth : selectedFinMonth;
    int year = isDebut ? selectedDebutYear : selectedFinYear;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isDebut
              ? 'Date de début'
              : 'Date de fin'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Jour',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        _dropContainer(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: day,
                            underline: const SizedBox(),
                            items: List.generate(31, (i) => i + 1)
                                .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d.toString().padLeft(2, '0'),
                                          textAlign: TextAlign.center),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => day = v ?? day),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Mois',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        _dropContainer(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: month,
                            underline: const SizedBox(),
                            items: _monthAbbr
                                .asMap()
                                .entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key + 1,
                                      child: Text(e.value, textAlign: TextAlign.center),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => month = v ?? month),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Année',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        _dropContainer(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: year,
                            underline: const SizedBox(),
                            items: List.generate(101, (i) => 2000 + i)
                                .map((y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(y.toString(), textAlign: TextAlign.center),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => year = v ?? year),
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
              onPressed: () =>
                  Navigator.pop(context, {'day': day, 'month': month, 'year': year}),
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
      });
    }
  }

  Widget _dropContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _creerExercice() async {
    if (!widget.userSession.isAdmin &&
        !widget.userSession.canCreate('exercices')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission insuffisante pour créer un exercice.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_anneeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le code de l\'exercice'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await _showConfirmDialog();
    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      await DatabaseService.createExercice(
        code: _anneeController.text.trim(),
        dateDebut: _dateDebutISO,
        dateFin: _dateFinISO,
        dureeMois: _dureeMois,
        reportSoldes: reportSoldes,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercice créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.showAppBar && mounted) {
        Navigator.of(context).pop(true);
      } else {
        _resetForm();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _showConfirmDialog() {
    final code = _anneeController.text.trim();
    final precede = _exercicePrecedent;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Créer l\'exercice ${code.isEmpty ? '?' : code}')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Résumé tabulaire
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _confirmRow('Code', code.isEmpty ? '—' : code,
                        icon: Icons.tag),
                    _confirmRow(
                        'Début',
                        _fmtDate(selectedDebutDay, selectedDebutMonth,
                            selectedDebutYear),
                        icon: Icons.calendar_today_outlined),
                    _confirmRow(
                        'Fin',
                        _fmtDate(
                            selectedFinDay, selectedFinMonth, selectedFinYear),
                        icon: Icons.event_outlined),
                    _confirmRow('Durée', '$_dureeMois mois',
                        icon: Icons.schedule, highlight: true),
                    _confirmRow('Type', _typeExercice,
                        icon: Icons.info_outline),
                    _confirmRow('Statut initial', 'OUVERT',
                        icon: Icons.lock_open_outlined),
                    if (precede != null)
                      _confirmRow('Exercice précédent',
                          precede['code']?.toString() ?? '—',
                          icon: Icons.history),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Report des soldes
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: reportSoldes ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: reportSoldes
                        ? Colors.blue.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      reportSoldes
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: reportSoldes
                          ? Colors.blue.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reportSoldes
                            ? 'Report des soldes activé${precede != null ? ' depuis "${precede['code']}"' : ''}. Les soldes de bilan seront repris en ouverture.'
                            : 'Pas de report. L\'exercice démarrera avec des soldes à zéro.',
                        style: TextStyle(
                          fontSize: 12,
                          color: reportSoldes
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Avertissement
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 15, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cette action est définitive. Vérifiez les dates et le code avant de confirmer.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Créer l\'exercice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(
    String label,
    String value, {
    required IconData icon,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? Colors.blue.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    final now = DateTime.now();
    setState(() {
      _anneeController.clear();
      selectedDebutDay = 1;
      selectedDebutMonth = 1;
      selectedDebutYear = now.year;
      selectedFinDay = 31;
      selectedFinMonth = 12;
      selectedFinYear = now.year;
      reportSoldes = true;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final precede = _exercicePrecedent;

    final body = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    _buildSection(
                      icon: Icons.tag,
                      title: 'IDENTIFICATION',
                      child: _buildIdentificationContent(),
                    ),
                    const SizedBox(height: 12),

                    _buildSection(
                      icon: Icons.date_range,
                      title: 'PÉRIODE',
                      child: _buildPeriodeContent(),
                    ),
                    const SizedBox(height: 12),

                    _buildSection(
                      icon: Icons.settings_outlined,
                      title: 'OPTIONS',
                      child: _buildOptionsContent(precede),
                    ),
                    const SizedBox(height: 24),

                    _buildActions(),
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
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: body,
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add_chart, color: Colors.blue.shade700, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nouvel exercice comptable',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Définissez la période et les paramètres du nouvel exercice',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade600),
                ),
                const SizedBox(width: 6),
                Text(
                  'Statut : OUVERT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ──────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ── Identification ───────────────────────────────────────────────────────────

  Widget _buildIdentificationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de l\'exercice',
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _anneeController,
          focusNode: _anneeFocusNode,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ex : 2025, EX-2025, AN2025…',
            prefixIcon:
                Icon(Icons.tag, size: 18, color: Colors.grey.shade400),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.blue.shade500, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ce code identifie l\'exercice de manière unique dans le logiciel. Il est généralement basé sur l\'année (ex : 2025) ou une référence interne.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ── Période ──────────────────────────────────────────────────────────────────

  Widget _buildPeriodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Un exercice dure généralement 12 mois. Il peut chevaucher deux années calendaires (ex : Juillet 2025 → Juin 2026).',
                  style:
                      TextStyle(fontSize: 11, color: Colors.blue.shade700),
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
                dateStr: _fmtDate(selectedDebutDay, selectedDebutMonth,
                    selectedDebutYear),
                onTap: () => _selectDate(context, true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
              child: Icon(Icons.arrow_forward,
                  size: 18, color: Colors.grey.shade400),
            ),
            Expanded(
              child: _buildDateButton(
                label: 'Date de fin',
                sublabel: 'Fin',
                dateStr: _fmtDate(
                    selectedFinDay, selectedFinMonth, selectedFinYear),
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDureeBadge(),
      ],
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
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 15, color: Colors.blue.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sublabel,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _buildDureeBadge() {
    final duree = _dureeMois;
    final isStandard = duree == 12;
    final isShort = duree < 12;

    Color bg, fg, border;
    String label;
    IconData icon;

    if (isStandard) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      border = Colors.green.shade200;
      label = 'Durée standard — 12 mois';
      icon = Icons.check_circle_outline;
    } else if (isShort) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      border = Colors.orange.shade200;
      label = 'Exercice court — $duree mois (inférieur à 12 mois)';
      icon = Icons.info_outline;
    } else {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade700;
      border = Colors.purple.shade200;
      label = 'Exercice long — $duree mois (supérieur à 12 mois)';
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }


  // ── Options ──────────────────────────────────────────────────────────────────

  Widget _buildOptionsContent(Map<String, dynamic>? precede) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reportSoldes ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reportSoldes
              ? Colors.blue.shade200
              : Colors.grey.shade200,
          width: reportSoldes ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Reporter les soldes d\'ouverture',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: reportSoldes
                                ? Colors.blue.shade800
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _showReportHelp,
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(Icons.help_outline,
                              size: 16, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reportSoldes
                          ? 'Les soldes de clôture de l\'exercice précédent seront automatiquement transférés en écriture d\'ouverture de ce nouvel exercice.'
                          : 'Le nouvel exercice démarrera avec des soldes nuls sur tous les comptes. Aucune écriture d\'ouverture ne sera générée.',
                      style: TextStyle(
                        fontSize: 12,
                        color: reportSoldes
                            ? Colors.blue.shade700
                            : Colors.grey.shade600,
                      ),
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
          if (reportSoldes) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.blue.shade100),
            const SizedBox(height: 14),
            Text(
              'IMPACTS DU REPORT',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade400,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            _impactRow(
              Icons.account_balance_outlined,
              'Comptes de bilan (classes 1 à 5)',
              'Les soldes débiteurs et créditeurs seront repris en écriture d\'ouverture.',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _impactRow(
              Icons.trending_up,
              'Comptes de résultat (classes 6 et 7)',
              'Non reportés — charges et produits repartent à zéro dans le nouvel exercice.',
              Colors.orange,
            ),
            const SizedBox(height: 8),
            if (precede != null)
              _impactRow(
                Icons.link,
                'Source : exercice "${precede['code']}"',
                'Les soldes seront issus de la clôture de cet exercice précédent.',
                Colors.green,
              )
            else
              _impactRow(
                Icons.warning_amber_outlined,
                'Aucun exercice précédent détecté',
                'Le report s\'effectuera s\'il existe des données pour la période précédente.',
                Colors.orange,
              ),
          ],
        ],
      ),
    );
  }

  Widget _impactRow(
      IconData icon, String title, String desc, MaterialColor color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: color.shade50, borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: color.shade600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.shade700)),
              Text(desc,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  void _showReportHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Report des soldes d\'ouverture',
                    style: TextStyle(fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le report des soldes assure la continuité comptable entre deux exercices successifs.',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              _helpSection(
                'Quand activer ?',
                [
                  'Lors de la création d\'un exercice faisant suite à un exercice précédent.',
                  'Pour assurer la continuité des soldes de bilan (actifs, dettes, capitaux…).',
                ],
                Colors.blue,
              ),
              const SizedBox(height: 10),
              _helpSection(
                'Quand désactiver ?',
                [
                  'Pour le tout premier exercice (aucune donnée antérieure).',
                  'Si vous souhaitez démarrer avec tous les soldes à zéro.',
                ],
                Colors.orange,
              ),
              const SizedBox(height: 10),
              _helpSection(
                'Comptes concernés',
                [
                  'Classes 1 à 5 (bilan) : capitaux, immobilisations, stocks, tiers, trésorerie.',
                  'Classes 6 et 7 (résultat) : non reportés — remis à zéro à chaque exercice.',
                ],
                Colors.green,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, List<String> points, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade700)),
          const SizedBox(height: 4),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color.shade600)),
                    Expanded(
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 12, color: color.shade700))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Actions bar ──────────────────────────────────────────────────────────────

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Réinitialiser'),
          style: OutlinedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            side: BorderSide(color: Colors.grey.shade300),
            foregroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _creerExercice,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_circle_outline,
                    size: 18, color: Colors.white),
            label: const Text('Créer l\'exercice'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
