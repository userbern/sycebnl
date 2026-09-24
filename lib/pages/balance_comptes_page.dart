import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bailleur.dart';
import '../models/exercice.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/local_repository.dart';
import 'balance_resultat_page.dart';

/// Résultat de la sélection de bailleurs dans l'assistant du filtre analytique.
class _BailleursChoice {
  final bool tous;
  final List<int> ids;
  const _BailleursChoice(this.tous, this.ids);
}

class BalanceComptesPage extends StatefulWidget {
  final int? exerciceId;
  final bool showAppBar;

  const BalanceComptesPage({
    super.key,
    this.exerciceId,
    this.showAppBar = true,
  });

  @override
  State<BalanceComptesPage> createState() => _BalanceComptesPageState();
}

class _BalanceComptesPageState extends State<BalanceComptesPage> {
  // Bloc 1 - Type d'état
  String _typeEtat =
      'general'; // 'general', 'tiers', 'analytique', 'tiers_analytique'

  // Filtre analytique : type de ventilation puis, si "Projet" ou
  // "Fonctionnement + Projet", bailleur(s) et type de projet.
  String?
  _typeVentilation; // 'fonctionnement' | 'projet' | 'fonctionnement_projet'
  String?
  _typeProjetVentilation; // 'activite' | 'administration' | 'activite_administration'

  List<Bailleur> _bailleursDisponibles = [];
  bool _isLoadingBailleurs = false;
  String? _bailleursError;
  List<int> _bailleursSelectionnes = [];
  bool _tousLesBailleurs = false;

  Exercice? _exercice;
  bool _isLoadingExercice = false;
  String? _exerciceError;

  // Bloc 2 - Période
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();

  // Bloc 3 - Comptes
  final _compteDebutController = TextEditingController();
  final _compteFinController = TextEditingController();

  // Bloc 4 - Niveau de regroupement
  final _niveauController = TextEditingController();

