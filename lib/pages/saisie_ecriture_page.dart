import 'package:flutter/material.dart';
import 'package:sycebnl_accounting/models/saisie_comptable.dart';
import 'package:sycebnl_accounting/models/compte.dart';
import 'package:sycebnl_accounting/models/tiers.dart';
import 'package:sycebnl_accounting/models/journal.dart';
import 'package:sycebnl_accounting/services/saisie_comptable_service.dart';
import 'package:sycebnl_accounting/services/database_service.dart';
import 'package:sycebnl_accounting/services/auth_service_local.dart' as auth;

// Fonction utilitaire globale pour formater les montants
String formatMontantCFA(double montant) {
  return montant
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ',
      );
}

class SaisieEcriturePage extends StatefulWidget {
  final JournalPeriode journalPeriode;
  final bool showAppBar;
  final Function(bool)? onClose;

  const SaisieEcriturePage({
    super.key,
    required this.journalPeriode,
    this.showAppBar = true,
    this.onClose,
  });

  @override
  State<SaisieEcriturePage> createState() => _SaisieEcriturePageState();
}

class _SaisieEcriturePageState extends State<SaisieEcriturePage> {
  // Données chargées
  List<LigneEcriture> _ecritures = [];
  List<Compte> _comptes = [];
  List<Tiers> _tiers = [];
  bool _isLoading = true;

  // Formulaire
  late TextEditingController _jourController;
  late TextEditingController _numeroDocController;
  late TextEditingController _referenceController;
  late TextEditingController _libelleController;
  late TextEditingController _debitController;
  late TextEditingController _creditController;
  late TextEditingController _compteController;
  final _jourFocusNode = FocusNode();
  FocusNode? _compteFocusNode;

  // Contrôleur utilisé par le champ Autocomplete pour pouvoir le nettoyer / compléter
  TextEditingController? _compteFieldController;

  String? _selectedCompteNumero;
  String? _selectedTiersNumero;
  bool _showTiersField = false;
  List<Compte> _filteredComptes = [];
  List<Tiers> _filteredTiers = [];

  // Mode édition
  int? _editingIndex;
  LigneEcriture? _editingEcriture;
  VentilationAnalytique? _currentVentilation;
  Journal? _journal;

