import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/banner_metrics.dart';

/// Hub Templates tab — the user-facing **Template library** (roadmap §1.4 /
/// PR-1.4). Mirrors the `packages_tab.dart` pattern:
///
/// * The **built-in** D&D 5e template (served read-only from
///   [BuiltinTemplateLoader]) sorts first. It exposes **View** + **Copy** only;
///   it can never be renamed, edited in place, or deleted. A persistent banner
///   tells the user to make a copy to edit (roadmap §1.5).
/// * **User copies** follow (newest-edited first) and expose **Edit**,
///   **Rename**, and **Delete**.
///
/// The list is driven by [templateLibraryProvider] (`[builtin] + userTemplates`)
/// and all mutations go through [templateRepositoryProvider], which only ever
/// touches the `templates` table — the built-in asset is untouchable by design.
///
/// The action area of each tile is responsive: on wide tiles (tablet/desktop)
/// every action shows as an inline button; on narrow tiles (phone) the primary
/// action stays inline and the rest collapse into an overflow menu. The full
/// responsive *editor* shell is a later step (PR-1.5); this surface is the
/// library CRUD only.
class TemplatesTab extends ConsumerStatefulWidget {
  const TemplatesTab({super.key});

  @override
  ConsumerState<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<TemplatesTab> {
  bool _isBuiltin(WorldSchema schema) =>
      schema.schemaId == builtinDnd5eV3SchemaId;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final templatesAsync = ref.watch(templateLibraryProvider);
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
              Text(
                'Templates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.tabActiveText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The built-in schema is read-only — copy it to make your own '
                'editable template.',
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
              else if (templatesAsync.hasError)
                _MessageCard(
                  palette: palette,
                  message: 'Failed to load templates: ${templatesAsync.error}',
                )
              else if (templates.isEmpty)
                _MessageCard(
                  palette: palette,
                  message: 'No templates available.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final schema = templates[index];
                    final isBuiltin = _isBuiltin(schema);
                    return _TemplateTile(
                      schema: schema,
                      palette: palette,
                      isBuiltin: isBuiltin,
                      onView: () => _openEditor(schema),
                      onCopy: () => _copyTemplate(schema),
                      onRename: isBuiltin ? null : () => _renameTemplate(schema),
                      onDelete: isBuiltin ? null : () => _deleteTemplate(schema),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(WorldSchema schema) {
    context.push('/template/edit', extra: schema);
  }

  /// Suggests a non-colliding "(Copy)" name. Mirrors `_copyPackage()`
  /// (`packages_tab.dart:437`): start at "<name> (Copy)", then append
  /// " (Copy 2)", " (Copy 3)", … until the name is free across the *whole*
  /// library (built-in name included, so a copy never shadows it).
  String _suggestCopyName(String base, Set<String> existing) {
    var candidate = '$base (Copy)';
    var n = 2;
    while (existing.contains(candidate)) {
      candidate = '$base (Copy $n)';
      n++;
    }
    return candidate;
  }

  Future<void> _copyTemplate(WorldSchema source) async {
    final repo = ref.read(templateRepositoryProvider);
    final library =
        ref.read(templateLibraryProvider).valueOrNull ?? const <WorldSchema>[];
    final existingNames = library.map((t) => t.name).toSet();

    final controller =
        TextEditingController(text: _suggestCopyName(source.name, existingNames));
    final focusNode = FocusNode();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (focusNode.canRequestFocus) focusNode.requestFocus();
    });

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy Template'),
        content: TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'New template name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    controller.dispose();
    focusNode.dispose();

    if (newName == null || newName.isEmpty) return;
    // Collision check against user templates (the built-in name lives outside
    // the table, but the suggestion already steps around it).
    if (existingNames.contains(newName) || await repo.nameExists(newName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "$newName" already exists')),
        );
      }
      return;
    }

    try {
      await repo.copy(source: source, newName: newName);
      ref.invalidate(templateLibraryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied "${source.name}" → "$newName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: $e')),
        );
      }
    }
  }

