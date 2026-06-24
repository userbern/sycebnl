import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/compte.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class PlanComptablePage extends StatefulWidget {
  const PlanComptablePage({super.key});

  @override
  State<PlanComptablePage> createState() => _PlanComptablePageState();
}

class _PlanComptablePageState extends State<PlanComptablePage> {
  List<Compte> _comptes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  NatureCompte? _selectedNature;
  TypeCompte? _selectedType;
  int _longueurCompteGeneral = 7;

  // Pagination
  int _itemsPerPage = 15;
  int _currentPage = 1;

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
        _currentPage = 1;
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

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
    });
  }

  List<Compte> get _filteredComptes {
    var filtered = List<Compte>.from(_comptes);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((compte) {
        return compte.numeroCompte.toLowerCase().contains(query) ||
            compte.intitule.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedNature != null) {
      filtered = filtered.where((compte) => compte.nature == _selectedNature).toList();
    }

    if (_selectedType != null) {
      filtered = filtered.where((compte) => compte.type == _selectedType).toList();
    }

    return filtered;
  }

  List<Compte> get _paginatedComptes {
    final filtered = _filteredComptes;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filtered.length) return [];
    return filtered.sublist(
      startIndex,
      endIndex > filtered.length ? filtered.length : endIndex,
    );
  }

  int get _totalPages {
    return (_filteredComptes.length / _itemsPerPage).ceil();
  }

  String _padNumeroCompte(String numero, TypeCompte type) {
    if (type == TypeCompte.total) return numero;
    if (numero.length >= _longueurCompteGeneral) return numero;
    return numero.padRight(_longueurCompteGeneral, '0');
  }

  // 4 couleurs uniformes selon la catégorie comptable
  Color _getNatureColor(NatureCompte nature) {
    switch (nature) {
      case NatureCompte.bilanActifImmobilise:
      case NatureCompte.bilanStocks:
      case NatureCompte.bilanAdherentsClientsUsagers:
      case NatureCompte.bilanBanque:
      case NatureCompte.bilanCaisse:
      case NatureCompte.bilanAutresTresoreries:
        return const Color(0xFF1565C0); // Bleu – Actif
      case NatureCompte.bilanRessourcesDurables:
      case NatureCompte.bilanFournisseurs:
      case NatureCompte.bilanPersonnel:
      case NatureCompte.bilanOrganismesSociaux:
      case NatureCompte.bilanEtatCollectivitesPubliques:
      case NatureCompte.bilanAutresTiers:
        return const Color(0xFFC62828); // Rouge – Passif
      case NatureCompte.chargesAO:
      case NatureCompte.chargesHAO:
        return const Color(0xFFE65100); // Orange – Charges
      case NatureCompte.produitsAO:
      case NatureCompte.produitsHAO:
        return const Color(0xFF2E7D32); // Vert – Produits
      case NatureCompte.engagementsHorsBilan:
        return const Color(0xFF546E7A); // Gris bleuté – Hors Bilan
    }
  }

  String _getNatureCategoryShort(NatureCompte nature) {
    switch (nature) {
      case NatureCompte.bilanActifImmobilise:
      case NatureCompte.bilanStocks:
      case NatureCompte.bilanAdherentsClientsUsagers:
      case NatureCompte.bilanBanque:
      case NatureCompte.bilanCaisse:
      case NatureCompte.bilanAutresTresoreries:
        return 'Actif';
      case NatureCompte.bilanRessourcesDurables:
      case NatureCompte.bilanFournisseurs:
      case NatureCompte.bilanPersonnel:
      case NatureCompte.bilanOrganismesSociaux:
      case NatureCompte.bilanEtatCollectivitesPubliques:
      case NatureCompte.bilanAutresTiers:
        return 'Passif';
      case NatureCompte.chargesAO:
      case NatureCompte.chargesHAO:
        return 'Charges';
      case NatureCompte.produitsAO:
      case NatureCompte.produitsHAO:
        return 'Produits';
      case NatureCompte.engagementsHorsBilan:
        return 'Hors Bilan';
    }
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

    Future<void> addAccount() async {
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

          numeroController.clear();
          intituleController.clear();
          descriptionController.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Compte créé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
            FocusScope.of(context).requestFocus(FocusNode());
          }

          await _loadComptes();
        } catch (e) {
          if (mounted) {
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
            return KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !isEdit) {
                  addAccount();
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
                                          calculateNatureFromNumeroCompte(value);
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
                                  items: TypeCompte.values.map((type) {
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
                            items: NatureCompte.values.map((nature) {
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
                              if (value == null) return 'Sélectionnez une nature';
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
                      onPressed: !isEdit ? () => addAccount() : null,
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
    final usedInJournaux = await DatabaseService.isCompteUsedInJournaux(
      numeroCompte,
    );
    return usedInJournaux;
  }

  Future<void> _deleteCompte(Compte compte) async {
    final isUsed = await _isCompteUtilise(compte.numeroCompte);
    if (!mounted) return;
    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce compte est utilisé dans une autre table et ne peut pas être supprimé.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer la suppression'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer le compte '),
              TextSpan(
                text: "'${compte.intitule}'",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' ('),
              TextSpan(
                text: compte.numeroCompte,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ') ?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
    );
  }

  // Carte mobile pour un compte
  Widget _buildMobileCard(Compte compte) {
    final isTotal = compte.type == TypeCompte.total;
    final color = _getNatureColor(compte.nature);
    final category = _getNatureCategoryShort(compte.nature);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isTotal ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isTotal ? Colors.blueGrey.shade300 : Colors.grey.shade200,
          width: isTotal ? 1.5 : 1,
        ),
      ),
      color: isTotal ? Colors.blueGrey.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Barre d'accentuation colorée
            Container(
              width: 4,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        compte.numeroCompte,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (isTotal) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    compte.intitule,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    compte.nature.toLabel(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade700),
                  onPressed: () => _showCompteDialog(compte: compte),
                  tooltip: 'Modifier',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 16, color: Colors.red.shade700),
                  onPressed: () => _deleteCompte(compte),
                  tooltip: 'Supprimer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
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
        backgroundColor: const Color(0xFFF5F7FA),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                size: 26,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Plan Comptable',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHeaderActions(),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Plan Comptable',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      _buildHeaderActions(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Barre de recherche et filtres
              _buildFilterBar(),
              const SizedBox(height: 16),

              // Légende des couleurs
              _buildColorLegend(),
              const SizedBox(height: 16),

              // Contenu principal
              Expanded(
                child: _isLoading
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
                        : Column(
                            children: [
                              Expanded(child: _buildMainContent()),
                              const SizedBox(height: 12),
                              _buildPaginationControls(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () => ImportService.importPlanComptable(
            context: context,
            onSuccess: _loadComptes,
          ),
          icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
          label: const Text('Importer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final comptes = _filteredComptes.map((c) => {
              'numeroCompte': c.numeroCompte,
              'intitule': c.intitule,
              'nature': c.nature.toLabel(),
              'type': c.type.toLabel(),
            }).toList();
            ExportService.exportPlanComptablePDF(comptes: comptes, context: context);
          },
          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
          label: const Text('PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final comptes = _filteredComptes.map((c) => {
              'numeroCompte': c.numeroCompte,
              'intitule': c.intitule,
              'nature': c.nature.toLabel(),
              'type': c.type.toLabel(),
            }).toList();
            ExportService.exportPlanComptableExcel(comptes: comptes, context: context);
          },
          icon: const Icon(Icons.table_chart, size: 16, color: Colors.white),
          label: const Text('Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        // Bouton "Nouveau compte" mis en valeur
        ElevatedButton.icon(
          onPressed: () => _showCompteDialog(),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text('Nouveau compte'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            elevation: 3,
            shadowColor: Colors.blue.shade200,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final hasActiveFilter = _searchQuery.isNotEmpty ||
        _selectedNature != null ||
        _selectedType != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveFilter ? Colors.blue.shade200 : Colors.grey.shade200,
          width: hasActiveFilter ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildNatureFilter()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTypeFilter()),
                    const SizedBox(width: 4),
                    _buildResetButton(hasActiveFilter),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: _buildSearchField()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildNatureFilter()),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildTypeFilter()),
              const SizedBox(width: 8),
              _buildResetButton(hasActiveFilter),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _resetPagination();
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un compte…',
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildNatureFilter() {
    return DropdownButtonFormField<NatureCompte?>(
      isExpanded: true,
      isDense: true,
      value: _selectedNature,
      decoration: InputDecoration(
        labelText: 'Nature',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(
          Icons.circle,
          size: 10,
          color: _selectedNature != null
              ? _getNatureColor(_selectedNature!)
              : Colors.grey.shade400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('— Toutes —', style: TextStyle(fontSize: 12))),
        for (final nature in NatureCompte.values)
          DropdownMenuItem(
            value: nature,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getNatureColor(nature),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    nature.toLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        setState(() => _selectedNature = value);
        _resetPagination();
      },
    );
  }

  Widget _buildTypeFilter() {
    return DropdownButtonFormField<TypeCompte?>(
      isExpanded: true,
      isDense: true,
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Type',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(Icons.type_specimen, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('— Tous —', style: TextStyle(fontSize: 12))),
        for (final type in TypeCompte.values)
          DropdownMenuItem(
            value: type,
            child: Text(type.toLabel(), style: const TextStyle(fontSize: 12)),
          ),
      ],
      onChanged: (value) {
        setState(() => _selectedType = value);
        _resetPagination();
      },
    );
  }

  Widget _buildResetButton(bool hasActiveFilter) {
    return Tooltip(
      message: 'Réinitialiser les filtres',
      child: Material(
        color: hasActiveFilter ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _searchQuery = '';
              _selectedNature = null;
              _selectedType = null;
            });
            _resetPagination();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasActiveFilter ? Colors.blue.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              Icons.clear,
              size: 18,
              color: hasActiveFilter ? Colors.blue.shade600 : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  // Légende rapide des 4 catégories de couleurs
  Widget _buildColorLegend() {
    final items = [
      ('Actif', const Color(0xFF1565C0)),
      ('Passif', const Color(0xFFC62828)),
      ('Charges', const Color(0xFFE65100)),
      ('Produits', const Color(0xFF2E7D32)),
    ];
    return Row(
      children: [
        for (final item in items) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.$2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.$1,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
        Text(
          '${_filteredComptes.length} compte${_filteredComptes.length > 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        if (isMobile) {
          // Vue mobile : cartes
          return ListView.builder(
            itemCount: _paginatedComptes.length,
            itemBuilder: (context, index) {
              return _buildMobileCard(_paginatedComptes[index]);
            },
          );
        }

        // Vue desktop : tableau
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  final double screenWidth = MediaQuery.of(context).size.width;
                  final double availableWidth =
                      innerConstraints.maxWidth.isFinite
                          ? innerConstraints.maxWidth
                          : (screenWidth - 48);
                  final double colSpacing =
                      (availableWidth * 0.015).clamp(6, 32).toDouble();

                  final double numWidth = availableWidth * 0.12;
                  final double actionsWidth = availableWidth * 0.09;
                  final double typeWidth = availableWidth * 0.09;
                  final double natureWidth = availableWidth * 0.14;
                  final double intituleWidth = (availableWidth -
                          (numWidth +
                              actionsWidth +
                              typeWidth +
                              natureWidth +
                              3 * colSpacing))
                      .clamp(80, availableWidth * 0.45);

                  return SizedBox(
                    width: availableWidth,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.blue.shade700,
                      ),
                      headingRowHeight: 22,
                      headingTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                      dataRowMinHeight: 20,
                      dataRowMaxHeight: 24,
                      columnSpacing: colSpacing * 0.5,
                      horizontalMargin: 12,
                      dividerThickness: 0.5,
                      columns: const [
                        DataColumn(label: Text('N° Compte')),
                        DataColumn(label: Text('Intitulé')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Nature')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _paginatedComptes.map((compte) {
                        final isTotal = compte.type == TypeCompte.total;
                        final color = _getNatureColor(compte.nature);
                        final category = _getNatureCategoryShort(compte.nature);

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (states) {
                              if (states.contains(WidgetState.hovered)) {
                                return Colors.blue.shade50;
                              }
                              return isTotal
                                  ? const Color(0xFFF0F4F8)
                                  : Colors.white;
                            },
                          ),
                          cells: [
                            // N° Compte
                            DataCell(
                              SizedBox(
                                width: numWidth,
                                child: Text(
                                  compte.numeroCompte,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isTotal
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                            // Intitulé avec indentation pour les comptes détail
                            DataCell(
                              SizedBox(
                                width: intituleWidth,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: isTotal ? 0.0 : 14.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isTotal) ...[
                                        Icon(
                                          Icons.subdirectory_arrow_right,
                                          size: 11,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 3),
                                      ],
                                      Flexible(
                                        child: Text(
                                          compte.intitule,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isTotal
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Type
                            DataCell(
                              SizedBox(
                                width: typeWidth,
                                child: Text(
                                  compte.type.toLabel(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isTotal
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isTotal
                                        ? Colors.blueGrey.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            // Nature avec point coloré et catégorie courte
                            DataCell(
                              Tooltip(
                                message: compte.nature.toLabel(),
                                child: SizedBox(
                                  width: natureWidth,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          category,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Actions
                            DataCell(
                              SizedBox(
                                width: actionsWidth,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, size: 15),
                                        color: Colors.blue.shade700,
                                        onPressed: () =>
                                            _showCompteDialog(compte: compte),
                                        tooltip: 'Modifier',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, size: 15),
                                        color: Colors.red.shade700,
                                        onPressed: () => _deleteCompte(compte),
                                        tooltip: 'Supprimer',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
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
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final totalItems = _filteredComptes.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          if (isMobile) {
            return Column(
              children: [
                Text(
                  'Page $_currentPage / $totalPages  •  $totalItems compte${totalItems > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _paginationButton(
                      icon: Icons.arrow_back,
                      label: '',
                      enabled: _currentPage > 1,
                      onPressed: () => setState(() => _currentPage--),
                    ),
                    const SizedBox(width: 8),
                    _paginationButton(
                      icon: Icons.arrow_forward,
                      label: '',
                      enabled: _currentPage < totalPages,
                      onPressed: () => setState(() => _currentPage++),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $_currentPage sur $totalPages  •  $totalItems compte${totalItems > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  _paginationButton(
                    icon: Icons.arrow_back,
                    label: 'Précédent',
                    enabled: _currentPage > 1,
                    onPressed: () => setState(() => _currentPage--),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: DropdownButtonFormField<int>(
                      isDense: true,
                      value: _currentPage,
                      decoration: InputDecoration(
                        labelText: 'Page',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: List.generate(
                        totalPages,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) setState(() => _currentPage = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int>(
                      isDense: true,
                      value: _itemsPerPage,
                      decoration: InputDecoration(
                        labelText: 'Par page',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [5, 10, 15, 20, 50]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value', style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _itemsPerPage = value;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _paginationButton(
                    icon: Icons.arrow_forward,
                    label: 'Suivant',
                    enabled: _currentPage < totalPages,
                    onPressed: () => setState(() => _currentPage++),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _paginationButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: label.isNotEmpty ? Text(label) : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade500,
        padding: EdgeInsets.symmetric(
          horizontal: label.isNotEmpty ? 14 : 10,
          vertical: 10,
        ),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}
