import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sycebnl_accounting/models/saisie_comptable.dart';
import 'package:sycebnl_accounting/models/compte.dart';
import 'package:sycebnl_accounting/models/tiers.dart';
import 'package:sycebnl_accounting/services/saisie_comptable_service.dart';
import 'package:sycebnl_accounting/services/database_service_new.dart';

class SaisieEcriturePage extends StatefulWidget {
  final JournalPeriode journalPeriode;

  const SaisieEcriturePage({super.key, required this.journalPeriode});

  @override
  State<SaisieEcriturePage> createState() => _SaisieEcriturePageState();
}

class _SaisieEcriturePageState extends State<SaisieEcriturePage> {
  // Données chargées
  List<LigneEcriture> _ecritures = [];
  List<Compte> _comptes = [];
  List<Tiers> _tiers = [];
  bool _isLoading = true;
  bool _requiresVentilation = false;

  // Formulaire
  late TextEditingController _jourController;
  late TextEditingController _numeroDocController;
  late TextEditingController _referenceController;
  late TextEditingController _libelleController;
  late TextEditingController _debitController;
  late TextEditingController _creditController;
  late TextEditingController _compteController;

  String? _selectedCompteNumero;
  String? _selectedTiersNumero;
  bool _showTiersField = false;
  List<Compte> _filteredComptes = [];
  List<Tiers> _filteredTiers = [];

  // Mode édition
  int? _editingIndex;
  LigneEcriture? _editingEcriture;

  // Gestion du numéro d'enregistrement courant
  int? _currentNumeroEnregistrement;
  bool _isCurrentEnregistrementBalanced = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    _jourController = TextEditingController();
    _numeroDocController = TextEditingController();
    _referenceController = TextEditingController();
    _libelleController = TextEditingController();
    _debitController = TextEditingController();
    _creditController = TextEditingController();
    _compteController = TextEditingController();

