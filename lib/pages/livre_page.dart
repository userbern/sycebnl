import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercice.dart';
import '../models/bailleur.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/local_repository.dart';
import '../widgets/download_button.dart';

enum _CompteFilterMode { all, single, range }

enum _LivreType { general, tiers, analytique, tiersAnalytique }

/// Résultat de la sélection de bailleurs dans l'assistant du filtre analytique.
class _BailleursChoice {
  final bool tous;
  final List<int> ids;
  const _BailleursChoice(this.tous, this.ids);
}

class LivreScreen extends StatefulWidget {
  final bool showAppBar;

  const LivreScreen({super.key, this.showAppBar = true});

  @override
  State<LivreScreen> createState() => _LivreScreenState();
}

class _LivreScreenState extends State<LivreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  final _compteDebutController = TextEditingController();
  final _compteFinController = TextEditingController();
  final _compteUniqueController = TextEditingController();

  _CompteFilterMode _compteMode = _CompteFilterMode.all;

  bool _isLoading = true;
  String? _errorMessage;

  Exercice? _exercice;
  List<Bailleur> _bailleurs = [];
  bool _isLoadingBailleurs = false;
  String? _bailleursError;

  DateTime? _dateDebut;
  DateTime? _dateFin;
  _LivreType _type = _LivreType.general;

  // Filtre analytique (mêmes filtres que Balance) : type de ventilation puis,
  // si "Projet" ou "Fonctionnement + Projet", bailleur(s) et type de projet.
  String?
  _typeVentilation; // 'fonctionnement' | 'projet' | 'fonctionnement_projet'
  String?
  _typeProjetVentilation; // 'activite' | 'administration' | 'activite_administration'
  List<int> _bailleursSelectionnes = [];
  bool _tousLesBailleurs = false;

  bool get _isAnalytique =>
      _type == _LivreType.analytique || _type == _LivreType.tiersAnalytique;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _compteDebutController.dispose();
    _compteFinController.dispose();
    _compteUniqueController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      const db = LocalRepository();
      final exerciceRows = await db.query(
        'exercice',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'date_debut DESC',
        limit: 1,
      );

      final exercice =
          exerciceRows.isNotEmpty ? Exercice.fromMap(exerciceRows.first) : null;
      if (exercice == null) {
        throw Exception('Aucun exercice actif trouve');
      }

      if (!mounted) return;
      setState(() {
        _exercice = exercice;
        _dateDebut = exercice.dateDebut;
        _dateFin = exercice.dateFin;
        _dateDebutController.text = _formatDate(exercice.dateDebut);
        _dateFinController.text = _formatDate(exercice.dateFin);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBailleurs() async {
    setState(() {
      _isLoadingBailleurs = true;
      _bailleursError = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }
      final bailleurs = await AuthService.getBailleurs();
      if (!mounted) return;
      setState(() {
        _bailleurs = bailleurs;
        _isLoadingBailleurs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBailleurs = false;
        _bailleursError = e.toString();
      });
    }
  }

  void _resetFiltreAnalytique() {
    _typeVentilation = null;
    _typeProjetVentilation = null;
    _bailleursSelectionnes = [];
    _tousLesBailleurs = false;
  }

  /// Lance l'assistant en cascade : type de ventilation, puis (si Projet ou
  /// Fonctionnement + Projet) bailleur(s) et type de projet. `previousType`
  /// permet de revenir en arrière si l'utilisateur annule une étape.
  Future<void> _startAnalytiqueWizard(_LivreType previousType) async {
    final ventilationChoice = await _askTypeVentilation();
    if (!mounted) return;
    if (ventilationChoice == null) {
      setState(() => _type = previousType);
      return;
    }

    setState(() {
      _typeVentilation = ventilationChoice;
      _typeProjetVentilation = null;
      _bailleursSelectionnes = [];
      _tousLesBailleurs = false;
    });

    if (ventilationChoice == 'fonctionnement') return;

    if (_bailleurs.isEmpty && !_isLoadingBailleurs) {
      await _loadBailleurs();
      if (!mounted) return;
    }

    final bailleursChoice = await _askBailleurs();
    if (!mounted) return;
    if (bailleursChoice == null) {
      setState(() {
        _type = previousType;
        _typeVentilation = null;
      });
      return;
    }
    setState(() {
      _tousLesBailleurs = bailleursChoice.tous;
      _bailleursSelectionnes = bailleursChoice.ids;
    });

    final typeProjetChoice = await _askTypeProjet();
    if (!mounted) return;
    if (typeProjetChoice == null) {
      setState(() {
        _type = previousType;
        _typeVentilation = null;
        _bailleursSelectionnes = [];
        _tousLesBailleurs = false;
      });
      return;
    }
    setState(() => _typeProjetVentilation = typeProjetChoice);
  }

  Future<String?> _askTypeVentilation() {
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Type de ventilation à consulter'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'fonctionnement'),
                child: const ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Fonctionnement'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'projet'),
                child: const ListTile(
                  leading: Icon(Icons.business_center),
                  title: Text('Projet'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'fonctionnement_projet'),
                child: const ListTile(
                  leading: Icon(Icons.merge_type),
                  title: Text('Fonctionnement + Projet'),
                ),
              ),
            ],
          ),
    );
  }

  Future<_BailleursChoice?> _askBailleurs() {
    var tous = _tousLesBailleurs;
    var selected = List<int>.from(_bailleursSelectionnes);
    return showDialog<_BailleursChoice>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Sélection des bailleurs'),
                  content: SizedBox(
                    width: 420,
                    child:
                        _isLoadingBailleurs
                            ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                            : _bailleurs.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Aucun bailleur disponible'),
                            )
                            : SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CheckboxListTile(
                                    title: const Text(
                                      'Tous les bailleurs',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    value: tous,
                                    activeColor: Colors.blue,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        tous = value ?? false;
                                        selected =
                                            tous
                                                ? _bailleurs
                                                    .map((b) => b.id!)
                                                    .toList()
                                                : <int>[];
                                      });
                                    },
                                  ),
                                  const Divider(height: 8),
                                  ..._bailleurs.map(
                                    (bailleur) => CheckboxListTile(
                                      title: Text(
                                        '${bailleur.sigle} - ${bailleur.designation}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      value: selected.contains(bailleur.id),
                                      activeColor: Colors.blue,
                                      dense: true,
                                      onChanged:
                                          tous
                                              ? null
                                              : (value) {
                                                setDialogState(() {
                                                  if (value == true) {
                                                    selected.add(
                                                      bailleur.id!,
                                                    );
                                                  } else {
                                                    selected.remove(
                                                      bailleur.id,
                                                    );
                                                  }
                                                });
                                              },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          (tous || selected.isNotEmpty)
                              ? () => Navigator.pop(
                                ctx,
                                _BailleursChoice(tous, selected),
                              )
                              : null,
                      child: const Text('Continuer'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<String?> _askTypeProjet() {
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Type de projet'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'activite'),
                child: const ListTile(
                  leading: Icon(Icons.task_alt),
                  title: Text('Activité'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'administration'),
                child: const ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Administration'),
                ),
              ),
              SimpleDialogOption(
                onPressed:
                    () => Navigator.pop(ctx, 'activite_administration'),
                child: const ListTile(
                  leading: Icon(Icons.merge_type),
                  title: Text('Activité + Administration'),
                ),
              ),
            ],
          ),
    );
  }

  String _labelTypeVentilation(String value) {
    switch (value) {
      case 'fonctionnement':
        return 'Fonctionnement';
      case 'projet':
        return 'Projet';
      case 'fonctionnement_projet':
        return 'Fonctionnement + Projet';
      default:
        return '';
    }
  }

  String _labelTypeProjet(String value) {
    switch (value) {
      case 'activite':
        return 'Activité';
      case 'administration':
        return 'Administration';
      case 'activite_administration':
        return 'Activité + Administration';
      default:
        return '';
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final exercice = _exercice;
    if (exercice == null) return;

    final current = isStart ? _dateDebut : _dateFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(current ?? exercice.dateDebut),
      firstDate: exercice.dateDebut,
      lastDate: exercice.dateFin,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _dateDebut = picked;
        _dateDebutController.text = _formatDate(picked);
        if (_dateFin != null && _dateFin!.isBefore(picked)) {
          _dateFin = picked;
          _dateFinController.text = _formatDate(picked);
        }
      } else {
        _dateFin = picked;
        _dateFinController.text = _formatDate(picked);
      }
    });
  }

  DateTime _clampDate(DateTime date) {
    final exercice = _exercice;
    if (exercice == null) return date;
    if (date.isBefore(exercice.dateDebut)) return exercice.dateDebut;
    if (date.isAfter(exercice.dateFin)) return exercice.dateFin;
    return date;
  }

  Future<void> _openResults() async {
    if (_exercice == null || _dateDebut == null || _dateFin == null) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;

    if (_dateDebut!.isAfter(_dateFin!)) {
      _showMessage('La date de debut doit etre avant la date de fin');
      return;
    }

    if (_isAnalytique && _typeVentilation == null) {
      _showMessage('Veuillez configurer le filtre analytique');
      return;
    }

    if (_isAnalytique && _typeVentilation != 'fonctionnement') {
      if (!_tousLesBailleurs && _bailleursSelectionnes.isEmpty) {
        _showMessage(
          'Veuillez sélectionner au moins un bailleur ou cocher "Tous les bailleurs"',
        );
        return;
      }
      if (_typeProjetVentilation == null) {
        _showMessage('Veuillez sélectionner le type de projet');
        return;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _LivreResultPage(
              criteria: _LivreCriteria(
                exercice: _exercice!,
                dateDebut: _dateDebut!,
                dateFin: _dateFin!,
                compteMode: _compteMode,
                compteDebut:
                    _compteMode == _CompteFilterMode.single
                        ? _compteUniqueController.text.trim()
                        : _compteDebutController.text.trim(),
                compteFin:
                    _compteMode == _CompteFilterMode.range
                        ? _compteFinController.text.trim()
                        : '',
                type: _type,
                typeVentilation: _typeVentilation,
                typeProjetVentilation: _typeProjetVentilation,
                bailleurIds: _bailleursSelectionnes,
                tousLesBailleurs: _tousLesBailleurs,
                bailleursLabel: _selectedBailleursLabel(),
              ),
            ),
      ),
    );
  }

  String _selectedBailleursLabel() {
    if (!_isAnalytique || _typeVentilation == 'fonctionnement') return '';
    if (_tousLesBailleurs) return 'Tous';
    return _bailleurs
        .where((b) => b.id != null && _bailleursSelectionnes.contains(b.id))
        .map((b) => b.sigle)
        .join(', ');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _openResults();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book, size: 32, color: Colors.blue),
                          const SizedBox(width: 12),
                          const Text(
                            'Livre',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            _errorMessage != null
                                ? Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                )
                                : _buildFilters(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final exercice = _exercice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exercice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exercice actif : ${_formatDate(exercice.dateDebut)} → ${_formatDate(exercice.dateFin)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        _buildFormSection(
          title: '🔹 Type d\'état',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_LivreType>(
                      title: const Text('Général'),
                      value: _LivreType.general,
                      groupValue: _type,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged:
                          (value) => setState(() {
                            _type = value!;
                            _resetFiltreAnalytique();
                          }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_LivreType>(
                      title: const Text('Tiers'),
                      value: _LivreType.tiers,
                      groupValue: _type,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged:
                          (value) => setState(() {
                            _type = value!;
                            _resetFiltreAnalytique();
                          }),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_LivreType>(
                      title: const Text('Analytique'),
                      value: _LivreType.analytique,
                      groupValue: _type,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged: (value) {
                        final previous = _type;
                        setState(() => _type = value!);
                        _startAnalytiqueWizard(previous);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_LivreType>(
                      title: const Text('Tiers & Analytique'),
                      value: _LivreType.tiersAnalytique,
                      groupValue: _type,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged: (value) {
                        final previous = _type;
                        setState(() => _type = value!);
                        _startAnalytiqueWizard(previous);
                      },
                    ),
                  ),
                ],
              ),
              if (_isAnalytique)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: _buildAnalytiqueSummary(),
                ),
            ],
          ),
        ),

        const Divider(height: 32, thickness: 1),

        _buildFormSection(
          title: '🔹 Période (OBLIGATOIRE)',
          child: Row(
            children: [
              Expanded(
                child: _dateField('Date début *', _dateDebutController, true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _dateField('Date fin *', _dateFinController, false),
              ),
            ],
          ),
        ),

        const Divider(height: 32, thickness: 1),

        _buildFormSection(
          title: '🔹 Comptes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_CompteFilterMode>(
                      title: const Text('Tous les comptes'),
                      value: _CompteFilterMode.all,
                      groupValue: _compteMode,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged: (v) => setState(() => _compteMode = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_CompteFilterMode>(
                      title: const Text('Compte spécifique'),
                      value: _CompteFilterMode.single,
                      groupValue: _compteMode,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged: (v) => setState(() => _compteMode = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_CompteFilterMode>(
                      title: const Text('Plage de comptes'),
                      value: _CompteFilterMode.range,
                      groupValue: _compteMode,
                      activeColor: Colors.blue,
                      dense: true,
                      onChanged: (v) => setState(() => _compteMode = v!),
                    ),
                  ),
                ],
              ),
              if (_compteMode == _CompteFilterMode.single) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _compteUniqueController,
                  decoration: InputDecoration(
                    labelText: 'N° compte',
                    hintText: 'Ex: 401000',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (_) =>
                          _compteMode == _CompteFilterMode.single &&
                                  _compteUniqueController.text.trim().isEmpty
                              ? 'Obligatoire'
                              : null,
                ),
              ],
              if (_compteMode == _CompteFilterMode.range) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _compteDebutController,
                        decoration: InputDecoration(
                          labelText: 'N° compte début',
                          hintText: 'Ex: 401',
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _compteFinController,
                        decoration: InputDecoration(
                          labelText: 'N° compte fin',
                          hintText: 'Ex: 499',
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _openResults,
            icon: Icon(Icons.book, size: 22, color: Colors.white),
            label: Text(
              'Afficher le livre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalytiqueSummary() {
    if (_typeVentilation == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _startAnalytiqueWizard(_type),
          icon: const Icon(Icons.tune),
          label: const Text('Configurer le filtre analytique'),
        ),
      );
    }

    final lines = <String>[
      'Ventilation : ${_labelTypeVentilation(_typeVentilation!)}',
    ];
    if (_typeVentilation != 'fonctionnement') {
      lines.add(
        _tousLesBailleurs
            ? 'Bailleurs : Tous'
            : 'Bailleurs : ${_bailleursSelectionnes.length} sélectionné(s)',
      );
      if (_typeProjetVentilation != null) {
        lines.add(
          'Type de projet : ${_labelTypeProjet(_typeProjetVentilation!)}',
        );
      }
    }
    if (_bailleursError != null) {
      lines.add(_bailleursError!);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  lines
                      .map(
                        (l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(l, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
            ),
          ),
          TextButton(
            onPressed: () => _startAnalytiqueWizard(_type),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller,
    bool isStart,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'jj/mm/aaaa',
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed:
              () => setState(() {
                controller.clear();
                if (isStart) {
                  _dateDebut = null;
                } else {
                  _dateFin = null;
                }
              }),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
      ),
      onTap: () => _selectDate(isStart: isStart),
      validator:
          (value) => value == null || value.isEmpty ? 'Obligatoire' : null,
    );
  }

  Widget _buildFormSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LivreResultPage extends StatefulWidget {
  final _LivreCriteria criteria;

  const _LivreResultPage({required this.criteria});

  @override
  State<_LivreResultPage> createState() => _LivreResultPageState();
}

class _LivreResultPageState extends State<_LivreResultPage> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  Map<String, dynamic>? _entite;
  List<_CompteGroup> _groups = [];

  _LivreCriteria get _criteria => widget.criteria;

  bool get _isAnalytique =>
      _criteria.type == _LivreType.analytique ||
      _criteria.type == _LivreType.tiersAnalytique;

  bool get _isTiers =>
      _criteria.type == _LivreType.tiers ||
      _criteria.type == _LivreType.tiersAnalytique;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de donnees non connectee');
      }

      const db = LocalRepository();
      final entiteRows = await db.query('entite', limit: 1);
      final rows = await db.rawQuery(_movementSql(), _movementArgs());
      final entries = rows.map(_LivreRow.fromMap).toList();
      final groups = await _buildGroups(entries);

      if (!mounted) return;
      setState(() {
        _entite = entiteRows.isNotEmpty ? entiteRows.first : null;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<_CompteGroup>> _buildGroups(List<_LivreRow> rows) async {
    final grouped = <String, _CompteGroup>{};
    for (final row in rows) {
      final key =
          _isTiers ? (row.numeroTiers ?? row.numeroCompte) : row.numeroCompte;
      final intitule =
          _isTiers
              ? (row.tiersIntitule.isNotEmpty ? row.tiersIntitule : key)
              : row.compteIntitule;
      final group = grouped.putIfAbsent(
        key,
        () => _CompteGroup(numeroCompte: key, intitule: intitule),
      );
      group.addRow(row);
    }

    for (final group in grouped.values) {
      group.openingBalance = await _openingBalance(group.numeroCompte);
      group.recomputeRunningBalance();
    }

    return grouped.values.toList()
      ..sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));
  }

  Future<double> _openingBalance(String accountOrTiers) async {
    if (_isTiers) return 0;

    final first = accountOrTiers.isEmpty ? '' : accountOrTiers[0];
    if (!['1', '2', '3', '4', '5'].contains(first)) return 0;

    final args = <dynamic>[
      _formatSqlDate(_criteria.exercice.dateDebut),
      _formatSqlDate(_criteria.dateDebut.subtract(const Duration(days: 1))),
      accountOrTiers,
    ];
    final where = StringBuffer('''
      date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)))
        BETWEEN date(?) AND date(?)
      AND e.numero_compte = ?
    ''');

    _appendAnalyticWhere(where, args);
    final rows = await const LocalRepository().rawQuery('''
      SELECT COALESCE(SUM(e.montant_debit), 0) AS debit,
             COALESCE(SUM(e.montant_credit), 0) AS credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      ${_isAnalytique ? 'JOIN ventilations_analytiques va ON va.ecriture_id = e.id AND va.deleted_at IS NULL' : ''}
      WHERE $where
    ''', args);

    final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    return ((row['debit'] as num?)?.toDouble() ?? 0) -
        ((row['credit'] as num?)?.toDouble() ?? 0);
  }

  String _movementSql() {
    final where = StringBuffer('''
      date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)))
        BETWEEN date(?) AND date(?)
    ''');
    final args = _movementArgs();
    _appendAccountWhere(where, args, mutate: false);
    _appendAnalyticWhere(where, args, mutate: false);

    return '''
      SELECT
        e.id,
        e.numero_compte,
        e.numero_tiers,
        COALESCE(c.intitule, '') AS compte_intitule,
        COALESCE(t.intitule, '') AS tiers_intitule,
        jp.code_journal,
        e.numero_document,
        e.reference,
        e.libelle,
        COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)) AS date_comptable,
        e.jour,
        e.numero_enregistrement,
        e.montant_debit,
        e.montant_credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      LEFT JOIN compte c ON c.numero_compte = e.numero_compte
      LEFT JOIN tiers t ON t.numero_compte = e.numero_tiers
      ${_isAnalytique ? 'JOIN ventilations_analytiques va ON va.ecriture_id = e.id AND va.deleted_at IS NULL' : ''}
      WHERE $where
      ${_isTiers ? "AND e.numero_tiers IS NOT NULL AND TRIM(e.numero_tiers) <> ''" : ''}
      ORDER BY ${_isTiers ? 'e.numero_tiers' : 'e.numero_compte'} ASC,
        date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour))) ASC,
        jp.code_journal ASC,
        e.numero_enregistrement ASC,
        e.id ASC
    ''';
  }

  List<dynamic> _movementArgs() {
    final args = <dynamic>[
      _formatSqlDate(_criteria.dateDebut),
      _formatSqlDate(_criteria.dateFin),
    ];
    final where = StringBuffer();
    _appendAccountWhere(where, args);
    _appendAnalyticWhere(where, args);
    return args;
  }

  void _appendAccountWhere(
    StringBuffer where,
    List<dynamic> args, {
    bool mutate = true,
  }) {
    if (_criteria.compteMode == _CompteFilterMode.single &&
        _criteria.compteDebut.isNotEmpty) {
      where.write(' AND e.numero_compte = ?');
      if (mutate) args.add(_criteria.compteDebut);
    } else if (_criteria.compteMode == _CompteFilterMode.range) {
      if (_criteria.compteDebut.isNotEmpty) {
        where.write(' AND e.numero_compte >= ?');
        if (mutate) args.add(_criteria.compteDebut);
      }
      if (_criteria.compteFin.isNotEmpty) {
        where.write(' AND e.numero_compte <= ?');
        if (mutate) args.add(_criteria.compteFin);
      }
    }
  }

  // Filtre analytique : type de ventilation (Fonctionnement / Projet /
  // Fonctionnement + Projet), bailleur(s) et Activité/Administration —
  // reprend exactement la logique du filtre analytique de la Balance.
  void _appendAnalyticWhere(
    StringBuffer where,
    List<dynamic> args, {
    bool mutate = true,
  }) {
    if (!_isAnalytique) return;

    String projetCondition() {
      final buffer = StringBuffer("va.type = 'projet'");
      if (!_criteria.tousLesBailleurs && _criteria.bailleurIds.isNotEmpty) {
        final placeholders = _criteria.bailleurIds.map((_) => '?').join(', ');
        buffer.write(' AND va.id_bailleur IN ($placeholders)');
      }
      switch (_criteria.typeProjetVentilation) {
        case 'activite':
          buffer.write(" AND LOWER(va.volet) LIKE 'activit%'");
          break;
        case 'administration':
          buffer.write(" AND LOWER(va.volet) LIKE 'admin%'");
          break;
      }
      return buffer.toString();
    }

    void addBailleursArgsIfNeeded() {
      if (!_criteria.tousLesBailleurs && _criteria.bailleurIds.isNotEmpty) {
        if (mutate) args.addAll(_criteria.bailleurIds);
      }
    }

    switch (_criteria.typeVentilation) {
      case 'fonctionnement':
        where.write(" AND va.type = 'fonctionnement'");
        break;
      case 'projet':
        where.write(' AND (${projetCondition()})');
        addBailleursArgsIfNeeded();
        break;
      case 'fonctionnement_projet':
        where.write(
          " AND (va.type = 'fonctionnement' OR (${projetCondition()}))",
        );
        addBailleursArgsIfNeeded();
        break;
    }
  }

  Future<void> _exportPdf() async {
    await _export(() async {
      await ExportService.exportGrandLivrePDF(
        entite: _entite,
        dateDebut: _criteria.dateDebut,
        dateFin: _criteria.dateFin,
        typeLabel: _typeLabel(_criteria.type),
        projetLabel: _ventilationLabel(),
        bailleursLabel:
            _isAnalytique && _criteria.typeVentilation != 'fonctionnement'
                ? _criteria.bailleursLabel
                : '',
        groups: _groups.map((g) => g.toExportMap()).toList(),
        context: context,
      );
    });
  }

  Future<void> _exportExcel() async {
    await _export(() async {
      await ExportService.exportGrandLivreExcel(
        entite: _entite,
        dateDebut: _criteria.dateDebut,
        dateFin: _criteria.dateFin,
        typeLabel: _typeLabel(_criteria.type),
        projetLabel: _ventilationLabel(),
        bailleursLabel:
            _isAnalytique && _criteria.typeVentilation != 'fonctionnement'
                ? _criteria.bailleursLabel
                : '',
        groups: _groups.map((g) => g.toExportMap()).toList(),
        context: context,
      );
    });
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_groups.isEmpty) {
      _showMessage('Aucun resultat a exporter');
      return;
    }
    setState(() => _isExporting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatSqlDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatAmount(double value) {
    if (value.abs() < 0.005) return '';
    final sign = value < 0 ? '-' : '';
    final raw = value.abs().toStringAsFixed(0);
    return '$sign${raw.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}';
  }

  String _typeLabel(_LivreType type) {
    switch (type) {
      case _LivreType.general:
        return 'GENERAL';
      case _LivreType.tiers:
        return 'TIERS';
      case _LivreType.analytique:
        return 'ANALYTIQUE';
      case _LivreType.tiersAnalytique:
        return 'TIERS & ANALYTIQUE';
    }
  }

  String _ventilationLabel() {
    if (!_isAnalytique) return '';
    final base = switch (_criteria.typeVentilation) {
      'fonctionnement' => 'Fonctionnement',
      'projet' => 'Projet',
      'fonctionnement_projet' => 'Fonctionnement + Projet',
      _ => '',
    };
    if (_criteria.typeVentilation == 'fonctionnement') return base;
    final typeProjetLabel = switch (_criteria.typeProjetVentilation) {
      'activite' => 'Activité',
      'administration' => 'Administration',
      'activite_administration' => 'Activité + Administration',
      _ => null,
    };
    return typeProjetLabel != null ? '$base ($typeProjetLabel)' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Livre ${_typeLabel(_criteria.type)}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            label: const Text('Retour', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          DownloadTooltip.pdf(
            child: TextButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: const DownloadIcon(
                Icons.picture_as_pdf,
                color: Colors.white,
              ),
              label: const Text('PDF', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: kDownloadPdfColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          DownloadTooltip.excel(
            child: TextButton.icon(
              onPressed: _isExporting ? null : _exportExcel,
              icon: const DownloadIcon(
                Icons.table_view,
                color: Colors.white,
              ),
              label: const Text('Excel', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: kDownloadExcelColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child:
            _errorMessage != null
                ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Text(
                        'LIVRE ${_typeLabel(_criteria.type)}',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentHeader(),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_groups.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucune ecriture ne correspond aux filtres.',
                          ),
                        ),
                      )
                    else
                      Column(
                        children:
                            _groups.map((g) => _buildAccountTable(g)).toList(),
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final denSociale = _entite?['denomination_sociale']?.toString() ?? '-';
    final nif = _entite?['numero_fiscal']?.toString() ?? '-';
    final adresse = [
      _entite?['ville'],
      _entite?['quartier'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');
    final periode =
        '${_formatDate(_criteria.dateDebut)} - ${_formatDate(_criteria.dateFin)}';
    final type = _typeLabel(_criteria.type);
    final showBailleur =
        _isAnalytique && _criteria.typeVentilation != 'fonctionnement';

    return Table(
      border: TableBorder.all(color: Colors.black54, width: 0.7),
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(0.7),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.6),
        6: FlexColumnWidth(0.8),
        7: FlexColumnWidth(1.6),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Colors.white),
          children: [
            _headerCell('Dénomination sociale', bold: true),
            _headerCell(denSociale),
            _headerCell('NIF', bold: true),
            _headerCell(nif),
            _headerCell('Adresse', bold: true),
            _headerCell(adresse),
            _headerCell('Période', bold: true),
            _headerCell(periode),
          ],
        ),
        TableRow(
          decoration: const BoxDecoration(color: Colors.white),
          children: [
            _headerCell('LIVRE', bold: true),
            _headerCell(type),
            _headerCell(''),
            _headerCell('TYPE', bold: true),
            _headerCell(type),
            _headerCell(
              _isAnalytique ? 'VENTILATION : ${_ventilationLabel()}' : '',
            ),
            _headerCell(showBailleur ? 'BAILLEUR' : '', bold: showBailleur),
            _headerCell(showBailleur ? _criteria.bailleursLabel : ''),
          ],
        ),
      ],
    );
  }

  Widget _headerCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAccountTable(_CompteGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: Colors.blue,
          child: Text(
            'Compte ${group.numeroCompte} - ${group.intitule}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(color: Colors.black, width: 0.8),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(.9),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(3.2),
            4: FlexColumnWidth(1.2),
            5: FlexColumnWidth(1.2),
            6: FlexColumnWidth(1.3),
          },
          children: [
            _tableRow(
              [
                'Date',
                'Journal',
                'N enregis.',
                'Libelle',
                'Debit',
                'Credit',
                'Solde',
              ],
              color: const Color(0xFFD8E7F1),
              bold: true,
            ),
            if (group.hasOpeningBalance)
              _tableRow(
                [
                  '',
                  '',
                  '',
                  'Solde d\'ouverture',
                  '',
                  '',
                  _formatAmount(group.openingBalance),
                ],
                color: const Color(0xFFEEF6FB),
                bold: true,
              ),
            ...group.rows.map(
              (row) => _tableRow([
                row.dateComptable == null
                    ? '-'
                    : _formatDate(row.dateComptable!),
                row.codeJournal,
                row.numeroEnregistrement.toString().padLeft(3, '0'),
                row.libelle,
                _formatAmount(row.debit),
                _formatAmount(row.credit),
                _formatAmount(row.runningBalance),
              ]),
            ),
            _tableRow(
              [
                '',
                '',
                '',
                'TOTAL COMPTE ${group.numeroCompte}',
                _formatAmount(group.totalDebit),
                _formatAmount(group.totalCredit),
                _formatAmount(group.finalBalance),
              ],
              color: const Color(0xFFD8E7F1),
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  TableRow _tableRow(List<String> values, {Color? color, bool bold = false}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.white),
      children:
          values
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _LivreCriteria {
  final Exercice exercice;
  final DateTime dateDebut;
  final DateTime dateFin;
  final _CompteFilterMode compteMode;
  final String compteDebut;
  final String compteFin;
  final _LivreType type;
  final String? typeVentilation;
  final String? typeProjetVentilation;
  final List<int> bailleurIds;
  final bool tousLesBailleurs;
  final String bailleursLabel;

  const _LivreCriteria({
    required this.exercice,
    required this.dateDebut,
    required this.dateFin,
    required this.compteMode,
    required this.compteDebut,
    required this.compteFin,
    required this.type,
    required this.typeVentilation,
    required this.typeProjetVentilation,
    required this.bailleurIds,
    required this.tousLesBailleurs,
    required this.bailleursLabel,
  });
}

class _LivreRow {
  final int id;
  final String numeroCompte;
  final String? numeroTiers;
  final String compteIntitule;
  final String tiersIntitule;
  final String codeJournal;
  final String numeroDocument;
  final String libelle;
  final DateTime? dateComptable;
  final int numeroEnregistrement;
  final double debit;
  final double credit;
  double runningBalance = 0;

  _LivreRow({
    required this.id,
    required this.numeroCompte,
    required this.numeroTiers,
    required this.compteIntitule,
    required this.tiersIntitule,
    required this.codeJournal,
    required this.numeroDocument,
    required this.libelle,
    required this.dateComptable,
    required this.numeroEnregistrement,
    required this.debit,
    required this.credit,
  });

  factory _LivreRow.fromMap(Map<String, dynamic> map) {
    return _LivreRow(
      id: (map['id'] as num?)?.toInt() ?? 0,
      numeroCompte: map['numero_compte']?.toString() ?? '',
      numeroTiers: map['numero_tiers']?.toString(),
      compteIntitule: map['compte_intitule']?.toString() ?? '',
      tiersIntitule: map['tiers_intitule']?.toString() ?? '',
      codeJournal: map['code_journal']?.toString() ?? '',
      numeroDocument: map['numero_document']?.toString() ?? '',
      libelle: map['libelle']?.toString() ?? '',
      dateComptable: DateTime.tryParse(map['date_comptable']?.toString() ?? ''),
      numeroEnregistrement:
          (map['numero_enregistrement'] as num?)?.toInt() ?? 0,
      debit: (map['montant_debit'] as num?)?.toDouble() ?? 0,
      credit: (map['montant_credit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toExportMap() => {
    'date': dateComptable,
    'journal': codeJournal,
    'numero_enregistrement': numeroEnregistrement,
    'libelle': libelle,
    'debit': debit,
    'credit': credit,
    'solde': runningBalance,
  };
}

class _CompteGroup {
  final String numeroCompte;
  final String intitule;
  final List<_LivreRow> rows = [];
  double openingBalance = 0;
  double totalDebit = 0;
  double totalCredit = 0;

  _CompteGroup({required this.numeroCompte, required this.intitule});

  void addRow(_LivreRow row) {
    rows.add(row);
    totalDebit += row.debit;
    totalCredit += row.credit;
  }

  void recomputeRunningBalance() {
    var balance = openingBalance;
    for (final row in rows) {
      balance += row.debit - row.credit;
      row.runningBalance = balance;
    }
  }

  double get finalBalance => openingBalance + totalDebit - totalCredit;

  bool get hasOpeningBalance =>
      numeroCompte.isNotEmpty &&
      ['1', '2', '3', '4', '5'].contains(numeroCompte[0]);

  Map<String, dynamic> toExportMap() => {
    'numero': numeroCompte,
    'intitule': intitule,
    'opening_balance': openingBalance,
    'has_opening_balance': hasOpeningBalance,
    'total_debit': totalDebit,
    'total_credit': totalCredit,
    'final_balance': finalBalance,
    'rows': rows.map((r) => r.toExportMap()).toList(),
  };
}
