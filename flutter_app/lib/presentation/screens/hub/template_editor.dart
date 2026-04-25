import 'package:flutter/material.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';

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

  WorldSchema get _schema => widget.initial;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final categories = _schema.categories;

    if (categories.isEmpty) {
      return Center(
        child: Text(
          'This template has no categories.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    final selectedIndex = _selectedIndex.clamp(0, categories.length - 1);
    final selected = categories[selectedIndex];

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Container(
            color: palette.sidebarFilterBg,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = i == selectedIndex;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor:
                      palette.featureCardAccent.withValues(alpha: 0.15),
                  title: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: palette.tabActiveText,
                    ),
                  ),
                  subtitle: Text(
                    '${cat.fields.length} fields',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                  onTap: () => setState(() => _selectedIndex = i),
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _CategoryInspector(category: selected, palette: palette),
        ),
      ],
    );
  }
}

class _CategoryInspector extends StatelessWidget {
  final EntityCategorySchema category;
  final DmToolColors palette;

  const _CategoryInspector({required this.category, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
            'Fields (${category.fields.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 8),
          ...category.fields.map((f) => _FieldRow(field: f, palette: palette)),
          if (category.fieldGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Groups (${category.fieldGroups.length})',
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
                  '• ${g.name}  (${g.gridColumns} col)',
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

  const _FieldRow({required this.field, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              field.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.tabActiveText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              field.fieldKey,
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              field.fieldType.name + (field.isList ? ' (list)' : ''),
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          if (field.isRequired)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'required',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.dangerBtnBg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
