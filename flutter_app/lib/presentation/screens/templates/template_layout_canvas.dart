import 'package:flutter/material.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/template_edit.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import 'template_edit_controller.dart';
import 'template_settings_forms.dart';
import 'template_styles.dart';

/// A category's layout as editable boxes (DESIGN §7.4): the ungrouped
/// "Properties" box, then the groups in card order, each laid out in its
/// columns. Groups reorder by their header handle; fields drag between and
/// inside groups (handle: at once; anywhere on the tile: long press);
/// palette styles drop in as new fields.
class TemplateLayoutCanvas extends StatelessWidget {
  const TemplateLayoutCanvas({
    super.key,
    required this.controller,
    required this.compact,
    this.onOpenField,
    this.onOpenGroup,
  });

  final TemplateEditController controller;

  /// Phone: one column per group (V22) and room for the add button.
  final bool compact;

  /// Phone: open the settings sheet after selecting (desktop shows the
  /// selection in the right panel instead).
  final ValueChanged<String>? onOpenField;
  final ValueChanged<String>? onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final cat = controller.category!;
    final groups = sortedGroups(cat);
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.fromLTRB(16, 16, 16, compact ? 96 : 24),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Bucket(canvas: this, cat: cat, group: null, index: null),
      ),
      footer: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => addGroupWithName(context, controller),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.tplAddGroup),
        ),
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) => Padding(
        key: ValueKey(groups[i].groupId),
        padding: const EdgeInsets.only(bottom: 12),
        child: _Bucket(canvas: this, cat: cat, group: groups[i], index: i),
      ),
      onReorderItem: controller.reorderGroups,
    );
  }

  /// A drop on [groupId] before [beforeFieldId] (end when null).
  void _drop(
    BuildContext context,
    TemplateDrag d,
    EntityCategorySchema cat,
    String? groupId,
    String? beforeFieldId,
  ) {
    final others = [
      for (final f in fieldsIn(cat, groupId))
        if (f.fieldId != d.fieldId) f,
    ];
    final at = beforeFieldId == null
        ? null
        : others.indexWhere((f) => f.fieldId == beforeFieldId);
    final index = at == null || at < 0 ? null : at;
    if (d.fieldId != null) {
      if (d.fieldId == beforeFieldId) return;
      controller.moveField(d.fieldId!, groupId: groupId, index: index);
    } else {
      addFromPalette(context, controller, d, groupId: groupId, index: index);
    }
  }
}

