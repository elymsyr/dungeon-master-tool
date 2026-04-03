import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
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

class _EntitySidebarState extends ConsumerState<EntitySidebar> {
  String _searchQuery = '';
  String? _selectedCategory; // null = tümü

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(entityProvider);
    final categories = widget.schema?.categories
            .where((c) => !c.isArchived)
            .toList() ??
        [];

    // Kategori slug → schema map (O(1) lookup)
    final catMap = <String, EntityCategorySchema>{};
    for (final c in categories) {
      catMap[c.slug] = c;
    }

    // Filtrele
    final filtered = entities.values.where((e) {
      if (_selectedCategory != null && e.categorySlug != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        // Arama
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.lblSearch,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // Kategori filtresi — dropdown, iki sütun
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCategory,
                isExpanded: true,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, size: 18, color: palette.tabText),
                style: TextStyle(fontSize: 12, color: palette.tabActiveText),
                dropdownColor: palette.uiPopupBg,
                borderRadius: BorderRadius.circular(4),
                hint: Text('All Categories', style: TextStyle(fontSize: 12, color: palette.tabText)),
                onChanged: (v) => setState(() => _selectedCategory = v),
                selectedItemBuilder: (_) => [
                  // "All" seçili gösterimi
                  _dropdownLabel('All Categories', null, palette),
                  ...categories.map((cat) =>
                    _dropdownLabel(cat.name, _parseColor(cat.color), palette),
                  ),
                ],
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Categories', style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                  ),
                  ...categories.map((cat) => DropdownMenuItem<String?>(
                    value: cat.slug,
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _parseColor(cat.color), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(cat.name, style: TextStyle(fontSize: 12, color: palette.uiPopupText)),
                      ],
                    ),
                  )),
                ],
                menuMaxHeight: 400,
              ),
            ),
          ),

        const SizedBox(height: 4),
        Divider(height: 1, color: palette.sidebarDivider),

        // Entity listesi — tek sütun liste
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    entities.isEmpty ? 'No entities yet' : 'No results',
                    style: TextStyle(color: palette.sidebarLabelSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  itemCount: filtered.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final entity = filtered[index];
                    final cat = catMap[entity.categorySlug];
                    final color = cat != null ? _parseColor(cat.color) : palette.tabText;

                    return Draggable<String>(
                      data: entity.id,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(entity.name, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: InkWell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Text(entity.name, style: TextStyle(fontSize: 13, color: palette.tabText)),
                          ),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => widget.onEntitySelected?.call(entity.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Row(
                            children: [
                              // Kategori renk noktası
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              // İsim + source
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entity.name, style: TextStyle(fontSize: 13, color: palette.tabActiveText), overflow: TextOverflow.ellipsis),
                                    if (entity.source.isNotEmpty)
                                      Text(entity.source, style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              // Kategori adı (sağ)
                              Text(cat?.name ?? entity.categorySlug, style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
    );
  }

  Widget _dropdownLabel(String text, Color? dotColor, DmToolColors palette) {
    return Row(
      children: [
        if (dotColor != null) ...[
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(text, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

