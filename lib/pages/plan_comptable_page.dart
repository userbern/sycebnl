import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/compte.dart';
import '../services/database_service_new.dart';

class PlanComptablePage extends StatefulWidget {
  const PlanComptablePage({super.key});

  @override
  State<PlanComptablePage> createState() => _PlanComptablePageState();
}

class _PlanComptablePageState extends State<PlanComptablePage> {
  List<Compte> _comptes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  NatureCompte? _selectedNature; // Filtre par nature
  TypeCompte? _selectedType; // Filtre par type
  int _longueurCompteGeneral = 7; // Valeur par défaut

  @override
  void initState() {
    super.initState();
    _loadComptes();
    _loadLongueurCompteGeneral();
  }

  Future<void> _loadLongueurCompteGeneral() async {
    try {
      final config = await DatabaseService.getFileConfig();
      if (config != null && config['longueur_compte_general'] != null) {
        setState(() {
          _longueurCompteGeneral = config['longueur_compte_general'] as int;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement longueur compte: $e');
    }
  }

  Future<void> _loadComptes() async {
    setState(() => _isLoading = true);
    try {
      final comptes = await DatabaseService.getAllComptes();
      setState(() {
        _comptes = comptes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des comptes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Compte> get _filteredComptes {
    var filtered = _comptes;

    // Filtrer par texte de recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((compte) {
            return compte.numeroCompte.toLowerCase().contains(query) ||
                compte.intitule.toLowerCase().contains(query);
          }).toList();
    }

    // Filtrer par nature
    if (_selectedNature != null) {
      filtered =
          filtered.where((compte) {
            return compte.nature == _selectedNature;
          }).toList();
    }

    // Filtrer par type
    if (_selectedType != null) {
      filtered =
          filtered.where((compte) {
            return compte.type == _selectedType;
          }).toList();
    }

    return filtered;
  }

  String _padNumeroCompte(String numero, TypeCompte type) {
    // Ne compléter avec des zéros que pour les comptes de type "detail"
    if (type == TypeCompte.total) {
      return numero;
    }

    if (numero.length >= _longueurCompteGeneral) {
      return numero;
    }
    return numero.padRight(_longueurCompteGeneral, '0');
  }

  void _showCompteDialog({Compte? compte}) {
    final isEdit = compte != null;
    final numeroController = TextEditingController(
      text: compte?.numeroCompte ?? '',
    );
    final intituleController = TextEditingController(
      text: compte?.intitule ?? '',
    );
    final descriptionController = TextEditingController(
      text: compte?.description ?? '',
    );
    TypeCompte selectedType = compte?.type ?? TypeCompte.detail;
    NatureCompte? calculatedNature = compte?.nature;
    bool liaisonTiers = compte?.liaisonTiers ?? false;
    final formKey = GlobalKey<FormState>();

    Future<void> _addAccount() async {
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

        final paddedNumero = _padNumeroCompte(
          numeroController.text.trim(),
          selectedType,
        );

        try {
          await DatabaseService.createCompte(
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

          // Réinitialiser le formulaire pour saisir un autre compte
          numeroController.clear();
          intituleController.clear();
          descriptionController.clear();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Compte créé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
            // Focus sur le champ numéro pour continuer la saisie
            FocusScope.of(context).requestFocus(FocusNode());
          }

          await _loadComptes();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }

     Future<void> _submit() async {
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

      final paddedNumero = _padNumeroCompte(
        numeroController.text.trim(),
        selectedType,
      );

      try {
        if (isEdit) {
          await DatabaseService.updateCompte(
            compteId: compte.id,
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
        } else {
          await DatabaseService.createCompte(
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
        }

        await _loadComptes();
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Compte modifié avec succès'
                    : 'Compte créé avec succès',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                if (event.isKeyPressed(LogicalKeyboardKey.enter) && !isEdit) {
                  _addAccount();
                }
              },
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit : Icons.add_circle,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Modifier le compte' : 'Nouveau compte',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: numeroController,
                                  label: 'N° Compte *',
                                  icon: Icons.numbers,
                                  isRequired: true,
                                  keyboardType: TextInputType.number,
                                  enabled: !isEdit,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Champ requis';
                                    }
                                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                      return 'Seuls les chiffres sont autorisés';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    setDialogState(() {
                                      calculatedNature =
                                          calculateNatureFromNumeroCompte(
                                            value,
                                          );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  controller: intituleController,
                                  label: 'Intitulé *',
                                  icon: Icons.title,
                                  isRequired: true,
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
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<TypeCompte>(
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
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.blue.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor:
                                        isEdit
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade50,
                                  ),
                                  dropdownColor: Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down_circle,
                                    color: Colors.blue.shade400,
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
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade400,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.arrow_drop_down_circle,
                              color: Colors.blue.shade400,
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
                          _buildTextField(
                            controller: descriptionController,
                            label: 'Description',
                            icon: Icons.notes,
                            maxLines: 3,
                            enabled: !isEdit,
                          ),
                          const SizedBox(height: 16),
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
                            tileColor:
                                isEdit
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade50,
                          ),
                          if (!isEdit) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.blue.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Utilisez Ctrl+N pour ajouter rapidement plusieurs comptes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  if (!isEdit)
                    ElevatedButton.icon(
                      onPressed: !isEdit ? () => _addAccount() : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter et continuer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () async {
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

                        final paddedNumero = _padNumeroCompte(
                          numeroController.text.trim(),
                          selectedType,
                        );

                        try {
                          if (isEdit) {
                            await DatabaseService.updateCompte(
                              compteId: compte.id,
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
                          } else {
                            await DatabaseService.createCompte(
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
                          }

                          await _loadComptes();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Compte modifié avec succès'
                                      : 'Compte créé avec succès',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: Icon(isEdit ? Icons.save : Icons.check),
                    label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _isCompteUtilise(String numeroCompte) async {
    // Vérifie si le compte est utilisé dans d'autres tables (journaux, écritures, etc.)
    // À adapter selon la structure réelle de la base !
    final usedInJournaux = await DatabaseService.isCompteUsedInJournaux(
      numeroCompte,
    );
    // Ajoute d'autres vérifications si besoin (écritures, budgets, etc.)
    return usedInJournaux;
  }

  Future<void> _deleteCompte(Compte compte) async {
    final isUsed = await _isCompteUtilise(compte.numeroCompte);
    if (isUsed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce compte est utilisé dans une autre table et ne peut pas être supprimé.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le compte ${compte.numeroCompte} - ${compte.intitule} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await DatabaseService.deleteCompte(compte.id);
        await _loadComptes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showCompteDialog();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 32,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Plan Comptable',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCompteDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau compte (Ctrl+N)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Barre de recherche et filtres (sur une seule ligne)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      onChanged:
                          (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Rechercher',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<NatureCompte?>(
                      isExpanded: true,
                      isDense: true,
                      value: _selectedNature,
                      decoration: InputDecoration(
                        labelText: 'Nature',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-- Toutes --'),
                        ),
                        for (final nature in NatureCompte.values)
                          DropdownMenuItem(
                            value: nature,
                            child: Text(nature.toLabel()),
                          ),
                      ],
                      onChanged:
                          (value) => setState(() => _selectedNature = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<TypeCompte?>(
                      isExpanded: true,
                      isDense: true,
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon: const Icon(Icons.type_specimen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-- Tous --'),
                        ),
                        for (final type in TypeCompte.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.toLabel()),
                          ),
                      ],
                      onChanged:
                          (value) => setState(() => _selectedType = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    child: IconButton(
                      tooltip: 'Réinitialiser',
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedNature = null;
                          _selectedType = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tableau
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredComptes.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Aucun compte dans le plan comptable'
                                    : 'Aucun compte trouvé',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Container(
                          constraints: const BoxConstraints.expand(),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double screenWidth =
                                      MediaQuery.of(context).size.width;
                                  final double availableWidth =
                                      constraints.maxWidth.isFinite
                                          ? constraints.maxWidth
                                          : (screenWidth -
                                              48); // fallback when unconstrained
                                  final double colSpacing =
                                      (availableWidth * 0.02)
                                          .clamp(8, 48)
                                          .toDouble();

                                  // proportional column widths (sum + margins should fit availableWidth)
                                  final double numWidth = availableWidth * 0.12;
                                  final double actionsWidth =
                                      availableWidth * 0.08;
                                  final double typeWidth =
                                      availableWidth * 0.12;
                                  final double natureWidth =
                                      availableWidth * 0.18;
                                  final double intituleWidth = (availableWidth -
                                          (numWidth +
                                              actionsWidth +
                                              typeWidth +
                                              natureWidth +
                                              3 * colSpacing))
                                      .clamp(80, availableWidth * 0.40);

                                  return SizedBox(
                                    width: availableWidth,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        Colors.blue.shade400,
                                      ),
                                      headingTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      dataRowMinHeight: 32,
                                      dataRowMaxHeight: 40,
                                      columnSpacing: colSpacing,
                                      horizontalMargin: 24,
                                      columns: const [
                                        DataColumn(label: Text('N° Compte')),
                                        DataColumn(label: Text('Intitulé')),
                                        DataColumn(label: Text('Type')),
                                        DataColumn(label: Text('Nature')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows:
                                          _filteredComptes.map((compte) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  SizedBox(
                                                    width: numWidth,
                                                    child: Text(
                                                      compte.numeroCompte,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: intituleWidth,
                                                    child: Text(
                                                      compte.intitule,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: typeWidth,
                                                    child: Text(
                                                      compte.type.toLabel(),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: natureWidth,
                                                    child: Text(
                                                      compte.nature.toLabel(),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _getNatureColor(
                                                          compte.nature,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: actionsWidth,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Flexible(
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                              size: 20,
                                                            ),
                                                            color:
                                                                Colors
                                                                    .blue
                                                                    .shade700,
                                                            onPressed:
                                                                () =>
                                                                    _showCompteDialog(
                                                                      compte:
                                                                          compte,
                                                                    ),
                                                            tooltip: 'Modifier',
                                                          ),
                                                        ),
                                                        Flexible(
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              size: 20,
                                                            ),
                                                            color:
                                                                Colors
                                                                    .red
                                                                    .shade700,
                                                            onPressed:
                                                                () =>
                                                                    _deleteCompte(
                                                                      compte,
                                                                    ),
                                                            tooltip:
                                                                'Supprimer',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNatureColor(NatureCompte nature) {
    switch (nature) {
      case NatureCompte.bilanRessourcesDurables:
        return Colors.blue.shade400;
      case NatureCompte.bilanActifImmobilise:
        return Colors.blue.shade600;
      case NatureCompte.bilanStocks:
        return Colors.blue.shade500;
      case NatureCompte.bilanFournisseurs:
        return Colors.orange.shade700;
      case NatureCompte.bilanAdherentsClientsUsagers:
        return Colors.green.shade700;
      case NatureCompte.bilanPersonnel:
        return Colors.purple.shade700;
      case NatureCompte.bilanOrganismesSociaux:
        return Colors.pink.shade700;
      case NatureCompte.bilanEtatCollectivitesPubliques:
        return Colors.red.shade700;
      case NatureCompte.bilanAutresTiers:
        return Colors.amber.shade700;
      case NatureCompte.bilanBanque:
        return Colors.teal.shade700;
      case NatureCompte.bilanCaisse:
        return Colors.cyan.shade700;
      case NatureCompte.bilanAutresTresoreries:
        return Colors.indigo.shade700;
      case NatureCompte.engagementsHorsBilan:
        return Colors.grey.shade700;
      case NatureCompte.chargesAO:
        return Colors.red.shade500;
      case NatureCompte.chargesHAO:
        return Colors.red.shade400;
      case NatureCompte.produitsAO:
        return Colors.green.shade500;
      case NatureCompte.produitsHAO:
        return Colors.green.shade400;
    }
  }
}
