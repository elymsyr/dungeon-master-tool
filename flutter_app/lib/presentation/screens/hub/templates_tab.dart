import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import 'template_editor.dart';

/// User's pick from the "save existing template" prompt.
enum _SaveChoice { update, saveAsNew, cancel }

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
    final builtinAsync = ref.watch(builtinTemplateProvider);
    final customTemplatesAsync = ref.watch(customTemplatesProvider);

    // view mode kaldırıldı — built-in dahil tüm template'ler düzenlenebilir

    if (_mode == 'edit') {
      return TemplateEditor(
        initial: _activeSchema,
        readOnly: false,
        onBack: () => setState(() { _mode = null; _activeSchema = null; }),
        onSave: (schema) async {
          // Existing template? → ask whether to update in place or fork as
          // a new template. New templates (no _activeSchema) skip the prompt.
          final isExisting = _activeSchema != null;
          if (isExisting) {
            final choice = await _showUpdateOrForkDialog(context);
            if (choice == null || choice == _SaveChoice.cancel) return;
            if (choice == _SaveChoice.saveAsNew) {
              final forked = _cloneAsNew(schema, '${schema.name} (v2)');
              await ref.read(templateLocalDsProvider).save(forked);
              ref.invalidate(builtinTemplateProvider);
              ref.invalidate(customTemplatesProvider);
              ref.invalidate(allTemplatesProvider);
              if (mounted) {
                setState(() { _mode = null; _activeSchema = null; });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved as new template: ${forked.name}')),
                );
              }
              return;
            }
            // _SaveChoice.update falls through to the in-place save below.
          }

          await ref.read(templateLocalDsProvider).save(schema);
          // Invalidate both — the saved file might be the built-in
          // (admin edit path) or a custom template, we don't need to
          // distinguish here.
          ref.invalidate(builtinTemplateProvider);
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

              // Built-in (default) template — loaded through the provider
              // so admin edits persist and no ghost copy appears.
              builtinAsync.when(
                data: (schema) => _TemplateCard(
                  schema: schema,
                  palette: palette,
                  onTap: () => setState(() { _mode = 'edit'; _activeSchema = schema; }),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
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
                        await ref.read(templateLocalDsProvider).moveToTrash(schema.schemaId, schema.name);
                        ref.invalidate(customTemplatesProvider);
                        ref.invalidate(allTemplatesProvider);
                        ref.invalidate(trashListProvider);
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
                      onPressed: builtinAsync.valueOrNull == null
                          ? null
                          : () => _showCopyFromDialog(
                              context, palette, builtinAsync.valueOrNull!),
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
                  final copy = _cloneAsNew(t, '${t.name} (Copy)');
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

  /// Prompts the user when saving an existing template, since the lazy
  /// template-sync flow will mark dependent campaigns as outdated on their
  /// next open. Returns the user's pick or null if they dismissed the
  /// dialog (treated as cancel).
  Future<_SaveChoice?> _showUpdateOrForkDialog(BuildContext context) {
    final l10n = L10n.of(context)!;
    return showDialog<_SaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.templateSaveTitle),
        content: Text(l10n.templateSaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveChoice.cancel),
            child: Text(l10n.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveChoice.saveAsNew),
            child: Text(l10n.templateSaveAsNew),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _SaveChoice.update),
            child: Text(l10n.templateSaveUpdate),
          ),
        ],
      ),
    );
  }

  /// Deep-clones a template with fresh UUIDs on every nested entity so the
  /// new template is fully independent of the source. Used by both the
  /// "Copy From Template" dialog and the "Save as New" save path.
  ///
  /// `originalHash` is explicitly cleared so the fork is treated as a
  /// brand-new lineage: `template_local_ds.save()` will lazy-init it from
  /// the fork's content on first save. Without this the fork would
  /// inherit the source's lineage and the lazy-sync flow would treat
  /// every dependent campaign as outdated against the wrong template.
  WorldSchema _cloneAsNew(WorldSchema t, String newName) {
    final now = DateTime.now().toUtc().toIso8601String();
    final newId = const Uuid().v4();
    return t.copyWith(
      schemaId: newId,
      name: newName,
      createdAt: now,
      updatedAt: now,
      originalHash: null,
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
                      title: const Text('Move to Trash'),
                      content: Text('Move "${schema.name}" to trash?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () { Navigator.pop(ctx); onDelete!(); },
                          style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
                          child: const Text('Move to Trash'),
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
