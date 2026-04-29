import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/global_tags_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/services/tag_moderation.dart';
import '../../../core/config/supabase_config.dart';
import '../../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../../data/repositories/cloud_backup_repository_impl.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/cloud_backup_meta.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/save_info_section.dart';
import '../database/entity_card.dart';

/// Standalone character editor. Hub-level Characters tab'dan push edilir.
/// Bir Character'ı template'inin Player kategorisine göre render eder.
class CharacterEditorScreen extends ConsumerStatefulWidget {
  final String characterId;

  const CharacterEditorScreen({super.key, required this.characterId});

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState
    extends ConsumerState<CharacterEditorScreen> {
  Character? _working;
  Timer? _autoSaveTimer;
  bool _saving = false;
  bool _readOnly = true;

  // Markdown controllers — kept in sync with `_working.entity` so user input
  // doesn't fight the rebuild loop. Initialized lazily on first build.
  final TextEditingController _descController = TextEditingController();
  final FocusNode _descFocus = FocusNode();
  final TextEditingController _dmNotesController = TextEditingController();
  final FocusNode _dmNotesFocus = FocusNode();
  bool _controllersPrimed = false;

  // Undo/redo — character scoped. Idle timer coalesces rapid mutations into
  // a single undo step so typing doesn't produce per-keystroke history.
  final List<Character> _undoStack = [];
  final List<Character> _redoStack = [];
  Character? _undoBaseline;
  Timer? _undoIdleTimer;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _undoIdleTimer?.cancel();
    _descController.dispose();
    _descFocus.dispose();
    _dmNotesController.dispose();
    _dmNotesFocus.dispose();
    super.dispose();
  }

  void _primeControllers(Character c) {
    if (_controllersPrimed) return;
    _descController.text = c.entity.description;
    _dmNotesController.text = c.entity.dmNotes;
    _controllersPrimed = true;
  }

  /// Sync controller text from entity only when not focused — avoids
  /// fighting in-flight typing.
  void _syncIfNotFocused(
      TextEditingController ctrl, FocusNode focus, String value) {
    if (!focus.hasFocus && ctrl.text != value) ctrl.text = value;
  }

