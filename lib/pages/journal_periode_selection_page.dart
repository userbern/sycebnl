import 'package:flutter/material.dart';
import 'package:sycebnl_accounting/models/exercice.dart';
import 'package:sycebnl_accounting/models/journal.dart';
import 'package:sycebnl_accounting/models/saisie_comptable.dart';
import 'package:sycebnl_accounting/models/user_session.dart';
import 'package:sycebnl_accounting/services/saisie_comptable_service.dart';
import 'package:sycebnl_accounting/services/auth_service.dart';
import 'saisie_ecriture_page.dart';

typedef MoisData = ({String label, int mois, int annee, String id});

const List<String> _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

class JournalPeriodeSelectionPage extends StatefulWidget {
  final bool showAppBar;
  final Future<bool> Function(JournalPeriode)? onOpenPeriode;
  final UserSession? userSession;

  const JournalPeriodeSelectionPage({
    super.key,
    this.showAppBar = true,
    this.onOpenPeriode,
    this.userSession,
  });

  @override
  State<JournalPeriodeSelectionPage> createState() =>
      _JournalPeriodeSelectionPageState();
}

class _JournalPeriodeSelectionPageState
    extends State<JournalPeriodeSelectionPage> {
  List<Journal> _journaux = [];
  bool _isLoading = true;
  List<MoisData> _moisDisponibles = [];
  Exercice? _exerciceActif;
  String? _selectedCodeJournal;
  String? _selectedMoisId;
  int? _selectedMois;
  int? _selectedAnnee;
  bool _isCreating = false;

  bool get _exerciceCloture => _exerciceActif?.isCloture ?? false;
  bool get _canSaisir =>
      !_exerciceCloture &&
      (widget.userSession == null
          ? true
          : widget.userSession!.canCreate('saisie_comptable'));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final exerciceActif = await AuthService.getExerciceActif();
      final journaux = await AuthService.getJournaux();
      final mois = await _generateMoisList(exerciceActif);

      setState(() {
        _journaux = journaux;
        _moisDisponibles = mois;
        _exerciceActif = exerciceActif;
        _isLoading = false;

        if (_selectedCodeJournal == null ||
            !_journaux.any((j) => j.code == _selectedCodeJournal)) {
          _selectedCodeJournal =
              _journaux.isNotEmpty ? _journaux.first.code : null;
        }

        if (_moisDisponibles.isNotEmpty) {
          final currentSelection = _moisDisponibles.firstWhere(
            (item) => item.id == _selectedMoisId,
            orElse: () => _moisDisponibles.first,
          );
          _selectedMoisId = currentSelection.id;
          _selectedMois = currentSelection.mois;
          _selectedAnnee = currentSelection.annee;
        } else {
          _selectedMoisId = null;
          _selectedMois = null;
          _selectedAnnee = null;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<List<MoisData>> _generateMoisList(Exercice? exerciceActif) async {
    try {
      if (exerciceActif == null) {
        return [];
      }

      final moisList = <MoisData>[];
      DateTime current = exerciceActif.dateDebut;

      while (current.isBefore(exerciceActif.dateFin) ||
          (current.year == exerciceActif.dateFin.year &&
              current.month == exerciceActif.dateFin.month)) {
        final label = '${_monthNames[current.month - 1]} ${current.year}';
        final id = '${current.year}-${current.month}';
        moisList.add((
          label: label,
          mois: current.month,
          annee: current.year,
          id: id,
        ));

        current = DateTime(current.year, current.month + 1, 1);
      }

      return moisList;
    } catch (e) {
      debugPrint('Erreur génération mois: $e');
      return [];
    }
  }

  InputDecoration _buildDropdownDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  String? get _selectedJournalValue {
    final selectedCode = _selectedCodeJournal;
    return _journaux.any((journal) => journal.code == selectedCode)
        ? selectedCode
        : null;
  }

  String? get _selectedMoisValue {
    final selectedId = _selectedMoisId;
    return _moisDisponibles.any((item) => item.id == selectedId)
        ? selectedId
        : null;
  }

  Future<void> _handleCreateSaisie() async {
    if (_exerciceCloture) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Exercice clôturé : la saisie est désactivée.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (!_canSaisir) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Permission insuffisante pour accéder à la saisie.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final codeJournal = _selectedCodeJournal;
    final mois = _selectedMois;
    final annee = _selectedAnnee;
    final exercice = _exerciceActif;
    final exerciceId = exercice?.id;

    if (codeJournal == null ||
        mois == null ||
        annee == null ||
        exerciceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sélectionnez un journal, une période et un exercice actif',
          ),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final periode = await SaisieComptableService.createJournalPeriode(
        codeJournal: codeJournal,
        annee: annee,
        mois: mois,
        exerciceId: exerciceId,
      );

      if (periode == null) {
        throw Exception('Impossible de préparer la période demandée');
      }

      if (!mounted) return;

      bool shouldReload = true;

      if (widget.onOpenPeriode != null) {
        shouldReload = await widget.onOpenPeriode!(periode);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SaisieEcriturePage(
              journalPeriode: periode,
              userSession: widget.userSession,
              exerciceCloture: _exerciceCloture,
            ),
          ),
        );
      }

      if (shouldReload && mounted) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_exerciceCloture)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Exercice clôturé — consultation uniquement, la saisie est désactivée.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: _buildHeroCard(),
                  ),
                ),
              ],
            ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saisie comptable'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.indigo.shade900,
          elevation: 1,
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildHeroCard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.indigo.shade50),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.fact_check,
                      size: 28,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Créer une nouvelle saisie',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Sélectionnez le journal et la période ci-dessous pour démarrer immédiatement la saisie comptable.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedJournalValue,
                decoration: _buildDropdownDecoration('Journal'),
                isExpanded: true,
                hint: const Text('Sélectionnez un journal'),
                items:
                    _journaux.map((journal) {
                      return DropdownMenuItem(
                        value: journal.code,
                        child: Text('${journal.code} - ${journal.intitule}'),
                      );
                    }).toList(),
                onChanged:
                    _journaux.isEmpty
                        ? null
                        : (value) =>
                            setState(() => _selectedCodeJournal = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedMoisValue,
                decoration: _buildDropdownDecoration('Mois de saisie'),
                isExpanded: true,
                menuMaxHeight: 320,
                hint: const Text('Sélectionnez un mois'),
                items:
                    _moisDisponibles.map((item) {
                      return DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      );
                    }).toList(),
                onChanged:
                    _moisDisponibles.isEmpty
                        ? null
                        : (value) {
                          if (value == null) return;
                          final selectedItem = _moisDisponibles.firstWhere(
                            (item) => item.id == value,
                            orElse: () => _moisDisponibles.first,
                          );
                          setState(() {
                            _selectedMoisId = selectedItem.id;
                            _selectedMois = selectedItem.mois;
                            _selectedAnnee = selectedItem.annee;
                          });
                        },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed:
                      _isCreating ||
                              _selectedCodeJournal == null ||
                              _selectedMois == null ||
                              _selectedAnnee == null
                          ? null
                          : _handleCreateSaisie,
                  icon:
                      _isCreating
                          ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(Icons.play_arrow),
                  label: Text(
                    _isCreating ? 'Ouverture...' : 'Démarrer la saisie',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
