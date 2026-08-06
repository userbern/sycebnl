import 'package:flutter/material.dart';
import '../models/compte.dart';
import '../models/journal.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/exercice_service.dart';

enum _ModeCreation { avecReport, sansReport, anterieur }

class NouvelExercicePage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;
  final VoidCallback? onExerciceCreated;

  const NouvelExercicePage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
    this.onExerciceCreated,
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

  List<Journal> _journaux = [];
  String? _journalSelectionne;
  final _compteEquilibrageController = TextEditingController();
  List<Compte> _comptes = [];
  Future<({double totalDebit, double totalCredit})>? _totauxReportFuture;

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
    _loadJournaux();
    _loadComptes();
  }

  @override
  void dispose() {
    _anneeController.dispose();
    _anneeFocusNode.dispose();
    _compteEquilibrageController.dispose();
    super.dispose();
  }

  Future<void> _loadExercices() async {
    try {
      final exs = await DatabaseService.getExercices();
      if (mounted) setState(() => _exercices = exs);
    } catch (_) {}
  }

  Future<void> _loadJournaux() async {
    try {
      final journaux = await AuthService.getJournaux();
      if (mounted) setState(() => _journaux = journaux);
    } catch (e) {
      debugPrint('Erreur chargement journaux: $e');
    }
  }

  Future<void> _loadComptes() async {
    try {
      final comptes = await DatabaseService.getAllComptes();
      if (mounted) setState(() => _comptes = comptes);
    } catch (e) {
      debugPrint('Erreur chargement comptes: $e');
    }
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

  bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Message d'erreur si la période saisie ne chaîne pas exactement
  /// (sans trou ni chevauchement) avec l'exercice adjacent existant, ou
  /// `null` si tout est cohérent.
  String? get _erreurContinuite {
    if (_mode == _ModeCreation.anterieur) {
      final plusAncien = _plusAncienDebut;
      if (plusAncien == null) return null;
      final attendu = plusAncien.subtract(const Duration(days: 1));
      if (!_memeJour(_dateFin, attendu)) {
        return 'La date de fin doit être exactement le ${_fmtDateTime(attendu)} '
            '(veille du début de l\'exercice le plus ancien), sans écart.';
      }
    } else if (_mode == _ModeCreation.avecReport ||
        _mode == _ModeCreation.sansReport) {
      final dernier = _dernierExercice;
      if (dernier == null) return null;
      final finPrecedente = DateTime.tryParse(dernier['date_fin'].toString());
      if (finPrecedente == null) return null;
      final attendu = finPrecedente.add(const Duration(days: 1));
      if (!_memeJour(_dateDebut, attendu)) {
        return 'La date de début doit être exactement le ${_fmtDateTime(attendu)} '
            '(lendemain de la fin de l\'exercice "${dernier['code']}"), sans '
            'écart.';
      }
    }
    return null;
  }

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
    if (_journaux.isEmpty) {
      // Re-vérifie au cas où le chargement initial (asynchrone, lancé dans
      // initState) ne serait pas encore terminé au moment du clic.
      await _loadJournaux();
    }
    if (_journaux.isEmpty) {
      _showBlockingMessage(
        'Aucun journal disponible',
        'Il n\'y a aucun journal dans ce dossier. Créez d\'abord un journal '
            '(page Journaux) pour pouvoir y enregistrer les écritures de '
            'report.',
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
      _journalSelectionne = null;
      _compteEquilibrageController.clear();
      _totauxReportFuture =
          ExerciceService.calculerTotauxReport(dernier['id'] as int);
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
      _journalSelectionne = null;
      _compteEquilibrageController.clear();
      _totauxReportFuture = null;
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
    if (_erreurContinuite != null) {
      return _erreurContinuite;
    }
    if (_mode == _ModeCreation.avecReport) {
      if (_journalSelectionne == null) {
        return 'Veuillez choisir le journal de report.';
      }
      if (_compteEquilibrageController.text.trim().isEmpty) {
        return 'Veuillez saisir le compte d\'équilibrage.';
      }
    }
    return null;
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.red.shade50,
        content: Text(message, style: TextStyle(color: Colors.red.shade700)),
        leading: Icon(Icons.error_outline, color: Colors.red.shade700),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Fermer'),
          ),
        ],
      ),
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
      _anPreviewFuture = ExerciceService.previewReportSoldes(
        _exercicePrecedentId!,
        compteEquilibrage: _compteEquilibrageController.text.trim(),
      );
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
        codeJournal: _journalSelectionne!,
        compteEquilibrage: _compteEquilibrageController.text.trim(),
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
    widget.onExerciceCreated?.call();
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
      _journalSelectionne = null;
      _compteEquilibrageController.clear();
      _totauxReportFuture = null;
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
      2: 'Vérifiez les soldes à reporter avant de confirmer',
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
              'Reprend les soldes de l\'exercice précédent (comptes classes '
              '1 à 5), recalculés automatiquement.',
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
    final erreurContinuite = _erreurContinuite;

    return Column(
      children: [
        if (erreurContinuite != null) ...[
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
                    erreurContinuite,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        if (_mode == _ModeCreation.avecReport) ...[
          const SizedBox(height: 12),
          _buildSection(
            icon: Icons.repeat,
            title: 'REPORT',
            child: _buildReportContent(),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading || erreurContinuite != null
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

  Widget _buildReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Journal de report',
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Autocomplete<Journal>(
          initialValue: TextEditingValue(
            text: _journalSelectionne == null
                ? ''
                : _journalLabel(_journaux.firstWhere(
                    (j) => j.code == _journalSelectionne,
                    orElse: () => _journaux.first,
                  )),
          ),
          displayStringForOption: _journalLabel,
          optionsBuilder: (value) {
            if (value.text.isEmpty) return _journaux;
            final query = value.text.toLowerCase();
            return _journaux.where((j) =>
                j.code.toLowerCase().contains(query) ||
                j.intitule.toLowerCase().contains(query));
          },
          onSelected: (j) => setState(() => _journalSelectionne = j.code),
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (_) => setState(() => _journalSelectionne = null),
              decoration: _fieldDecoration(
                hint: 'Rechercher un journal…',
                icon: Icons.menu_book_outlined,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) =>
              _optionsListView<Journal>(
            options: options,
            onSelected: onSelected,
            titleOf: (j) => j.code,
            subtitleOf: (j) => j.intitule,
          ),
        ),
        const SizedBox(height: 16),
        _buildSoldeTotalBanner(),
        const SizedBox(height: 12),
        Text(
          'Compte d\'équilibrage',
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Autocomplete<Compte>(
          initialValue:
              TextEditingValue(text: _compteEquilibrageController.text),
          displayStringForOption: (c) => c.numeroCompte,
          optionsBuilder: (value) {
            if (value.text.isEmpty) return const Iterable<Compte>.empty();
            final query = value.text.toLowerCase();
            return _comptes.where((c) =>
                c.numeroCompte.toLowerCase().contains(query) ||
                c.intitule.toLowerCase().contains(query));
          },
          onSelected: (c) => setState(
              () => _compteEquilibrageController.text = c.numeroCompte),
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (v) => _compteEquilibrageController.text = v,
              decoration: _fieldDecoration(
                hint: 'Ex : 120000',
                icon: Icons.account_balance_outlined,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) =>
              _optionsListView<Compte>(
            options: options,
            onSelected: onSelected,
            titleOf: (c) => c.numeroCompte,
            subtitleOf: (c) => c.intitule,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Compte sur lequel imputer l\'écart de balancement (excédent ou '
          'déficit). Créé automatiquement s\'il n\'existe pas encore.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  String _journalLabel(Journal j) => '${j.code} — ${j.intitule}';

  Widget _buildSoldeTotalBanner() {
    return FutureBuilder<({double totalDebit, double totalCredit})>(
      future: _totauxReportFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Calcul du solde à reporter…',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }

        final totalDebit = snapshot.data!.totalDebit;
        final totalCredit = snapshot.data!.totalCredit;
        // Solde total = Crédit - Débit : positif → excédent créditeur (on
        // débitera le compte d'équilibrage), négatif → excédent débiteur
        // (on créditera le compte d'équilibrage).
        final soldeCreditMoinsDebit = totalCredit - totalDebit;
        final estEquilibre = soldeCreditMoinsDebit.abs() <= 0.01;
        final estCrediteur = soldeCreditMoinsDebit > 0;
        final sens = estEquilibre
            ? 'Équilibré'
            : (estCrediteur ? 'Créditeur' : 'Débiteur');
        final color = estEquilibre || estCrediteur
            ? Colors.green
            : Colors.orange;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions, size: 16, color: color.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total débit : ${totalDebit.toStringAsFixed(2)}   ·   '
                      'Total crédit : ${totalCredit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: color.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  estEquilibre
                      ? 'Solde total (Crédit − Débit) : équilibré, aucune '
                          'écriture d\'équilibrage nécessaire.'
                      : 'Solde total (Crédit − Débit) : '
                          '${soldeCreditMoinsDebit >= 0 ? '' : '-'}'
                          '${soldeCreditMoinsDebit.abs().toStringAsFixed(2)} '
                          '($sens) — c\'est ce montant qui sera imputé sur le '
                          'compte d\'équilibrage ci-dessous.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.shade700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade500, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      isDense: true,
    );
  }

  Widget _optionsListView<T extends Object>({
    required Iterable<T> options,
    required AutocompleteOnSelected<T> onSelected,
    required String Function(T) titleOf,
    required String Function(T) subtitleOf,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titleOf(option),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(subtitleOf(option),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
              title: 'SOLDES À REPORTER',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journal : ${_journalSelectionne ?? '-'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  aucuneEcriture
                      ? Text(
                          'L\'exercice précédent n\'a aucun solde non nul sur '
                          'les comptes classes 1 à 5. L\'exercice sera créé '
                          'sans compte d\'ouverture.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        )
                      : _buildRecapTable(preview),
                ],
              ),
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
          final estEquilibrage = l.numeroCompte == preview.compteEquilibrage;
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
