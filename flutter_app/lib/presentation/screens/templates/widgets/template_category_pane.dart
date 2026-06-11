import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../theme/dm_tool_colors.dart';

/// Left-hand category list of the Template Editor (roadmap §1.5).
///
/// PR-1.5 is read-only: it lists the template's categories and drives selection
/// into [templateEditorProvider]. Reorder handles and the "+ Add category" row
/// land in Phase 2.1; until then they are hidden (built-in) or shown disabled
/// (editable copy) so the layout contract is stable.
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
                    text: 'This template has no categories.',
                    palette: palette,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      final isSelected =
                          cat.categoryId == state.selectedCategoryId;
                      return _CategoryTile(
                        category: cat,
                        isSelected: isSelected,
                        palette: palette,
                        showChevron: onCategoryTap != null,
                        onTap: () {
                          ref
                              .read(templateEditorProvider.notifier)
                              .selectCategory(cat.categoryId);
                          onCategoryTap?.call(cat);
                        },
                      );
                    },
                  ),
          ),
          if (state.canEdit) ...[
            Divider(height: 1, color: palette.sidebarDivider),
            _AddRow(
              label: 'Add category',
              palette: palette,
              // Wired in Phase 2.1 (category CRUD). Disabled in PR-1.5.
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final EntityCategorySchema category;
  final bool isSelected;
  final DmToolColors palette;
  final bool showChevron;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.palette,
    required this.showChevron,
    required this.onTap,
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
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: palette.tabActiveText,
        ),
      ),
      subtitle: Text(
        '${category.fields.length} field${category.fields.length == 1 ? '' : 's'}'
        '${category.isArchived ? ' · archived' : ''}',
        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
      ),
      trailing: showChevron
          ? Icon(Icons.chevron_right,
              size: 18, color: palette.sidebarLabelSecondary)
          : null,
      onTap: onTap,
    );
  }
}

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
