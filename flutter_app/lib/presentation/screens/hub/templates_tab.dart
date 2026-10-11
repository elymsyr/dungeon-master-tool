import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/template_provider.dart';
import '../../../application/services/content_transfer/content_item.dart';
import '../../../application/services/local_media_localizer.dart';
import '../../../core/utils/error_format.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/free_template.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/banner_metrics.dart';
import '../../widgets/compactable_button.dart';
import '../../widgets/content_archive_menu.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../l10n/app_localizations.dart';

/// Templates library, laid out like the Worlds tab: tap selects, double tap
/// opens; View · Copy · Transfer · Delete act on the selection
/// (docs/free-template/ROADMAP.md, Faz 1). The built-in template can only be
/// viewed and copied. Editing arrives in Faz 2.
class TemplatesTab extends ConsumerStatefulWidget {
  const TemplatesTab({super.key});

  @override
  ConsumerState<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<TemplatesTab> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final builtins =
        ref.watch(allTemplatesProvider).valueOrNull ?? const <WorldSchema>[];
    final mineAsync = ref.watch(userTemplatesProvider);
    final mine = mineAsync.valueOrNull ?? const <WorldSchema>[];
    final all = [...builtins, ...mine];
    final selected = all.where((t) => t.schemaId == _selectedId).firstOrNull;
    final own = selected != null && isFreeTemplate(selected);

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
                      l10n.tabTemplates,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: l10n.templateNewEmpty,
                    child: OutlinedButton(
                      onPressed: () => _createEmpty(context, ref),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        minimumSize: const Size(32, 32),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Icon(Icons.add, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.templatesSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              const SizedBox(height: 16),
              for (final schema in all) ...[
                _TemplateCard(
                  key: ValueKey(schema.schemaId),
                  schema: schema,
                  palette: palette,
                  isSelected: schema.schemaId == _selectedId,
                  onTap: () => setState(() => _selectedId = schema.schemaId),
                  onOpen: () => _view(context, schema),
                  onSettings: isFreeTemplate(schema)
                      ? () => _settings(context, ref, schema)
                      : null,
                ),
                const SizedBox(height: 4),
              ],
              if (mineAsync.hasError)
                _HintCard(
                  palette: palette,
                  text: l10n.templateActionFailed(
                    formatError(mineAsync.error!),
                  ),
                )
              else if (mineAsync.hasValue && mine.isEmpty)
                _HintCard(palette: palette, text: l10n.templateMineEmpty),
              const SizedBox(height: 12),

              // View + Copy + Transfer + Delete, as on the Worlds tab. The
              // first button becomes "Edit" for own templates in Faz 2.
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => _view(context, selected),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(l10n.btnView),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompactableButton(
                    onPressed: selected == null
                        ? null
                        : () => _copy(context, ref, selected),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: l10n.templateActionCopy,
                  ),
                  const SizedBox(width: 8),
                  ContentArchiveMenu(
                    type: ContentItemType.template,
                    selectedId: own ? selected.schemaId : null,
                    selectedName: own ? selected.name : null,
                  ),
                  const SizedBox(width: 8),
                  CompactableButton(
                    filled: true,
                    onPressed: own
                        ? () => _delete(context, ref, selected)
                        : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: l10n.btnDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.dangerBtnBg,
                      foregroundColor: palette.dangerBtnText,
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

  void _view(BuildContext context, WorldSchema schema) {
    context.push('/template/edit', extra: schema);
  }

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref,
    WorldSchema source,
  ) async {
    final l10n = L10n.of(context)!;
    final name = await _askName(
      context,
      title: l10n.templateCopyTitle,
      initial: l10n.templateCopyName(source.name),
      confirm: l10n.templateActionCopy,
    );
    if (name == null || !context.mounted) return;
    await _run(
      context,
      l10n.templateCreated(name),
      () => ref.read(userTemplatesProvider.notifier).copy(source, name),
    );
  }

  Future<void> _createEmpty(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context)!;
    final name = await _askName(
      context,
      title: l10n.templateNewEmpty,
      initial: l10n.templateDefaultName,
      confirm: l10n.btnCreate,
      helper: l10n.templateNewEmptyHint,
    );
    if (name == null || !context.mounted) return;
    await _run(
      context,
      l10n.templateCreated(name),
      () => ref
          .read(userTemplatesProvider.notifier)
          .createEmpty(name, playerCardName: l10n.templatePlayerCardName),
    );
  }

  /// World-style settings: name, description, tags, cover; delete sits at
  /// the bottom of the same dialog.
  Future<void> _settings(
    BuildContext context,
    WidgetRef ref,
    WorldSchema schema,
  ) async {
    final l10n = L10n.of(context)!;
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => _SettingsDialog(schema: schema),
    );
    if (!context.mounted) return;
    if (result == _SettingsDialog.delete) {
      await _delete(context, ref, schema);
    } else if (result is _Info) {
      await _run(
        context,
        l10n.worldsSettingsSaved,
        () => ref
            .read(userTemplatesProvider.notifier)
            .saveInfo(
              schema.schemaId,
              name: result.name,
              description: result.description,
              tags: result.tags,
              coverImagePath: result.cover,
            ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WorldSchema schema,
  ) async {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.templateDeleteTitle),
        content: Text(l10n.templateDeleteBody(schema.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      l10n.templateDeleted(schema.name),
      () => ref.read(userTemplatesProvider.notifier).delete(schema.schemaId),
    );
  }

  /// Runs [action] and reports [done] or the error in a snackbar.
  Future<void> _run(
    BuildContext context,
    String done,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context)!;
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.templateActionFailed(formatError(e)))),
      );
    }
  }
}

