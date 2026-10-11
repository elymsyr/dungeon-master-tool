import 'package:flutter/material.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../l10n/app_localizations.dart';

/// Read-only template inspector. Walks a [WorldSchema] and renders its
/// categories, fields, and groups for browsing. The schema is no longer
/// user-editable — only the built-in D&D 5e template ships with the app.
class TemplateEditor extends StatefulWidget {
  final WorldSchema initial;

  const TemplateEditor({super.key, required this.initial});

  @override
  State<TemplateEditor> createState() => TemplateEditorState();
}

class TemplateEditorState extends State<TemplateEditor> {
  int _selectedIndex = 0;

  /// Narrow layouts show the category list first and the selected category
  /// on its own page; back returns to the list.
  bool _showDetail = false;

  WorldSchema get _schema => widget.initial;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final categories = _schema.categories;

    if (categories.isEmpty) {
      return Center(
        child: Text(
          L10n.of(context)!.templateNoCategories,
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    final selectedIndex = _selectedIndex.clamp(0, categories.length - 1);
    final selected = categories[selectedIndex];

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      Widget list() => ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSelected = !compact && i == selectedIndex;
              return ListTile(
                dense: !compact,
                selected: isSelected,
                selectedTileColor:
                    palette.featureCardAccent.withValues(alpha: 0.15),
                title: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: compact ? 15 : 13,
                    fontWeight: FontWeight.w500,
                    color: palette.tabActiveText,
                  ),
                ),
                subtitle: Text(
                  L10n.of(context)!.templateFieldCount('${cat.fields.length}'),
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
                trailing: compact ? const Icon(Icons.chevron_right) : null,
                onTap: () => setState(() {
                  _selectedIndex = i;
                  _showDetail = true;
                }),
              );
            },
          );

      if (!compact) {
        return Row(
          children: [
            SizedBox(
              width: 240,
              // Material, not a colored Container: ListTile paints its
              // selection on the nearest Material, which a ColoredBox hides.
              child: Material(color: palette.sidebarFilterBg, child: list()),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _CategoryInspector(
                  category: selected, palette: palette, compact: false),
            ),
          ],
        );
      }

      return PopScope(
        canPop: !_showDetail,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _showDetail = false);
        },
        child: !_showDetail
            ? list()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showDetail = false),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(L10n.of(context)!.templateCategoriesBack),
                    ),
                  ),
                  Expanded(
                    child: _CategoryInspector(
                        category: selected, palette: palette, compact: true),
                  ),
                ],
              ),
      );
    });
  }
}

class _CategoryInspector extends StatelessWidget {
  final EntityCategorySchema category;
  final DmToolColors palette;
  final bool compact;

  const _CategoryInspector({
    required this.category,
    required this.palette,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'slug: ${category.slug}',
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            L10n.of(context)!.templateFieldsHeading('${category.fields.length}'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 8),
          ...category.fields.map(
              (f) => _FieldRow(field: f, palette: palette, compact: compact)),
          if (category.fieldGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              L10n.of(context)!.templateGroupsHeading('${category.fieldGroups.length}'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 8),
            ...category.fieldGroups.map(
              (g) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  L10n.of(context)!.templateGroupLine(g.name, '${g.gridColumns}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final FieldSchema field;
  final DmToolColors palette;
  final bool compact;

  const _FieldRow({
    required this.field,
    required this.palette,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      field.label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: palette.tabActiveText,
      ),
    );
    final key = Text(
      field.fieldKey,
      style: TextStyle(
        fontSize: 11,
        color: palette.sidebarLabelSecondary,
        fontFamily: 'monospace',
      ),
    );
    final type = Text(
      field.fieldType.name + (field.isList ? ' (list)' : ''),
      style: TextStyle(
        fontSize: 11,
        color: palette.sidebarLabelSecondary,
      ),
    );
    final required = field.isRequired
        ? Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              L10n.of(context)!.templateFieldRequired,
              style: TextStyle(
                fontSize: 10,
                color: palette.dangerBtnBg,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : null;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: label), ?required]),
            const SizedBox(height: 2),
            Wrap(spacing: 8, children: [key, type]),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: label),
          Expanded(flex: 3, child: key),
          Expanded(flex: 2, child: type),
          ?required,
        ],
      ),
    );
  }
}