/// One box: the ungrouped fields ([group] null) or a group.
class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.canvas,
    required this.cat,
    required this.group,
    required this.index,
  });

  final TemplateLayoutCanvas canvas;
  final EntityCategorySchema cat;
  final FieldGroup? group;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = canvas.controller;
    final g = group;
    final fields = fieldsIn(cat, g?.groupId);
    final selected =
        g != null && c.panel == TemplatePanel.group && c.groupId == g.groupId;
    final cols = canvas.compact || g == null ? 1 : g.gridColumns.clamp(1, 4);

    void open() {
      c.selectGroup(g?.groupId);
      if (g != null) canvas.onOpenGroup?.call(g.groupId);
    }

    final headerRow = InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
        child: Row(
          children: [
            if (index != null)
              ReorderableDragStartListener(
                index: index!,
                child: Tooltip(
                  message: l10n.tplDragHandle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                g == null ? l10n.propertiesTitle : g.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            if (g != null) ...[
              if (g.isCollapsed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.unfold_less,
                    size: 16,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              TemplatePill(l10n.tplColumns(g.gridColumns)),
              IconButton(
                tooltip: l10n.tplGroupSettings,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.more_vert, size: 18, color: palette.tabText),
                onPressed: open,
              ),
            ],
          ],
        ),
      ),
    );

    // Long press on the header picks the group up (touch); the handle drags
    // at once. Field tiles keep their own long press.
    final header = index == null
        ? headerRow
        : ReorderableDelayedDragStartListener(index: index!, child: headerRow);

    final body = fields.isEmpty
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              g == null ? l10n.tplUngroupedHint : l10n.tplGroupEmpty,
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              children: [
                for (final row in _rows(fields, cols))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, f) in row.indexed) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            flex: f.gridColumnSpan.clamp(1, cols),
                            child: _FieldTile(
                              canvas: canvas,
                              cat: cat,
                              field: f,
                            ),
                          ),
                        ],
                        if (_span(row, cols) < cols) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            flex: cols - _span(row, cols),
                            child: const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );

    return DragTarget<TemplateDrag>(
      onAcceptWithDetails: (d) =>
          canvas._drop(context, d.data, cat, g?.groupId, null),
      builder: (context, candidates, _) => Container(
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(
            width: selected || candidates.isNotEmpty ? 2 : 1,
            color: selected || candidates.isNotEmpty
                ? palette.featureCardAccent
                : palette.featureCardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        ),
      ),
    );
  }

  static int _span(List<FieldSchema> row, int cols) =>
      row.fold(0, (s, f) => s + f.gridColumnSpan.clamp(1, cols));

  /// Left to right, row by row; a field never splits across rows (same
  /// rule as the card).
  static List<List<FieldSchema>> _rows(List<FieldSchema> fields, int cols) {
    final rows = <List<FieldSchema>>[];
    var row = <FieldSchema>[];
    var used = 0;
    for (final f in fields) {
      final span = f.gridColumnSpan.clamp(1, cols);
      if (used + span > cols && row.isNotEmpty) {
        rows.add(row);
        row = [];
        used = 0;
      }
      row.add(f);
      used += span;
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.canvas,
    required this.cat,
    required this.field,
  });

  final TemplateLayoutCanvas canvas;
  final EntityCategorySchema cat;
  final FieldSchema field;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = canvas.controller;
    final f = field;
    final selected = c.panel == TemplatePanel.field && c.fieldId == f.fieldId;
    final legacy = isLegacyFieldType(f.fieldType);

    Widget tile({required bool highlight, Widget? handle}) => Material(
      // The page colour inside the group box, so a tile reads as one.
      color: selected
          ? palette.featureCardAccent.withValues(alpha: 0.12)
          : palette.canvasBg,
      shape: RoundedRectangleBorder(
        borderRadius: palette.br,
        side: BorderSide(
          color: highlight || selected
              ? palette.featureCardAccent
              : palette.featureCardBorder,
          width: highlight ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: palette.br,
        onTap: () {
          c.selectField(f.fieldId);
          canvas.onOpenField?.call(f.fieldId);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: canvas.compact ? 44 : 36),
          child: Row(
            children: [
              handle ?? const SizedBox(width: 8),
              Icon(styleIcon(f.fieldType), size: 15, color: palette.tabText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.label.isEmpty ? f.fieldKey : f.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: palette.tabActiveText),
                ),
              ),
              if (f.isList)
                _Tag(text: '[ ]', tooltip: l10n.tplList, palette: palette),
              if (f.isRequired)
                _Tag(text: '*', tooltip: l10n.tplRequired, palette: palette),
              // DESIGN §10.1: a list of a category with a Level table.
              if (f.fieldType == FieldType.relation &&
                  f.isList &&
                  c.schema.categories.any(
                    (t) =>
                        (f.validation.allowedTypes?.contains(t.slug) ??
                            false) &&
                        t.fields.any(
                          (x) => x.fieldType == FieldType.progressionTable,
                        ),
                  ))
                _Tag(
                  text: l10n.tplLevelListBadge,
                  tooltip: l10n.tplLevelListBadgeHint,
                  palette: palette,
                ),
              if (f.visibility != FieldVisibility.shared)
                Tooltip(
                  message: f.visibility == FieldVisibility.dmOnly
                      ? l10n.tplVisDm
                      : l10n.tplVisPrivate,
                  child: Icon(
                    Icons.visibility_off_outlined,
                    size: 14,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              if (legacy)
                _Tag(
                  text: l10n.tplLegacyBadge,
                  tooltip: l10n.tplLegacyHint,
                  palette: palette,
                ),
              if (c.presetById(f.presetId) case final p?)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: l10n.tplBoundTo(p.label),
                    child: Icon(
                      Icons.bookmark,
                      size: 14,
                      color: palette.featureCardAccent,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );

    final feedback = Material(
      elevation: 6,
      borderRadius: palette.br,
      child: SizedBox(width: 220, child: tile(highlight: true)),
    );

    return DragTarget<TemplateDrag>(
      onAcceptWithDetails: (d) =>
          canvas._drop(context, d.data, cat, f.groupId, f.fieldId),
      builder: (context, candidates, _) => LongPressDraggable<TemplateDrag>(
        data: TemplateDrag.field(f.fieldId),
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.4, child: tile(highlight: false)),
        child: tile(
          highlight: candidates.isNotEmpty,
          handle: Draggable<TemplateDrag>(
            data: TemplateDrag.field(f.fieldId),
            feedback: feedback,
            child: Tooltip(
              message: l10n.tplDragHandle,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  // As tall as the tile; long press on the tile is the touch
                  // alternative.
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: canvas.compact ? 13 : 9,
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.tooltip,
    required this.palette,
  });

  final String text;
  final String tooltip;
  final DmToolColors palette;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.sidebarLabelSecondary,
        ),
      ),
    ),
  );
}
