import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../domain/entities/schema/field_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'field_type_meta.dart';
import 'field_type_picker.dart';

/// Middle pane: the field list for the currently-selected category
/// (roadmap §1.5).
///
/// Read-only on the built-in template (taps select a field for the inspector).
/// On an editable copy (PR-2.2) it becomes a full CRUD surface: drag-to-reorder,
/// a per-tile Delete menu, and a working "+ Add field" row that opens the
/// responsive field-type picker — all wired into [TemplateEditorNotifier]'s
/// field mutators.
class TemplateFieldListPane extends ConsumerWidget {
  /// Optional back affordance shown as a leading header chevron (tablet master
  /// pane drilling back to the category list). Null on desktop/phone.
  final VoidCallback? onBack;

  /// Run after a field is selected (phone pushes the field edit page). Also
  /// fired after a new field is added on touch surfaces so the phone flow drills
  /// straight into the new field's edit page.
  final ValueChanged<FieldSchema>? onFieldTap;

  /// Phone pages own the title via their AppBar, so they hide the in-pane
  /// header to avoid showing the category name twice.
  final bool showHeader;

  const TemplateFieldListPane({
    super.key,
    this.onBack,
    this.onFieldTap,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(templateEditorProvider);
    final category = state.selectedCategory;
    final canEdit = state.canEdit;

    if (category == null) {
      return Container(
        color: palette.tabBg,
        child: _Empty(
          text: 'Select a category to see its fields.',
          palette: palette,
        ),
      );
    }

    // Sort by orderIndex (stable) to mirror the on-sheet field order. This is
    // the order the reorder mutator's indices are taken against.
    final fields = [...category.fields]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Container(
      color: palette.tabBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _Header(
              title: category.name,
              subtitle:
                  '${fields.length} field${fields.length == 1 ? '' : 's'}',
              palette: palette,
              onBack: onBack,
            ),
            Divider(height: 1, color: palette.sidebarDivider),
          ],
          Expanded(
            child: fields.isEmpty
                ? _Empty(
                    text: canEdit
                        ? 'No fields yet — add one below.'
                        : 'This category has no fields.',
                    palette: palette,
                  )
                : _buildList(context, ref, fields, state, palette, canEdit),
          ),
          if (canEdit) ...[
            Divider(height: 1, color: palette.sidebarDivider),
            _AddRow(
              palette: palette,
              onTap: () => _handleAdd(context, ref, category.categoryId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<FieldSchema> fields,
    TemplateEditorState state,
    DmToolColors palette,
    bool canEdit,
  ) {
    if (!canEdit) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: fields.length,
        itemBuilder: (ctx, i) =>
            _tile(context, ref, fields[i], state, palette, canEdit,
                reorderIndex: null),
      );
    }
    // Editable copy: drag-to-reorder with explicit handles so taps still select.
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      buildDefaultDragHandles: false,
      itemCount: fields.length,
      onReorder: (oldIndex, newIndex) => ref
          .read(templateEditorProvider.notifier)
          .reorderFields(state.selectedCategoryId!, oldIndex, newIndex),
      itemBuilder: (ctx, i) => _tile(
        context,
        ref,
        fields[i],
        state,
        palette,
        canEdit,
        reorderIndex: i,
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    FieldSchema field,
    TemplateEditorState state,
    DmToolColors palette,
    bool canEdit, {
    required int? reorderIndex,
  }) {
    return _FieldTile(
      // Stable key required by ReorderableListView; harmless for ListView.
      key: ValueKey(field.fieldId),
      field: field,
      isSelected: field.fieldId == state.selectedFieldId,
      palette: palette,
      canEdit: canEdit,
      reorderIndex: reorderIndex,
      onTap: () {
        ref.read(templateEditorProvider.notifier).selectField(field.fieldId);
        onFieldTap?.call(field);
      },
      onDelete: canEdit
          ? () => _handleDelete(context, ref, state.selectedCategoryId!, field)
          : null,
    );
  }

  Future<void> _handleAdd(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
  ) async {
    final type = await showFieldTypePicker(context);
    if (type == null) return;
    final notifier = ref.read(templateEditorProvider.notifier);
    notifier.addField(categoryId, type);
    // addField selects the new field; drill into it on the phone flow.
    final added = ref.read(templateEditorProvider).selectedField;
    if (added != null) onFieldTap?.call(added);
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    FieldSchema field,
  ) async {
    final label = field.label.isEmpty ? field.fieldKey : field.label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete field?'),
        content: Text(
          'Remove "$label" from this category? Cards already created keep any '
          'value stored under "${field.fieldKey}" until they are next saved, '
          'but the field stops rendering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(ctx).extension<DmToolColors>()!.dangerBtnBg,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(templateEditorProvider.notifier).removeField(categoryId, field.fieldId);
  }
}

class _FieldTile extends StatelessWidget {
  final FieldSchema field;
  final bool isSelected;
  final DmToolColors palette;
  final bool canEdit;
  final int? reorderIndex;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FieldTile({
    super.key,
    required this.field,
    required this.isSelected,
    required this.palette,
    required this.canEdit,
    required this.reorderIndex,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = FieldTypeMeta.of(field.fieldType);
    final ruleCount = field.rules?.length ?? 0;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: palette.featureCardAccent.withValues(alpha: 0.15),
      leading: Icon(meta.icon, size: 18, color: palette.sidebarLabelSecondary),
      title: Row(
        children: [
          Flexible(
            child: Text(
              field.label.isEmpty ? field.fieldKey : field.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.tabActiveText,
              ),
            ),
          ),
          if (field.isRequired)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.star, size: 11, color: palette.dangerBtnBg),
            ),
        ],
      ),
      subtitle: Text(
        '${meta.label}${field.isList ? ' · list' : ''} · ${field.fieldKey}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: palette.sidebarLabelSecondary,
        ),
      ),
      trailing: _buildTrailing(),
      onTap: onTap,
    );
  }

  Widget? _buildTrailing() {
    final ruleCount = field.rules?.length ?? 0;
    if (!canEdit) {
      return ruleCount > 0 ? _RuleBadge(count: ruleCount, palette: palette) : null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ruleCount > 0) _RuleBadge(count: ruleCount, palette: palette),
        PopupMenuButton<_FieldAction>(
          tooltip: 'Field actions',
          icon: Icon(Icons.more_vert,
              size: 18, color: palette.sidebarLabelSecondary),
          onSelected: (action) {
            switch (action) {
              case _FieldAction.delete:
                onDelete?.call();
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: _FieldAction.delete,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, size: 18),
                title: Text('Delete'),
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

enum _FieldAction { delete }

class _RuleBadge extends StatelessWidget {
  final int count;
  final DmToolColors palette;

  const _RuleBadge({required this.count, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count rule${count == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.featureCardAccent,
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final DmToolColors palette;
  final VoidCallback onTap;

  const _AddRow({required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.add, size: 18, color: palette.featureCardAccent),
      title: Text(
        'Add field',
        style: TextStyle(fontSize: 13, color: palette.featureCardAccent),
      ),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final DmToolColors palette;
  final VoidCallback? onBack;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.palette,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 16, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              iconSize: 22,
              color: palette.tabActiveText,
              tooltip: 'Back to categories',
              onPressed: onBack,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.tabActiveText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  final DmToolColors palette;

  const _Empty({required this.text, required this.palette});

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
