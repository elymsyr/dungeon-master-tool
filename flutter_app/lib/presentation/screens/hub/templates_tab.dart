import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/close_guard.dart';
import '../../widgets/marketplace_panel.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';
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
  final _nameController = TextEditingController();
  int _selectedIndex = -1;
  /// null = "(Empty — start from scratch)"; otherwise schemaId to clone from.
  String? _copyFromId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final templatesAsync = ref.watch(allTemplatesProvider);

    if (_mode == 'edit') {
      return TemplateEditor(
        initial: _activeSchema,
        readOnly: false,
        onBack: () async {
          final ok = await confirmCloseUnconditional(
            context: context,
            title: 'Close template editor?',
          );
          if (ok && mounted) {
            setState(() { _mode = null; _activeSchema = null; });
          }
        },
        onSave: (schema) async {
          // Existing template? → ask whether to update in place or fork as
          // a new template. New templates (no _activeSchema) skip the prompt.
          final isExisting = _activeSchema != null;
          if (isExisting) {
            final choice = await _showUpdateOrForkDialog(context);
            if (choice == null || choice == _SaveChoice.cancel) return;
            if (choice == _SaveChoice.saveAsNew) {
              final forked = _cloneAsNew(schema, '${schema.name} (v2)');
              await withLoading(
                ref.read(globalLoadingProvider.notifier),
                'save-template-new',
                'Saving template "${forked.name}"...',
                () => ref.read(templateLocalDsProvider).save(forked),
              );
              ref.invalidate(allTemplatesProvider);
              if (context.mounted) {
                setState(() { _mode = null; _activeSchema = null; });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved as new template: ${forked.name}')),
                );
              }
              return;
            }
            // _SaveChoice.update falls through to the in-place save below.
          }

          await withLoading(
            ref.read(globalLoadingProvider.notifier),
            'save-template',
            'Saving template "${schema.name}"...',
            () => ref.read(templateLocalDsProvider).save(schema),
          );
          ref.invalidate(allTemplatesProvider);
          if (context.mounted) {
            setState(() { _mode = null; _activeSchema = null; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template saved')),
            );
          }
        },
      );
    }

    final combined = templatesAsync.valueOrNull ?? const <WorldSchema>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Templates',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.tabActiveText)),
              const SizedBox(height: 4),
              Text('World templates define entity categories and their fields.',
                  style: TextStyle(
                      fontSize: 12, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              if (templatesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (combined.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    borderRadius: palette.br,
                    border: Border.all(color: palette.featureCardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No templates found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: palette.sidebarLabelSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: combined.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final schema = combined[index];
                    final isSelected = index == _selectedIndex;
                    final totalFields = schema.categories
                        .fold<int>(0, (sum, c) => sum + c.fields.length);
                    final meta = schema.metadata;
                    return InkWell(
                      borderRadius: palette.br,
                      onTap: () => setState(() => _selectedIndex = index),
                      onDoubleTap: () => _loadTemplate(schema),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? palette.featureCardAccent
                                  .withValues(alpha: 0.1)
                              : palette.featureCardBg,
                          borderRadius: palette.br,
                          border: Border.all(
                            color: isSelected
                                ? palette.featureCardAccent
                                : palette.featureCardBorder,
                          ),
                        ),
                        child: MetadataListTile(
                          icon: Icons.description,
                          name: schema.name,
                          subtitle:
                              '${schema.categories.length} cat · $totalFields fields · v${schema.version}',
                          description: schema.description.isNotEmpty
                              ? schema.description
                              : ((meta['description'] as String?) ?? ''),
                          tags: ((meta['tags'] as List?) ?? const [])
                              .whereType<String>()
                              .toList(),
                          coverImagePath:
                              (meta['cover_image_path'] as String?) ?? '',
                          isSelected: isSelected,
                          palette: palette,
                          layout: MetadataTileLayout.topBanner,
                          onSettings: () =>
                              _showTemplateSettings(schema, palette),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 12),

              // Load + Delete
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedIndex >= 0 &&
                              _selectedIndex < combined.length
                          ? () => _loadTemplate(combined[_selectedIndex])
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Load Template'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _canDelete(combined)
                        ? () => _deleteSelected(combined)
                        : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.dangerBtnBg,
                      foregroundColor: palette.dangerBtnText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Divider(color: palette.sidebarDivider),
              const SizedBox(height: 16),

              // Create New Template
              Text('Create New Template',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('tpl_copy_${combined.length}'),
                initialValue: _copyFromId,
                decoration: const InputDecoration(
                  labelText: 'Copy from (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('(Empty — start from scratch)',
                        style: TextStyle(fontSize: 12)),
                  ),
                  ...combined.map((t) => DropdownMenuItem<String?>(
                        value: t.schemaId,
                        child: Text(
                            '${t.name}  (${t.categories.length} cat)',
                            style: const TextStyle(fontSize: 12)),
                      )),
                ],
                onChanged: (id) => setState(() => _copyFromId = id),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(hintText: 'Template name'),
                      onSubmitted: (_) => _createTemplate(combined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _createTemplate(combined),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create'),
                    style: FilledButton.styleFrom(
                        backgroundColor: palette.successBtnBg,
                        foregroundColor: palette.successBtnText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canDelete(List<WorldSchema> combined) {
    return _selectedIndex >= 0 && _selectedIndex < combined.length;
  }

  void _loadTemplate(WorldSchema schema) {
    setState(() {
      _mode = 'edit';
      _activeSchema = schema;
    });
  }

  Future<void> _deleteSelected(List<WorldSchema> combined) async {
    if (!_canDelete(combined)) return;
    final schema = combined[_selectedIndex];
    final palette = Theme.of(context).extension<DmToolColors>()!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text('Move "${schema.name}" to trash?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(templateLocalDsProvider)
                  .moveToTrash(schema.schemaId, schema.name);
              await ref
                  .read(cloudBackupOperationProvider.notifier)
                  .deleteBackupByItem(schema.schemaId, 'template');
              ref.invalidate(allTemplatesProvider);
              ref.invalidate(trashListProvider);
              if (mounted) setState(() => _selectedIndex = -1);
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  void _createTemplate(List<WorldSchema> combined) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a template name')),
      );
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    WorldSchema schema;
    if (_copyFromId == null) {
      schema = WorldSchema(
        schemaId: const Uuid().v4(),
        name: name,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      final source =
          combined.where((t) => t.schemaId == _copyFromId).firstOrNull;
      if (source == null) return;
      schema = _cloneAsNew(source, name);
    }
    setState(() {
      _mode = 'edit';
      _activeSchema = schema;
      _nameController.clear();
      _copyFromId = null;
    });
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
  Future<void> _showTemplateSettings(
      WorldSchema schema, DmToolColors palette) async {
    final l10n = L10n.of(context)!;

    DateTime? localUpdatedAt;
    try {
      localUpdatedAt = DateTime.parse(schema.updatedAt);
    } catch (_) {
      localUpdatedAt = null;
    }

    // Mutable working copy.
    var workingName = schema.name;
    var workingDescription = schema.description;
    final meta = Map<String, dynamic>.from(schema.metadata);
    var workingTags = ((meta['tags'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    var workingCover = (meta['cover_image_path'] as String?) ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${schema.name} — Settings'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetadataEditorSection(
                    name: workingName,
                    description: workingDescription,
                    tags: workingTags,
                    coverImagePath: workingCover,
                    onNameChanged: (v) => workingName = v,
                    onDescriptionChanged: (v) => workingDescription = v,
                    onTagsChanged: (v) =>
                        setDialogState(() => workingTags = v),
                    onCoverChanged: (v) =>
                        setDialogState(() => workingCover = v),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: palette.featureCardBorder),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.description,
                          size: 16,
                          color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${schema.categories.length} categories  ·  v${schema.version}',
                          style: TextStyle(
                              fontSize: 13,
                              color: palette.tabActiveText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SaveInfoSection(
                    itemName: schema.name,
                    itemId: schema.schemaId,
                    type: 'template',
                    localUpdatedAt: localUpdatedAt,
                  ),
                  const SizedBox(height: 12),
                  MarketplacePanel(
                    itemType: 'template',
                    localId: schema.schemaId,
                    title: schema.name,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.btnCancel),
            ),
            FilledButton(
              onPressed: () async {
                final newMeta = Map<String, dynamic>.from(schema.metadata)
                  ..['cover_image_path'] = workingCover
                  ..['tags'] = workingTags;
                final updated = schema.copyWith(
                  name: workingName,
                  description: workingDescription,
                  metadata: newMeta,
                  updatedAt:
                      DateTime.now().toUtc().toIso8601String(),
                );
                try {
                  await ref.read(templateLocalDsProvider).save(updated);
                  ref.invalidate(allTemplatesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Save failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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

