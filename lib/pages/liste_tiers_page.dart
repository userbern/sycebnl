import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/tiers.dart';
import '../models/compte.dart';
import '../models/user_session.dart';
import '../services/export_service.dart';

class ListeTiersPage extends StatefulWidget {
  final UserSession? userSession;

  const ListeTiersPage({super.key, this.userSession});

  @override
  State<ListeTiersPage> createState() => _ListeTiersPageState();
}

class _ListeTiersPageState extends State<ListeTiersPage> {
  List<Tiers> _tiers = [];
  List<Compte> _comptes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  TypeTiers? _selectedType;
  String _sortBy = 'numero';

  // Pagination
  int _itemsPerPage = 15;
  int _currentPage = 1;

  // Permissions
  bool get _canCreate =>
      widget.userSession == null ? true : widget.userSession!.canCreate('liste_tiers');
  bool get _canModify =>
      widget.userSession == null ? true : widget.userSession!.canModify('liste_tiers');
  bool get _canDelete =>
      widget.userSession == null ? true : widget.userSession!.canDelete('liste_tiers');

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

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((tiers) {
        return tiers.numeroCompte.toLowerCase().contains(query) ||
            tiers.intitule.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedType != null) {
      filtered = filtered.where((t) => t.type == _selectedType).toList();
    }

    if (_sortBy == 'numero') {
      filtered.sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));
    } else if (_sortBy == 'intitule') {
      filtered.sort((a, b) => a.intitule.compareTo(b.intitule));
    }

    return filtered;
  }

  List<Tiers> get _paginatedTiers {
    final filtered = _filteredTiers;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= filtered.length) return [];
    return filtered.sublist(
      startIndex,
      endIndex > filtered.length ? filtered.length : endIndex,
    );
  }

  int get _totalPages {
    return (_filteredTiers.length / _itemsPerPage).ceil();
  }

  void _resetPagination() {
    setState(() => _currentPage = 1);
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
        _currentPage = 1;
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

  Compte? _findCompteByNumero(String tiersNumero) {
    if (tiersNumero.isEmpty) return null;

    String numeriqueOnly = '';
    for (var char in tiersNumero.split('')) {
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        numeriqueOnly += char;
      } else {
        break;
      }
    }

    if (numeriqueOnly.isEmpty) return null;

    try {
      return _comptes.firstWhere(
        (compte) => compte.numeroCompte.startsWith(numeriqueOnly),
      );
    } catch (e) {
      return null;
    }
  }

  TypeTiers? _getTypeFromCompteNumber(String numeroCompte) {
    if (numeroCompte.isEmpty || numeroCompte.length < 2) return null;
    final prefix = numeroCompte.substring(0, 2);
    switch (prefix) {
      case '41':
        return TypeTiers.client;
      case '40':
        return TypeTiers.fournisseur;
      case '52':
        return TypeTiers.banque;
      case '57':
        return TypeTiers.caisse;
      case '47':
        return TypeTiers.autre;
      case '42':
        return TypeTiers.salarie;
      default:
        return null;
    }
  }

  // Couleurs par type de tiers
  Color _getTypeColor(TypeTiers type) {
    switch (type) {
      case TypeTiers.client:
        return const Color(0xFF1565C0); // Bleu
      case TypeTiers.fournisseur:
        return const Color(0xFFC62828); // Rouge
      case TypeTiers.salarie:
        return const Color(0xFFE65100); // Orange
      case TypeTiers.banque:
        return const Color(0xFF00695C); // Teal
      case TypeTiers.caisse:
        return const Color(0xFF2E7D32); // Vert
      case TypeTiers.autre:
        return const Color(0xFF546E7A); // Gris bleuté
    }
  }

  void _showTiersDialog({Tiers? tiers}) {
    final isEdit = tiers != null;
    final numeroController = TextEditingController(text: tiers?.numeroCompte ?? '');
    final intituleController = TextEditingController(text: tiers?.intitule ?? '');
    final nifController = TextEditingController(text: tiers?.nif ?? '');
    final adresseController = TextEditingController(text: tiers?.adresse ?? '');

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
                      isEdit ? Icons.edit : Icons.add_circle,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Modifier le tiers' : 'Nouveau tiers',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogTextField(
                          controller: numeroController,
                          label: 'N° compte *',
                          icon: Icons.numbers,
                          enabled: !isEdit,
                          autofocus: !isEdit,
                          onChanged: !isEdit
                              ? (value) {
                                  final compteCollectif = _findCompteByNumero(value);
                                  final tiersType = _getTypeFromCompteNumber(value);
                                  setDialogState(() {
                                    selectedCompteCollectif =
                                        compteCollectif?.numeroCompte ?? '';
                                    if (tiersType != null) selectedType = tiersType;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildDialogTextField(
                          controller: intituleController,
                          label: 'Intitulé *',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TypeTiers>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type *',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            fillColor: isEdit ? Colors.grey.shade200 : Colors.grey.shade50,
                          ),
                          items: TypeTiers.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getTypeColor(type),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(type.toLabel()),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: isEdit
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => selectedType = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedCompteCollectif.isEmpty
                                    ? null
                                    : selectedCompteCollectif,
                                decoration: InputDecoration(
                                  labelText: 'Compte collectif *',
                                  prefixIcon: const Icon(Icons.account_tree),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isEdit ? Colors.grey.shade200 : Colors.grey.shade50,
                                ),
                                items: _comptes.map((compte) {
                                  final displayIntitule = compte.intitule.isEmpty
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
                                onChanged: isEdit
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setDialogState(
                                            () => selectedCompteCollectif = value,
                                          );
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color: isEdit
                                    ? Colors.grey.shade400
                                    : Colors.blue.shade700,
                              ),
                              tooltip: 'Créer un nouveau compte',
                              onPressed: isEdit
                                  ? null
                                  : () {
                                      _showCompteDialogInlined(
                                        setDialogState: setDialogState,
                                        onCompteCreated: (numeroCompte) {
                                          setDialogState(() {
                                            selectedCompteCollectif = numeroCompte;
                                          });
                                        },
                                      );
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDialogTextField(
                          controller: nifController,
                          label: 'NIF',
                          icon: Icons.badge,
                        ),
                        const SizedBox(height: 16),
                        _buildDialogTextField(
                          controller: adresseController,
                          label: 'Adresse',
                          icon: Icons.location_on,
                          maxLines: 3,
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (numeroController.text.isEmpty ||
                            intituleController.text.isEmpty ||
                            selectedCompteCollectif.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez remplir tous les champs obligatoires'),
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
                            nifController.text.isEmpty ? null : nifController.text,
                            adresseController.text.isEmpty ? null : adresseController.text,
                          );
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
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter et continuer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (numeroController.text.isEmpty ||
                          intituleController.text.isEmpty ||
                          selectedCompteCollectif.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Veuillez remplir tous les champs obligatoires'),
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
                            nifController.text.isEmpty ? null : nifController.text,
                            adresseController.text.isEmpty ? null : adresseController.text,
                          );
                        } else {
                          await DatabaseService.createTiers(
                            numeroController.text,
                            intituleController.text,
                            selectedType.toDbString(),
                            selectedCompteCollectif,
                            nifController.text.isEmpty ? null : nifController.text,
                            adresseController.text.isEmpty ? null : adresseController.text,
                          );
                        }
                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Tiers modifié avec succès' : 'Tiers ajouté avec succès',
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
                    icon: Icon(isEdit ? Icons.save : Icons.check),
                    label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setCompteDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue.shade700),
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
                                keyboardType: TextInputType.number,
                                autofocus: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Champ requis';
                                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                    return 'Seuls les chiffres sont autorisés';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setCompteDialogState(() {
                                    calculatedNature = calculateNatureFromNumeroCompte(value);
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
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Champ requis';
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
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                dropdownColor: Colors.white,
                                items: TypeCompte.values.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type.toLabel()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setCompteDialogState(() => selectedType = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: calculatedNature != null
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: calculatedNature != null
                                        ? Colors.blue.shade300
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: calculatedNature != null
                                          ? Colors.blue.shade400
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            calculatedNature?.toLabel() ?? 'Auto',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: calculatedNature != null
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
                            setCompteDialogState(() => liaisonTiers = value ?? false);
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
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                        );
                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(context);
                          onCompteCreated(paddedNumero);
                          setDialogState(() {
                            _comptes.clear();
                            DatabaseService.getAllComptes().then((comptes) {
                              setDialogState(() => _comptes = comptes);
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
    const longueurCompteGeneral = 7;
    if (type == TypeCompte.total) return numero;
    if (numero.length >= longueurCompteGeneral) return numero;
    return numero.padRight(longueurCompteGeneral, '0');
  }

  NatureCompte? calculateNatureFromNumeroCompte(String numero) {
    if (numero.isEmpty) return null;
    final firstDigit = int.tryParse(numero[0]);
    if (firstDigit == null) return null;

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
    bool enabled = true,
    bool autofocus = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
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

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool autofocus = false,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
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
    );
  }

  Future<void> _deleteTiers(Tiers tiers) async {
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
              const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer le tiers '),
              TextSpan(
                text: "'${tiers.intitule}'",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' ('),
              TextSpan(
                text: tiers.numeroCompte,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
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

  // Carte mobile pour un tiers
  Widget _buildMobileCard(Tiers tiers) {
    final color = _getTypeColor(tiers.type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
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
                        tiers.numeroCompte,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
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
                          tiers.type.toLabel(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tiers.intitule,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  if (tiers.compteCollectif.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Compte collectif : ${tiers.compteCollectif}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canModify) IconButton(
                  icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade700),
                  onPressed: () => _showTiersDialog(tiers: tiers),
                  tooltip: 'Modifier',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                if (_canDelete) IconButton(
                  icon: Icon(Icons.delete, size: 16, color: Colors.red.shade700),
                  onPressed: () => _deleteTiers(tiers),
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
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showTiersDialog();
        }
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
                                Icons.people,
                                size: 26,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Plan Tiers',
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
                          Icons.people,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Plan Tiers',
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

              // Filtres
              _buildFilterBar(),
              const SizedBox(height: 16),

              // Légende
              _buildTypeLegend(),
              const SizedBox(height: 16),

              // Contenu principal
              Expanded(
                child: _isLoading
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
                                  _searchQuery.isEmpty
                                      ? 'Aucun tiers dans le plan'
                                      : 'Aucun tiers trouvé',
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
          onPressed: () {
            final tiersList = _filteredTiers.map((t) => {
              'numeroCompte': t.numeroCompte,
              'intitule': t.intitule,
              'type': t.type.toLabel(),
              'nif': t.nif ?? '',
            }).toList();
            ExportService.exportTiersPDF(tiers: tiersList, context: context);
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
            final tiersList = _filteredTiers.map((t) => {
              'numeroCompte': t.numeroCompte,
              'intitule': t.intitule,
              'type': t.type.toLabel(),
              'nif': t.nif ?? '',
            }).toList();
            ExportService.exportTiersExcel(tiers: tiersList, context: context);
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
        if (_canCreate) ElevatedButton.icon(
          onPressed: () => _showTiersDialog(),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text('Nouveau tiers'),
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
    final hasActiveFilter =
        _searchQuery.isNotEmpty || _selectedType != null || _sortBy != 'numero';

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
                    Expanded(child: _buildTypeFilter()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSortFilter()),
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
              Expanded(flex: 2, child: _buildTypeFilter()),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildSortFilter()),
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
        hintText: 'Rechercher un tiers…',
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

  Widget _buildTypeFilter() {
    return DropdownButtonFormField<TypeTiers?>(
      isExpanded: true,
      isDense: true,
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Type',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(
          Icons.circle,
          size: 10,
          color: _selectedType != null
              ? _getTypeColor(_selectedType!)
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
        const DropdownMenuItem(
          value: null,
          child: Text('— Tous —', style: TextStyle(fontSize: 12)),
        ),
        for (final type in TypeTiers.values)
          DropdownMenuItem(
            value: type,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getTypeColor(type),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    type.toLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        setState(() => _selectedType = value);
        _resetPagination();
      },
    );
  }

  Widget _buildSortFilter() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      isDense: true,
      value: _sortBy,
      decoration: InputDecoration(
        labelText: 'Trier par',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(Icons.sort, size: 18, color: Colors.grey.shade500),
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
      items: const [
        DropdownMenuItem(
          value: 'numero',
          child: Text('Numéro', style: TextStyle(fontSize: 12)),
        ),
        DropdownMenuItem(
          value: 'intitule',
          child: Text('Intitulé', style: TextStyle(fontSize: 12)),
        ),
      ],
      onChanged: (value) {
        setState(() => _sortBy = value ?? 'numero');
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
              _selectedType = null;
              _sortBy = 'numero';
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

  Widget _buildTypeLegend() {
    final items = [
      ('Client', const Color(0xFF1565C0)),
      ('Fournisseur', const Color(0xFFC62828)),
      ('Salarié', const Color(0xFFE65100)),
      ('Banque', const Color(0xFF00695C)),
      ('Caisse', const Color(0xFF2E7D32)),
      ('Autre', const Color(0xFF546E7A)),
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
          const SizedBox(width: 14),
        ],
        Text(
          '${_filteredTiers.length} tiers',
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
          return ListView.builder(
            itemCount: _paginatedTiers.length,
            itemBuilder: (context, index) => _buildMobileCard(_paginatedTiers[index]),
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
                  final double tableWidth = innerConstraints.maxWidth.isFinite
                      ? innerConstraints.maxWidth
                      : (MediaQuery.of(context).size.width - 48);
                  final double colSpacing = (tableWidth * 0.015).clamp(6, 28).toDouble();

                  double clampW(double val, double min, double maxFactor) {
                    return val.clamp(min, math.max(min, tableWidth * maxFactor));
                  }

                  final double numWidth = clampW(tableWidth * 0.14, 100, 0.18);
                  final double intituleWidth = clampW(tableWidth * 0.26, 140, 0.34);
                  final double typeWidth = clampW(tableWidth * 0.16, 110, 0.22);
                  final double collectifWidth = clampW(tableWidth * 0.18, 110, 0.24);
                  final double nifWidth = clampW(tableWidth * 0.12, 80, 0.16);
                  final double actionsWidth = clampW(tableWidth * 0.08, 60, 0.12);

                  return SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue.shade700),
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
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      columns: const [
                        DataColumn(label: Text('N° Compte')),
                        DataColumn(label: Text('Intitulé')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Cpte Collectif')),
                        DataColumn(label: Text('NIF')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _paginatedTiers.map((tiers) {
                        final color = _getTypeColor(tiers.type);

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) {
                              return Colors.blue.shade50;
                            }
                            return Colors.white;
                          }),
                          cells: [
                            // N° Compte
                            DataCell(
                              SizedBox(
                                width: numWidth,
                                child: Text(
                                  tiers.numeroCompte,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            // Intitulé
                            DataCell(
                              SizedBox(
                                width: intituleWidth,
                                child: Text(
                                  tiers.intitule,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                            // Type avec point coloré
                            DataCell(
                              SizedBox(
                                width: typeWidth,
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
                                        tiers.type.toLabel(),
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
                            // Compte collectif
                            DataCell(
                              SizedBox(
                                width: collectifWidth,
                                child: Text(
                                  tiers.compteCollectif,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            // NIF
                            DataCell(
                              SizedBox(
                                width: nifWidth,
                                child: Text(
                                  tiers.nif ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tiers.nif != null
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade400,
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
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 15),
                                      color: Colors.blue.shade700,
                                      onPressed: () => _showTiersDialog(tiers: tiers),
                                      tooltip: 'Modifier',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 15),
                                      color: Colors.red.shade700,
                                      onPressed: () => _deleteTiers(tiers),
                                      tooltip: 'Supprimer',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
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
    final totalItems = _filteredTiers.length;

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
                  'Page $_currentPage / $totalPages  •  $totalItems tiers',
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
                'Page $_currentPage sur $totalPages  •  $totalItems tiers',
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
