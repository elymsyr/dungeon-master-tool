import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import 'template_editor.dart';

class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  String? _mode;
  WorldSchema? _activeSchema;
  final List<WorldSchema> _customTemplates = [];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final defaultSchema = generateDefaultDnd5eSchema();

    if (_mode == 'view' && _activeSchema != null) {
      return TemplateEditor(
        initial: _activeSchema,
        readOnly: true,
        onBack: () => setState(() { _mode = null; _activeSchema = null; }),
      );
    }

    if (_mode == 'edit') {
      return TemplateEditor(
        initial: _activeSchema,
        readOnly: false,
        onBack: () => setState(() { _mode = null; _activeSchema = null; }),
        onSave: (schema) {
          setState(() {
            final idx = _customTemplates.indexWhere((t) => t.schemaId == schema.schemaId);
            if (idx >= 0) {
              _customTemplates[idx] = schema;
            } else {
              _customTemplates.add(schema);
            }
            _mode = null;
            _activeSchema = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template saved')),
          );
        },
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

              _TemplateCard(
                schema: defaultSchema,
                palette: palette,
                onTap: () => setState(() { _mode = 'view'; _activeSchema = defaultSchema; }),
              ),

              ..._customTemplates.map((schema) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TemplateCard(
                  schema: schema,
                  palette: palette,
                  isCustom: true,
                  onTap: () => setState(() { _mode = 'edit'; _activeSchema = schema; }),
                ),
              )),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() { _mode = 'edit'; _activeSchema = null; }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Empty'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCopyFromDialog(context, palette, defaultSchema),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy From...'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCopyFromDialog(BuildContext context, DmToolColors palette, WorldSchema defaultSchema) {
    final allTemplates = [defaultSchema, ..._customTemplates];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy From Template'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allTemplates.length,
            itemBuilder: (_, i) {
              final t = allTemplates[i];
              return ListTile(
                leading: Icon(Icons.description, color: palette.featureCardAccent),
                title: Text(t.name),
                subtitle: Text('${t.categories.length} categories'),
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now().toUtc().toIso8601String();
                  final newId = const Uuid().v4();
                  final copy = t.copyWith(
                    schemaId: newId,
                    name: '${t.name} (Copy)',
                    createdAt: now,
                    updatedAt: now,
                    categories: t.categories.map((c) => c.copyWith(
                      categoryId: const Uuid().v4(),
                      schemaId: newId,
                      isBuiltin: false,
                      fields: c.fields.map((f) => f.copyWith(
                        fieldId: const Uuid().v4(),
                        isBuiltin: false,
                      )).toList(),
                    )).toList(),
                  );
                  setState(() { _mode = 'edit'; _activeSchema = copy; });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final VoidCallback onTap;
  final bool isCustom;

  const _TemplateCard({required this.schema, required this.palette, required this.onTap, this.isCustom = false});

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
