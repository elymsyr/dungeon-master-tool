import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/resizable_split.dart';
import 'entity_card.dart';

/// Database tab — Dual-panel tabbed card workspace.
/// Python ui/tabs/database_tab.py birebir karşılığı:
/// Sol panel (EntityTabWidget) + Sağ panel (EntityTabWidget), splitter ile.
class DatabaseScreen extends ConsumerStatefulWidget {
  final bool editMode;
  final String? selectedEntityId;
  final ValueChanged<String>? onEntitySelected;
  /// Optional panel hint paired with [selectedEntityId]. 'left' or
  /// 'right' opens the target in that panel (if both panels are visible).
  /// 'opposite' isn't passed in directly — relation taps resolve it to a
  /// concrete 'left'/'right' before propagating.
  final String? selectedEntityPanel;

  const DatabaseScreen({
    this.editMode = false,
    this.selectedEntityId,
    this.onEntitySelected,
    this.selectedEntityPanel,
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

  @override
  void didUpdateWidget(DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEntityId != null &&
        widget.selectedEntityId != oldWidget.selectedEntityId) {
      // Build sırasında provider değiştirilemez — frame sonrasına ertele
      final eid = widget.selectedEntityId!;
      final targetPanel = switch (widget.selectedEntityPanel) {
        'right' => _Panel.right,
        _ => _Panel.left,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTab(eid, panel: targetPanel);
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

    Color catColor = const Color(0xFF808080);
    if (entity != null) {
      final cat = _firstWhereOrNull(schema.categories, (c) => c.slug == entity.categorySlug);
      if (cat != null) catColor = _parseHexColor(cat.color);
    }

    final entry = _TabEntry(
      entityId: entityId,
      title: entity?.name ?? 'Unknown',
      categorySlug: entity?.categorySlug ?? '',
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
            child: IndexedStack(
              index: active,
              sizing: StackFit.expand,
              children: [
                for (final t in _leftTabs)
                  EntityCard(
                    key: ValueKey(t.entityId),
                    entityId: t.entityId,
                    categorySchema: _firstWhereOrNull(
                        schema.categories, (c) => c.slug == t.categorySlug),
                    readOnly: !widget.editMode,
                    panelId: 'left',
                  ),
              ],
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
          onSelect: (i) { setState(() => _rightActiveIndex = i); _persistOpenTabs(); },
          onClose: (i) => _closeTab(i, _Panel.right),
        ),
      ),
    );
  }
}

enum _Panel { left, right }

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
  final String? panelId;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _TabPanel({
    required this.tabs,
    required this.activeIndex,
    required this.palette,
    required this.editMode,
    this.schema,
    this.panelId,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tabs.isEmpty) {
      return _EmptyPanel(palette: palette);
    }

    final active = activeIndex.clamp(0, tabs.length - 1);

    // IndexedStack keeps non-active tabs mounted (Offstage). Switching tabs
    // skips re-running EntityCard initState + first computedFields evaluate.
    // Memory cost: O(open tabs) — open tabs are user-controlled, low.
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
          child: IndexedStack(
            index: active,
            sizing: StackFit.expand,
            children: [
              for (final t in tabs)
                EntityCard(
                  key: ValueKey(t.entityId),
                  entityId: t.entityId,
                  categorySchema: schema == null
                      ? null
                      : _firstWhereOrNull(
                          schema.categories, (c) => c.slug == t.categorySlug),
                  readOnly: !editMode,
                  panelId: panelId,
                ),
            ],
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
