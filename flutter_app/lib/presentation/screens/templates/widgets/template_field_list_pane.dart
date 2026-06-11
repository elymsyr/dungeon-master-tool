import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../domain/entities/schema/field_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'field_type_meta.dart';

/// Middle pane: the field list for the currently-selected category
/// (roadmap §1.5). Read-only in PR-1.5 — taps select a field for the inspector;
/// reorder handles and "+ Add field" land in Phase 2.2 (shown disabled here so
/// the layout contract is fixed).
class TemplateFieldListPane extends ConsumerWidget {
  /// Optional back affordance shown as a leading header chevron (tablet master
  /// pane drilling back to the category list). Null on desktop/phone.
  final VoidCallback? onBack;

  /// Run after a field is selected (phone pushes the field edit page).
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

    if (category == null) {
      return Container(
        color: palette.tabBg,
        child: _Empty(
          text: 'Select a category to see its fields.',
          palette: palette,
        ),
      );
    }

    // Sort by orderIndex (stable) to mirror the on-sheet field order.
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
                    text: 'This category has no fields.',
                    palette: palette,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: fields.length,
                    itemBuilder: (ctx, i) {
                      final field = fields[i];
                      return _FieldTile(
                        field: field,
                        isSelected: field.fieldId == state.selectedFieldId,
                        palette: palette,
                        onTap: () {
                          ref
                              .read(templateEditorProvider.notifier)
                              .selectField(field.fieldId);
                          onFieldTap?.call(field);
                        },
                      );
                    },
                  ),
          ),
          if (state.canEdit) ...[
            Divider(height: 1, color: palette.sidebarDivider),
            ListTile(
              dense: true,
              enabled: false,
              leading: Icon(Icons.add,
                  size: 18,
                  color: palette.sidebarLabelSecondary.withValues(alpha: 0.5)),
              title: Text(
                'Add field',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.sidebarLabelSecondary.withValues(alpha: 0.5),
                ),
              ),
              // Wired in Phase 2.2 (field CRUD + type picker).
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final FieldSchema field;
  final bool isSelected;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _FieldTile({
    required this.field,
    required this.isSelected,
    required this.palette,
    required this.onTap,
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
      trailing: ruleCount > 0
          ? _RuleBadge(count: ruleCount, palette: palette)
          : null,
      onTap: onTap,
    );
  }
}

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
