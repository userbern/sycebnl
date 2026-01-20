import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service_new.dart' as db_service;
import '../models/journal.dart';
import '../models/compte.dart';
import '../models/user_session.dart';
import '../utils/form_enter_shortcut.dart';

class JournauxPage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const JournauxPage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<JournauxPage> createState() => _JournauxPageState();
}

class _JournauxPageState extends State<JournauxPage> {
  final FocusNode _focusNode = FocusNode();
  List<Journal> journaux = [];
  List<Compte> comptes = [];
  bool isLoading = true;
  String searchQuery = '';
  String? _selectedType;
  String _filterStatus = 'actifs';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final result = await AuthService.getJournaux();
      final comptesList = await db_service.DatabaseService.getAllComptes();
      if (!mounted) return;
      setState(() {
        journaux = result;
        comptes = comptesList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      setState(() => isLoading = false);
    }
  }

  List<Journal> get _filteredJournaux {
    var filtered = journaux;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered =
          filtered
              .where(
                (j) =>
                    j.code.toLowerCase().contains(query) ||
                    j.intitule.toLowerCase().contains(query),
              )
              .toList();
    }

    if (_selectedType != null) {
      final typeFilter =
          _selectedType == 'financier'
              ? TypeJournal.financier
              : TypeJournal.nonFinancier;
      filtered = filtered.where((j) => j.type == typeFilter).toList();
    }

    if (_filterStatus == 'actifs') {
      filtered = filtered.where((j) => j.isActive).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((j) => !j.isActive).toList();
    }

