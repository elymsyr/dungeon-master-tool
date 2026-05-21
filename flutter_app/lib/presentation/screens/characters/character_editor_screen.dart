import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/character_creation/level_up_planner.dart';
import '../../../application/character_creation/multiclass_helper.dart';
import '../../../application/character_creation/pending_choices.dart';
import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/connectivity_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/sync_engine_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/outbox_status_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../../application/services/builtin_srd_entities.dart';
import '../../../application/services/entity_media_cleanup_service.dart';
import '../../../application/services/marketplace_cover_sync_service.dart';
import '../../../application/services/image_upload_helper.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../data/network/network_providers.dart';
import '../../widgets/character_stat_chips.dart';
import 'level_up_dialog.dart';
import 'pending_choice_resolver_dialog.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/character_ext.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/character_resolver.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/asset_ref_image.dart';
import '../../widgets/class_level_up_table.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/pending_choices_badge.dart';
import '../../widgets/perf/image_cache_size.dart';
import '../../widgets/resolved_grants_card.dart';
import '../../widgets/save_info_section.dart';
import '../../widgets/save_sync_shared.dart';
import '../database/entity_card.dart';

/// Standalone character editor. Hub-level Characters tab'dan push edilir.
/// Bir Character'ı template'inin Player kategorisine göre render eder.
///
/// When `onClose` is non-null the screen is rendered embedded (player tab /
/// world sidebar). The AppBar collapses to back + name + view/edit + undo/redo
/// + save-sync and the back arrow calls `onClose` instead of popping the
/// route. Global actions (theme/language/import/bug) drop since the host
/// shell already exposes them.
class CharacterEditorScreen extends ConsumerStatefulWidget {
  final String characterId;
  final VoidCallback? onClose;

