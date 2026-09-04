import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/template_mechanics.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/banner_metrics.dart';

/// Template kütüphanesi. Built-in şema read-only (View + Copy); kullanıcı
/// template'leri yaratılabilir, kopyalanabilir, düzenlenebilir, silinebilir.
///
/// **Built-in dışındaki template'lerde otomatik mekanik çalışmaz** — kart
/// üzerinde rozetle belirtilir; bkz. [templateIdHasMechanics].
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final templatesAsync = ref.watch(allTemplatesProvider);
    final templates = templatesAsync.valueOrNull ?? const <WorldSchema>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCardMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createBlank(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New template'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'The built-in template is read-only and the only one that runs '
                'automatic mechanics. Copies and new templates are pure data — '
                'fields render, values are entered by hand, nothing resolves.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (templatesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (templates.isEmpty)
                _EmptyCard(palette: palette)
              else
                ...templates.map(
                  (schema) => _TemplateTile(
                    schema: schema,
                    palette: palette,
                    onOpen: () => context.push('/template/edit', extra: schema),
                    onCopy: () => _copy(context, ref, schema),
                    onRename: () => _rename(context, ref, schema),
                    onDelete: () => _delete(context, ref, schema),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBlank(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, 'New template', 'My template');
    if (name == null || !context.mounted) return;
    final schema = await ref.read(templateLibraryProvider).createBlank(name);
    if (!context.mounted) return;
    context.push('/template/edit', extra: schema);
  }

  Future<void> _copy(
      BuildContext context, WidgetRef ref, WorldSchema source) async {
    final name =
        await _promptName(context, 'Copy template', '${source.name} (copy)');
    if (name == null || !context.mounted) return;
    final copy = await ref.read(templateLibraryProvider).copyFrom(source, name);
    if (!context.mounted) return;
    context.push('/template/edit', extra: copy);
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, WorldSchema schema) async {
    final name = await _promptName(context, 'Rename template', schema.name);
    if (name == null) return;
    await ref.read(templateLibraryProvider).rename(schema, name);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, WorldSchema schema) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${schema.name}"?'),
        content: const Text(
          'Worlds already created from this template keep their own copy of '
          'the schema and are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateLibraryProvider).delete(schema.schemaId);
  }

  Future<String?> _promptName(
      BuildContext context, String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return (name == null || name.isEmpty) ? null : name;
  }
}

class _EmptyCard extends StatelessWidget {
  final DmToolColors palette;

  const _EmptyCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Center(
        child: Text(
          'No templates available.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.schema,
    required this.palette,
    required this.onOpen,
    required this.onCopy,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalFields = schema.categories.fold<int>(
      0,
      (sum, c) => sum + c.fields.length,
    );
    final hasMechanics = schemaHasMechanics(schema);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner cover (built-in D&D 5e template art); collapses if the
          // asset is missing. Custom templates ship no art.
          if (hasMechanics)
            AspectRatio(
              aspectRatio: kBannerCoverAspect,
              child: Image.asset(
                'assets/first_party/banners/dnd5e-template.jpg',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              schema.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.tabActiveText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Badge(
                            label: hasMechanics ? 'Built-in' : 'No automation',
                            palette: palette,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${schema.categories.length} categories · $totalFields fields',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.sidebarLabelSecondary,
                        ),
                      ),
                      if (schema.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          schema.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.sidebarLabelSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: Icon(
                    hasMechanics ? Icons.visibility : Icons.edit,
                    size: 16,
                  ),
                  label: Text(hasMechanics ? 'View' : 'Edit'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    switch (v) {
                      case 'copy':
                        onCopy();
                      case 'rename':
                        onRename();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                    if (!hasMechanics) ...[
                      const PopupMenuItem(
                          value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final DmToolColors palette;

  const _Badge({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
      ),
    );
  }
}
