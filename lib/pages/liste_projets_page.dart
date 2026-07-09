import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class ListeProjetsPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeProjetsPage({super.key, this.showAppBar = true, this.userSession});

  @override
  State<ListeProjetsPage> createState() => _ListeProjetsPageState();
}

class _ListeProjetsPageState extends State<ListeProjetsPage> {
  List<Map<String, dynamic>> _projets = [];
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'code';
  String _filterStatus = 'actifs';
  late FocusNode _focusNode;
  String? _entiteNom;

  int _itemsPerPage = 15;
  int _currentPage = 1;

  bool get _canCreate =>
      widget.userSession == null ? true : widget.userSession!.canCreate('liste_projets');
  bool get _canUpdate =>
      widget.userSession == null ? true : widget.userSession!.canModify('liste_projets');
  bool get _canDelete =>
      widget.userSession == null ? true : widget.userSession!.canDelete('liste_projets');

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _loadData();
    _loadEntite();
  }

  Future<void> _loadEntite() async {
    try {
      final entite = await DatabaseService.getEntite();
      if (mounted) {
        setState(() {
          _entiteNom = entite?['denomination_sociale'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement entité: $e');
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final projets = await AuthService.getProjetsWithBailleur();
      final bailleurs = await AuthService.getBailleurs();

      if (!mounted) return;
      setState(() {
        _projets = projets;
        _bailleurs =
            bailleurs
                .map(
                  (b) => {
                    'id': b.id,
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredProjets {
    var filtered = List<Map<String, dynamic>>.from(_projets);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((projet) {
            return (projet['code'] ?? '').toString().toLowerCase().contains(
                  query,
                ) ||
                (projet['designation'] ?? '').toString().toLowerCase().contains(
                  query,
                );
          }).toList();
    }

    if (_filterStatus == 'actifs') {
      filtered = filtered.where((p) => p['deleted_at'] == null).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((p) => p['deleted_at'] != null).toList();
    }

    if (_sortBy == 'code') {
      filtered.sort(
        (a, b) => (a['code'] ?? '').toString().compareTo(
          (b['code'] ?? '').toString(),
        ),
      );
    } else if (_sortBy == 'designation') {
      filtered.sort(
        (a, b) => (a['designation'] ?? '').toString().compareTo(
          (b['designation'] ?? '').toString(),
        ),
      );
    }

    return filtered;
  }

  List<Map<String, dynamic>> get _paginatedProjets {
    final filtered = _filteredProjets;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int get _totalPages => math.max(1, (_filteredProjets.length / _itemsPerPage).ceil());

  void _resetPagination() => setState(() => _currentPage = 1);

  String _getBailleursString(Map<String, dynamic> projet) {
    final bailleurs = projet['bailleurs'];
    if (bailleurs == null || bailleurs.isEmpty) return 'Aucun';
    return bailleurs.toString();
  }

  Future<void> _deleteProjet(Map<String, dynamic> projet) async {
    final code = projet['code']?.toString() ?? '';
    final designation = projet['designation']?.toString() ?? '';
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
              const TextSpan(text: 'Voulez-vous vraiment supprimer le projet '),
              TextSpan(
                text: designation.isNotEmpty ? '"$designation"' : '"$code"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' ?'),
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
        await AuthService.deleteProjet(int.parse(projet['id'].toString()));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projet supprimé'), backgroundColor: Colors.green),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProjetDialog(Map<String, dynamic>? projet) {
    showDialog(
      context: context,
      builder:
          (context) => _ProjetDialog(
            projet: projet,
            bailleurs: _bailleurs,
            onSave: (_) {
              _loadData();
              Navigator.pop(context);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showProjetDialog(null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Projets'),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
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
                              _buildPageTitle(),
                              const SizedBox(height: 12),
                              _buildHeaderActions(),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            _buildPageTitle(),
                            const Spacer(),
                            _buildHeaderActions(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterBar(),
                    const SizedBox(height: 12),
                    // Compteur
                    Text(
                      '${_filteredProjets.length} projet${_filteredProjets.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    // Contenu
                    Expanded(
                      child: _filteredProjets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty ? 'Aucun projet. Cliquez sur "Nouveau projet"' : 'Aucun projet trouvé',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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

  Widget _buildPageTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.folder_open, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Text(
          'Projets',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
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
            final data = _filteredProjets.map((p) => {
              'code': p['code']?.toString() ?? '',
              'designation': p['designation']?.toString() ?? '',
              'bailleur': p['bailleur']?.toString() ?? '',
            }).toList();
            ExportService.exportProjetsPDF(
              projets: data,
              context: context,
              entiteNom: _entiteNom,
            );
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
            final data = _filteredProjets.map((p) => {
              'code': p['code']?.toString() ?? '',
              'designation': p['designation']?.toString() ?? '',
              'bailleur': p['bailleur']?.toString() ?? '',
            }).toList();
            ExportService.exportProjetsExcel(projets: data, context: context);
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
        if (_canCreate)
          ElevatedButton.icon(
            onPressed: () => _showProjetDialog(null),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text('Nouveau projet'),
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
    final hasActiveFilter = _searchQuery.isNotEmpty || _sortBy != 'code' || _filterStatus != 'actifs';
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                    Expanded(child: _buildSortDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusDropdown()),
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
              Expanded(flex: 2, child: _buildSortDropdown()),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildStatusDropdown()),
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
      onChanged: (value) { setState(() => _searchQuery = value); _resetPagination(); },
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un projet…',
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true, isDense: true, value: _sortBy,
      decoration: InputDecoration(
        labelText: 'Trier par', labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(Icons.sort, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(value: 'code', child: Text('Code', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'designation', child: Text('Désignation', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (value) { setState(() => _sortBy = value ?? 'code'); _resetPagination(); },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true, isDense: true, value: _filterStatus,
      decoration: InputDecoration(
        labelText: 'Statut', labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(Icons.filter_alt, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(value: 'actifs', child: Text('Actifs', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'inactifs', child: Text('Inactifs', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'tous', child: Text('Tous', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (value) { setState(() => _filterStatus = value ?? 'actifs'); _resetPagination(); },
    );
  }

  Widget _buildResetButton(bool hasActiveFilter) {
    return Tooltip(
      message: 'Réinitialiser',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() { _searchQuery = ''; _sortBy = 'code'; _filterStatus = 'actifs'; });
          _resetPagination();
        },
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: hasActiveFilter ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hasActiveFilter ? Colors.blue.shade300 : Colors.grey.shade300),
          ),
          child: Icon(Icons.clear, size: 18, color: hasActiveFilter ? Colors.blue.shade600 : Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return ListView.builder(
            itemCount: _paginatedProjets.length,
            itemBuilder: (context, index) => _buildMobileCard(_paginatedProjets[index]),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, inner) {
                  final tw = inner.maxWidth.isFinite ? inner.maxWidth : (MediaQuery.of(context).size.width - 48);
                  double cw(double v, double mn, double mxf) => v.clamp(mn, math.max(mn, tw * mxf));
                  final codeW   = cw(tw * 0.13, 80,  0.16);
                  final desigW  = cw(tw * 0.30, 150, 0.38);
                  final bailW   = cw(tw * 0.25, 120, 0.30);
                  final dateW   = cw(tw * 0.12, 80,  0.15);
                  final actW    = cw(tw * 0.08, 60,  0.12);
                  return SizedBox(
                    width: tw,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue.shade700),
                      headingRowHeight: 22,
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3),
                      dataRowMinHeight: 20,
                      dataRowMaxHeight: 24,
                      columnSpacing: 8,
                      horizontalMargin: 12,
                      dividerThickness: 0.5,
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Désignation')),
                        DataColumn(label: Text('Bailleurs')),
                        DataColumn(label: Text('Début')),
                        DataColumn(label: Text('Fin')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _paginatedProjets.map((p) {
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) return Colors.blue.shade50;
                            return Colors.white;
                          }),
                          cells: [
                            DataCell(SizedBox(width: codeW, child: Text(p['code']?.toString() ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 11)))),
                            DataCell(SizedBox(width: desigW, child: Text(p['designation']?.toString() ?? '—', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)))),
                            DataCell(SizedBox(width: bailW, child: Text(_getBailleursString(p), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)))),
                            DataCell(SizedBox(width: dateW, child: Text(_formatDate(p['date_debut']), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))),
                            DataCell(SizedBox(width: dateW, child: Text(_formatDate(p['date_fin']), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))),
                            DataCell(SizedBox(
                              width: actW,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (_canUpdate) IconButton(icon: const Icon(Icons.edit, size: 15), color: Colors.blue.shade700, onPressed: () => _showProjetDialog(p), tooltip: 'Modifier', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
                                if (_canDelete) IconButton(icon: const Icon(Icons.delete, size: 15), color: Colors.red.shade700, onPressed: () => _deleteProjet(p), tooltip: 'Supprimer', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
                              ]),
                            )),
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

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final s = date.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  Widget _buildMobileCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(width: 4, height: 54, decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['code']?.toString() ?? '—', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(p['designation']?.toString() ?? '—', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                  if (_getBailleursString(p) != 'Aucun') ...[
                    const SizedBox(height: 2),
                    Text(_getBailleursString(p), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (_canUpdate) IconButton(icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade700), onPressed: () => _showProjetDialog(p), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              if (_canDelete) IconButton(icon: Icon(Icons.delete, size: 16, color: Colors.red.shade700), onPressed: () => _deleteProjet(p), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final total = _filteredProjets.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          if (isMobile) {
            return Column(children: [
              Text('Page $_currentPage / $totalPages  •  $total projet${total > 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _pagBtn(Icons.arrow_back, '', _currentPage > 1, () => setState(() => _currentPage--)),
                const SizedBox(width: 8),
                _pagBtn(Icons.arrow_forward, '', _currentPage < totalPages, () => setState(() => _currentPage++)),
              ]),
            ]);
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Page $_currentPage sur $totalPages  •  $total projet${total > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              Row(children: [
                _pagBtn(Icons.arrow_back, 'Précédent', _currentPage > 1, () => setState(() => _currentPage--)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<int>(
                    isDense: true, value: _currentPage,
                    decoration: InputDecoration(labelText: 'Page', labelStyle: const TextStyle(fontSize: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: List.generate(totalPages, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 13)))),
                    onChanged: (v) { if (v != null) setState(() => _currentPage = v); },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    isDense: true, value: _itemsPerPage,
                    decoration: InputDecoration(labelText: 'Par page', labelStyle: const TextStyle(fontSize: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [5, 10, 15, 20, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) { if (v != null) setState(() { _itemsPerPage = v; _currentPage = 1; }); },
                  ),
                ),
                const SizedBox(width: 10),
                _pagBtn(Icons.arrow_forward, 'Suivant', _currentPage < totalPages, () => setState(() => _currentPage++)),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _pagBtn(IconData icon, String label, bool enabled, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: label.isNotEmpty ? Text(label) : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade500,
        padding: EdgeInsets.symmetric(horizontal: label.isNotEmpty ? 14 : 10, vertical: 10),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _ProjetDialog extends StatefulWidget {
  final Map<String, dynamic>? projet;
  final List<Map<String, dynamic>> bailleurs;
  final Function(Map<String, dynamic>) onSave;

  const _ProjetDialog({
    required this.projet,
    required this.bailleurs,
    required this.onSave,
  });

  @override
  State<_ProjetDialog> createState() => _ProjetDialogState();
}

class _ProjetDialogState extends State<_ProjetDialog> {
  late TextEditingController _codeController;
  late TextEditingController _designationController;
  late TextEditingController _dateDebutController;
  late TextEditingController _dateFinController;
  late TextEditingController _bailleurSearchController;
  List<Map<String, dynamic>> _availableBailleurs = [];
  List<Map<String, dynamic>> _selectedBailleurs = [];
  bool _isSaving = false;
  bool _loadingBailleurs = true;
  final _formKey = GlobalKey<FormState>();

  // Variables pour le date picker avec dropdowns
  late int _debutDay, _debutMonth, _debutYear;
  late int _finDay, _finMonth, _finYear;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.projet?['code'] ?? '');
    _designationController = TextEditingController(
      text: widget.projet?['designation'] ?? '',
    );
    _dateDebutController = TextEditingController(
      text: widget.projet?['date_debut'] ?? '',
    );
    _dateFinController = TextEditingController(
      text: widget.projet?['date_fin'] ?? '',
    );
    _bailleurSearchController = TextEditingController();

    // Initialiser les dropdowns de date
    final debutDate =
        _dateDebutController.text.isNotEmpty
            ? DateTime.parse(_dateDebutController.text)
            : DateTime.now();
    final finDate =
        _dateFinController.text.isNotEmpty
            ? DateTime.parse(_dateFinController.text)
            : DateTime.now().add(const Duration(days: 365));

    _debutDay = debutDate.day;
    _debutMonth = debutDate.month;
    _debutYear = debutDate.year;
    _finDay = finDate.day;
    _finMonth = finDate.month;
    _finYear = finDate.year;

    _initializeBailleurs();
  }

  Future<void> _initializeBailleurs() async {
    try {
      // Charger la liste des bailleurs disponibles
      final availableList =
          widget.bailleurs.isNotEmpty
              ? widget.bailleurs
              : (await AuthService.getBailleurs())
                  .map(
                    (b) => {
                      'id': b.id,
                      'sigle': b.sigle,
                      'designation': b.designation,
                    },
                  )
                  .toList();

      setState(() {
        _availableBailleurs = availableList;
        _loadingBailleurs = false;
      });

      // Si on édite un projet, charger ses bailleurs
      if (widget.projet != null) {
        await _loadProjectBailleurs();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des bailleurs: $e');
      setState(() => _loadingBailleurs = false);
    }
  }

  Future<void> _loadProjectBailleurs() async {
    try {
      if (widget.projet != null) {
        final bailleurs = await AuthService.getBailleursForProjet(
          widget.projet!['id'] as int,
        );
        setState(() {
          _selectedBailleurs = List<Map<String, dynamic>>.from(bailleurs);
        });
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    }
  }

  Future<void> _reloadBailleurs() async {
    try {
      setState(() => _loadingBailleurs = true);
      final bailleurs = await AuthService.getBailleurs();
      setState(() {
        _availableBailleurs =
            bailleurs
                .map(
                  (b) => {
                    'id': b.id,
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
        _loadingBailleurs = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du rechargement des bailleurs: $e');
      setState(() => _loadingBailleurs = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _designationController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _bailleurSearchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final isDebut = controller == _dateDebutController;
    int day = isDebut ? _debutDay : _finDay;
    int month = isDebut ? _debutMonth : _finMonth;
    int year = isDebut ? _debutYear : _finYear;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    isDebut
                        ? 'Sélectionner la date de début'
                        : 'Sélectionner la date de fin',
                  ),
                  content: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Jour
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Jour',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: day,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(31, (i) => i + 1)
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d.toString().padLeft(2, '0'),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => day = value ?? day);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Mois
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Mois',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: month,
                                    underline: const SizedBox(),
                                    items:
                                        [
                                              'Jan',
                                              'Fév',
                                              'Mar',
                                              'Avr',
                                              'Mai',
                                              'Jun',
                                              'Jul',
                                              'Aoû',
                                              'Sep',
                                              'Oct',
                                              'Nov',
                                              'Déc',
                                            ]
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e.key + 1,
                                                child: Text(
                                                  e.value,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => month = value ?? month);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Année
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Année',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: year,
                                    underline: const SizedBox(),
                                    items:
                                        List.generate(101, (i) => 2000 + i)
                                            .map(
                                              (y) => DropdownMenuItem(
                                                value: y,
                                                child: Text(
                                                  y.toString(),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => year = value ?? year);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.pop(context, {
                            'day': day,
                            'month': month,
                            'year': year,
                          }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
          ),
    );

    if (result != null) {
      setState(() {
        if (isDebut) {
          _debutDay = result['day']!;
          _debutMonth = result['month']!;
          _debutYear = result['year']!;
        } else {
          _finDay = result['day']!;
          _finMonth = result['month']!;
          _finYear = result['year']!;
        }

        final formattedDay = result['day'].toString().padLeft(2, '0');
        final formattedMonth = result['month'].toString().padLeft(2, '0');
        final formattedDate = '${result['year']}-$formattedMonth-$formattedDay';
        controller.text = formattedDate;
      });
    }
  }

  Widget _buildBailleurSection() {
    if (_loadingBailleurs) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_availableBailleurs.isEmpty) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Text('Aucun bailleur disponible')),
      );
    }

    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _availableBailleurs.where((bailleur) {
            return !_selectedBailleurs.any(
              (selected) => selected['id'] == bailleur['id'],
            );
          });
        }
        return _availableBailleurs.where((bailleur) {
          if (_selectedBailleurs.any(
            (selected) => selected['id'] == bailleur['id'],
          )) {
            return false;
          }
          final code = (bailleur['code'] ?? '').toString().toLowerCase();
          final sigle = (bailleur['sigle'] ?? '').toString().toLowerCase();
          final designation =
              (bailleur['designation'] ?? '').toString().toLowerCase();
          final searchText = textEditingValue.text.toLowerCase();
          return code.contains(searchText) ||
              sigle.contains(searchText) ||
              designation.contains(searchText);
        }).toList();
      },
      displayStringForOption:
          (Map<String, dynamic> option) =>
              '${option['code']} - ${option['sigle']}',
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        _bailleurSearchController = textEditingController;
        return TextFormField(
          controller: _bailleurSearchController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Sélectionner un bailleur',
            helperText:
                'Sélectionnez un bailleur puis recommencez pour en ajouter un autre',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator:
              (value) =>
                  _selectedBailleurs.isEmpty && (value?.isEmpty ?? true)
                      ? 'Au moins un bailleur est requis'
                      : null,
        );
      },
      onSelected: (Map<String, dynamic> selection) {
        if (!_selectedBailleurs.any((b) => b['id'] == selection['id'])) {
          setState(() {
            _selectedBailleurs.add(selection);
            _bailleurSearchController.clear();
          });
        }
      },
    );
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBailleurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un bailleur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService.createProjet(
        code: _codeController.text,
        designation: _designationController.text,
        bailleurIds: _selectedBailleurs.map((b) => b['id'] as int).toList(),
        dateDebut:
            _dateDebutController.text.isNotEmpty
                ? DateTime.parse(_dateDebutController.text)
                : null,
        dateFin:
            _dateFinController.text.isNotEmpty
                ? DateTime.parse(_dateFinController.text)
                : null,
      );

      if (!mounted) return;

      // Réinitialiser les champs
      _codeController.clear();
      _designationController.clear();
      _dateDebutController.clear();
      _dateFinController.clear();
      setState(() {
        _selectedBailleurs.clear();
        _debutDay = 1;
        _debutMonth = 1;
        _debutYear = DateTime.now().year;
        _finDay = 31;
        _finMonth = 12;
        _finYear = DateTime.now().year;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projet créé avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Focus sur le premier champ
      FocusScope.of(context).requestFocus(FocusNode());
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBailleurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un bailleur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.projet == null) {
        await AuthService.createProjet(
          code: _codeController.text,
          designation: _designationController.text,
          bailleurIds: _selectedBailleurs.map((b) => b['id'] as int).toList(),
          dateDebut:
              _dateDebutController.text.isNotEmpty
                  ? DateTime.parse(_dateDebutController.text)
                  : null,
          dateFin:
              _dateFinController.text.isNotEmpty
                  ? DateTime.parse(_dateFinController.text)
                  : null,
        );
      } else {
        await AuthService.updateProjet(
          id: widget.projet!['id'] as int,
          code: _codeController.text,
          designation: _designationController.text,
          bailleurIds: _selectedBailleurs.map((b) => b['id'] as int).toList(),
          dateDebut:
              _dateDebutController.text.isNotEmpty
                  ? DateTime.parse(_dateDebutController.text)
                  : null,
          dateFin:
              _dateFinController.text.isNotEmpty
                  ? DateTime.parse(_dateFinController.text)
                  : null,
        );
      }
      if (!mounted) return;
      widget.onSave({});
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

  void _showCreateBailleurDialog() {
    final sigController = TextEditingController();
    final designationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Créer un nouveau bailleur'),
                content: SizedBox(
                  width: 400,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: sigController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Sigle *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true
                                      ? 'Le sigle est requis'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: designationController,
                          decoration: InputDecoration(
                            labelText: 'Désignation *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true
                                      ? 'La désignation est requise'
                                      : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isCreating ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isCreating
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;

                              setState(() => isCreating = true);
                              try {
                                await AuthService.createBailleur(
                                  code: sigController.text,
                                  nom: designationController.text,
                                );

                                // Recharger la liste des bailleurs
                                await _reloadBailleurs();

                                if (!context.mounted) return;
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bailleur créé avec succès'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setState(() => isCreating = false);
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        isCreating
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Créer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.projet == null ? 'Nouveau projet' : 'Modifier le projet',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _codeController,
                  autofocus: widget.projet == null,
                  decoration: InputDecoration(
                    labelText: 'Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true ? 'Le code est requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _designationController,
                  decoration: InputDecoration(
                    labelText: 'Désignation *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'La désignation est requise'
                              : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateDebutController,
                        decoration: InputDecoration(
                          labelText: 'Date début *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(_dateDebutController),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true
                                    ? 'La date début est requise'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dateFinController,
                        decoration: InputDecoration(
                          labelText: 'Date fin *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(_dateFinController),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true
                                    ? 'La date fin est requise'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bailleurs *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildBailleurSection()),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Créer un nouveau bailleur',
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _showCreateBailleurDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Nouveau'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Afficher les bailleurs sélectionnés comme chips
                if (_selectedBailleurs.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _selectedBailleurs.map((bailleur) {
                          return Chip(
                            label: Text(
                              '${bailleur['sigle']} - ${bailleur['designation']}',
                            ),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () {
                              setState(() {
                                final newList = List<Map<String, dynamic>>.from(
                                  _selectedBailleurs,
                                );
                                newList.removeWhere(
                                  (b) => b['id'] == bailleur['id'],
                                );
                                _selectedBailleurs = newList;
                              });
                            },
                            backgroundColor: Colors.indigo.withValues(
                              alpha: 0.2,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.indigo.shade700,
                            ),
                          );
                        }).toList(),
                  ),
              ],
            ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade400,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Enregistrer'),
        ),
        if (widget.projet == null)
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAndContinue,
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.add_circle, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            label: const Text('Ajouter et continuer'),
          ),
      ],
    );
  }
}