  Future<void> _renameTemplate(WorldSchema source) async {
    final repo = ref.read(templateRepositoryProvider);
    final library =
        ref.read(templateLibraryProvider).valueOrNull ?? const <WorldSchema>[];
    // Names already taken by *other* templates (excluding this one).
    final otherNames = library
        .where((t) => t.schemaId != source.schemaId)
        .map((t) => t.name)
        .toSet();

    final controller = TextEditingController(text: source.name);
    final focusNode = FocusNode();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (focusNode.canRequestFocus) focusNode.requestFocus();
    });

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Template'),
        content: TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Template name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    focusNode.dispose();

    if (newName == null || newName.isEmpty || newName == source.name) return;
    if (otherNames.contains(newName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "$newName" already exists')),
        );
      }
      return;
    }

    try {
      await repo.rename(source.schemaId, newName);
      ref.invalidate(templateLibraryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to "$newName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(WorldSchema source) async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Delete "${source.name}"? Worlds and packages already created from '
          'this template keep their own embedded copy and are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(templateRepositoryProvider).delete(source.schemaId);
      ref.invalidate(templateLibraryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${source.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

class _MessageCard extends StatelessWidget {
  final DmToolColors palette;
  final String message;

  const _MessageCard({required this.palette, required this.message});

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
          message,
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
  final bool isBuiltin;
  final VoidCallback onView;
  final VoidCallback onCopy;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _TemplateTile({
    required this.schema,
    required this.palette,
    required this.isBuiltin,
    required this.onView,
    required this.onCopy,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalFields = schema.categories.fold<int>(
      0,
      (sum, c) => sum + c.fields.length,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner cover (built-in only ships dedicated art); collapses if the
          // asset is missing so user copies don't show a broken box.
          if (isBuiltin)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isBuiltin ? Icons.auto_stories : Icons.dashboard_customize,
                      size: 20,
                      color: palette.sidebarLabelSecondary,
                    ),
                    const SizedBox(width: 10),
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
                              if (isBuiltin) ...[
                                const SizedBox(width: 8),
                                _ReadOnlyBadge(palette: palette),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${schema.categories.length} categories · '
                            '$totalFields fields',
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
                  ],
                ),
                if (isBuiltin) ...[
                  const SizedBox(height: 10),
                  _CopyToEditBanner(palette: palette, onCopy: onCopy),
                ],
                const SizedBox(height: 12),
                _TileActions(
                  palette: palette,
                  isBuiltin: isBuiltin,
                  onView: onView,
                  onCopy: onCopy,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  final DmToolColors palette;

  const _ReadOnlyBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: palette.featureCardBorder.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Read-only',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: palette.sidebarLabelSecondary,
        ),
      ),
    );
  }
}

/// The "Built-in template — make a copy to edit" strip (roadmap §1.5) with an
/// inline Copy button.
class _CopyToEditBanner extends StatelessWidget {
  final DmToolColors palette;
  final VoidCallback onCopy;

  const _CopyToEditBanner({required this.palette, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.08),
        borderRadius: palette.br,
        border: Border.all(
          color: palette.featureCardAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: palette.featureCardAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Built-in template — make a copy to edit.',
              style: TextStyle(
                fontSize: 11,
                color: palette.tabActiveText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy, size: 14),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 32),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive action row. Wide tiles (≥ 360 logical px of action room) show
/// every action inline; narrow tiles keep the primary action inline and fold
/// the rest into an overflow menu so the footer never overflows on phones.
class _TileActions extends StatelessWidget {
  final DmToolColors palette;
  final bool isBuiltin;
  final VoidCallback onView;
  final VoidCallback onCopy;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _TileActions({
    required this.palette,
    required this.isBuiltin,
    required this.onView,
    required this.onCopy,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabel = isBuiltin ? 'View' : 'Edit';
    final primaryIcon = isBuiltin ? Icons.visibility : Icons.edit_outlined;

    // Secondary actions, in roadmap order (Copy · Rename · Delete).
    final secondary = <_TileAction>[
      _TileAction(
        label: 'Copy',
        icon: Icons.content_copy,
        onTap: onCopy,
      ),
      if (onRename != null)
        _TileAction(
          label: 'Rename',
          icon: Icons.drive_file_rename_outline,
          onTap: onRename!,
        ),
      if (onDelete != null)
        _TileAction(
          label: 'Delete',
          icon: Icons.delete_outline,
          onTap: onDelete!,
          danger: true,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Inline only when there's comfortable room for the primary button
        // plus every secondary button; otherwise fold the secondaries into an
        // overflow menu so the footer never overflows on phones.
        final wide = constraints.maxWidth >= 110 + secondary.length * 116;

        final primaryBtn = FilledButton.icon(
          onPressed: onView,
          icon: Icon(primaryIcon, size: 16),
          label: Text(primaryLabel),
        );

        if (wide) {
          return Row(
            children: [
              primaryBtn,
              const Spacer(),
              for (final a in secondary) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: a.onTap,
                  icon: Icon(a.icon, size: 16),
                  label: Text(a.label),
                  style: a.danger
                      ? OutlinedButton.styleFrom(
                          foregroundColor: palette.dangerBtnBg,
                        )
                      : null,
                ),
              ],
            ],
          );
        }

        // Narrow: primary inline + overflow menu for the rest.
        return Row(
          children: [
            Expanded(child: primaryBtn),
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More actions',
              onSelected: (i) => secondary[i].onTap(),
              itemBuilder: (context) => [
                for (var i = 0; i < secondary.length; i++)
                  PopupMenuItem<int>(
                    value: i,
                    child: Row(
                      children: [
                        Icon(
                          secondary[i].icon,
                          size: 18,
                          color: secondary[i].danger
                              ? palette.dangerBtnBg
                              : palette.sidebarLabelSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          secondary[i].label,
                          style: TextStyle(
                            color: secondary[i].danger
                                ? palette.dangerBtnBg
                                : palette.tabActiveText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Lightweight descriptor for a secondary tile action.
class _TileAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _TileAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
}
