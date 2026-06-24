import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';

class ListeBailleursPage extends StatefulWidget {
  final bool showAppBar;
  final UserSession? userSession;

  const ListeBailleursPage({
    super.key,
    this.showAppBar = true,
    this.userSession,
  });

  @override
  State<ListeBailleursPage> createState() => _ListeBailleursPageState();
}

class _ListeBailleursPageState extends State<ListeBailleursPage> {
  List<Map<String, dynamic>> _bailleurs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'sigle'; // 'sigle' ou 'designation'
  String _filterStatus = 'actifs'; // 'actifs', 'inactifs', 'tous'
  late FocusNode _focusNode;

  int _itemsPerPage = 15;
  int _currentPage = 1;

  // Permissions
  bool get _canCreate => _hasPermission('creation');

  bool _hasPermission(String type) {
    if (userSession == null) return true;
    final permission = userSession!.permissions.firstWhere(
      (p) => p['menu'] == 'parametrages' && p['sous_menu'] == 'liste_bailleurs',
      orElse: () => <String, dynamic>{},
    );
    if (permission.isEmpty) return true;
    return permission[type] == true;
  }

  UserSession? get userSession => widget.userSession;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _loadBailleurs();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBailleurs() async {
    setState(() => _isLoading = true);
    try {
      final bailleurs = await AuthService.getBailleurs();
      setState(() {
        // Filtrer les bailleurs actifs (deleted_at == null)
        _bailleurs =
            bailleurs
                .where((b) => b.isActive)
                .map(
                  (b) => {
                    'id': (b.id ?? 0).toString(),
                    'sigle': b.sigle,
                    'designation': b.designation,
                  },
                )
                .toList();
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

  List<Map<String, dynamic>> get _filteredBailleurs {
    var filtered = List<Map<String, dynamic>>.from(_bailleurs);

    // Filtrer par texte de recherche
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((bailleur) {
            final query = _searchQuery.toLowerCase();
            return (bailleur['sigle'] ?? '').toString().toLowerCase().contains(
                  query,
                ) ||
                (bailleur['designation'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query);
          }).toList();
    }

    // Filtrer par statut (actif/inactif)
    if (_filterStatus == 'actifs') {
      filtered = filtered.where((b) => b['deleted_at'] == null).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((b) => b['deleted_at'] != null).toList();
    }

    // Trier
    if (_sortBy == 'sigle') {
      filtered.sort(
        (a, b) => (a['sigle'] ?? '').toString().compareTo(
          (b['sigle'] ?? '').toString(),
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

  List<Map<String, dynamic>> get _paginatedBailleurs {
    final filtered = _filteredBailleurs;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int get _totalPages => math.max(1, (_filteredBailleurs.length / _itemsPerPage).ceil());

  void _resetPagination() => setState(() => _currentPage = 1);

  bool _isActive(Map<String, dynamic> bailleur) {
    return bailleur['deleted_at'] == null;
  }

  Future<void> _deleteBailleur(String id, String sigle) async {
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
              const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer le bailleur '),
              TextSpan(text: '"$sigle"', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.deleteBailleur(int.parse(id));
        if (!mounted) return;
        _loadBailleurs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bailleur supprimé'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showBailleurDialog(null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Bailleurs'),
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
                            children: [_buildPageTitle(), const SizedBox(height: 12), _buildHeaderActions()],
                          );
                        }
                        return Row(children: [_buildPageTitle(), const Spacer(), _buildHeaderActions()]);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterBar(),
                    const SizedBox(height: 12),
                    Text(
                      '${_filteredBailleurs.length} bailleur${_filteredBailleurs.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    // Contenu
                    Expanded(
                      child: _filteredBailleurs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.business_center_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty ? 'Aucun bailleur. Cliquez sur "Nouveau bailleur"' : 'Aucun bailleur trouvé',
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
          decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.business, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Text('Bailleurs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Wrap(
      spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () => ExportService.exportBailleursListPDF(bailleurs: _filteredBailleurs, context: context),
          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
          label: const Text('PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => ExportService.exportBailleursListExcel(bailleurs: _filteredBailleurs, context: context),
          icon: const Icon(Icons.table_chart, size: 16, color: Colors.white),
          label: const Text('Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        if (_canCreate)
          ElevatedButton.icon(
            onPressed: () => _showBailleurDialog(null),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text('Nouveau bailleur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              elevation: 3, shadowColor: Colors.blue.shade200,
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final hasActiveFilter = _searchQuery.isNotEmpty || _sortBy != 'sigle' || _filterStatus != 'actifs';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasActiveFilter ? Colors.blue.shade200 : Colors.grey.shade200, width: hasActiveFilter ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          final searchField = TextField(
            onChanged: (v) { setState(() => _searchQuery = v); _resetPagination(); },
            decoration: InputDecoration(
              isDense: true, hintText: 'Rechercher un bailleur…',
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
              filled: true, fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
          final sortField = DropdownButtonFormField<String>(
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
              DropdownMenuItem(value: 'sigle', child: Text('Sigle', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'designation', child: Text('Désignation', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) { setState(() => _sortBy = v ?? 'sigle'); _resetPagination(); },
          );
          final statusField = DropdownButtonFormField<String>(
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
            onChanged: (v) { setState(() => _filterStatus = v ?? 'actifs'); _resetPagination(); },
          );
          final resetBtn = Tooltip(
            message: 'Réinitialiser',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () { setState(() { _searchQuery = ''; _sortBy = 'sigle'; _filterStatus = 'actifs'; }); _resetPagination(); },
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
          if (isMobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              searchField, const SizedBox(height: 10),
              Row(children: [Expanded(child: sortField), const SizedBox(width: 8), Expanded(child: statusField), const SizedBox(width: 4), resetBtn]),
            ]);
          }
          return Row(children: [
            Expanded(flex: 3, child: searchField), const SizedBox(width: 12),
            Expanded(flex: 2, child: sortField), const SizedBox(width: 10),
            Expanded(flex: 2, child: statusField), const SizedBox(width: 8),
            resetBtn,
          ]);
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return ListView.builder(
            itemCount: _paginatedBailleurs.length,
            itemBuilder: (context, index) => _buildMobileCard(_paginatedBailleurs[index]),
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
                  final sigleW = cw(tw * 0.20, 100, 0.26);
                  final desigW = cw(tw * 0.55, 200, 0.65);
                  final actW   = cw(tw * 0.10, 70,  0.14);
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
                      columns: const [
                        DataColumn(label: Text('Sigle')),
                        DataColumn(label: Text('Désignation')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _paginatedBailleurs.map((b) {
                        final active = _isActive(b);
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) return Colors.blue.shade50;
                            return Colors.white;
                          }),
                          cells: [
                            DataCell(SizedBox(
                              width: sigleW,
                              child: Text(b['sigle']?.toString() ?? '—', overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 11, color: active ? Colors.black87 : Colors.grey.shade400)),
                            )),
                            DataCell(SizedBox(
                              width: desigW,
                              child: Text(b['designation']?.toString() ?? '—', overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: active ? Colors.grey.shade800 : Colors.grey.shade400)),
                            )),
                            DataCell(SizedBox(
                              width: actW,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit, size: 15), color: Colors.blue.shade700, onPressed: () => _showBailleurDialog(b), tooltip: 'Modifier', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
                                IconButton(icon: const Icon(Icons.delete, size: 15), color: Colors.red.shade700, onPressed: () => _deleteBailleur(b['id'].toString(), b['sigle'] ?? ''), tooltip: 'Supprimer', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
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

  Widget _buildMobileCard(Map<String, dynamic> b) {
    final active = _isActive(b);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(width: 4, height: 44, decoration: BoxDecoration(color: active ? Colors.blue.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['sigle']?.toString() ?? '—', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: active ? Colors.black87 : Colors.grey.shade400)),
                const SizedBox(height: 3),
                Text(b['designation']?.toString() ?? '—', style: TextStyle(fontSize: 12, color: active ? Colors.grey.shade800 : Colors.grey.shade400)),
              ]),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade700), onPressed: () => _showBailleurDialog(b), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              IconButton(icon: Icon(Icons.delete, size: 16, color: Colors.red.shade700), onPressed: () => _deleteBailleur(b['id'].toString(), b['sigle'] ?? ''), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final total = _filteredBailleurs.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          if (isMobile) {
            return Column(children: [
              Text('Page $_currentPage / $totalPages  •  $total bailleur${total > 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
              Text('Page $_currentPage sur $totalPages  •  $total bailleur${total > 1 ? 's' : ''}',
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

  void _showBailleurDialog(Map<String, dynamic>? bailleur) {
    final isEdit = bailleur != null;
    final sigleController = TextEditingController(
      text: bailleur?['sigle'] ?? '',
    );
    final designationController = TextEditingController(
      text: bailleur?['designation'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    Future<void> submit() async {
      if (formKey.currentState!.validate()) {
        try {
          if (isEdit) {
            await AuthService.updateBailleur(
              id: int.parse(bailleur['id'].toString()),
              code: sigleController.text.trim(),
              nom: designationController.text.trim(),
            );
          } else {
            await AuthService.createBailleur(
              code: sigleController.text.trim(),
              nom: designationController.text.trim(),
            );
          }

          if (!mounted) return;
          _loadBailleurs();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Bailleur modifié avec succès'
                    : 'Bailleur créé avec succès',
              ),
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
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Focus(
              autofocus: true,
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
                      color: Colors.indigo.shade700,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Modifier le bailleur' : 'Nouveau bailleur',
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
                          // Sigle
                          TextFormField(
                            controller: sigleController,
                            decoration: InputDecoration(
                              labelText: 'Sigle *',
                              prefixIcon: const Icon(Icons.label),
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
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              // Focus sur le champ suivant
                              FocusScope.of(context).nextFocus();
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Le sigle est requis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Désignation
                          TextFormField(
                            controller: designationController,
                            maxLines: 1,
                            decoration: InputDecoration(
                              labelText: 'Désignation *',
                              prefixIcon: const Icon(Icons.description),
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
                                  color: Colors.indigo.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            textInputAction: TextInputAction.go,
                            onFieldSubmitted: (_) {
                              // Ici, la touche Entrée déclenche la soumission
                              submit();
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La désignation est requise';
                              }
                              return null;
                            },
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
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          if (isEdit) {
                            await AuthService.updateBailleur(
                              id: int.parse(bailleur['id'].toString()),
                              code: sigleController.text.trim(),
                              nom: designationController.text.trim(),
                            );
                          } else {
                            await AuthService.createBailleur(
                              code: sigleController.text.trim(),
                              nom: designationController.text.trim(),
                            );
                          }

                          if (!mounted) return;
                          _loadBailleurs();

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Bailleur modifié avec succès'
                                    : 'Bailleur créé avec succès',
                              ),
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEdit ? 'Modifier' : 'Créer'),
                  ),
                  if (!isEdit)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            await AuthService.createBailleur(
                              code: sigleController.text.trim(),
                              nom: designationController.text.trim(),
                            );

                            if (!mounted) return;
                            _loadBailleurs();

                            // Réinitialiser les champs
                            sigleController.clear();
                            designationController.clear();
                            setDialogState(() {});

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bailleur créé avec succès'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 1),
                              ),
                            );

                            // Focus sur le premier champ pour continuer la saisie
                            FocusScope.of(context).requestFocus(FocusNode());
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
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Ajouter et continuer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
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
}
