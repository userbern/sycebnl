import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/global_search_result.dart';
import '../models/saisie_comptable.dart';
import '../services/global_search_service.dart';

/// Barre de recherche globale de la Top Bar : interroge en parallèle les
/// comptes, tiers, journaux, projets, bailleurs, écritures et la liste des
/// fonctionnalités de l'application, et affiche les résultats regroupés
/// par catégorie dans un panneau déroulant.
///
/// Widget indépendant et réutilisable : n'altère aucune recherche locale
/// existante sur les autres pages.
class GlobalSearchBar extends StatefulWidget {
  final FocusNode focusNode;
  final int? exerciceId;
  final void Function(int pageIndex) onNavigateToPage;
  final Future<void> Function(JournalPeriode periode) onOpenEcriture;

  const GlobalSearchBar({
    super.key,
    required this.focusNode,
    required this.onNavigateToPage,
    required this.onOpenEcriture,
    this.exerciceId,
  });

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();

  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  Map<GlobalSearchCategory, List<GlobalSearchResult>> _results = {};
  List<GlobalSearchResult> _flatResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.focusNode.removeListener(_onFocusChange);
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus && _flatResults.isNotEmpty) {
      _syncOverlay();
    }
  }

  void _onChanged(String value) {
    setState(() {}); // reflète immédiatement le bouton "effacer"
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = {};
        _flatResults = [];
        _hasSearched = false;
      });
      _syncOverlay();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(trimmed),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isLoading = true);
    _syncOverlay();
    try {
      final results = await GlobalSearchService.search(
        query,
        exerciceId: widget.exerciceId,
      );
      if (!mounted) return;
      final flat = <GlobalSearchResult>[];
      for (final category in GlobalSearchService.categoryOrder) {
        flat.addAll(results[category] ?? const []);
      }
      setState(() {
        _results = results;
        _flatResults = flat;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _results = {};
        _flatResults = [];
      });
    }
    _syncOverlay();
  }

  void _syncOverlay() {
    final shouldShow =
        widget.focusNode.hasFocus && _controller.text.trim().isNotEmpty;
    if (!shouldShow) {
      _removeOverlay();
      return;
    }
    if (_overlayEntry == null) {
      final overlay = Overlay.of(context);
      _overlayEntry = OverlayEntry(builder: (context) => _buildOverlay());
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = {};
      _flatResults = [];
      _hasSearched = false;
      _isLoading = false;
    });
    _removeOverlay();
  }

  void _selectResult(GlobalSearchResult result) {
    widget.focusNode.unfocus();
    _removeOverlay();
    _controller.clear();
    setState(() {
      _results = {};
      _flatResults = [];
      _hasSearched = false;
    });
    if (result.journalPeriode != null) {
      widget.onOpenEcriture(result.journalPeriode!);
    } else if (result.pageIndex != null) {
      widget.onNavigateToPage(result.pageIndex!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) {
        if (widget.focusNode.hasFocus) widget.focusNode.unfocus();
        _removeOverlay();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: SizedBox(
          height: 38,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                widget.focusNode.unfocus();
                _removeOverlay();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              onChanged: _onChanged,
              onTap: () => _syncOverlay(),
              onSubmitted: (_) {
                if (_flatResults.isNotEmpty) {
                  _selectResult(_flatResults.first);
                }
              },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: 'Rechercher dans SYCEBNL...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.blue.shade400,
                ),
                suffixIcon:
                    _isLoading
                        ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : (_controller.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              splashRadius: 16,
                              tooltip: 'Effacer',
                              onPressed: _clearSearch,
                            )
                            : null),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.blue.shade200,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned(
      width: 440,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 44),
        child: TapRegion(
          groupId: _tapRegionGroupId,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildOverlayContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent() {
    if (_isLoading && _flatResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasSearched && _flatResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.search_off, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (final category in GlobalSearchService.categoryOrder) {
      final items = _results[category];
      if (items == null || items.isEmpty) continue;
      children.add(_buildCategoryHeader(category));
      children.addAll(items.map(_buildResultTile));
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: children,
    );
  }

  Widget _buildCategoryHeader(GlobalSearchCategory category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        category.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildResultTile(GlobalSearchResult result) {
    return InkWell(
      onTap: () => _selectResult(result),
      hoverColor: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(result.category.icon, size: 17, color: result.category.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.subtitle != null)
                    Text(
                      result.subtitle!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
