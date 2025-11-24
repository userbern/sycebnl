import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';
import 'budget_details_page.dart';

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
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _projets = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _selectedBudget;

  // Permissions
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
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les projets
      final projetsResponse = await _supabase
          .from('projet')
          .select()
          .order('code', ascending: true);

      // Charger les budgets avec leurs projets
      final budgetsResponse = await _supabase
          .from('budget')
          .select('*, projet(id, code, designation)')
          .order('code', ascending: true);

      setState(() {
        _projets = List<Map<String, dynamic>>.from(projetsResponse);
        _budgets = List<Map<String, dynamic>>.from(budgetsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBudgetForm({Map<String, dynamic>? budget}) {
    final codeController = TextEditingController(text: budget?['code'] ?? '');
    final designationController = TextEditingController(
      text: budget?['designation'] ?? '',
    );
    final montantController = TextEditingController(
      text: budget?['montant']?.toString() ?? '',
    );
    String? selectedProjetId = budget?['projet_id'];
    String selectedStatut = budget?['statut'] ?? 'brouillon';

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    budget == null ? 'Nouveau Budget' : 'Modifier Budget',
                  ),
                  content: SizedBox(
                    width: 500,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: codeController,
                              decoration: const InputDecoration(
                                labelText: 'Code',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Le code est requis';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: designationController,
                              decoration: const InputDecoration(
                                labelText: 'Désignation',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La désignation est requise';
                                }
                                return null;
                              },
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedProjetId,
                              decoration: const InputDecoration(
                                labelText: 'Projet',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  _projets.map((projet) {
                                    return DropdownMenuItem<String>(
                                      value: projet['id'],
                                      child: Text(
                                        '${projet['code']} - ${projet['designation']}',
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProjetId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Le projet est requis';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: montantController,
                              decoration: const InputDecoration(
                                labelText: 'Montant',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (double.tryParse(value) == null) {
                                    return 'Montant invalide';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedStatut,
                              decoration: const InputDecoration(
                                labelText: 'Statut',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'brouillon',
                                  child: Text('Brouillon'),
                                ),
                                DropdownMenuItem(
                                  value: 'validé',
                                  child: Text('Validé'),
                                ),
                                DropdownMenuItem(
                                  value: 'clôturé',
                                  child: Text('Clôturé'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatut = value!;
                                });
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
                            if (budget == null) {
                              await _supabase.from('budget').insert({
                                'code': codeController.text.trim(),
                                'designation':
                                    designationController.text.trim(),
                                'projet_id': selectedProjetId,
                                'montant':
                                    montantController.text.isNotEmpty
                                        ? double.parse(montantController.text)
                                        : 0,
                                'statut': selectedStatut,
                              });
                            } else {
                              await _supabase
                                  .from('budget')
                                  .update({
                                    'code': codeController.text.trim(),
                                    'designation':
                                        designationController.text.trim(),
                                    'projet_id': selectedProjetId,
                                    'montant':
                                        montantController.text.isNotEmpty
                                            ? double.parse(
                                              montantController.text,
                                            )
                                            : 0,
                                    'statut': selectedStatut,
                                  })
                                  .eq('id', budget['id']);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    budget == null
                                        ? 'Budget créé avec succès'
                                        : 'Budget modifié avec succès',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _deleteBudget(Map<String, dynamic> budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le budget "${budget['code']}" ?\nToutes les données associées seront supprimées.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('budget').delete().eq('id', budget['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
          if (_selectedBudget?['id'] == budget['id']) {
            setState(() {
              _selectedBudget = null;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewBudgetDetails(Map<String, dynamic> budget) {
    setState(() {
      _selectedBudget = budget;
    });
    // Navigation vers la page de détails du budget
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BudgetDetailsPage(
              budget: budget,
              userSession: widget.userSession,
            ),
      ),
    ).then((_) => _loadData());
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
            _showBudgetForm();
          }
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Gestion des Budgets'),
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
                : Column(
                  children: [
                    // Barre d'outils
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          if (_canCreate)
                            ElevatedButton.icon(
                              onPressed: () => _showBudgetForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouveau Budget (Ctrl+N)'),
                            ),
                          if (_canCreate) const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Actualiser'),
                          ),
                        ],
                      ),
                    ),
                    // Liste des budgets
                    Expanded(
                      child:
                          _budgets.isEmpty
                              ? const Center(
                                child: Text(
                                  'Aucun budget enregistré',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: _budgets.length,
                                itemBuilder: (context, index) {
                                  final budget = _budgets[index];
                                  final projet = budget['projet'];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        budget['code'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(budget['designation'] ?? ''),
                                          const SizedBox(height: 4),
                                          if (projet != null)
                                            Text(
                                              'Projet: ${projet['code']} - ${projet['designation']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          Text(
                                            'Montant: \$${budget['montant'] ?? 0} | Statut: ${budget['statut']} | Total calculé: \$${budget['montant_total'] ?? 0}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility),
                                            color: Colors.green,
                                            onPressed:
                                                () =>
                                                    _viewBudgetDetails(budget),
                                            tooltip: 'Voir détails',
                                          ),
                                          if (_canUpdate)
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: Colors.blue,
                                              onPressed:
                                                  () => _showBudgetForm(
                                                    budget: budget,
                                                  ),
                                              tooltip: 'Modifier',
                                            ),
                                          if (_canDelete)
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed:
                                                  () => _deleteBudget(budget),
                                              tooltip: 'Supprimer',
                                            ),
                                        ],
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
