import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../domain/entities/schema/builtin/content.dart' show tier1Slugs;
import '../../domain/entities/schema/builtin/lookups.dart' show tier0Slugs;
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Sol sidebar — entity listesi, arama, kategori filtresi.
/// Python ui/widgets/entity_sidebar.py karşılığı.
class EntitySidebar extends ConsumerStatefulWidget {
  final WorldSchema? schema;
  final void Function(String entityId)? onEntitySelected;
  final void Function(String categorySlug)? onCreateEntity;

  const EntitySidebar({
    this.schema,
    this.onEntitySelected,
    this.onCreateEntity,
    super.key,
  });

  @override
  ConsumerState<EntitySidebar> createState() => _EntitySidebarState();
}

enum _SortMode { name, category, source }

class _EntitySidebarState extends ConsumerState<EntitySidebar> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  /// Selected category slugs. Empty = show all.
  final Set<String> _selectedSlugs = <String>{};
  _SortMode _sortMode = _SortMode.name;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
    // Restore the persisted category-filter selection on the next frame
    // (avoid `ref.read` in initState before the framework has finished
    // wiring this widget's element into the tree).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final persisted = ref.read(uiStateProvider).dbFilterSlugs;
      if (persisted.isNotEmpty) {
        setState(() {
          _selectedSlugs
            ..clear()
            ..addAll(persisted);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _persistFilter() {
    ref.read(uiStateProvider.notifier).update(
          (s) => s.copyWith(dbFilterSlugs: _selectedSlugs.toList()),
        );
  }

  /// Map slug → tier number (0/1/2) using the canonical built-in slug lists.
  /// Custom (user-authored) categories not in any list fall through to tier 2.
  int _tierFor(String slug) {
    if (tier0Slugs.contains(slug)) return 0;
    if (tier1Slugs.contains(slug)) return 1;
    return 2;
  }

  static const _tierLabels = {
    0: 'Tier 0 — Lookups',
    1: 'Tier 1 — Content',
    2: 'Tier 2 — DM',
  };
  static const _tierShort = {0: 'T0', 1: 'T1', 2: 'T2'};

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Watch only the sidebar-relevant fields — avoids rebuild when entity
    // fields (description, dmNotes, custom fields etc.) change.
    final summaries = ref.watch(entityProvider.select((map) =>
      map.values.map((e) => (
        id: e.id,
        name: e.name,
        categorySlug: e.categorySlug,
        source: e.source,
        tags: e.tags,
      )).toList(),
    ));
    final categories = widget.schema?.categories
            .where((c) => !c.isArchived)
            .toList() ??
        [];

    // Kategori slug → schema map (O(1) lookup)
    final catMap = <String, EntityCategorySchema>{};
    for (final c in categories) {
      catMap[c.slug] = c;
    }

    // Pass 1 — apply category filter only.
    final filtered = summaries.where((e) {
      if (_selectedSlugs.isNotEmpty &&
          !_selectedSlugs.contains(e.categorySlug)) {
        return false;
      }
      return true;
    }).toList();

    int cmp(({String id, String name, String categorySlug, String source,
        List<String> tags}) a,
        ({String id, String name, String categorySlug, String source,
        List<String> tags}) b) {
      return switch (_sortMode) {
        _SortMode.name => a.name.compareTo(b.name),
        _SortMode.category => a.categorySlug.compareTo(b.categorySlug) != 0
            ? a.categorySlug.compareTo(b.categorySlug)
            : a.name.compareTo(b.name),
        _SortMode.source => a.source.compareTo(b.source) != 0
            ? a.source.compareTo(b.source)
            : a.name.compareTo(b.name),
      };
    }

    // Pass 2 — split by search query.
    //   query empty: matched = filtered, others empty.
    //   query non-empty:
    //     matched = entities in filter AND match query
    //     others  = entities matching query but OUTSIDE the filter
    //               (so user still sees matches across all categories,
    //               just dimmed below the in-filter block).
    final query = _searchQuery.trim().toLowerCase();
    final matched = <({String id, String name, String categorySlug,
        String source, List<String> tags})>[];
    final others = <({String id, String name, String categorySlug,
        String source, List<String> tags})>[];
    if (query.isEmpty) {
      matched.addAll(filtered);
    } else {
      bool hits(({String id, String name, String categorySlug, String source,
          List<String> tags}) e) =>
          e.name.toLowerCase().contains(query) ||
          e.source.toLowerCase().contains(query) ||
          e.tags.any((t) => t.toLowerCase().contains(query));
      final inFilter = _selectedSlugs.isEmpty
          ? null
          : _selectedSlugs;
      for (final e in summaries) {
        if (!hits(e)) continue;
        final isIn = inFilter == null || inFilter.contains(e.categorySlug);
        (isIn ? matched : others).add(e);
      }
    }
    matched.sort(cmp);
    others.sort(cmp);

    return Column(
      children: [
        // Arama
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.lblSearch,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _searchController.clear(),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),

        // Kategori filtresi — compact summary button. Tap → opens a wide
        // floating dialog with the Tier-grouped checkbox grid (the dialog
        // is wider than the sidebar so 3 tiers fit comfortably).
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: OutlinedButton.icon(
              onPressed: () => _openFilterDialog(categories),
              icon: const Icon(Icons.filter_list, size: 16),
              label: Builder(builder: (_) {
                final summary = _selectedSlugs.isEmpty
                    ? 'All Categories'
                    : '${_selectedSlugs.length} of ${categories.length} selected';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        summary,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedSlugs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(_selectedSlugs.clear);
                          _persistFilter();
                        },
                        child: Icon(Icons.close, size: 14,
                            color: palette.sidebarLabelSecondary),
                      ),
                    ],
                  ],
                );
              }),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),

        // Sort toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                query.isEmpty
                    ? '${matched.length} entities'
                    : '${matched.length} match · ${others.length} other',
                style: TextStyle(
                    fontSize: 10, color: palette.sidebarLabelSecondary),
              ),
              const Spacer(),
              PopupMenuButton<_SortMode>(
                initialValue: _sortMode,
                onSelected: (v) => setState(() => _sortMode = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _SortMode.name, child: Text('Sort by Name', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: _SortMode.category, child: Text('Sort by Category', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: _SortMode.source, child: Text('Sort by Source', style: TextStyle(fontSize: 12))),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 14, color: palette.sidebarLabelSecondary),
                    const SizedBox(width: 2),
                    Text(
                      switch (_sortMode) { _SortMode.name => 'Name', _SortMode.category => 'Category', _SortMode.source => 'Source' },
                      style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Divider(height: 1, color: palette.sidebarDivider),

        // Entity listesi — tek sütun. Search active iken matched ilk sırada,
        // ardından "Other entities" header + dimmed others bloğu.
        Expanded(
          child: (matched.isEmpty && others.isEmpty)
              ? Center(
                  child: Text(
                    summaries.isEmpty ? 'No entities yet' : 'No results',
                    style: TextStyle(color: palette.sidebarLabelSecondary),
                  ),
                )
              : Builder(builder: (_) {
                  // Flatten into a single index space:
                  //   [matched...] [optional header] [others...]
                  final hasOthers = others.isNotEmpty;
                  final headerIndex = hasOthers ? matched.length : -1;
                  final total = matched.length +
                      (hasOthers ? 1 + others.length : 0);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    itemCount: total,
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      if (index == headerIndex) {
                        return _OtherEntitiesHeader(
                            count: others.length, palette: palette);
                      }
                      final isOther = hasOthers && index > headerIndex;
                      final entity = isOther
                          ? others[index - headerIndex - 1]
                          : matched[index];
                      return _entityRow(
                          entity, catMap, palette, dimmed: isOther);
                    },
                  );
                }),
        ),

        // Yeni entity ekleme
        Divider(height: 1, color: palette.sidebarDivider),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, categories),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.btnCreate),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.successBtnBg,
                    foregroundColor: palette.successBtnText,
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openFilterDialog(
      List<EntityCategorySchema> categories) async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Local working set so the dialog can apply or cancel atomically.
    final working = Set<String>.from(_selectedSlugs);

    await showDialog<void>(
      context: context,
      // Barrier dismiss = cancel; "Apply" commits.
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        // Wide dialog so 3 tier columns fit. Cap at 720; shrink on phones.
        final width = mq.size.width.clamp(320.0, 720.0);
        final height = (mq.size.height * 0.7).clamp(360.0, 600.0);

        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 32),
            child: SizedBox(
              width: width,
              height: height,
              child: Column(
                children: [
                  // Title + close
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 18,
                            color: palette.tabActiveText),
                        const SizedBox(width: 6),
                        Text(
                          'Filter Categories',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: palette.sidebarDivider),
                  Expanded(
                    child: _CategoryFilterPanel(
                      categories: categories,
                      selected: working,
                      tierFor: _tierFor,
                      tierLabels: _tierLabels,
                      tierShort: _tierShort,
                      palette: palette,
                      onToggleSlug: (slug) {
                        setDialogState(() {
                          if (working.contains(slug)) {
                            working.remove(slug);
                          } else {
                            working.add(slug);
                          }
                        });
                      },
                      onToggleTier: (tier, allSelected) {
                        setDialogState(() {
                          final tierSlugs = categories
                              .where((c) => _tierFor(c.slug) == tier)
                              .map((c) => c.slug);
                          if (allSelected) {
                            working.removeAll(tierSlugs);
                          } else {
                            working.addAll(tierSlugs);
                          }
                        });
                      },
                      onClearAll: () => setDialogState(working.clear),
                    ),
                  ),
                  Divider(height: 1, color: palette.sidebarDivider),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Text(
                          working.isEmpty
                              ? 'All categories shown'
                              : '${working.length} of ${categories.length} selected',
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedSlugs
                                ..clear()
                                ..addAll(working);
                            });
                            _persistFilter();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showCreateDialog(
      BuildContext context, List<EntityCategorySchema> categories) {
    final nameController = TextEditingController(text: 'New Record');
    String selectedSlug = categories.isNotEmpty ? categories.first.slug : 'npc';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Entity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSlug,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(
                        value: c.slug,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => selectedSlug = v ?? selectedSlug,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.of(context)!.btnCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final id = ref.read(entityProvider.notifier).create(
                      selectedSlug,
                      name: name,
                    );
                Navigator.pop(ctx);
                widget.onEntitySelected?.call(id);
              }
            },
            child: Text(L10n.of(context)!.btnCreate),
          ),
        ],
      ),
    ).whenComplete(nameController.dispose);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Single entity row used by the sidebar list. [dimmed] = true for the
  /// "Other entities" section shown below the matches when a search query
  /// is active — opacity 0.5 so the matched block visually leads.
  Widget _entityRow(
    ({String id, String name, String categorySlug, String source,
        List<String> tags}) entity,
    Map<String, EntityCategorySchema> catMap,
    DmToolColors palette, {
    required bool dimmed,
  }) {
    final cat = catMap[entity.categorySlug];
    final color =
        cat != null ? _parseColor(cat.color) : palette.tabText;
    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Draggable<String>(
        key: ValueKey(entity.id),
        data: entity.id,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          elevation: 2,
          borderRadius: palette.cbr,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: palette.featureCardBg,
                borderRadius: palette.cbr),
            child: Text(entity.name,
                style: TextStyle(
                    fontSize: 12, color: palette.tabActiveText)),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: InkWell(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: Text(entity.name,
                  style:
                      TextStyle(fontSize: 13, color: palette.tabText)),
            ),
          ),
        ),
        child: InkWell(
          onTap: () => widget.onEntitySelected?.call(entity.id),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entity.name,
                          style: TextStyle(
                              fontSize: 13,
                              color: palette.tabActiveText),
                          overflow: TextOverflow.ellipsis),
                      if (entity.source.isNotEmpty)
                        Text(entity.source,
                            style: TextStyle(
                                fontSize: 10,
                                color: palette.sidebarLabelSecondary),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(cat?.name ?? entity.categorySlug,
                    style: TextStyle(
                        fontSize: 10,
                        color: palette.sidebarLabelSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section divider rendered between the matched and the dimmed "other"
/// entities when a search query is active.
class _OtherEntitiesHeader extends StatelessWidget {
  final int count;
  final DmToolColors palette;
  const _OtherEntitiesHeader({required this.count, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.sidebarDivider)),
          const SizedBox(width: 8),
          Text(
            'Other entities ($count)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: palette.sidebarDivider)),
        ],
      ),
    );
  }
}

