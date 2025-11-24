import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class ListeProjetsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeProjetsPage({super.key, this.showAppBar = true, this.userSession});

  @override
  State<ListeProjetsPage> createState() => _ListeProjetsPageState();
}

class _ListeProjetsPageState extends State<ListeProjetsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _projets = [];
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();

  // Permissions
  bool get _canCreate => _hasPermission('creation');
  bool get _canUpdate => _hasPermission('modification');
  bool get _canDelete => _hasPermission('suppression');

  bool _hasPermission(String type) {
    if (widget.userSession == null)
      return true; // Par défaut, autoriser si pas de session

    final permission = widget.userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'liste_projets',
      orElse: () => <String, dynamic>{},
    );

    if (permission.isEmpty)
      return true; // Si pas de permission définie, autoriser
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
      print('📊 Chargement des données projets...');

      // Charger les bailleurs
      final bailleursResponse = await _supabase
          .from('bailleur')
          .select()
          .order('sigle', ascending: true);

      print('✅ Bailleurs chargés: ${bailleursResponse.length}');

      // Charger les projets avec leurs relations
      final projetsResponse = await _supabase
          .from('projet')
          .select('*, projet_bailleur(bailleur(id, sigle, designation))')
          .order('code', ascending: true);

      print('✅ Projets chargés: ${projetsResponse.length}');

      setState(() {
        _bailleurs = List<Map<String, dynamic>>.from(bailleursResponse);
        _projets = List<Map<String, dynamic>>.from(projetsResponse);
        _isLoading = false;
      });

      print('✅ État mis à jour avec succès');
    } catch (e, stackTrace) {
      print('❌ Erreur lors du chargement: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showProjetForm({Map<String, dynamic>? projet}) {
    final codeController = TextEditingController(text: projet?['code'] ?? '');
    final designationController = TextEditingController(
      text: projet?['designation'] ?? '',
    );
    final dateDebutController = TextEditingController(
      text: projet?['date_debut'] ?? '',
    );
    final dateFinController = TextEditingController(
      text: projet?['date_fin'] ?? '',
    );

    // Récupérer les bailleurs existants du projet
    final Set<String> selectedBailleurIds = {};
    if (projet != null && projet['projet_bailleur'] != null) {
      for (var pb in projet['projet_bailleur']) {
        if (pb['bailleur'] != null && pb['bailleur']['id'] != null) {
          selectedBailleurIds.add(pb['bailleur']['id']);
        }
      }
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    projet == null ? 'Nouveau Projet' : 'Modifier Projet',
                  ),
                  content: SizedBox(
                    width: 500,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: dateDebutController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date début',
                                      border: OutlineInputBorder(),
                                      hintText: 'AAAA-MM-JJ',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            dateDebutController.text.isNotEmpty
                                                ? DateTime.parse(
                                                  dateDebutController.text,
                                                )
                                                : DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        dateDebutController.text =
                                            date.toIso8601String().split(
                                              'T',
                                            )[0];
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: dateFinController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date fin',
                                      border: OutlineInputBorder(),
                                      hintText: 'AAAA-MM-JJ',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            dateFinController.text.isNotEmpty
                                                ? DateTime.parse(
                                                  dateFinController.text,
                                                )
                                                : DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        dateFinController.text =
                                            date.toIso8601String().split(
                                              'T',
                                            )[0];
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bailleurs (sélection multiple)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child:
                                  _bailleurs.isEmpty
                                      ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          'Aucun bailleur disponible',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                      : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _bailleurs.length,
                                        itemBuilder: (context, index) {
                                          final bailleur = _bailleurs[index];
                                          final bailleurId = bailleur['id'];
                                          final isSelected = selectedBailleurIds
                                              .contains(bailleurId);

                                          return CheckboxListTile(
                                            title: Text(
                                              bailleur['sigle'] ?? '',
                                            ),
                                            subtitle: Text(
                                              bailleur['designation'] ?? '',
                                            ),
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              setDialogState(() {
                                                if (value == true) {
                                                  selectedBailleurIds.add(
                                                    bailleurId,
                                                  );
                                                } else {
                                                  selectedBailleurIds.remove(
                                                    bailleurId,
                                                  );
                                                }
                                              });
                                            },
                                            dense: true,
                                          );
                                        },
                                      ),
                            ),
                            if (selectedBailleurIds.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Veuillez sélectionner au moins un bailleur',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
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
                        if (formKey.currentState!.validate() &&
                            selectedBailleurIds.isNotEmpty) {
                          try {
                            String projetId;

                            if (projet == null) {
                              // Insertion
                              final response =
                                  await _supabase
                                      .from('projet')
                                      .insert({
                                        'code': codeController.text.trim(),
                                        'designation':
                                            designationController.text.trim(),
                                        'date_debut':
                                            dateDebutController.text.isNotEmpty
                                                ? dateDebutController.text
                                                : null,
                                        'date_fin':
                                            dateFinController.text.isNotEmpty
                                                ? dateFinController.text
                                                : null,
                                      })
                                      .select('id')
                                      .single();

                              projetId = response['id'];
                            } else {
                              // Mise à jour
                              await _supabase
                                  .from('projet')
                                  .update({
                                    'code': codeController.text.trim(),
                                    'designation':
                                        designationController.text.trim(),
                                    'date_debut':
                                        dateDebutController.text.isNotEmpty
                                            ? dateDebutController.text
                                            : null,
                                    'date_fin':
                                        dateFinController.text.isNotEmpty
                                            ? dateFinController.text
                                            : null,
                                  })
                                  .eq('id', projet['id']);

                              projetId = projet['id'];

                              // Supprimer les anciennes relations
                              await _supabase
                                  .from('projet_bailleur')
                                  .delete()
                                  .eq('projet_id', projetId);
                            }

                            // Insérer les nouvelles relations
                            final relations =
                                selectedBailleurIds
                                    .map(
                                      (bailleurId) => {
                                        'projet_id': projetId,
                                        'bailleur_id': bailleurId,
                                      },
                                    )
                                    .toList();

                            if (relations.isNotEmpty) {
                              await _supabase
                                  .from('projet_bailleur')
                                  .insert(relations);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    projet == null
                                        ? 'Projet ajouté avec succès'
                                        : 'Projet modifié avec succès',
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

  Future<void> _deleteProjet(Map<String, dynamic> projet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le projet "${projet['code']}" ?',
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
        // Les relations seront supprimées automatiquement grâce à ON DELETE CASCADE
        await _supabase.from('projet').delete().eq('id', projet['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projet supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getBailleursString(Map<String, dynamic> projet) {
    if (projet['projet_bailleur'] == null) return 'Aucun';

    final bailleurs = <String>[];
    for (var pb in projet['projet_bailleur']) {
      if (pb['bailleur'] != null && pb['bailleur']['designation'] != null) {
        bailleurs.add(pb['bailleur']['designation']);
      }
    }

    return bailleurs.isEmpty ? 'Aucun' : bailleurs.join(', ');
  }

  String _getPeriodeString(Map<String, dynamic> projet) {
    final debut = projet['date_debut'];
    final fin = projet['date_fin'];

    if (debut == null && fin == null) return 'Non définie';

    final debutStr = debut ?? '?';
    final finStr = fin ?? '?';

    return '$debutStr → $finStr';
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
            _showProjetForm();
          }
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Liste des Projets'),
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
                              onPressed: () => _showProjetForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouveau (Ctrl+N)'),
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
                    // Liste des projets
                    Expanded(
                      child:
                          _projets.isEmpty
                              ? const Center(
                                child: Text(
                                  'Aucun projet enregistré',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: _projets.length,
                                itemBuilder: (context, index) {
                                  final projet = _projets[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        projet['code'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(projet['designation'] ?? ''),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.people_outline,
                                                size: 14,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _getBailleursString(projet),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getPeriodeString(projet),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_canUpdate)
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: Colors.blue,
                                              onPressed:
                                                  () => _showProjetForm(
                                                    projet: projet,
                                                  ),
                                              tooltip: 'Modifier',
                                            ),
                                          if (_canDelete)
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed:
                                                  () => _deleteProjet(projet),
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
