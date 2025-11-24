import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import 'autorisations_acces_page.dart';
import 'entite_list_page.dart';
import 'monnaie_page.dart';
import 'plan_comptable_page.dart';
import 'liste_tiers_page.dart';
import 'journaux_page.dart';
import 'liste_bailleurs_page.dart';
import 'liste_projets_page.dart';
import 'gestion_budgets_page.dart';

class HomePage extends StatefulWidget {
  final UserSession userSession;

  const HomePage({super.key, required this.userSession});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  String? _expandedMenu;

  void _showPage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  void _toggleMenu(String menuName) {
    setState(() {
      if (_expandedMenu == menuName) {
        _expandedMenu = null;
      } else {
        _expandedMenu = menuName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'SYCEBNL Accounting',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text(
                  '${widget.userSession.prenom} ${widget.userSession.nom}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await AuthService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar VSCode style
          Container(
            width: 280,
            color: Colors.blue.shade50,
            child: Column(
              children: [
                // User info compact
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
                        child: Text(
                          widget.userSession.prenom[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.userSession.prenom} ${widget.userSession.nom}',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                widget.userSession.role,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem('NOTRE ENTITE', Icons.business, [
                        _SubMenuItem('Identification', 1),
                        _SubMenuItem('Autorisations d\'accès', 2),
                        _SubMenuItem('Monnaie', 3),
                      ]),
                      _buildMenuItem('PARAMETRAGES', Icons.settings, [
                        _SubMenuItem('Plan comptable', 4),
                        _SubMenuItem('Liste des tiers', 5),
                        _SubMenuItem('Journaux de saisie', 6),
                        _SubMenuItem('Liste des bailleurs', 7),
                        _SubMenuItem('Liste des projets', 8),
                        _SubMenuItem('Gestion des budgets', 9),
                      ]),
                      _buildMenuItem('TRAITEMENTS', Icons.description, [
                        _SubMenuItem('Saisie comptable', 10),
                      ]),
                      _buildMenuItem('EDITION', Icons.print, [
                        _SubMenuItem('Balance des comptes', 11),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(child: _buildContentPage()),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon,
    List<_SubMenuItem> subItems,
  ) {
    final isExpanded = _expandedMenu == title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggleMenu(title),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isExpanded ? Colors.blue.shade100 : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isExpanded ? Colors.blue.shade700 : Colors.transparent,
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
                  color: Colors.blue.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 12,
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
          ...subItems.map(
            (subItem) => InkWell(
              onTap: () => _showPage(subItem.index),
              child: Container(
                padding: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
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
                            : Colors.blue.shade700,
                    fontSize: 11,
                    fontWeight:
                        _currentPageIndex == subItem.index
                            ? FontWeight.w600
                            : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContentPage() {
    switch (_currentPageIndex) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return EntiteListPage(userSession: widget.userSession);
      case 2:
        return AutorisationsAccesPage(userSession: widget.userSession);
      case 3:
        return MonnaiePageEdit(userSession: widget.userSession);
      case 4:
        return PlanComptablePage(
          userSession: widget.userSession,
          showAppBar: false,
        );
      case 5:
        return ListeTiersPage(
          userSession: widget.userSession,
          showAppBar: false,
        );
      case 6:
        return JournauxPage(userSession: widget.userSession, showAppBar: false);
      case 7:
        return ListeBailleursPage(
          showAppBar: false,
          userSession: widget.userSession,
        );
      case 8:
        return ListeProjetsPage(
          showAppBar: false,
          userSession: widget.userSession,
        );
      case 9:
        return GestionBudgetsPage(
          showAppBar: false,
          userSession: widget.userSession,
        );
      default:
        return _buildWelcomePage();
    }
  }

  Widget _buildWelcomePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calculate, size: 80, color: Colors.blue[300]),
          const SizedBox(height: 24),
          const Text(
            'Bienvenue dans SYCEBNL Accounting',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez un menu dans la barre latérale',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _SubMenuItem {
  final String title;
  final int index;

  _SubMenuItem(this.title, this.index);
}
