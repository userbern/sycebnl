import 'package:flutter/material.dart';
import '../models/exercice.dart';
import '../models/projet.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'balance_resultat_page.dart';

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
  int? _projetSelectionne;
  List<Projet> _projets = [];
  bool _isLoadingProjets = false;
  String? _projetsError;

  List<Map<String, dynamic>> _bailleurs = [];
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
  bool _inclureComptesSansMouvement = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadExercice();
    _loadProjets();
  }

  Future<void> _onProjetChanged(int? projetId) async {
    setState(() {
      _projetSelectionne = projetId;
      _bailleursSelectionnes.clear();
      _tousLesBailleurs = false;
      _bailleurs = []; // Replace with empty list instead of clearing
    });

    if (projetId != null) {
      await _loadBailleursForProjet(projetId);
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
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime(2100, 12, 31);
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
        } else {
          _dateFin = picked;
        }
        controller.text = _formatDate(picked);
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

      // Validation analytique : au moins un bailleur si projet sélectionné
      if ((_typeEtat == 'analytique' || _typeEtat == 'tiers_analytique') &&
          _projetSelectionne != null) {
        if (_bailleursSelectionnes.isEmpty) {
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
      }

      // Naviguer vers la page des résultats
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BalanceResultatPage(
                typeEtat: _typeEtat,
                projetId: _projetSelectionne,
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

  Future<void> _loadProjets() async {
    setState(() {
      _isLoadingProjets = true;
      _projetsError = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }
      final projets = await AuthService.getProjets();
      if (!mounted) return;
      setState(() {
        _projets = projets;
        _isLoadingProjets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProjets = false);
      _projetsError = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des projets: $e'),
          backgroundColor: Colors.red,
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
        final results = await DatabaseService.database.query(
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

  Future<void> _loadBailleursForProjet(int projetId) async {
    setState(() {
      _isLoadingBailleurs = true;
      _bailleursError = null;
    });
    try {
      if (!DatabaseService.isConnected) {
        throw Exception('Base de données non connectée');
      }
      final bailleurs = await AuthService.getBailleursForProjet(projetId);
      if (!mounted) return;
      setState(() {
        _bailleurs = List.from(bailleurs); // Convert to mutable list
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
                title: const Text('Balance Générale des Comptes'),
                backgroundColor: Colors.blue.shade700,
                elevation: 0,
              )
              : null,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800, // Largeur maximale réduite
            maxHeight: 850, // Hauteur maximale pour éviter le défilement
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
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Balance Générale des Comptes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
                                  const Icon(
                                    Icons.event_available,
                                    color: Colors.green,
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
                                        activeColor: Colors.blue.shade700,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                            _projetSelectionne = null;
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
                                        activeColor: Colors.blue.shade700,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                            _projetSelectionne = null;
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
                                        activeColor: Colors.blue.shade700,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                          });
                                        },
                                        dense: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Tiers & Analytique'),
                                        value: 'tiers_analytique',
                                        groupValue: _typeEtat,
                                        activeColor: Colors.blue.shade700,
                                        onChanged: (value) {
                                          setState(() {
                                            _typeEtat = value!;
                                          });
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
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_isLoadingProjets)
                                          const LinearProgressIndicator(),
                                        if (_projetsError != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              _projetsError!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        if (!_isLoadingProjets &&
                                            _projets.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'Aucun projet disponible',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        if (!_isLoadingProjets &&
                                            _projets.isNotEmpty)
                                          DropdownButtonFormField<int>(
                                            value: _projetSelectionne,
                                            isExpanded: true,
                                            menuMaxHeight: 320,
                                            decoration: InputDecoration(
                                              labelText: 'Projet',
                                              hintText:
                                                  'Sélectionnez un projet',
                                              prefixIcon: const Icon(
                                                Icons.business_center,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.blue.shade700,
                                                  width: 2,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                    horizontal: 16,
                                                  ),
                                            ),
                                            items:
                                                _projets
                                                    .map(
                                                      (p) => DropdownMenuItem<
                                                        int
                                                      >(
                                                        value: p.id,
                                                        child: Text(
                                                          '${p.code} - ${p.nom}',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) {
                                              _onProjetChanged(value);
                                            },
                                            validator: (value) {
                                              if ((_typeEtat == 'analytique' ||
                                                      _typeEtat ==
                                                          'tiers_analytique') &&
                                                  (value == null ||
                                                      _projets.isEmpty)) {
                                                return 'Veuillez sélectionner un projet';
                                              }
                                              return null;
                                            },
                                          ),

                                        // Section Bailleurs (si projet sélectionné)
                                        if (_projetSelectionne != null) ...[
                                          const SizedBox(height: 16),
                                          if (_isLoadingBailleurs)
                                            const LinearProgressIndicator(),
                                          if (_bailleursError != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              child: Text(
                                                _bailleursError!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          if (!_isLoadingBailleurs &&
                                              _bailleurs.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              child: Text(
                                                'Aucun bailleur associé à ce projet',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          if (!_isLoadingBailleurs &&
                                              _bailleurs.isNotEmpty) ...[
                                            const Text(
                                              'Bailleurs du projet :',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            CheckboxListTile(
                                              title: const Text(
                                                'Tous les bailleurs',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              value: _tousLesBailleurs,
                                              activeColor: Colors.blue.shade700,
                                              dense: true,
                                              onChanged: (value) {
                                                setState(() {
                                                  _tousLesBailleurs =
                                                      value ?? false;
                                                  if (_tousLesBailleurs) {
                                                    _bailleursSelectionnes =
                                                        _bailleurs
                                                            .map(
                                                              (b) =>
                                                                  b['id']
                                                                      as int,
                                                            )
                                                            .toList();
                                                  } else {
                                                    _bailleursSelectionnes
                                                        .clear();
                                                  }
                                                });
                                              },
                                            ),
                                            const Divider(height: 8),
                                            ..._bailleurs.map((bailleur) {
                                              final bailleurId =
                                                  bailleur['id'] as int;
                                              return CheckboxListTile(
                                                title: Text(
                                                  '${bailleur['sigle']} - ${bailleur['designation']}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                value: _bailleursSelectionnes
                                                    .contains(bailleurId),
                                                activeColor:
                                                    Colors.blue.shade700,
                                                dense: true,
                                                onChanged:
                                                    _tousLesBailleurs
                                                        ? null
                                                        : (value) {
                                                          setState(() {
                                                            if (value == true) {
                                                              _bailleursSelectionnes
                                                                  .add(
                                                                    bailleurId,
                                                                  );
                                                            } else {
                                                              _bailleursSelectionnes
                                                                  .remove(
                                                                    bailleurId,
                                                                  );
                                                            }
                                                          });
                                                        },
                                              );
                                            }).toList(),
                                          ],
                                        ],
                                      ],
                                    ),
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
                          Container(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _afficherBalance,
                              icon: const Icon(Icons.assessment, size: 22),
                              label: const Text(
                                'Afficher la balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
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
              color: Colors.blue.shade800,
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
