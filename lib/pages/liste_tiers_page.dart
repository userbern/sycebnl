import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/tiers.dart';
import '../models/compte.dart';
import '../services/export_service.dart';

class ListeTiersPage extends StatefulWidget {
  const ListeTiersPage({super.key});

  @override
  State<ListeTiersPage> createState() => _ListeTiersPageState();
}

class _ListeTiersPageState extends State<ListeTiersPage> {
  List<Tiers> _tiers = [];
  List<Compte> _comptes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  TypeTiers? _selectedType; // null = tous les types
  String _sortBy = 'numero'; // 'numero' ou 'intitule'

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _loadData();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<Tiers> get _filteredTiers {
    var filtered = List<Tiers>.from(_tiers);

    // Filtrer par texte de recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((tiers) {
            return tiers.numeroCompte.toLowerCase().contains(query) ||
                tiers.intitule.toLowerCase().contains(query);
          }).toList();
    }

    // Filtrer par type
    if (_selectedType != null) {
      filtered = filtered.where((t) => t.type == _selectedType).toList();
    }

    // Trier
    if (_sortBy == 'numero') {
      filtered.sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));
    } else if (_sortBy == 'intitule') {
      filtered.sort((a, b) => a.intitule.compareTo(b.intitule));
    }

    return filtered;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tiers = await DatabaseService.getAllTiers();
      final comptes = await DatabaseService.getAllComptes();
      setState(() {
        _tiers = tiers;
        _comptes = comptes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  /// Cherche un compte qui commence par le numéro extrait
  /// Ex: "4011AB" -> extrait "4011" -> cherche un compte commençant par "4011"
  Compte? _findCompteByNumero(String tiersNumero) {
    if (tiersNumero.isEmpty) return null;

    // Extraire la partie numérique au début
    String numeriqueOnly = '';
    for (var char in tiersNumero.split('')) {
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        // 0-9
        numeriqueOnly += char;
      } else {
        break; // S'arrêter à la première lettre
      }
    }

    if (numeriqueOnly.isEmpty) return null;

    // Chercher un compte qui commence par ce numéro
    try {
      return _comptes.firstWhere(
        (compte) => compte.numeroCompte.startsWith(numeriqueOnly),
      );
    } catch (e) {
      // Aucun compte trouvé
      return null;
    }
  }

  /// Détermine le type de tiers basé sur le numéro de compte
  /// 41 -> Adhérent - client usager
  /// 40 -> Fournisseurs
  /// 52 -> Banque
  /// 57 -> Caisse
  /// 47 -> Autres
  /// 42 -> Salarié
  TypeTiers? _getTypeFromCompteNumber(String numeroCompte) {
    if (numeroCompte.isEmpty || numeroCompte.length < 2) return null;

    final prefix = numeroCompte.substring(0, 2);

    switch (prefix) {
      case '41':
        return TypeTiers.client; // Adhérent - client usager
      case '40':
        return TypeTiers.fournisseur; // Fournisseurs
      case '52':
        return TypeTiers.banque; // Banque
      case '57':
        return TypeTiers.caisse; // Caisse
      case '47':
        return TypeTiers.autre; // Autres
      case '42':
        return TypeTiers.salarie; // Salarié
      default:
        return null;
    }
  }

  void _showTiersDialog({Tiers? tiers}) {
    final isEdit = tiers != null;
    final numeroController = TextEditingController(
      text: tiers?.numeroCompte ?? '',
    );
    final intituleController = TextEditingController(
      text: tiers?.intitule ?? '',
    );
    final nifController = TextEditingController(text: tiers?.nif ?? '');
    final adresseController = TextEditingController(text: tiers?.adresse ?? '');

    // Variables d'état pour le dialog - déclarées ici pour persister
    TypeTiers selectedType = tiers?.type ?? TypeTiers.client;
    String selectedCompteCollectif = tiers?.compteCollectif ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(context);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: Colors.blue.shade100,
                    ),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'Modifier le tiers' : 'Nouveau tiers'),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Numéro de compte
                        TextField(
                          controller: numeroController,
                          enabled: !isEdit,
                          onChanged:
                              !isEdit
                                  ? (value) {
                                    // Chercher le compte correspondant
                                    final compteCollectif = _findCompteByNumero(
                                      value,
                                    );
                                    // Déterminer le type de tiers basé sur le numéro
                                    final tiersType = _getTypeFromCompteNumber(
                                      value,
                                    );
                                    setDialogState(() {
                                      if (compteCollectif != null) {
                                        selectedCompteCollectif =
                                            compteCollectif.numeroCompte;
                                      } else {
                                        selectedCompteCollectif = '';
                                      }
                                      if (tiersType != null) {
                                        selectedType = tiersType;
                                      }
                                    });
                                  }
                                  : null,
                          decoration: InputDecoration(
                            labelText: 'N° compte *',
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
                            filled: true,
                            fillColor:
                                isEdit
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Intitulé
                        TextField(
                          controller: intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Type
                        DropdownButtonFormField<TypeTiers>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type *',
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
                            filled: true,
                            fillColor:
                                isEdit
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade50,
                          ),
                          items:
                              TypeTiers.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type.toLabel()),
                                );
                              }).toList(),
                          onChanged:
                              isEdit
                                  ? null
                                  : (value) {
                                    if (value != null) {
                                      setDialogState(
                                        () => selectedType = value,
                                      );
                                    }
                                  },
                        ),
                        const SizedBox(height: 16),

                        // Compte collectif
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value:
                                    selectedCompteCollectif.isEmpty
                                        ? null
                                        : selectedCompteCollectif,
                                decoration: InputDecoration(
                                  labelText: 'Compte collectif *',
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
                                  filled: true,
                                  fillColor:
                                      isEdit
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade50,
                                ),
                                items:
                                    _comptes.map((compte) {
                                      final displayIntitule =
                                          compte.intitule.isEmpty
                                              ? compte.nature.toLabel()
                                              : compte.intitule;
                                      return DropdownMenuItem(
                                        value: compte.numeroCompte,
                                        child: Text(
                                          '${compte.numeroCompte} - $displayIntitule',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                onChanged:
                                    isEdit
                                        ? null
                                        : (value) {
                                          if (value != null) {
                                            setDialogState(
                                              () =>
                                                  selectedCompteCollectif =
                                                      value,
                                            );
                                          }
                                        },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color:
                                    isEdit
                                        ? Colors.grey.shade400
                                        : Colors.blue.shade400,
                              ),
                              tooltip: 'Créer un nouveau compte',
                              onPressed:
                                  isEdit
                                      ? null
                                      : () async {
                                        _showCompteDialogInlined(
                                          setDialogState: setDialogState,
                                          onCompteCreated: (numeroCompte) {
                                            setDialogState(() {
                                              selectedCompteCollectif =
                                                  numeroCompte;
                                            });
                                          },
                                        );
                                      },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // NIF
                        TextField(
                          controller: nifController,
                          decoration: InputDecoration(
                            labelText: 'NIF',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Adresse
                        TextField(
                          controller: adresseController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Adresse',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  if (!isEdit)
                    ElevatedButton(
                      onPressed: () async {
                        if (numeroController.text.isEmpty ||
                            intituleController.text.isEmpty ||
                            selectedCompteCollectif.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez remplir tous les champs obligatoires',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        try {
                          await DatabaseService.createTiers(
                            numeroController.text,
                            intituleController.text,
                            selectedType.toDbString(),
                            selectedCompteCollectif,
                            nifController.text.isEmpty
                                ? null
                                : nifController.text,
                            adresseController.text.isEmpty
                                ? null
                                : adresseController.text,
                          );

                          // Réinitialiser le formulaire
                          numeroController.clear();
                          intituleController.clear();
                          nifController.clear();
                          adresseController.clear();
                          setDialogState(() {
                            selectedType = TypeTiers.client;
                            selectedCompteCollectif = '';
                          });

                          await _loadData();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tiers ajouté avec succès'),
                                backgroundColor: Colors.green,
                              ),
                            );
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
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ajouter et continuer'),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                      if (numeroController.text.isEmpty ||
                          intituleController.text.isEmpty ||
                          selectedCompteCollectif.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez remplir tous les champs obligatoires',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      try {
                        if (isEdit) {
                          await DatabaseService.updateTiers(
                            int.parse(tiers.id),
                            numeroController.text,
                            intituleController.text,
                            selectedType.toDbString(),
                            selectedCompteCollectif,
                            nifController.text.isEmpty
                                ? null
                                : nifController.text,
                            adresseController.text.isEmpty
                                ? null
                                : adresseController.text,
                          );
                        } else {
                          await DatabaseService.createTiers(
                            numeroController.text,
                            intituleController.text,
                            selectedType.toDbString(),
                            selectedCompteCollectif,
                            nifController.text.isEmpty
                                ? null
                                : nifController.text,
                            adresseController.text.isEmpty
                                ? null
                                : adresseController.text,
                          );
                        }

                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Tiers modifié avec succès'
                                    : 'Tiers ajouté avec succès',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
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
                    },
                    child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCompteDialogInlined({
    required StateSetter setDialogState,
    required Function(String) onCompteCreated,
  }) {
    final numeroController = TextEditingController();
    final intituleController = TextEditingController();
    final descriptionController = TextEditingController();
    TypeCompte selectedType = TypeCompte.detail;
    NatureCompte? calculatedNature;
    bool liaisonTiers = false;
    final formKey = GlobalKey<FormState>();

    // Charger la longueur du compte
    DatabaseService.getFileConfig().then((config) {
      if (config != null && config['longueur_compte_general'] != null) {
        // longueur du compte chargée
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setCompteDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue.shade400),
                  const SizedBox(width: 12),
                  const Text(
                    'Nouveau compte',
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
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: numeroController,
                                label: 'N° Compte *',
                                icon: Icons.numbers,
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                enabled: true,
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
                                  setCompteDialogState(() {
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
                                    TypeCompte.values.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(type.toLabel()),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setCompteDialogState(() {
                                      selectedType = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      calculatedNature != null
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        calculatedNature != null
                                            ? Colors.blue.shade300
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color:
                                          calculatedNature != null
                                              ? Colors.blue.shade400
                                              : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Nature',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            calculatedNature?.toLabel() ??
                                                'Auto',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  calculatedNature != null
                                                      ? Colors.blue.shade900
                                                      : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: descriptionController,
                          label: 'Description',
                          icon: Icons.notes,
                          maxLines: 3,
                          enabled: true,
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
                            setCompteDialogState(() {
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

                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(context);
                          // Callback pour mettre à jour le compte collectif sélectionné
                          onCompteCreated(paddedNumero);
                          // Mettre à jour la liste des comptes dans le dialog des tiers
                          setDialogState(() {
                            _comptes.clear();
                            DatabaseService.getAllComptes().then((comptes) {
                              setDialogState(() {
                                _comptes = comptes;
                              });
                            });
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Compte créé avec succès'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
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
                  icon: const Icon(Icons.add),
                  label: const Text('Créer le compte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _padNumeroCompte(String numero, TypeCompte type) {
    int longueurCompteGeneral = 7;
    // Ne compléter avec des zéros que pour les comptes de type "detail"
    if (type == TypeCompte.total) {
      return numero;
    }

    if (numero.length >= longueurCompteGeneral) {
      return numero;
    }
    return numero.padRight(longueurCompteGeneral, '0');
  }

  NatureCompte? calculateNatureFromNumeroCompte(String numero) {
    if (numero.isEmpty ) return null;

    final firstDigit = int.tryParse(numero[0]);
    if (firstDigit == null) return null;

    // Cas des 2 premiers chiffres pour plus de précision
    if (numero.length >= 2) {
      final firstTwoDigits = numero.substring(0, 2);

      switch (firstTwoDigits) {
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
          return NatureCompte.bilanAutresTresoreries;
        case '52':
          return NatureCompte.bilanBanque;
        case '57':
          return NatureCompte.bilanCaisse;
        // Cas pour 8X (charge ou produit hors activités ordinaires)
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
    }

    // Cas du premier chiffre uniquement
    switch (firstDigit) {
      case 1:
        return NatureCompte.bilanRessourcesDurables;
      case 2:
        return NatureCompte.bilanActifImmobilise;
      case 3:
        return NatureCompte.bilanStocks;
      case 6:
        return NatureCompte.chargesAO;
      case 7:
        return NatureCompte.produitsAO;
      case 8:
        // Vérifier le 2e chiffre pour déterminer si c'est charge ou produit
        if (numero.length >= 2) {
          final secondDigit = int.tryParse(numero[1]);
          if (secondDigit != null) {
            return (secondDigit % 2 == 0)
                ? NatureCompte.produitsHAO
                : NatureCompte.chargesHAO;
          }
        }
        return null;
      case 9:
        return NatureCompte.engagementsHorsBilan;
      default:
        return null;
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

  Future<void> _deleteTiers(Tiers tiers) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer le tiers "${tiers.intitule}" ?',
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
        await DatabaseService.deleteTiers(int.parse(tiers.id));
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tiers supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
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

  Color _getTypeColor(TypeTiers type) {
    switch (type) {
      case TypeTiers.client:
        return Colors.blue;
      case TypeTiers.fournisseur:
        return Colors.orange;
      case TypeTiers.salarie:
        return Colors.green;
      case TypeTiers.banque:
        return Colors.purple;
      case TypeTiers.caisse:
        return Colors.teal;
      case TypeTiers.autre:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          _showTiersDialog();
        }
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.people, size: 32, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Liste des tiers',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Boutons d'export
                  ElevatedButton.icon(
                    onPressed: () {
                      final tiers =
                          _filteredTiers.map((t) {
                            return {
                              'numeroCompte': t.numeroCompte,
                              'intitule': t.intitule,
                              'type': t.type.toLabel(),
                              'nif': t.nif ?? '',
                            };
                          }).toList();
                      ExportService.exportTiersPDF(
                        tiers: tiers,
                        context: context,
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final tiers =
                          _filteredTiers.map((t) {
                            return {
                              'numeroCompte': t.numeroCompte,
                              'intitule': t.intitule,
                              'type': t.type.toLabel(),
                              'nif': t.nif ?? '',
                            };
                          }).toList();
                      ExportService.exportTiersExcel(
                        tiers: tiers,
                        context: context,
                      );
                    },
                    icon: const Icon(Icons.table_chart, color: Colors.white),
                    label: const Text('Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showTiersDialog(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Nouveau tiers (Ctrl+N)'),
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
                    flex: 2,
                    child: TextField(
                      onChanged:
                          (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Rechercher un tiers',
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
                    child: DropdownButtonFormField<TypeTiers?>(
                      value: _selectedType,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Type de tiers',
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
                          child: Text('-- Tous --'),
                        ),
                        for (final type in TypeTiers.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.toLabel()),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Trier par',
                        prefixIcon: const Icon(Icons.sort),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'numero',
                          child: Text('Numéro de compte'),
                        ),
                        DropdownMenuItem(
                          value: 'intitule',
                          child: Text('Intitulé'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value ?? 'numero');
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
                          _searchQuery = '';
                          _selectedType = null;
                          _sortBy = 'numero';
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
                        : _filteredTiers.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun tiers trouvé',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Container(
                                width: constraints.maxWidth,
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
                                    child: LayoutBuilder(
                                      builder: (context, innerConstraints) {
                                        final double tableWidth =
                                            innerConstraints.maxWidth;
                                        final double columnSpacing =
                                            (tableWidth * 0.02)
                                                .clamp(6, 24)
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
                                          return value.clamp(min, upper);
                                        }

                                        final double numWidth = clampWidth(
                                          tableWidth * 0.14,
                                          120,
                                          0.20,
                                        );
                                        final double intituleWidth = clampWidth(
                                          tableWidth * 0.26,
                                          150,
                                          0.34,
                                        );
                                        final double typeWidth = clampWidth(
                                          tableWidth * 0.20,
                                          130,
                                          0.28,
                                        );
                                        final double collectifWidth =
                                            clampWidth(
                                              tableWidth * 0.22,
                                              140,
                                              0.28,
                                            );
                                        final double actionsWidth = clampWidth(
                                          tableWidth * 0.12,
                                          120,
                                          0.16,
                                        );

                                        return SizedBox(
                                          width: tableWidth,
                                          child: DataTable(
                                            headingRowColor:
                                                WidgetStateProperty.all(
                                                  Colors.blue.shade400,
                                                ),
                                            headingTextStyle: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                            headingRowHeight: 22,
                                            dataRowMinHeight: 14,
                                            dataRowMaxHeight: 18,
                                            columnSpacing: columnSpacing,
                                            horizontalMargin: 6,
                                            columns: const [
                                              DataColumn(
                                                label: Text('N° Compte'),
                                              ),
                                              DataColumn(
                                                label: Text('Intitulé'),
                                              ),
                                              DataColumn(label: Text('Type')),
                                              DataColumn(
                                                label: Text('Compte Collectif'),
                                              ),
                                              DataColumn(
                                                label: Text('Actions'),
                                              ),
                                            ],
                                            rows:
                                                _filteredTiers.map((tiers) {
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        SizedBox(
                                                          width: numWidth,
                                                          child: Text(
                                                            tiers.numeroCompte,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 10,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: intituleWidth,
                                                          child: Text(
                                                            tiers.intitule,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: typeWidth,
                                                          child: Text(
                                                            tiers.type
                                                                .toLabel(),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              color:
                                                                  _getTypeColor(
                                                                    tiers.type,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: collectifWidth,
                                                          child: Text(
                                                            tiers
                                                                .compteCollectif,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: actionsWidth,
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            children: [
                                                              IconButton(
                                                                icon:
                                                                    const Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 14,
                                                                    ),
                                                                color:
                                                                    Colors.blue,
                                                                onPressed:
                                                                    () => _showTiersDialog(
                                                                      tiers:
                                                                          tiers,
                                                                    ),
                                                                tooltip:
                                                                    'Modifier',
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(
                                                                      minWidth:
                                                                          18,
                                                                      minHeight:
                                                                          18,
                                                                    ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.delete,
                                                                  size: 14,
                                                                ),
                                                                color:
                                                                    Colors.red,
                                                                onPressed:
                                                                    () =>
                                                                        _deleteTiers(
                                                                          tiers,
                                                                        ),
                                                                tooltip:
                                                                    'Supprimer',
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(
                                                                      minWidth:
                                                                          18,
                                                                      minHeight:
                                                                          18,
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
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
