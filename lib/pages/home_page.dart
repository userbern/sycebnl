import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sycebnl_accounting/widgets/app_icon.dart';
import 'package:sycebnl_accounting/widgets/company_header_card.dart';
import '../services/database_service.dart';
import '../services/local_repository.dart';
import '../services/repository_provider.dart';
import '../services/network/accounting_server_service.dart';
import '../services/network/network_connection_service.dart';
import '../widgets/network_share_dialog.dart';
import 'network_data_page.dart';
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
import 'dossier_security_page.dart';
import '../widgets/app_logo.dart';
import '../widgets/global_search_bar.dart';
import 'interrogations_lettrages_page.dart';
import 'liste_exercices_page.dart';
import 'journal_an_page.dart';
import 'dashboard_dg_page.dart';
import '../models/saisie_comptable.dart';

class HomePage extends StatefulWidget {
  final UserSession? userSession;

  const HomePage({super.key, this.userSession});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  int _createUserTrigger = 0;
  String? _expandedMenu;
  Map<String, dynamic>? _entiteData;

  List<Map<String, dynamic>> _exercices = [];
  int? _activeExerciceId;
  bool _isSwitchingExercice = false;
  int _journauxRefreshSeed = 0;
  int _selectionRefreshSeed = 0;
  int _contentRefreshSeed = 0;
  bool _isSidebarCollapsed = false;
  final List<int> _pageHistory = [];
  final List<int> _pageForwardStack = [];
  final FocusNode _globalSearchFocusNode = FocusNode();
  static const List<_QuickAccessItem> _quickAccessItems = [
    _QuickAccessItem(
      label: 'Dashboard DG',
      icon: Icons.dashboard,
      pageIndex: 18,
    ),
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

  @override
  void dispose() {
    _globalSearchFocusNode.dispose();
    super.dispose();
  }

  /// En mode réseau (client distant), il n'y a pas de connexion SQLite
  /// locale : `DatabaseService.database` lèverait immédiatement. Seules les
  /// données déjà exposées en lecture par `RemoteRepository` (exercices,
  /// entité) sont chargées ; la config n'est pas encore disponible à
  /// distance (voir `network_routes.dart`).
  bool get _isNetworkMode => NetworkConnectionService.instance.isConnected;

  Future<void> _loadDatabaseInfo() async {
    if (_isNetworkMode) {
      await _refreshExercices();
      try {
        final entites = await RepositoryProvider.current.query('entite');
        if (entites.isNotEmpty) {
          setState(() {
            _entiteData = entites.first;
          });
        }
      } catch (e) {
        print('Erreur lors du chargement de l\'entité (réseau): $e');
      }
      return;
    }
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
    } catch (e) {
      print('DEBUG: Erreur lors du chargement: $e');
      // Ignorer les erreurs de chargement
    }
  }

  /// Règle : aucun utilisateur dans la base (bootstrap) → toujours true.
  /// Sinon, délègue à UserSession.canRead (admin → true, refus par défaut
  /// si aucune permission explicite ne correspond au module).
  bool _canRead(String? moduleNom) {
    if (widget.userSession == null) return true;
    if (moduleNom == null) return true;
    return widget.userSession!.canRead(moduleNom);
  }

