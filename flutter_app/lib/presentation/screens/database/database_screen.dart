import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../theme/dm_tool_colors.dart';
import 'entity_card.dart';

/// Database tab — Dual-panel tabbed card workspace.
/// Python ui/tabs/database_tab.py birebir karşılığı:
/// Sol panel (EntityTabWidget) + Sağ panel (EntityTabWidget), splitter ile.
/// Her panel birden fazla entity kartını tab olarak açabilir.
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
  int _leftActiveIndex = -1;

  @override
  void didUpdateWidget(DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sidebar'dan entity seçildiğinde sol panelde tab aç
    if (widget.selectedEntityId != null &&
        widget.selectedEntityId != oldWidget.selectedEntityId) {
      _openTab(widget.selectedEntityId!, panel: _Panel.left);
    }
  }

  void _openTab(String entityId, {_Panel panel = _Panel.left}) {
    final existing = _leftTabs.indexWhere((t) => t.entityId == entityId);
    if (existing >= 0) {
      setState(() => _leftActiveIndex = existing);
      return;
    }

    final entities = ref.read(entityProvider);
    final entity = entities[entityId];

    setState(() {
      _leftTabs.add(_TabEntry(entityId: entityId, title: entity?.name ?? 'Unknown', categorySlug: entity?.categorySlug ?? ''));
      _leftActiveIndex = _leftTabs.length - 1;
    });
  }

  void _closeTab(int index, _Panel panel) {
    setState(() {
      _leftTabs.removeAt(index);
      if (_leftActiveIndex >= _leftTabs.length) _leftActiveIndex = _leftTabs.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);
    final schema = ref.watch(worldSchemaProvider);

    // Mobile: tek panel
    if (screen == ScreenType.phone) {
      if (_leftTabs.isEmpty) {
        return _EmptyPanel(palette: palette);
      }
      final active = _leftActiveIndex.clamp(0, _leftTabs.length - 1);
      return Column(
        children: [
          _TabBar(
            tabs: _leftTabs,
            activeIndex: active,
            palette: palette,
            onSelect: (i) => setState(() => _leftActiveIndex = i),
            onClose: (i) => _closeTab(i, _Panel.left),
          ),
          Expanded(
            child: EntityCard(
              key: ValueKey(_leftTabs[active].entityId),
              entityId: _leftTabs[active].entityId,
              categorySchema: _firstWhereOrNull(
                  schema.categories, (c) => c.slug == _leftTabs[active].categorySlug),
              readOnly: !widget.editMode,
            ),
          ),
        ],
      );
    }

    // Tek panel — DragTarget ile
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _openTab(details.data, panel: _Panel.left),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(border: Border.all(color: palette.tabIndicator, width: 2))
              : null,
          child: _TabPanel(
            tabs: _leftTabs,
            activeIndex: _leftActiveIndex,
            palette: palette,
            editMode: widget.editMode,
            schema: schema,
            onSelect: (i) => setState(() => _leftActiveIndex = i),
            onClose: (i) => _closeTab(i, _Panel.left),
          ),
        );
      },
    );
  }
}

enum _Panel { left }

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

  _TabEntry({required this.entityId, required this.title, required this.categorySlug});
}

/// Tek bir panel: üstte tab bar, altta entity card.
class _TabPanel extends ConsumerWidget {
  final List<_TabEntry> tabs;
  final int activeIndex;
  final DmToolColors palette;
  final bool editMode;
  final dynamic schema;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _TabPanel({
    required this.tabs,
    required this.activeIndex,
    required this.palette,
    required this.editMode,
    this.schema,
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
          child: EntityCard(
            key: ValueKey(tabs[active].entityId),
            entityId: tabs[active].entityId,
            categorySchema: schema == null ? null : _firstWhereOrNull(
                schema.categories, (c) => c.slug == tabs[active].categorySlug),
            readOnly: !editMode,
          ),
        ),
      ],
    );
  }
}

/// Tab bar — Python EntityTabWidget karşılığı.
/// Kapatılabilir, tıklanabilir tab'lar.
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
          final catColor = _categoryColor(tab.categorySlug);

          return GestureDetector(
            onTap: () => onSelect(i),
            // Orta tık ile kapat
            onTertiaryTapUp: (_) => onClose(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 1),
              decoration: BoxDecoration(
                color: isActive ? palette.tabActiveBg : palette.tabBg,
                border: Border(
                  top: BorderSide(
                    color: isActive ? catColor : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kategori renk noktası
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: catColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Tab başlığı
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
                  // Kapat butonu
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

  Color _categoryColor(String slug) {
    const colors = {
      'npc': Color(0xFFFF9800),
      'monster': Color(0xFFD32F2F),
      'player': Color(0xFF4CAF50),
      'spell': Color(0xFF7B1FA2),
      'equipment': Color(0xFF795548),
      'class': Color(0xFF1976D2),
      'race': Color(0xFF00897B),
      'location': Color(0xFF2E7D32),
      'quest': Color(0xFFF57C00),
      'lore': Color(0xFF5C6BC0),
      'status-effect': Color(0xFFE91E63),
      'feat': Color(0xFFFF7043),
      'background': Color(0xFF8D6E63),
      'plane': Color(0xFF26C6DA),
      'condition': Color(0xFFAB47BC),
    };
    return colors[slug] ?? const Color(0xFF808080);
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
