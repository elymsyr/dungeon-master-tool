import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/content_translator_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/free_character_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/services/entity_media_cleanup_service.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/character_ext.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/content_translator.dart';
import '../../../domain/services/free_field_styles.dart';
import '../../../domain/services/free_grants.dart';
import '../../../domain/services/free_template.dart';
import '../../../domain/services/template_edit.dart'
    show fieldsIn, sortedGroups;
import '../../../domain/value_objects/asset_ref.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/asset_ref_image.dart';
import '../../widgets/character_stat_chips.dart';
import '../../widgets/dice/dice_fab.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/perf/image_cache_size.dart';
import '../../widgets/section_jump_pad.dart';
import '../../widgets/srd_text.dart';
import '../database/entity_card.dart'
    show
        EntityCardCollapsibleGroupCard,
        EntityCardSectionHeading,
        splitFieldRows;
import '../hub/characters_tab.dart' show showCharacterSettingsDialog;
import '../hub/settings_tab.dart';
import 'character_editor_screen.dart'
    show CharacterSaveSyncButton, CharacterSaveSyncDialog;
import 'free_level_dialogs.dart';

/// A free template character's sheet (docs/free-template/DESIGN.md §10.2):
/// the built-in character screen's look — portrait, name, description,
/// summary chips, view / edit, undo, DM notes — drawn with the player
/// card's layout, plus Level up, Short / Long rest and what the
/// character's cards grant (§11: cards into lists, the Pool). None of the
/// built-in sheet's rules (resolved grants, class resource tracker, derived
/// values): the built-in editor only routes here (ROADMAP K3).
class FreeCharacterSheet extends ConsumerStatefulWidget {
  const FreeCharacterSheet({
    super.key,
    required this.characterId,
    required this.schema,
    this.onClose,
  });

  final String characterId;

  /// The world's own copy, or the template of a worldless character.
  final WorldSchema schema;

  /// Embedded (sidebar / player tab): back closes through this.
  final VoidCallback? onClose;

  @override
  ConsumerState<FreeCharacterSheet> createState() => _FreeCharacterSheetState();
}

class _FreeCharacterSheetState extends ConsumerState<FreeCharacterSheet> {
  Character? _working;
  bool _readOnly = true;
  bool _saving = false;

  /// Local edits not stored yet: an outside change (the encounter writing
  /// HP back) is taken only when there are none.
  bool _pending = false;

  // Undo / redo, as the built-in sheet: quick edits make one step.
  final List<Character> _undoStack = [];
  final List<Character> _redoStack = [];
  Character? _undoBaseline;
  Timer? _undoIdleTimer;

  final _descController = TextEditingController();
  final _descFocus = FocusNode();
  final _dmNotesController = TextEditingController();
  final _dmNotesFocus = FocusNode();
  bool _controllersPrimed = false;

