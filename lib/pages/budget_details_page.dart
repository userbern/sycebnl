import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;
  final UserSession? userSession;

  const BudgetDetailsPage({super.key, required this.budget, this.userSession});

  @override
  State<BudgetDetailsPage> createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _postes = [];
  bool _isLoading = false;
  Map<String, bool> _expandedPostes = {};

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
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('poste_budgetaire')
          .select('''
            *,
            ligne_budgetaire(
              *,
              sous_rubrique_budgetaire(*)
            )
          ''')
          .eq('budget_id', widget.budget['id'])
          .order('code', ascending: true);

      setState(() {
        _postes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  void _showPosteForm({Map<String, dynamic>? poste}) {
    final codeController = TextEditingController(text: poste?['code'] ?? '');
    final designationController = TextEditingController(
      text: poste?['designation'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              poste == null ? 'Nouveau Poste Budgétaire' : 'Modifier Poste',
            ),
            content: Form(
              key: formKey,
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
                  if (formKey.currentState!.validate()) {
                    try {
                      if (poste == null) {
                        await _supabase.from('poste_budgetaire').insert({
                          'code': codeController.text.trim(),
                          'designation': designationController.text.trim(),
                          'budget_id': widget.budget['id'],
                        });
                      } else {
                        await _supabase
                            .from('poste_budgetaire')
                            .update({
                              'code': codeController.text.trim(),
                              'designation': designationController.text.trim(),
                            })
                            .eq('id', poste['id']);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              poste == null
                                  ? 'Poste créé avec succès'
                                  : 'Poste modifié avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadPostes();
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
    );
  }

  void _showLigneForm({required String posteId, Map<String, dynamic>? ligne}) {
    final codeController = TextEditingController(text: ligne?['code'] ?? '');
    final designationController = TextEditingController(
      text: ligne?['designation'] ?? '',
    );
    final compteController = TextEditingController(
      text: ligne?['numero_compte'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              ligne == null ? 'Nouvelle Ligne Budgétaire' : 'Modifier Ligne',
            ),
            content: Form(
              key: formKey,
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
                  TextFormField(
                    controller: compteController,
                    decoration: const InputDecoration(
                      labelText: 'N° Compte',
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
                  if (formKey.currentState!.validate()) {
                    try {
                      if (ligne == null) {
                        await _supabase.from('ligne_budgetaire').insert({
                          'code': codeController.text.trim(),
                          'designation': designationController.text.trim(),
                          'numero_compte': compteController.text.trim(),
                          'poste_budgetaire_id': posteId,
                        });
                      } else {
                        await _supabase
                            .from('ligne_budgetaire')
                            .update({
                              'code': codeController.text.trim(),
                              'designation': designationController.text.trim(),
                              'numero_compte': compteController.text.trim(),
                            })
                            .eq('id', ligne['id']);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ligne == null
                                  ? 'Ligne créée avec succès'
                                  : 'Ligne modifiée avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadPostes();
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
    );
  }

  void _showSousRubriqueForm({
    required String ligneId,
    Map<String, dynamic>? sousRubrique,
  }) {
    final codeController = TextEditingController(
      text: sousRubrique?['code'] ?? '',
    );
    final designationController = TextEditingController(
      text: sousRubrique?['designation'] ?? '',
    );
    final montantController = TextEditingController(
      text: sousRubrique?['montant']?.toString() ?? '',
    );
    final compteController = TextEditingController(
      text: sousRubrique?['numero_compte'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              sousRubrique == null
                  ? 'Nouvelle Sous-Rubrique'
                  : 'Modifier Sous-Rubrique',
            ),
            content: Form(
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
                    TextFormField(
                      controller: montantController,
                      decoration: const InputDecoration(
                        labelText: 'Montant',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le montant est requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Montant invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: compteController,
                      decoration: const InputDecoration(
                        labelText: 'N° Compte',
                        border: OutlineInputBorder(),
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
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      if (sousRubrique == null) {
                        await _supabase
                            .from('sous_rubrique_budgetaire')
                            .insert({
                              'code': codeController.text.trim(),
                              'designation': designationController.text.trim(),
                              'montant': double.parse(montantController.text),
                              'numero_compte': compteController.text.trim(),
                              'ligne_budgetaire_id': ligneId,
                            });
                      } else {
                        await _supabase
                            .from('sous_rubrique_budgetaire')
                            .update({
                              'code': codeController.text.trim(),
                              'designation': designationController.text.trim(),
                              'montant': double.parse(montantController.text),
                              'numero_compte': compteController.text.trim(),
                            })
                            .eq('id', sousRubrique['id']);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sousRubrique == null
                                  ? 'Sous-rubrique créée avec succès'
                                  : 'Sous-rubrique modifiée avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadPostes();
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
    );
  }

  Future<void> _deletePoste(Map<String, dynamic> poste) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Supprimer le poste "${poste['code']}" ?\nToutes les lignes et sous-rubriques seront supprimées.',
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
        await _supabase.from('poste_budgetaire').delete().eq('id', poste['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poste supprimé'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPostes();
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

  Future<void> _deleteLigne(Map<String, dynamic> ligne) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Supprimer la ligne "${ligne['code']}" ?\nToutes les sous-rubriques seront supprimées.',
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
        await _supabase.from('ligne_budgetaire').delete().eq('id', ligne['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ligne supprimée'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPostes();
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

  Future<void> _deleteSousRubrique(Map<String, dynamic> sousRubrique) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Supprimer la sous-rubrique "${sousRubrique['code']}" ?',
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
        await _supabase
            .from('sous_rubrique_budgetaire')
            .delete()
            .eq('id', sousRubrique['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sous-rubrique supprimée'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPostes();
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

  Widget _buildPosteCard(Map<String, dynamic> poste) {
    final isExpanded = _expandedPostes[poste['id']] ?? false;
    final lignes = poste['ligne_budgetaire'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _expandedPostes[poste['id']] = !isExpanded;
                });
              },
            ),
            title: Text(
              '${poste['code']} - ${poste['designation']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Montant total: \$${poste['montant_total'] ?? 0} | ${lignes.length} ligne(s)',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canCreate)
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: Colors.green,
                    onPressed: () => _showLigneForm(posteId: poste['id']),
                    tooltip: 'Ajouter ligne',
                  ),
                if (_canUpdate)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: Colors.blue,
                    onPressed: () => _showPosteForm(poste: poste),
                    tooltip: 'Modifier',
                  ),
                if (_canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    onPressed: () => _deletePoste(poste),
                    tooltip: 'Supprimer',
                  ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(),
            ...lignes.map((ligne) => _buildLigneItem(ligne)),
          ],
        ],
      ),
    );
  }

  Widget _buildLigneItem(Map<String, dynamic> ligne) {
    final sousRubriques =
        ligne['sous_rubrique_budgetaire'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          '${ligne['code']} - ${ligne['designation']}',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          'Compte: ${ligne['numero_compte'] ?? 'N/A'} | Montant: \$${ligne['montant_total'] ?? 0} | ${sousRubriques.length} sous-rubrique(s)',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canCreate)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                color: Colors.green,
                onPressed: () => _showSousRubriqueForm(ligneId: ligne['id']),
                tooltip: 'Ajouter sous-rubrique',
              ),
            if (_canUpdate)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: Colors.blue,
                onPressed:
                    () => _showLigneForm(
                      posteId: ligne['poste_budgetaire_id'],
                      ligne: ligne,
                    ),
                tooltip: 'Modifier',
              ),
            if (_canDelete)
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.red,
                onPressed: () => _deleteLigne(ligne),
                tooltip: 'Supprimer',
              ),
          ],
        ),
        children:
            sousRubriques
                .map((sr) => _buildSousRubriqueItem(sr, ligne['id']))
                .toList(),
      ),
    );
  }

  Widget _buildSousRubriqueItem(
    Map<String, dynamic> sousRubrique,
    String ligneId,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 32, right: 16, bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sousRubrique['code']} - ${sousRubrique['designation']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compte: ${sousRubrique['numero_compte'] ?? 'N/A'} | Montant: \$${sousRubrique['montant'] ?? 0}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canUpdate)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  onPressed:
                      () => _showSousRubriqueForm(
                        ligneId: ligneId,
                        sousRubrique: sousRubrique,
                      ),
                  tooltip: 'Modifier',
                ),
              if (_canDelete)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  onPressed: () => _deleteSousRubrique(sousRubrique),
                  tooltip: 'Supprimer',
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Budget: ${widget.budget['code']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPostes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête du budget
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.budget['designation'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Montant: \$${widget.budget['montant'] ?? 0}'),
                Text('Statut: ${widget.budget['statut']}'),
                Text(
                  'Total calculé: \$${widget.budget['montant_total'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Barre d'outils
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                if (_canCreate)
                  ElevatedButton.icon(
                    onPressed: () => _showPosteForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau Poste'),
                  ),
              ],
            ),
          ),
          // Liste des postes
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _postes.isEmpty
                    ? const Center(
                      child: Text(
                        'Aucun poste budgétaire',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _postes.length,
                      itemBuilder: (context, index) {
                        return _buildPosteCard(_postes[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
