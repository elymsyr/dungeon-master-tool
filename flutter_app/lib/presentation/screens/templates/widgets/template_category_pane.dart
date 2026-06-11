import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'category_edit_sheet.dart';

/// Left-hand category list of the Template Editor (roadmap §1.5).
///
/// Read-only on the built-in template (selection + drill only). On an editable
/// copy (PR-2.1) it becomes a full CRUD surface: drag-to-reorder, a per-tile
/// Edit/Archive menu, and a working "+ Add category" row — all wired into
/// [TemplateEditorNotifier]'s category mutators.
class TemplateCategoryPane extends ConsumerWidget {
  /// When set, tapping a category also runs this (used by the tablet master
  /// pane to drill into the in-place field list, and by the phone page to push
  /// the fields page). Desktop leaves it null — selection alone repaints the
  /// adjacent field list pane.
  final ValueChanged<EntityCategorySchema>? onCategoryTap;

  const TemplateCategoryPane({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(templateEditorProvider);
    final categories = state.categories;
    final canEdit = state.canEdit;

    return Container(
      color: palette.sidebarFilterBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaneHeader(
            label: 'Categories',
            count: categories.length,
            palette: palette,
          ),
          Divider(height: 1, color: palette.sidebarDivider),
          Expanded(
            child: categories.isEmpty
                ? _EmptyHint(
                    text: canEdit
                        ? 'No categories yet — add one below.'
                        : 'This template has no categories.',
                    palette: palette,
                  )
                : _buildList(context, ref, categories, state, palette, canEdit),
          ),
          if (canEdit) ...[
            Divider(height: 1, color: palette.sidebarDivider),
            _AddRow(
              label: 'Add category',
              palette: palette,
              onTap: () => _handleAdd(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<EntityCategorySchema> categories,
    TemplateEditorState state,
    DmToolColors palette,
    bool canEdit,
  ) {
    if (!canEdit) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: categories.length,
        itemBuilder: (ctx, i) => _tile(context, ref, categories[i], state,
            palette, canEdit, reorderIndex: null),
      );
    }
    // Editable copy: drag-to-reorder with explicit handles so taps still select.
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      buildDefaultDragHandles: false,
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) => ref
          .read(templateEditorProvider.notifier)
          .reorderCategories(oldIndex, newIndex),
      itemBuilder: (ctx, i) => _tile(context, ref, categories[i], state,
          palette, canEdit,
          reorderIndex: i),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    EntityCategorySchema cat,
    TemplateEditorState state,
    DmToolColors palette,
    bool canEdit, {
    required int? reorderIndex,
  }) {
    return _CategoryTile(
      // Stable key required by ReorderableListView; harmless for ListView.
      key: ValueKey(cat.categoryId),
      category: cat,
      isSelected: cat.categoryId == state.selectedCategoryId,
      palette: palette,
      showChevron: onCategoryTap != null,
      canEdit: canEdit,
      reorderIndex: reorderIndex,
      onTap: () {
        ref
            .read(templateEditorProvider.notifier)
            .selectCategory(cat.categoryId);
        onCategoryTap?.call(cat);
      },
      onEdit: canEdit ? () => _handleEdit(context, ref, cat) : null,
      onToggleArchive: canEdit
          ? () => ref
              .read(templateEditorProvider.notifier)
              .toggleCategoryArchived(cat.categoryId)
          : null,
    );
  }

  Future<void> _handleAdd(BuildContext context, WidgetRef ref) async {
    final state = ref.read(templateEditorProvider);
    final result = await showCategoryEditSheet(
      context,
      siblingSlugs: [for (final c in state.categories) c.slug],
    );
    if (result == null) return;
    ref.read(templateEditorProvider.notifier).addCategory(
          name: result.name,
          slug: result.slug,
          icon: result.icon,
          color: result.color,
        );
  }

  Future<void> _handleEdit(
    BuildContext context,
    WidgetRef ref,
    EntityCategorySchema cat,
  ) async {
    final state = ref.read(templateEditorProvider);
    final result = await showCategoryEditSheet(
      context,
      existing: cat,
      siblingSlugs: [
        for (final c in state.categories)
          if (c.categoryId != cat.categoryId) c.slug,
      ],
    );
    if (result == null) return;
    ref.read(templateEditorProvider.notifier).updateCategoryMeta(
          cat.categoryId,
          name: result.name,
          slug: result.slug,
          icon: result.icon,
          color: result.color,
        );
  }
}

class _CategoryTile extends StatelessWidget {
  final EntityCategorySchema category;
  final bool isSelected;
  final DmToolColors palette;
  final bool showChevron;
  final bool canEdit;
  final int? reorderIndex;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleArchive;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.isSelected,
    required this.palette,
    required this.showChevron,
    required this.canEdit,
    required this.reorderIndex,
    required this.onTap,
    this.onEdit,
    this.onToggleArchive,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.color) ?? palette.featureCardAccent;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: palette.featureCardAccent.withValues(alpha: 0.15),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        category.name.isEmpty ? '(unnamed)' : category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: palette.tabActiveText,
          fontStyle: category.isArchived ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      subtitle: Text(
        '${category.fields.length} field${category.fields.length == 1 ? '' : 's'}'
        '${category.isArchived ? ' · archived' : ''}',
        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
      ),
      trailing: _buildTrailing(context),
      onTap: onTap,
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    if (!canEdit) {
      return showChevron
          ? Icon(Icons.chevron_right,
              size: 18, color: palette.sidebarLabelSecondary)
          : null;
    }
    // Editable: an actions menu plus a reorder drag handle.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<_CategoryAction>(
          tooltip: 'Category actions',
          icon: Icon(Icons.more_vert,
              size: 18, color: palette.sidebarLabelSecondary),
          onSelected: (action) {
            switch (action) {
              case _CategoryAction.edit:
                onEdit?.call();
              case _CategoryAction.toggleArchive:
                onToggleArchive?.call();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: _CategoryAction.edit,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit, size: 18),
                title: Text('Edit'),
              ),
            ),
            PopupMenuItem(
              value: _CategoryAction.toggleArchive,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  category.isArchived ? Icons.unarchive : Icons.archive,
                  size: 18,
                ),
                title: Text(category.isArchived ? 'Unarchive' : 'Archive'),
              ),
            ),
          ],
        ),
        if (reorderIndex != null)
          ReorderableDragStartListener(
            index: reorderIndex!,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 4),
              child: Icon(Icons.drag_handle,
                  size: 18, color: palette.sidebarLabelSecondary),
            ),
          ),
      ],
    );
  }
}

enum _CategoryAction { edit, toggleArchive }

class _PaneHeader extends StatelessWidget {
  final String label;
  final int count;
  final DmToolColors palette;

  const _PaneHeader({
    required this.label,
    required this.count,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  final VoidCallback? onTap;

  const _AddRow({required this.label, required this.palette, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? palette.featureCardAccent
        : palette.sidebarLabelSecondary.withValues(alpha: 0.5);
    return ListTile(
      dense: true,
      enabled: enabled,
      leading: Icon(Icons.add, size: 18, color: color),
      title: Text(
        label,
        style: TextStyle(fontSize: 13, color: color),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final DmToolColors palette;

  const _EmptyHint({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
        ),
      ),
    );
  }
}

Color? _parseColor(String hex) {
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}
