import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class ListeBailleursPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeBailleursPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
  });

  @override
  State<ListeBailleursPage> createState() => _ListeBailleursPageState();
}

class _ListeBailleursPageState extends State<ListeBailleursPage> {
  final _supabase = Supabase.instance.client;
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
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'liste_bailleurs',
      orElse: () => <String, dynamic>{},
    );

    if (permission.isEmpty)
      return true; // Si pas de permission définie, autoriser
    return permission[type] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadBailleurs();
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

  Future<void> _loadBailleurs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('bailleur')
          .select()
          .order('sigle', ascending: true);

      setState(() {
        _bailleurs = List<Map<String, dynamic>>.from(response);
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

  void _showBailleurForm({Map<String, dynamic>? bailleur}) {
    final sigleController = TextEditingController(
      text: bailleur?['sigle'] ?? '',
    );
    final designationController = TextEditingController(
      text: bailleur?['designation'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              bailleur == null ? 'Nouveau Bailleur' : 'Modifier Bailleur',
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: sigleController,
                    decoration: const InputDecoration(
                      labelText: 'Sigle',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le sigle est requis';
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
                      if (bailleur == null) {
                        // Ajout
                        await _supabase.from('bailleur').insert({
                          'sigle': sigleController.text.trim(),
                          'designation': designationController.text.trim(),
                        });
                      } else {
                        // Modification
                        await _supabase
                            .from('bailleur')
                            .update({
                              'sigle': sigleController.text.trim(),
                              'designation': designationController.text.trim(),
                            })
                            .eq('id', bailleur['id']);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              bailleur == null
                                  ? 'Bailleur ajouté avec succès'
                                  : 'Bailleur modifié avec succès',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadBailleurs();
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

  Future<void> _deleteBailleur(Map<String, dynamic> bailleur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le bailleur "${bailleur['sigle']}" ?',
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
        await _supabase.from('bailleur').delete().eq('id', bailleur['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bailleur supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBailleurs();
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
            _showBailleurForm();
          }
        }
      },
      child: Scaffold(
        appBar:
            widget.showAppBar
                ? AppBar(
                  title: const Text('Liste des Bailleurs'),
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
                              onPressed: () => _showBailleurForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouveau (Ctrl+N)'),
                            ),
                          if (_canCreate) const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _loadBailleurs,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Actualiser'),
                          ),
                        ],
                      ),
                    ),
                    // Liste des bailleurs
                    Expanded(
                      child:
                          _bailleurs.isEmpty
                              ? const Center(
                                child: Text(
                                  'Aucun bailleur enregistré',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: _bailleurs.length,
                                itemBuilder: (context, index) {
                                  final bailleur = _bailleurs[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        bailleur['sigle'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        bailleur['designation'] ?? '',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            color: Colors.blue,
                                            onPressed:
                                                () => _showBailleurForm(
                                                  bailleur: bailleur,
                                                ),
                                            tooltip: 'Modifier',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            color: Colors.red,
                                            onPressed:
                                                () => _deleteBailleur(bailleur),
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