/// Tier-grouped category filter body — three side-by-side tier columns,
/// each with sticky header + 1-column scrollable list of checkboxes.
/// Hosted inside a `Dialog` (see `_openFilterDialog`); the dialog supplies
/// its own title bar and Apply/Cancel actions, so this widget renders only
/// the grid body.
///
/// Selected rows are rendered against a working copy that the host widget
/// applies on Apply.
class _CategoryFilterPanel extends StatelessWidget {
  final List<EntityCategorySchema> categories;
  final Set<String> selected;
  final int Function(String slug) tierFor;
  final Map<int, String> tierLabels;
  final Map<int, String> tierShort;
  final DmToolColors palette;
  final ValueChanged<String> onToggleSlug;
  final void Function(int tier, bool allSelected) onToggleTier;
  final VoidCallback onClearAll;

  const _CategoryFilterPanel({
    required this.categories,
    required this.selected,
    required this.tierFor,
    required this.tierLabels,
    required this.tierShort,
    required this.palette,
    required this.onToggleSlug,
    required this.onToggleTier,
    required this.onClearAll,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final byTier = <int, List<EntityCategorySchema>>{0: [], 1: [], 2: []};
    for (final c in categories) {
      byTier[tierFor(c.slug)]!.add(c);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tier in const [0, 1, 2]) ...[
            Expanded(
              child: _tierColumn(tier, byTier[tier] ?? const []),
            ),
            if (tier != 2)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: palette.sidebarDivider,
              ),
          ],
        ],
      ),
    );
  }

  /// Single-tier column: sticky header on top, scrollable 1-column list of
  /// category checkboxes below. Three of these sit side-by-side in the
  /// expanded filter panel.
  Widget _tierColumn(int tier, List<EntityCategorySchema> tierCats) {
    final tierSlugs = tierCats.map((c) => c.slug).toSet();
    final selectedInTier =
        tierSlugs.where((s) => selected.contains(s)).length;
    final allSelected =
        selectedInTier == tierSlugs.length && tierSlugs.isNotEmpty;
    final partial = selectedInTier > 0 && !allSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tier header — bold label + bulk toggle + N/M counter.
        Container(
          color: palette.tabBg,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              _smallCheckbox(
                value: allSelected ? true : (partial ? null : false),
                tristate: true,
                onChanged: () => onToggleTier(tier, allSelected),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  tierLabels[tier]!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.tabActiveText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$selectedInTier/${tierSlugs.length}',
                style: TextStyle(
                    fontSize: 9, color: palette.sidebarLabelSecondary),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.sidebarDivider),
        // Category list — own scroll axis so a long Tier-0 column doesn't
        // force the others to scroll in lockstep.
        Expanded(
          child: tierCats.isEmpty
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final cat in tierCats) _categoryRow(cat, tier),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _categoryRow(EntityCategorySchema cat, int tier) {
    // Tier badge dropped — outer column already encodes the tier.
    return InkWell(
      onTap: () => onToggleSlug(cat.slug),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          children: [
            _smallCheckbox(
              value: selected.contains(cat.slug),
              onChanged: () => onToggleSlug(cat.slug),
            ),
            const SizedBox(width: 3),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: _parseColor(cat.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                cat.name,
                style: TextStyle(
                    fontSize: 11, color: palette.tabActiveText),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact checkbox — Material's min hit-target stays at 48dp; we shrink
  /// the painted box via Transform.scale and clamp the slot to 16x16.
  Widget _smallCheckbox({
    required bool? value,
    required VoidCallback onChanged,
    bool tristate = false,
  }) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Transform.scale(
        scale: 0.75,
        child: Checkbox(
          value: value,
          tristate: tristate,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: palette.sidebarDivider, width: 1),
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }
}

