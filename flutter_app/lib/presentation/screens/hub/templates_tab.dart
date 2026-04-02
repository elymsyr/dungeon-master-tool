import 'package:flutter/material.dart';

import '../../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';

class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  WorldSchema? _selectedTemplate;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final defaultSchema = generateDefaultDnd5eSchema();

    if (_selectedTemplate != null) {
      return _TemplateDetail(
        schema: _selectedTemplate!,
        palette: palette,
        onBack: () => setState(() => _selectedTemplate = null),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Templates', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 4),
              Text('World templates define entity categories and their fields.', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              // Default D&D 5e template
              _TemplateCard(
                schema: defaultSchema,
                palette: palette,
                onTap: () => setState(() => _selectedTemplate = defaultSchema),
              ),

              const SizedBox(height: 16),

              // Create template butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Template creation coming soon')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Template'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Template kart özeti.
class _TemplateCard extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _TemplateCard({required this.schema, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final totalFields = schema.categories.fold<int>(0, (sum, c) => sum + c.fields.length);

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.description, size: 36, color: palette.featureCardAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schema.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  const SizedBox(height: 2),
                  Text(schema.description, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    '${schema.categories.length} categories  ·  $totalFields fields  ·  v${schema.version}',
                    style: TextStyle(fontSize: 11, color: palette.tabText),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.tabText),
          ],
        ),
      ),
    );
  }
}

/// Template detay — kategoriler + alanları expandable listesi.
class _TemplateDetail extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final VoidCallback onBack;

  const _TemplateDetail({required this.schema, required this.palette, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border(bottom: BorderSide(color: palette.featureCardBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: onBack,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Icon(Icons.description, size: 20, color: palette.featureCardAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(schema.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              ),
              Text('v${schema.version}', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ),

        // Kategori listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schema.categories.length,
            itemBuilder: (context, index) {
              final cat = schema.categories[index];
              final color = _parseColor(cat.color);

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: ExpansionTile(
                  leading: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  title: Text(cat.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                  subtitle: Text(
                    '${cat.fields.length} fields',
                    style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: cat.fields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Icon(_fieldTypeIcon(field.fieldType), size: 14, color: palette.tabText),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(field.label, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _fieldTypeName(field.fieldType),
                              style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                            ),
                          ),
                          if (field.validation.allowedValues != null)
                            Expanded(
                              flex: 3,
                              child: Text(
                                field.validation.allowedValues!.join(', '),
                                style: TextStyle(fontSize: 10, color: palette.tabText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (field.validation.allowedTypes != null)
                            Expanded(
                              flex: 3,
                              child: Text(
                                '→ ${field.validation.allowedTypes!.join(', ')}',
                                style: TextStyle(fontSize: 10, color: palette.featureCardAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _fieldTypeName(FieldType type) => switch (type) {
    FieldType.text => 'Text',
    FieldType.textarea => 'Text Area',
    FieldType.markdown => 'Markdown',
    FieldType.integer => 'Integer',
    FieldType.float_ => 'Float',
    FieldType.boolean_ => 'Boolean',
    FieldType.enum_ => 'Enum',
    FieldType.date => 'Date',
    FieldType.image => 'Image',
    FieldType.file => 'File',
    FieldType.relation => 'Relation',
    FieldType.tagList => 'Tags',
    FieldType.statBlock => 'Stat Block',
    FieldType.combatStats => 'Combat Stats',
    FieldType.actionList => 'Action List',
    FieldType.spellList => 'Spell List',
  };

  IconData _fieldTypeIcon(FieldType type) => switch (type) {
    FieldType.text || FieldType.textarea || FieldType.markdown => Icons.text_fields,
    FieldType.integer || FieldType.float_ => Icons.tag,
    FieldType.boolean_ => Icons.check_box_outlined,
    FieldType.enum_ => Icons.list,
    FieldType.date => Icons.calendar_today,
    FieldType.image => Icons.image,
    FieldType.file => Icons.attach_file,
    FieldType.relation => Icons.link,
    FieldType.tagList => Icons.label,
    FieldType.statBlock => Icons.casino,
    FieldType.combatStats => Icons.shield,
    FieldType.actionList => Icons.bolt,
    FieldType.spellList => Icons.auto_fix_high,
  };

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