  /// Central mutation entry point — records undo baseline, updates state,
  /// schedules autosave. All edits (name, desc, tags, portrait, fields)
  /// should go through this.
  void _mutate(Character next) {
    final prev = _working;
    setState(() => _working = next);
    _undoBaseline ??= prev;
    _undoIdleTimer?.cancel();
    _undoIdleTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final baseline = _undoBaseline;
      if (baseline != null && baseline != _working) {
        _undoStack.add(baseline);
        if (_undoStack.length > 100) _undoStack.removeAt(0);
        _redoStack.clear();
      }
      _undoBaseline = null;
      setState(() {});
    });
    _scheduleAutoSave();
  }

  bool get _canUndo => _undoStack.isNotEmpty || _undoBaseline != null;
  bool get _canRedo => _redoStack.isNotEmpty;

  void _undo() {
    // Commit any pending baseline first so the user's in-progress edit
    // counts as one undo step.
    _undoIdleTimer?.cancel();
    final baseline = _undoBaseline;
    if (baseline != null && baseline != _working) {
      _undoStack.add(baseline);
    }
    _undoBaseline = null;
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    final cur = _working;
    if (cur != null) _redoStack.add(cur);
    setState(() => _working = prev);
    _scheduleAutoSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    final cur = _working;
    if (cur != null) _undoStack.add(cur);
    setState(() => _working = next);
    _scheduleAutoSave();
  }

  /// Mark `_working` as dirty and debounce-persist via characterListProvider.
  /// Mirrors the world editor's autosave vibe.
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _save(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final character =
        _working ?? ref.watch(characterByIdProvider(widget.characterId));

    if (character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Character')),
        body: const Center(child: Text('Character not found.')),
      );
    }

    _working ??= character;

    final templatesAsync = ref.watch(allTemplatesProvider);
    return templatesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (templates) {
        final template = templates
            .where((t) => t.schemaId == character.templateId)
            .firstOrNull;
        if (template == null) {
          return Scaffold(
            appBar: AppBar(title: Text(character.entity.name)),
            body: Center(
              child: Text(
                'Template "${character.templateName}" missing.\n'
                'Restore it in the Templates tab to edit this character.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.sidebarLabelSecondary),
              ),
            ),
          );
        }
        final playerCat = findPlayerCategory(template);
        if (playerCat == null) {
          return Scaffold(
            appBar: AppBar(title: Text(character.entity.name)),
            body: const Center(
              child: Text('Template has no Player category.'),
            ),
          );
        }
        return _buildEditor(context, palette, playerCat, template);
      },
    );
  }

  Widget _buildEditor(
    BuildContext context,
    DmToolColors palette,
    EntityCategorySchema playerCat,
    WorldSchema template,
  ) {
    final character = _working!;
    final l10n = L10n.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose(context);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: 'Back',
                onPressed: () => _saveAndClose(context),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const AppIconImage(size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  character.entity.name.isEmpty
                      ? 'Character'
                      : character.entity.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                template.name,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
          actions: [
            // View / Edit toggle — mirrors EntityCard's read-only default.
            IconButton(
              icon: Icon(_readOnly ? Icons.edit : Icons.visibility,
                  size: 20),
              tooltip: _readOnly ? 'Edit' : 'View',
              onPressed: () => setState(() => _readOnly = !_readOnly),
              visualDensity: VisualDensity.compact,
            ),
            // Undo / Redo
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              tooltip: 'Undo',
              onPressed: _readOnly || !_canUndo ? null : _undo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              tooltip: 'Redo',
              onPressed: _readOnly || !_canRedo ? null : _redo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            // Cloud save & sync — same UI/behaviour as worlds' Save & Sync.
            _CharacterSaveSyncButton(
              character: character,
              saving: _saving,
              flushLocal: () => _save(silent: true),
            ),
            // Import package / world — shared dialog.
            IconButton(
              icon: const Icon(Icons.inventory_2, size: 20),
              tooltip: l10n.importPackage,
              onPressed: () => ImportPackageDialog.show(context),
            ),
            // Theme
            PopupMenuButton<String>(
              icon: const Icon(Icons.palette, size: 20),
              tooltip: l10n.lblTheme,
              onSelected: (name) =>
                  ref.read(themeProvider.notifier).setTheme(name),
              itemBuilder: (_) => themeNames
                  .map((name) => PopupMenuItem(
                        value: name,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: themePalettes[name]?.canvasBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name[0].toUpperCase() + name.substring(1)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            // Language
            PopupMenuButton<String>(
              icon: const Icon(Icons.language, size: 20),
              tooltip: l10n.lblLanguage,
              onSelected: (code) =>
                  ref.read(localeProvider.notifier).setLocale(code),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'en', child: Text('English')),
                PopupMenuItem(value: 'tr', child: Text('Türkçe')),
                PopupMenuItem(value: 'de', child: Text('Deutsch')),
                PopupMenuItem(value: 'fr', child: Text('Français')),
              ],
            ),
            // Bug report
            IconButton(
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              tooltip: 'Report a Bug',
              onPressed: () => BugReportDialog.show(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _buildCardBody(context, palette, character, playerCat, template),
      ),
    );
  }

  Widget _buildCardBody(
    BuildContext context,
    DmToolColors palette,
    Character character,
    EntityCategorySchema playerCat,
    WorldSchema template,
  ) {
    _primeControllers(character);
    _syncIfNotFocused(
        _descController, _descFocus, character.entity.description);
    _syncIfNotFocused(
        _dmNotesController, _dmNotesFocus, character.entity.dmNotes);

    final baseTheme = Theme.of(context);
    final cardTheme = palette.cardBorderlessInputs
        ? baseTheme.copyWith(
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            ),
          )
        : baseTheme;

    return Theme(
      data: cardTheme,
      child: Container(
        color: palette.srdParchment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _entityHeader(palette, character, template),
                  const SizedBox(height: 16),
                  ..._renderSchemaFields(palette, playerCat, character),
                  const SizedBox(height: 8),
                  EntityCardSectionHeading(
                    title: 'DM Notes',
                    palette: palette,
                    leadingIcon: Icons.lock,
                  ),
                  const SizedBox(height: 6),
                  MarkdownTextArea(
                    controller: _dmNotesController,
                    focusNode: _dmNotesFocus,
                    readOnly: _readOnly,
                    minLines: _readOnly ? null : 3,
                    textStyle: TextStyle(
                        fontSize: 13,
                        color: palette.srdInk,
                        height: 1.4),
                    decoration: InputDecoration(
                      hintText: 'Private DM notes... (@ to mention)',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      hintStyle:
                          TextStyle(color: palette.sidebarLabelSecondary),
                    ),
                    onChanged: (v) {
                      final c = _working;
                      if (c == null) return;
                      _mutate(c.copyWith(
                          entity: c.entity.copyWith(dmNotes: v)));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// EntityCard-style header — square portrait left, big serif red name +
  /// italic subtitle (template · world) + red rule + markdown description +
  /// tags row on the right.
  Widget _entityHeader(
      DmToolColors palette, Character c, WorldSchema template) {
    final entity = c.entity;
    final hasImage =
        entity.imagePath.isNotEmpty && File(entity.imagePath).existsSync();
    final globalTags = ref.watch(globalTagsProvider);
    final l10n = L10n.of(context)!;
    final subtitle = c.worldName.isEmpty
        ? '${template.name} · ${l10n.charWorldOrphan}'
        : '${template.name} · ${c.worldName}';

    const portraitSize = 200.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _readOnly ? null : _pickPortrait,
          child: Container(
            width: portraitSize,
            height: 260,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: hasImage
                ? Image.file(File(entity.imagePath), fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person,
                          size: 56,
                          color: palette.sidebarLabelSecondary),
                      if (!_readOnly) ...[
                        const SizedBox(height: 4),
                        Text('Add photo',
                            style: TextStyle(
                                fontSize: 11,
                                color: palette.sidebarLabelSecondary)),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_readOnly)
                Text(
                  entity.name.isEmpty ? '(Unnamed)' : entity.name,
                  style: TextStyle(
                    fontFamily: palette.useSerif ? 'Georgia' : null,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: palette.srdHeadingRed,
                    letterSpacing: palette.cardHeadingUppercase ? 1.2 : 0,
                    height: 1.1,
                  ),
                )
              else
                TextFormField(
                  key: ValueKey('hdr_name_${c.id}'),
                  initialValue: entity.name,
                  style: TextStyle(
                    fontFamily: palette.useSerif ? 'Georgia' : null,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: palette.srdHeadingRed,
                    letterSpacing: palette.cardHeadingUppercase ? 1.2 : 0,
                    height: 1.1,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Character Name',
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    _mutate(c.copyWith(entity: c.entity.copyWith(name: v)));
                  },
                ),
              const SizedBox(height: 2),
              InkWell(
                onTap: c.worldName.isEmpty ? null : () => _openWorld(c.worldName),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: palette.useSerif ? 'Georgia' : null,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: palette.srdSubtitle,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (palette.cardShowRule)
                Container(height: 1, color: palette.srdRule),
              const SizedBox(height: 10),
              MarkdownTextArea(
                controller: _descController,
                focusNode: _descFocus,
                readOnly: _readOnly,
                minLines: _readOnly ? null : 3,
                textStyle: TextStyle(
                    fontSize: 16, color: palette.srdInk, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'Markdown supported... (@ to mention)',
                  border: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                      color: palette.srdSubtitle,
                      fontStyle: FontStyle.italic),
                ),
                onChanged: (v) {
                  final cur = _working;
                  if (cur == null) return;
                  _mutate(cur.copyWith(
                      entity: cur.entity.copyWith(description: v)));
                },
              ),
              const SizedBox(height: 10),
              if (_readOnly)
                entity.tags.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        'Tags: ${entity.tags.join(', ')}',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: palette.srdSubtitle,
                        ),
                      )
              else
                _HeaderTagsField(
                  initial: entity.tags.join(', '),
                  globalTags: globalTags,
                  onCommit: (tags) {
                    _mutate(
                        c.copyWith(entity: c.entity.copyWith(tags: tags)));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openWorld(String worldName) async {
    await _save(silent: true);
    if (!mounted) return;
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-world-$worldName',
      'Opening world "$worldName"...',
      () => ref.read(activeCampaignProvider.notifier).load(worldName),
    );
    if (!success || !mounted) return;
    context.go('/main');
  }

  Future<void> _pickPortrait() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;
    final c = _working;
    if (c == null) return;
    _mutate(c.copyWith(entity: c.entity.copyWith(imagePath: path)));
  }


  /// EntityCard-style schema render — ungrouped fields under a "Properties"
  /// heading, grouped fields wrapped in a collapsible card per group.
  List<Widget> _renderSchemaFields(
      DmToolColors palette, EntityCategorySchema cat, Character character) {
    final fieldsByGroup = <String?, List<FieldSchema>>{};
    for (final f in cat.fields) {
      fieldsByGroup.putIfAbsent(f.groupId, () => []).add(f);
    }
    for (final list in fieldsByGroup.values) {
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }
    final groupsInOrder = [...cat.fieldGroups]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final widgets = <Widget>[];
    final ungrouped = fieldsByGroup[null] ?? const <FieldSchema>[];
    if (ungrouped.isNotEmpty) {
      widgets.add(EntityCardSectionHeading(
          title: 'Properties', palette: palette));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ungrouped.map((f) => _fieldTile(f, character)).toList(),
      ));
    }

    for (final g in groupsInOrder) {
      final list = fieldsByGroup[g.groupId] ?? const <FieldSchema>[];
      if (list.isEmpty) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
      widgets.add(EntityCardCollapsibleGroupCard(
        group: g,
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.map((f) => _fieldTile(f, character)).toList(),
        ),
      ));
    }
    return widgets;
  }

  Widget _fieldTile(FieldSchema f, Character character) {
    final value = character.entity.fields[f.fieldKey];
    // Resolve relation refs only when the active campaign matches this
    // character's world — entityProvider is scoped per-campaign, so a
    // mismatched map would be wrong/empty.
    final activeCampaign = ref.watch(activeCampaignProvider);
    final entities = activeCampaign == character.worldName
        ? ref.watch(entityProvider)
        : null;
    return FieldWidgetFactory.create(
      schema: f,
      value: value,
      readOnly: _readOnly,
      onChanged: (v) {
        final updatedFields = {
          ...character.entity.fields,
          f.fieldKey: v,
        };
        _mutate(character.copyWith(
          entity: character.entity.copyWith(fields: updatedFields),
        ));
      },
      entities: entities,
      entityFields: character.entity.fields,
      ref: ref,
    );
  }

  Future<void> _save({bool silent = false}) async {
    final w = _working;
    if (w == null) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(characterListProvider.notifier).update(w);
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Character saved.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndClose(BuildContext context) async {
    _autoSaveTimer?.cancel();
    await _save(silent: true);
    if (context.mounted) context.pop();
  }
}

// ── Character-scoped Save & Sync button ────────────────────────────
//
// Mirrors the worlds' SaveSyncIndicator: state-aware cloud icon in the app
// bar, tap opens a dialog with Save Locally / Backup to Cloud / Sync from
// Cloud actions plus this character's save info and cloud storage usage.

class _CharacterSaveSyncButton extends ConsumerWidget {
  final Character character;
  final bool saving;
  final Future<void> Function() flushLocal;

  const _CharacterSaveSyncButton({
    required this.character,
    required this.saving,
    required this.flushLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hasCloud = SupabaseConfig.isConfigured;
    final opState = ref.watch(cloudBackupOperationProvider);
    final busy = saving ||
        opState.type == CloudBackupOpType.uploading ||
        opState.type == CloudBackupOpType.downloading;

    final (icon, color) = _resolveIcon(palette, hasCloud, opState);

    return IconButton(
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 20, color: color),
      tooltip: _tooltip(opState, saving),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (ctx) => _CharacterSaveSyncDialog(
          character: character,
          flushLocal: flushLocal,
        ),
      ),
    );
  }

  (IconData, Color) _resolveIcon(
    DmToolColors palette,
    bool hasCloud,
    CloudBackupOperationState op,
  ) {
    if (!hasCloud) {
      return (Icons.save, palette.sidebarLabelSecondary);
    }
    if (op.errorMessage != null) {
      return (Icons.cloud_off, palette.dangerBtnBg);
    }
    return switch (op.type) {
      CloudBackupOpType.uploading ||
      CloudBackupOpType.downloading =>
        (Icons.cloud_sync, palette.featureCardAccent),
      _ => op.result != null
          ? (Icons.cloud_done, palette.successBtnBg)
          : (Icons.cloud_queue, palette.sidebarLabelSecondary),
    };
  }

  String _tooltip(CloudBackupOperationState op, bool saving) {
    if (saving) return 'Saving...';
    if (op.errorMessage != null) return 'Cloud error';
    return switch (op.type) {
      CloudBackupOpType.uploading => 'Backing up...',
      CloudBackupOpType.downloading => 'Restoring...',
      CloudBackupOpType.deleting => 'Deleting...',
      _ => 'Save & Sync',
    };
  }
}

class _CharacterSaveSyncDialog extends ConsumerWidget {
  final Character character;
  final Future<void> Function() flushLocal;

  const _CharacterSaveSyncDialog({
    required this.character,
    required this.flushLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hasCloud = SupabaseConfig.isConfigured;
    final opState = ref.watch(cloudBackupOperationProvider);
    final isUploading = opState.type == CloudBackupOpType.uploading;
    final isDownloading = opState.type == CloudBackupOpType.downloading;

    DateTime? updatedAt;
    try {
      updatedAt = DateTime.parse(character.updatedAt);
    } catch (_) {}

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasCloud ? Icons.cloud_sync : Icons.save,
                      size: 20,
                      color: palette.tabActiveText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Save & Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active character info
                _sectionLabel(palette, character.entity.name.isEmpty
                    ? 'Character'
                    : character.entity.name),
                const SizedBox(height: 6),
                SaveInfoSection(
                  itemName: character.entity.name,
                  itemId: character.id,
                  type: 'character',
                  localUpdatedAt: updatedAt,
                ),
                const SizedBox(height: 16),

                // Actions
                _sectionLabel(palette, 'Actions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _actionButton(
                      palette,
                      icon: Icons.save,
                      label: 'Save Locally',
                      onPressed: () async {
                        await flushLocal();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved locally.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    if (hasCloud)
                      _actionButton(
                        palette,
                        icon: Icons.cloud_upload_outlined,
                        label: isUploading ? 'Syncing...' : 'Backup to Cloud',
                        onPressed: isUploading
                            ? null
                            : () => _backupToCloud(context, ref),
                      ),
                    if (hasCloud)
                      _actionButton(
                        palette,
                        icon: Icons.cloud_download_outlined,
                        label: isDownloading ? 'Restoring...' : 'Sync from Cloud',
                        onPressed: isDownloading
                            ? null
                            : () => _syncFromCloud(context, ref),
                      ),
                  ],
                ),

                // Storage
                if (hasCloud) ...[
                  const SizedBox(height: 16),
                  _sectionLabel(palette, 'Storage'),
                  const SizedBox(height: 8),
                  _CharacterStorageBar(palette: palette),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(DmToolColors palette, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.sidebarLabelSecondary,
          letterSpacing: 0.5,
        ),
      );

  Widget _actionButton(
    DmToolColors palette, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: palette.featureCardBorder),
          visualDensity: VisualDensity.compact,
        ),
      );

  Future<void> _backupToCloud(BuildContext context, WidgetRef ref) async {
    if (!ref.read(betaProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cloud save is beta-only. Open Settings → Subscriptions to join the free beta.',
          ),
        ),
      );
      return;
    }
    // Flush local edits first so the cloud copy matches disk.
    await flushLocal();
    final ok = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'character-backup-cloud',
      'Backing up "${character.entity.name}" to cloud...',
      () => ref
          .read(cloudBackupOperationProvider.notifier)
          .uploadCharacter(character),
    );
    if (!context.mounted) return;
    final fresh = ref.read(cloudBackupOperationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Cloud backup complete'
            : 'Cloud backup failed: ${fresh.errorMessage ?? ''}'),
      ),
    );
  }

  Future<void> _syncFromCloud(BuildContext context, WidgetRef ref) async {
    final remoteDs = CloudBackupRemoteDataSource();
    final loading = ref.read(globalLoadingProvider.notifier);
    const fetchTaskId = 'character-sync-fetch';
    loading.start(LoadingTask(
      id: fetchTaskId,
      message: 'Looking up cloud backup for "${character.entity.name}"...',
    ));
    CloudBackupMeta? meta;
    try {
      meta = await remoteDs.fetchByItem(character.id, 'character');
    } catch (e) {
      debugPrint('character fetchByItem failed: $e');
    } finally {
      loading.end(fetchTaskId);
    }
    if (!context.mounted) return;
    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No cloud backup found for "${character.entity.name}".'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore "${character.entity.name}" from cloud?'),
        content: const Text(
          'This will OVERWRITE the local character with the cloud backup. '
          'Any unsaved changes since the last cloud backup will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'character-sync-restore',
      'Restoring "${character.entity.name}"...',
      () => ref
          .read(cloudBackupOperationProvider.notifier)
          .restoreBackup(meta!),
    );
    if (!context.mounted) return;
    final fresh = ref.read(cloudBackupOperationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Restored "${character.entity.name}" from cloud.'
            : 'Restore failed: ${fresh.errorMessage ?? ''}'),
      ),
    );
  }
}

