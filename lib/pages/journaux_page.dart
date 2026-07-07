import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart' as db_service;
import '../models/journal.dart';
import '../models/compte.dart';
import '../models/user_session.dart';
import '../utils/form_enter_shortcut.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

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
  final FocusNode _focusNode = FocusNode();
  List<Journal> journaux = [];
  List<Compte> comptes = [];
  bool isLoading = true;
  String searchQuery = '';
  String? _selectedType;
  String _filterStatus = 'actifs';

  // Pagination
  int _itemsPerPage = 15;
  int _currentPage = 1;

  // Permissions
  bool get _canCreate => widget.userSession.isAdmin
      ? true
      : widget.userSession.canCreate('codes_journaux');
  bool get _canModify => widget.userSession.isAdmin
      ? true
      : widget.userSession.canModify('codes_journaux');
  bool get _canDelete => widget.userSession.isAdmin
      ? true
      : widget.userSession.canDelete('codes_journaux');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final result = await AuthService.getJournaux();
      final comptesList = await db_service.DatabaseService.getAllComptes();
      if (!mounted) return;
      setState(() {
        journaux = result;
        comptes = comptesList;
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

  List<Journal> get _filteredJournaux {
    var filtered = journaux;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered =
          filtered
              .where(
                (j) =>
                    j.code.toLowerCase().contains(query) ||
                    j.intitule.toLowerCase().contains(query),
              )
              .toList();
    }

    if (_selectedType != null) {
      final typeFilter =
          _selectedType == 'financier'
              ? TypeJournal.financier
              : TypeJournal.nonFinancier;
      filtered = filtered.where((j) => j.type == typeFilter).toList();
    }

    if (_filterStatus == 'actifs') {
      filtered = filtered.where((j) => j.isActive).toList();
    } else if (_filterStatus == 'inactifs') {
      filtered = filtered.where((j) => !j.isActive).toList();
    }

    return filtered;
  }

  List<Journal> get _paginatedJournaux {
    final filtered = _filteredJournaux;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex > filtered.length ? filtered.length : endIndex);
  }

  int get _totalPages => (_filteredJournaux.length / _itemsPerPage).ceil();

  void _resetPagination() => setState(() => _currentPage = 1);

  Future<void> _deleteJournal(String id, String intitule) async {
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
              const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer le journal '),
              TextSpan(
                text: "'$intitule'",
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
        await AuthService.deleteJournal(int.parse(id));
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal supprimé'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        final errorMessage = e.toString();
        final displayMessage = errorMessage.contains('ne peut pas être supprimé')
            ? 'Ce journal contient des écritures et ne peut pas être supprimé'
            : 'Erreur: $errorMessage';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(displayMessage)));
      }
    }
  }

  Color _getTypeColor(TypeJournal type) {
    switch (type) {
      case TypeJournal.financier:
        return const Color(0xFF00695C); // Teal
      case TypeJournal.nonFinancier:
        return const Color(0xFFE65100); // Orange
    }
  }

  void _showJournalDialog(Journal? journal) {
    showDialog(
      context: context,
      builder:
          (context) => JournalDialog(
            journal: journal,
            comptes: comptes,
            onSave: (updatedJournal) {
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
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed &&
            _canCreate) {
          _showJournalDialog(null);
        } else if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (searchQuery.isNotEmpty || _selectedType != null || _filterStatus != 'actifs') {
            setState(() {
              searchQuery = '';
              _selectedType = null;
              _filterStatus = 'actifs';
            });
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Codes Journaux'),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
              )
            : null,
        body: isLoading
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

                    // Filtres
                    _buildFilterBar(),
                    const SizedBox(height: 16),

                    // Légende
                    _buildTypeLegend(),
                    const SizedBox(height: 16),

                    // Contenu
                    Expanded(
                      child: _filteredJournaux.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.book_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    searchQuery.isEmpty
                                        ? 'Aucun journal. Appuyez sur "Nouveau journal" ou Ctrl+N'
                                        : 'Aucun journal trouvé',
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
          child: const Icon(Icons.book, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Text(
          'Codes Journaux',
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
          onPressed: () => ImportService.importJournaux(context: context, onSuccess: _loadData),
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
            final data = _filteredJournaux.map((j) => {
              'code': j.code,
              'intitule': j.intitule,
              'type': j.type.toLabel(),
              'compteTresorerie': j.compteTresorerie ?? '',
              'saisieAnalytique': j.saisieAnalytique,
            }).toList();
            ExportService.exportJournauxPDF(journaux: data, context: context);
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
            final data = _filteredJournaux.map((j) => {
              'code': j.code,
              'intitule': j.intitule,
              'type': j.type.toLabel(),
              'compteTresorerie': j.compteTresorerie ?? '',
              'saisieAnalytique': j.saisieAnalytique,
            }).toList();
            ExportService.exportJournauxExcel(journaux: data, context: context);
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
          onPressed: () => _showJournalDialog(null),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text('Nouveau journal'),
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
        searchQuery.isNotEmpty || _selectedType != null || _filterStatus != 'actifs';

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
                    Expanded(child: _buildTypeDropdown()),
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
              Expanded(flex: 2, child: _buildTypeDropdown()),
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
      onChanged: (value) {
        setState(() => searchQuery = value);
        _resetPagination();
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un journal…',
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

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      isDense: true,
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Type',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(
          Icons.circle,
          size: 10,
          color: _selectedType == 'financier'
              ? const Color(0xFF00695C)
              : _selectedType == 'non_financier'
                  ? const Color(0xFFE65100)
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
        const DropdownMenuItem(value: null, child: Text('— Tous —', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(
          value: 'financier',
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00695C))),
            const SizedBox(width: 6),
            const Text('Financier', style: TextStyle(fontSize: 12)),
          ]),
        ),
        DropdownMenuItem(
          value: 'non_financier',
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE65100))),
            const SizedBox(width: 6),
            const Text('Non Financier', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedType = value);
        _resetPagination();
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      isDense: true,
      value: _filterStatus,
      decoration: InputDecoration(
        labelText: 'Statut',
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(Icons.filter_alt, size: 18, color: Colors.grey.shade500),
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
        DropdownMenuItem(value: 'actifs', child: Text('Actifs', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'inactifs', child: Text('Inactifs', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'tous', child: Text('Tous', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (value) {
        setState(() => _filterStatus = value ?? 'actifs');
        _resetPagination();
      },
    );
  }

  Widget _buildResetButton(bool hasActiveFilter) {
    return Tooltip(
      message: 'Réinitialiser',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            searchQuery = '';
            _selectedType = null;
            _filterStatus = 'actifs';
          });
          _resetPagination();
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: hasActiveFilter ? Colors.blue.shade50 : Colors.transparent,
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
    );
  }

  Widget _buildTypeLegend() {
    return Row(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00695C))),
          const SizedBox(width: 4),
          Text('Financier', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(width: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE65100))),
          const SizedBox(width: 4),
          Text('Non Financier', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(width: 16),
        Text(
          '${_filteredJournaux.length} journal${_filteredJournaux.length > 1 ? 'aux' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
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
            itemCount: _paginatedJournaux.length,
            itemBuilder: (context, index) => _buildMobileCard(_paginatedJournaux[index]),
          );
        }

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
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  final double tw = innerConstraints.maxWidth.isFinite
                      ? innerConstraints.maxWidth
                      : (MediaQuery.of(context).size.width - 48);
                  final double cs = (tw * 0.015).clamp(6, 28).toDouble();

                  double cw(double v, double mn, double mxf) =>
                      v.clamp(mn, math.max(mn, tw * mxf));

                  final double codeWidth     = cw(tw * 0.14, 80,  0.18);
                  final double intituleWidth = cw(tw * 0.32, 140, 0.40);
                  final double typeWidth     = cw(tw * 0.16, 110, 0.22);
                  final double collectifW    = cw(tw * 0.14, 90,  0.18);
                  final double saisieWidth   = cw(tw * 0.10, 80,  0.14);
                  final double actionsWidth  = cw(tw * 0.08, 60,  0.12);

                  return SizedBox(
                    width: tw,
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
                      columnSpacing: cs * 0.5,
                      horizontalMargin: 12,
                      dividerThickness: 0.5,
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Intitulé')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Cpte Trésorerie')),
                        DataColumn(label: Text('Analytique')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _paginatedJournaux.map((j) {
                        final color = _getTypeColor(j.type);
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) return Colors.blue.shade50;
                            return Colors.white;
                          }),
                          cells: [
                            DataCell(SizedBox(
                              width: codeWidth,
                              child: Text(j.code,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 11),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: intituleWidth,
                              child: Text(j.intitule,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: typeWidth,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                const SizedBox(width: 5),
                                Flexible(child: Text(j.type.toLabel(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                )),
                              ]),
                            )),
                            DataCell(SizedBox(
                              width: collectifW,
                              child: Text(j.compteTresorerie ?? '—',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: j.compteTresorerie != null ? 'monospace' : null,
                                  color: j.compteTresorerie != null ? Colors.grey.shade800 : Colors.grey.shade400,
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: saisieWidth,
                              child: Center(
                                child: j.saisieAnalytique
                                    ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14)
                                    : Icon(Icons.cancel, color: Colors.grey.shade400, size: 14),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: actionsWidth,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (_canModify) IconButton(
                                  icon: const Icon(Icons.edit, size: 15),
                                  color: Colors.blue.shade700,
                                  onPressed: () => _showJournalDialog(j),
                                  tooltip: 'Modifier',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
                                if (_canDelete) IconButton(
                                  icon: const Icon(Icons.delete, size: 15),
                                  color: Colors.red.shade700,
                                  onPressed: () => _deleteJournal(j.id, j.intitule),
                                  tooltip: 'Supprimer',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
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

  Widget _buildMobileCard(Journal j) {
    final color = _getTypeColor(j.type);
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
              width: 4, height: 54,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(j.code,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Text(j.type.toLabel(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(j.intitule, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                  if (j.compteTresorerie != null) ...[
                    const SizedBox(height: 2),
                    Text('Trésorerie : ${j.compteTresorerie}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade700),
                onPressed: () => _showJournalDialog(j),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 16, color: Colors.red.shade700),
                onPressed: () => _deleteJournal(j.id, j.intitule),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final totalItems = _filteredJournaux.length;
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
            return Column(children: [
              Text('Page $_currentPage / $totalPages  •  $totalItems journal${totalItems > 1 ? 'aux' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
              Text(
                'Page $_currentPage sur $totalPages  •  $totalItems journal${totalItems > 1 ? 'aux' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              Row(children: [
                _pagBtn(Icons.arrow_back, 'Précédent', _currentPage > 1, () => setState(() => _currentPage--)),
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
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: List.generate(totalPages, (i) => DropdownMenuItem(
                      value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
                    )),
                    onChanged: (v) { if (v != null) setState(() => _currentPage = v); },
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
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [5, 10, 15, 20, 50].map((v) => DropdownMenuItem(
                      value: v, child: Text('$v', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() { _itemsPerPage = v; _currentPage = 1; });
                    },
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

// ============ DIALOGUE DE CRÉATION/MODIFICATION ============

class JournalDialog extends StatefulWidget {
  final Journal? journal;
  final List<Compte> comptes;
  final Function(Journal) onSave;

  const JournalDialog({
    super.key,
    this.journal,
    required this.comptes,
    required this.onSave,
  });

  @override
  State<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends State<JournalDialog> {
  late TextEditingController _codeController;
  late TextEditingController _intituleController;
  late TextEditingController _compteFresorerieController;
  TypeJournal? _selectedType;
  Compte? _selectedCompteFresorerie;
  bool _saisieAnalytique = false;
  bool _isSaving = false;
  String? _compteError;
  final _formKey = GlobalKey<FormState>();
  Timer? _debounceTimer;
  bool _compteFieldInitialized = false;

  Future<void> _showCompteCreationDialog() async {
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
          builder: (context, setDialogState) {
            // Fonction de soumission pour FormWithEnterShortcut
            Future<void> handleSubmit() async {
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

                try {
                  // Récupérer la longueur de compte depuis la config
                  final config =
                      await db_service.DatabaseService.getFileConfig();
                  final longueurCompteGeneral =
                      config?['longueur_compte_general'] as int? ?? 7;

                  // Padding du numéro de compte
                  String paddedNumero = numeroController.text.trim();
                  if (selectedType == TypeCompte.detail &&
                      paddedNumero.length < longueurCompteGeneral) {
                    paddedNumero = paddedNumero.padRight(
                      longueurCompteGeneral,
                      '0',
                    );
                  }

                  // Créer le compte
                  await db_service.DatabaseService.createCompte(
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

                  // Récupérer le nouveau compte créé
                  final allComptes =
                      await db_service.DatabaseService.getAllComptes();
                  final newCompte = allComptes.firstWhere(
                    (c) => c.numeroCompte == paddedNumero,
                    orElse:
                        () => allComptes.firstWhere(
                          (c) => c.numeroCompte.startsWith(
                            numeroController.text.trim(),
                          ),
                        ),
                  );

                  // Mettre à jour l'état local et le parent
                  if (!context.mounted) return;

                  setState(() {
                    widget.comptes.add(newCompte);
                    _selectedCompteFresorerie = newCompte;
                    _compteFresorerieController.text =
                        '${newCompte.numeroCompte} - ${newCompte.intitule}';
                    _compteError = null;
                  });

                  // Fermer le dialogue
                  Navigator.pop(context);

                  // Confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Compte $paddedNumero créé avec succès'),
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
                }
              }
            }

            return FormWithEnterShortcut(
              formKey: formKey,
              onSubmit: handleSubmit,
              child: Shortcuts(
                shortcuts: <ShortcutActivator, Intent>{
                  const SingleActivator(LogicalKeyboardKey.escape):
                      const DismissIntent(),
                  const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ):
                      const ActivateIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (intent) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        return null;
                      },
                    ),
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (intent) {
                        handleSubmit();
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.add_circle, color: Colors.indigo.shade700),
                          const SizedBox(width: 12),
                          const Text(
                            'Nouveau compte de trésorerie',
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
                                // Numéro de compte
                                TextFormField(
                                  controller: numeroController,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    labelText: 'N° Compte *',
                                    prefixIcon: const Icon(Icons.numbers),
                                    hintText: 'Ex: 52100, 57100, 53000...',
                                    helperText:
                                        'Doit commencer par 52, 57 ou 50-59',
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
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Champ requis';
                                    }
                                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                      return 'Seuls les chiffres sont autorisés';
                                    }
                                    // Vérifier que c'est un compte de trésorerie
                                    final isTresorerie = [
                                      '52',
                                      '57',
                                      '50',
                                      '51',
                                      '53',
                                      '55',
                                      '56',
                                      '58',
                                      '59',
                                    ].any((prefix) => value.startsWith(prefix));

                                    if (!isTresorerie) {
                                      return 'Le compte doit être de trésorerie (classe 5)';
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
                                const SizedBox(height: 10),

                                // Intitulé
                                TextFormField(
                                  controller: intituleController,
                                  decoration: InputDecoration(
                                    labelText: 'Intitulé *',
                                    prefixIcon: const Icon(Icons.title),
                                    hintText:
                                        'Ex: Caisse principale, Banque ABC...',
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
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Champ requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Type (fixé à "détail" pour les comptes de trésorerie)
                                DropdownButtonFormField<TypeCompte>(
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
                                        color: Colors.indigo.shade700,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  dropdownColor: Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down_circle,
                                    color: Colors.indigo.shade700,
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
                                const SizedBox(height: 10),

                                // Nature (auto-détectée)
                                DropdownButtonFormField<NatureCompte>(
                                  value: calculatedNature,
                                  decoration: InputDecoration(
                                    labelText: 'Nature *',
                                    prefixIcon: const Icon(Icons.layers),
                                    helperText:
                                        'Auto-détecté du numéro de compte',
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
                                  dropdownColor: Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down_circle,
                                    color: Colors.indigo.shade700,
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
                                const SizedBox(height: 10),

                                // Description
                                TextFormField(
                                  controller: descriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    prefixIcon: const Icon(Icons.notes),
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
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 10),

                                // Rattachement de tiers
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
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
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
                        ElevatedButton(
                          onPressed: handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Créer le compte'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final journal = widget.journal;
    _codeController = TextEditingController(text: journal?.code ?? '');
    _intituleController = TextEditingController(text: journal?.intitule ?? '');
    _compteFresorerieController = TextEditingController();
    _selectedType = journal?.type ?? TypeJournal.financier;
    _saisieAnalytique = journal?.saisieAnalytique ?? false;

    // Chercher le compte de trésorerie si édition
    if (journal?.compteTresorerie != null &&
        journal!.compteTresorerie!.isNotEmpty) {
      try {
        _selectedCompteFresorerie = widget.comptes.firstWhere(
          (c) => c.numeroCompte == journal.compteTresorerie,
        );
        _compteFresorerieController.text =
            '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
      } catch (_) {
        // Compte non trouvé dans la liste locale
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _intituleController.dispose();
    _compteFresorerieController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _searchCompteFresorerie(String input) {
    if (input.isEmpty) {
      setState(() {
        _selectedCompteFresorerie = null;
        _compteError = null;
      });
      return;
    }

    final comptesFresorerie = _getFilteredComptes();
    final matching =
        comptesFresorerie
            .where((c) => c.numeroCompte.startsWith(input))
            .toList();

    setState(() {
      if (matching.isEmpty) {
        _selectedCompteFresorerie = null;
        _compteError = 'Compte "$input" non trouvé dans le plan comptable';
      } else if (matching.length == 1) {
        _selectedCompteFresorerie = matching.first;
        _compteError = null;
      } else {
        _selectedCompteFresorerie = null;
        _compteError = 'Plusieurs comptes trouvés, soyez plus précis';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation supplémentaire
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

    // Si type financier, vérifier que compte de trésorerie est sélectionné
    if (_selectedType == TypeJournal.financier &&
        _selectedCompteFresorerie == null) {
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
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
          saisieAnalytique: _saisieAnalytique,
        );
      } else {
        // Modifier
        await AuthService.updateJournal(
          id: int.parse(widget.journal!.id),
          code: _codeController.text,
          libelle: _intituleController.text,
          type: _selectedType!.toDbString(),
          numeroCompteFresorerie: _selectedCompteFresorerie?.numeroCompte,
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
              compteTresorerie: _selectedCompteFresorerie?.numeroCompte,
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

    return FormWithEnterShortcut(
      formKey: _formKey,
      onSubmit: _save,
      enabled: !_isSaving,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.escape):
              const DismissIntent(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (intent) {
                if (!_isSaving && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                return null;
              },
            ),
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                if (!_isSaving) {
                  _save();
                }
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_circle,
                    color: Colors.indigo.shade700,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Modifier le journal' : 'Nouveau journal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedType == TypeJournal.financier &&
                            _selectedCompteFresorerie != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Compte sélectionné: ${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Code et Intitulé
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codeController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  labelText: 'Code *',
                                  prefixIcon: const Icon(Icons.code),
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
                                enabled: !_isSaving,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Champ requis';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _intituleController,
                                decoration: InputDecoration(
                                  labelText: 'Intitulé *',
                                  prefixIcon: const Icon(Icons.title),
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
                                enabled: !_isSaving,
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
                        const SizedBox(height: 10),
                        // Type de Journal
                        DropdownButtonFormField<TypeJournal>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type *',
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
                                color: Colors.indigo.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          dropdownColor: Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down_circle,
                            color: Colors.indigo.shade700,
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
                          validator: (value) {
                            if (value == null) {
                              return 'Sélectionnez un type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        // Compte de Trésorerie (seulement si financier)
                        if (_selectedType == TypeJournal.financier)
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Autocomplete<Compte>(
                                      displayStringForOption:
                                          (Compte option) =>
                                              '${option.numeroCompte} - ${option.intitule}',
                                      optionsBuilder: (
                                        TextEditingValue textEditingValue,
                                      ) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<Compte>.empty();
                                        }
                                        final comptesFresorerie =
                                            _getFilteredComptes();
                                        return comptesFresorerie.where(
                                          (c) => c.numeroCompte
                                              .toLowerCase()
                                              .startsWith(
                                                textEditingValue.text
                                                    .toLowerCase(),
                                              ),
                                        );
                                      },
                                      onSelected: (Compte selection) {
                                        setState(() {
                                          _selectedCompteFresorerie = selection;
                                          _compteFresorerieController.text =
                                              '${selection.numeroCompte} - ${selection.intitule}';
                                          _compteError = null;
                                        });
                                      },
                                      fieldViewBuilder: (
                                        BuildContext context,
                                        TextEditingController
                                        textEditingController,
                                        FocusNode focusNode,
                                        VoidCallback onFieldSubmitted,
                                      ) {
                                        // Initialiser le texte la première fois si on a un compte sélectionné
                                        if (!_compteFieldInitialized &&
                                            _selectedCompteFresorerie != null) {
                                          _compteFieldInitialized = true;
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                textEditingController.text =
                                                    '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                                              });
                                        }

                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          onChanged: (String value) {
                                            _searchCompteFresorerie(value);
                                          },
                                          decoration: InputDecoration(
                                            labelText: 'Compte de Trésorerie *',
                                            hintText:
                                                'Tapez le numéro de compte...',
                                            prefixIcon: const Icon(
                                              Icons.account_balance,
                                            ),
                                            errorText: _compteError,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color:
                                                    _compteError != null
                                                        ? Colors.red
                                                        : (_selectedCompteFresorerie !=
                                                                null
                                                            ? Colors.green
                                                            : Colors
                                                                .grey
                                                                .shade400),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.indigo.shade700,
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                          ),
                                          enabled: !_isSaving,
                                          validator: (value) {
                                            if (_selectedType ==
                                                    TypeJournal.financier &&
                                                _selectedCompteFresorerie ==
                                                    null) {
                                              return _compteError ??
                                                  'Sélectionnez un compte de trésorerie valide';
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                      optionsViewBuilder: (
                                        BuildContext context,
                                        AutocompleteOnSelected<Compte>
                                        onSelected,
                                        Iterable<Compte> options,
                                      ) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: SizedBox(
                                              width: 400,
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final Compte option = options
                                                      .elementAt(index);
                                                  return InkWell(
                                                    onTap: () {
                                                      onSelected(option);
                                                    },
                                                    child: Container(
                                                      color:
                                                          index.isEven
                                                              ? Colors
                                                                  .grey
                                                                  .shade50
                                                              : Colors.white,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            option.numeroCompte,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                          Text(
                                                            option.intitule,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade600,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isSaving
                                              ? null
                                              : _showCompteCreationDialog,
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                      ),
                                      label: const Text('Créer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade400,
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
                              const SizedBox(height: 10),
                            ],
                          ),
                        // Saisie Analytique
                        CheckboxListTile(
                          title: const Text('Saisie Analytique'),
                          value: _saisieAnalytique,
                          onChanged:
                              _isSaving
                                  ? null
                                  : (value) {
                                    setState(
                                      () => _saisieAnalytique = value ?? false,
                                    );
                                  },
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.indigo.shade700,
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Text(isEditing ? 'Modifier' : 'Créer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
  void _showCompteSelectionDialog([String? prefilledNumero]) {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              TextEditingController searchController = TextEditingController(
                text: prefilledNumero ?? '',
              );
              List<Compte> filteredComptes = _getFilteredComptes();

              return AlertDialog(
                title: const Text('Sélectionner un compte de trésorerie'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Ex: 41101AB ou 5210',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setDialogState(() {
                                          searchController.clear();
                                        });
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: _buildCompteSelectionList(
                            searchController.text,
                            filteredComptes,
                            setDialogState,
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
                ],
              );
            },
          ),
    );
  }
  */

  List<Compte> _getFilteredComptes() {
    return widget.comptes.where((c) {
      return [
        '52',
        '57',
        '50',
        '51',
        '53',
        '55',
        '56',
        '58',
        '59',
      ].any((prefix) => c.numeroCompte.startsWith(prefix));
    }).toList();
  }

  /*
  Widget _buildCompteSelectionList(
    String searchText,
    List<Compte> filteredComptes,
    Function(VoidCallback) setDialogState,
  ) {
    final numericSearch = _extractNumericPrefix(searchText);

    List<Compte> matchingComptes =
        filteredComptes.where((c) {
          if (numericSearch.isEmpty) return true;
          return c.numeroCompte.startsWith(numericSearch);
        }).toList();

    return Column(
      children: [
        Expanded(
          child:
              matchingComptes.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aucun compte trouvé',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        if (numericSearch.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _showCompteCreationDialog(numericSearch);
                              },
                              icon: const Icon(Icons.add),
                              label: Text('Créer compte $numericSearch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: matchingComptes.length,
                    itemBuilder: (context, index) {
                      final compte = matchingComptes[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.indigo,
                        ),
                        title: Text(compte.numeroCompte),
                        subtitle: Text(compte.intitule),
                        trailing: const Icon(Icons.check_circle_outline),
                        onTap: () {
                          setState(() {
                            _selectedCompteFresorerie = compte;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
  */

  /*
  String _extractNumericPrefix(String input) {
    final regex = RegExp(r'^(\d+)');
    final match = regex.firstMatch(input);
    return match?.group(1) ?? '';
  }

  Future<void> _showCompteCreationDialog(String numeroCompte) async {
    final intituleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Nouveau compte de trésorerie',
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
                        TextFormField(
                          initialValue: numeroCompte,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'N° Compte',
                            prefixIcon: const Icon(Icons.numbers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: intituleController,
                          decoration: InputDecoration(
                            labelText: 'Intitulé *',
                            prefixIcon: const Icon(Icons.label),
                            hintText: 'Ex: Banque principale',
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'L\'intitulé est requis';
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
                        final nature = _calculateNatureFromNumero(numeroCompte);
                        await db_service.DatabaseService.createCompte(
                          numeroCompte: numeroCompte,
                          intitule: intituleController.text,
                          type: TypeCompte.detail.toDbString(),
                          nature: nature.toDbString(),
                          liaisonTiers: false,
                          description: '',
                        );

                        final allComptes =
                            await db_service.DatabaseService.getAllComptes();
                        final compte = allComptes.firstWhere(
                          (c) => c.numeroCompte == numeroCompte,
                        );

                        if (!mounted) return;

                        setState(() {
                          _selectedCompteFresorerie = compte;
                          widget.comptes.add(compte);
                        });

                        if (!mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Compte $numeroCompte créé avec succès',
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
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  */

  /*
  void _showCompteCreationDialogForTresorerie() {
    TextEditingController numeroController = TextEditingController();
    TextEditingController intituleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Créer un nouveau compte'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro du compte',
                    hintText: 'Ex: 52100',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: intituleController,
                  decoration: const InputDecoration(
                    labelText: 'Intitulé du compte',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String numero = numeroController.text.trim();
                final String intitule = intituleController.text.trim();

                if (numero.isEmpty || intitule.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez remplir tous les champs'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Récupérer la longueur de compte depuis la config
                  final config = await db_service.DatabaseService.getConfig();
                  final longueurCompte =
                      config?['longueur_compte_general'] as int? ?? 8;

                  // Compléter le numéro avec des zéros à la fin
                  final numeroPadded = numero.padRight(longueurCompte, '0');

                  final nature = calculateNatureFromNumeroCompte(numeroPadded);
                  if (nature == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Impossible de déterminer la nature du compte',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  await AuthService.createCompte(
                    numeroCompte: numeroPadded,
                    intitule: intitule,
                    type: TypeCompte.detail.toDbString(),
                    nature: nature.toDbString(),
                  );

                  // Récupérer les comptes mis à jour
                  final updatedComptes = await AuthService.getComptes();

                  setState(() {
                    widget.comptes.clear();
                    widget.comptes.addAll(updatedComptes);
                    _selectedCompteFresorerie = updatedComptes.firstWhere(
                      (c) => c.numeroCompte == numeroPadded,
                      orElse: () => updatedComptes.first,
                    );
                    _compteFresorerieController.text =
                        '${_selectedCompteFresorerie!.numeroCompte} - ${_selectedCompteFresorerie!.intitule}';
                  });

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Compte $numeroPadded créé avec succès'),
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }
  */
}
