import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/template_edit.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../database/database_screen.dart' show parseHexColor;
import '../database/entity_card.dart'
    show EntityCardCollapsibleGroupCard, EntityCardSectionHeading;

/// An empty sample card of [category] drawn with the card's own pieces
/// (group heading, column rule, field widgets), editable like a new card
/// (V27). Nothing typed here is stored. Free templates have no built-in
/// layout rules, so no group is centred.
class TemplateCardPreview extends ConsumerWidget {
  const TemplateCardPreview({super.key, required this.category});

  final EntityCategorySchema category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final cols1 = isPhone(context);
    final shown = category.fields
        .where((f) => f.visibility != FieldVisibility.private_)
        .toSet();

    Widget fieldWidget(FieldSchema f) => FieldWidgetFactory.create(
      schema: f,
      value: f.defaultValue,
      readOnly: false,
      onChanged: (_) {},
      entities: const <String, Entity>{},
      ref: ref,
      entityFields: const {},
      entityName: l10n.tplPreviewSample,
    );

    Widget grid(List<FieldSchema> fields, int columns) {
      final cols = cols1 ? 1 : columns.clamp(1, 4);
      final rows = <List<FieldSchema>>[];
      var used = 0;
      for (final f in fields) {
        final span = f.gridColumnSpan.clamp(1, cols);
        if (rows.isEmpty || used + span > cols) {
          rows.add([]);
          used = 0;
        }
        rows.last.add(f);
        used += span;
      }
      int spanOf(List<FieldSchema> row) =>
          row.fold(0, (s, f) => s + f.gridColumnSpan.clamp(1, cols));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, f) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    flex: f.gridColumnSpan.clamp(1, cols),
                    child: fieldWidget(f),
                  ),
                ],
                // A short row keeps its cells at full-row column width.
                if (spanOf(row) < cols) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: cols - spanOf(row),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      );
    }

    final ungrouped = fieldsIn(category, null).where(shown.contains).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            borderRadius: palette.br,
            border: Border(
              left: BorderSide(color: parseHexColor(category.color), width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tplPreviewSample,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                category.name,
                style: TextStyle(color: palette.sidebarLabelSecondary),
              ),
              const SizedBox(height: 16),
              if (ungrouped.isNotEmpty) ...[
                EntityCardSectionHeading(
                  title: l10n.propertiesTitle,
                  palette: palette,
                ),
                const SizedBox(height: 8),
                for (final f in ungrouped) fieldWidget(f),
                const SizedBox(height: 16),
              ],
              for (final g in sortedGroups(category))
                if (fieldsIn(category, g.groupId).any(shown.contains)) ...[
                  EntityCardCollapsibleGroupCard(
                    key: ValueKey('${g.groupId}-${g.isCollapsed}'),
                    group: g,
                    palette: palette,
                    child: grid(
                      fieldsIn(
                        category,
                        g.groupId,
                      ).where(shown.contains).toList(),
                      g.gridColumns,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
