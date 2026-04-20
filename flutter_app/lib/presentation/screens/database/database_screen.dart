import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/entity_summary_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/dnd5e/card_panel_scope.dart';
import '../../widgets/dnd5e/typed_card_dispatcher.dart';
import '../../widgets/resizable_split.dart';
import 'entity_card.dart';

/// Database tab — Dual-panel tabbed card workspace.
/// Python ui/tabs/database_tab.py birebir karşılığı:
/// Sol panel (EntityTabWidget) + Sağ panel (EntityTabWidget), splitter ile.
class DatabaseScreen extends ConsumerStatefulWidget {
  final bool editMode;
  final String? selectedEntityId;
  final ValueChanged<String>? onEntitySelected;

  const DatabaseScreen({
    this.editMode = false,
    this.selectedEntityId,
    this.onEntitySelected,
    super.key,
  });

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> {
  final List<_TabEntry> _leftTabs = [];
  final List<_TabEntry> _rightTabs = [];
  int _leftActiveIndex = -1;
  int _rightActiveIndex = -1;

  // Stable callback references so `CardPanelScope.updateShouldNotify` does
  // not fire on every parent rebuild — creating new lambdas inline each
  // build invalidates the whole scope and forces descendant typed cards to
  // re-decode their JSON bodies.
  // ignore: prefer_function_declarations_over_variables
  late final void Function(String) _openInLeft =
      (eid) => _openTab(eid, panel: _Panel.left);
  // ignore: prefer_function_declarations_over_variables
  late final void Function(String) _openInRight =
      (eid) => _openTab(eid, panel: _Panel.right);

  @override
  void didUpdateWidget(DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEntityId != null &&
        widget.selectedEntityId != oldWidget.selectedEntityId) {
      // Build sırasında provider değiştirilemez — frame sonrasına ertele
      final eid = widget.selectedEntityId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTab(eid, panel: _Panel.left);
      });
    }
  }

  void _openTab(String entityId, {_Panel panel = _Panel.left}) {
    final tabs = panel == _Panel.left ? _leftTabs : _rightTabs;

    // Aynı tab zaten açıksa aktif yap
    final existing = tabs.indexWhere((t) => t.entityId == entityId);
    if (existing >= 0) {
      setState(() {
        if (panel == _Panel.left) {
          _leftActiveIndex = existing;
        } else {
          _rightActiveIndex = existing;
        }
      });
      _persistOpenTabs();
      return;
    }

    // Diğer panelde de var mı kontrol et (varsa oraya focus)
    final otherTabs = panel == _Panel.left ? _rightTabs : _leftTabs;
    final otherExisting = otherTabs.indexWhere((t) => t.entityId == entityId);
    if (otherExisting >= 0) {
      setState(() {
        if (panel == _Panel.left) {
          _rightActiveIndex = otherExisting;
        } else {
          _leftActiveIndex = otherExisting;
        }
      });
      _persistOpenTabs();
      return;
    }

    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    final schema = ref.read(worldSchemaProvider);
    final typedSummary = ref.read(entitySummaryByIdProvider)[entityId];

    final resolvedName = entity?.name ?? typedSummary?.name ?? 'Unknown';
    final resolvedCategorySlug =
        entity?.categorySlug ?? typedSummary?.categorySlug ?? '';

    final palette = Theme.of(context).extension<DmToolColors>()!;
    Color catColor = palette.categoryNeutral;
    if (resolvedCategorySlug.isNotEmpty) {
      final cat = _firstWhereOrNull(
          schema.categories, (c) => c.slug == resolvedCategorySlug);
      if (cat != null) catColor = _parseHexColor(cat.color);
    }

    final entry = _TabEntry(
      entityId: entityId,
      title: resolvedName,
      categorySlug: resolvedCategorySlug,
      categoryColor: catColor,
    );

    setState(() {
      tabs.add(entry);
      if (panel == _Panel.left) {
        _leftActiveIndex = _leftTabs.length - 1;
      } else {
        _rightActiveIndex = _rightTabs.length - 1;
      }
    });
    _persistOpenTabs();
  }

  void _closeTab(int index, _Panel panel) {
    setState(() {
      if (panel == _Panel.left) {
        _leftTabs.removeAt(index);
        if (_leftActiveIndex >= _leftTabs.length) _leftActiveIndex = _leftTabs.length - 1;
      } else {
        _rightTabs.removeAt(index);
        if (_rightActiveIndex >= _rightTabs.length) _rightActiveIndex = _rightTabs.length - 1;
      }
    });
    _persistOpenTabs();
  }

  void _persistOpenTabs() {
    Future(() {
      if (!mounted) return;
      ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
        dbOpenLeft: _leftTabs.map((t) => t.entityId).toList(),
        dbOpenRight: _rightTabs.map((t) => t.entityId).toList(),
        dbActiveLeft: _leftActiveIndex,
        dbActiveRight: _rightActiveIndex,
      ));
    });
  }

  /// Uygulama açılışında UiState'den açık kartları restore et
  void restoreOpenTabs() {
    final uiState = ref.read(uiStateProvider);
    for (final eid in uiState.dbOpenLeft) {
      _openTab(eid, panel: _Panel.left);
    }
    for (final eid in uiState.dbOpenRight) {
      _openTab(eid, panel: _Panel.right);
    }
    setState(() {
      if (uiState.dbActiveLeft >= 0 && uiState.dbActiveLeft < _leftTabs.length) {
        _leftActiveIndex = uiState.dbActiveLeft;
      }
      if (uiState.dbActiveRight >= 0 && uiState.dbActiveRight < _rightTabs.length) {
        _rightActiveIndex = uiState.dbActiveRight;
      }
    });
  }

  bool _restored = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);
    final schema = ref.watch(worldSchemaProvider);

    // İlk build'de açık kartları restore et
    if (!_restored) {
      _restored = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreOpenTabs());
    }

    // Mobile: tek panel
    if (screen == ScreenType.phone) {
      if (_leftTabs.isEmpty) return _EmptyPanel(palette: palette);
      final active = _leftActiveIndex.clamp(0, _leftTabs.length - 1);
      return Column(
        children: [
          _TabBar(
            tabs: _leftTabs,
            activeIndex: active,
            palette: palette,
            onSelect: (i) { setState(() => _leftActiveIndex = i); _persistOpenTabs(); },
            onClose: (i) => _closeTab(i, _Panel.left),
          ),
          Expanded(
            child: _buildDatabaseCard(
              tab: _leftTabs[active],
              schema: schema,
              editMode: widget.editMode,
              panelId: 'left',
              onOpenLinked: _openInLeft,
            ),
          ),
        ],
      );
    }

    // Desktop/Tablet: Dual-panel with resizable splitter
    final uiState = ref.read(uiStateProvider);

    return ResizableSplit(
      axis: Axis.horizontal,
      initialRatio: uiState.dbSplitterRatio,
      minFirstSize: 200,
      minSecondSize: 200,
      palette: palette,
      onRatioChanged: (r) {
        ref.read(uiStateProvider.notifier).update((s) => s.copyWith(dbSplitterRatio: r));
      },
      first: _DragDropZone(
        highlightColor: palette.tabIndicator,
        onAccept: (id) => _openTab(id, panel: _Panel.left),
        child: _TabPanel(
          tabs: _leftTabs,
          activeIndex: _leftActiveIndex,
          palette: palette,
          editMode: widget.editMode,
          schema: schema,
          panelId: 'left',
          onOpenLinked: _openInRight,
          onSelect: (i) { setState(() => _leftActiveIndex = i); _persistOpenTabs(); },
          onClose: (i) => _closeTab(i, _Panel.left),
        ),
      ),
      second: _DragDropZone(
        highlightColor: palette.tabIndicator,
        onAccept: (id) => _openTab(id, panel: _Panel.right),
        child: _TabPanel(
          tabs: _rightTabs,
          activeIndex: _rightActiveIndex,
          palette: palette,
          editMode: widget.editMode,
          schema: schema,
          panelId: 'right',
          onOpenLinked: _openInLeft,
          onSelect: (i) { setState(() => _rightActiveIndex = i); _persistOpenTabs(); },
          onClose: (i) => _closeTab(i, _Panel.right),
        ),
      ),
    );
  }
}