  // The section jump pad (top right).
  final _sheetScroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];
  List<({String label, int row})> _navTargets = const [];
  final Map<int, double> _rowOffsetCache = {};

  /// Held from initState: `ref` is gone in dispose.
  PendingWriteBuffer? _pendingBuffer;

  String get _saveKey => 'character:${widget.characterId}';

  @override
  void initState() {
    super.initState();
    _pendingBuffer = ref.read(pendingWriteBufferProvider);
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
    // ignore: discarded_futures
    _pendingBuffer?.flushPrefix(_saveKey);
    _descController.dispose();
    _descFocus.dispose();
    _dmNotesController.dispose();
    _dmNotesFocus.dispose();
    _sheetScroll.dispose();
    super.dispose();
  }

  /// Owner or the world's DM; anyone without an account or in a world that
  /// is not online (the built-in sheet's rule).
  bool get _canEdit {
    final c = _working;
    if (c == null) return false;
    final selfUid = ref.read(authProvider)?.uid;
    if (selfUid == null) return true;
    if (c.ownerId == selfUid) return true;
    final wid = c.worldId;
    if (wid == null) return false;
    if (!ref.read(onlineWorldIdsProvider).contains(wid)) return true;
    return ref.read(worldRoleProvider(wid)).valueOrNull == WorldRole.dm;
  }

  bool get _canUndo => _undoStack.isNotEmpty || _undoBaseline != null;

  /// Every edit goes through here: undo step, then a debounced save.
  /// [rebuild] false for typing, which its text field already shows.
  void _edit(Character Function(Character) change, {bool rebuild = true}) {
    final c = _working;
    if (c == null) return;
    final next = change(c);
    if (rebuild) {
      setState(() => _working = next);
    } else {
      _working = next;
    }
    _pending = true;
    _undoBaseline ??= c;
    _undoIdleTimer?.cancel();
    _undoIdleTimer = Timer(const Duration(milliseconds: 400), () {
      final baseline = _undoBaseline;
      if (baseline != null && baseline != _working) {
        _undoStack.add(baseline);
        if (_undoStack.length > 100) _undoStack.removeAt(0);
        _redoStack.clear();
      }
      _undoBaseline = null;
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    if (!_canEdit) return;
    final notifier = ref.read(characterListProvider.notifier);
    ref
        .read(pendingWriteBufferProvider)
        .schedule(
          key: _saveKey,
          kind: WriteKind.shortText,
          action: () async {
            final cur = _working;
            if (cur == null) return;
            await notifier.update(cur);
            if (identical(_working, cur)) _pending = false;
          },
        );
  }

  void _undo() {
    _undoIdleTimer?.cancel();
    final baseline = _undoBaseline;
    if (baseline != null && baseline != _working) _undoStack.add(baseline);
    _undoBaseline = null;
    if (_undoStack.isEmpty) return;
    final cur = _working;
    if (cur != null) _redoStack.add(cur);
    setState(() => _working = _undoStack.removeLast());
    _pending = true;
    _scheduleSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final cur = _working;
    if (cur != null) _undoStack.add(cur);
    setState(() => _working = _redoStack.removeLast());
    _pending = true;
    _scheduleSave();
  }

  void _setFields(Map<String, dynamic> patch) => _edit(
    (c) => c.copyWith(
      entity: c.entity.copyWith(fields: {...c.entity.fields, ...patch}),
    ),
  );

  void _replaceFields(Map<String, dynamic> fields) =>
      _edit((c) => c.copyWith(entity: c.entity.copyWith(fields: fields)));

  Future<void> _save({bool silent = false}) async {
    final w = _working;
    if (w == null || _saving || !_canEdit) return;
    setState(() => _saving = true);
    try {
      await ref.read(characterListProvider.notifier).update(w);
      if (identical(_working, w)) _pending = false;
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context)!.charSaved),
          duration: const Duration(seconds: 1),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _flushAndSave() async {
    try {
      await ref.read(pendingWriteBufferProvider).flushPrefix(_saveKey);
    } catch (_) {
      /* best-effort */
    }
    await _save(silent: true);
  }

  Future<void> _close() async {
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'save-close-char-${widget.characterId}',
      L10n.of(context)!.savingEllipsis,
      _flushAndSave,
    );
    if (!mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      context.pop();
    }
  }

  Future<void> _pickPortrait() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    final c = _working;
    if (path == null || c == null) return;
    final oldRef = c.entity.imagePath;
    _edit((c) => c.copyWith(entity: c.entity.copyWith(imagePath: path)));
    await _flushAndSave();
    // The replaced portrait's cloud copy goes (best-effort).
    if (!mounted || ref.read(authProvider) == null) return;
    // ignore: discarded_futures
    ref
        .read(entityMediaCleanupServiceProvider)
        ?.cleanupReplacedRef(oldRef: oldRef, newRef: path)
        .catchError((Object e) => debugPrint('portrait cleanup error: $e'));
  }

  Future<void> _openWorld(Character c) async {
    final worldId = c.worldId;
    if (worldId == null) return;
    final infos = ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final worldName = c.resolvedWorldName(infos);
    if (worldName.isEmpty) return;
    await _save(silent: true);
    if (!mounted) return;
    final ok = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-world-$worldId',
      L10n.of(context)!.loadingOpeningWorld(worldName),
      () => ref.read(activeCampaignProvider.notifier).load(worldId),
    );
    if (ok && mounted) context.go('/main');
  }

  /// The reached levels a card opened from here marks (DESIGN §11.8).
  Map<String, int> _reached = const {};

  @override
  void deactivate() {
    // Not in dispose: Riverpod forbids `ref` there.
    if (_reached.isNotEmpty) {
      ref.read(freeReachedLevelsProvider.notifier).state = const {};
    }
    super.deactivate();
  }

  void _publishReached(Map<String, int> reached) {
    if (_mapEquals(reached, _reached)) return;
    _reached = reached;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(freeReachedLevelsProvider.notifier).state = reached;
      }
    });
  }

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  /// A change that may grant or take back cards (DESIGN §11.4–§11.7): the
  /// cards it newly grants join their lists, a summary shows what came,
  /// and labelled cards nothing grants any more are offered for removal.
  Future<void> _changeCards(
    GrantContext ctx,
    Map<String, dynamic> after, {
    String? title,
  }) async {
    final change = settleGrants(_working!.entity.fields, after, ctx);
    _replaceFields(change.fields);
    final summary = summarize(change);
    final l10n = L10n.of(context)!;
    if (title != null || !summary.isEmpty) {
      await showGrantSummaryDialog(
        context,
        title: title ?? l10n.freeSummaryTitle,
        summary: summary,
        entities: ctx.entities,
        listLabels: {
          for (final f in carrierListsOf(ctx.carrier)) f.fieldKey: f.label,
        },
      );
    }
    if (change.stale.isEmpty || !mounted) return;
    if (await confirmRemoveGranted(
          context,
          ids: change.stale,
          entities: ctx.entities,
        ) &&
        mounted) {
      await _changeCards(
        ctx,
        withoutCards(_working!.entity.fields, change.stale, ctx),
      );
    }
  }

  Future<void> _levelUp(GrantContext ctx) async {
    final fields = _working!.entity.fields;
    final from = mainLevelOf(ctx.carrier, fields);
    if (from == null) return;
    final groups = levelUpGroups(fields, ctx);
    final picks = await showFreeLevelUpDialog(
      context,
      ref,
      from: from,
      groups: groups,
      entities: ctx.entities,
    );
    if (picks == null || !mounted) return;
    await _changeCards(
      ctx,
      levelUp(fields, ctx, picked: picks.picked, added: picks.added),
      title: L10n.of(context)!.freeSummaryLevel(from + 1),
    );
  }

  Future<void> _editLevels(GrantContext ctx) async {
    final next = await showFreeLevelsDialog(
      context,
      fields: _working!.entity.fields,
      ctx: ctx,
    );
    if (next != null && mounted) await _changeCards(ctx, next);
  }

  /// Under each listed card: who granted it (V12), or its own level in a
  /// separate category.
  Map<String, String> _captions(GrantContext ctx, Map<String, dynamic> f) {
    final l10n = L10n.of(context)!;
    String name(String id) {
      final e = ctx.entities[id];
      return e == null ? id : srdName(context, e);
    }

    return {
      for (final g in levelUpGroups(f, ctx))
        for (final c in g.cards) c.id: l10n.freeSheetLevel(c.level),
      for (final MapEntry(key: id, value: label) in grantLabelsOf(f).entries)
        id: label.level == null
            ? l10n.freeGrantedFromCard(name(label.from))
            : l10n.freeGrantedFrom(name(label.from), label.level!),
    };
  }

  void _rest(EntityCategorySchema card, RestKind kind, GrantResult grants) {
    final fields = _working!.entity.fields;
    final patch = restPatch(card.fields, fields, kind);
    // The Pool's resources rest too (DESIGN §12.3).
    final pool = poolFieldOf(card);
    final poolValue = pool == null
        ? null
        : poolAfterRest(grants, fields[pool.fieldKey], kind);
    if (poolValue != null) patch[pool!.fieldKey] = poolValue;
    if (patch.isNotEmpty) _setFields(patch);
    final l10n = L10n.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          kind == RestKind.short
              ? l10n.freeShortRestDone
              : l10n.freeLongRestDone,
        ),
      ),
    );
  }

  void _syncIfNotFocused(
    TextEditingController ctrl,
    FocusNode focus,
    String value,
  ) {
    if (!focus.hasFocus && ctrl.text != value) ctrl.text = value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    ref.listen<Character?>(characterByIdProvider(widget.characterId), (
      _,
      next,
    ) {
      if (next != null && !_pending && mounted) {
        setState(() => _working = next);
      }
    });
    _working ??= ref.read(characterByIdProvider(widget.characterId));
    final character = _working;
    final card = freePlayerCard(widget.schema);
    if (character == null || card == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            character == null ? l10n.charNotFound : l10n.charTemplateNoPlayer,
          ),
        ),
      );
    }
    final embedded = widget.onClose != null;
    final phone = getScreenType(context) == ScreenType.phone;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: l10n.btnBack,
                onPressed: _close,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.schema.name,
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
            IconButton(
              key: const ValueKey('free_sheet_edit'),
              icon: Icon(_readOnly ? Icons.edit : Icons.visibility, size: 20),
              tooltip: _canEdit
                  ? (_readOnly ? l10n.btnEdit : l10n.btnView)
                  : l10n.charReadOnlyNotOwner,
              onPressed: !_canEdit
                  ? null
                  : () => setState(() => _readOnly = !_readOnly),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              tooltip: l10n.mainUndoShort,
              onPressed: _canUndo ? _undo : null,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              tooltip: l10n.mainRedoShort,
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              visualDensity: VisualDensity.compact,
            ),
            if (!phone)
              CharacterSaveSyncButton(
                character: character,
                saving: _saving,
                flushLocal: () => _save(silent: true),
              ),
            if (!embedded && phone)
              _phoneMenu(character, palette)
            else if (!embedded) ...[
              IconButton(
                icon: const Icon(Icons.inventory_2, size: 20),
                tooltip: l10n.importPackage,
                onPressed: () => ImportPackageDialog.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: l10n.tabSettings,
                onPressed: () =>
                    showCharacterSettingsDialog(context, ref, character.id),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: l10n.appSettings,
                onPressed: () => SettingsTab.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.bug_report_outlined, size: 20),
                tooltip: l10n.menuReportBug,
                onPressed: () => BugReportDialog.show(context),
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
        body: _body(context, palette, character, card),
        // Embedded in a world screen, that screen's dice button is there.
        floatingActionButton: embedded ? null : const DiceFab(),
      ),
    );
  }

  Widget _phoneMenu(Character character, DmToolColors palette) {
    final l10n = L10n.of(context)!;
    PopupMenuItem<String> item(String value, IconData icon, String text) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)],
          ),
        );
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) {
        switch (action) {
          case 'sync':
            showDialog<void>(
              context: context,
              builder: (_) => CharacterSaveSyncDialog(
                character: character,
                flushLocal: () => _save(silent: true),
              ),
            );
          case 'import':
            ImportPackageDialog.show(context);
          case 'settings':
            showCharacterSettingsDialog(context, ref, character.id);
          case 'app_settings':
            SettingsTab.show(context);
          case 'bug':
            BugReportDialog.show(context);
        }
      },
      itemBuilder: (_) => [
        item(
          'sync',
          _saving ? Icons.cloud_upload : Icons.cloud_done,
          _saving ? l10n.savingEllipsis : l10n.saveAndSync,
        ),
        const PopupMenuDivider(),
        item('import', Icons.inventory_2, l10n.importPackage),
        const PopupMenuDivider(),
        item('settings', Icons.info_outline, l10n.tabSettings),
        item('app_settings', Icons.settings_outlined, l10n.appSettings),
        item('bug', Icons.bug_report_outlined, l10n.menuReportBug),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    DmToolColors palette,
    Character character,
    EntityCategorySchema card,
  ) {
    final l10n = L10n.of(context)!;
    if (!_controllersPrimed) {
      _descController.text = character.entity.description;
      _dmNotesController.text = character.entity.dmNotes;
      _controllersPrimed = true;
    }
    _syncIfNotFocused(
      _descController,
      _descFocus,
      character.entity.description,
    );
    _syncIfNotFocused(
      _dmNotesController,
      _dmNotesFocus,
      character.entity.dmNotes,
    );

    // Card links resolve against the open world's cards.
    final Map<String, Entity> entities =
        character.worldId != null &&
            ref.watch(activeCampaignProvider) == character.worldId
        ? ref.watch(entityProvider)
        : const {};
    final ctx = GrantContext(
      carrier: card,
      categories: widget.schema.categories,
      entities: entities,
    );
    final grants = computeGrants(character.entity.fields, ctx);
    _publishReached(grants.reached);
    final g = (
      ctx: ctx,
      grants: grants,
      captions: _captions(ctx, character.entity.fields),
      // Without the world's cards nothing can be granted or taken back.
      cardsLoaded: entities.isNotEmpty,
    );
    final tx = ref.watch(contentTranslatorProvider);
    final phone = isPhone(context);

    final baseTheme = Theme.of(context);
    final cardTheme = palette.cardBorderlessInputs
        ? baseTheme.copyWith(
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
            ),
          )
        : baseTheme;

    final ungrouped = fieldsIn(card, null);
    final rows = <Widget>[
      _header(palette, character, card, entities),
      const SizedBox(height: 12),
      _actions(card, mainLevelOf(card, character.entity.fields) != null, g),
      const SizedBox(height: 16),
      if (ungrouped.isNotEmpty) ...[
        EntityCardSectionHeading(title: l10n.propertiesTitle, palette: palette),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _fields(ungrouped, 1, card, character, entities, g),
        ),
        const SizedBox(height: 16),
      ],
      for (final grp in sortedGroups(card))
        if (fieldsIn(card, grp.groupId).isNotEmpty) ...[
          EntityCardCollapsibleGroupCard(
            group: grp.copyWith(
              name: tx.tr(ContentTranslator.schemaScope, grp.name),
            ),
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _fields(
                fieldsIn(card, grp.groupId),
                phone ? 1 : grp.gridColumns,
                card,
                character,
                entities,
                g,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      EntityCardSectionHeading(
        title: l10n.dmNotesTitle,
        palette: palette,
        leadingIcon: Icons.lock,
      ),
      const SizedBox(height: 6),
      MarkdownTextArea(
        controller: _dmNotesController,
        focusNode: _dmNotesFocus,
        readOnly: _readOnly,
        minLines: _readOnly ? null : 3,
        textStyle: TextStyle(fontSize: 13, color: palette.srdInk, height: 1.4),
        decoration: InputDecoration(
          hintText: l10n.dmNotesPrivateHint,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
          hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
        ),
        onChanged: (v) => _edit(
          (c) => c.copyWith(entity: c.entity.copyWith(dmNotes: v)),
          rebuild: false,
        ),
      ),
    ];

    while (_rowKeys.length < rows.length) {
      _rowKeys.add(GlobalKey());
    }
    _navTargets = [
      for (var i = 0; i < rows.length; i++)
        if (rows[i] case EntityCardSectionHeading(:final title))
          (label: title, row: i)
        else if (rows[i] case EntityCardCollapsibleGroupCard(:final group))
          (label: group.name, row: i),
    ];

    return Theme(
      data: cardTheme,
      child: Container(
        color: palette.srdParchment,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Stack(
              children: [
                ListView.builder(
                  controller: _sheetScroll,
                  // Bottom room so the dice button never covers the last row.
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 96),
                  itemCount: rows.length,
                  itemBuilder: (_, i) =>
                      KeyedSubtree(key: _rowKeys[i], child: rows[i]),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: SectionJumpPad(
                    palette: palette,
                    sections: [for (final t in _navTargets) t.label],
                    onSelect: (i) =>
                        _jumpToRow(_navTargets[i].row, rows.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The built-in sheet's header: portrait, name, template · world,
  /// description, and the player card's summary chips.
  Widget _header(
    DmToolColors palette,
    Character c,
    EntityCategorySchema card,
    Map<String, Entity> entities,
  ) {
    final l10n = L10n.of(context)!;
    final entity = c.entity;
    final infos = ref.watch(campaignInfoListProvider).valueOrNull ?? const [];
    final worldLabel = c.resolvedWorldName(infos);
    final subtitle =
        '${widget.schema.name} · '
        '${worldLabel.isEmpty ? l10n.charWorldOrphan : worldLabel}';
    final phone = getScreenType(context) == ScreenType.phone;
    final nameStyle = TextStyle(
      fontFamily: palette.useSerif ? 'Georgia' : null,
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: palette.srdHeadingRed,
      letterSpacing: palette.cardHeadingUppercase ? 1.2 : 0,
      height: 1.1,
    );

    Widget placeholder() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person, size: 56, color: palette.sidebarLabelSecondary),
        if (!_readOnly) ...[
          const SizedBox(height: 4),
          Text(
            l10n.charAddPhoto,
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _readOnly ? null : _pickPortrait,
          child: Container(
            width: 200,
            height: 260,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: entity.imagePath.isNotEmpty
                ? AssetRefImage(
                    ref: AssetRef(entity.imagePath),
                    fit: BoxFit.cover,
                    cacheHeight: cachePxFromLogical(context, 260),
                    placeholder: placeholder(),
                    errorWidget: placeholder(),
                  )
                : placeholder(),
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
                  style: nameStyle,
                )
              else
                TextFormField(
                  key: const ValueKey('free_sheet_name'),
                  initialValue: entity.name,
                  style: nameStyle,
                  decoration: InputDecoration(
                    hintText: l10n.charNameHint,
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => _edit(
                    (c) => c.copyWith(entity: c.entity.copyWith(name: v)),
                    rebuild: false,
                  ),
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
                  fontSize: 16,
                  color: palette.srdInk,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: l10n.markdownMentionHint,
                  border: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: palette.srdSubtitle,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                onChanged: (v) => _edit(
                  (c) => c.copyWith(entity: c.entity.copyWith(description: v)),
                  rebuild: false,
                ),
              ),
              const SizedBox(height: 10),
              CharacterStatChips(
                lines: freeChipLines(
                  card,
                  c.entity.fields,
                  entities,
                  l10n: l10n,
                  tx: ref.watch(contentTranslatorProvider),
                  ownerLabel: resolveCharacterOwnerLabel(ref, c),
                ),
                palette: palette,
                compact: phone,
                scrollHorizontally: phone,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The player's verbs, in view mode too: Level up (with a Level field)
  /// and the rests.
  Widget _actions(EntityCategorySchema card, bool hasLevel, _Grants g) {
    final l10n = L10n.of(context)!;
    Widget button(Key key, IconData icon, String label, VoidCallback? on) =>
        Expanded(
          child: OutlinedButton.icon(
            key: key,
            onPressed: on,
            icon: Icon(icon, size: 16),
            label: Text(label),
          ),
        );
    return Row(
      children: [
        if (hasLevel) ...[
          button(
            const ValueKey('free_level_up'),
            Icons.arrow_upward,
            l10n.charLevelUp,
            g.cardsLoaded ? () => _levelUp(g.ctx) : null,
          ),
          const SizedBox(width: 8),
        ],
        button(
          const ValueKey('free_short_rest'),
          Icons.bedtime_outlined,
          l10n.charShortRest,
          () => _rest(card, RestKind.short, g.grants),
        ),
        const SizedBox(width: 8),
        button(
          const ValueKey('free_long_rest'),
          Icons.nightlight_round,
          l10n.charLongRest,
          () => _rest(card, RestKind.long, g.grants),
        ),
      ],
    );
  }

  /// [fields] in rows of [cols] columns, each field as wide as its span.
  List<Widget> _fields(
    List<FieldSchema> fields,
    int cols,
    EntityCategorySchema card,
    Character character,
    Map<String, Entity> entities,
    _Grants g,
  ) {
    final tx = ref.read(contentTranslatorProvider);
    Widget tile(FieldSchema f, {bool compact = false}) {
      final link = f.fieldType == FieldType.relation;
      final list = link && f.isList;
      final levelField = f.fieldType == FieldType.characterLevel;
      final w = FieldWidgetFactory.create(
        schema: tx.field(f),
        value: freeFieldValue(f, character.entity.fields),
        // The Level changes through Level up and the levels dialog.
        readOnly: _readOnly || levelField,
        play: true,
        onChanged: (v) => link && g.cardsLoaded
            ? _changeCards(g.ctx, {...character.entity.fields, f.fieldKey: v})
            : _setFields({f.fieldKey: v}),
        entities: entities,
        ref: ref,
        entityFields: character.entity.fields,
        entityName: character.entity.name,
        compact: compact && list && !f.hasEquip,
        categoryFields: card.fields,
        grants: g.grants,
        itemCaptions: list ? g.captions : null,
      );
      if (!levelField || !g.cardsLoaded || _readOnly) return w;
      return InkWell(
        key: const ValueKey('free_sheet_levels'),
        onTap: () => _editLevels(g.ctx),
        child: w,
      );
    }

    if (cols <= 1) return [for (final f in fields) tile(f)];
    return [
      for (final row in splitFieldRows(fields, cols, useCache: false))
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, f) in row.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                flex: f.gridColumnSpan.clamp(1, cols),
                child: tile(f, compact: true),
              ),
            ],
            // A short row keeps its cells at full-row widths.
            if (row.fold(0, (n, f) => n + f.gridColumnSpan.clamp(1, cols)) <
                cols)
              Expanded(
                flex:
                    cols -
                    row.fold(0, (n, f) => n + f.gridColumnSpan.clamp(1, cols)),
                child: const SizedBox.shrink(),
              ),
          ],
        ),
    ];
  }

  /// Scrolls to row [index] of the lazy list: its offset is not known
  /// until it is built, so the built-in sheet's bisection finds it.
  Future<void> _jumpToRow(int index, int rowCount) async {
    if (!_sheetScroll.hasClients || index >= _rowKeys.length) return;
    var lo = _sheetScroll.position.minScrollExtent;
    var hi = _sheetScroll.position.maxScrollExtent;
    final seed =
        _rowOffsetCache[index] ?? (rowCount == 0 ? 0.0 : hi * index / rowCount);
    if ((seed - _sheetScroll.position.pixels).abs() > 8) {
      _sheetScroll.jumpTo(seed.clamp(lo, hi));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_sheetScroll.hasClients) return;
    }
    for (var attempt = 0; attempt < 16; attempt++) {
      final pos = _sheetScroll.position;
      final ctx = _rowKeys[index].currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: 0.02);
        if (_sheetScroll.hasClients) {
          _rowOffsetCache[index] = _sheetScroll.position.pixels;
        }
        return;
      }
      int? mountedRow;
      for (var j = 0; j < rowCount && j < _rowKeys.length; j++) {
        if (_rowKeys[j].currentContext != null) {
          mountedRow = j;
          break;
        }
      }
      if (mountedRow == null) return;
      if (index > mountedRow) {
        lo = pos.pixels;
        if (pos.maxScrollExtent > hi) hi = pos.maxScrollExtent;
      } else {
        hi = pos.pixels;
      }
      final next = ((lo + hi) / 2).clamp(pos.minScrollExtent, hi);
      if ((next - pos.pixels).abs() < 1) return;
      _sheetScroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }
}

/// What the sheet's field tiles need of the level system.
typedef _Grants = ({
  GrantContext ctx,
  GrantResult grants,
  Map<String, String> captions,
  bool cardsLoaded,
});
