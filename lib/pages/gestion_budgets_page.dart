import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class GestionBudgetsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const GestionBudgetsPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
  });

  @override
  State<GestionBudgetsPage> createState() => _GestionBudgetsPageState();
}

class _GestionBudgetsPageState extends State<GestionBudgetsPage> {
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _projets = [];
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();

  bool get _canCreate => _hasPermission('creation');
  bool get _canUpdate => _hasPermission('modification');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'gestion_budgets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final budgets = await AuthService.getBudgetsWithDetails();
      final projets = await AuthService.getProjetsWithBailleur();
      final bailleurs = await AuthService.getBailleurs();

      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _projets = projets;
        _bailleurs =
            bailleurs
                .map(
                  (b) => {
                    'id': b.id,
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Unused - replaced by _createBudgetWithIds
  // This method is kept for reference but no longer used

  Future<void> _deleteBudget(int budgetId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce budget ?',
            ),
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
        await AuthService.deleteBudget(budgetId);
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget supprimé'),
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
  }

  void _showCreateBudgetDialog() {
    int? selectedProjetId;
    int? selectedBailleurId;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Créer un nouveau budget'),
            content: StatefulBuilder(
              builder:
                  (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedProjetId,
                        hint: const Text('Sélectionner un projet'),
                        items:
                            _projets
                                .where((p) => p['deleted_at'] == null)
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p['id'] as int,
                                    child: Text(
                                      '${p['code']} - ${p['designation']}',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => selectedProjetId = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Projet *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedBailleurId,
                        hint: const Text('Sélectionner un bailleur'),
                        items:
                            _bailleurs
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b['id'] as int,
                                    child: Text(
                                      '${b['sigle']} - ${b['designation']}',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => selectedBailleurId = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Bailleur *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                onPressed:
                    selectedProjetId != null && selectedBailleurId != null
                        ? () {
                          _createBudgetWithIds(
                            selectedProjetId!,
                            selectedBailleurId!,
                          );
                          if (mounted) Navigator.pop(context);
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Créer'),
              ),
            ],
          ),
    );
  }

  Future<void> _createBudgetWithIds(int projetId, int bailleurId) async {
    try {
      await AuthService.createBudget(
        projetId: projetId,
        bailleurId: bailleurId,
      );
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget créé avec succès'),
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

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.isControlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyN &&
              _canCreate) {
            _showCreateBudgetDialog();
          }
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Gestion des Budgets'),
                  backgroundColor: Colors.indigo,
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bouton créer budget
                        if (_canCreate)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: _showCreateBudgetDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Nouveau Budget (Ctrl+N)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        // Liste des budgets
                        if (_budgets.isEmpty)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun budget',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _budgets.length,
                            itemBuilder: (context, index) {
                              final budget = _budgets[index];
                              return BudgetCard(
                                budget: budget,
                                onEdit: () => _showBudgetDetails(budget),
                                onDelete:
                                    () => _deleteBudget(budget['id'] as int),
                                canUpdate: _canUpdate,
                                canDelete: _canDelete,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  void _showBudgetDetails(Map<String, dynamic> budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BudgetDetailsPage(
              budget: budget,
              userSession: widget.userSession,
              onRefresh: _loadData,
            ),
      ),
    );
  }
}

class BudgetCard extends StatelessWidget {
  final Map<String, dynamic> budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canUpdate;
  final bool canDelete;

  const BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
    required this.canUpdate,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.attach_money, color: Colors.indigo),
        title: Text(
          '${budget['projet_code']} - ${budget['bailleur_sigle']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${budget['projet_designation']} / ${budget['bailleur_designation']}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUpdate)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.indigo),
                onPressed: onEdit,
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;
  final UserSession? userSession;
  final VoidCallback onRefresh;

  const BudgetDetailsPage({
    required this.budget,
    this.userSession,
    required this.onRefresh,
  });

  @override
  State<BudgetDetailsPage> createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> {
  List<Map<String, dynamic>> _postes = [];
  bool _isLoading = false;
  double _montantTotal = 0.0;

  bool get _canCreate => _hasPermission('creation');
  bool get _canUpdate => _hasPermission('modification');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'gestion_budgets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadPostes();
  }

  Future<void> _loadPostes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final postes = await AuthService.getPostesBudgetaires(
        widget.budget['id'] as int,
      );
      final montant = await AuthService.getMontantBudget(
        widget.budget['id'] as int,
      );

      if (!mounted) return;
      setState(() {
        _postes = postes;
        _montantTotal = montant;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createPoste() async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nouveau poste budgétaire'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Intitulé *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed:
                    controller.text.isNotEmpty
                        ? () => Navigator.pop(context, true)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Créer'),
              ),
            ],
          ),
    );

    if (confirm == true && controller.text.isNotEmpty) {
      try {
        await AuthService.createPosteBudgetaire(
          budgetId: widget.budget['id'] as int,
          intitule: controller.text,
        );
        _loadPostes();
        widget.onRefresh();
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
  }

  Future<void> _deletePoste(int posteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce poste ?',
            ),
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
        await AuthService.deletePosteBudgetaire(posteId);
        _loadPostes();
        widget.onRefresh();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.budget['projet_code']} - ${widget.budget['bailleur_sigle']}',
        ),
        backgroundColor: Colors.indigo,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info budget
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Montant total du budget',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_montantTotal.toStringAsFixed(2)} XOF',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Bouton créer poste
                      if (_canCreate)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ElevatedButton.icon(
                            onPressed: _createPoste,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un poste'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      // Liste des postes
                      if (_postes.isEmpty)
                        Center(
                          child: Text(
                            'Aucun poste budgétaire',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _postes.length,
                          itemBuilder: (context, index) {
                            final poste = _postes[index];
                            return PosteBudgetaireCard(
                              poste: poste,
                              budgetId: widget.budget['id'] as int,
                              onDelete: () => _deletePoste(poste['id'] as int),
                              onUpdate: _loadPostes,
                              userSession: widget.userSession,
                              canUpdate: _canUpdate,
                              canDelete: _canDelete,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class PosteBudgetaireCard extends StatefulWidget {
  final Map<String, dynamic> poste;
  final int budgetId;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;
  final UserSession? userSession;
  final bool canUpdate;
  final bool canDelete;

  const PosteBudgetaireCard({
    required this.poste,
    required this.budgetId,
    required this.onDelete,
    required this.onUpdate,
    this.userSession,
    required this.canUpdate,
    required this.canDelete,
  });

  @override
  State<PosteBudgetaireCard> createState() => _PosteBudgetaireCardState();
}

class _PosteBudgetaireCardState extends State<PosteBudgetaireCard> {
  List<Map<String, dynamic>> _lignes = [];
  bool _isExpanded = false;
  bool _isLoadingLignes = false;
  double _montantPoste = 0.0;

  Future<void> _loadLignes() async {
    setState(() => _isLoadingLignes = true);

    try {
      final lignes = await AuthService.getLignesBudgetaires(
        widget.poste['id'] as int,
      );
      final montant = await AuthService.getMontantPosteBudgetaire(
        widget.poste['id'] as int,
      );

      if (mounted) {
        setState(() {
          _lignes = lignes;
          _montantPoste = montant;
          _isLoadingLignes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLignes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createLigne() async {
    final codeController = TextEditingController();
    final intituleController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nouvelle ligne budgétaire'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: intituleController,
                  decoration: InputDecoration(
                    labelText: 'Intitulé *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed:
                    codeController.text.isNotEmpty &&
                            intituleController.text.isNotEmpty
                        ? () => Navigator.pop(context, true)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Créer'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await AuthService.createLigneBudgetaire(
          posteBudgetaireId: widget.poste['id'] as int,
          code: codeController.text,
          intitule: intituleController.text,
        );
        _loadLignes();
        widget.onUpdate();
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
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.folder, color: Colors.indigo),
            title: Text(widget.poste['intitule'] as String),
            subtitle: Text('Montant: ${_montantPoste.toStringAsFixed(2)} XOF'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.indigo,
                  ),
                  onPressed: () {
                    if (!_isExpanded) {
                      _loadLignes();
                    }
                    setState(() => _isExpanded = !_isExpanded);
                  },
                ),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.canUpdate)
                    ElevatedButton.icon(
                      onPressed: _createLigne,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une ligne'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_isLoadingLignes)
                    const Center(child: CircularProgressIndicator())
                  else if (_lignes.isEmpty)
                    Text(
                      'Aucune ligne',
                      style: TextStyle(color: Colors.grey.shade500),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lignes.length,
                      itemBuilder: (context, index) {
                        final ligne = _lignes[index];
                        return LigneBudgetaireCard(
                          ligne: ligne,
                          onUpdate: _loadLignes,
                          userSession: widget.userSession,
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LigneBudgetaireCard extends StatefulWidget {
  final Map<String, dynamic> ligne;
  final VoidCallback onUpdate;
  final UserSession? userSession;

  const LigneBudgetaireCard({
    required this.ligne,
    required this.onUpdate,
    this.userSession,
  });

  @override
  State<LigneBudgetaireCard> createState() => _LigneBudgetaireCardState();
}

class _LigneBudgetaireCardState extends State<LigneBudgetaireCard> {
  List<Map<String, dynamic>> _sousRubriques = [];
  bool _isExpanded = false;
  bool _isLoadingSousRubriques = false;
  double _montantLigne = 0.0;

  Future<void> _loadSousRubriques() async {
    setState(() => _isLoadingSousRubriques = true);

    try {
      final sousRubriques = await AuthService.getSousRubriques(
        widget.ligne['id'] as int,
      );
      final montant = await AuthService.getMontantLigneBudgetaire(
        widget.ligne['id'] as int,
      );

      if (mounted) {
        setState(() {
          _sousRubriques = sousRubriques;
          _montantLigne = montant;
          _isLoadingSousRubriques = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSousRubriques = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.list, color: Colors.orange),
            title: Text(
              '${widget.ligne['code']} - ${widget.ligne['intitule']}',
            ),
            subtitle: Text('Montant: ${_montantLigne.toStringAsFixed(2)} XOF'),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.orange,
              ),
              onPressed: () {
                if (!_isExpanded) {
                  _loadSousRubriques();
                }
                setState(() => _isExpanded = !_isExpanded);
              },
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SousRubriquesSection(
                ligneBudgetaireId: widget.ligne['id'] as int,
                sousRubriques: _sousRubriques,
                isLoading: _isLoadingSousRubriques,
                onUpdate: () {
                  _loadSousRubriques();
                  widget.onUpdate();
                },
                userSession: widget.userSession,
              ),
            ),
        ],
      ),
    );
  }
}

class SousRubriquesSection extends StatefulWidget {
  final int ligneBudgetaireId;
  final List<Map<String, dynamic>> sousRubriques;
  final bool isLoading;
  final VoidCallback onUpdate;
  final UserSession? userSession;

  const SousRubriquesSection({
    required this.ligneBudgetaireId,
    required this.sousRubriques,
    required this.isLoading,
    required this.onUpdate,
    this.userSession,
  });

  @override
  State<SousRubriquesSection> createState() => _SousRubriquesSection();
}

class _SousRubriquesSection extends State<SousRubriquesSection> {
  List<Map<String, dynamic>> _comptes = [];
  bool _isLoadingComptes = false;

  bool get _canCreate => _hasPermission('creation');

  bool _hasPermission(String type) {
    if (widget.userSession == null) return true;
    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'gestion_budgets',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  Future<void> _loadComptes() async {
    if (_comptes.isNotEmpty) return;

    setState(() => _isLoadingComptes = true);
    try {
      final comptes = await AuthService.getComptes();
      if (mounted) {
        setState(() {
          _comptes =
              comptes
                  .map(
                    (c) => {
                      'id': c.id,
                      'numero_compte': c.numeroCompte,
                      'intitule': c.intitule,
                    },
                  )
                  .toList();
          _isLoadingComptes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComptes = false);
      }
    }
  }

  Future<void> _createSousRubrique() async {
    await _loadComptes();

    final intituleController = TextEditingController();
    final montantController = TextEditingController();
    Map<String, dynamic>? selectedCompte;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nouvelle sous-rubrique'),
            content: StatefulBuilder(
              builder:
                  (context, setState) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: montantController,
                          decoration: InputDecoration(
                            labelText: 'Montant *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isLoadingComptes
                            ? const CircularProgressIndicator()
                            : DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedCompte,
                              hint: const Text('Sélectionner un compte'),
                              items:
                                  _comptes
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            '${c['numero_compte']} - ${c['intitule']}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() => selectedCompte = value);
                              },
                              decoration: InputDecoration(
                                labelText: 'Compte',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed:
                    intituleController.text.isNotEmpty &&
                            montantController.text.isNotEmpty
                        ? () => Navigator.pop(context, true)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Créer'),
              ),
            ],
          ),
    );

    if (confirm == true && intituleController.text.isNotEmpty) {
      try {
        await AuthService.createSousRubrique(
          ligneBudgetaireId: widget.ligneBudgetaireId,
          intitule: intituleController.text,
          montant: double.tryParse(montantController.text) ?? 0.0,
          compteId: selectedCompte?['id'] as int?,
        );
        widget.onUpdate();
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_canCreate)
          ElevatedButton.icon(
            onPressed: _createSousRubrique,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une sous-rubrique'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 12),
        if (widget.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (widget.sousRubriques.isEmpty)
          Text(
            'Aucune sous-rubrique',
            style: TextStyle(color: Colors.grey.shade500),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.sousRubriques.length,
            itemBuilder: (context, index) {
              final sousRubrique = widget.sousRubriques[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.attach_money, color: Colors.green),
                  title: Text(sousRubrique['intitule'] as String),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Montant: ${(sousRubrique['montant'] as num).toDouble().toStringAsFixed(2)} XOF',
                      ),
                      if (sousRubrique['numero_compte'] != null)
                        Text(
                          'Compte: ${sousRubrique['numero_compte']} - ${sousRubrique['compte_intitule']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