class _CharacterStorageBar extends ConsumerWidget {
  final DmToolColors palette;
  const _CharacterStorageBar({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(cloudStorageUsedProvider);
    final quotaBytes = ref.watch(betaProvider).quotaBytes;

    return storageAsync.when(
      data: (bytes) {
        final usedMb = bytes / (1024 * 1024);
        final totalMb = quotaBytes / (1024 * 1024);
        final itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / quotaBytes).clamp(0.0, 1.0);
        final remainingMb = totalMb - usedMb;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: palette.featureCardBorder,
                      color: ratio > 0.9
                          ? palette.dangerBtnBg
                          : palette.featureCardAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${usedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(0)} MB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${remainingMb.toStringAsFixed(1)} MB remaining  |  Max ${itemLimitMb.toStringAsFixed(0)} MB per item',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 8,
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Text(
        'Could not load storage info',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
    );
  }
}

/// Compact comma-separated tags field with global autocomplete + moderation.
class _HeaderTagsField extends StatefulWidget {
  final String initial;
  final Set<String> globalTags;
  final ValueChanged<List<String>> onCommit;

  const _HeaderTagsField({
    required this.initial,
    required this.globalTags,
    required this.onCommit,
  });

  @override
  State<_HeaderTagsField> createState() => _HeaderTagsFieldState();
}

class _HeaderTagsFieldState extends State<_HeaderTagsField> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parts = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    String? err;
    final accepted = <String>[];
    for (final p in parts) {
      final reason = TagModeration.validate(p);
      if (reason != null) {
        err = '"$p": $reason';
        continue;
      }
      if (!accepted.contains(p)) accepted.add(p);
    }
    setState(() => _error = err);
    widget.onCommit(accepted);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      focusNode: _focus,
      textEditingController: _ctrl,
      optionsBuilder: (value) {
        final text = value.text;
        final lastComma = text.lastIndexOf(',');
        final current =
            (lastComma >= 0 ? text.substring(lastComma + 1) : text)
                .trim()
                .toLowerCase();
        if (current.isEmpty) return const Iterable<String>.empty();
        final already =
            text.split(',').map((s) => s.trim().toLowerCase()).toSet();
        return widget.globalTags
            .where((t) =>
                t.toLowerCase().contains(current) &&
                !already.contains(t.toLowerCase()))
            .take(8);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            hintText: 'tags, comma, separated',
            errorText: _error,
            isDense: true,
            prefixIcon: const Icon(Icons.tag, size: 14),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
          style: const TextStyle(fontSize: 11),
          onChanged: _commit,
          onSubmitted: (_) {
            onSubmit();
            _commit(controller.text);
          },
        );
      },
      onSelected: (option) {
        final text = _ctrl.text;
        final lastComma = text.lastIndexOf(',');
        final head =
            lastComma >= 0 ? '${text.substring(0, lastComma + 1)} ' : '';
        final replaced = '$head$option, ';
        _ctrl.value = TextEditingValue(
          text: replaced,
          selection: TextSelection.collapsed(offset: replaced.length),
        );
        _commit(replaced);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 360, maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child:
                          Text(opt, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