  // Bloc 5 - Options
  final bool _inclureComptesSansMouvement = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadExercice();
  }

  void _resetFiltreAnalytique() {
    _typeVentilation = null;
    _typeProjetVentilation = null;
    _bailleursSelectionnes = [];
    _tousLesBailleurs = false;
  }

  /// Lance l'assistant en cascade : type de ventilation, puis (si Projet ou
  /// Fonctionnement + Projet) bailleur(s) et type de projet. `previousTypeEtat`
  /// permet de revenir en arrière si l'utilisateur annule une étape.
  Future<void> _startAnalytiqueWizard(String previousTypeEtat) async {
    final ventilationChoice = await _askTypeVentilation();
    if (!mounted) return;
    if (ventilationChoice == null) {
      setState(() => _typeEtat = previousTypeEtat);
      return;
    }

    setState(() {
      _typeVentilation = ventilationChoice;
      _typeProjetVentilation = null;
      _bailleursSelectionnes = [];
      _tousLesBailleurs = false;
    });

    if (ventilationChoice == 'fonctionnement') return;

    if (_bailleursDisponibles.isEmpty && !_isLoadingBailleurs) {
      await _loadBailleurs();
      if (!mounted) return;
    }

    final bailleursChoice = await _askBailleurs();
    if (!mounted) return;
    if (bailleursChoice == null) {
      setState(() {
        _typeEtat = previousTypeEtat;
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
        _typeEtat = previousTypeEtat;
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
                            : _bailleursDisponibles.isEmpty
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
                                                ? _bailleursDisponibles
                                                    .map((b) => b.id!)
                                                    .toList()
                                                : <int>[];
                                      });
                                    },
                                  ),
                                  const Divider(height: 8),
                                  ..._bailleursDisponibles.map(
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

  @override
  void dispose() {
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _compteDebutController.dispose();
    _compteFinController.dispose();
    _niveauController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
    bool isDebut,
  ) async {
    final exercice = _exercice;
    if (exercice == null) return;

    final DateTime firstDate = exercice.dateDebut;
    final DateTime lastDate = exercice.dateFin;
    final DateTime initialDate = _clampDate(
      isDebut ? _dateDebut : _dateFin,
      firstDate,
      lastDate,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
          controller.text = _formatDate(picked);
          if (_dateFin != null && _dateFin!.isBefore(picked)) {
            _dateFin = picked;
            _dateFinController.text = _formatDate(picked);
          }
        } else {
          _dateFin = picked;
          controller.text = _formatDate(picked);
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime _clampDate(DateTime? value, DateTime min, DateTime max) {
    final candidate = value ?? DateTime.now();
    if (candidate.isBefore(min)) return min;
    if (candidate.isAfter(max)) return max;
    return candidate;
  }

  void _afficherBalance() {
    if (_formKey.currentState!.validate()) {
      // Validation de l'exercice
      if (_exercice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun exercice actif trouvé'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validation supplémentaire des dates
      if (_dateDebut != null && _dateFin != null) {
        if (_dateDebut!.isAfter(_dateFin!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La date de début doit être antérieure ou égale à la date de fin',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Validation du filtre analytique
      if (_typeEtat == 'analytique' || _typeEtat == 'tiers_analytique') {
        if (_typeVentilation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez configurer le filtre analytique'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (_typeVentilation != 'fonctionnement') {
          if (!_tousLesBailleurs && _bailleursSelectionnes.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Veuillez sélectionner au moins un bailleur ou cocher "Tous les bailleurs"',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          if (_typeProjetVentilation == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez sélectionner le type de projet'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }

      // Naviguer vers la page des résultats
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BalanceResultatPage(
                typeEtat: _typeEtat,
                typeVentilationAnalytique: _typeVentilation,
                typeProjetVentilation: _typeProjetVentilation,
                bailleursSelectionnes:
                    _bailleursSelectionnes.isNotEmpty
                        ? _bailleursSelectionnes
                        : null,
                tousLesBailleurs: _tousLesBailleurs,
                dateDebut: _dateDebut!,
                dateFin: _dateFin!,
                exerciceId: widget.exerciceId,
                compteDebut:
                    _compteDebutController.text.isEmpty
                        ? null
                        : _compteDebutController.text,
                compteFin:
                    _compteFinController.text.isEmpty
                        ? null
                        : _compteFinController.text,
                inclureComptesSansMouvement: _inclureComptesSansMouvement,
                exercice: _exercice,
              ),
        ),
      );
    }
  }

  Future<void> _loadExercice() async {
    setState(() {
      _isLoadingExercice = true;
      _exerciceError = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }

      Exercice? exercice;
      if (widget.exerciceId != null) {
        final results = await const LocalRepository().query(
          'exercice',
          where: 'id = ?',
          whereArgs: [widget.exerciceId],
          limit: 1,
        );
        if (results.isNotEmpty) {
          exercice = Exercice.fromMap(results.first);
        }
      }

      exercice ??= await AuthService.getExerciceActif();

      if (!mounted) return;
      setState(() {
        _exercice = exercice;
        if (exercice != null) {
          _dateDebut = exercice.dateDebut;
          _dateFin = exercice.dateFin;
          _dateDebutController.text = _formatDate(exercice.dateDebut);
          _dateFinController.text = _formatDate(exercice.dateFin);
        }
        _isLoadingExercice = false;
      });

      if (exercice == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun exercice actif trouvé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingExercice = false;
        _exerciceError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement de l\'exercice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadBailleurs() async {
    setState(() {
      _isLoadingBailleurs = true;
      _bailleursError = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }
      final bailleurs = await AuthService.getBailleurs();
      if (!mounted) return;
      setState(() {
        _bailleursDisponibles = bailleurs;
        _isLoadingBailleurs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBailleurs = false;
        _bailleursError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des bailleurs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text('Balance Générale des Comptes', style: TextStyle(color: Colors.black)),
                backgroundColor: Colors.blue.shade700,
                elevation: 0,
              )
              : null,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _afficherBalance();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 850,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête
                  Container(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance,
                          size: 32,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Balance Générale des Comptes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Formulaire dans un container unique
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          if (_isLoadingExercice)
                            const LinearProgressIndicator()
                          else if (_exerciceError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _exerciceError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          else if (_exercice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Exercice actif : ${_formatDate(_exercice!.dateDebut)} → ${_formatDate(_exercice!.dateFin)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Bloc 1 - Type d'état
                          _buildFormSection(
                            title: '🔹 Type d\'état',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Général'),
                                        value: 'general',
                                        groupValue: _typeEtat,
                                        activeColor: Colors.blue,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                            _resetFiltreAnalytique();
                                          });
                                        },
                                        dense: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Tiers'),
                                        value: 'tiers',
                                        groupValue: _typeEtat,
                                        activeColor: Colors.blue,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                            _resetFiltreAnalytique();
                                          });
                                        },
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Analytique'),
                                        value: 'analytique',
                                        groupValue: _typeEtat,
                                        activeColor: Colors.blue,
                                        onChanged: (value) {
                                          final previous = _typeEtat;
                                          setState(() => _typeEtat = value!);
                                          _startAnalytiqueWizard(previous);
                                        },
                                        dense: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Tiers & Analytique'),
                                        value: 'tiers_analytique',
                                        groupValue: _typeEtat,
                                        activeColor: Colors.blue,
                                        onChanged: (value) {
                                          final previous = _typeEtat;
                                          setState(() => _typeEtat = value!);
                                          _startAnalytiqueWizard(previous);
                                        },
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_typeEtat == 'analytique' ||
                                    _typeEtat == 'tiers_analytique')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      left: 16,
                                      right: 16,
                                    ),
                                    child: _buildAnalytiqueSummary(),
                                  ),
                              ],
                            ),
                          ),

                          const Divider(height: 32, thickness: 1),

                          // Bloc 2 - Période (OBLIGATOIRE)
                          _buildFormSection(
                            title: '🔹 Période (OBLIGATOIRE)',
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateDebutController,
                                    decoration: InputDecoration(
                                      labelText: 'Date début *',
                                      hintText: 'jj/mm/aaaa',
                                      prefixIcon: const Icon(
                                        Icons.calendar_today,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _dateDebutController.clear();
                                            _dateDebut = null;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                    ),
                                    readOnly: true,
                                    onTap:
                                        () => _selectDate(
                                          context,
                                          _dateDebutController,
                                          true,
                                        ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Date de début requise';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateFinController,
                                    decoration: InputDecoration(
                                      labelText: 'Date fin *',
                                      hintText: 'jj/mm/aaaa',
                                      prefixIcon: const Icon(
                                        Icons.calendar_today,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _dateFinController.clear();
                                            _dateFin = null;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                    ),
                                    readOnly: true,
                                    onTap:
                                        () => _selectDate(
                                          context,
                                          _dateFinController,
                                          false,
                                        ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Date de fin requise';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 32, thickness: 1),

                          // Bloc 3 - Comptes
                          _buildFormSection(
                            title: '🔹 Comptes',
                            subtitle:
                                'Laisser vide pour inclure tous les comptes',
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _compteDebutController,
                                    decoration: InputDecoration(
                                      labelText: 'N° compte début',
                                      hintText: 'Ex: 401',
                                      prefixIcon: const Icon(
                                        Icons.account_balance_wallet,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                      prefixIcon: const Icon(
                                        Icons.account_balance_wallet,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bloc 4 - Niveau de regroupement
                          /*                           _buildFormSection(
                            title: '🔹 Niveau de regroupement',
                            subtitle:
                                'Indispensable pour les comptes du bilan, comptes de gestion et totaux (1 à 13)',
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: _niveauController,
                                    decoration: InputDecoration(
                                      labelText: 'Niveau',
                                      hintText: '1-13',
                                      prefixIcon: const Icon(Icons.layers),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final niveau = int.tryParse(value);
                                        if (niveau == null ||
                                            niveau < 1 ||
                                            niveau > 13) {
                                          return 'Entre 1 et 13';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
 */

                          // Bouton d'action
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _afficherBalance,
                              icon: Icon(Icons.assessment, size: 22, color: Colors.white),
                              label: const Text(
                                'Afficher la balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                      ),
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

  Widget _buildAnalytiqueSummary() {
    if (_typeVentilation == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _startAnalytiqueWizard(_typeEtat),
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
            onPressed: () => _startAnalytiqueWizard(_typeEtat),
            child: const Text('Modifier'),
          ),
        ],
      ),
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
