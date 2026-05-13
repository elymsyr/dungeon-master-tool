import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/character_creation/level_up_planner.dart';
import '../../../application/character_creation/multiclass_helper.dart';
import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/services/builtin_srd_entities.dart';
import '../../widgets/character_stat_chips.dart';
import 'level_up_dialog.dart';
import '../../../core/config/supabase_config.dart';
import '../../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../../data/repositories/cloud_backup_repository_impl.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/cloud_backup_meta.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/class_level_up_table.dart';
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
                  const SizedBox(height: 12),
                  _renderRestActions(palette, character),
                  const SizedBox(height: 16),
                  ..._renderSchemaFields(palette, playerCat, character),
                  ..._renderLevelUpTable(palette, character),
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
    // E2: drop synchronous `File.existsSync()` from the build path. The
    // ImageProvider stat-cache + `errorBuilder` already handle the
    // missing-file case without blocking the frame, and the `File`
    // allocation per rebuild is gone.
    final hasImagePath = entity.imagePath.isNotEmpty;
    final l10n = L10n.of(context)!;
    final subtitle = c.worldName.isEmpty
        ? '${template.name} · ${l10n.charWorldOrphan}'
        : '${template.name} · ${c.worldName}';

    Widget portraitPlaceholder() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person,
                size: 56, color: palette.sidebarLabelSecondary),
            if (!_readOnly) ...[
              const SizedBox(height: 4),
              Text('Add photo',
                  style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary)),
            ],
          ],
        );

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
            child: hasImagePath
                ? Image.file(
                    File(entity.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => portraitPlaceholder(),
                  )
                : portraitPlaceholder(),
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
              // E5/E6: avoid watching the full entity map for the header.
              // Resolve race/class names via `.select` so the strip only
              // rebuilds when those two specific names flip. RepaintBoundary
              // isolates the strip from descriptor edits above.
              _StatChipsHeader(character: c, palette: palette),
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


  static const _hiddenCharacterFieldKeys = <String>{
    'class_levels',
    'class_resources',
  };

  /// EntityCard-style schema render — ungrouped fields under a "Properties"
  /// heading, grouped fields wrapped in a collapsible card per group.
  List<Widget> _renderSchemaFields(
      DmToolColors palette, EntityCategorySchema cat, Character character) {
    final fieldsByGroup = <String?, List<FieldSchema>>{};
    for (final f in cat.fields) {
      if (_hiddenCharacterFieldKeys.contains(f.fieldKey)) continue;
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

  /// Render a level-up progression table when the character has both a
  /// class and a subclass resolved in the active campaign. Returns empty
  /// list otherwise (no header so the rest of the layout is unaffected).
  List<Widget> _renderLevelUpTable(DmToolColors palette, Character character) {
    final entities = _readEntitiesFor(character);
    if (entities.isEmpty) return const [];
    final fields = character.entity.fields;

    String? firstId(Iterable<String> keys) {
      for (final k in keys) {
        final v = fields[k];
        if (v is String && v.isNotEmpty) return v;
        if (v is List) {
          final s = v.whereType<String>().firstWhere(
                (e) => e.isNotEmpty,
                orElse: () => '',
              );
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    final classId = firstId(const ['class_refs', 'class_']);
    final subclassId = firstId(const ['subclass_refs', 'subclass_id']);
    final classEntity = classId == null ? null : entities[classId];
    final subclassEntity = subclassId == null ? null : entities[subclassId];
    if (classEntity == null || subclassEntity == null) return const [];

    final level = fields['level'] is int ? fields['level'] as int : null;
    return [
      const SizedBox(height: 16),
      EntityCardSectionHeading(title: 'Level Up Table', palette: palette),
      const SizedBox(height: 8),
      ClassLevelUpTable(
        classEntity: classEntity,
        subclassEntity: subclassEntity,
        currentLevel: level,
      ),
    ];
  }

  Widget _fieldTile(FieldSchema f, Character character) {
    final value = character.entity.fields[f.fieldKey];
    // Resolve relation refs against the active campaign (world-bound
    // character) or the bundled SRD map (worldless character). Either
    // path returns a non-null map so feat / class / race chips render.
    final entities = _readEntitiesFor(character);
    return FieldWidgetFactory.create(
      schema: f,
      value: value,
      readOnly: _readOnly,
      onChanged: (v) {
        final updatedFields = {
          ...character.entity.fields,
          f.fieldKey: v,
        };
        final nextCharacter = character.copyWith(
          entity: character.entity.copyWith(fields: updatedFields),
        );
        _mutate(nextCharacter);
        if (f.fieldKey == 'level') {
          _maybeRunLevelUp(
            from: value,
            to: v,
            base: nextCharacter,
            entities: entities,
          );
        }
      },
      entities: entities,
      entityFields: character.entity.fields,
      ref: ref,
    );
  }

  /// Open the level-up dialog when the level field grew. Looks up class
  /// + subclass via the active campaign so HP / PB / new-feature deltas
  /// reflect the SRD entity tables. No-op if [from]/[to] aren't ints or
  /// the new value is not strictly greater.
  Future<void> _maybeRunLevelUp({
    required Object? from,
    required Object? to,
    required Character base,
    required Map<String, Entity> entities,
    String? targetClassId,
    bool isNewClass = false,
  }) async {
    final fromLvl = from is int
        ? from
        : (from is String ? int.tryParse(from) : null);
    final toLvl = to is int
        ? to
        : (to is String ? int.tryParse(to) : null);
    if (fromLvl == null || toLvl == null) return;
    if (toLvl <= fromLvl) return;

    String? firstId(Iterable<String> keys) {
      for (final k in keys) {
        final v = base.entity.fields[k];
        if (v is String && v.isNotEmpty) return v;
        if (v is List) {
          final s = v.whereType<String>().firstWhere(
                (e) => e.isNotEmpty,
                orElse: () => '',
              );
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    // Multiclass: target class is the one the level-up button just bumped.
    // Fall back to the legacy "first class_refs" lookup so the bare `level`
    // field edit path still works for single-class characters.
    final classId =
        targetClassId ?? firstId(const ['class_refs', 'class_']);
    // SRD §1.10: pick the subclass whose parent_class_ref matches the
    // target class. Falls back to the first subclass_refs entry when
    // none match — preserves legacy single-class behaviour.
    final subclassId = _subclassForClass(
      base: base,
      entities: entities,
      classId: classId,
    );
    final classEntity = classId == null ? null : entities[classId];
    final subclassEntity =
        subclassId == null ? null : entities[subclassId];

    final plan = planLevelUp(
      fromLevel: fromLvl,
      toLevel: toLvl,
      classEntity: classEntity,
      subclassEntity: subclassEntity,
      entities: entities,
    );
    if (!plan.isLevelUp) return;

    // Snapshot ability scores + feat list so the dialog's ASI/Feat picker
    // can enforce caps and skip non-repeatable feats the character already
    // has. Falls back to the stat_block map when individual `str` keys
    // aren't populated.
    final scoresEntries = <String, int>{};
    final statBlock = base.entity.fields['stat_block'];
    final statBlockMap =
        statBlock is Map ? Map<String, dynamic>.from(statBlock) : null;
    int asInt(Object? raw) {
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }

    for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
      final lower = k.toLowerCase();
      final v = base.entity.fields[lower] ??
          base.entity.fields[k] ??
          statBlockMap?[k] ??
          statBlockMap?[lower];
      scoresEntries[k] = asInt(v).clamp(1, 30);
    }
    final existingFeatIds = <String>{};
    final rawFeats = base.entity.fields['feat_ids'];
    if (rawFeats is List) {
      for (final id in rawFeats) {
        if (id is String && id.isNotEmpty) existingFeatIds.add(id);
      }
    }

    // Spells already on the sheet — cantrips + leveled spells are both
    // stored in `spells_known`; merging `prepared_spells` keeps the
    // picker from re-offering a prepared-but-not-yet-known spell.
    final existingSpellIds = <String>{};
    void collectSpells(Object? raw) {
      if (raw is List) {
        for (final id in raw) {
          if (id is String && id.isNotEmpty) existingSpellIds.add(id);
        }
      }
    }
    collectSpells(base.entity.fields['spells_known']);
    collectSpells(base.entity.fields['prepared_spells']);

    final result = await LevelUpDialog.show(
      context,
      plan,
      entities: entities,
      abilityScores: scoresEntries,
      existingFeatIds: existingFeatIds,
      classId: classId,
      existingSpellIds: existingSpellIds,
    );
    if (!mounted || result == null || !result.applied) return;

    final updated = Map<String, dynamic>.from(base.entity.fields);

    // Apply ASI bumps to per-ability keys + stat_block (when present)
    // before recomputing derived HP so Constitution increases stack into
    // the HP delta consistently with SRD §1.
    final bumps = result.abilityBumps;
    if (bumps.isNotEmpty) {
      final nextStat = statBlockMap == null
          ? null
          : Map<String, dynamic>.from(statBlockMap);
      for (final entry in bumps.entries) {
        final code = entry.key;
        final lower = code.toLowerCase();
        if (updated.containsKey(lower)) {
          updated[lower] = asInt(updated[lower]) + entry.value;
        } else if (updated.containsKey(code)) {
          updated[code] = asInt(updated[code]) + entry.value;
        }
        if (nextStat != null) {
          final at = nextStat[code] ?? nextStat[lower];
          if (at != null) {
            if (nextStat.containsKey(code)) {
              nextStat[code] = asInt(at) + entry.value;
            } else {
              nextStat[lower] = asInt(at) + entry.value;
            }
          } else {
            nextStat[code] = (scoresEntries[code] ?? 10) + entry.value;
          }
        }
      }
      if (nextStat != null) updated['stat_block'] = nextStat;
    }

    if (result.hpDelta > 0) {
      updated['max_hp'] = asInt(updated['max_hp']) + result.hpDelta;
      updated['hp'] = asInt(updated['hp']) + result.hpDelta;
    }

    // SRD §1.6: gain one Hit Die per level. Max is derived from `level`
    // (no separate field), so we only carry forward `hit_dice_remaining`
    // and add the levels gained, clamped to the new max. When the field
    // was never written we assume the character was at full dice for
    // their old level — matches the fallback used by Short/Long Rest.
    final postClassLevels = _readClassLevels(base);
    final levelsGained = plan.levelsGained;
    if (levelsGained > 0) {
      // SRD §1.6: max hit dice = total character level (sum of class
      // levels). Multiclass adds the new class's hit die alongside the
      // existing pool — but until per-class hit-die tracking lands, we
      // keep a single combined pool keyed off the character total.
      final newMaxHd = totalCharacterLevel(postClassLevels);
      final prevTotal = newMaxHd - levelsGained;
      final prevHd = updated.containsKey('hit_dice_remaining')
          ? asInt(updated['hit_dice_remaining'])
          : (prevTotal < 0 ? 0 : prevTotal);
      updated['hit_dice_remaining'] =
          (prevHd + levelsGained).clamp(0, newMaxHd);
    }

    // SRD §1.5 / §1.10: writing the new slot pool. Max is rewritten outright
    // so pact-tier shifts (L2 → L3) discard the old entry. Remaining keeps
    // any spent slots the player carried over (so leveling up doesn't
    // restore slots), then adds the per-spell-level delta as fresh capacity
    // — clamped to the new max.
    //
    // Multi-caster override: when the character has two or more caster
    // classes, the planner's single-class slot map is wrong. Compute the
    // combined caster level table off `class_levels` (Warlock pact slots
    // stay separate — they ride on their own pool field).
    final blendedNow = multiclassSpellSlotsFor(
      classLevels: postClassLevels,
      entities: entities,
    );
    Map<int, int>? newSlots;
    Map<int, int>? prevSlotsOverride;
    if (blendedNow != null) {
      newSlots = blendedNow;
      // Recompute the previous blended map by reverting the target class
      // back to its from-level so the slot delta = blendedNow - prev.
      if (targetClassId != null) {
        final prevClassLevels = {
          ...postClassLevels,
          targetClassId: plan.fromLevel,
        };
        prevSlotsOverride = multiclassSpellSlotsFor(
              classLevels: prevClassLevels,
              entities: entities,
            ) ??
            const {};
      }
    } else {
      newSlots = plan.newSpellSlots;
    }
    if (newSlots != null && newSlots.isNotEmpty) {
      final prevSlots = prevSlotsOverride ??
          plan.prevSpellSlots ??
          const <int, int>{};
      // Source of truth is `spell_slots` field with shape
      // {max: {...}, remaining: {...}}. Read prev remaining from there.
      final prevSlotsField = updated['spell_slots'];
      final prevRemainingRaw =
          prevSlotsField is Map ? prevSlotsField['remaining'] : null;
      int prevRem(int spellLevel) {
        if (prevRemainingRaw is Map) {
          final v = prevRemainingRaw[spellLevel.toString()] ??
              prevRemainingRaw[spellLevel];
          if (v is int) return v;
          if (v is String) {
            return int.tryParse(v) ?? (prevSlots[spellLevel] ?? 0);
          }
        }
        return prevSlots[spellLevel] ?? 0;
      }

      final maxOut = <String, dynamic>{};
      final remainingOut = <String, dynamic>{};
      for (final entry in newSlots.entries) {
        final k = entry.key;
        final keyStr = k.toString();
        final newMax = entry.value;
        maxOut[keyStr] = newMax;
        final delta = newMax - (prevSlots[k] ?? 0);
        final base = prevRem(k);
        remainingOut[keyStr] = (base + delta).clamp(0, newMax);
      }
      updated['spell_slots'] = {'max': maxOut, 'remaining': remainingOut};
    }

    if (result.newProfBonus > 0) {
      updated['proficiency_bonus'] = result.newProfBonus;
    }

    // New feat pick OR fighting-style pick — append to the resolver's
    // `feat_ids` (effect side-channel) AND the visible `feats` relation list
    // so the player sheet renders the new row.
    void appendFeatId(String? id) {
      if (id == null || id.isEmpty) return;
      final list = updated['feat_ids'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      if (!next.contains(id)) next.add(id);
      updated['feat_ids'] = next;

      final featsRaw = updated['feats'];
      final featsList = featsRaw is List
          ? List<dynamic>.from(featsRaw)
          : <dynamic>[];
      final alreadyShown = featsList.any((row) {
        if (row is String) return row == id;
        if (row is Map) return row['id'] == id;
        return false;
      });
      if (!alreadyShown) featsList.add(id);
      updated['feats'] = featsList;
    }

    appendFeatId(result.newFeatId);
    appendFeatId(result.newFightingStyleId);

    if (result.newSpellIds.isNotEmpty) {
      final list = updated['spells_known'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      for (final id in result.newSpellIds) {
        if (id.isEmpty) continue;
        if (!next.contains(id)) next.add(id);
      }
      updated['spells_known'] = next;
    }

    // SRD §1.5: class resource pool maxes (Rage, Ki, Bardic Inspiration,
    // …) computed from class+subclass features. The character carries
    // *remaining* counts forward where they existed before and adds the
    // delta as fresh capacity; a pool that goes away (rare) is dropped.
    if (plan.newResourcePools.isNotEmpty ||
        plan.prevResourcePools.isNotEmpty) {
      final maxOut = <String, dynamic>{};
      final remainingOut = <String, dynamic>{};
      final prevRemainingRaw = updated['class_resource_pools_remaining'];
      int prevRem(String pool, int prevMax) {
        if (prevRemainingRaw is Map) {
          final v = prevRemainingRaw[pool];
          if (v is int) return v;
          if (v is String) return int.tryParse(v) ?? prevMax;
        }
        return prevMax;
      }

      for (final entry in plan.newResourcePools.entries) {
        final pool = entry.key;
        final newMax = entry.value;
        maxOut[pool] = newMax;
        final prevMax = plan.prevResourcePools[pool] ?? 0;
        final base = prevRem(pool, prevMax);
        final delta = newMax - prevMax;
        remainingOut[pool] = (base + delta).clamp(0, newMax);
      }
      updated['class_resource_pools'] = maxOut;
      updated['class_resource_pools_remaining'] = remainingOut;
    }

    _mutate(base.copyWith(
      entity: base.entity.copyWith(fields: updated),
    ));
  }

  /// Action bar shown above the schema fields. Three quick verbs — Level
  /// Up, Short Rest, Long Rest — that wrap the longer-form dialogs so the
  /// player doesn't need to find the level field and bump it by hand.
  Widget _renderRestActions(DmToolColors palette, Character character) {
    // Player verbs — bypass edit-mode gate so mid-session level-up / rest
    // doesn't require flipping to edit.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _levelUp(character),
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('Level Up'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shortRest(character),
            icon: const Icon(Icons.bedtime_outlined, size: 16),
            label: const Text('Short Rest'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _longRest(character),
            icon: const Icon(Icons.nightlight_round, size: 16),
            label: const Text('Long Rest'),
          ),
        ),
      ],
    );
  }

  int _asInt(Object? raw, [int fallback = 0]) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  /// Hit die max value parsed from class entity's `hit_die` field
  /// ('d8' → 8). Returns 0 when unknown.
  int _hitDieMax(Character character, Map<String, Entity> entities) {
    String? firstId(Iterable<String> keys) {
      for (final k in keys) {
        final v = character.entity.fields[k];
        if (v is String && v.isNotEmpty) return v;
        if (v is List) {
          final s = v.whereType<String>().firstWhere(
                (e) => e.isNotEmpty,
                orElse: () => '',
              );
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    final classId = firstId(const ['class_refs', 'class_']);
    if (classId == null) return 0;
    final classEntity = entities[classId];
    final die = classEntity?.fields['hit_die'];
    if (die is! String) return 0;
    final m = RegExp(r'd(\d+)').firstMatch(die);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  int _conModifier(Character character) {
    final score = _asInt(character.entity.fields['con'], 10);
    return ((score - 10) / 2).floor();
  }

  Map<String, Entity> _activeEntities(Character character) {
    return _readEntitiesFor(character);
  }

  /// Entity lookup for [character]. Characters created via the wizard
  /// without picking a world store `worldName == ''` and resolve against
  /// the bundled SRD map. World-bound characters get the active
  /// campaign's entities (merged with builtin so resolver lookups still
  /// find Tier-0 rows on a half-seeded world).
  ///
  /// E1: returns a lazy `CombinedMapView` instead of spreading both
  /// maps into a fresh `{}` per call. Reads are O(1); 20+ field tiles
  /// hitting this helper no longer allocate one 7 K-entry map each.
  Map<String, Entity> _readEntitiesFor(Character character) {
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    if (character.worldName.isEmpty) return builtin;
    final activeCampaign = ref.watch(activeCampaignProvider);
    if (activeCampaign != character.worldName) return builtin;
    final campaign = ref.watch(entityProvider);
    if (campaign.isEmpty) return builtin;
    return UnmodifiableMapView<String, Entity>(
      CombinedMapView<String, Entity>([campaign, builtin]),
    );
  }

  Future<void> _levelUp(Character character) async {
    final totalLevel = _asInt(character.entity.fields['level'], 1);
    if (totalLevel >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already at level 20.')),
      );
      return;
    }
    final entities = _activeEntities(character);
    final classLevels = _readClassLevels(character);

    // Multiclass picker: existing classes + "Add new class". Single-class
    // characters (one entry) bypass the dialog when there's no scenario
    // to disambiguate — straight to the level-up flow.
    final pick = await _pickLevelUpClass(
      character: character,
      entities: entities,
      classLevels: classLevels,
    );
    if (pick == null || !mounted) return;
    final targetClassId = pick.classId;
    final isNewClass = pick.isNew;

    final prevClassLevel = classLevels[targetClassId] ?? 0;
    if (prevClassLevel >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pick.classLabel} already at level 20.')),
      );
      return;
    }
    final nextClassLevel = prevClassLevel + 1;
    final nextClassLevels = {
      ...classLevels,
      targetClassId: nextClassLevel,
    };
    final newTotal = totalCharacterLevel(nextClassLevels);

    final classRefs = <String>{
      ...?_readStringList(character.entity.fields['class_refs']),
      targetClassId,
    }.toList();

    final updated = {
      ...character.entity.fields,
      'class_levels': nextClassLevels.map((k, v) => MapEntry(k, v)),
      'class_refs': classRefs,
      'level': newTotal,
    };
    final nextCharacter = character.copyWith(
      entity: character.entity.copyWith(fields: updated),
    );
    _mutate(nextCharacter);
    await _maybeRunLevelUp(
      from: prevClassLevel,
      to: nextClassLevel,
      base: nextCharacter,
      entities: entities,
      targetClassId: targetClassId,
      isNewClass: isNewClass,
    );
  }

  Map<String, int> _readClassLevels(Character character) {
    final raw = character.entity.fields['class_levels'];
    final out = <String, int>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key?.toString();
        if (k == null || k.isEmpty) continue;
        final v = e.value;
        final lvl = v is int ? v : int.tryParse('$v');
        if (lvl == null || lvl <= 0) continue;
        out[k] = lvl;
      }
    }
    // Back-compat: pre-multiclass characters set `class_refs` + flat `level`
    // and never wrote `class_levels`. Treat the primary class_ref + level
    // as the canonical single-class map so `_levelUp` works on legacy data.
    if (out.isEmpty) {
      final refs = character.entity.fields['class_refs'];
      String? primary;
      if (refs is List) {
        for (final r in refs) {
          if (r is String && r.isNotEmpty) {
            primary = r;
            break;
          }
        }
      } else if (refs is String && refs.isNotEmpty) {
        primary = refs;
      }
      final lvl = _asInt(character.entity.fields['level'], 1);
      if (primary != null && lvl > 0) {
        out[primary] = lvl;
      }
    }
    return out;
  }

  List<String>? _readStringList(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) return [raw];
    return null;
  }

  /// Class picker for level-up. Single-class characters with no `class_refs`
  /// entries beyond the primary class auto-pick that one. Otherwise shows
  /// a dialog listing each current class (with its current level) plus an
  /// "Add new class" row that opens a secondary picker over every class
  /// entity not already taken. SRD §1.10 prereq is checked on entry to a
  /// new class; failure shows a warning banner but doesn't block.
  Future<_LevelUpPick?> _pickLevelUpClass({
    required Character character,
    required Map<String, Entity> entities,
    required Map<String, int> classLevels,
  }) async {
    if (classLevels.isEmpty) {
      return null;
    }
    final picked = await showDialog<_LevelUpPick>(
      context: context,
      builder: (ctx) => _LevelUpClassPicker(
        classLevels: classLevels,
        entities: entities,
        abilityScores: _readAbilityScores(character),
      ),
    );
    return picked;
  }

  /// Pick the subclass id matching [classId] via its `parent_class_ref`.
  /// Single-subclass characters with a list-typed `subclass_refs` still work
  /// (returns the first / only entry) — only the rare multi-subclass case
  /// needs the parent-class match. Returns null when no match exists.
  String? _subclassForClass({
    required Character base,
    required Map<String, Entity> entities,
    required String? classId,
  }) {
    final raw = base.entity.fields['subclass_refs'] ??
        base.entity.fields['subclass_id'];
    final ids = <String>[];
    if (raw is List) {
      for (final r in raw) {
        if (r is String && r.isNotEmpty) ids.add(r);
      }
    } else if (raw is String && raw.isNotEmpty) {
      ids.add(raw);
    }
    if (ids.isEmpty) return null;
    if (classId == null || ids.length == 1) return ids.first;
    for (final id in ids) {
      final sub = entities[id];
      if (sub == null) continue;
      final parentRef = sub.fields['parent_class_ref'];
      if (parentRef is Map) {
        final parentName = parentRef['name']?.toString();
        if (parentName != null && entities[classId]?.name == parentName) {
          return id;
        }
      }
    }
    return ids.first;
  }

  Map<String, int> _readAbilityScores(Character character) {
    final out = <String, int>{};
    final stat = character.entity.fields['stat_block'];
    final statMap = stat is Map ? Map<String, dynamic>.from(stat) : null;
    for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
      final lower = k.toLowerCase();
      final v = character.entity.fields[lower] ??
          character.entity.fields[k] ??
          statMap?[k] ??
          statMap?[lower];
      out[k] = _asInt(v, 10);
    }
    return out;
  }

  Future<void> _shortRest(Character character) async {
    final entities = _activeEntities(character);
    final fields = character.entity.fields;
    final level = _asInt(fields['level'], 1);
    final maxHp = _asInt(fields['max_hp'], 0);
    final hp = _asInt(fields['hp'], 0);
    final dieMax = _hitDieMax(character, entities);
    final conMod = _conModifier(character);
    final maxHd = level;
    final hdRemaining = fields.containsKey('hit_dice_remaining')
        ? _asInt(fields['hit_dice_remaining'], maxHd)
        : maxHd;

    if (hdRemaining <= 0 || dieMax <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dieMax <= 0
              ? 'No class hit die data — set a class first.'
              : 'No hit dice left to spend.'),
        ),
      );
      return;
    }

    final spent = await _ShortRestDialog.show(
      context,
      hdRemaining: hdRemaining,
      dieMax: dieMax,
      conMod: conMod,
    );
    if (spent == null || !mounted) return;
    final dice = spent.dice;
    final restored = spent.restored;
    if (dice <= 0) return;

    final newHp = (hp + restored).clamp(0, maxHp);
    final newHdRemaining = (hdRemaining - dice).clamp(0, maxHd);
    final updated = {
      ...fields,
      'hp': newHp,
      'hit_dice_remaining': newHdRemaining,
    };
    _mutate(character.copyWith(
      entity: character.entity.copyWith(fields: updated),
    ));
  }

  Future<void> _longRest(Character character) async {
    final fields = character.entity.fields;
    final level = _asInt(fields['level'], 1);
    final maxHp = _asInt(fields['max_hp'], 0);
    final maxHd = level;
    final hdRemaining = fields.containsKey('hit_dice_remaining')
        ? _asInt(fields['hit_dice_remaining'], maxHd)
        : maxHd;
    final regained = (maxHd ~/ 2).clamp(1, maxHd);
    final newHd = (hdRemaining + regained).clamp(0, maxHd);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Long Rest'),
        content: Text(
          'Restore HP to full ($maxHp), regain $regained Hit Die'
          '${regained == 1 ? '' : 's'} '
          '(now $newHd/$maxHd), and reset class resources. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rest'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final updated = {
      ...fields,
      if (maxHp > 0) 'hp': maxHp,
      'hit_dice_remaining': newHd,
    };
    _mutate(character.copyWith(
      entity: character.entity.copyWith(fields: updated),
    ));
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

/// Outcome of [_LevelUpClassPicker]. [classId] names the class being
/// advanced; [isNew] is true when the user picked "Add new class" and
/// confirmed the SRD §1.10 prereq dialog. [classLabel] is the entity name
/// for snackbar/error messages.
class _LevelUpPick {
  final String classId;
  final String classLabel;
  final bool isNew;
  const _LevelUpPick({
    required this.classId,
    required this.classLabel,
    required this.isNew,
  });
}

/// First-step dialog of the multi-class level-up flow. Shows each existing
/// class with its current level + an "Add new class" row. The secondary
/// picker shows all class entities not already taken and validates SRD
/// §1.10 ability prereqs against [abilityScores] — failures show a
/// warning banner but the player can confirm anyway (rule-zero / homebrew).
class _LevelUpClassPicker extends StatelessWidget {
  final Map<String, int> classLevels;
  final Map<String, Entity> entities;
  final Map<String, int> abilityScores;

  const _LevelUpClassPicker({
    required this.classLevels,
    required this.entities,
    required this.abilityScores,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    classLevels.forEach((classId, level) {
      final entity = entities[classId];
      final label = entity?.name ?? classId;
      rows.add(ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text('Current level $level → ${level + 1}'),
        onTap: level >= 20
            ? null
            : () => Navigator.of(context).pop(
                  _LevelUpPick(
                      classId: classId, classLabel: label, isNew: false),
                ),
        enabled: level < 20,
      ));
    });
    rows.add(const Divider());
    rows.add(ListTile(
      dense: true,
      leading: const Icon(Icons.add_circle_outline),
      title: const Text('Add new class (multiclass)'),
      onTap: () async {
        final pick = await _showAddClassDialog(context);
        if (pick != null && context.mounted) {
          Navigator.of(context).pop(pick);
        }
      },
    ));

    return AlertDialog(
      title: const Text('Level Up — Choose Class'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<_LevelUpPick?> _showAddClassDialog(BuildContext context) {
    final available = entities.values
        .where((e) => e.categorySlug == 'class')
        .where((e) => !classLevels.containsKey(e.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other classes available.')),
      );
      return Future.value(null);
    }
    return showDialog<_LevelUpPick>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Multiclass: New Class'),
        children: [
          for (final cls in available)
            SimpleDialogOption(
              onPressed: () async {
                final check = checkMulticlassPrereq(
                  classEntity: cls,
                  entities: entities,
                  abilityScores: abilityScores,
                );
                if (!check.met) {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (warn) => AlertDialog(
                      title: Text('${cls.name} prereq not met'),
                      content: Text(
                        '${check.reason}\n\nProceed anyway (homebrew / rule-zero)?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(warn, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(warn, true),
                          child: const Text('Proceed'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !ctx.mounted) return;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(
                  _LevelUpPick(
                      classId: cls.id, classLabel: cls.name, isNew: true),
                );
              },
              child: Text(cls.name),
            ),
        ],
      ),
    );
  }
}

class _ShortRestSpend {
  final int dice;
  final int restored;
  const _ShortRestSpend({required this.dice, required this.restored});
}

/// Modal for SRD short rest: pick N hit dice, sum die roll + Con modifier
/// per die, return total HP to restore. Returns null on cancel.
class _ShortRestDialog extends StatefulWidget {
  final int hdRemaining;
  final int dieMax;
  final int conMod;

  const _ShortRestDialog({
    required this.hdRemaining,
    required this.dieMax,
    required this.conMod,
  });

  static Future<_ShortRestSpend?> show(
    BuildContext context, {
    required int hdRemaining,
    required int dieMax,
    required int conMod,
  }) {
    return showDialog<_ShortRestSpend>(
      context: context,
      builder: (_) => _ShortRestDialog(
        hdRemaining: hdRemaining,
        dieMax: dieMax,
        conMod: conMod,
      ),
    );
  }

  @override
  State<_ShortRestDialog> createState() => _ShortRestDialogState();
}

class _ShortRestDialogState extends State<_ShortRestDialog> {
  int _dice = 1;
  List<int> _rolls = const [];
  final Random _rng = Random();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final hint =
        palette?.sidebarLabelSecondary ?? Theme.of(context).hintColor;
    final restored = _rolls.fold<int>(0, (a, b) => a + b) +
        (_rolls.length * widget.conMod);
    return AlertDialog(
      title: const Text('Short Rest'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hit Dice available: ${widget.hdRemaining}  ·  d${widget.dieMax}  ·  '
              'Con mod: ${widget.conMod >= 0 ? '+' : ''}${widget.conMod}',
              style: TextStyle(fontSize: 12, color: hint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Dice to spend:'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _dice <= 1
                      ? null
                      : () => setState(() {
                            _dice -= 1;
                            _rolls = const [];
                          }),
                ),
                Text('$_dice',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _dice >= widget.hdRemaining
                      ? null
                      : () => setState(() {
                            _dice += 1;
                            _rolls = const [];
                          }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.casino, size: 16),
              label: Text(_rolls.isEmpty
                  ? 'Roll ${_dice}d${widget.dieMax}'
                  : 'Re-roll ${_dice}d${widget.dieMax}'),
              onPressed: () => setState(() {
                _rolls = [
                  for (var i = 0; i < _dice; i++)
                    1 + _rng.nextInt(widget.dieMax),
                ];
              }),
            ),
            if (_rolls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Rolls: ${_rolls.join(', ')}  '
                '(+ ${_rolls.length} × ${widget.conMod} Con)',
                style: TextStyle(fontSize: 12, color: hint),
              ),
              const SizedBox(height: 4),
              Text(
                'HP restored: $restored',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _rolls.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _ShortRestSpend(dice: _dice, restored: restored),
                  ),
          child: const Text('Apply'),
        ),
      ],
    );
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
        const itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
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

/// E5/E6: header stat-chip strip with scoped name watches. Watches the
/// entity provider via `.select` so only the two resolved names trigger a
/// rebuild — the rest of the editor frame doesn't repaint this strip.
class _StatChipsHeader extends ConsumerWidget {
  final Character character;
  final DmToolColors palette;
  const _StatChipsHeader({required this.character, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = characterRaceClassIds(character);
    final useCampaign = character.worldName.isNotEmpty &&
        ref.watch(activeCampaignProvider) == character.worldName;

    String resolve(String? id) {
      if (id == null) return '—';
      if (useCampaign) {
        final name =
            ref.watch(entityProvider.select((m) => m[id]?.name));
        if (name != null && name.isNotEmpty) return name;
      }
      final builtinName = ref.watch(
        builtinSrdEntitiesProvider.select((m) => m[id]?.name),
      );
      return (builtinName != null && builtinName.isNotEmpty)
          ? builtinName
          : '—';
    }

    return RepaintBoundary(
      child: CharacterStatChips(
        lines: characterStatLinesWithNames(
          character,
          raceName: resolve(ids.raceId),
          className: resolve(ids.classId),
        ),
        palette: palette,
      ),
    );
  }
}