/// Name prompt shared by copy, create and rename. Null when cancelled;
/// the confirm button stays disabled while the name is blank.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirm,
  String? helper,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(
    title: title,
    initial: initial,
    confirm: confirm,
    helper: helper,
  ),
);

/// Owns its controller so it is disposed only after the route's exit
/// animation, not while the closing dialog still listens to it.
class _NameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String confirm;
  final String? helper;

  const _NameDialog({
    required this.title,
    required this.initial,
    required this.confirm,
    this.helper,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.templateNameLabel,
            helperText: widget.helper,
            helperMaxLines: 2,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, v, _) => FilledButton(
            onPressed: v.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirm),
          ),
        ),
      ],
    );
  }
}

String _summary(BuildContext context, WorldSchema schema) {
  final fields = schema.categories.fold<int>(0, (n, c) => n + c.fields.length);
  return L10n.of(
    context,
  )!.templateSummary('${schema.categories.length}', '$fields');
}

/// Card subtitle: size, plus the lineage on SRD copies.
String _subtitle(BuildContext context, WorldSchema schema) => [
  _summary(context, schema),
  if (isSrdLineage(schema)) L10n.of(context)!.templateLineageSrd,
].join(' · ');

/// Cover shown when a template has none of its own: the built-in template
/// and SRD copies keep the SRD banner.
const _srdBanner = 'assets/first_party/banners/dnd5e-template.jpg';

List<String> _tagsOf(WorldSchema s) =>
    ((s.metadata['tags'] as List?) ?? const []).whereType<String>().toList();

String _coverOf(WorldSchema s) =>
    (s.metadata['cover_image_path'] as String?) ?? '';

/// One card for every template — the Worlds tab's selectable banner card.
/// [onSettings] null = the read-only built-in template (no gear).
class _TemplateCard extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback? onSettings;

  const _TemplateCard({
    super.key,
    required this.schema,
    required this.palette,
    required this.isSelected,
    required this.onTap,
    required this.onOpen,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final builtin = onSettings == null;
    final cover = _coverOf(schema);

    return InkWell(
      borderRadius: palette.br,
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? palette.featureCardAccent.withValues(alpha: 0.1)
              : palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(
            color: isSelected
                ? palette.featureCardAccent
                : palette.featureCardBorder,
          ),
        ),
        child: MetadataListTile(
          icon: Icons.dashboard_customize_outlined,
          name: schema.name,
          subtitle: builtin
              ? _summary(context, schema)
              : _subtitle(context, schema),
          description: schema.description,
          tags: _tagsOf(schema),
          coverImagePath: cover,
          coverAssetPath: cover.isEmpty && (builtin || isSrdLineage(schema))
              ? _srdBanner
              : null,
          isSelected: isSelected,
          palette: palette,
          layout: MetadataTileLayout.topBanner,
          onSettings: onSettings ?? () {},
          trailingControl: builtin ? const SizedBox.shrink() : null,
          // Only the read-only built-in template is marked: a bare lock.
          trailingBadges: [
            if (builtin) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.templateBadgeBuiltin,
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _Info = ({
  String name,
  String description,
  List<String> tags,
  String cover,
});

/// Pops an [_Info] on save, [delete] on delete, null on cancel.
class _SettingsDialog extends StatefulWidget {
  static const delete = #delete;

  final WorldSchema schema;

  const _SettingsDialog({required this.schema});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late String _name = widget.schema.name;
  late String _description = widget.schema.description;
  late List<String> _tags = _tagsOf(widget.schema);
  late String _cover = _coverOf(widget.schema);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final schema = widget.schema;

    return AlertDialog(
      title: Text(l10n.worldsSettingsTitle(schema.name)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetadataEditorSection(
                name: _name,
                description: _description,
                tags: _tags,
                coverImagePath: _cover,
                onNameChanged: (v) => _name = v,
                onDescriptionChanged: (v) => _description = v,
                onTagsChanged: (v) => setState(() => _tags = v),
                // Copied into the template's own folder so `.dmtz` carries it.
                onCoverChanged: (v) async {
                  final local = v.isEmpty
                      ? v
                      : await LocalMediaLocalizer.localize(
                          v,
                          ownerDir: LocalMediaLocalizer.templateDir(
                            widget.schema.schemaId,
                          ),
                        );
                  if (mounted) setState(() => _cover = local);
                },
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 16,
                    color: palette.sidebarLabelSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _subtitle(context, schema),
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.tabActiveText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _SettingsDialog.delete),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.dangerBtnBg,
                  side: BorderSide(color: palette.dangerBtnBg),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.templateDeleteAction),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<_Info>(context, (
            name: _name.trim().isEmpty ? schema.name : _name.trim(),
            description: _description.trim(),
            tags: _tags,
            cover: _cover,
          )),
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  final DmToolColors palette;
  final String text;

  const _HintCard({required this.palette, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 13),
      ),
    );
  }
}
