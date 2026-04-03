import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import 'template_editor.dart';

class TemplatesTab extends ConsumerStatefulWidget {
  const TemplatesTab({super.key});

  @override
  ConsumerState<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<TemplatesTab> {
  String? _mode;
  WorldSchema? _activeSchema;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final defaultSchema = generateDefaultDnd5eSchema();
    final customTemplatesAsync = ref.watch(customTemplatesProvider);

    // view mode kaldırıldı — built-in dahil tüm template'ler düzenlenebilir

    if (_mode == 'edit') {
      return TemplateEditor(
        initial: _activeSchema,
        readOnly: false,
        onBack: () => setState(() { _mode = null; _activeSchema = null; }),
        onSave: (schema) async {
          await ref.read(templateLocalDsProvider).save(schema);
          ref.invalidate(customTemplatesProvider);
          ref.invalidate(allTemplatesProvider);
          if (mounted) {
            setState(() { _mode = null; _activeSchema = null; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template saved')),
            );
          }
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

              // Default template (editable)
              _TemplateCard(
                schema: defaultSchema,
                palette: palette,
                onTap: () => setState(() { _mode = 'edit'; _activeSchema = defaultSchema; }),
              ),

              // Custom templates
              customTemplatesAsync.when(
                data: (templates) => Column(
                  children: templates.map((schema) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _TemplateCard(
                      schema: schema,
                      palette: palette,
                      isCustom: true,
                      onTap: () => setState(() { _mode = 'edit'; _activeSchema = schema; }),
                      onDelete: () async {
                        await ref.read(templateLocalDsProvider).delete(schema.schemaId);
                        ref.invalidate(customTemplatesProvider);
                        ref.invalidate(allTemplatesProvider);
                      },
                    ),
                  )).toList(),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
              ),

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
    final customTemplates = ref.read(customTemplatesProvider).valueOrNull ?? [];
    final allTemplates = [defaultSchema, ...customTemplates];

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
  final VoidCallback? onDelete;

  const _TemplateCard({required this.schema, required this.palette, required this.onTap, this.isCustom = false, this.onDelete});

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
            Icon(Icons.description, size: 36, color: isCustom ? palette.tabIndicator : palette.featureCardAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(schema.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText))),
                      if (!isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: BorderRadius.circular(3)),
                          child: Text('Built-in', style: TextStyle(fontSize: 9, color: palette.tabText)),
                        ),
                    ],
                  ),
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
            if (isCustom && onDelete != null) ...[
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: palette.sidebarLabelSecondary),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Template'),
                      content: Text('Delete "${schema.name}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () { Navigator.pop(ctx); onDelete!(); },
                          style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
            Icon(Icons.chevron_right, color: palette.tabText),
          ],
        ),
      ),
    );
  }
}
