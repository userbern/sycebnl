import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/database_service.dart';
import '../services/exercice_service.dart';

enum _ModeCreation { avecReport, sansReport, anterieur }

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
  List<Map<String, dynamic>> _exercices = [];

  _ModeCreation? _mode;
  int _step = 0; // 0 = choix du mode, 1 = dates, 2 = récap (avecReport)
  int? _exercicePrecedentId;
  Future<AnPreview?>? _anPreviewFuture;
  bool _datesModifieesManuellement = false;

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

  DateTime get _dateDebut =>
      DateTime(selectedDebutYear, selectedDebutMonth, selectedDebutDay);

  DateTime get _dateFin =>
      DateTime(selectedFinYear, selectedFinMonth, selectedFinDay);

  int get _dureeMois {
    final d = _dateDebut;
    final f = _dateFin;
    final m = (f.year - d.year) * 12 + (f.month - d.month) + 1;
    return m < 1 ? 1 : m;
  }

  /// Exercice le plus récent (par date de fin) déjà présent, tous statuts
  /// confondus — c'est celui dont dépend l'option "Avec report".
  Map<String, dynamic>? get _dernierExercice {
    Map<String, dynamic>? best;
    DateTime? bestEnd;
    for (final ex in _exercices) {
      final fin = DateTime.tryParse(ex['date_fin']?.toString() ?? '');
      if (fin == null) continue;
      if (bestEnd == null || fin.isAfter(bestEnd)) {
        bestEnd = fin;
        best = ex;
      }
    }
    return best;
  }

  DateTime? get _plusAncienDebut {
    DateTime? best;
    for (final ex in _exercices) {
      final debut = DateTime.tryParse(ex['date_debut']?.toString() ?? '');
      if (debut == null) continue;
      if (best == null || debut.isBefore(best)) best = debut;
    }
    return best;
  }

  String _fmtDate(int d, int m, int y) =>
      '${d.toString().padLeft(2, '0')} ${_monthAbbr[m - 1]} $y';

  String _fmtDateTime(DateTime d) => _fmtDate(d.day, d.month, d.year);

  static final RegExp _codeAnneeRegExp = RegExp(r'^\d{4}$');

  void _onCodeChanged(String value) {
    if (!_datesModifieesManuellement) {
      final code = value.trim();
      if (_codeAnneeRegExp.hasMatch(code)) {
        final annee = int.parse(code);
        if (annee >= 1900 && annee <= 2999) {
          selectedDebutDay = 1;
          selectedDebutMonth = 1;
          selectedDebutYear = annee;
          selectedFinDay = 31;
          selectedFinMonth = 12;
          selectedFinYear = annee;
        }
      }
    }
    setState(() {});
  }

  // ── Choix du mode ────────────────────────────────────────────────────────────

  Future<void> _choisirAvecReport() async {
    final dernier = _dernierExercice;
    if (dernier == null) {
      _showBlockingMessage(
        'Aucun exercice existant',
        'Il n\'y a aucun exercice précédent dans ce dossier. Utilisez '
            '"Créer un exercice sans report" pour le tout premier exercice.',
      );
      return;
    }
    if ((dernier['is_cloture'] as int? ?? 0) != 1) {
      _showBlockingMessage(
        'Clôture requise',
        'L\'exercice "${dernier['code']}" doit être clôturé avant de créer un '
            'exercice avec report : c\'est la clôture qui génère le journal '
            'des A-Nouveaux utilisé pour les comptes d\'ouverture.',
      );
      return;
    }

    final finPrecedent =
        DateTime.tryParse(dernier['date_fin'].toString()) ?? DateTime.now();
    final debut = finPrecedent.add(const Duration(days: 1));
    final fin = DateTime(debut.year + 1, debut.month, debut.day)
        .subtract(const Duration(days: 1));

    setState(() {
      _mode = _ModeCreation.avecReport;
      _exercicePrecedentId = dernier['id'] as int;
      selectedDebutDay = debut.day;
      selectedDebutMonth = debut.month;
      selectedDebutYear = debut.year;
      selectedFinDay = fin.day;
      selectedFinMonth = fin.month;
      selectedFinYear = fin.year;
      _datesModifieesManuellement = false;
      _step = 1;
    });
  }

  void _choisirSansReport() {
    final dernier = _dernierExercice;
    if (dernier != null) {
      final finPrecedent =
          DateTime.tryParse(dernier['date_fin'].toString()) ?? DateTime.now();
      final debut = finPrecedent.add(const Duration(days: 1));
      final fin = DateTime(debut.year + 1, debut.month, debut.day)
          .subtract(const Duration(days: 1));
      setState(() {
        selectedDebutDay = debut.day;
        selectedDebutMonth = debut.month;
        selectedDebutYear = debut.year;
        selectedFinDay = fin.day;
        selectedFinMonth = fin.month;
        selectedFinYear = fin.year;
      });
    }
    setState(() {
      _mode = _ModeCreation.sansReport;
      _datesModifieesManuellement = false;
      _step = 1;
    });
  }

  void _choisirAnterieur() {
    final plusAncien = _plusAncienDebut;
    if (plusAncien != null) {
      final fin = plusAncien.subtract(const Duration(days: 1));
      final debut = DateTime(fin.year - 1, fin.month, fin.day)
          .add(const Duration(days: 1));
      setState(() {
        selectedDebutDay = debut.day;
        selectedDebutMonth = debut.month;
        selectedDebutYear = debut.year;
        selectedFinDay = fin.day;
        selectedFinMonth = fin.month;
        selectedFinYear = fin.year;
      });
    }
    setState(() {
      _mode = _ModeCreation.anterieur;
      _datesModifieesManuellement = false;
      _step = 1;
    });
  }

  void _showBlockingMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
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

  void _retourChoixMode() {
    setState(() {
      _mode = null;
      _step = 0;
      _exercicePrecedentId = null;
      _anPreviewFuture = null;
      _datesModifieesManuellement = false;
    });
  }

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context, bool isDebut) async {
    int day = isDebut ? selectedDebutDay : selectedFinDay;
    int month = isDebut ? selectedDebutMonth : selectedFinMonth;
    int year = isDebut ? selectedDebutYear : selectedFinYear;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isDebut ? 'Date de début' : 'Date de fin'),
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
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
                                      child: Text(e.value,
                                          textAlign: TextAlign.center),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => month = v ?? month),
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        _dropContainer(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: year,
                            underline: const SizedBox(),
                            items: List.generate(101, (i) => 2000 + i)
                                .map((y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(y.toString(),
                                          textAlign: TextAlign.center),
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
              onPressed: () => Navigator.pop(
                  context, {'day': day, 'month': month, 'year': year}),
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
        _datesModifieesManuellement = true;
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

  // ── Validation / actions ─────────────────────────────────────────────────────

  bool get _canCreate =>
      widget.userSession.isAdmin || widget.userSession.canCreate('exercices');

  String? _validerFormulaire() {
    if (!_canCreate) return 'Permission insuffisante pour créer un exercice.';
    if (_anneeController.text.trim().isEmpty) {
      return 'Veuillez saisir le code de l\'exercice.';
    }
    if (!_dateFin.isAfter(_dateDebut)) {
      return 'La date de fin doit être postérieure à la date de début.';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _continuerVersRecap() async {
    final erreur = _validerFormulaire();
    if (erreur != null) {
      _showError(erreur);
      return;
    }
    setState(() {
      _step = 2;
      _anPreviewFuture = ExerciceService.getAnPreview(_exercicePrecedentId!);
    });
  }

  Future<void> _creerSansReportOuAnterieur() async {
    final erreur = _validerFormulaire();
    if (erreur != null) {
      _showError(erreur);
      return;
    }

    setState(() => isLoading = true);
    try {
      if (_mode == _ModeCreation.sansReport) {
        await ExerciceService.creerExerciceSansReport(
          code: _anneeController.text.trim(),
          dateDebut: _dateDebut,
          dateFin: _dateFin,
        );
      } else {
        await ExerciceService.creerExerciceAnterieur(
          code: _anneeController.text.trim(),
          dateDebut: _dateDebut,
          dateFin: _dateFin,
        );
      }
      _onCreationReussie();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showError(e is ExerciceOperationException ? e.message : 'Erreur : $e');
    }
  }

  Future<void> _confirmerCreationAvecReport() async {
    setState(() => isLoading = true);
    try {
      await ExerciceService.creerExerciceAvecReport(
        code: _anneeController.text.trim(),
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        exercicePrecedentId: _exercicePrecedentId!,
      );
      _onCreationReussie();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showError(e is ExerciceOperationException ? e.message : 'Erreur : $e');
    }
  }

  void _onCreationReussie() {
    if (!mounted) return;
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exercice créé avec succès'),
        backgroundColor: Colors.green,
      ),
    );
    if (widget.showAppBar) {
      Navigator.of(context).pop(true);
    } else {
      _resetForm();
    }
  }

  void _resetForm() {
    final now = DateTime.now();
    setState(() {
      _anneeController.clear();
      _mode = null;
      _step = 0;
      _exercicePrecedentId = null;
      _anPreviewFuture = null;
      _datesModifieesManuellement = false;
      selectedDebutDay = 1;
      selectedDebutMonth = 1;
      selectedDebutYear = now.year;
      selectedFinDay = 31;
      selectedFinMonth = 12;
      selectedFinYear = now.year;
    });
    _loadExercices();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: switch (_step) {
                  1 => _buildStepDates(),
                  2 => _buildStepRecap(),
                  _ => _buildStepChoixMode(),
                },
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

  Widget _buildHeader() {
    const titles = {
      0: 'Nouvel exercice comptable',
      1: 'Période de l\'exercice',
      2: 'Récapitulatif des reports',
    };
    const subtitles = {
      0: 'Choisissez comment créer ce nouvel exercice',
      1: 'Définissez les dates de début et de fin',
      2: 'Vérifiez le journal AN avant de confirmer',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            IconButton(
              onPressed: _step == 2
                  ? () => setState(() => _step = 1)
                  : _retourChoixMode,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour',
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.add_chart, color: Colors.blue.shade700, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_step]!,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitles[_step]!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Étape 1 : choix du mode ───────────────────────────────────────────────────

  Widget _buildStepChoixMode() {
    return Column(
      children: [
        _ModeCard(
          icon: Icons.repeat,
          color: Colors.blue,
          title: 'Créer un exercice avec report',
          description:
              'Reprend les soldes de clôture de l\'exercice précédent via son '
              'journal des A-Nouveaux. Nécessite que l\'exercice précédent '
              'soit clôturé.',
          onTap: _choisirAvecReport,
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.note_add_outlined,
          color: Colors.green,
          title: 'Créer un exercice sans report',
          description:
              'Crée un exercice totalement vide, sans compte d\'ouverture. '
              'Idéal pour le tout premier exercice du dossier.',
          onTap: _choisirSansReport,
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.history,
          color: Colors.purple,
          title: 'Créer un exercice antérieur',
          description:
              'Ajoute un exercice plus ancien que ceux déjà présents (ex : '
              'ajouter 2024 alors que 2025 existe déjà).',
          onTap: _choisirAnterieur,
        ),
      ],
    );
  }

  // ── Étape 2 : dates ───────────────────────────────────────────────────────────

  Widget _buildStepDates() {
    final plusAncien = _plusAncienDebut;
    final incoherenceAnterieur = _mode == _ModeCreation.anterieur &&
        plusAncien != null &&
        !_dateFin.isBefore(plusAncien);

    return Column(
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
        if (_mode == _ModeCreation.anterieur && incoherenceAnterieur) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La date de fin doit précéder le début du plus ancien '
                    'exercice existant (${_fmtDateTime(plusAncien)}).',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading || incoherenceAnterieur
                    ? null
                    : (_mode == _ModeCreation.avecReport
                        ? _continuerVersRecap
                        : _creerSansReportOuAnterieur),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _mode == _ModeCreation.avecReport
                            ? Icons.arrow_forward
                            : Icons.add_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(_mode == _ModeCreation.avecReport
                    ? 'Voir le récapitulatif'
                    : 'Créer l\'exercice'),
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
        ),
        const SizedBox(height: 24),
      ],
    );
  }

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
          onChanged: _onCodeChanged,
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
      ],
    );
  }

  Widget _buildPeriodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  // ── Étape 3 : récapitulatif (avec report uniquement) ─────────────────────────

  Widget _buildStepRecap() {
    return FutureBuilder<AnPreview?>(
      future: _anPreviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final preview = snapshot.data;
        final aucuneEcriture = preview == null || preview.lignes.isEmpty;

        return Column(
          children: [
            _buildSection(
              icon: Icons.summarize_outlined,
              title: 'JOURNAL AN UTILISÉ',
              child: aucuneEcriture
                  ? Text(
                      'L\'exercice précédent n\'a généré aucune écriture de '
                      'report (aucun solde non nul sur les classes 1 à 5). '
                      'L\'exercice sera créé sans compte d\'ouverture.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    )
                  : _buildRecapTable(preview),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _confirmerCreationAvecReport,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.white),
                    label: const Text('Confirmer la création'),
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
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildRecapTable(AnPreview preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _recapStat('Comptes reportés', '${preview.lignes.length}'),
            ),
            Expanded(
              child: _recapStat(
                  'Total débit', preview.totalDebit.toStringAsFixed(2)),
            ),
            Expanded(
              child: _recapStat(
                  'Total crédit', preview.totalCredit.toStringAsFixed(2)),
            ),
            Expanded(
              child: _recapStat(
                  'Compte d\'équilibrage', preview.compteEquilibrage ?? '-'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 8),
        Text(
          'Aperçu des écritures d\'ouverture qui seront créées',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        ...preview.lignes.map((l) {
          final estEquilibrage =
              l.numeroCompte.startsWith('121') || l.numeroCompte.startsWith('129');
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: estEquilibrage ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text(l.numeroCompte,
                        style: const TextStyle(fontSize: 12))),
                Expanded(
                    child: Text(l.intitule,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                SizedBox(
                  width: 90,
                  child: Text(
                    l.montantDebit == 0 ? '-' : l.montantDebit.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    l.montantCredit == 0
                        ? '-'
                        : l.montantCredit.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _recapStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final MaterialColor color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color.shade600, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