  // Gestion du numéro d'enregistrement courant
  int? _currentNumeroEnregistrement;
  bool _isCurrentEnregistrementBalanced = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _compteFocusNode = FocusNode();
    _loadData();
  }

  // (dispose centralisé plus bas dans la classe)
  void _initializeControllers() {
    _jourController = TextEditingController();
    _numeroDocController = TextEditingController();
    _referenceController = TextEditingController();
    _libelleController = TextEditingController();
    _debitController = TextEditingController();
    _creditController = TextEditingController();
    _compteController = TextEditingController();

    // Écouter les changements pour filtrer les comptes
    _compteController.addListener(_filterComptes);
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

  void _autoCompleteCompteIfPrefix(
    String value, [
    TextEditingController? controller,
  ]) {
    final query = value.trim();
    if (query.isEmpty) return;

    // Compléter avec des zéros si le numéro est numérique et moins de 8 chiffres
    String comptePadded = query;
    if (RegExp(r'^\d+$').hasMatch(query) && query.length < 8) {
      comptePadded = query.padRight(8, '0');
    }

    try {
      // Chercher d'abord avec le numéro complété
      final compte = _comptes.firstWhere(
        (c) =>
            c.numeroCompte == comptePadded || c.numeroCompte.startsWith(query),
      );

      // Mettre à jour tous les controllers
      _compteController.text = compte.numeroCompte;
      if (controller != null) {
        controller.text = compte.numeroCompte;
      }
      if (_compteFieldController != null &&
          _compteFieldController != controller) {
        _compteFieldController!.text = compte.numeroCompte;
      }
      _selectedCompteNumero = compte.numeroCompte;
      _updateTiersForCompte(compte.numeroCompte);

      setState(() {});
    } catch (_) {
      // Aucun compte ne correspond: ne rien faire
    }
  }

  List<Compte> _applyJournalCompteFilter(List<Compte> comptes) {
    if (_journal == null) return comptes;

    // Pour journal financier: exclure le compte de trésorerie
    if (_journal!.type == TypeJournal.financier) {
      return comptes;
      /*   .where((c) => c.numeroCompte != _journal!.compteTresorerie)
          .toList(); */
    }

    // Pour journal non-financier: exclure les comptes commençant par '5'
    return comptes.where((c) => !c.numeroCompte.startsWith('5')).toList();
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
            widget.journalPeriode.exerciceId ?? 0,
          );

      setState(() {
        _comptes = comptes;
        _filteredComptes = comptes;
        _tiers = tiers;
        _journal = journal;
        _ecritures = ecritures;
        _isLoading = false;

        // Initialiser le numéro d'enregistrement courant
        _initializeCurrentEnregistrement();
      });

      // Recalcule la ventilation automatique des lignes d'équilibre à l'affichage
      await _recomputeAllEquilibrageVentilations();
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

  bool _isTiersRequired(bool? liaisonTiers) {
    return liaisonTiers ?? false;
  }

  bool _isCompteEquilibrage(String numeroCompte) {
    final compteTresorerie = _journal?.compteTresorerie;
    if (compteTresorerie == null || compteTresorerie.isEmpty) return false;
    return compteTresorerie == numeroCompte;
  }

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
    _resetCompteSelection();
    _editingIndex = null;
    _editingEcriture = null;
  }

  void _resetCompteSelection() {
    _compteController.clear();
    _compteFieldController?.clear();
    _selectedCompteNumero = null;
    _selectedTiersNumero = null;
    _showTiersField = false;
    _filteredTiers = [];
  }

  void _updateTiersForCompte(String numeroCompte) {
    final compte = _comptes.firstWhere(
      (c) => c.numeroCompte == numeroCompte,
      orElse: () => _comptes.first,
    );
    _showTiersField = _isTiersRequired(compte.liaisonTiers);

    if (_showTiersField) {
      _filteredTiers =
          _tiers.where((tier) => tier.compteCollectif == numeroCompte).toList();
    } else {
      _filteredTiers = [];
    }
  }

  void _setCompteSelectionFromNumero(String numeroCompte) {
    _compteController.text = numeroCompte;
    _compteFieldController?.text = numeroCompte;
    _selectedCompteNumero = numeroCompte;
    _updateTiersForCompte(numeroCompte);
  }

  Widget _buildVentilationBadge(LigneEcriture ecriture) {
    // Récupérer toutes les lignes de cet enregistrement
    final lignesEnregistrement =
        _ecritures
            .where(
              (e) => e.numeroEnregistrement == ecriture.numeroEnregistrement,
            )
            .toList();

    final bool isLigneEquilibre = _isLigneEquilibrage(
      ecriture,
      lignesEnregistrement,
    );

    final bool isVentileeManuellement = ecriture.hasVentilation == true;

    Color borderColor;
    Color backgroundColor;
    Color iconColor;
    IconData iconData;
    String tooltipMessage;

    // Principe métier : Une ligne d'équilibre est toujours considérée comme ventilée
    if (isLigneEquilibre) {
      // Ligne d'équilibre : pas besoin de ventilation pour être valide
      borderColor = Colors.green.shade600;
      backgroundColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      iconData = Icons.check_circle;
      tooltipMessage = 'Ligne d\'équilibre (ventilation automatique)';
    } else if (isVentileeManuellement) {
      // Ligne NON-équilibre ventilée manuellement
      borderColor = Colors.green.shade600;
      backgroundColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      iconData = Icons.check_circle;
      tooltipMessage = 'Ventilé manuellement';
    } else {
      // Ligne NON-équilibre non ventilée
      borderColor = Colors.red.shade600;
      backgroundColor = Colors.red.shade50;
      iconColor = Colors.red.shade700;
      iconData = Icons.cancel_outlined;
      tooltipMessage = 'Non ventilé';
    }

    return Tooltip(
      message: tooltipMessage,
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(iconData, color: iconColor, size: 10),
      ),
    );
  }

  void _clearAmountsOnly() {
    // Ne réinitialiser que les champs montants et compte
    // Les champs persistants (jour, numDoc, ref, libellé) restent
    _debitController.clear();
    _creditController.clear();
    _resetCompteSelection();

    // Utiliser addPostFrameCallback pour s'assurer que le widget est construit
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_compteFocusNode?.context != null) {
          _compteFocusNode?.requestFocus();
        }
      });
    }
  }

  void _onCompteSelected(String numeroCompte) {
    setState(() {
      _selectedCompteNumero = numeroCompte;
      _compteController.text = numeroCompte;
      _compteFieldController?.text = numeroCompte;
      _selectedTiersNumero = null;
      _updateTiersForCompte(numeroCompte);
    });
  }

  /// Récupère la ventilation appropriée pour une écriture
  /// Si c'est un crédit, cherche la ventilation d'un débit du même enregistrement
  /// Si c'est un débit, utilise la ventilation stockée
  VentilationAnalytique? _getVentilationForEcriture(
    int numeroEnregistrement,
    bool isDebit,
  ) {
    if (_selectedCompteNumero != null &&
        _isCompteEquilibrage(_selectedCompteNumero!)) {
      // Pas de ventilation manuelle sur le compte d'équilibre
      return null;
    }

    if (isDebit) {
      // Pour un débit, utiliser la ventilation stockée
      return _currentVentilation;
    } else {
      // Pour un crédit, chercher une ventilation d'un débit du même enregistrement
      for (final ecriture in _ecritures) {
        if (ecriture.numeroEnregistrement == numeroEnregistrement &&
            ecriture.montantDebit > 0 &&
            ecriture.ventilation != null) {
          return ecriture.ventilation;
        }
      }
      // Pas de ventilation trouvée
      return null;
    }
  }

  Future<void> _recomputeVentilationEquilibrage(
    int numeroEnregistrement,
    int? balanceLigneId,
  ) async {
    // Pour tous les journaux (avec ou sans compte de trésorerie)
    final lignesDuNumero =
        _ecritures
            .where((e) => e.numeroEnregistrement == numeroEnregistrement)
            .toList();

    if (lignesDuNumero.isEmpty) return;

    // Identifier la(les) ligne(s) d'équilibre
    List<LigneEcriture> lignesEquilibre = [];

    // Chercher d'abord par compte de trésorerie
    final compteTresorerie = _journal?.compteTresorerie;

    if (compteTresorerie != null && compteTresorerie.isNotEmpty) {
      // Journal avec compte de trésorerie
      lignesEquilibre =
          lignesDuNumero
              .where((e) => e.numeroCompte == compteTresorerie)
              .toList();
    } else {
      // Journal sans compte de trésorerie : dernière ligne
      final derniereLigne = lignesDuNumero.last;
      lignesEquilibre = [derniereLigne];
    }

    if (lignesEquilibre.isEmpty) return;

    // Agrégation des ventilations des autres lignes
    final agregats = await _aggregateVentilationsForEquilibre(
      numeroEnregistrement,
      balanceLigneId,
    );

    // Mettre à jour l'affichage (en mémoire uniquement)
    for (final cible in lignesEquilibre) {
      setState(() {
        _ecritures =
            _ecritures.map((e) {
              if (e.id == cible.id) {
                // Ne pas créer de ventilation si aucun agrégat
                // Le badge vert sera affiché via _buildVentilationBadge()
                return e.copyWith(
                  ventilation: agregats.isNotEmpty ? agregats.first : null,
                  hasVentilation: agregats.isNotEmpty,
                );
              }
              return e;
            }).toList();
      });
    }
  }

  Future<void> _recomputeAllEquilibrageVentilations() async {
    final compteTresorerie = _journal?.compteTresorerie;
    if (compteTresorerie == null || compteTresorerie.isEmpty) return;

    // Traiter chaque numéro d'enregistrement contenant au moins une ligne d'équilibre
    final numeros =
        _ecritures
            .where((e) => e.numeroCompte == compteTresorerie)
            .map((e) => e.numeroEnregistrement)
            .toSet();

    for (final numero in numeros) {
      await _recomputeVentilationEquilibrage(numero, null);
    }
  }

  void _submitForm() async {
    final compteNumero = _selectedCompteNumero;

    if (compteNumero == null || compteNumero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un compte')),
      );
      return;
    }

    if (_showTiersField) {
      if (_selectedTiersNumero == null || _selectedTiersNumero!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce compte nécessite un tiers')),
        );
        return;
      }
    }

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

    final daysInMonth = DateUtils.getDaysInMonth(
      widget.journalPeriode.annee,
      widget.journalPeriode.mois,
    );

    if (jour > daysInMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jour invalide pour cette période (max $daysInMonth)'),
        ),
      );
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

    final bool isCompteEquilibrage = _isCompteEquilibrage(compteNumero);

    final dateComptable = DateTime(
      widget.journalPeriode.annee,
      widget.journalPeriode.mois,
      jour,
    );

    var ligne = LigneEcriture(
      id: _editingEcriture?.id,
      journalPeriodeId: widget.journalPeriode.id,
      numeroEnregistrement: numeroEnregistrement,
      jour: jour,
      dateComptable: dateComptable,
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
      // Ventilation: interdite sur le compte d'équilibre
      ventilation:
          isCompteEquilibrage
              ? null
              : _getVentilationForEcriture(numeroEnregistrement, debit > 0),
      hasVentilation:
          isCompteEquilibrage
              ? false
              : _editingEcriture?.hasVentilation ?? false,
    );

    try {
      if (_editingIndex != null && _editingEcriture != null) {
        await SaisieComptableService.updateEcriture(ligne);

        setState(() {
          _ecritures[_editingIndex!] = ligne;
          _editingIndex = null;
          _editingEcriture = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Écriture modifiée')));
      } else {
        final newId = await SaisieComptableService.addLigneEcriture(ligne);
        ligne = ligne.copyWith(id: newId);

        setState(() {
          _ecritures.add(ligne);
          _currentNumeroEnregistrement = numeroEnregistrement;

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

        // Déterminer si on doit ouvrir le dialog de ventilation
        if (!isCompteEquilibrage && ligne.id != null) {
          await _handleAutoVentilationDialog(ligne, numeroEnregistrement);
        }
      }

      if (ligne.id != null) {
        await _recomputeVentilationEquilibrage(numeroEnregistrement, ligne.id!);
      }

      await _refreshPeriodeData();

      if (_isCurrentEnregistrementBalanced) {
        _clearForm();
      } else {
        _clearAmountsOnly();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  /// Détermine automatiquement si le dialog de ventilation doit s'ouvrir
  Future<void> _handleAutoVentilationDialog(
    LigneEcriture ligne,
    int numeroEnregistrement,
  ) async {
    final lignesEnregistrement =
        _ecritures
            .where((e) => e.numeroEnregistrement == numeroEnregistrement)
            .toList();

    // Cas 1 : Premier enregistrement avec ce numéro
    if (lignesEnregistrement.length == 1) {
      _showVentilationDialog(ligne);
      return;
    }

    // Cas 2 : Pas le premier, vérifier si même colonne que ligne précédente
    if (lignesEnregistrement.length >= 2) {
      // Trouver la ligne précédente (avant-dernière car la dernière c'est celle qu'on vient d'ajouter)
      final lignePrecedente =
          lignesEnregistrement[lignesEnregistrement.length - 2];

      final bool ligneActuelleEstDebit = ligne.montantDebit > 0;
      final bool lignePrecedenteEstDebit = lignePrecedente.montantDebit > 0;

      // Si même colonne (les deux au débit OU les deux au crédit)
      if (ligneActuelleEstDebit == lignePrecedenteEstDebit) {
        _showVentilationDialog(ligne);
        return;
      }
    }

    // Cas 3 : Logique actuelle (ligne d'équilibrage)
    final bool isLigneEquilibre = _isLigneEquilibrage(
      ligne,
      lignesEnregistrement,
    );

    if (isLigneEquilibre) {
      // Afficher la ventilation agrégée automatique
      _showAggregatedVentilationPreview(ligne);
    } else {
      // Dialog de ventilation éditable
      _showVentilationDialog(ligne);
    }
  }

  void _showVentilationDialog(LigneEcriture ligne) {
    // Récupérer toutes les lignes de cet enregistrement
    final lignesEnregistrement =
        _ecritures
            .where((e) => e.numeroEnregistrement == ligne.numeroEnregistrement)
            .toList();

    final bool isLigneEquilibre = _isLigneEquilibrage(
      ligne,
      lignesEnregistrement,
    );

    if (isLigneEquilibre) {
      // Pour TOUTES les lignes d'équilibre (avec ou sans compte de trésorerie)
      // Afficher la ventilation agrégée
      _showAggregatedVentilationPreview(ligne);
      return;
    }

    // Pour les autres lignes : dialog normal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => VentilationDialog(
            ligne: ligne,
            onSaved: (ventilation) async {
              await _handleVentilationSaved(ligne, ventilation);
            },
          ),
    );
  }

  Future<void> _showAggregatedVentilationPreview(LigneEcriture ligne) async {
    final agregats = await _aggregateVentilationsForEquilibre(
      ligne.numeroEnregistrement,
      ligne.id,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Ventilation automatique - Enregistrement ${ligne.numeroEnregistrement}',
          ),
          content:
              agregats.isEmpty
                  ? const Text(
                    'Aucune ventilation trouvée sur les autres lignes de cet enregistrement',
                  )
                  : SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Résumé
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total agrégé:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade400,
                                  ),
                                ),
                                Text(
                                  formatMontantCFA(
                                    agregats.fold(
                                      0.0,
                                      (sum, v) => sum + v.montantVentrle,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade400,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Liste des ventilations
                          ...agregats.map((v) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.type == 'projet'
                                              ? 'Projet ${v.idProjet ?? ''}'
                                              : 'Fonctionnement',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (v.typeActivite != null &&
                                            v.typeActivite!.isNotEmpty)
                                          Text(
                                            'Volet: ${v.typeActivite}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        if (v.idBailleur != null &&
                                            v.idBailleur!.isNotEmpty)
                                          Text(
                                            'Bailleur: ${v.idBailleur}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatMontantCFA(v.montantVentrle),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleVentilationSaved(
    LigneEcriture ligne,
    VentilationAnalytique? ventilation,
  ) async {
    final hasVentilation = ventilation != null;

    setState(() {
      _currentVentilation = hasVentilation ? ventilation : null;
      _ecritures =
          _ecritures.map((e) {
            if (e.id == ligne.id) {
              return e.copyWith(
                ventilation: ventilation,
                hasVentilation: hasVentilation,
              );
            }
            if (e.id != ligne.id &&
                e.numeroEnregistrement == ligne.numeroEnregistrement) {
              return e.copyWith(hasVentilation: hasVentilation);
            }
            return e;
          }).toList();
    });

    if (!hasVentilation || _isCompteEquilibrage(ligne.numeroCompte)) return;

    await _recomputeVentilationEquilibrage(ligne.numeroEnregistrement, null);
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
      debugPrint('Erreur lors du rafraîchissement: $e');
    }
  }

  void _editEcriture(int index, LigneEcriture ecriture) {
    // Update controllers and fields first (without setState)
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

    final compte = _comptes.firstWhere(
      (c) => c.numeroCompte == ecriture.numeroCompte,
      orElse: () => _comptes.first,
    );
    _showTiersField = _isTiersRequired(compte.liaisonTiers);

    if (_showTiersField) {
      _filteredTiers =
          _tiers
              .where((tier) => tier.compteCollectif == ecriture.numeroCompte)
              .toList();
    }

    _editingIndex = index;
    _editingEcriture = ecriture;

    // Defer all state mutations outside mouse tracking cycle
    Future.delayed(const Duration(milliseconds: 0), () {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Modification: complétez les champs et cliquez sur Enregistrer',
            ),
          ),
        );
      }
    });
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
              'Montant: ${ecriture.montantDebit > 0 ? ecriture.montantDebit : ecriture.montantCredit} FCFA',
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

      // Defer all state mutations outside mouse tracking cycle
      Future.delayed(const Duration(milliseconds: 0), () {
        if (mounted) {
          setState(() {
            _ecritures.removeAt(index);

            if (_editingIndex == index) {
              _editingIndex = null;
              _editingEcriture = null;
              _clearForm();
            }

            _initializeCurrentEnregistrement();
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Écriture supprimée')));
        }
      });

      await _refreshPeriodeData();

      // Si on supprime une ligne ventilée ou la ligne d'équilibre, recalculer la ventilation auto
      /*  await _recomputeVentilationEquilibrage(
        ecriture.numeroEnregistrement,
        null,
      ); */
      await _recomputeVentilationEquilibrage(
        ecriture.numeroEnregistrement,
        null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de suppression: $e')));
      }
    }
  }

  void _balanceEnregistrement() {
    if (_currentNumeroEnregistrement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun enregistrement en cours')),
      );
      return;
    }

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

    setState(() {
      if (ecrituresActuelles.isNotEmpty) {
        final derniere = ecrituresActuelles.last;
        _jourController.text = derniere.jour.toString();
        _numeroDocController.text = derniere.numeroDocument;
        _referenceController.text = derniere.reference ?? '';
        _libelleController.text = derniere.libelle;

        // Utilise le compte de trésorerie s'il est défini sur le journal
        final compteTresorerie = _journal?.compteTresorerie;

        if (compteTresorerie != null && compteTresorerie.isNotEmpty) {
          // Chercher le compte de trésorerie; s'il manque, laisser vide
          try {
            final compte = _comptes.firstWhere(
              (c) => c.numeroCompte == compteTresorerie,
            );
            _setCompteSelectionFromNumero(compte.numeroCompte);
          } catch (_) {
            _resetCompteSelection();
          }
        } else {
          // Pas de trésorerie : ne pré-remplit pas le compte
          _resetCompteSelection();
        }

        _selectedTiersNumero = null;

        if (difference > 0) {
          _creditController.text = difference.toStringAsFixed(2);
          _debitController.clear();
        } else {
          _debitController.text = (-difference).toStringAsFixed(2);
          _creditController.clear();
        }

        // Mettre à jour le champ tiers uniquement si un compte est présent
        if (_selectedCompteNumero == null) {
          _showTiersField = false;
          _filteredTiers = [];
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ligne d\'équilibrage pré-remplie: ${formatMontantCFA(difference.abs())} FCFA',
        ),
      ),
    );
  }

  ///Détermine si une ligne est la ligne d'équilibre d'un enregistrement
  /// Une ligne d'équilibre = celle qui équilibre la somme des autres
  /// Détection par le montant, indépendante du compte de trésorerie
  bool _isLigneEquilibrage(
    LigneEcriture ligne,
    List<LigneEcriture> lignesEnregistrement,
  ) {
    if (lignesEnregistrement.length <= 1) return false;

    // Calculer la somme signée de toutes les autres lignes
    double totalAutres = 0;
    for (final l in lignesEnregistrement) {
      if (l.id != ligne.id) {
        final montantSigne = l.montantDebit - l.montantCredit;
        totalAutres += montantSigne;
      }
    }

    // La ligne d'équilibre est celle dont le montant compense exactement les autres
    final montantSigneLigne = ligne.montantDebit - ligne.montantCredit;
    final difference = (montantSigneLigne + totalAutres).abs();

    return difference < 0.01;
  }

  //Agrège les ventilations de toutes les lignes SAUF la ligne d'équilibre
  Future<List<VentilationAnalytique>> _aggregateVentilationsForEquilibre(
    int numeroEnregistrement,
    int? excludedLigneId,
  ) async {
    final lignesDuNumero =
        _ecritures
            .where((e) => e.numeroEnregistrement == numeroEnregistrement)
            .toList();

    final Map<String, Map<String, dynamic>> agregats = {};

    for (final ligne in lignesDuNumero) {
      //Exclure la ligne d'équilibre
      if (ligne.id == excludedLigneId) continue;
      if (ligne.id == null) continue;

      //Récupérer les ventilations de cette ligne

      final ventilations = await SaisieComptableService.getVentilations(
        ligne.id!,
      );

      for (final v in ventilations) {
        final key =
            '${v.type}|${v.idProjet ?? ''}|${v.typeActivite ?? ''}|${v.idBailleur ?? ''}|${v.postebudgetaire ?? ''}|${v.ligneBudgetaire ?? ''}';

        final current = agregats.putIfAbsent(key, () {
          return {
            'type': v.type,
            'idProjet': v.idProjet,
            'typeActivite': v.typeActivite,
            'idBailleur': v.idBailleur,
            'posteBudgetaire': v.postebudgetaire,
            'ligneBudgetaire': v.ligneBudgetaire,
            'montant': 0.0,
          };
        });

        current['montant'] = (current['montant'] as double) + v.montantVentrle;
      }
    }

    //Convertir en ligne de ventilationAnalytique
    return agregats.values.map((entry) {
      return VentilationAnalytique(
        ligneEcritureId: 0, // non persisté
        type: (entry['type'] as String?) ?? 'fonctionnement',
        idProjet: entry['idProjet'] as String?,
        typeActivite: entry['typeActivite'] as String?,
        idBailleur: entry['idBailleur'] as String?,
        postebudgetaire: entry['posteBudgetaire'] as String?,
        ligneBudgetaire: entry['ligneBudgetaire'] as String?,
        montantVentrle: (entry['montant'] as double?) ?? 0.0,
      );
    }).toList();
  }

  @override
  void dispose() {
    _jourController.dispose();
    _numeroDocController.dispose();
    _referenceController.dispose();
    _libelleController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _compteController.removeListener(_filterComptes);
    _compteController.dispose();
    _jourFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final loader = const Center(child: CircularProgressIndicator());
      if (widget.showAppBar) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Saisie Écriture'),
            backgroundColor: Colors.blue.shade500,
          ),
          body: loader,
        );
      }
      return loader;
    }

    final body = _buildPageBody();

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saisie Écriture'),
          backgroundColor: Colors.blue.shade500,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildPageBody() {
    return PopScope(
      canPop: _totaux.isEquilibre,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_totaux.isEquilibre) {
          _showBalanceWarning();
        }
      },
      child: Column(
        children: [
          if (!widget.showAppBar) _buildEmbeddedToolbar(),
          // En-tête avec infos du journal et totaux
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                // Ligne 1: Journal et nombre d'écritures
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Icon(Icons.assignment, size: 16, color: Colors.white70),
                        Text(
                          '$_nombreEnregistrementsUniques',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'écriture${_nombreEnregistrementsUniques > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Ligne 2: Totaux (Débit/Crédit/Solde)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Débit
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 14,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Débit',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                formatMontantCFA(_totaux.totalDebit),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Crédit
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.arrow_upward,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Crédit',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                formatMontantCFA(_totaux.totalCredit),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Séparateur
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),

                      // Solde
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  _totaux.isEquilibre
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              _totaux.isEquilibre
                                  ? Icons.check_circle
                                  : Icons.error,
                              size: 14,
                              color:
                                  _totaux.isEquilibre
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Solde',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                formatMontantCFA(_totaux.solde),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _totaux.isEquilibre
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ligne 3: Enregistrement en cours (s'il existe)
                if (_currentNumeroEnregistrement != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isCurrentEnregistrementBalanced
                              ? Colors.green.shade500
                              : Colors.orange.shade500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Icon(
                          _isCurrentEnregistrementBalanced
                              ? Icons.check_circle
                              : Icons.timer,
                          size: 16,
                          color: Colors.white,
                        ),
                        Text(
                          'Enregistrement n° $_currentNumeroEnregistrement',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isCurrentEnregistrementBalanced
                              ? '(équilibré)'
                              : '(en cours)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Tableau avec saisie intégrée
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTableWithInputRow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (widget.onClose != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                if (_totaux.isEquilibre) {
                  widget.onClose!(true);
                } else {
                  _showBalanceWarning();
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              'Saisie Écriture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade400,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  void _showBalanceWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Le solde doit être équilibré (actuellement: ${_totaux.solde.toStringAsFixed(2)})',
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Widget _buildTableWithInputRow() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // LIGNE 1: Champs de saisie
          _buildInputRow(),

          // LIGNE 2: En-têtes des colonnes
          _buildHeaderRow(),

          // LIGNES 3+: Données (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child:
                  _ecritures.isNotEmpty
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_ecritures.length, (index) {
                          final ecriture = _ecritures[index];
                          final isEvenRow = index % 2 == 0;
                          return _buildDataRow(index, ecriture, isEvenRow);
                        }),
                      )
                      : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Aucune écriture saisie',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // Ligne 1: Champs de saisie
  Widget _buildInputRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 2),
        ),
      ),
      child: Row(
        children: [
          // N° d'enregistrement (automatique, non-éditable)
          _buildCell(
            width: 120,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Text(
                _currentNumeroEnregistrement?.toString() ?? '—',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade500,
                ),
              ),
            ),
          ),

          // Jour
          _buildCell(
            width: 85,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _jourController,
                focusNode: _jourFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'JJ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // N° Document
          _buildCell(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _numeroDocController,
                decoration: InputDecoration(
                  hintText: 'N° Doc',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Référence
          _buildCell(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  hintText: 'Ref',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Compte
          _buildCell(
            width: 170,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Autocomplete<Compte>(
                initialValue: TextEditingValue(text: _compteController.text),
                displayStringForOption: (Compte option) => option.numeroCompte,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Compte>.empty();
                  }
                  final query = textEditingValue.text.toLowerCase();
                  final matches =
                      _comptes.where((compte) {
                        return compte.numeroCompte.toLowerCase().contains(
                              query,
                            ) ||
                            compte.intitule.toLowerCase().contains(query);
                      }).toList();
                  return _applyJournalCompteFilter(matches);
                },
                onSelected: (Compte selection) {
                  _compteController.text = selection.numeroCompte;
                  _onCompteSelected(selection.numeroCompte);
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Stocker le FocusNode pour pouvoir l'utiliser dans _clearAmountsOnly()
                  _compteFocusNode = focusNode;
                  _compteFieldController = textEditingController;

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onTapOutside: (_) {
                      _autoCompleteCompteIfPrefix(
                        textEditingController.text,
                        textEditingController,
                      );
                    },
                    onChanged: (value) {
                      _compteController.text = value;
                      setState(() {
                        _selectedCompteNumero = value;
                        try {
                          final compte = _comptes.firstWhere(
                            (c) => c.numeroCompte == value,
                          );
                          _showTiersField = compte.liaisonTiers;
                        } catch (e) {
                          _showTiersField = false;
                        }
                      });
                    },
                    onSubmitted: (value) {
                      _autoCompleteCompteIfPrefix(value, textEditingController);
                    },
                    onEditingComplete: () {
                      _autoCompleteCompteIfPrefix(
                        textEditingController.text,
                        textEditingController,
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Compte (code/nom)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      isDense: true,
                      suffixIcon:
                          textEditingController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  textEditingController.clear();
                                  _compteController.clear();
                                  setState(() {
                                    _selectedCompteNumero = null;
                                    _showTiersField = false;
                                  });
                                },
                              )
                              : null,
                    ),
                  );
                },
                optionsViewBuilder: (
                  BuildContext context,
                  AutocompleteOnSelected<Compte> onSelected,
                  Iterable<Compte> options,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: Container(
                        width: 170,
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Compte option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                color:
                                    index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.numeroCompte,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      option.intitule,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Tiers
          _buildCell(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DropdownButtonFormField<String>(
                value: _selectedTiersNumero,
                decoration: InputDecoration(
                  hintText: 'Tiers',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                  filled: !_showTiersField,
                  fillColor: !_showTiersField ? Colors.grey.shade200 : null,
                ),
                isExpanded: true,
                disabledHint: Text(
                  'Non requis',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                items:
                    _showTiersField
                        ? _filteredTiers.map((tier) {
                          return DropdownMenuItem<String>(
                            value: tier.numeroCompte,
                            child: Text(
                              tier.numeroCompte,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList()
                        : null,
                onChanged:
                    _showTiersField
                        ? (value) =>
                            setState(() => _selectedTiersNumero = value)
                        : null,
              ),
            ),
          ),

          // Libellé
          _buildCell(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _libelleController,
                decoration: InputDecoration(
                  hintText: 'Libellé',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Débit
          _buildCell(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _debitController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitForm(),
                decoration: InputDecoration(
                  hintText: 'Débit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Crédit
          _buildCell(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _creditController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Crédit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Actions
          _buildCell(
            width: 270,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: Icon(
                        _editingIndex != null ? Icons.edit : Icons.add,
                        size: 14,
                      ),
                      label: Text(
                        _editingIndex != null ? 'Modif.' : 'Ajouter',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          !_isCurrentEnregistrementBalanced
                              ? _balanceEnregistrement
                              : null,
                      icon: const Icon(Icons.balance, size: 14),
                      label: const Text(
                        'Équil.',
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.clear, size: 14),
                      label: Text(
                        _editingIndex != null ? 'Réinit.' : 'Annul.',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
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

  // Ligne 2: En-têtes
  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('N° Enr', 120),
          _buildHeaderCell('Jour', 85),
          _buildHeaderCell('N° Doc', 130),
          _buildHeaderCell('Ref', 120),
          _buildHeaderCell('Compte', 170),
          _buildHeaderCell('Tiers', 120),
          _buildHeaderCell('Libellé', 200),
          _buildHeaderCell('Débit', 110),
          _buildHeaderCell('Crédit', 110),
          _buildHeaderCell('Ventilation', 120),
          _buildHeaderCell('Actions', 150),
        ],
      ),
    );
  }

  // Lignes 3+: Données
  Widget _buildDataRow(int index, LigneEcriture ecriture, bool isEvenRow) {
    return Material(
      color: isEvenRow ? Colors.white : Colors.grey.shade50,
      child: InkWell(
        onTap: () => _showLigneLibelle(ecriture),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              _buildDataCell(ecriture.numeroEnregistrement.toString(), 120),
              _buildDataCell(ecriture.jour.toString(), 85),
              _buildDataCell(ecriture.numeroDocument, 130),
              _buildDataCell(ecriture.reference ?? '-', 120),
              _buildDataCell(ecriture.numeroCompte, 170),
              _buildDataCell(ecriture.numeroTiers ?? '-', 120),
              _buildDataCell(ecriture.libelle, 200),
              _buildDataCell(
                ecriture.montantDebit > 0
                    ? formatMontantCFA(ecriture.montantDebit)
                    : '-',
                110,
                isDebit: true,
              ),
              _buildDataCell(
                ecriture.montantCredit > 0
                    ? formatMontantCFA(ecriture.montantCredit)
                    : '-',
                110,
                isCredit: true,
              ),
              // Colonne Ventilation
              _buildCell(
                width: 120,
                minHeight: 14,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _showVentilationDialog(ecriture);
                    },
                    child: Container(
                      padding: EdgeInsets.zero,
                      child: _buildVentilationBadge(ecriture),
                    ),
                  ),
                ),
              ),
              // Colonne Actions
              _buildCell(
                width: 150,
                minHeight: 14,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 28,
                    height: 16,
                    child: Icon(
                      Icons.more_vert,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text('Modifier'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('Supprimer'),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    // Defer actions outside mouse tracking cycle
                    if (value == 'edit') {
                      Future.delayed(const Duration(milliseconds: 0), () {
                        if (mounted) _editEcriture(index, ecriture);
                      });
                    } else if (value == 'delete') {
                      Future.delayed(const Duration(milliseconds: 0), () {
                        if (mounted) _showDeleteConfirmation(index, ecriture);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLigneLibelle(LigneEcriture ecriture) {
    final libelle = ecriture.libelle.trim();
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Libelle de la ligne'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SelectableText(
                libelle.isEmpty ? 'Aucun libelle renseigne' : libelle,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  // Cellule de contenu (données)
  Widget _buildDataCell(
    String content,
    double width, {
    bool isDebit = false,
    bool isCredit = false,
  }) {
    final bool isMontantCell = isDebit || isCredit;
    final Color amountColor = Colors.indigo.shade700;

    return _buildCell(
      width: width,
      minHeight: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          content,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMontantCell ? amountColor : Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Cellule en-tête
  Widget _buildHeaderCell(String title, double width) {
    return _buildCell(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Conteneur de cellule
  Widget _buildCell({
    required double width,
    required Widget child,
    double minHeight = 58,
  }) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: child,
    );
  }
}

/// Dialog pour la ventilation analytique
class VentilationDialog extends StatefulWidget {
  final LigneEcriture ligne;
  final Function(VentilationAnalytique?) onSaved;

  const VentilationDialog({
    super.key,
    required this.ligne,
    required this.onSaved,
  });

  @override
  State<VentilationDialog> createState() => _VentilationDialogState();
}

class _VentilationDialogState extends State<VentilationDialog> {
  List<_VentilationRow> _rows = [];
  static const List<double> _columnWidths = <double>[
    90,
    200,
    120,
    165,
    165,
    165,
    120,
    60,
  ];

  bool _isSaving = false;

  // Champs de saisie pour la première ligne
  String? _selectedAxe;
  int? _selectedProjetId;
  String? _selectedVolet;
  int? _selectedBailleurId;
  int? _selectedPosteId;
  int? _selectedLigneId;
  double _montantSaisie = 0;
  final TextEditingController _montantController = TextEditingController();

  // Données chargées
  List<Map<String, Object?>> _projets = [];
  List<dynamic> _bailleurs = [];
  List<dynamic> _postes = [];
  List<dynamic> _lignes = [];

  // Montants
  double get _montantLigne =>
      widget.ligne.montantDebit > 0
          ? widget.ligne.montantDebit
          : widget.ligne.montantCredit;

  double get _totalVentile =>
      _rows.fold(0, (sum, row) => sum + (row.montant ?? 0));

  double get _solde => _montantLigne - _totalVentile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final projets = await auth.AuthService.getProjets();
      final List<Map<String, Object?>> projetOptions =
          projets
              .map((p) => <String, Object?>{'id': p.id, 'intitule': p.nom})
              .toList();

      List<_VentilationRow> existingRows = [];
      if (widget.ligne.id != null) {
        final ventilations = await SaisieComptableService.getVentilations(
          widget.ligne.id!,
        );
        existingRows =
            ventilations
                .map(
                  (ventilation) =>
                      _buildRowFromVentilation(ventilation, projetOptions),
                )
                .toList();
      }

      if (!mounted) return;
      setState(() {
        _projets = projetOptions;
        _rows = existingRows;
      });
    } catch (e) {
      debugPrint('Erreur chargement projets: $e');
    }
  }

  Future<void> _loadBailleurs() async {
    if (_selectedProjetId == null) return;

    try {
      final bailleurs = await auth.AuthService.getBailleursForProjet(
        _selectedProjetId!,
      );
      setState(() {
        _bailleurs = bailleurs;
      });
    } catch (e) {
      debugPrint('Erreur chargement bailleurs: $e');
    }
  }

  Future<void> _loadPostes() async {
    if (_selectedProjetId == null) return;

    try {
      final postes = await auth.AuthService.getPostesBudgetaires(
        _selectedProjetId!,
      );
      setState(() {
        _postes = postes;
      });
    } catch (e) {
      debugPrint('Erreur chargement postes: $e');
    }
  }

  Future<void> _loadLignes() async {
    if (_selectedPosteId == null) return;

    try {
      final lignes = await auth.AuthService.getLignesBudgetaires(
        _selectedPosteId!,
      );
      setState(() {
        _lignes = lignes;
      });
    } catch (e) {
      debugPrint('Erreur chargement lignes: $e');
    }
  }

  Future<bool> _persistVentilations() async {
    if (_isSaving) return false;

    setState(() {
      _isSaving = true;
    });

    try {
      final ligneId = widget.ligne.id;
      if (ligneId == null) {
        return true;
      }

      await SaisieComptableService.deleteVentilations(ligneId);

      if (_selectedAxe == 'Fonctionnement' &&
          !_rows.any(
            (row) =>
                row.axe != null && row.axe!.toLowerCase() == 'fonctionnement',
          )) {
        _rows.add(_VentilationRow(axe: 'Fonctionnement', montant: _solde));
      }

      if (_rows.isEmpty) {
        widget.onSaved(null);
        return true;
      }

      for (final row in _rows) {
        final bool isFonctionnement =
            row.axe != null && row.axe!.toLowerCase() == 'fonctionnement';

        final VentilationAnalytique ventilation =
            isFonctionnement
                ? VentilationAnalytique(
                  ligneEcritureId: ligneId,
                  type: 'fonctionnement',
                  montantVentrle: row.montant ?? _solde,
                )
                : VentilationAnalytique(
                  ligneEcritureId: ligneId,
                  type: 'projet',
                  idProjet: row.projetId?.toString(),
                  typeActivite: row.volet,
                  idBailleur: row.bailleurId?.toString(),
                  postebudgetaire: row.posteId?.toString(),
                  ligneBudgetaire: row.ligneId?.toString(),
                  montantVentrle: row.montant ?? 0,
                );

        await SaisieComptableService.saveVentilation(ventilation);
        widget.onSaved(ventilation);
      }

      return true;
    } catch (e) {
      debugPrint('Erreur sauvegarde ventilations: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveAndClose() async {
    final shouldClose = await _persistVentilations();
    if (shouldClose && mounted) {
      Navigator.pop(context);
    }
  }

  _VentilationRow _buildRowFromVentilation(
    VentilationAnalytique ventilation,
    List<Map<String, Object?>> projetOptions,
  ) {
    if (ventilation.type == 'fonctionnement') {
      return _VentilationRow(
        axe: 'Fonctionnement',
        montant: ventilation.montantVentrle,
      );
    }

    int? parseNullableInt(String? value) {
      if (value == null || value.isEmpty) return null;
      return int.tryParse(value);
    }

    final projetId = parseNullableInt(ventilation.idProjet);
    final bailleurId = parseNullableInt(ventilation.idBailleur);
    final posteId = parseNullableInt(ventilation.postebudgetaire);
    final ligneId = parseNullableInt(ventilation.ligneBudgetaire);

    String? projetIntitule;
    if (projetId != null) {
      final match = projetOptions.firstWhere(
        (item) => item['id'] == projetId,
        orElse: () => <String, Object?>{},
      );
      projetIntitule =
          match['intitule'] as String? ?? ventilation.projetNom ?? '$projetId';
    } else {
      projetIntitule = ventilation.projetNom;
    }

    return _VentilationRow(
      axe: 'Projet',
      projetId: projetId,
      projetIntitule: projetIntitule,
      volet: ventilation.typeActivite,
      bailleurId: bailleurId,
      bailleur: ventilation.bailleurNom ?? (bailleurId?.toString() ?? '—'),
      posteId: posteId,
      poste: ventilation.posteNom ?? (posteId?.toString() ?? '—'),
      ligneId: ligneId,
      ligne: ventilation.ligneNom ?? (ligneId?.toString() ?? '—'),
      montant: ventilation.montantVentrle,
    );
  }

  void _resetInputRow() {
    setState(() {
      _selectedAxe = null;
      _selectedProjetId = null;
      _selectedVolet = null;
      _selectedBailleurId = null;
      _selectedPosteId = null;
      _selectedLigneId = null;
      _montantSaisie = 0;
      _montantController.clear();
      _bailleurs = [];
      _postes = [];
      _lignes = [];
    });
  }

  void _equilibrer() {
    setState(() {
      _montantSaisie = _solde;
      _montantController.text = _solde == 0 ? '' : _solde.toStringAsFixed(0);
    });
  }

  void _enregistrerLigne() {
    if (_selectedAxe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un axe')),
      );
      return;
    }

    if (_selectedAxe == 'Fonctionnement') {
      setState(() {
        _rows.removeWhere((row) => row.axe == 'Fonctionnement');
        _rows.add(_VentilationRow(axe: 'Fonctionnement', montant: _solde));
      });
      return;
    }

    // Sinon, vérifier les champs obligatoires pour Projet
    if (_selectedProjetId == null ||
        _selectedVolet == null ||
        _montantSaisie <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les champs sont obligatoires')),
      );
      return;
    }

    // Ajouter à la liste
    setState(() {
      // Trouver les intitulés
      final projetIntitule =
          (_projets.firstWhere(
                (p) => p['id'] == _selectedProjetId,
                orElse: () => <String, Object?>{'intitule': '—'},
              )['intitule']
              as String?) ??
          '—';

      final bailleurIntitule =
          _selectedBailleurId != null
              ? ((_bailleurs.firstWhere(
                        (b) => b['id'] == _selectedBailleurId,
                        orElse: () => <String, Object?>{'designation': '—'},
                      )['designation']
                      as String?) ??
                  '—')
              : '—';

      final posteIntitule =
          _selectedPosteId != null
              ? ((_postes.firstWhere(
                        (p) => p['id'] == _selectedPosteId,
                        orElse: () => <String, Object?>{'intitule': '—'},
                      )['intitule']
                      as String?) ??
                  '—')
              : '—';

      final ligneIntitule =
          _selectedLigneId != null
              ? ((_lignes.firstWhere(
                        (l) => l['id'] == _selectedLigneId,
                        orElse: () => <String, Object?>{'intitule': '—'},
                      )['intitule']
                      as String?) ??
                  '—')
              : '—';

      _rows.add(
        _VentilationRow(
          axe: _selectedAxe,
          projetId: _selectedProjetId,
          projetIntitule: projetIntitule,
          volet: _selectedVolet,
          bailleurId: _selectedBailleurId,
          bailleur: bailleurIntitule,
          posteId: _selectedPosteId,
          poste: posteIntitule,
          ligneId: _selectedLigneId,
          ligne: ligneIntitule,
          montant: _montantSaisie,
        ),
      );
      _resetInputRow();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving) {
          return;
        }

        final shouldClose = await _persistVentilations();
        if (shouldClose && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Dialog(
        child: Container(
          width: 1200,
          height: 700,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Header avec bouton de retour
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ventilation Analytique',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSaving ? null : _saveAndClose,
                    ),
                  ],
                ),
              ),
              // Contenu principal
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informations de montants
                        _buildMontantInfo(),
                        const SizedBox(height: 24),

                        // Tableau
                        _buildTableau(),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer avec boutons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving ? null : _saveAndClose,
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMontantInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Montant à ventiler',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                formatMontantCFA(_montantLigne),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text(
                'Total ventilé',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                formatMontantCFA(_totalVentile),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text(
                'Solde',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                formatMontantCFA(_solde),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      _solde == 0
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableau() {
    final List<Widget> dataRows = [];
    if (_rows.isEmpty) {
      dataRows.add(_buildEmptyVentilationState());
    } else {
      for (var i = 0; i < _rows.length; i++) {
        dataRows.add(_buildDataLigne(i, _rows[i], i == _rows.length - 1));
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildLigneSaisie(), _buildHeadersLigne(), ...dataRows],
        ),
      ),
    );
  }

  Widget _buildEmptyVentilationState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      alignment: Alignment.center,
      child: Text(
        'Aucune ventilation enregistrée pour le moment.',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildLigneSaisie() {
    final bool isFonctionnement = _selectedAxe == 'Fonctionnement';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputCell(
            _buildDropdown<String>(
              value: _selectedAxe,
              items: const ['Projet', 'Fonctionnement'],
              onChanged: (value) {
                setState(() {
                  final bool wasFonctionnement =
                      _selectedAxe == 'Fonctionnement';
                  _selectedAxe = value;
                  if (!wasFonctionnement && value == 'Fonctionnement') {
                    _selectedProjetId = null;
                    _selectedVolet = null;
                    _selectedBailleurId = null;
                    _selectedPosteId = null;
                    _selectedLigneId = null;
                    _montantController.clear();
                    _montantSaisie = _montantLigne;
                    _rows.removeWhere((row) => row.axe == 'Fonctionnement');
                  }
                  if (wasFonctionnement && value != 'Fonctionnement') {
                    _montantSaisie = 0;
                    _rows.removeWhere((row) => row.axe == 'Fonctionnement');
                  }
                });
              },
              label: 'Axe',
            ),
            _columnWidths[0],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField('Projet')
                : _buildAutocompleteDropdown(
                  value: _selectedProjetId,
                  items: _projets,
                  displayField: 'intitule',
                  idField: 'id',
                  onChanged: (id) {
                    setState(() {
                      _selectedProjetId = id;
                      _selectedBailleurId = null;
                      _selectedPosteId = null;
                      _selectedLigneId = null;
                    });
                    if (id != null) {
                      _loadBailleurs();
                      _loadPostes();
                    }
                  },
                  label: 'Projet',
                ),
            _columnWidths[1],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField('Volet')
                : _buildDropdown<String>(
                  value: _selectedVolet,
                  items: const ['Administration', 'Activités'],
                  onChanged: (value) => setState(() => _selectedVolet = value),
                  label: 'Volet',
                ),
            _columnWidths[2],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField('Bailleur')
                : _buildAutocompleteDropdown(
                  value: _selectedBailleurId,
                  items: _bailleurs,
                  displayField: 'designation',
                  idField: 'id',
                  onChanged: (id) => setState(() => _selectedBailleurId = id),
                  label: 'Bailleur',
                ),
            _columnWidths[3],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField('Poste')
                : _buildAutocompleteDropdown(
                  value: _selectedPosteId,
                  items: _postes,
                  displayField: 'intitule',
                  idField: 'id',
                  onChanged: (id) {
                    setState(() {
                      _selectedPosteId = id;
                      _selectedLigneId = null;
                      if (id == null) {
                        _lignes = [];
                      }
                    });
                    if (id != null) {
                      _loadLignes();
                    }
                  },
                  label: 'Poste',
                  allowEmpty: true,
                  emptyLabel: 'Aucun poste',
                ),
            _columnWidths[4],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField('Ligne')
                : _buildAutocompleteDropdown(
                  value: _selectedLigneId,
                  items: _lignes,
                  displayField: 'intitule',
                  idField: 'id',
                  onChanged: (id) => setState(() => _selectedLigneId = id),
                  label: 'Ligne',
                  allowEmpty: true,
                  emptyLabel: 'Aucune ligne',
                ),
            _columnWidths[5],
          ),
          _buildInputCell(
            isFonctionnement
                ? _buildReadOnlyField(
                  'Montant',
                  value: formatMontantCFA(_montantLigne),
                )
                : _buildAmountField(),
            _columnWidths[6],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children:
                    isFonctionnement
                        ? [
                          SizedBox(
                            width: 180,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _enregistrerLigne,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Valider', softWrap: false),
                              ),
                            ),
                          ),
                        ]
                        : [
                          SizedBox(
                            width: 160,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _equilibrer,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Équilibrer',
                                  softWrap: false,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _enregistrerLigne,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Ajouter', softWrap: false),
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

  Widget _buildReadOnlyField(String label, {String value = '—'}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      child: Text(
        value,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _montantController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: 'Montant',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: (value) {
        setState(() {
          final sanitized = value.replaceAll(' ', '').replaceAll(',', '.');
          _montantSaisie = double.tryParse(sanitized) ?? 0;
        });
      },
    );
  }

  Widget _buildHeadersLigne() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Axe', _columnWidths[0]),
          _buildHeaderCell('Projet', _columnWidths[1]),
          _buildHeaderCell('Volet', _columnWidths[2]),
          _buildHeaderCell('Bailleur', _columnWidths[3]),
          _buildHeaderCell('Poste budgétaire', _columnWidths[4]),
          _buildHeaderCell('Ligne budgétaire', _columnWidths[5]),
          _buildHeaderCell('Montant', _columnWidths[6], align: TextAlign.right),
          _buildHeaderCell(
            'Actions',
            _columnWidths[7],
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataLigne(int index, _VentilationRow row, bool isLast) {
    final Color backgroundColor =
        index.isEven ? Colors.white : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildDataCell(row.axe ?? '—', _columnWidths[0]),
          _buildDataCell(row.projetIntitule ?? '—', _columnWidths[1]),
          _buildDataCell(row.volet ?? '—', _columnWidths[2]),
          _buildDataCell(row.bailleur ?? '—', _columnWidths[3]),
          _buildDataCell(row.poste ?? '—', _columnWidths[4]),
          _buildDataCell(row.ligne ?? '—', _columnWidths[5]),
          _buildDataCell(
            formatMontantCFA(row.montant ?? 0),
            _columnWidths[6],
            align: TextAlign.right,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(
            width: _columnWidths[7],
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              tooltip: 'Supprimer la ventilation',
              onPressed: () => setState(() => _rows.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }

  Widget _buildHeaderCell(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        textAlign: align,
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: fontWeight),
        overflow: TextOverflow.ellipsis,
        textAlign: align,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String label,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items:
          items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildAutocompleteDropdown({
    required int? value,
    required List<dynamic> items,
    required String displayField,
    required String idField,
    required Function(int?) onChanged,
    required String label,
    bool allowEmpty = false,
    String emptyLabel = 'Aucun',
  }) {
    final menuItems = <DropdownMenuItem<int?>>[];

    if (allowEmpty) {
      menuItems.add(
        DropdownMenuItem<int?>(value: null, child: Text(emptyLabel)),
      );
    }

    for (final item in items) {
      final dynamic rawId = item[idField];
      final int? itemId = rawId is int ? rawId : int.tryParse('$rawId');
      final String labelText =
          (item[displayField] ?? '').toString().isEmpty
              ? '—'
              : item[displayField].toString();
      menuItems.add(
        DropdownMenuItem<int?>(value: itemId, child: Text(labelText)),
      );
    }

    return DropdownButtonFormField<int?>(
      value: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: menuItems.isEmpty ? null : menuItems,
      onChanged: menuItems.isEmpty ? null : onChanged,
    );
  }
}

/// Helper class for ventilation row data
class _VentilationRow {
  String? axe;
  int? projetId;
  String? projetIntitule;
  String? volet;
  int? bailleurId;
  String? bailleur;
  int? posteId;
  String? poste;
  int? ligneId;
  String? ligne;
  double? montant;

  _VentilationRow({
    this.axe,
    this.projetId,
    this.projetIntitule,
    this.volet,
    this.bailleurId,
    this.bailleur,
    this.posteId,
    this.poste,
    this.ligneId,
    this.ligne,
    this.montant = 0,
  });
}