  const CharacterEditorScreen({
    super.key,
    required this.characterId,
    this.onClose,
  });

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState
    extends ConsumerState<CharacterEditorScreen> {
  Character? _working;
  bool _saving = false;
  bool _readOnly = true;
  bool _grantsBackfilled = false;

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

  // Captured at initState — Riverpod marks `ref` disposed before
  // `state.dispose()` runs during unmount, so we cannot `ref.read(...)` in
  // dispose(). Hold a direct reference to flush any pending writes.
  PendingWriteBuffer? _pendingBuffer;

  @override
  void initState() {
    super.initState();
    _pendingBuffer = ref.read(pendingWriteBufferProvider);
    // Cross-device freshness: another device may have pushed a newer
    // cloud_backup while we were away. Pull on open so the editor renders
    // the latest payload instead of stale local state. Skips silently when
    // local is already at least as new.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      ref
          .read(characterListProvider.notifier)
          .pullCharFromCloudIfNewer(widget.characterId);
    });
  }

  @override
  void dispose() {
    _undoIdleTimer?.cancel();
    // Dispose sırasında bekleyen debounced write varsa hemen fire et —
    // kullanıcı back tuşunu atlatarak (router pop, app close) çıkarsa
    // son edit'in kaybolmasını önle.
    // ignore: discarded_futures
    _pendingBuffer?.flushPrefix('character:${widget.characterId}');
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
      // No setState — `_canUndo` is invariant across the baseline → stack
      // transition (true before AND after), so no visible state changes.
      // Dropping the full-editor rebuild that used to fire 400 ms after
      // every keystroke.
    });
    _scheduleAutoSave();
  }

  bool get _canUndo => _undoStack.isNotEmpty || _undoBaseline != null;
  bool get _canRedo => _redoStack.isNotEmpty;

  /// 039 model edit permission: owner VEYA world DM. Auth yoksa true (pure
  /// offline). World-bound karakterde DM role lookup `worldId` (canonical) ile
  /// yapılır; eski `worldName` set ama `worldId` null durumunda DM gate
  /// kapalıdır — kullanıcı bir kez save edip worldId hidratasyonu olunca açılır.
  bool get _canEdit {
    final c = _working;
    if (c == null) return false;
    final selfUid = ref.read(authProvider)?.uid;
    if (selfUid == null) return true;
    if (c.ownerId == selfUid) return true;
    final wid = c.worldId;
    if (wid == null) return false;
    final role = ref.read(worldRoleProvider(wid)).valueOrNull;
    return role == WorldRole.dm;
  }

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

  /// Worlds parity: edit'leri row-level debounce et ve gecikmeli olarak
  /// `characterListProvider.update()` ile diske + outbox'a yaz. Aynı key
  /// (`character:$id`) ardışık fire'larda son `_working` snapshot'ını yazar
  /// (coalesced). Owner/DM yetkisi yoksa fire silent no-op.
  ///
  /// Sidebar embed: widget close → State dispose → Riverpod marks `ref`
  /// disposed → pending action `ref.read(...)` throws → save lost. Capture
  /// the notifier + a snapshot of `_working` at schedule time so the
  /// deferred fire is independent of widget lifecycle.
  void _scheduleAutoSave({WriteKind kind = WriteKind.shortText}) {
    final c = _working;
    if (c == null) return;
    if (!_canEdit) return;
    final id = c.id;
    final notifier = ref.read(characterListProvider.notifier);
    ref.read(pendingWriteBufferProvider).schedule(
          key: 'character:$id',
          kind: kind,
          action: () async {
            final cur = _working ?? c;
            if (cur.id != id) return;
            await notifier.update(cur);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Cross-device freshness: when the cloud-pull (initState) replaces the
    // local Character with a newer payload, adopt it into `_working` so the
    // editor renders the new data instead of the stale snapshot it cached
    // on first build. Auto-save kaldırıldı; user actively editing iken
    // bile cloud-newer geldiğinde overwrite ediyoruz (kullanıcı Save'e
    // basana kadar `_working` zaten kaydedilmiş değil — tek meşru kaynak
    // cloud).
    ref.listen<Character?>(
      characterByIdProvider(widget.characterId),
      (prev, next) {
        if (next == null || !mounted) return;
        final working = _working;
        if (working == null) return;
        final nextAt = DateTime.tryParse(next.updatedAt);
        final workingAt = DateTime.tryParse(working.updatedAt);
        if (nextAt == null || workingAt == null) return;
        if (!nextAt.isAfter(workingAt)) return;
        setState(() => _working = next);
      },
    );
    final character =
        _working ?? ref.watch(characterByIdProvider(widget.characterId));

    if (character == null) {
      final onClose = widget.onClose;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: 'Back',
                onPressed: () {
                  if (onClose != null) {
                    onClose();
                  } else {
                    context.pop();
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Text('Character'),
            ],
          ),
        ),
        body: const Center(child: Text('Character not found.')),
      );
    }

    _working ??= character;
    _backfillDefensesFromResolverIfNeeded();

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
    final embedded = widget.onClose != null;
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
              if (!embedded) const AppIconImage(size: 22),
              if (!embedded) const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        character.entity.name.isEmpty
                            ? 'Character'
                            : character.entity.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        template.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.sidebarLabelSecondary,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // View / Edit toggle — gated by _canEdit (owner VEYA world DM).
            // Yetki yoksa görüntü-only zorla, toggle disable.
            if (!_canEdit && !_readOnly) ...[
              const SizedBox.shrink(),
            ],
            IconButton(
              icon: Icon(_readOnly ? Icons.visibility : Icons.edit,
                  size: 20),
              tooltip: _canEdit
                  ? (_readOnly ? 'View' : 'Edit')
                  : 'Read-only (not owner)',
              onPressed: !_canEdit
                  ? null
                  : () => setState(() => _readOnly = !_readOnly),
              visualDensity: VisualDensity.compact,
            ),
            // Undo / Redo — available in view mode too, since pending
            // upgrade resolution + dismiss/restore bypass the edit gate
            // and the user explicitly asked for those mutations to be
            // undoable/redoable from anywhere.
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              tooltip: 'Undo',
              onPressed: !_canUndo ? null : _undo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              tooltip: 'Redo',
              onPressed: !_canRedo ? null : _redo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            // Cloud save & sync — desktop/tablet only. On phone the entry
            // moves into the overflow menu below to free AppBar space.
            if (getScreenType(context) != ScreenType.phone)
              _CharacterSaveSyncButton(
                character: character,
                saving: _saving,
                flushLocal: () => _save(silent: true),
              ),
            // Embedded mode (player tab / world sidebar host): drop global
            // actions — host shell already surfaces them.
            if (!embedded && getScreenType(context) == ScreenType.phone) ...[
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'sync':
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => _CharacterSaveSyncDialog(
                          character: character,
                          flushLocal: () => _save(silent: true),
                        ),
                      );
                    case 'import':
                      ImportPackageDialog.show(context);
                    case 'bug':
                      BugReportDialog.show(context);
                    default:
                      if (action.startsWith('theme:')) {
                        ref.read(themeProvider.notifier).setTheme(action.substring(6));
                      }
                      if (action.startsWith('lang:')) {
                        ref.read(localeProvider.notifier).setLocale(action.substring(5));
                      }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'sync', child: Row(children: [
                    Icon(_saving ? Icons.cloud_upload : Icons.cloud_done, size: 18, color: palette.sidebarLabelSecondary),
                    const SizedBox(width: 8),
                    Text(_saving ? 'Saving...' : 'Save & Sync'),
                  ])),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'import', child: Row(children: [const Icon(Icons.inventory_2, size: 18), const SizedBox(width: 8), Text(l10n.importPackage)])),
                  const PopupMenuDivider(),
                  ...themeNames.map((name) => PopupMenuItem(
                    value: 'theme:$name',
                    child: Row(children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: themePalettes[name]?.canvasBg, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
                      const SizedBox(width: 8),
                      Text(name[0].toUpperCase() + name.substring(1)),
                    ]),
                  )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'lang:en', child: Text('English')),
                  const PopupMenuItem(value: 'lang:tr', child: Text('Türkçe')),
                  const PopupMenuItem(value: 'lang:de', child: Text('Deutsch')),
                  const PopupMenuItem(value: 'lang:fr', child: Text('Français')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'bug', child: Row(children: [Icon(Icons.bug_report_outlined, size: 18), SizedBox(width: 8), Text('Report a Bug')])),
                ],
              ),
            ] else if (!embedded) ...[
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
            ],
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
            child: LayoutBuilder(builder: (ctx, c) {
              final isPhone = c.maxWidth < 600;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? c.maxWidth : 760,
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _entityHeader(palette, character, template),
                  const SizedBox(height: 12),
                  _renderRestActions(palette, character),
                  const SizedBox(height: 16),
                  ..._renderResolvedGrants(palette, character),
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
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Resolves the world label shown in headers/settings. Display canonical
  /// olarak `worldId` üzerinden `campaignInfoListProvider`'den ad çözer.
  String _displayWorldLabelFor(Character c, L10n l10n) {
    final infos = ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final label = c.resolvedWorldName(infos);
    return label.isEmpty ? l10n.charWorldOrphan : label;
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
    final subtitle =
        '${template.name} · ${_displayWorldLabelFor(c, l10n)}';

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
    final pendingCount =
        readPendingChoices(entity.fields['pending_choices']).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
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
                    // AssetRefImage: portre `dmt-public://` (ücretsiz Supabase)
                    // ref'i olabilir — ham `File()` bunu çözemez, ikinci
                    // cihazda kırık görünürdü. Resolver local/public/cloud
                    // hepsini çözer + SHA-cache'ler.
                    ? AssetRefImage(
                        ref: AssetRef(entity.imagePath),
                        fit: BoxFit.cover,
                        // Decode on a single axis only — passing both
                        // cacheWidth and cacheHeight stretches the bitmap to
                        // those exact dims, squishing the portrait before
                        // BoxFit.cover can crop it.
                        cacheHeight: cachePxFromLogical(context, 260),
                        placeholder: portraitPlaceholder(),
                        errorWidget: portraitPlaceholder(),
                      )
                    : portraitPlaceholder(),
              ),
            ),
            if (pendingCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: pendingChoicesBadge(context, pendingCount),
              ),
          ],
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
                onTap: c.worldId == null ? null : () => _openWorld(c),
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

  Future<void> _openWorld(Character c) async {
    final worldId = c.worldId;
    if (worldId == null) return;
    final infos = ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final worldName = c.resolvedWorldName(infos);
    if (worldName.isEmpty) return;
    await _save(silent: true);
    if (!mounted) return;
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-world-$worldId',
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
    final oldRef = c.entity.imagePath;

    // Eager upload the portrait to the free-media bucket (quota-exempt) so the
    // `dmt-public://` ref is portable across devices immediately — mirrors
    // `_pickCover`. Offline / failure → keep the local path; the portrait
    // bundles later via the character outbox / cloud-backup push.
    // Cloud upload is a beta feature — non-beta users keep a local path.
    final svc = ref.read(isBetaActiveProvider)
        ? ref.read(freeMediaServiceProvider)
        : null;
    final newRef = await uploadCharacterPortraitRef(
      svc,
      localPath: path,
      scopeId: c.worldId ?? c.id,
    );
    if (!mounted) return;
    _mutate(c.copyWith(entity: c.entity.copyWith(imagePath: newRef)));
    // Persist + push now so the portrait reaches the cloud without waiting
    // for the autosave debounce.
    await _flushAndPush();

    // Portre değiştiyse eski cloud resmini best-effort sil.
    if (!mounted) return;
    if (ref.read(authProvider) != null) {
      final cleanup = ref.read(entityMediaCleanupServiceProvider);
      // ignore: discarded_futures
      cleanup
          ?.cleanupReplacedRef(oldRef: oldRef, newRef: newRef)
          .catchError(
            (Object e) => debugPrint('portrait cleanup error: $e'),
          );
      // Portre değiştiyse publish edilmiş listing banner'larını da tazele.
      final coverSync = ref.read(marketplaceCoverSyncServiceProvider);
      // ignore: discarded_futures
      coverSync
          ?.syncCover(
            itemType: 'character',
            localId: c.id,
            oldRef: oldRef,
            newRef: newRef,
          )
          .catchError(
            (Object e) => debugPrint('portrait cover sync error: $e'),
          );
    }
  }

  /// Drains the pending debounced write, persists, flushes the cloud
  /// snapshot, and forces the outbox push. Shared by [_saveAndClose] and
  /// [_pickPortrait] so a freshly picked portrait syncs immediately.
  Future<void> _flushAndPush() async {
    // Pending debounced write'ı önce drain et — buffer fire'ı zaten
    // characterListProvider.update() çağırıyor (disk + sync push).
    try {
      await ref
          .read(pendingWriteBufferProvider)
          .flushPrefix('character:${widget.characterId}');
    } catch (_) {/* best-effort */}
    await _save(silent: true);
    // Flush cloud snapshot (beta + non-online-world chars). Mirror-route
    // chars are already pushed from `update()`.
    try {
      await ref
          .read(characterListProvider.notifier)
          .flushCloudBackup(widget.characterId);
    } catch (_) {/* best-effort */}
    // Online ise outbox push'unu zorla — slow tier cloudDelay (10s)
    // beklemeden network'e gitsin.
    final online = ref.read(connectivityStreamProvider).valueOrNull ?? false;
    if (online) {
      try {
        await ref.read(syncEngineProvider).forceTick();
      } catch (_) {/* best-effort */}
    }
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
      // Identity group splices in the subspecies / ancestry picker right
      // after the species_ref tile so the lineage choice sits next to its
      // parent species (no schema field needed — the resolver already
      // reads `subspecies_id` from PC fields).
      final children = <Widget>[];
      for (final f in list) {
        children.add(_fieldTile(f, character));
        if (f.fieldKey == 'species_ref') {
          children.add(_subspeciesPickerTile(character));
        }
      }
      widgets.add(EntityCardCollapsibleGroupCard(
        group: g,
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ));
    }
    return widgets;
  }

  /// One-shot defensive backfill: if the PC's raw defense ref fields are
  /// empty but the resolver computed grants from race / class / subclass,
  /// copy those resolved ids onto the PC entity. Fixes the common case
  /// where a character was created before PR-A1 landed, or where the
  /// wizard's seed never wrote the fields for some reason. Runs once per
  /// editor lifecycle so manual edits aren't fought.
  void _backfillDefensesFromResolverIfNeeded() {
    if (_grantsBackfilled) return;
    final w = _working;
    if (w == null) return;
    final effective =
        ref.read(effectiveCharacterProvider(w.entity.id));
    if (effective == null) return;
    final fields = w.entity.fields;

    bool isEmptyList(Object? raw) {
      if (raw == null) return true;
      if (raw is List) return raw.isEmpty;
      return false;
    }

    final pairs = <(String, List<String>)>[
      ('resistance_refs', effective.damageResistanceIds),
      ('damage_immunity_refs', effective.damageImmunityIds),
      ('vulnerability_refs', effective.damageVulnerabilityIds),
      ('condition_immunity_refs', effective.conditionImmunityIds),
      ('senses', effective.senseEntityIds),
    ];

    final updated = <String, dynamic>{};
    for (final pair in pairs) {
      final key = pair.$1;
      final resolvedIds = pair.$2;
      if (resolvedIds.isEmpty) continue;
      if (!isEmptyList(fields[key])) continue;
      updated[key] = List<String>.from(resolvedIds);
    }
    _grantsBackfilled = true;
    if (updated.isEmpty) return;
    final nextFields = {...fields, ...updated};
    _working = w.copyWith(entity: w.entity.copyWith(fields: nextFields));
    _scheduleAutoSave();
  }

  /// Render the resolver-derived grant summary (senses, resistances,
  /// immunities, condition immunities, vulnerabilities). Reads from the
  /// `effectiveCharacterProvider` so feat / class-feature auto-grants that
  /// don't land on raw PC ref fields still surface to the player.
  List<Widget> _renderResolvedGrants(
      DmToolColors palette, Character character) {
    final effective =
        ref.watch(effectiveCharacterProvider(character.entity.id));
    if (effective == null) return const [];
    final entities = _readEntitiesFor(character);
    final remaining = _readGrantedPoolRemaining(character);
    final (slotsMax, slotsRemaining) = _readSpellSlotsState(character);
    return [
      ResolvedGrantsCard(
        effective: effective,
        entities: entities,
        palette: palette,
        poolRemaining: remaining,
        onPoolRemainingChanged: _writeGrantedPoolRemaining,
        spellSlotsMax: slotsMax,
        spellSlotsRemaining: slotsRemaining,
        onSpellSlotsRemainingChanged: _writeSpellSlotsRemaining,
      ),
    ];
  }

  /// Reads the PC's `spell_slots` field into (max, remaining) maps. Returns
  /// `(null, null)` when the field is missing or malformed so the Font of
  /// Magic conversion button stays hidden for non-casters.
  (Map<int, int>?, Map<int, int>?) _readSpellSlotsState(Character character) {
    final raw = character.entity.fields['spell_slots'];
    if (raw is! Map) return (null, null);
    Map<int, int>? readSide(Object? side) {
      if (side is! Map) return null;
      final out = <int, int>{};
      side.forEach((k, v) {
        final ki = k is int ? k : int.tryParse('$k');
        if (ki == null) return;
        final vi = v is int ? v : int.tryParse('$v');
        if (vi == null) return;
        out[ki] = vi;
      });
      return out.isEmpty ? null : out;
    }

    return (readSide(raw['max']), readSide(raw['remaining']));
  }

  void _writeSpellSlotsRemaining(Map<int, int> nextRemaining) {
    final w = _working;
    if (w == null) return;
    final fields = Map<String, dynamic>.from(w.entity.fields);
    final raw = fields['spell_slots'];
    final maxOut = <String, int>{};
    if (raw is Map && raw['max'] is Map) {
      (raw['max'] as Map).forEach((k, v) {
        if (v is int) maxOut[k.toString()] = v;
      });
    }
    final remOut = <String, int>{
      for (final e in nextRemaining.entries) e.key.toString(): e.value,
    };
    fields['spell_slots'] = {'max': maxOut, 'remaining': remOut};
    setState(() {
      _working = w.copyWith(entity: w.entity.copyWith(fields: fields));
    });
    _scheduleAutoSave();
  }

  Map<String, int> _readGrantedPoolRemaining(Character character) {
    final raw = character.entity.fields['granted_pool_uses_remaining'];
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (k is! String) return;
      if (v is int) {
        out[k] = v;
      } else if (v is String) {
        final n = int.tryParse(v);
        if (n != null) out[k] = n;
      }
    });
    return out;
  }

  void _writeGrantedPoolRemaining(Map<String, int> next) {
    final w = _working;
    if (w == null) return;
    final fields = Map<String, dynamic>.from(w.entity.fields);
    if (next.isEmpty) {
      fields.remove('granted_pool_uses_remaining');
    } else {
      fields['granted_pool_uses_remaining'] = next;
    }
    setState(() {
      _working = w.copyWith(entity: w.entity.copyWith(fields: fields));
    });
    _scheduleAutoSave();
  }

  /// Pending level-up decisions that should attach a `!` badge to the
  /// given schema field's tile. Returns an empty list when the character
  /// has no pending decisions matching that field key.
  List<PendingChoice> _pendingChoicesForField(
      Character character, String fieldKey) {
    final raw = character.entity.fields['pending_choices'];
    final list = readPendingChoices(raw);
    if (list.isEmpty) return const [];
    return list
        .where((p) =>
            !p.dismissed &&
            pendingChoiceFieldHints(p.kind).contains(fieldKey))
        .toList();
  }

  Future<void> _resolvePendingChoice(
      Character character, PendingChoice choice) async {
    final entities = _readEntitiesFor(character);

    final abilityScores = <String, int>{};
    final statBlock = character.entity.fields['stat_block'];
    final statBlockMap =
        statBlock is Map ? Map<String, dynamic>.from(statBlock) : null;
    for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
      final lower = k.toLowerCase();
      final v = character.entity.fields[lower] ??
          character.entity.fields[k] ??
          statBlockMap?[k] ??
          statBlockMap?[lower];
      abilityScores[k] = _asInt(v, 10).clamp(1, 30);
    }

    final existingFeatIds = <String>{};
    final rawFeats = character.entity.fields['feat_ids'];
    if (rawFeats is List) {
      for (final id in rawFeats) {
        if (id is String && id.isNotEmpty) existingFeatIds.add(id);
      }
    }
    final existingSpellIds = <String>{};
    void collectSpells(Object? raw) {
      if (raw is List) {
        for (final id in raw) {
          if (id is String && id.isNotEmpty) existingSpellIds.add(id);
        }
      }
    }
    collectSpells(character.entity.fields['spells_known']);
    collectSpells(character.entity.fields['prepared_spells']);

    final existingSkillNames = <String>{};
    final expertiseSkillNames = <String>{};
    final rawSkills = character.entity.fields['skills'];
    if (rawSkills is Map) {
      final rows = rawSkills['rows'];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final isExp = row['expertise'] == true;
          if (row['proficient'] == true || isExp) {
            final n = row['name'];
            if (n is String && n.isNotEmpty) {
              existingSkillNames.add(n);
              if (isExp) expertiseSkillNames.add(n);
            }
          }
        }
      }
    }

    final existingToolIds = <String>{};
    final rawTools = character.entity.fields['tool_proficiencies'];
    if (rawTools is List) {
      for (final id in rawTools) {
        if (id is String && id.isNotEmpty) existingToolIds.add(id);
      }
    }
    final existingLanguageIds = <String>{};
    for (final key in const ['language_refs', 'languages']) {
      final raw = character.entity.fields[key];
      if (raw is List) {
        for (final id in raw) {
          if (id is String && id.isNotEmpty) existingLanguageIds.add(id);
        }
      }
    }
    final featChoices = <String, String>{};
    final rawFeatChoices = character.entity.fields['feat_choices'];
    if (rawFeatChoices is Map) {
      for (final entry in rawFeatChoices.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        if (v is String) featChoices[k] = v;
      }
    }

    final resolution = await showPendingChoiceResolver(
      context,
      choice: choice,
      entities: entities,
      abilityScores: abilityScores,
      existingFeatIds: existingFeatIds,
      existingSpellIds: existingSpellIds,
      existingSkillNames: existingSkillNames,
      expertiseSkillNames: expertiseSkillNames,
      existingToolIds: existingToolIds,
      existingLanguageIds: existingLanguageIds,
      featChoices: featChoices,
    );
    if (!mounted || resolution == null) return;

    _applyPendingResolution(character, choice, resolution);
  }

  void _applyPendingResolution(
    Character character,
    PendingChoice choice,
    PendingChoiceResolution resolution,
  ) {
    final updated = Map<String, dynamic>.from(character.entity.fields);

    // Ability bumps — write to per-ability keys + stat_block (when present).
    final bumps = resolution.abilityBumps;
    if (bumps.isNotEmpty) {
      final statBlock = updated['stat_block'];
      final nextStat = statBlock is Map
          ? Map<String, dynamic>.from(statBlock)
          : null;
      for (final entry in bumps.entries) {
        final code = entry.key;
        final lower = code.toLowerCase();
        if (updated.containsKey(lower)) {
          updated[lower] = _asInt(updated[lower]) + entry.value;
        } else if (updated.containsKey(code)) {
          updated[code] = _asInt(updated[code]) + entry.value;
        } else {
          updated[lower] = (_asInt(updated[lower], 10)) + entry.value;
        }
        if (nextStat != null) {
          final at = nextStat[code] ?? nextStat[lower];
          if (at != null) {
            if (nextStat.containsKey(code)) {
              nextStat[code] = _asInt(at) + entry.value;
            } else {
              nextStat[lower] = _asInt(at) + entry.value;
            }
          }
        }
      }
      if (nextStat != null) updated['stat_block'] = nextStat;
    }

    // Feat / Fighting Style — append to feat_ids + visible feats list.
    final featId = resolution.featId;
    PendingChoice? followOnFeatSkillPick;
    PendingChoice? followOnFeatExpertisePick;
    PendingChoice? followOnFeatAsi;
    if (featId != null && featId.isNotEmpty) {
      final list = updated['feat_ids'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      if (!next.contains(featId)) next.add(featId);
      updated['feat_ids'] = next;

      final featsRaw = updated['feats'];
      final featsList = featsRaw is List
          ? List<dynamic>.from(featsRaw)
          : <dynamic>[];
      final shown = featsList.any((row) {
        if (row is String) return row == featId;
        if (row is Map) return row['id'] == featId;
        return false;
      });
      if (!shown) featsList.add(featId);
      updated['feats'] = featsList;
      // Scan chosen feat for follow-on `bonus_skill_pick_count` (e.g. Skill
      // Expert). Queue a skillProficiency pending choice when present so the
      // player picks the N skills on the spot — mirrors the subclass-pick
      // hook used for Lore L3.
      final ents = _readEntitiesFor(character);
      final featEntity = ents[featId];
      final skillPickCount =
          _asInt(featEntity?.fields['bonus_skill_pick_count']);
      if (skillPickCount > 0) {
        followOnFeatSkillPick = newPendingChoice(
          kind: PendingChoiceKind.skillProficiency,
          level: choice.level,
          classId: choice.classId,
          classLabel: choice.classLabel,
          count: skillPickCount,
        );
      }
      final expertisePickCount =
          _asInt(featEntity?.fields['bonus_expertise_pick_count']);
      if (expertisePickCount > 0) {
        followOnFeatExpertisePick = newPendingChoice(
          kind: PendingChoiceKind.expertise,
          level: choice.level,
          classId: choice.classId,
          classLabel: choice.classLabel,
          count: expertisePickCount,
        );
      }
      // Feat-side ASI sub-pick. Triggers for any feat with `asi_amount > 0`
      // when taken via the asiOrFeat resolution path — Resilient (also grants
      // save prof), Skill Expert, Epic Boons, and most General feats.
      final featAsiAmount = _asInt(featEntity?.fields['asi_amount']);
      if (featAsiAmount > 0) {
        followOnFeatAsi = newPendingChoice(
          kind: PendingChoiceKind.featAsi,
          level: choice.level,
          classId: choice.classId,
          classLabel: choice.classLabel,
          sourceEntityId: featId,
        );
      }
    }

    // Spell ids — append to spells_known. Existing rows may be either
    // plain ID strings or `{id, prepared, …}` maps (the spells field
    // widget round-trips the richer shape). Preserve every prior entry as
    // its original type, then append any new ids whose id isn't already
    // represented. Previously we did `List<String>.from(whereType<String>())`
    // which silently dropped all Map rows — the user's "level-up spells
    // wiped my prepared list" regression.
    if (resolution.spellIds.isNotEmpty) {
      final list = updated['spells_known'];
      final next = <dynamic>[];
      final existingIds = <String>{};
      if (list is List) {
        for (final row in list) {
          next.add(row);
          if (row is String) {
            existingIds.add(row);
          } else if (row is Map) {
            final id = row['id'];
            if (id is String) existingIds.add(id);
          }
        }
      }
      for (final id in resolution.spellIds) {
        if (id.isEmpty || existingIds.contains(id)) continue;
        next.add(id);
        existingIds.add(id);
      }
      updated['spells_known'] = next;
    }

    // Subclass id — append to subclass_refs (multiclass supports many
    // entries; pick keeps prior subclasses for other classes intact).
    final subId = resolution.subclassId;
    PendingChoice? followOnSkillPick;
    if (subId != null && subId.isNotEmpty) {
      final list = updated['subclass_refs'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      if (!next.contains(subId)) next.add(subId);
      updated['subclass_refs'] = next;
      // Bonus Proficiencies surface: if the chosen subclass declares
      // `bonus_skill_pick_count`, queue a follow-on skillProficiency choice
      // so the player picks the N skills the feature promises (Lore L3).
      final ents = _readEntitiesFor(character);
      final subEntity = ents[subId];
      final pickCount = _asInt(subEntity?.fields['bonus_skill_pick_count']);
      if (pickCount > 0) {
        followOnSkillPick = newPendingChoice(
          kind: PendingChoiceKind.skillProficiency,
          level: choice.level,
          classId: choice.classId,
          classLabel: choice.classLabel,
          count: pickCount,
        );
      }
    }

    // Weapon mastery ids — append to weapon_masteries.
    if (resolution.weaponMasteryIds.isNotEmpty) {
      final list = updated['weapon_masteries'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      for (final id in resolution.weaponMasteryIds) {
        if (id.isEmpty) continue;
        if (!next.contains(id)) next.add(id);
      }
      updated['weapon_masteries'] = next;
    }

    // Skill ids — flip `skills.rows[i].proficient` to true for each picked
    // skill, looked up by skill entity name against the row's `name`.
    if (resolution.skillIds.isNotEmpty ||
        resolution.expertiseSkillIds.isNotEmpty) {
      final ents = _readEntitiesFor(character);
      final profNames = <String>{
        for (final id in resolution.skillIds) ?ents[id]?.name,
      }..removeWhere((n) => n.isEmpty);
      final expNames = <String>{
        for (final id in resolution.expertiseSkillIds) ?ents[id]?.name,
      }..removeWhere((n) => n.isEmpty);
      if (profNames.isNotEmpty || expNames.isNotEmpty) {
        final skillsRaw = updated['skills'];
        final skills =
            skillsRaw is Map ? Map<String, dynamic>.from(skillsRaw) : <String, dynamic>{};
        final rowsRaw = skills['rows'];
        final rows = rowsRaw is List
            ? List<dynamic>.from(rowsRaw)
            : <dynamic>[];
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row is! Map) continue;
          final name = row['name'];
          if (name is! String) continue;
          final hitProf = profNames.contains(name);
          final hitExp = expNames.contains(name);
          if (!hitProf && !hitExp) continue;
          final next = Map<String, dynamic>.from(row);
          if (hitProf) next['proficient'] = true;
          if (hitExp) {
            next['proficient'] = true;
            next['expertise'] = true;
          }
          rows[i] = next;
        }
        skills['rows'] = rows;
        updated['skills'] = skills;
      }
    }

    // Tool proficiency ids — append to tool_proficiencies.
    if (resolution.toolIds.isNotEmpty) {
      final list = updated['tool_proficiencies'];
      final next = list is List
          ? List<String>.from(list.whereType<String>())
          : <String>[];
      for (final id in resolution.toolIds) {
        if (id.isEmpty) continue;
        if (!next.contains(id)) next.add(id);
      }
      updated['tool_proficiencies'] = next;
    }

    // Language ids — append to language_refs / languages (whichever the
    // schema exposes; both are mirrored for the few templates that use the
    // legacy key).
    if (resolution.languageIds.isNotEmpty) {
      for (final key in const ['language_refs', 'languages']) {
        final list = updated[key];
        if (list == null && key == 'languages') continue;
        final next = list is List
            ? List<String>.from(list.whereType<String>())
            : <String>[];
        for (final id in resolution.languageIds) {
          if (id.isEmpty) continue;
          if (!next.contains(id)) next.add(id);
        }
        updated[key] = next;
      }
    }

    // Cantrip ids — write to spells_known (prepared=true, source=auto).
    // Mirrors the wizard's commit-time `add(... prepared: true)` path so the
    // editor renders the feat-granted cantrips alongside class cantrips.
    if (resolution.cantripIds.isNotEmpty) {
      final list = updated['spells_known'];
      final next = <dynamic>[];
      final seenIds = <String>{};
      if (list is List) {
        for (final row in list) {
          next.add(row);
          if (row is String) {
            seenIds.add(row);
          } else if (row is Map) {
            final id = row['id'];
            if (id is String) seenIds.add(id);
          }
        }
      }
      for (final id in resolution.cantripIds) {
        if (id.isEmpty || seenIds.contains(id)) continue;
        next.add({'id': id, 'equipped': true, 'source': 'auto'});
        seenIds.add(id);
      }
      updated['spells_known'] = next;
    }

    // feat_choices map — persist a feat sub-pick (Magic Initiate's class
    // list, cantrips, level-1 spell, etc.). Merge with any existing picks
    // since featChoice resolutions can fire on top of partial wizard state.
    final fcKey = resolution.featChoiceKey;
    if (fcKey != null && fcKey.isNotEmpty) {
      final raw = updated['feat_choices'];
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      map[fcKey] = resolution.featChoiceValue ?? '';
      updated['feat_choices'] = map;
    }

    // Save-throw ability picks (Resilient via featAsi). Match on row's
    // `ability` field (full name) — translate abbrevs to long names.
    if (resolution.saveProfAbilityAbbrevs.isNotEmpty) {
      const abbrevToName = <String, String>{
        'STR': 'Strength',
        'DEX': 'Dexterity',
        'CON': 'Constitution',
        'INT': 'Intelligence',
        'WIS': 'Wisdom',
        'CHA': 'Charisma',
      };
      final pickedNames = <String>{
        for (final a in resolution.saveProfAbilityAbbrevs)
          ?abbrevToName[a],
      };
      final savesRaw = updated['saving_throws'];
      final saves = savesRaw is Map
          ? Map<String, dynamic>.from(savesRaw)
          : <String, dynamic>{};
      final rowsRaw = saves['rows'];
      final rows = rowsRaw is List ? List<dynamic>.from(rowsRaw) : <dynamic>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row is! Map) continue;
        final ability = row['ability'];
        if (ability is! String) continue;
        if (!pickedNames.contains(ability)) continue;
        final next = Map<String, dynamic>.from(row);
        next['proficient'] = true;
        rows[i] = next;
      }
      saves['rows'] = rows;
      updated['saving_throws'] = saves;
    }

    _removePendingFromMap(updated, choice.id);
    final followOns = <PendingChoice>[
      ?followOnSkillPick,
      ?followOnFeatSkillPick,
      ?followOnFeatExpertisePick,
      ?followOnFeatAsi,
    ];
    if (followOns.isNotEmpty) {
      final raw = updated['pending_choices'];
      final next = raw is List
          ? List<Map<String, dynamic>>.from(
              raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)))
          : <Map<String, dynamic>>[];
      for (final p in followOns) {
        next.add(p.toMap());
      }
      updated['pending_choices'] = next;
    }
    _mutate(character.copyWith(
      entity: character.entity.copyWith(fields: updated),
    ));
  }

  void _removePendingChoice(Character character, String id) {
    // Soft-dismiss instead of removing entirely. The Upgrades panel still
    // surfaces dismissed pendings with a Restore action, per the user's
    // request that "if I dismiss an upgrade it should still continue to
    // appear in this section". `_dropPendingChoice` is the hard-delete
    // variant used by the resolver after a pick is committed.
    final updated = Map<String, dynamic>.from(character.entity.fields);
    _setPendingDismissedInMap(updated, id, true);
    _mutate(character.copyWith(
      entity: character.entity.copyWith(fields: updated),
    ));
  }

  void _setPendingDismissedInMap(
      Map<String, dynamic> fields, String id, bool dismissed) {
    final raw = fields['pending_choices'];
    if (raw is! List) return;
    final next = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      if (m['id'] == id) {
        if (dismissed) {
          m['dismissed'] = true;
        } else {
          m.remove('dismissed');
        }
      }
      next.add(m);
    }
    fields['pending_choices'] = next;
  }

  void _removePendingFromMap(Map<String, dynamic> fields, String id) {
    final raw = fields['pending_choices'];
    if (raw is! List) return;
    final next = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      if (entry['id'] == id) continue;
      next.add(Map<String, dynamic>.from(entry));
    }
    if (next.isEmpty) {
      fields.remove('pending_choices');
    } else {
      fields['pending_choices'] = next;
    }
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

  /// Inline picker rendered in the Identity group right after `species_ref`.
  /// Surfaces the chosen species's `subspecies_options` as a dropdown so
  /// the player can flip between lineages (Drow / High Elf / Wood Elf,
  /// Hill / Mountain Dwarf, …) without leaving the editor. Returns an
  /// empty box when no species is picked or the species ships no
  /// subspecies rows.
  Widget _subspeciesPickerTile(Character character) {
    final entities = _readEntitiesFor(character);
    final ids = characterRaceClassIds(character);
    final raceId = ids.raceId;
    if (raceId == null) return const SizedBox.shrink();
    final species = entities[raceId];
    if (species == null) return const SizedBox.shrink();
    final raw = species.fields['subspecies_options'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final options = <String>[];
    for (final r in raw) {
      if (r is Map) {
        final n = r['name'];
        if (n is String && n.isNotEmpty && !options.contains(n)) {
          options.add(n);
        }
      }
    }
    if (options.isEmpty) return const SizedBox.shrink();

    final current = character.entity.fields['subspecies_id'];
    final currentStr =
        current is String && current.isNotEmpty ? current : null;
    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: Text(
                'Ancestry:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette?.srdInk ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Expanded(
            child: _readOnly
                ? Text(
                    currentStr ?? '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette?.srdInk ??
                          Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : DropdownButtonFormField<String?>(
                    initialValue:
                        options.contains(currentStr) ? currentStr : null,
                    isDense: true,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child:
                            Text('(None)', overflow: TextOverflow.ellipsis),
                      ),
                      for (final o in options)
                        DropdownMenuItem<String?>(
                          value: o,
                          child: Text(o, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      final updatedFields = {
                        ...character.entity.fields,
                        'subspecies_id': v ?? '',
                      };
                      final next = character.copyWith(
                        entity: character.entity
                            .copyWith(fields: updatedFields),
                      );
                      _mutate(next);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fieldTile(FieldSchema f, Character character) {
    final value = character.entity.fields[f.fieldKey];
    // Resolve relation refs against the active campaign (world-bound
    // character) or the bundled SRD map (worldless character). Either
    // path returns a non-null map so feat / class / race chips render.
    final entities = _readEntitiesFor(character);

    // Combat-stats grid: feed the derived `level` (root field, kept current
    // by level-up) and `ac` (resolver: equipped armor + Dex + shield) so
    // those cells track live values instead of stale manual entries.
    // Resolve against the in-editor working copy directly — the
    // `effectiveCharacterProvider` only sees the persisted character, so it
    // lags behind unsaved inventory equip toggles.
    int? combatStatsLevel;
    int? combatStatsAc;
    List<String> combatStatsArmorNotes = const [];
    if (f.fieldType == FieldType.combatStats) {
      final rawLevel = character.entity.fields['level'];
      combatStatsLevel = rawLevel is int
          ? rawLevel
          : (rawLevel is String ? int.tryParse(rawLevel) : null);
      final ec = CharacterResolver.resolve(character, entities);
      combatStatsAc = ec.armorClass;
      combatStatsArmorNotes = ec.armorNotes;
    }

    final tile = FieldWidgetFactory.create(
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
      combatStatsLevel: combatStatsLevel,
      combatStatsAc: combatStatsAc,
      combatStatsArmorNotes: combatStatsArmorNotes,
    );

    // Inline `!` badges for any pending level-up decisions that map to
    // this schema field. Tap-to-resolve works in view mode too — the
    // resolver is the player's only entry point now that the post-level
    // panel is gone.
    final pending = _pendingChoicesForField(character, f.fieldKey);
    if (pending.isEmpty) return tile;
    return _PendingBadgeRow(
      tile: tile,
      pending: pending,
      onResolve: (p) => _resolvePendingChoice(character, p),
      onDiscard: (p) => _removePendingChoice(character, p.id),
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

    // CON snapshot — needed so the dialog's auto HP delta folds in the
    // CON modifier consistently with SRD §1.5. We no longer need the full
    // ability map / feat list / spell list because the dialog dropped its
    // interactive pickers; everything else becomes a pending choice.
    final statBlock = base.entity.fields['stat_block'];
    final statBlockMap =
        statBlock is Map ? Map<String, dynamic>.from(statBlock) : null;
    int asInt(Object? raw) {
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }

    final conRaw = base.entity.fields['con'] ??
        base.entity.fields['CON'] ??
        statBlockMap?['CON'] ??
        statBlockMap?['con'];
    final currentCon = asInt(conRaw).clamp(1, 30);

    final result = await LevelUpDialog.show(
      context,
      plan,
      classId: classId,
      classLabel: classEntity?.name,
      currentCon: currentCon,
      hasSubclass: subclassId != null,
      existingPending: readPendingChoices(
        base.entity.fields['pending_choices'],
      ),
    );
    if (!mounted || result == null || !result.applied) return;

    final updated = Map<String, dynamic>.from(base.entity.fields);

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

    // Interactive picks (ASI/Feat, Fighting Style, cantrip/spell selection)
    // are no longer applied here — they're queued onto `pending_choices`
    // and resolved later from the editor's pending-choices panel.
    if (result.pendingChoices.isNotEmpty) {
      final existing = updated['pending_choices'];
      final next = existing is List
          ? List<Map<String, dynamic>>.from(
              existing.whereType<Map>().map(Map<String, dynamic>.from),
            )
          : <Map<String, dynamic>>[];
      for (final p in result.pendingChoices) {
        next.add(p.toMap());
      }
      updated['pending_choices'] = next;
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

    // Per-level grant absorption — mirrors PR-A1 wizard logic for the
    // level-up path. Walk the class & subclass feature tables for rows
    // unlocked in the (fromLevel, toLevel] window and fold any ref-list
    // grants (resistances / immunities / senses / languages / feats) onto
    // the PC raw fields so they appear on the sheet immediately.
    //
    // `fullWindow=true` walks every row at `level <= toLvl` instead of the
    // delta-only slice. Used for the subclass entity so a first-time L3
    // (or class-defined gate) subclass pick absorbs every previously gated
    // row, not just the row whose level equals the new character level.
    // Idempotency (`existing.contains(id)`) keeps repeat absorption safe.
    void absorbFeatureRowsInRange(Entity? src, {bool fullWindow = false}) {
      if (src == null) return;
      final rows = src.fields['features'];
      if (rows is! List) return;
      for (final row in rows) {
        if (row is! Map) continue;
        final lvl = row['level'];
        if (lvl is! int) continue;
        if (lvl > toLvl) continue;
        if (!fullWindow && lvl <= fromLvl) continue;
        void copyRow(String fromKey, List<String> toKeys) {
          final raw = row[fromKey];
          if (raw is! List) return;
          final ids = raw.whereType<String>().toList();
          if (ids.isEmpty) return;
          for (final to in toKeys) {
            final existing = (updated[to] is List)
                ? List<String>.from(updated[to] as List)
                : <String>[];
            for (final id in ids) {
              if (!existing.contains(id)) existing.add(id);
            }
            updated[to] = existing;
            return;
          }
        }

        copyRow('granted_damage_resistances',
            const ['resistance_refs', 'damage_resistances']);
        copyRow('granted_damage_immunities',
            const ['damage_immunity_refs', 'damage_immunities']);
        copyRow('granted_damage_vulnerabilities',
            const ['vulnerability_refs', 'damage_vulnerabilities']);
        copyRow('granted_condition_immunities',
            const ['condition_immunity_refs', 'condition_immunities']);
        copyRow('granted_senses', const ['senses']);
        copyRow('granted_languages', const ['language_refs', 'languages']);
        copyRow('granted_feat_refs', const ['feats']);
        copyRow('granted_trait_refs', const ['trait_refs']);
        copyRow('granted_action_refs', const ['action_refs']);
        copyRow('granted_bonus_action_refs', const ['bonus_action_refs']);
        copyRow('granted_reaction_refs', const ['reaction_refs']);
      }
    }

    absorbFeatureRowsInRange(classEntity);
    absorbFeatureRowsInRange(subclassEntity, fullWindow: true);

    // Top-level granted_* fields on the subclass entity (not per-feature
    // rows) are normally applied once at wizard finalize via absorbGrants.
    // When the subclass is picked AFTER creation — typical at L3 — those
    // grants never landed. Re-run them here; the contains-check guards
    // against duplicate adds on subsequent level-ups.
    void absorbTopLevelGrants(Entity? src) {
      if (src == null) return;
      void copy(String fromKey, List<String> toKeys) {
        final raw = src.fields[fromKey];
        if (raw is! List) return;
        final ids = raw.whereType<String>().toList();
        if (ids.isEmpty) return;
        for (final to in toKeys) {
          final existing = (updated[to] is List)
              ? List<String>.from(updated[to] as List)
              : <String>[];
          for (final id in ids) {
            if (!existing.contains(id)) existing.add(id);
          }
          updated[to] = existing;
          return;
        }
      }

      copy('granted_damage_resistances',
          const ['resistance_refs', 'damage_resistances']);
      copy('granted_damage_immunities',
          const ['damage_immunity_refs', 'damage_immunities']);
      copy('granted_damage_vulnerabilities',
          const ['vulnerability_refs', 'damage_vulnerabilities']);
      copy('granted_condition_immunities',
          const ['condition_immunity_refs', 'condition_immunities']);
      copy('granted_senses', const ['senses']);
      copy('granted_languages', const ['language_refs', 'languages']);
      copy('granted_trait_refs', const ['trait_refs']);
      copy('granted_action_refs', const ['action_refs']);
      copy('granted_bonus_action_refs', const ['bonus_action_refs']);
      copy('granted_reaction_refs', const ['reaction_refs']);
    }

    absorbTopLevelGrants(subclassEntity);

    _mutate(base.copyWith(
      entity: base.entity.copyWith(fields: updated),
    ));
  }

  /// Action bar shown above the schema fields. Three quick verbs — Level
  /// Up, Short Rest, Long Rest — that wrap the longer-form dialogs so the
  /// player doesn't need to find the level field and bump it by hand.
  Widget _renderRestActions(DmToolColors palette, Character character) {
    // Player verbs — bypass edit-mode gate so mid-session level-up / rest
    // doesn't require flipping to edit. Pending upgrades surface in their
    // own panel below this row so the player has a single place to act on
    // them (the field-tile `!` badges still work; this panel is the
    // additive entry point requested by the user).
    // Pending upgrades surface inside the Level-Up class-picker dialog
    // (next dialog the user sees after pressing Level Up), not under
    // these buttons. Keeps the editor body short and gives the user one
    // place to act on past-level pendings before committing to a new
    // class advance.
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
    final scores = _readAbilityScores(character);
    final score = scores['CON'] ?? 10;
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
    if (character.worldId == null) return builtin;
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    if (activeWorldId != character.worldId) return builtin;
    // Subscribe only to add/remove (length changes). Per-keystroke field
    // edits mutate values in place without changing map.length, so this
    // helper no longer triggers a 20+ tile rebuild cascade. Linked-entity
    // value freshness handled at the specific tile level if needed.
    ref.watch(entityProvider.select((m) => m.length));
    final campaign = ref.read(entityProvider);
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
        character: character,
        onResolvePending: (p) {
          Navigator.of(ctx).pop();
          _resolvePendingChoice(character, p);
        },
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
    // Prefer resolver-derived effective abilities so background ASI, species
    // ability_score_bonus, and feat bumps surface in level-up + rest flows.
    // The resolver only consults `base_abilities`, so for legacy characters
    // that only carry `stat_block` (or top-level STR/DEX/... fields) we keep
    // the original fallback chain to avoid regressing to all-10s.
    final hasBaseAbilities =
        character.entity.fields['base_abilities'] is Map &&
            (character.entity.fields['base_abilities'] as Map).isNotEmpty;
    final eff = hasBaseAbilities
        ? ref.read(effectiveCharacterProvider(character.entity.id))
        : null;
    final resolved = eff?.effectiveAbilities ?? const <String, int>{};
    final out = <String, int>{};
    final stat = character.entity.fields['stat_block'];
    final statMap = stat is Map ? Map<String, dynamic>.from(stat) : null;
    for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
      final lower = k.toLowerCase();
      final fallback = character.entity.fields[lower] ??
          character.entity.fields[k] ??
          statMap?[k] ??
          statMap?[lower];
      out[k] = resolved[k] ?? _asInt(fallback, 10);
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
    // 039 edit permission gate: yetki yoksa save sessiz fail eder. RLS UPDATE
    // policy zaten server-side reddederdi, ama client-side fail-fast hem
    // network'ten kaçınır hem de yanlış uyarı snackbar'ı engeller.
    if (!_canEdit) return;
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
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'save-close-char-${widget.characterId}',
      'Saving...',
      _flushAndPush,
    );
    if (!context.mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      context.pop();
    }
  }
}

/// Wraps a schema field tile with a row of orange `!` chips — one per
/// pending level-up decision attached to this field. Tapping a chip opens
/// the resolver; long-press discards without applying. The chips render
/// regardless of editor read-only mode so the player can resolve from the
/// view tab too.
class _PendingBadgeRow extends StatelessWidget {
  final Widget tile;
  final List<PendingChoice> pending;
  final void Function(PendingChoice) onResolve;
  final void Function(PendingChoice) onDiscard;

  const _PendingBadgeRow({
    required this.tile,
    required this.pending,
    required this.onResolve,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    // Distinguish duplicate same-name pendings (Warlock L1 Eldritch
    // Invocations → 2 picks): suffix "(N/M)" when more than one chip
    // shares (kind, level, featureName). Without this the user sees two
    // identical chips and can't tell which one they just resolved.
    final groupCount = <String, int>{};
    for (final p in pending) {
      final key = '${p.kind}|${p.level}|${p.featureName ?? ''}';
      groupCount[key] = (groupCount[key] ?? 0) + 1;
    }
    final groupOrdinal = <String, int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in pending)
                _PendingChip(
                  label: () {
                    final key =
                        '${p.kind}|${p.level}|${p.featureName ?? ''}';
                    final total = groupCount[key] ?? 1;
                    if (total <= 1) return pendingChoiceLabel(p);
                    final idx = (groupOrdinal[key] ?? 0) + 1;
                    groupOrdinal[key] = idx;
                    return '${pendingChoiceLabel(p)} ($idx/$total)';
                  }(),
                  onTap: () => onResolve(p),
                  onLongPress: () => onDiscard(p),
                ),
            ],
          ),
        ),
        tile,
      ],
    );
  }
}

class _PendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PendingChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: 'Tap to resolve · Long-press to discard',
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              border: Border.all(color: Colors.orange, width: 1.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.priority_high,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
  /// Character whose pending upgrades render at the top of this dialog.
  /// Every pending choice — including dismissed ones — appears as an
  /// actionable Resolve chip. Dismiss only hides the field-tile `!`
  /// badge; it does not remove the upgrade from this list.
  final Character character;
  final void Function(PendingChoice) onResolvePending;

  const _LevelUpClassPicker({
    required this.classLevels,
    required this.entities,
    required this.abilityScores,
    required this.character,
    required this.onResolvePending,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
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
      content: SizedBox(
        width: 380,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (palette != null)
                  _UpgradesPanel(
                    character: character,
                    palette: palette,
                    onResolve: onResolvePending,
                  ),
                ...rows,
              ],
            ),
          ),
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
    // 039+040: personal_characters retired. Char is "online" iff user is
    // signed in — world_characters RLS auto-mirrors every owned row.
    final isOnline = hasCloud && ref.watch(authProvider) != null;

    final (icon, color) = _resolveIcon(palette, hasCloud, isOnline);

    return IconButton(
      icon: saving
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 20, color: color),
      tooltip: saving
          ? 'Saving...'
          : (isOnline ? 'Online · Save & Sync' : 'Save & Sync'),
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
    bool isOnline,
  ) {
    if (!hasCloud) {
      return (Icons.save, palette.sidebarLabelSecondary);
    }
    if (isOnline) {
      return (Icons.cloud_done, palette.successBtnBg);
    }
    return (Icons.cloud_outlined, palette.sidebarLabelSecondary);
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
    final outbox = hasCloud
        ? (ref.watch(activeItemOutboxStatusProvider).valueOrNull ??
            OutboxStatus.empty)
        : null;

    // Sync button eligibility: world-bound + online world OR worldless + beta.
    // Aksi halde push edilecek bir cloud row yok.
    final signedIn = ref.watch(authProvider) != null;
    final betaActive = ref.watch(betaProvider).isActive;
    final worldId = character.worldId;
    final worldOnline = worldId != null &&
        ref.watch(onlineWorldIdsProvider).contains(worldId);
    final syncEnabled =
        hasCloud && signedIn && (worldOnline || betaActive);
    final disabledTooltip = !signedIn
        ? 'Sign in to sync'
        : (worldId != null && !worldOnline)
            ? 'Make this world online first'
            : 'Join beta to sync personal characters';

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

                if (hasCloud) ...[
                  const SizedBox(height: 16),
                  SectionLabel('Actions', palette),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SyncButton(
                        palette: palette,
                        enabled: syncEnabled,
                        disabledTooltip: disabledTooltip,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Online', palette),
                  const SizedBox(height: 8),
                  _CharacterOnlineToggle(
                    character: character,
                    flushLocal: flushLocal,
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Storage', palette),
                  const SizedBox(height: 8),
                  StorageUsageBar(palette: palette),
                ],

                if (hasCloud && outbox != null && outbox.pending > 0) ...[
                  const SizedBox(height: 16),
                  SectionLabel('Sync Queue', palette),
                  const SizedBox(height: 8),
                  OutboxStatusRow(outbox: outbox, palette: palette),
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

}

/// Online sync status card. Routing rules:
///   - Online world → world_characters mirror (real-time), regardless of beta.
///   - Beta + (worldless or world offline) → cloud_backup snapshot auto-sync.
///   - Non-beta + (worldless or world offline) → local only.
class _CharacterOnlineToggle extends ConsumerWidget {
  final Character character;
  final Future<void> Function() flushLocal;

  const _CharacterOnlineToggle({
    required this.character,
    required this.flushLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final isBeta = ref.watch(isBetaActiveProvider);
    final worldId = character.worldId;
    final onlineIds = ref.watch(onlineWorldIdsProvider);
    final worldOnline = worldId != null && onlineIds.contains(worldId);

    final IconData icon;
    final Color color;
    final String label;
    if (worldOnline) {
      icon = Icons.cloud_done;
      color = palette.successBtnBg;
      label = 'Online · auto-synced';
    } else if (isBeta) {
      icon = Icons.cloud_done;
      color = palette.successBtnBg;
      label = 'Cloud · auto-synced';
    } else {
      icon = Icons.cloud_off;
      color = palette.sidebarLabelSecondary;
      label = 'Offline · local only';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
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
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    final useCampaign = character.worldId != null &&
        activeWorldId == character.worldId;

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

    // On phone the header is squeezed by the 200-px portrait, so the chip
    // strip routinely overflowed when the full-size font wrapped onto extra
    // rows. Render the compact variant and allow horizontal scroll so chips
    // can extend off-screen instead of pushing layout around.
    final isPhone = getScreenType(context) == ScreenType.phone;
    // Resolve AC off the live working `character` so equipping armor
    // refreshes the chip immediately. `effectiveCharacterProvider` only sees
    // the persisted copy and lags behind unsaved equip toggles. Campaign
    // entities read (not watched) — this widget already rebuilds on every
    // editor `_mutate`, which is when inventory actually changes.
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    final entities = useCampaign
        ? <String, Entity>{...builtin, ...ref.read(entityProvider)}
        : builtin;
    final effectiveAc =
        CharacterResolver.resolve(character, entities).armorClass;
    return RepaintBoundary(
      child: CharacterStatChips(
        lines: characterStatLinesWithNames(
          character,
          raceName: resolve(ids.raceId),
          className: resolve(ids.classId),
          effectiveAc: effectiveAc,
          ownerLabel: resolveCharacterOwnerLabel(ref, character),
        ),
        palette: palette,
        compact: isPhone,
        scrollHorizontally: isPhone,
      ),
    );
  }
}

/// Pending upgrades panel shown at the top of the level-up class
/// picker dialog. Every pending choice (including dismissed ones) is
/// rendered as an actionable Resolve chip. Dismiss only hides the `!`
/// badge on card field tiles — it never removes an upgrade from this
/// list. Pendings disappear here only when actually resolved.
class _UpgradesPanel extends StatelessWidget {
  final Character character;
  final DmToolColors palette;
  final void Function(PendingChoice) onResolve;

  const _UpgradesPanel({
    required this.character,
    required this.palette,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final raw = character.entity.fields['pending_choices'];
    final all = readPendingChoices(raw);
    if (all.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.upgrade, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Upgrades · ${all.length} pending',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in all)
                  ActionChip(
                    label: Text(pendingChoiceLabel(p)),
                    avatar: const Icon(Icons.priority_high,
                        size: 14, color: Colors.orange),
                    onPressed: () => onResolve(p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