    // Écouter les changements pour filtrer les comptes
    _compteController.addListener(() {
      _filterComptes();
    });
  }

  void _filterComptes() {
    final query = _compteController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredComptes = _comptes;
        _showTiersField = false;
      } else {
        _filteredComptes =
            _comptes.where((compte) {
              return compte.numeroCompte.toLowerCase().contains(query) ||
                  compte.intitule.toLowerCase().contains(query);
            }).toList();

        // Autocomplétion: si une seule suggestion, la compléter automatiquement
        if (_filteredComptes.length == 1) {
          final compteExact = _filteredComptes.first;
          _compteController.text = compteExact.numeroCompte;
          _selectedCompteNumero = compteExact.numeroCompte;
          _showTiersField = compteExact.liaisonTiers;
        } else {
          // Vérifier si un compte exact correspond et a liaison_tiers = true
          try {
            final compteExact = _comptes.firstWhere(
              (c) => c.numeroCompte.toLowerCase() == query,
            );
            _showTiersField = compteExact.liaisonTiers;
          } catch (e) {
            _showTiersField = false;
          }
        }
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Charger les données
      final comptes = await DatabaseService.getAllComptes();
      final tiers = await DatabaseService.getAllTiers();
      final journal = await DatabaseService.getJournalByCode(
        widget.journalPeriode.codeJournal,
      );

      // Charger les écritures de toute l'année pour ce journal
      final ecritures =
          await SaisieComptableService.getEcrituresByJournalAndYear(
            widget.journalPeriode.codeJournal,
            widget.journalPeriode.annee,
            widget.journalPeriode.mois,
          );

      setState(() {
        _comptes = comptes;
        _filteredComptes = comptes;
        _tiers = tiers;
        _requiresVentilation = journal.saisieAnalytique;
        _ecritures = ecritures;
        _isLoading = false;

        // Initialiser le numéro d'enregistrement courant
        _initializeCurrentEnregistrement();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  TotauxSaisie get _totaux =>
      SaisieComptableService.calculateTotaux(_ecritures);

  int get _nombreEnregistrementsUniques {
    if (_ecritures.isEmpty) return 0;
    final numeroUniques = <int>{};
    for (final ecriture in _ecritures) {
      numeroUniques.add(ecriture.numeroEnregistrement);
    }
    return numeroUniques.length;
  }

  void _initializeCurrentEnregistrement() {
    if (_ecritures.isEmpty) {
      _currentNumeroEnregistrement = null;
      _isCurrentEnregistrementBalanced = true;
    } else {
      // Récupérer le dernier numéro d'enregistrement
      final lastNumero = _ecritures.last.numeroEnregistrement;
      final ecrituresWithLastNumero =
          _ecritures
              .where((e) => e.numeroEnregistrement == lastNumero)
              .toList();

      // Vérifier si équilibré
      final totaux = SaisieComptableService.calculateTotaux(
        ecrituresWithLastNumero,
      );
      _isCurrentEnregistrementBalanced =
          (totaux.totalDebit - totaux.totalCredit).abs() < 0.01;

      if (_isCurrentEnregistrementBalanced) {
        _currentNumeroEnregistrement = null;
      } else {
        _currentNumeroEnregistrement = lastNumero;
      }
    }
  }

  void _clearForm() {
    _jourController.clear();
    _numeroDocController.clear();
    _referenceController.clear();
    _libelleController.clear();
    _debitController.clear();
    _creditController.clear();
    _compteController.clear();
    _selectedCompteNumero = null;
    _selectedTiersNumero = null;
    _showTiersField = false;
    _editingIndex = null;
    _editingEcriture = null;
  }

  void _clearAmountsOnly() {
    // Vider seulement les montants si l'enregistrement n'est pas équilibré
    _debitController.clear();
    _creditController.clear();
  }

  void _onCompteSelected(String numeroCompte) {
    setState(() {
      _selectedCompteNumero = numeroCompte;
      _compteController.text = numeroCompte;
      _selectedTiersNumero = null;

      // Vérifier si le compte a liaison_tiers = true dans le plan comptable
      final compte = _comptes.firstWhere(
        (c) => c.numeroCompte == numeroCompte,
        orElse: () => _comptes.first,
      );
      // Dégrise le champ Tiers si liaison_tiers est true (accepte 1 ou true)
      _showTiersField = compte.liaisonTiers;

      // Filtrer les tiers associés à ce compte
      if (_showTiersField) {
        _filteredTiers =
            _tiers
                .where((tier) => tier.compteCollectif == numeroCompte)
                .toList();
      } else {
        _filteredTiers = [];
      }
    });
  }

  void _submitForm() async {
    // Récupérer le numéro de compte sélectionné
    final compteNumero = _selectedCompteNumero;

    // Validations
    if (compteNumero == null || compteNumero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un compte')),
      );
      return;
    }

    // Vérifier si tiers est requis (si le compte a liaison_tiers = true)
    if (_showTiersField) {
      if (_selectedTiersNumero == null || _selectedTiersNumero!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce compte nécessite un tiers')),
        );
        return;
      }
    }

    /* // Vérifier si ventilation analytique est requise
    if (_requiresVentilation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ventilation analytique requise pour ce journal'),
        ),
      );
      return;
    } */

    // Vérifier que N° Doc est saisi
    if (_numeroDocController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le numéro de document est obligatoire')),
      );
      return;
    }

    final jour = int.tryParse(_jourController.text);
    if (jour == null || jour < 1 || jour > 31) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jour invalide (1-31)')));
      return;
    }

    final debit = double.tryParse(_debitController.text) ?? 0;
    final credit = double.tryParse(_creditController.text) ?? 0;

    if ((debit > 0 && credit > 0) || (debit == 0 && credit == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exactement un des champs Débit/Crédit doit être saisi',
          ),
        ),
      );
      return;
    }

    // Créer la ligne d'écriture
    // Si en mode édition, garder le numéro d'enregistrement courant
    // Sinon, si un enregistrement courant non-équilibré existe, l'utiliser
    // Sinon, générer un nouveau numéro
    int numeroEnregistrement;
    if (_editingEcriture != null) {
      numeroEnregistrement = _editingEcriture!.numeroEnregistrement;
    } else if (_currentNumeroEnregistrement != null &&
        !_isCurrentEnregistrementBalanced) {
      numeroEnregistrement = _currentNumeroEnregistrement!;
    } else {
      numeroEnregistrement = SaisieComptableService.getNextNumeroEnregistrement(
        _ecritures,
      );
    }

    var ligne = LigneEcriture(
      id: _editingEcriture?.id,
      journalPeriodeId: widget.journalPeriode.id,
      numeroEnregistrement: numeroEnregistrement,
      jour: jour,
      numeroDocument: _numeroDocController.text,
      reference:
          _referenceController.text.isEmpty
              ? _numeroDocController.text
              : _referenceController.text,
      numeroCompte: compteNumero,
      numeroTiers: _selectedTiersNumero,
      libelle: _libelleController.text,
      montantDebit: debit,
      montantCredit: credit,
    );

    try {
      if (_editingIndex != null && _editingEcriture != null) {
        // Mode édition: mettre à jour
        await SaisieComptableService.updateEcriture(ligne);
        if (!mounted) return;

        setState(() {
          _ecritures[_editingIndex!] = ligne;
          _editingIndex = null;
          _editingEcriture = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Écriture modifiée')));
      } else {
        // Mode création: ajouter
        final newId = await SaisieComptableService.addLigneEcriture(ligne);
        ligne = ligne.copyWith(id: newId);
        if (!mounted) return;

        setState(() {
          _ecritures.add(ligne);
          _currentNumeroEnregistrement = numeroEnregistrement;

          // Vérifier si équilibré
          final ecrituresWithNumero =
              _ecritures
                  .where((e) => e.numeroEnregistrement == numeroEnregistrement)
                  .toList();
          final totaux = SaisieComptableService.calculateTotaux(
            ecrituresWithNumero,
          );
          _isCurrentEnregistrementBalanced =
              (totaux.totalDebit - totaux.totalCredit).abs() < 0.01;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Écriture enregistrée')));
      }

      // Recharger les données de la période pour mettre à jour le nombre d'écritures
      await _refreshPeriodeData();
      if (!mounted) return;

      // Si ventilation analytique requise, afficher le formulaire
      if (_requiresVentilation) {
        _showVentilationDialog(ligne);
      }

      // Si équilibré, réinitialiser complètement. Sinon, vider seulement les montants
      if (_isCurrentEnregistrementBalanced) {
        _clearForm();
      } else {
        _clearAmountsOnly();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showVentilationDialog(LigneEcriture ligne) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => VentilationDialog(
            ligne: ligne,
            onSaved: () {
              Navigator.pop(context);
            },
          ),
    );
  }

  Future<void> _refreshPeriodeData() async {
    try {
      final updatedPeriode = await SaisieComptableService.getJournalPeriodeById(
        widget.journalPeriode.id,
      );
      setState(() {
        widget.journalPeriode.nombreEcritures = updatedPeriode.nombreEcritures;
      });
    } catch (e) {
      // Silencieusement échouer si impossible de rafraîchir
      debugPrint('Erreur lors du rafraîchissement: $e');
    }
  }

  void _editEcriture(int index, LigneEcriture ecriture) {
    // Pré-remplir les champs avec les données de l'écriture
    _jourController.text = ecriture.jour.toString();
    _numeroDocController.text = ecriture.numeroDocument;
    _referenceController.text = ecriture.reference ?? '';
    _compteController.text = ecriture.numeroCompte;
    _selectedCompteNumero = ecriture.numeroCompte;
    _selectedTiersNumero = ecriture.numeroTiers;
    _libelleController.text = ecriture.libelle;

    if (ecriture.montantDebit > 0) {
      _debitController.text = ecriture.montantDebit.toString();
      _creditController.clear();
    } else {
      _creditController.text = ecriture.montantCredit.toString();
      _debitController.clear();
    }

    // Mettre à jour le champ tiers
    final compte = _comptes.firstWhere(
      (c) => c.numeroCompte == ecriture.numeroCompte,
      orElse: () => _comptes.first,
    );
    _showTiersField = compte.liaisonTiers;

    if (_showTiersField) {
      _filteredTiers =
          _tiers
              .where((tier) => tier.compteCollectif == ecriture.numeroCompte)
              .toList();
    }

    // Mode édition
    _editingIndex = index;
    _editingEcriture = ecriture;

    // Scroll vers le formulaire
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Modification: complétez les champs et cliquez sur Enregistrer',
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index, LigneEcriture ecriture) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmation de suppression'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer cette écriture?\n\n'
              'Compte: ${ecriture.numeroCompte}\n'
              'Montant: ${ecriture.montantDebit > 0 ? ecriture.montantDebit : ecriture.montantCredit} €',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteEcriture(index);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteEcriture(int index) async {
    final ecriture = _ecritures[index];
    try {
      await SaisieComptableService.deleteEcriture(ecriture.id ?? 0);
      if (!mounted) return;

      setState(() {
        _ecritures.removeAt(index);

        // Si on supprime la ligne actuellement en édition, réinitialiser
        if (_editingIndex == index) {
          _editingIndex = null;
          _editingEcriture = null;
          _clearForm();
        }

        // Réinitialiser l'état du numéro d'enregistrement
        _initializeCurrentEnregistrement();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Écriture supprimée')));

      // Recharger les données de la période pour mettre à jour le nombre d'écritures
      await _refreshPeriodeData();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de suppression: $e')));
    }
  }

  void _balanceEnregistrement() {
    if (_currentNumeroEnregistrement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun enregistrement en cours')),
      );
      return;
    }

    // Récupérer les écritures de l'enregistrement courant
    final ecrituresActuelles =
        _ecritures
            .where(
              (e) => e.numeroEnregistrement == _currentNumeroEnregistrement,
            )
            .toList();

    final totaux = SaisieComptableService.calculateTotaux(ecrituresActuelles);
    final difference = totaux.totalDebit - totaux.totalCredit;

    if (difference.abs() < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet enregistrement est déjà équilibré')),
      );
      return;
    }

    // Pré-remplir la ligne d'équilibrage
    setState(() {
      // Récupérer le dernier compte et jour saisie
      if (ecrituresActuelles.isNotEmpty) {
        final derniere = ecrituresActuelles.last;
        _jourController.text = derniere.jour.toString();
        _numeroDocController.text = derniere.numeroDocument;
        _referenceController.text = derniere.reference ?? '';
        _libelleController.text = derniere.libelle;

        // Le compte reste le même que la dernière ligne
        _compteController.text = derniere.numeroCompte;
        _selectedCompteNumero = derniere.numeroCompte;
        _selectedTiersNumero = derniere.numeroTiers;

        // Déterminer s'il faut un débit ou un crédit pour équilibrer
        if (difference > 0) {
          // Plus de débits, il faut un crédit
          _creditController.text = difference.toStringAsFixed(2);
          _debitController.clear();
        } else {
          // Plus de crédits, il faut un débit
          _debitController.text = (-difference).toStringAsFixed(2);
          _creditController.clear();
        }

        // Vérifier le champ tiers
        final compte = _comptes.firstWhere(
          (c) => c.numeroCompte == derniere.numeroCompte,
          orElse: () => _comptes.first,
        );
        _showTiersField = compte.liaisonTiers;

        if (_showTiersField) {
          _filteredTiers =
              _tiers
                  .where(
                    (tier) => tier.compteCollectif == derniere.numeroCompte,
                  )
                  .toList();
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ligne d\'équilibrage pré-remplie: ${difference.abs().toStringAsFixed(2)}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _jourController.dispose();
    _numeroDocController.dispose();
    _referenceController.dispose();
    _libelleController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _compteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saisie Écriture'),
          backgroundColor: Colors.blue.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie Écriture'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: PopScope(
        canPop: _totaux.isEquilibre,
        onPopInvoked: (didPop) {
          if (!didPop && !_totaux.isEquilibre) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Le solde doit être équilibré (actuellement: ${_totaux.solde.toStringAsFixed(2)})',
                ),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        child: Column(
          children: [
            // En-tête compact avec titre, nombre et résumé
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.shade700,
              child: Column(
                spacing: 8,
                children: [
                  // Ligne 1: Journal, Période et Nombre d'écritures
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Journal ${widget.journalPeriode.codeJournal}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.journalPeriode.periodeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      // Nombre d'enregistrements uniques
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_nombreEnregistrementsUniques écriture${_nombreEnregistrementsUniques > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Ligne 2: Numéro d'enregistrement et Totaux compacts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Numéro d'enregistrement
                      if (_currentNumeroEnregistrement != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _isCurrentEnregistrementBalanced
                                    ? Colors.green.shade400
                                    : Colors.orange.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'N° Enr: $_currentNumeroEnregistrement ${_isCurrentEnregistrementBalanced ? '✓' : '⏱'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      // Totaux compacts
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            // Débits
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                const Icon(
                                  Icons.trending_down,
                                  color: Colors.lightBlueAccent,
                                  size: 14,
                                ),
                                const Text(
                                  'D:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${_totaux.totalDebit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Crédits
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  color: Colors.lightGreenAccent,
                                  size: 14,
                                ),
                                const Text(
                                  'C:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${_totaux.totalCredit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightGreenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Séparateur
                            Container(
                              width: 1,
                              height: 16,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            // Solde
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                Icon(
                                  _totaux.isEquilibre
                                      ? Icons.check_circle
                                      : Icons.info,
                                  color:
                                      _totaux.isEquilibre
                                          ? Colors.green.shade300
                                          : _totaux.isSoldeNegatif
                                          ? Colors.red.shade300
                                          : Colors.orange.shade300,
                                  size: 14,
                                ),
                                const Text(
                                  'S:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${_totaux.solde.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _totaux.isEquilibre
                                            ? Colors.green.shade300
                                            : _totaux.isSoldeNegatif
                                            ? Colors.red.shade300
                                            : Colors.orange.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Formulaire de saisie
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: _buildFormulaire(),
            ),

            // Tableau des écritures
            Expanded(
              child:
                  _ecritures.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_chart,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucune écriture saisie',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(child: _buildTable()),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaire() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Jour
          SizedBox(
            width: 70,
            child: TextField(
              controller: _jourController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jour',
                hintText: 'JJ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // N° Document
          SizedBox(
            width: 110,
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                // Appuyer sur Tab pour passer au champ suivant ou valider
                if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
                  // Laisser le comportement par défaut de Tab
                }
              },
              child: TextField(
                controller: _numeroDocController,
                decoration: InputDecoration(
                  labelText: 'N° Doc',
                  hintText: 'Numéro',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Référence
          SizedBox(
            width: 110,
            child: TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Référence',
                hintText: 'Optionnel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // N° Compte (Searchable avec suggestions)
          SizedBox(
            width: 160,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Champ de saisie
                SizedBox(
                  height: 48,
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
                    onKey: (event) {
                      // Appuyer sur Tab pour compléter avec la première suggestion
                      if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
                        if (_filteredComptes.isNotEmpty) {
                          final compte = _filteredComptes.first;
                          _compteController.text = compte.numeroCompte;
                          _selectedCompteNumero = compte.numeroCompte;
                          setState(() {
                            _showTiersField = compte.liaisonTiers;
                          });
                        }
                      }
                    },
                    child: TextField(
                      controller: _compteController,
                      decoration: InputDecoration(
                        labelText: 'Compte',
                        hintText: 'Chercher... (Tab pour compléter)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon:
                            _filteredComptes.isNotEmpty
                                ? PopupMenuButton<Compte>(
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                  ),
                                  itemBuilder:
                                      (context) =>
                                          _filteredComptes
                                              .map(
                                                (
                                                  compte,
                                                ) => PopupMenuItem<Compte>(
                                                  value: compte,
                                                  child: Text(
                                                    '${compte.numeroCompte} - ${compte.intitule}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                  onSelected:
                                      (compte) => _onCompteSelected(
                                        compte.numeroCompte,
                                      ),
                                )
                                : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Tiers (toujours affiché, grisé par défaut)
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              value: _selectedTiersNumero,
              decoration: InputDecoration(
                labelText: _showTiersField ? 'Tiers*' : 'Tiers',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: !_showTiersField,
                fillColor: !_showTiersField ? Colors.grey.shade200 : null,
              ),
              isExpanded: true,
              disabledHint: Text(
                'Non requis',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              items:
                  _showTiersField
                      ? _filteredTiers.map((tier) {
                        return DropdownMenuItem<String>(
                          value: tier.numeroCompte,
                          child: Text(
                            tier.numeroCompte,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList()
                      : null,
              onChanged:
                  _showTiersField
                      ? (value) => setState(() => _selectedTiersNumero = value)
                      : null,
            ),
          ),
          const SizedBox(width: 8),

          // Libellé
          SizedBox(
            width: 140,
            child: TextField(
              controller: _libelleController,
              decoration: InputDecoration(
                labelText: 'Libellé',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Débit
          SizedBox(
            width: 80,
            child: TextField(
              controller: _debitController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Débit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Crédit
          SizedBox(
            width: 80,
            child: TextField(
              controller: _creditController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitForm(),
              decoration: InputDecoration(
                labelText: 'Crédit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Boutons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: Icon(
                  _editingIndex != null ? Icons.edit : Icons.add,
                  size: 18,
                ),
                label: Text(_editingIndex != null ? 'Modifier' : 'Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Bouton Équilibrer
              ElevatedButton.icon(
                onPressed:
                    !_isCurrentEnregistrementBalanced
                        ? _balanceEnregistrement
                        : null,
                icon: const Icon(Icons.balance, size: 18),
                label: const Text('Équilibrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(
                  _editingIndex != null ? 'Réinitialiser' : 'Annuler',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
        headingRowHeight: 48,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columnSpacing: 12,
        horizontalMargin: 12,
        columns: [
          DataColumn(
            label: Text(
              'N°',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Jour',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Doc',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Réf.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Compte',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Tiers',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Libellé',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
            numeric: false,
          ),
          DataColumn(
            label: Text(
              'Débit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Crédit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
        ],
        rows:
            _ecritures.asMap().entries.map((entry) {
              final index = entry.key;
              final ecriture = entry.value;
              final isEvenRow = index % 2 == 0;

              return DataRow(
                color: WidgetStateProperty.all(
                  isEvenRow ? Colors.white : Colors.grey.shade50,
                ),
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${ecriture.numeroEnregistrement}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade500,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Center(child: Text('${ecriture.jour}'))),
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: Text(
                        ecriture.numeroDocument,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Text(
                        ecriture.reference ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Text(
                        ecriture.numeroCompte,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Text(
                        ecriture.numeroTiers ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        ecriture.libelle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${ecriture.montantDebit.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  DataCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${ecriture.montantCredit.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  DataCell(
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      itemBuilder:
                          (context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Modifier'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Supprimer'),
                                ],
                              ),
                            ),
                          ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editEcriture(index, ecriture);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(index, ecriture);
                        }
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

/// Dialog pour la ventilation analytique
class VentilationDialog extends StatefulWidget {
  final LigneEcriture ligne;
  final VoidCallback onSaved;

  const VentilationDialog({required this.ligne, required this.onSaved});

  @override
  State<VentilationDialog> createState() => _VentilationDialogState();
}

class _VentilationDialogState extends State<VentilationDialog> {
  late TextEditingController _montantController;
  String? _selectedType;
  String? _selectedProjet;
  String? _selectedActivite;
  String? _selectedBailleur;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(
      text:
          widget.ligne.montantDebit > 0
              ? widget.ligne.montantDebit.toString()
              : widget.ligne.montantCredit.toString(),
    );
    _selectedType = 'fonctionnement';
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ventilation Analytique'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant: ${widget.ligne.montantDebit > 0 ? widget.ligne.montantDebit.toStringAsFixed(2) : widget.ligne.montantCredit.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type de ventilation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text('Fonctionnement'),
              value: 'fonctionnement',
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value),
            ),
            RadioListTile<String>(
              title: const Text('Projet'),
              value: 'projet',
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value),
            ),
            if (_selectedType == 'projet') ...[
              const SizedBox(height: 16),
              const Text(
                'Informations Projet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Projet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: _selectedProjet,
                items: const [
                  DropdownMenuItem(value: 'proj1', child: Text('Projet 1')),
                  DropdownMenuItem(value: 'proj2', child: Text('Projet 2')),
                ],
                onChanged: (value) => setState(() => _selectedProjet = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Type Activité',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: _selectedActivite,
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administration'),
                  ),
                  DropdownMenuItem(value: 'activite', child: Text('Activité')),
                ],
                onChanged: (value) => setState(() => _selectedActivite = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Bailleur',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: _selectedBailleur,
                items: const [
                  DropdownMenuItem(value: 'baill1', child: Text('Bailleur 1')),
                  DropdownMenuItem(value: 'baill2', child: Text('Bailleur 2')),
                ],
                onChanged: (value) => setState(() => _selectedBailleur = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _validateAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _validateAndSave() async {
    if (_selectedType == 'projet') {
      if (_selectedProjet == null ||
          _selectedActivite == null ||
          _selectedBailleur == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez compléter tous les champs')),
        );
        return;
      }
    }

    final ligneId = widget.ligne.id;
    if (ligneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement introuvable, ventilation impossible'),
        ),
      );
      return;
    }

    final ventilation = VentilationAnalytique(
      ligneEcritureId: ligneId,
      type: _selectedType ?? 'fonctionnement',
      idProjet: _selectedProjet,
      typeActivite: _selectedActivite,
      idBailleur: _selectedBailleur,
      montantVentrle: double.tryParse(_montantController.text) ?? 0.0,
    );

    try {
      await SaisieComptableService.saveVentilation(ventilation);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ventilation enregistrée')));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}
