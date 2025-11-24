import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/journal.dart';
import '../models/user_session.dart';

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
  List<Journal> journaux = [];
  String searchQuery = '';
  bool isLoading = true;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.microtask(() {
      _focusNode.requestFocus();
    });
    _loadJournaux();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadJournaux() async {
    try {
      final result = await AuthService.getJournaux();
      if (!mounted) return;
      setState(() {
        journaux = result;
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
        await AuthService.deleteJournal(id);
        if (!mounted) return;
        _loadJournaux();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Journal supprimé')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        journaux
            .where(
              (j) =>
                  j.code.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  j.intitule.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();

    return RawKeyboardListener(
      focusNode: _focusNode,
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
                  title: const Text('Journaux de saisie'),
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
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Barre de recherche
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un journal...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // Tableau des journaux
                    Expanded(
                      child:
                          filtered.isEmpty
                              ? Center(
                                child: Text(
                                  searchQuery.isEmpty
                                      ? 'Aucun journal. Cliquez sur + ou Ctrl+N'
                                      : 'Aucun journal trouvé',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Code')),
                                    DataColumn(label: Text('Intitulé')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(
                                      label: Text('Saisie Analytique'),
                                    ),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows:
                                      filtered
                                          .map(
                                            (j) => DataRow(
                                              cells: [
                                                DataCell(Text(j.code)),
                                                DataCell(Text(j.intitule)),
                                                DataCell(
                                                  Chip(
                                                    label: Text(
                                                      j.type.toLabel(),
                                                    ),
                                                    backgroundColor:
                                                        j.type ==
                                                                TypeJournal
                                                                    .financier
                                                            ? Colors.green[100]
                                                            : Colors
                                                                .orange[100],
                                                  ),
                                                ),
                                                DataCell(
                                                  j.saisieAnalytique
                                                      ? const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                      )
                                                      : const Icon(
                                                        Icons.cancel,
                                                        color: Colors.red,
                                                      ),
                                                ),
                                                DataCell(
                                                  PopupMenuButton(
                                                    itemBuilder:
                                                        (context) => [
                                                          PopupMenuItem(
                                                            onTap:
                                                                () =>
                                                                    _showJournalDialog(
                                                                      j,
                                                                    ),
                                                            child: const Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.edit,
                                                                  size: 16,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  'Modifier',
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          PopupMenuItem(
                                                            onTap:
                                                                () =>
                                                                    _deleteJournal(
                                                                      j.id,
                                                                      j.intitule,
                                                                    ),
                                                            child: const Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.delete,
                                                                  size: 16,
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  'Supprimer',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                    ),
                  ],
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showJournalDialog(null),
          tooltip: 'Nouveau journal (Ctrl+N)',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showJournalDialog(Journal? journal) {
    showDialog(
      context: context,
      builder:
          (context) => JournalDialog(
            journal: journal,
            onSave: (updatedJournal) {
              _loadJournaux();
              Navigator.pop(context);
            },
          ),
    );
  }
}

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class JournalDialog extends StatefulWidget {
  final Journal? journal;
  final Function(Journal) onSave;

  const JournalDialog({super.key, this.journal, required this.onSave});

  @override
  State<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends State<JournalDialog> {
  late TextEditingController _codeController;
  late TextEditingController _intituleController;
  late TextEditingController _compteFresorerieController;
  TypeJournal? _selectedType;
  bool _saisieAnalytique = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final journal = widget.journal;
    _codeController = TextEditingController(text: journal?.code ?? '');
    _intituleController = TextEditingController(text: journal?.intitule ?? '');
    _compteFresorerieController = TextEditingController(
      text: journal?.compteFresorerie ?? '',
    );
    _selectedType = journal?.type ?? TypeJournal.financier;
    _saisieAnalytique = journal?.saisieAnalytique ?? false;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _intituleController.dispose();
    _compteFresorerieController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

    // Si type financier, vérifier que compte de trésorerie est rempli
    if (_selectedType == TypeJournal.financier &&
        _compteFresorerieController.text.isEmpty) {
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
          intitule: _intituleController.text,
          type: _selectedType!.toDbString(),
          compteFresorerie:
              _selectedType == TypeJournal.financier
                  ? _compteFresorerieController.text
                  : null,
          saisieAnalytique: _saisieAnalytique,
        );
      } else {
        // Modifier
        await AuthService.updateJournal(
          id: widget.journal!.id,
          code: _codeController.text,
          intitule: _intituleController.text,
          type: _selectedType!.toDbString(),
          compteFresorerie:
              _selectedType == TypeJournal.financier
                  ? _compteFresorerieController.text
                  : null,
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
              compteFresorerie: _compteFresorerieController.text,
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

    return AlertDialog(
      title: Text(isEditing ? 'Modifier le journal' : 'Nouveau journal'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _intituleController,
                decoration: const InputDecoration(
                  labelText: 'Intitulé *',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TypeJournal>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
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
              ),
              const SizedBox(height: 16),
              // Afficher le champ compte de trésorerie seulement si type financier
              if (_selectedType == TypeJournal.financier)
                Column(
                  children: [
                    TextField(
                      controller: _compteFresorerieController,
                      decoration: const InputDecoration(
                        labelText: 'Compte de Trésorerie *',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              CheckboxListTile(
                title: const Text('Saisie Analytique'),
                value: _saisieAnalytique,
                onChanged:
                    _isSaving
                        ? null
                        : (value) {
                          setState(() => _saisieAnalytique = value ?? false);
                        },
                contentPadding: EdgeInsets.zero,
              ),
            ],
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
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(isEditing ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }
}
