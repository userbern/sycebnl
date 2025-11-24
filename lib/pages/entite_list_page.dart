import 'package:flutter/material.dart';
import 'package:sycebnl_accounting/models/entite.dart';
import 'package:sycebnl_accounting/models/user_session.dart';
import 'package:sycebnl_accounting/services/auth_service.dart';
import 'entite_form_page.dart';

class EntiteListPage extends StatefulWidget {
  final UserSession userSession;

  const EntiteListPage({Key? key, required this.userSession}) : super(key: key);

  @override
  State<EntiteListPage> createState() => _EntiteListPageState();
}

class _EntiteListPageState extends State<EntiteListPage> {
  late List<Entite> _entites = [];
  late List<Entite> _filteredEntites = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntites();
    _searchController.addListener(_filterEntites);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Charger toutes les entités
  Future<void> _loadEntites() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final entites = await AuthService.getEntites();

      if (!mounted) return;

      setState(() {
        _entites = entites;
        _filteredEntites = entites;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtrer les entités selon la recherche
  void _filterEntites() {
    final query = _searchController.text.toLowerCase();

    if (!mounted) return;

    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEntites = _entites;
      } else {
        _filteredEntites =
            _entites
                .where(
                  (entite) =>
                      entite.denominationSociale.toLowerCase().contains(
                        query,
                      ) ||
                      (entite.sigleUsuel?.toLowerCase().contains(query) ??
                          false) ||
                      (entite.email?.toLowerCase().contains(query) ?? false),
                )
                .toList();
      }
    });
  }

  /// Ouvrir le formulaire pour créer une nouvelle entité (CTRL+N)
  void _openCreateForm() {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seuls les administrateurs peuvent créer des entités'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EntiteFormPage(
              userSession: widget.userSession,
              onSave: (entite) {
                _loadEntites();
              },
            ),
      ),
    );
  }

  /// Ouvrir le formulaire pour modifier une entité
  void _openEditForm(Entite entite) {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seuls les administrateurs peuvent modifier les entités',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EntiteFormPage(
              userSession: widget.userSession,
              entite: entite,
              onSave: (updatedEntite) {
                _loadEntites();
              },
            ),
      ),
    );
  }

  /// Supprimer une entité
  Future<void> _deleteEntite(String entiteId) async {
    if (!widget.userSession.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seuls les administrateurs peuvent supprimer les entités',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher une confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette entité ?',
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

    if (confirm != true) return;

    if (!mounted) return;

    try {
      await AuthService.deleteEntite(entiteId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entité supprimée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _loadEntites();
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identification'),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
      ),
      floatingActionButton:
          widget.userSession.isAdmin
              ? FloatingActionButton(
                onPressed: _openCreateForm,
                backgroundColor: Colors.blue.shade900,
                tooltip: 'Créer une entité (Ctrl+N)',
                child: const Icon(Icons.add),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 🔍 Barre de recherche
                  Container(
                    padding: EdgeInsets.all(screenHeight * 0.02),
                    color: Colors.grey.shade100,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Rechercher par dénomination, sigle ou email...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenHeight * 0.02,
                          vertical: screenHeight * 0.015,
                        ),
                      ),
                    ),
                  ),
                  // 📋 Liste des entités
                  Expanded(
                    child:
                        _filteredEntites.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 80,
                                    color: Colors.grey.shade300,
                                  ),
                                  SizedBox(height: screenHeight * 0.02),
                                  Text(
                                    'Aucune entité trouvée',
                                    style: TextStyle(
                                      fontSize: screenHeight * 0.022,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: EdgeInsets.all(screenHeight * 0.02),
                              itemCount: _filteredEntites.length,
                              itemBuilder: (context, index) {
                                final entite = _filteredEntites[index];

                                return Card(
                                  margin: EdgeInsets.only(
                                    bottom: screenHeight * 0.015,
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.all(
                                      screenHeight * 0.015,
                                    ),
                                    title: Text(
                                      entite.denominationSociale,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenHeight * 0.02,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: screenHeight * 0.005),
                                        if (entite.sigleUsuel != null)
                                          Text(
                                            '📍 ${entite.sigleUsuel}',
                                            style: TextStyle(
                                              fontSize: screenHeight * 0.015,
                                            ),
                                          ),
                                        if (entite.email != null)
                                          Text(
                                            '📧 ${entite.email}',
                                            style: TextStyle(
                                              fontSize: screenHeight * 0.015,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        if (entite.ongType != null)
                                          Text(
                                            '🏢 ${entite.ongType!.toLabel()}',
                                            style: TextStyle(
                                              fontSize: screenHeight * 0.015,
                                              color: Colors.green.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing:
                                        widget.userSession.isAdmin
                                            ? PopupMenuButton(
                                              itemBuilder:
                                                  (context) => [
                                                    PopupMenuItem(
                                                      onTap: () {
                                                        Future.delayed(
                                                          const Duration(
                                                            milliseconds: 300,
                                                          ),
                                                          () => _openEditForm(
                                                            entite,
                                                          ),
                                                        );
                                                      },
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.edit,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text('Modifier'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      onTap: () {
                                                        Future.delayed(
                                                          const Duration(
                                                            milliseconds: 300,
                                                          ),
                                                          () => _deleteEntite(
                                                            entite.id,
                                                          ),
                                                        );
                                                      },
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.delete,
                                                            size: 18,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            'Supprimer',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                            )
                                            : null,
                                    onTap: () {
                                      // Afficher les détails en lecture seule
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