enum _Panel { left, right }

/// Per-tab card renderer. Routes typed entity ids (`srd:…`, `hb:…`) through
/// `TypedCardDispatcher`; all other ids fall back to the schema-driven
/// `EntityCard`. Wraps the typed card in a [CardPanelScope] so link chips
/// inside can open referenced entities in the opposite panel.
Widget _buildDatabaseCard({
  required _TabEntry tab,
  required dynamic schema,
  required bool editMode,
  required String panelId,
  required void Function(String entityId) onOpenLinked,
}) {
  if (isTypedEntityId(tab.entityId)) {
    final typed = dispatchTypedCard(
      categorySlug: tab.categorySlug,
      entityId: tab.entityId,
      categoryColor: tab.categoryColor,
    );
    if (typed != null) {
      return CardPanelScope(
        panelId: panelId,
        openInOtherPanel: onOpenLinked,
        child: typed,
      );
    }
  }
  return EntityCard(
    key: ValueKey(tab.entityId),
    entityId: tab.entityId,
    categorySchema: schema == null
        ? null
        : _firstWhereOrNull(
            schema.categories, (c) => c.slug == tab.categorySlug),
    readOnly: !editMode,
  );
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class _TabEntry {
  final String entityId;
  final String title;
  final String categorySlug;
  final Color categoryColor;

  _TabEntry({required this.entityId, required this.title, required this.categorySlug, required this.categoryColor});
}

/// Tek bir panel: üstte tab bar, altta entity card.
class _TabPanel extends ConsumerWidget {
  final List<_TabEntry> tabs;
  final int activeIndex;
  final DmToolColors palette;
  final bool editMode;
  final dynamic schema;
  final String panelId;
  final void Function(String entityId) onOpenLinked;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _TabPanel({
    required this.tabs,
    required this.activeIndex,
    required this.palette,
    required this.editMode,
    this.schema,
    required this.panelId,
    required this.onOpenLinked,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tabs.isEmpty) {
      return _EmptyPanel(palette: palette);
    }

    final active = activeIndex.clamp(0, tabs.length - 1);

    return Column(
      children: [
        _TabBar(
          tabs: tabs,
          activeIndex: active,
          palette: palette,
          onSelect: onSelect,
          onClose: onClose,
        ),
        Expanded(
          child: _buildDatabaseCard(
            tab: tabs[active],
            schema: schema,
            editMode: editMode,
            panelId: panelId,
            onOpenLinked: onOpenLinked,
          ),
        ),
      ],
    );
  }
}

/// Tab bar — Python EntityTabWidget karşılığı.
class _TabBar extends StatelessWidget {
  final List<_TabEntry> tabs;
  final int activeIndex;
  final DmToolColors palette;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _TabBar({
    required this.tabs,
    required this.activeIndex,
    required this.palette,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final isActive = i == activeIndex;
          final catColor = tab.categoryColor;

          return GestureDetector(
            key: ValueKey(tab.entityId),
            onTap: () => onSelect(i),
            onTertiaryTapUp: (_) => onClose(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 1),
              decoration: BoxDecoration(
                color: isActive ? palette.tabActiveBg : palette.tabBg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      tab.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? palette.tabActiveText : palette.tabText,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onClose(i),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: isActive ? palette.tabText : palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// DragTarget wrapper — child'ı drag sırasında rebuild etmez, sadece border gösterir.
class _DragDropZone extends StatelessWidget {
  final Color highlightColor;
  final ValueChanged<String> onAccept;
  final Widget child;

  const _DragDropZone({
    required this.highlightColor,
    required this.onAccept,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (candidateData.isNotEmpty)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: highlightColor, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Color _parseHexColor(String hex) {
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFF808080);
  }
}

/// Boş panel placeholder.
class _EmptyPanel extends StatelessWidget {
  final DmToolColors palette;

  const _EmptyPanel({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 40, color: palette.sidebarLabelSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            'Select an entity from the sidebar\nor drag here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.sidebarLabelSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