  Future<void> _refreshExercices() async {
    try {
      final exercices = _isNetworkMode
          ? await RepositoryProvider.current
              .query('exercice', orderBy: 'date_debut DESC')
          : await DatabaseService.getExercices();
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

  void _openCreateUserShortcut() {
    setState(() {
      _currentPageIndex = 2;
      _createUserTrigger++;
    });
  }

  void _showPage(int index, {bool recordHistory = true}) async {
    // Vérifier permission de lecture
    const pageModules = <int, String>{
      1: 'identification',
      4: 'plan_comptable',
      5: 'liste_tiers',
      6: 'codes_journaux',
      7: 'liste_bailleurs',
      8: 'liste_projets',
      9: 'gestion_budgets',
      10: 'saisie_comptable',
      16: 'journaux_de_saisie',
      11: 'interrogations',
      13: 'balance_comptes',
      14: 'grand_livre',
      15: 'journal',
      12: 'exercices',
      17: 'exercices',
      18: 'dashboard_dg',
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

    // En mode réseau, seuls comptes/tiers/journaux/bailleurs/projets (CRUD)
    // et la liste des exercices (lecture) sont câblés sur `RemoteRepository`
    // (voir `_buildContentPage`). Les autres pages dépendent encore
    // directement de `DatabaseService` (connexion SQLite locale) et
    // planteraient.
    const networkAvailablePages = {0, 4, 5, 6, 7, 8, 17};
    if (_isNetworkMode && !networkAvailablePages.contains(index)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Non disponible en mode réseau pour le moment'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Rafraîchir la liste si on quitte la page Nouvel Exercice ou Liste exercices
    if ((_currentPageIndex == 12 || _currentPageIndex == 17) &&
        index != _currentPageIndex) {
      await _refreshExercices();
    }

    setState(() {
      if (recordHistory && index != _currentPageIndex) {
        _pageHistory.add(_currentPageIndex);
        _pageForwardStack.clear();
      }
      _currentPageIndex = index;
    });
  }

  bool get _canGoBack => _pageHistory.isNotEmpty;
  bool get _canGoForward => _pageForwardStack.isNotEmpty;

  void _goBack() {
    if (_pageHistory.isEmpty) return;
    final previous = _pageHistory.removeLast();
    _pageForwardStack.add(_currentPageIndex);
    _showPage(previous, recordHistory: false);
  }

  void _goForward() {
    if (_pageForwardStack.isEmpty) return;
    final next = _pageForwardStack.removeLast();
    _pageHistory.add(_currentPageIndex);
    _showPage(next, recordHistory: false);
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

  Future<bool> _openSaisie(JournalPeriode periode) async {
    final openingPageIndex = _currentPageIndex;
    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => SaisieEcriturePage(
              journalPeriode: periode,
              userSession: widget.userSession,
              exerciceCloture: _activeExerciceCloture,
            ),
      ),
    );

    if (refresh == true && mounted) {
      setState(() {
        if (openingPageIndex == 16) {
          _journauxRefreshSeed++;
        } else if (openingPageIndex == 10) {
          _selectionRefreshSeed++;
        }
      });
    }

    return refresh ?? false;
  }

  void _reloadCurrentPage() {
    // La page Nouvel exercice est un assistant à plusieurs étapes : la
    // remonter détruirait sa progression (retour forcé au choix du mode).
    // Elle recharge déjà ses propres données, un rafraîchissement forcé
    // n'est donc pas nécessaire ici.
    if (_currentPageIndex == 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Actualisation non nécessaire : les données de cette page se '
            'rechargent automatiquement.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _contentRefreshSeed++;
    });
  }

  void _showNetworkUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Non disponible en mode réseau pour le moment'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showExerciceSelector() {
    if (_isSwitchingExercice) return;
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
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Changer d\'exercice',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._exercices.map((exercice) {
                      final isActive = exercice['id'] == _activeExerciceId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            if (!isActive) {
                              Navigator.pop(context);
                              await _switchExercice(exercice['id']);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isActive
                                        ? Colors.green.shade200
                                        : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isActive
                                          ? Colors.green.shade600
                                          : Colors.grey.shade400,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercice['code'].toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                          color:
                                              isActive
                                                  ? Colors.green.shade800
                                                  : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_fmtExerciceDate(exercice['date_debut'])} → '
                                        '${_fmtExerciceDate(exercice['date_fin'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Actif',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  String _fmtExerciceDate(Object? raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return raw?.toString() ?? '-';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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

    return CallbackShortcuts(
      bindings: {
        if (_currentPageIndex == 2)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
              _openCreateUserShortcut,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            () => _globalSearchFocusNode.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (dbPath != null)
                      Text(
                        ' $fileName',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                // Recherche globale (avant l'entité/exercice)
                SizedBox(
                  width: 260,
                  child: GlobalSearchBar(
                    focusNode: _globalSearchFocusNode,
                    exerciceId: _activeExerciceId,
                    onNavigateToPage: (index) => _showPage(index),
                    onOpenEcriture: (periode) async {
                      await _openSaisie(periode);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                // Centre: Entité + Exercice (cliquable)
                Expanded(
                  child: InkWell(
                    onTap: _isSwitchingExercice ? null : _showExerciceSelector,
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
                        _isSwitchingExercice
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.edit, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade400,
            foregroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Tooltip(
                  message: 'Retour à la page précédente',
                  child: OutlinedButton.icon(
                    onPressed: _canGoBack ? _goBack : null,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Precedent'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      disabledForegroundColor: Colors.grey.shade400,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Tooltip(
                  message: 'Revenir à la page que vous venez de quitter',
                  child: OutlinedButton.icon(
                    onPressed: _canGoForward ? _goForward : null,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Suivant'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      disabledForegroundColor: Colors.grey.shade400,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reloadCurrentPage,
                tooltip: 'Actualiser la page',
              ),
              if (!_isNetworkMode)
                IconButton(
                  icon: Icon(
                    AccountingServerService.instance.isRunning
                        ? Icons.wifi_tethering
                        : Icons.wifi_tethering_off,
                    color:
                        AccountingServerService.instance.isRunning
                            ? Colors.greenAccent
                            : Colors.white,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const NetworkShareDialog(),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  tooltip: 'Partager cette base sur le réseau',
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  if (_isNetworkMode) {
                    await NetworkConnectionService.instance.disconnect();
                  } else {
                    await AccountingServerService.instance.stop();
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed('/');
                },
                tooltip: _isNetworkMode
                    ? 'Se déconnecter de la base réseau'
                    : 'Fermer le fichier',
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
                      CompanyHeaderCard(
                        companyName: entiteName,
                        exerciceCode:
                            _exercices.isNotEmpty && _activeExerciceId != null
                                ? _exercices
                                    .firstWhere(
                                      (e) => e['id'] == _activeExerciceId,
                                      orElse: () => {'code': 'N/A'},
                                    )['code']
                                    ?.toString()
                                : null,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: AppIcon(size: 32),
                      ),
                    // Menu items
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildMenuItem('TABLEAU DE BORD', Icons.dashboard, [
                            _SubMenuItem(
                              'Dashboard DG',
                              18,
                              moduleNom: 'dashboard_dg',
                            ),
                          ]),
                          _buildMenuItem('NOTRE ENTITE', Icons.business, [
                            _SubMenuItem(
                              'Identification',
                              1,
                              moduleNom: 'identification',
                            ),
                            _SubMenuItem('Autorisations d\'accès', 2),
                            _SubMenuItem('Sécurité du dossier', 3),
                          ]),
                          _buildMenuItem('PARAMETRAGES', Icons.settings, [
                            _SubMenuItem(
                              'Plan comptable',
                              4,
                              moduleNom: 'plan_comptable',
                            ),
                            _SubMenuItem(
                              'Liste des tiers',
                              5,
                              moduleNom: 'liste_tiers',
                            ),
                            _SubMenuItem(
                              'Codes journaux',
                              6,
                              moduleNom: 'codes_journaux',
                            ),
                            _SubMenuItem(
                              'Liste des bailleurs',
                              7,
                              moduleNom: 'liste_bailleurs',
                            ),
                            _SubMenuItem(
                              'Liste des projets',
                              8,
                              moduleNom: 'liste_projets',
                            ),
                            _SubMenuItem(
                              'Gestion des budgets',
                              9,
                              moduleNom: 'gestion_budgets',
                            ),
                          ]),
                          _buildMenuItem('TRAITEMENTS', Icons.description, [
                            _SubMenuItem(
                              'Saisie comptable',
                              10,
                              moduleNom: 'saisie_comptable',
                            ),
                            _SubMenuItem(
                              'Journaux de saisie',
                              16,
                              moduleNom: 'journaux_de_saisie',
                            ),
                            _SubMenuItem(
                              'Interrogations & Lettrages',
                              11,
                              moduleNom: 'interrogations',
                            ),
                          ]),
                          _buildMenuItem('EXERCICE', Icons.calendar_today, [
                            _SubMenuItem(
                              'Exercices',
                              17,
                              moduleNom: 'exercices',
                            ),
                            _SubMenuItem(
                              'Nouvel exercice',
                              12,
                              moduleNom: 'exercices',
                            ),
                          ]),
                          _buildMenuItem('EDITION', Icons.print, [
                            _SubMenuItem(
                              'Balance des comptes',
                              13,
                              moduleNom: 'balance_comptes',
                            ),
                            _SubMenuItem(
                              'Grand livre',
                              14,
                              moduleNom: 'grand_livre',
                            ),
                            _SubMenuItem('Journal', 15, moduleNom: 'journal'),
                          ]),
                        ],
                      ),
                    ),
                    _buildQuickAccessSection(),
                  ],
                ),
              ),
              // Main content area
              Expanded(
                child: Stack(
                  children: [
                    KeyedSubtree(
                      key: ValueKey(_contentRefreshSeed),
                      child: _buildContentPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          ...subItems
              .where((s) => _canRead(s.moduleNom))
              .map(
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
    int id,
    String code,
    String dateDebut,
    String dateFin,
  ) async {
    if (!_session.isAdmin && !_session.canModify('exercices')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission insuffisante pour modifier un exercice.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      const db = LocalRepository();
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
    if (_isSwitchingExercice) return;
    setState(() => _isSwitchingExercice = true);
    try {
      await DatabaseService.setActiveExercice(exerciceId);
      await _loadDatabaseInfo();
      if (!mounted) return;
      setState(() {
        _isSwitchingExercice = false;
        // Force le remontage complet de la page actuellement affichée pour
        // qu'elle relise systématiquement les données du nouvel exercice
        // actif, même si elle ne dépend pas d'un paramètre reconstruit.
        _contentRefreshSeed++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exercice activé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSwitchingExercice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Session de secours utilisée uniquement en mode bootstrap (aucun utilisateur en base).
  static final _bootstrapSession = UserSession(
    id: '0',
    login: 'admin',
    nom: 'Admin',
    prenom: 'Système',
    email: '',
    role: 'admin',
    permissions: [],
  );

  UserSession get _session => widget.userSession ?? _bootstrapSession;

  bool get _activeExerciceCloture {
    if (_activeExerciceId == null || _exercices.isEmpty) return false;
    final ex = _exercices.firstWhere(
      (e) => e['id'] == _activeExerciceId,
      orElse: () => {},
    );
    return (ex['is_cloture'] as int? ?? 0) == 1;
  }

  Widget _buildContentPage() {
    switch (_currentPageIndex) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return EntiteIdentificationPage(onDataUpdated: _loadDatabaseInfo);
      case 2:
        return PermissionsPage(
          showAppBar: false,
          userSession: widget.userSession,
          createUserTrigger: _createUserTrigger,
        );
      case 3:
        return DossierSecurityPage(
          showAppBar: false,
          userSession: widget.userSession,
        );
      case 4:
        return _isNetworkMode
            ? const NetworkComptesView()
            : PlanComptablePage(userSession: widget.userSession);
      case 5:
        return _isNetworkMode
            ? const NetworkTiersView()
            : ListeTiersPage(userSession: widget.userSession);
      case 6:
        return _isNetworkMode
            ? const NetworkJournauxView()
            : JournauxPage(userSession: _session, showAppBar: false);
      case 7:
        return _isNetworkMode
            ? const NetworkBailleursView()
            : ListeBailleursPage(
                showAppBar: false,
                userSession: widget.userSession,
              );
      case 8:
        return _isNetworkMode
            ? const NetworkProjetsView()
            : ListeProjetsPage(
                showAppBar: false,
                userSession: widget.userSession,
              );
      case 9:
        return GestionBudgetsPage(
          showAppBar: false,
          exerciceId: _activeExerciceId,
          userSession: widget.userSession,
        );
      case 10:
        return JournalPeriodeSelectionPage(
          key: ValueKey(_selectionRefreshSeed),
          showAppBar: false,
          onOpenPeriode: _openSaisie,
          userSession: widget.userSession,
        );
      case 11:
        return InterrogationsLettragesPage(
          userSession: _session,
          showAppBar: false,
        );
      case 12:
        return NouvelExercicePage(
          userSession: _session,
          showAppBar: false,
          onExerciceCreated: _refreshExercices,
        );
      case 17:
        return ListeExercicesPage(
          exercices: _exercices,
          activeExerciceId: _activeExerciceId,
          onSwitch: _isNetworkMode
              ? (_) async => _showNetworkUnavailable()
              : _switchExercice,
          onCreateNew: _isNetworkMode
              ? _showNetworkUnavailable
              : () => _showPage(12),
          onEdit: _isNetworkMode
              ? (_, __, ___, ____) async => _showNetworkUnavailable()
              : _editExercice,
          onViewJournalAN:
              (exerciceId) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JournalAnPage(exerciceId: exerciceId),
                ),
              ),
          userSession: widget.userSession,
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
      case 18:
        return DashboardDgPage(
          exerciceId: _activeExerciceId,
          showAppBar: false,
        );
      default:
        return _buildWelcomePage();
    }
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