    return filtered;
  }

  Future<void> _deleteJournal(String id, String intitule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Êtes-vous sûr de supprimer "$intitule"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await AuthService.deleteJournal(int.parse(id));
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Journal supprimé')));
      } catch (e) {
        if (!mounted) return;
        final errorMessage = e.toString();
        String displayMessage = 'Erreur: ${e.toString()}';

        if (errorMessage.contains('ne peut pas être supprimé')) {
          displayMessage =
              'Ce journal contient des écritures et ne peut pas être supprimé';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayMessage)));
      }
    }
  }

  Color _getTypeColor(TypeJournal type) {
    switch (type) {
      case TypeJournal.financier:
        return Colors.green;
      case TypeJournal.nonFinancier:
        return Colors.orange;
    }
  }

  void _showJournalDialog(Journal? journal) {
    showDialog(
      context: context,
      builder:
          (context) => JournalDialog(
            journal: journal,
            comptes: comptes,
            onSave: (updatedJournal) {
              _loadData();
              Navigator.pop(context);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showJournalDialog(null);
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Journaux comptables'),
                  backgroundColor: Colors.blue.shade400,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                )
                : null,
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Codes Journaux',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _showJournalDialog(null),
                                icon: const Icon(Icons.add),
                                label: const Text('Nouveau (Ctrl+N)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() => searchQuery = value);
                                  },
                                  decoration: InputDecoration(
                                    labelText:
                                        'Rechercher par code ou intitulé',
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: 'Type de journal',
                                    prefixIcon: const Icon(Icons.category),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Tous les types'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'financier',
                                      child: Text('Financier'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'non_financier',
                                      child: Text('Non Financier'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedType = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Statut',
                                    prefixIcon: const Icon(Icons.filter_alt),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'actifs',
                                      child: Text('Journaux actifs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactifs',
                                      child: Text('Journaux inactifs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'tous',
                                      child: Text('Tous'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStatus = value ?? 'actifs',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 44,
                                child: IconButton(
                                  tooltip: 'Réinitialiser',
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = '';
                                      _selectedType = null;
                                      _filterStatus = 'actifs';
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _filteredJournaux.isEmpty
                              ? Center(
                                child: Text(
                                  searchQuery.isEmpty
                                      ? 'Aucun journal. Cliquez sur "Nouveau" ou Ctrl+N'
                                      : 'Aucun journal trouvé',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : LayoutBuilder(
                                builder: (context, constraints) {
                                  final double availableWidth =
                                      constraints.maxWidth;
                                  final double horizontalPadding =
                                      (availableWidth * 0.05)
                                          .clamp(16, 80)
                                          .toDouble();
                                  final double tableWidth =
                                      availableWidth - (horizontalPadding * 2);
                                  final double columnSpacing =
                                      (tableWidth * 0.02)
                                          .clamp(12, 40)
                                          .toDouble();

                                  double clampWidth(
                                    double value,
                                    double min,
                                    double preferredMaxFactor,
                                  ) {
                                    final double preferredMax =
                                        tableWidth * preferredMaxFactor;
                                    final double upper = math.max(
                                      min,
                                      preferredMax,
                                    );
                                    return value.clamp(min, upper).toDouble();
                                  }

                                  final double codeWidth = clampWidth(
                                    tableWidth * 0.18,
                                    120,
                                    0.24,
                                  );
                                  final double intituleWidth = clampWidth(
                                    tableWidth * 0.32,
                                    200,
                                    0.38,
                                  );
                                  final double typeWidth = clampWidth(
                                    tableWidth * 0.18,
                                    140,
                                    0.24,
                                  );
                                  final double saisieWidth = clampWidth(
                                    tableWidth * 0.16,
                                    120,
                                    0.22,
                                  );
                                  final double actionsWidth = clampWidth(
                                    tableWidth * 0.16,
                                    120,
                                    0.20,
                                  );

                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: SizedBox(
                                            width: tableWidth,
                                            child: DataTable(
                                              columnSpacing: columnSpacing,
                                              horizontalMargin: 24,
                                              dataRowMinHeight: 28,
                                              dataRowMaxHeight: 40,
                                              headingRowColor:
                                                  MaterialStateProperty.all(
                                                    Colors.blue.shade400,
                                                  ),
                                              headingTextStyle: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              columns: const [
                                                DataColumn(label: Text('Code')),
                                                DataColumn(
                                                  label: Text('Intitulé'),
                                                ),
                                                DataColumn(label: Text('Type')),
                                                DataColumn(
                                                  label: Text(
                                                    'Saisie Analytique',
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text('Actions'),
                                                ),
                                              ],
                                              rows:
                                                  _filteredJournaux
                                                      .map(
                                                        (j) => DataRow(
                                                          cells: [
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    codeWidth,
                                                                child: Text(
                                                                  j.code,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    intituleWidth,
                                                                child: Text(
                                                                  j.intitule,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    typeWidth,
                                                                child: Text(
                                                                  j.type
                                                                      .toLabel(),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    color:
                                                                        _getTypeColor(
                                                                          j.type,
                                                                        ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    saisieWidth,
                                                                child: Center(
                                                                  child:
                                                                      j.saisieAnalytique
                                                                          ? const Icon(
                                                                            Icons.check_circle,
                                                                            color:
                                                                                Colors.green,
                                                                          )
                                                                          : const Icon(
                                                                            Icons.cancel,
                                                                            color:
                                                                                Colors.red,
                                                                          ),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    actionsWidth,
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerLeft,
                                                                  child: PopupMenuButton(
                                                                    itemBuilder:
                                                                        (
                                                                          context,
                                                                        ) => [
                                                                          PopupMenuItem(
                                                                            onTap:
                                                                                () => _showJournalDialog(j),
                                                                            child: const Row(
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.edit,
                                                                                  size:
                                                                                      16,
                                                                                ),
                                                                                SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Text(
                                                                                  'Modifier',
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          PopupMenuItem(
                                                                            onTap:
                                                                                () => _deleteJournal(
                                                                                  j.id,
                                                                                  j.intitule,
                                                                                ),
                                                                            child: const Row(
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.delete,
                                                                                  size:
                                                                                      16,
                                                                                  color:
                                                                                      Colors.red,
                                                                                ),
                                                                                SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Text(
                                                                                  'Supprimer',
                                                                                  style: TextStyle(
                                                                                    color:
                                                                                        Colors.red,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class JournalDialog extends StatefulWidget {
  final Journal? journal;
  final List<Compte> comptes;
  final Function(Journal) onSave;

  const JournalDialog({
    super.key,
    this.journal,
    required this.comptes,
    required this.onSave,
  });

  @override
  State<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends State<JournalDialog> {
  late TextEditingController _codeController;
  late TextEditingController _intituleController;
  late TextEditingController _compteFresorerieController;
  TypeJournal? _selectedType;
  Compte? _selectedCompteFresorerie;
  bool _saisieAnalytique = false;
  bool _isSaving = false;
  String? _compteError;
  final _formKey = GlobalKey<FormState>();
  Timer? _debounceTimer;
  bool _compteFieldInitialized = false;

  Future<void> _showCompteCreationDialog() async {
    final numeroController = TextEditingController();
    final intituleController = TextEditingController();
    final descriptionController = TextEditingController();
    TypeCompte selectedType = TypeCompte.detail;
    NatureCompte? calculatedNature;
    bool liaisonTiers = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fonction de soumission pour FormWithEnterShortcut
            Future<void> handleSubmit() async {
              if (formKey.currentState!.validate()) {
                if (calculatedNature == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Numéro de compte invalide'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Récupérer la longueur de compte depuis la config
                  final config =
                      await db_service.DatabaseService.getFileConfig();
                  final longueurCompteGeneral =
                      config?['longueur_compte_general'] as int? ?? 7;

                  // Padding du numéro de compte
                  String paddedNumero = numeroController.text.trim();
                  if (selectedType == TypeCompte.detail &&
                      paddedNumero.length < longueurCompteGeneral) {
                    paddedNumero = paddedNumero.padRight(
                      longueurCompteGeneral,
                      '0',
                    );
                  }

                  // Créer le compte
                  await db_service.DatabaseService.createCompte(
                    numeroCompte: paddedNumero,
                    intitule: intituleController.text.trim(),
                    type: selectedType.toDbString(),
                    nature: calculatedNature!.toDbString(),
                    liaisonTiers: liaisonTiers,
                    description:
                        descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                  );

                  // Récupérer le nouveau compte créé
                  final allComptes =
                      await db_service.DatabaseService.getAllComptes();
                  final newCompte = allComptes.firstWhere(
                    (c) => c.numeroCompte == paddedNumero,
                    orElse:
                        () => allComptes.firstWhere(
                          (c) => c.numeroCompte.startsWith(
                            numeroController.text.trim(),
                          ),
                        ),
                  );

                  // Mettre à jour l'état local et le parent
                  if (!context.mounted) return;

                  setState(() {
                    widget.comptes.add(newCompte);
                    _selectedCompteFresorerie = newCompte;
                    _compteFresorerieController.text =
                        '${newCompte.numeroCompte} - ${newCompte.intitule}';
                    _compteError = null;
                  });

                  // Fermer le dialogue
                  Navigator.pop(context);

                  // Confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Compte $paddedNumero créé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return FormWithEnterShortcut(
              formKey: formKey,
              onSubmit: handleSubmit,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.indigo.shade700),
                    const SizedBox(width: 12),
                    const Text(
                      'Nouveau compte de trésorerie',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Numéro de compte
                          TextFormField(
                            controller: numeroController,
                            decoration: InputDecoration(
                              labelText: 'N° Compte *',
                              prefixIcon: const Icon(Icons.numbers),
                              hintText: 'Ex: 52100, 57100, 53000...',
                              helperText: 'Doit commencer par 52, 57 ou 50-59',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Champ requis';
                              }
                              if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                return 'Seuls les chiffres sont autorisés';
                              }
                              // Vérifier que c'est un compte de trésorerie
                              final isTresorerie = [
                                '52',
                                '57',
                                '50',
                                '51',
                                '53',
                                '55',
                                '56',
                                '58',
                                '59',
                              ].any((prefix) => value.startsWith(prefix));

                              if (!isTresorerie) {
                                return 'Le compte doit être de trésorerie (classe 5)';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setDialogState(() {
                                calculatedNature =
                                    calculateNatureFromNumeroCompte(value);
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Intitulé
                          TextFormField(
                            controller: intituleController,
                            decoration: InputDecoration(
                              labelText: 'Intitulé *',
                              prefixIcon: const Icon(Icons.title),
                              hintText: 'Ex: Caisse principale, Banque ABC...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Champ requis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Type (fixé à "détail" pour les comptes de trésorerie)
                          DropdownButtonFormField<TypeCompte>(
                            value: selectedType,
                            decoration: InputDecoration(
                              labelText: 'Type',
                              prefixIcon: const Icon(Icons.category),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.arrow_drop_down_circle,
                              color: Colors.indigo.shade700,
                            ),
                            items:
                                TypeCompte.values.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type.toLabel()),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedType = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Nature (auto-détectée)
                          DropdownButtonFormField<NatureCompte>(
                            value: calculatedNature,
                            decoration: InputDecoration(
                              labelText: 'Nature *',
                              prefixIcon: const Icon(Icons.layers),
                              helperText: 'Auto-détecté du numéro de compte',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.arrow_drop_down_circle,
                              color: Colors.indigo.shade700,
                            ),
                            items:
                                NatureCompte.values.map((nature) {
                                  return DropdownMenuItem(
                                    value: nature,
                                    child: Text(nature.toLabel()),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  calculatedNature = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Sélectionnez une nature';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.notes),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Rattachement de tiers
                          CheckboxListTile(
                            title: const Text('Rattachement de tiers'),
                            subtitle: const Text(
                              'Permet de rattacher un tiers à ce compte',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: liaisonTiers,
                            onChanged: (value) {
                              setDialogState(() {
                                liaisonTiers = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            tileColor: Colors.grey.shade50,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Créer le compte'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final journal = widget.journal;
    _codeController = TextEditingController(text: journal?.code ?? '');
    _intituleController = TextEditingController(text: journal?.intitule ?? '');
    _compteFresorerieController = TextEditingController();
    _selectedType = journal?.type ?? TypeJournal.financier;
    _saisieAnalytique = journal?.saisieAnalytique ?? false;

    // DEBUG
    print('📝 DEBUG initState - Journal: ${journal?.code}');
    print('📝 DEBUG - compteTresorerie value: "${journal?.compteTresorerie}"');
    print(
      '📝 DEBUG - compteTresorerie null: ${journal?.compteTresorerie == null}',
    );
    print(
      '📝 DEBUG - compteTresorerie empty: ${journal?.compteTresorerie?.isEmpty}',
    );

    // Chercher le compte de trésorerie si édition
    if (journal?.compteTresorerie != null &&
        journal!.compteTresorerie!.isNotEmpty) {
      try {
        print('📝 DEBUG - Cherchant compte: "${journal.compteTresorerie}"');
        _selectedCompteFresorerie = widget.comptes.firstWhere(
          (c) => c.numeroCompte == journal.compteTresorerie,
        );
        print(
          '📝 DEBUG - Compte trouvé: ${_selectedCompteFresorerie!.numeroCompte}',
        );
        _compteFresorerieController.text =
            '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
      } catch (e) {
        // Compte non trouvé
        print('📝 DEBUG - Compte non trouvé: $e');
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _intituleController.dispose();
    _compteFresorerieController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _searchCompteFresorerie(String input) {
    if (input.isEmpty) {
      setState(() {
        _selectedCompteFresorerie = null;
        _compteError = null;
      });
      return;
    }

    final comptesFresorerie = _getFilteredComptes();
    final matching =
        comptesFresorerie
            .where((c) => c.numeroCompte.startsWith(input))
            .toList();

    setState(() {
      if (matching.isEmpty) {
        _selectedCompteFresorerie = null;
        _compteError = 'Compte "$input" non trouvé dans le plan comptable';
      } else if (matching.length == 1) {
        _selectedCompteFresorerie = matching.first;
        _compteError = null;
      } else {
        _selectedCompteFresorerie = null;
        _compteError = 'Plusieurs comptes trouvés, soyez plus précis';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation supplémentaire
    if (_codeController.text.isEmpty ||
        _intituleController.text.isEmpty ||
        _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les champs obligatoires doivent être remplis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Si type financier, vérifier que compte de trésorerie est sélectionné
    if (_selectedType == TypeJournal.financier &&
        _selectedCompteFresorerie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte de trésorerie requis pour journal financier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.journal == null) {
        // Créer
        await AuthService.createJournal(
          code: _codeController.text,
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
          saisieAnalytique: _saisieAnalytique,
        );
      } else {
        // Modifier
        await AuthService.updateJournal(
          id: int.parse(widget.journal!.id),
          code: _codeController.text,
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
          saisieAnalytique: _saisieAnalytique,
        );
      }

      if (!mounted) return;
      widget.onSave(
        widget.journal ??
            Journal(
              id: '',
              code: _codeController.text,
              intitule: _intituleController.text,
              type: _selectedType!,
              compteTresorerie: _selectedCompteFresorerie?.numeroCompte,
              saisieAnalytique: _saisieAnalytique,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.journal != null;

    return FormWithEnterShortcut(
      formKey: _formKey,
      onSubmit: _save,
      enabled: !_isSaving,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              isEditing ? Icons.edit : Icons.add_circle,
              color: Colors.indigo.shade700,
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Modifier le journal' : 'Nouveau journal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code et Intitulé
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Code *',
                            prefixIcon: const Icon(Icons.code),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.indigo.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          enabled: !_isSaving,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Champ requis';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.indigo.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          enabled: !_isSaving,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Champ requis';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Type de Journal
                  DropdownButtonFormField<TypeJournal>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type *',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.indigo.shade700,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.arrow_drop_down_circle,
                      color: Colors.indigo.shade700,
                    ),
                    items:
                        TypeJournal.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.toLabel()),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _isSaving
                            ? null
                            : (value) {
                              setState(() => _selectedType = value);
                            },
                    validator: (value) {
                      if (value == null) {
                        return 'Sélectionnez un type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Compte de Trésorerie (seulement si financier)
                  if (_selectedType == TypeJournal.financier)
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Autocomplete<Compte>(
                                displayStringForOption:
                                    (Compte option) =>
                                        '${option.numeroCompte} - ${option.intitule}',
                                optionsBuilder: (
                                  TextEditingValue textEditingValue,
                                ) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Compte>.empty();
                                  }
                                  final comptesFresorerie =
                                      _getFilteredComptes();
                                  return comptesFresorerie.where(
                                    (c) =>
                                        c.numeroCompte.toLowerCase().startsWith(
                                          textEditingValue.text.toLowerCase(),
                                        ),
                                  );
                                },
                                onSelected: (Compte selection) {
                                  setState(() {
                                    _selectedCompteFresorerie = selection;
                                    _compteFresorerieController.text =
                                        '${selection.numeroCompte} - ${selection.intitule}';
                                    _compteError = null;
                                  });
                                },
                                fieldViewBuilder: (
                                  BuildContext context,
                                  TextEditingController textEditingController,
                                  FocusNode focusNode,
                                  VoidCallback onFieldSubmitted,
                                ) {
                                  // Initialiser le texte la première fois si on a un compte sélectionné
                                  if (!_compteFieldInitialized &&
                                      _selectedCompteFresorerie != null) {
                                    _compteFieldInitialized = true;
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      textEditingController.text =
                                          '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                                    });
                                  }

                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    onChanged: (String value) {
                                      _searchCompteFresorerie(value);
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Compte de Trésorerie *',
                                      hintText: 'Tapez le numéro de compte...',
                                      prefixIcon: const Icon(
                                        Icons.account_balance,
                                      ),
                                      errorText: _compteError,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color:
                                              _compteError != null
                                                  ? Colors.red
                                                  : (_selectedCompteFresorerie !=
                                                          null
                                                      ? Colors.green
                                                      : Colors.grey.shade400),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.indigo.shade700,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    enabled: !_isSaving,
                                    validator: (value) {
                                      if (_selectedType ==
                                              TypeJournal.financier &&
                                          _selectedCompteFresorerie == null) {
                                        return _compteError ??
                                            'Sélectionnez un compte de trésorerie valide';
                                      }
                                      return null;
                                    },
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
                                      elevation: 4.0,
                                      child: SizedBox(
                                        width: 400,
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (
                                            BuildContext context,
                                            int index,
                                          ) {
                                            final Compte option = options
                                                .elementAt(index);
                                            return InkWell(
                                              onTap: () {
                                                onSelected(option);
                                              },
                                              child: Container(
                                                color:
                                                    index.isEven
                                                        ? Colors.grey.shade50
                                                        : Colors.white,
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      option.numeroCompte,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      option.intitule,
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                        fontSize: 12,
                                                      ),
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
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSaving
                                        ? null
                                        : _showCompteCreationDialog,
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.white,
                                ),
                                label: const Text('Créer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  // Saisie Analytique
                  CheckboxListTile(
                    title: const Text('Saisie Analytique'),
                    value: _saisieAnalytique,
                    onChanged:
                        _isSaving
                            ? null
                            : (value) {
                              setState(
                                () => _saisieAnalytique = value ?? false,
                              );
                            },
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.indigo.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                    : Text(isEditing ? 'Modifier' : 'Créer'),
          ),
        ],
      ),
    );
  }

  NatureCompte _calculateNatureFromNumero(String numero) {
    if (numero.isEmpty) return NatureCompte.bilanBanque;

    // Extraire les 2 premiers chiffres pour les cas spéciaux
    String twoDigitPrefix = '';
    if (numero.length >= 2) {
      twoDigitPrefix = numero.substring(0, 2);
    }

    // Cas spécifiques 2 chiffres
    switch (twoDigitPrefix) {
      case '40':
        return NatureCompte.bilanFournisseurs;
      case '41':
        return NatureCompte.bilanAdherentsClientsUsagers;
      case '42':
        return NatureCompte.bilanPersonnel;
      case '43':
        return NatureCompte.bilanOrganismesSociaux;
      case '44':
        return NatureCompte.bilanEtatCollectivitesPubliques;
      case '45':
      case '46':
      case '47':
      case '48':
      case '49':
        return NatureCompte.bilanAutresTiers;
      case '50':
      case '51':
      case '53':
      case '55':
      case '56':
      case '58':
      case '59':
        return NatureCompte.bilanBanque;
      case '52':
      case '57':
        return NatureCompte.bilanCaisse;
      case '80':
      case '82':
      case '84':
      case '86':
      case '88':
        return NatureCompte.produitsHAO;
      case '81':
      case '83':
      case '85':
      case '87':
      case '89':
        return NatureCompte.chargesHAO;
    }

    // Fallback sur 1er chiffre
    final firstDigit = numero[0];
    switch (firstDigit) {
      case '1':
        return NatureCompte.bilanRessourcesDurables;
      case '2':
        return NatureCompte.bilanActifImmobilise;
      case '3':
        return NatureCompte.bilanStocks;
      case '5':
        return NatureCompte.bilanBanque;
      case '6':
        return NatureCompte.chargesAO;
      case '7':
        return NatureCompte.produitsAO;
      case '8':
        // Pour '8X', vérifier la parité du 2ème chiffre
        if (numero.length >= 2) {
          final secondDigit = int.tryParse(numero[1]) ?? 0;
          if (secondDigit % 2 == 0) {
            return NatureCompte.produitsHAO;
          } else {
            return NatureCompte.chargesHAO;
          }
        }
        return NatureCompte.chargesHAO;
      case '9':
        return NatureCompte.engagementsHorsBilan;
      default:
        return NatureCompte.bilanBanque;
    }
  }

  /*
  void _showCompteSelectionDialog([String? prefilledNumero]) {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              TextEditingController searchController = TextEditingController(
                text: prefilledNumero ?? '',
              );
              List<Compte> filteredComptes = _getFilteredComptes();

              return AlertDialog(
                title: const Text('Sélectionner un compte de trésorerie'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Ex: 41101AB ou 5210',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setDialogState(() {
                                          searchController.clear();
                                        });
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: _buildCompteSelectionList(
                            searchController.text,
                            filteredComptes,
                            setDialogState,
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
                ],
              );
            },
          ),
    );
  }
  */

  List<Compte> _getFilteredComptes() {
    return widget.comptes.where((c) {
      return [
        '52',
        '57',
        '50',
        '51',
        '53',
        '55',
        '56',
        '58',
        '59',
      ].any((prefix) => c.numeroCompte.startsWith(prefix));
    }).toList();
  }

  /*
  Widget _buildCompteSelectionList(
    String searchText,
    List<Compte> filteredComptes,
    Function(VoidCallback) setDialogState,
  ) {
    final numericSearch = _extractNumericPrefix(searchText);

    List<Compte> matchingComptes =
        filteredComptes.where((c) {
          if (numericSearch.isEmpty) return true;
          return c.numeroCompte.startsWith(numericSearch);
        }).toList();

    return Column(
      children: [
        Expanded(
          child:
              matchingComptes.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aucun compte trouvé',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        if (numericSearch.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _showCompteCreationDialog(numericSearch);
                              },
                              icon: const Icon(Icons.add),
                              label: Text('Créer compte $numericSearch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: matchingComptes.length,
                    itemBuilder: (context, index) {
                      final compte = matchingComptes[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.indigo,
                        ),
                        title: Text(compte.numeroCompte),
                        subtitle: Text(compte.intitule),
                        trailing: const Icon(Icons.check_circle_outline),
                        onTap: () {
                          setState(() {
                            _selectedCompteFresorerie = compte;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
  */

  /*
  String _extractNumericPrefix(String input) {
    final regex = RegExp(r'^(\d+)');
    final match = regex.firstMatch(input);
    return match?.group(1) ?? '';
  }

  Future<void> _showCompteCreationDialog(String numeroCompte) async {
    final intituleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Nouveau compte de trésorerie',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: numeroCompte,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'N° Compte',
                            prefixIcon: const Icon(Icons.numbers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            prefixIcon: const Icon(Icons.label),
                            hintText: 'Ex: Banque principale',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.indigo.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'L\'intitulé est requis';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        final nature = _calculateNatureFromNumero(numeroCompte);
                        await db_service.DatabaseService.createCompte(
                          numeroCompte: numeroCompte,
                          intitule: intituleController.text,
                          type: TypeCompte.detail.toDbString(),
                          nature: nature.toDbString(),
                          liaisonTiers: false,
                          description: '',
                        );

                        final allComptes =
                            await db_service.DatabaseService.getAllComptes();
                        final compte = allComptes.firstWhere(
                          (c) => c.numeroCompte == numeroCompte,
                        );

                        if (!mounted) return;

                        setState(() {
                          _selectedCompteFresorerie = compte;
                          widget.comptes.add(compte);
                        });

                        if (!mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Compte $numeroCompte créé avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  */

  /*
  void _showCompteCreationDialogForTresorerie() {
    TextEditingController numeroController = TextEditingController();
    TextEditingController intituleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Créer un nouveau compte'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro du compte',
                    hintText: 'Ex: 52100',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: intituleController,
                  decoration: const InputDecoration(
                    labelText: 'Intitulé du compte',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String numero = numeroController.text.trim();
                final String intitule = intituleController.text.trim();

                if (numero.isEmpty || intitule.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez remplir tous les champs'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Récupérer la longueur de compte depuis la config
                  final config = await db_service.DatabaseService.getConfig();
                  final longueurCompte =
                      config?['longueur_compte_general'] as int? ?? 8;

                  // Compléter le numéro avec des zéros à la fin
                  final numeroPadded = numero.padRight(longueurCompte, '0');

                  final nature = calculateNatureFromNumeroCompte(numeroPadded);
                  if (nature == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Impossible de déterminer la nature du compte',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  await AuthService.createCompte(
                    numeroCompte: numeroPadded,
                    intitule: intitule,
                    type: TypeCompte.detail.toDbString(),
                    nature: nature.toDbString(),
                  );

                  // Récupérer les comptes mis à jour
                  final updatedComptes = await AuthService.getComptes();

                  setState(() {
                    widget.comptes.clear();
                    widget.comptes.addAll(updatedComptes);
                    _selectedCompteFresorerie = updatedComptes.firstWhere(
                      (c) => c.numeroCompte == numeroPadded,
                      orElse: () => updatedComptes.first,
                    );
                    _compteFresorerieController.text =
                        '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                  });

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Compte $numeroPadded créé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }
  */
}
