import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/auth_service_local.dart';
import '../models/user_session.dart';
import 'entite_identification_page.dart';
import 'nouvel_exercice_page.dart';
import 'plan_comptable_page.dart';
import 'liste_tiers_page.dart';
import 'journaux_page.dart';
import 'liste_bailleurs_page.dart';
import 'liste_projets_page.dart';
import 'gestion_budgets_page.dart';
import 'journal_page.dart';
import 'journal_periode_selection_page.dart';
import 'journaux_de_saisie_page.dart';
import 'grand_livre_page.dart';
import 'saisie_ecriture_page.dart';
import 'balance_comptes_page.dart';
import 'permissions_page.dart';
import 'interrogations_lettrages_page.dart';
import 'liste_exercices_page.dart';
import '../models/saisie_comptable.dart';

class HomePage extends StatefulWidget {
  final UserSession? userSession;

  const HomePage({super.key, this.userSession});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  String? _expandedMenu;
  Map<String, dynamic>? _entiteData;

  List<Map<String, dynamic>> _exercices = [];
  int? _activeExerciceId;
  static const int _saisiePageIndex = 99;
  JournalPeriode? _activeSaisiePeriode;
  int? _previousPageIndex;
  Completer<bool>? _saisieCompleter;
  int _journauxRefreshSeed = 0;
  int _selectionRefreshSeed = 0;
  bool _isSidebarCollapsed = false;
  // null = pas encore chargé (= aucune restriction appliquée)
  Map<String, Map<String, bool>>? _modulePermissions;
  static const List<_QuickAccessItem> _quickAccessItems = [
    _QuickAccessItem(
      label: 'Plan comptable',
      icon: Icons.list_alt,
      pageIndex: 4,
    ),
    _QuickAccessItem(label: 'Codes journaux', icon: Icons.code, pageIndex: 6),
    _QuickAccessItem(
      label: 'Saisie comptable',
      icon: Icons.receipt_long,
      pageIndex: 10,
    ),
    _QuickAccessItem(
      label: 'Journaux de saisie',
      icon: Icons.view_list,
      pageIndex: 16,
    ),
    _QuickAccessItem(
      label: 'Interrogations & Lettrages',
      icon: Icons.search,
      pageIndex: 11,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    print('DEBUG: Début du chargement des données...');
    try {
      print('DEBUG: Récupération de l\'entité...');
      final entite = await DatabaseService.getEntite();
      print('DEBUG: Entité récupérée: $entite');

      print('DEBUG: Récupération de la config...');
      final config = await DatabaseService.getConfig();
      print('DEBUG: Config récupérée: $config');

      print('DEBUG: Récupération des exercices...');
      final exercices = await DatabaseService.getExercices();
      print('DEBUG: Exercices récupérés: $exercices');

      final activeExercice = exercices.firstWhere(
        (e) => e['is_active'] == 1,
        orElse: () => exercices.isNotEmpty ? exercices.first : {},
      );

      print('DEBUG: Mise à jour du state...');
      setState(() {
        _entiteData = entite;
        _exercices = exercices;
        _activeExerciceId = activeExercice['id'];
      });
      print('DEBUG: State mis à jour avec succès!');

      // Charger les permissions pour les non-admin
      if (widget.userSession != null && widget.userSession!.isAdmin != true) {
        final userId = int.tryParse(widget.userSession!.id);
        if (userId != null) {
          try {
            final rawPerms = await AuthService.getUserPermissions(userId);
            final perms = <String, Map<String, bool>>{};
            for (final p in rawPerms) {
              final nom = p['module_nom']?.toString() ?? '';
              if (nom.isNotEmpty) {
                perms[nom] = {
                  'lecture':      p['lecture']      == 1 || p['lecture']      == true,
                  'ajout':        p['ajout']        == 1 || p['ajout']        == true,
                  'modification': p['modification'] == 1 || p['modification'] == true,
                  'suppression':  p['suppression']  == 1 || p['suppression']  == true,
                };
              }
            }
            if (mounted) setState(() => _modulePermissions = perms);
          } catch (_) {
            // En cas d'erreur, on laisse _modulePermissions à null = aucune restriction
          }
        }
      }
    } catch (e) {
      print('DEBUG: Erreur lors du chargement: $e');
      // Ignorer les erreurs de chargement
    }
  }

  /// Règle : admin → toujours true.
  /// Pas de permission configurée (null ou module absent) → true (aucune restriction).
  /// Permission explicite lecture=false → false.
  bool _canRead(String? moduleNom) {
    if (widget.userSession?.isAdmin == true) return true;
    if (moduleNom == null) return true;
    // Permissions pas encore chargées ou vides = aucune restriction
    final perms = _modulePermissions;
    if (perms == null || perms.isEmpty) return true;
    // Module non configuré = aucune restriction
    final perm = perms[moduleNom];
    if (perm == null) return true;
    return perm['lecture'] == true;
  }

  Future<void> _refreshExercices() async {
    try {
      final exercices = await DatabaseService.getExercices();
      final activeExercice = exercices.firstWhere(
        (e) => e['is_active'] == 1,
        orElse: () => exercices.isNotEmpty ? exercices.first : {},
      );
      setState(() {
        _exercices = exercices;
        _activeExerciceId = activeExercice['id'];
      });
    } catch (e) {
      print('Erreur lors du rafraîchissement des exercices: $e');
    }
  }

  void _showPage(int index) async {
    _saisieCompleter?.complete(false);
    _saisieCompleter = null;

    // Vérifier permission de lecture
    const pageModules = <int, String>{
      1: 'identification',   4: 'plan_comptable',    5: 'liste_tiers',
      6: 'codes_journaux',   7: 'liste_bailleurs',   8: 'liste_projets',
      9: 'gestion_budgets', 10: 'saisie_comptable', 16: 'journaux_de_saisie',
     11: 'interrogations',  13: 'balance_comptes',  14: 'grand_livre',
     15: 'journal',         12: 'exercices',         17: 'exercices',
    };
    if (!_canRead(pageModules[index])) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès refusé : permission de lecture requise'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Rafraîchir la liste si on quitte la page Nouvel Exercice ou Liste exercices
    if ((_currentPageIndex == 12 || _currentPageIndex == 17) && index != _currentPageIndex) {
      await _refreshExercices();
    }

    setState(() {
      _currentPageIndex = index;
      _activeSaisiePeriode = null;
      _previousPageIndex = null;
    });
  }

  void _toggleMenu(String menuName) {
    if (_isSidebarCollapsed) {
      setState(() {
        _isSidebarCollapsed = false;
        _expandedMenu = menuName;
      });
      return;
    }
    setState(() {
      if (_expandedMenu == menuName) {
        _expandedMenu = null;
      } else {
        _expandedMenu = menuName;
      }
    });
  }

  void _toggleSidebarCollapse() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _expandedMenu = null;
      }
    });
  }

  Future<bool> _openSaisie(JournalPeriode periode) {
    final completer = Completer<bool>();
    setState(() {
      _previousPageIndex = _currentPageIndex;
      _activeSaisiePeriode = periode;
      _currentPageIndex = _saisiePageIndex;
      _saisieCompleter = completer;
    });
    return completer.future;
  }

  void _closeSaisie(bool refresh) {
    final target = _previousPageIndex ?? 10;

    setState(() {
      _currentPageIndex = target;
      _activeSaisiePeriode = null;
      _previousPageIndex = null;
      if (refresh) {
        if (target == 16) {
          _journauxRefreshSeed++;
        } else if (target == 10) {
          _selectionRefreshSeed++;
        }
      }
    });

    _saisieCompleter?.complete(refresh);
    _saisieCompleter = null;
  }

  void _showDatabaseInfo() {
    final dbPath = DatabaseService.currentDatabasePath;
    if (dbPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune base de données connectée'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = File(dbPath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
    final lastModified =
        file.existsSync()
            ? file.lastModifiedSync().toString().substring(0, 19)
            : 'N/A';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                /* Icon(Icons.storage, color: Colors.blue.shade400), */
                IconButton(
                  icon: Icon(Icons.storage, color: Colors.blue.shade400),
                  onPressed: () {
                    print('Bouton stockage cliqué');
                  },
                  tooltip: 'Stockage', // texte d'aide au survol
                ),
                const SizedBox(width: 12),
                const Text('Informations sur la base de données'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Emplacement', dbPath, canCopy: true),
                  const Divider(),
                  _buildInfoRow('Taille', '$fileSizeMB MB'),
                  const Divider(),
                  _buildInfoRow('Dernière modification', lastModified),
                  const Divider(),
                  _buildInfoRow(
                    'Statut',
                    file.existsSync() ? 'Connecté' : 'Introuvable',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: dbPath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chemin copié dans le presse-papiers'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier le chemin'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (canCopy)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copié!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copier',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExerciceSelector() {
    if (_exercices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun exercice disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue.shade400),
                const SizedBox(width: 12),
                const Text('Changer d\'exercice'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    _exercices.map((exercice) {
                      final isActive = exercice['id'] == _activeExerciceId;
                      return ListTile(
                        leading: Icon(
                          isActive
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          exercice['code'].toString(),
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${exercice['date_debut']} - ${exercice['date_fin']}',
                          style: TextStyle(fontSize: 12),
                        ),
                        tileColor: isActive ? Colors.green.shade50 : null,
                        onTap: () async {
                          if (!isActive) {
                            Navigator.pop(context);
                            await _switchExercice(exercice['id']);
                          }
                        },
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbPath = DatabaseService.currentDatabasePath;
    final fileName =
        dbPath != null ? dbPath.split(Platform.pathSeparator).last : '';
    final entiteName = _entiteData?['denomination_sociale'] ?? 'Chargement...';
    final exerciceCode =
        _exercices.isNotEmpty && _activeExerciceId != null
            ? _exercices.firstWhere(
              (e) => e['id'] == _activeExerciceId,
              orElse: () => {'code': 'N/A'},
            )['code']
            : 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Gauche: SYCEBNL + fichier
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYCEBNL Accounting',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (dbPath != null)
                  Text(
                    '📂 $fileName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
              ],
            ),
            // Centre: Entité + Exercice (cliquable)
            Expanded(
              child: InkWell(
                onTap: _showExerciceSelector,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '$entiteName - EXERCICE $exerciceCode',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, size: 18),
                  ],
                ),
              ),
            ),
            // Droite: actions
            const SizedBox(width: 100), // Espace pour équilibrer
          ],
        ),
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDatabaseInfo,
            tooltip: 'Informations base de données',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
            tooltip: 'Fermer le fichier',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar VSCode style
          Container(
            width: _isSidebarCollapsed ? 72 : 280,
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Container(
                  alignment:
                      _isSidebarCollapsed
                          ? Alignment.center
                          : Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Tooltip(
                    message:
                        _isSidebarCollapsed
                            ? 'Développer le menu'
                            : 'Réduire le menu',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _toggleSidebarCollapse,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _isSidebarCollapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: Colors.blue.shade900,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Entity info compact
                if (!_isSidebarCollapsed)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 16,
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entiteName,
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_exercices.isNotEmpty &&
                                  _activeExerciceId != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Exercice: ${_exercices.firstWhere((e) => e['id'] == _activeExerciceId, orElse: () => {'code': 'N/A'})['code']}',
                                    style: TextStyle(
                                      color: Colors.blue.shade400,
                                      fontSize: 9,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 20,
                      child: const Icon(
                        Icons.business,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                // Menu items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem('NOTRE ENTITE', Icons.business, [
                        _SubMenuItem('Identification', 1,    moduleNom: 'identification'),
                        _SubMenuItem('Autorisations d\'accès', 2),
                      ]),
                      _buildMenuItem('PARAMETRAGES', Icons.settings, [
                        _SubMenuItem('Plan comptable', 4,      moduleNom: 'plan_comptable'),
                        _SubMenuItem('Liste des tiers', 5,     moduleNom: 'liste_tiers'),
                        _SubMenuItem('Codes journaux', 6,      moduleNom: 'codes_journaux'),
                        _SubMenuItem('Liste des bailleurs', 7, moduleNom: 'liste_bailleurs'),
                        _SubMenuItem('Liste des projets', 8,   moduleNom: 'liste_projets'),
                        _SubMenuItem('Gestion des budgets', 9, moduleNom: 'gestion_budgets'),
                      ]),
                      _buildMenuItem('TRAITEMENTS', Icons.description, [
                        _SubMenuItem('Saisie comptable', 10,           moduleNom: 'saisie_comptable'),
                        _SubMenuItem('Journaux de saisie', 16,         moduleNom: 'journaux_de_saisie'),
                        _SubMenuItem('Interrogations & Lettrages', 11, moduleNom: 'interrogations'),
                      ]),
                      _buildMenuItem('EXERCICE', Icons.calendar_today, [
                        _SubMenuItem('Exercices', 17,       moduleNom: 'exercices'),
                        _SubMenuItem('Nouvel exercice', 12, moduleNom: 'exercices'),
                      ]),
                      _buildMenuItem('EDITION', Icons.print, [
                        _SubMenuItem('Balance des comptes', 13, moduleNom: 'balance_comptes'),
                        _SubMenuItem('Grand livre', 14,         moduleNom: 'grand_livre'),
                        _SubMenuItem('Journal', 15,             moduleNom: 'journal'),
                      ]),
                    ],
                  ),
                ),
                _buildQuickAccessSection(),
              ],
            ),
          ),
          // Main content area
          Expanded(child: _buildContentPage()),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    if (_quickAccessItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isSidebarCollapsed) {
      return Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.blue.shade100)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              _quickAccessItems.map((item) {
                final bool isActive = _currentPageIndex == item.pageIndex;
                return Tooltip(
                  message: item.label,
                  preferBelow: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showPage(item.pageIndex),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? Colors.blue.shade200
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          item.icon,
                          color:
                              isActive
                                  ? Colors.blue.shade900
                                  : Colors.blue.shade400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(top: BorderSide(color: Colors.blue.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Raccourcis',
            style: TextStyle(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ..._quickAccessItems.map((item) {
            final bool isActive = _currentPageIndex == item.pageIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showPage(item.pageIndex),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? Colors.blue.shade200
                            : Colors.blue.shade100.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color:
                            isActive
                                ? Colors.blue.shade900
                                : Colors.blue.shade400,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color:
                                isActive
                                    ? Colors.blue.shade900
                                    : Colors.blue.shade400,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon,
    List<_SubMenuItem> subItems,
  ) {
    if (_isSidebarCollapsed) {
      final bool isActive = subItems.any(
        (item) => item.index == _currentPageIndex,
      );
      return Tooltip(
        message: title,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleMenu(title),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isActive ? Colors.blue.shade900 : Colors.blue.shade400,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    final isExpanded = _expandedMenu == title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggleMenu(title),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isExpanded ? Colors.blue.shade100 : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isExpanded ? Colors.blue.shade400 : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: Colors.blue.shade400,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.blue.shade400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...subItems.where((s) => _canRead(s.moduleNom)).map(
            (subItem) => InkWell(
              onTap: () => _showPage(subItem.index),
              child: Container(
                padding: const EdgeInsets.only(left: 52, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color:
                      _currentPageIndex == subItem.index
                          ? Colors.blue.shade200
                          : Colors.transparent,
                ),
                child: Text(
                  subItem.title,
                  style: TextStyle(
                    color:
                        _currentPageIndex == subItem.index
                            ? Colors.blue.shade900
                            : Colors.blue.shade400,
                    fontSize: 12.5,
                    fontWeight:
                        _currentPageIndex == subItem.index
                            ? FontWeight.w600
                            : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  Future<void> _editExercice(
      int id, String code, String dateDebut, String dateFin) async {
    try {
      final db = DatabaseService.database;
      final d = DateTime.parse(dateDebut);
      final f = DateTime.parse(dateFin);
      final dureeMois = (f.year - d.year) * 12 + (f.month - d.month) + 1;
      await db.update(
        'exercice',
        {
          'code': code,
          'date_debut': dateDebut,
          'date_fin': dateFin,
          'duree_mois': dureeMois,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshExercices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercice modifié avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _switchExercice(int exerciceId) async {
    try {
      await DatabaseService.setActiveExercice(exerciceId);
      await _loadDatabaseInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exercice activé avec succès'),
          backgroundColor: Colors.green,
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
    }
  }

  Widget _buildContentPage() {
    switch (_currentPageIndex) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return EntiteIdentificationPage(onDataUpdated: _loadDatabaseInfo);
      case 2:
        return const PermissionsPage();
      case 4:
        return const PlanComptablePage();
      case 5:
        return const ListeTiersPage();
      case 6:
        return JournauxPage(
          userSession: UserSession(
            id: '0',
            login: 'admin',
            nom: 'Admin',
            prenom: 'Système',
            email: '',
            role: 'admin',
            permissions: [],
          ),
          showAppBar: false,
        );
      case 7:
        return const ListeBailleursPage(showAppBar: false);
      case 8:
        return const ListeProjetsPage(showAppBar: false);
      case 9:
        return GestionBudgetsPage(
          showAppBar: false,
          exerciceId: _activeExerciceId,
          userSession: UserSession(
            id: '0',
            login: 'admin',
            nom: 'Admin',
            prenom: 'Système',
            email: 'admin@system.local',
            role: 'admin',
            permissions: [],
          ),
        );
      case 10:
        return JournalPeriodeSelectionPage(
          key: ValueKey(_selectionRefreshSeed),
          showAppBar: false,
          onOpenPeriode: _openSaisie,
        );
      case 11:
        return InterrogationsLettragesPage(
          userSession:
              widget.userSession ??
              UserSession(
                id: '0',
                login: 'admin',
                nom: 'Admin',
                prenom: 'Système',
                email: 'admin@system.local',
                role: 'admin',
                permissions: [],
              ),
          showAppBar: false,
        );
      case 12:
        return NouvelExercicePage(
          userSession: UserSession(
            id: '0',
            login: 'admin',
            nom: 'Admin',
            prenom: 'Système',
            email: '',
            role: 'admin',
            permissions: [],
          ),
          showAppBar: false,
        );
      case 17:
        return ListeExercicesPage(
          exercices: _exercices,
          activeExerciceId: _activeExerciceId,
          onSwitch: _switchExercice,
          onCreateNew: () => _showPage(12),
          onEdit: _editExercice,
        );
      case 13:
        return BalanceComptesPage(
          exerciceId: _activeExerciceId,
          showAppBar: false,
        );
      case 14:
        return const GrandLivreScreen();
      case 15:
        return const JournalPage(showAppBar: false);
      case 16:
        return JournauxDeSaisiePage(
          key: ValueKey(_journauxRefreshSeed),
          showAppBar: false,
          onOpenPeriode: _openSaisie,
        );
      case _saisiePageIndex:
        final periode = _activeSaisiePeriode;
        if (periode == null) {
          return _buildPlaceholderPage('Sélectionnez une période de saisie');
        }
        return SaisieEcriturePage(
          journalPeriode: periode,
          showAppBar: false,
          onClose: _closeSaisie,
        );
      default:
        return _buildWelcomePage();
    }
  }

  Widget _buildPlaceholderPage(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 80, color: Colors.orange[300]),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cette fonctionnalité est en cours de développement',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Icon(Icons.dashboard, size: 32, color: Colors.blue.shade400),
              const SizedBox(width: 12),
              const Text(
                'Tableau de bord',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Accès rapide aux fonctionnalités principales',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Grille de menus rapides
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildQuickAccessCard(
                icon: Icons.edit,
                title: 'Saisie\ncomptable',
                color: Colors.blue,
                onTap: () => _showPage(10),
              ),
              _buildQuickAccessCard(
                icon: Icons.account_balance_wallet,
                title: 'Plan\ncomptable',
                color: Colors.green,
                onTap: () => _showPage(4),
              ),
              _buildQuickAccessCard(
                icon: Icons.people,
                title: 'Tiers',
                color: Colors.orange,
                onTap: () => _showPage(5),
              ),
              _buildQuickAccessCard(
                icon: Icons.book,
                title: 'Journaux',
                color: Colors.purple,
                onTap: () => _showPage(6),
              ),
              _buildQuickAccessCard(
                icon: Icons.folder,
                title: 'Projets',
                color: Colors.teal,
                onTap: () => _showPage(8),
              ),
              _buildQuickAccessCard(
                icon: Icons.account_balance,
                title: 'Bailleurs',
                color: Colors.indigo,
                onTap: () => _showPage(7),
              ),
              _buildQuickAccessCard(
                icon: Icons.pie_chart,
                title: 'Budgets',
                color: Colors.red,
                onTap: () => _showPage(9),
              ),
              _buildQuickAccessCard(
                icon: Icons.search,
                title: 'Interrogations',
                color: Colors.cyan,
                onTap: () => _showPage(11),
              ),
              _buildQuickAccessCard(
                icon: Icons.calendar_today,
                title: 'Exercice\ncomptable',
                color: Colors.amber,
                onTap: () => _showPage(12),
              ),
              _buildQuickAccessCard(
                icon: Icons.assessment,
                title: 'Balance',
                color: Colors.blueGrey,
                onTap: () => _showPage(13),
              ),
              _buildQuickAccessCard(
                icon: Icons.menu_book,
                title: 'Grand\nlivre',
                color: Colors.brown,
                onTap: () => _showPage(14),
              ),
              _buildQuickAccessCard(
                icon: Icons.receipt,
                title: 'Journal',
                color: Colors.deepOrange,
                onTap: () => _showPage(15),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Informations rapides
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.business,
                  title: 'Entité',
                  value: _entiteData?['denomination_sociale'] ?? 'N/A',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.location_on,
                  title: 'Localisation',
                  value:
                      '${_entiteData?['ville'] ?? 'N/A'}, ${_entiteData?['pays'] ?? ''}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.attach_money,
                  title: 'Monnaie',
                  value: _entiteData?['currency'] ?? 'N/A',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubMenuItem {
  final String title;
  final int index;
  final String? moduleNom;

  _SubMenuItem(this.title, this.index, {this.moduleNom});
}

class _QuickAccessItem {
  final String label;
  final IconData icon;
  final int pageIndex;

  const _QuickAccessItem({
    required this.label,
    required this.icon,
    required this.pageIndex,
  });
}
