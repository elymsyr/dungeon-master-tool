import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
import '../../theme/markdown_theme.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/asset_ref_image.dart';
import '../../widgets/character_stat_chips.dart';
import '../../widgets/dice/dice_fab.dart';
import '../../widgets/field_widgets/entity_link.dart' show EntityOpenScope;
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/perf/image_cache_size.dart';
import '../../widgets/section_jump_pad.dart';
import '../../widgets/srd_text.dart';
import '../database/entity_card.dart'
    show
        EntityCardCollapsibleGroupCard,
        EntityCardCollapsibleGroupCardState,
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
/// card's layout, plus Level up, Short / Long rest, what the character's
/// cards grant (§11: cards into lists, the Pool) and the template's
/// creation guide (§13.3). None of the
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

  // The creation guide (DESIGN §13.3): the step shown, null while closed;
  // each field's tile and row, to scroll to and highlight it.
  int? _guideStep;
  bool _guideChecked = false;
  final Map<String, GlobalKey> _fieldKeys = {};
  final Map<String, GlobalKey<EntityCardCollapsibleGroupCardState>>
  _groupKeys = {};
  Map<String, int> _fieldRows = const {};

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

  /// The character's reached levels; only the cards opened from here show
  /// theirs (DESIGN §11.8).
  Map<String, int> _reached = const {};
  final _opened = <String>{};
  Map<String, int> _shown = const {};

  @override
  void deactivate() {
    // Not in dispose: Riverpod forbids `ref` there. After the frame: a
    // provider change while the tree is being finalized rebuilds an open
    // card in the wrong build scope.
    if (_shown.isNotEmpty) {
      final reached = ref.read(freeReachedLevelsProvider.notifier);
      _shown = const {};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) reached.state = const {};
      });
    }
    super.deactivate();
  }

  void _publishReached(Map<String, int> reached) {
    _reached = reached;
    final shown = {for (final id in _opened) id: ?reached[id]};
    if (_mapEquals(shown, _shown)) return;
    _shown = shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(freeReachedLevelsProvider.notifier).state = shown;
      }
    });
  }

  void _opensCard(String id) {
    if (_opened.add(id)) _publishReached(_reached);
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
        listLabels: _listLabels(ctx),
      );
    }
    await _offerStale(ctx, change);
  }

  Map<String, String> _listLabels(GrantContext ctx) => {
    for (final f in carrierListsOf(ctx.carrier)) f.fieldKey: f.label,
  };

  /// V12: labelled cards nothing grants any more, offered for removal.
  Future<void> _offerStale(GrantContext ctx, GrantChange change) async {
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
    final after = levelUp(fields, ctx, picked: picks.picked, added: picks.added);
    final l10n = L10n.of(context)!;
    // What it grants, shown before anything changes; [Level Up] applies it
    // and the same dialog stays.
    final change = settleGrants(fields, after, ctx);
    final applied = await showGrantSummaryDialog(
      context,
      title: l10n.freeLevelUpTitle(from, from + 1),
      summary: summarize(change),
      entities: ctx.entities,
      listLabels: _listLabels(ctx),
      confirm: l10n.charLevelUp,
      onConfirm: () async => _replaceFields(change.fields),
    );
    if (applied) await _offerStale(ctx, change);
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

  List<GuideStep> get _guide {
    final card = freePlayerCard(widget.schema);
    return card == null ? const [] : guideOf(card);
  }

  String? get _guideField =>
      _guideStep == null ? null : _guide.elementAtOrNull(_guideStep!)?.field;

  /// Where the guide is, stored outside undo.
  void _storeGuide(int step, bool open) {
    final c = _working;
    if (c == null || !_canEdit) return;
    _working = c.copyWith(
      entity: c.entity.copyWith(
        fields: {
          ...c.entity.fields,
          guideKey: guideProgressJson((step: step, open: open)),
        },
      ),
    );
    _pending = true;
    _scheduleSave();
  }

  /// Shows step [step]; every field is editable while the guide is open.
  void _guideTo(int step) {
    setState(() {
      _guideStep = step;
      if (_canEdit) _readOnly = false;
    });
    _storeGuide(step, true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideField());
  }

  /// Close pauses on the step; Done on the last one ends the guide, which
  /// then starts over.
  void _closeGuide({required bool done}) {
    final step = done ? 0 : _guideStep ?? 0;
    setState(() => _guideStep = null);
    _storeGuide(step, false);
  }

  void _resumeGuide() => _guideTo(
    guideProgressOf(_working!.entity.fields, _guide.length)?.step ?? 0,
  );

  /// Scrolls the step's field into view, opening its group; a step without
  /// a field, or whose field is gone, shows only its text.
  Future<void> _showGuideField() async {
    final key = _guideField;
    final row = _fieldRows[key];
    if (key == null || row == null || !mounted) return;
    await _jumpToRow(row);
    if (!mounted) return;
    final group = freePlayerCard(
      widget.schema,
    )?.fields.where((f) => f.fieldKey == key).firstOrNull?.groupId;
    _groupKeys[group]?.currentState?.expand();
    await WidgetsBinding.instance.endOfFrame;
    final ctx = _fieldKeys[key]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
      );
    }
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
    final steps = guideOf(card);
    // A new character opens on the guide (DESIGN §13.3).
    if (!_guideChecked) {
      _guideChecked = true;
      if (guideProgressOf(character.entity.fields, steps.length)?.open ??
          false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resumeGuide();
        });
      }
    }
    final sheet = EntityOpenScope(
      onOpen: _opensCard,
      child: _body(context, palette, character, card),
    );
    final guideOpen = _guideStep != null && steps.isNotEmpty;
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
            if (steps.isNotEmpty)
              IconButton(
                key: const ValueKey('free_sheet_guide'),
                icon: const Icon(Icons.signpost_outlined, size: 20),
                tooltip: l10n.freeGuide,
                onPressed: guideOpen ? null : _resumeGuide,
                visualDensity: VisualDensity.compact,
              ),
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
        // The guide: under the sheet when narrow, beside it when wide.
        body: !guideOpen
            ? sheet
            : LayoutBuilder(
                builder: (context, box) => box.maxWidth < 900
                    ? Column(
                        children: [
                          Expanded(child: sheet),
                          _guidePanel(steps, palette, side: false),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: sheet),
                          SizedBox(
                            width: 320,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                              child: _guidePanel(steps, palette, side: true),
                            ),
                          ),
                        ],
                      ),
              ),
        // Embedded in a world screen, that screen's dice button is there;
        // the guide's buttons take its corner.
        floatingActionButton: embedded || guideOpen ? null : const DiceFab(),
      ),
    );
  }

  /// The guide's step (DESIGN §13.3): its text, Back / Close / Done; no
  /// check that the field was filled (D24).
  Widget _guidePanel(
    List<GuideStep> steps,
    DmToolColors palette, {
    required bool side,
  }) {
    final l10n = L10n.of(context)!;
    final i = _guideStep!.clamp(0, steps.length - 1);
    final last = i == steps.length - 1;
    return Material(
      key: const ValueKey('free_guide_panel'),
      color: palette.featureCardBg,
      elevation: 6,
      shape: side
          ? RoundedRectangleBorder(
              borderRadius: palette.br,
              side: BorderSide(color: palette.featureCardBorder),
            )
          : Border(top: BorderSide(color: palette.featureCardAccent, width: 2)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.freeGuideStep(i + 1, steps.length),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: palette.srdHeadingRed,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: side ? 420 : MediaQuery.sizeOf(context).height / 4,
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: steps[i].text,
                    styleSheet: dmMarkdownStyle(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('guide_back'),
                    onPressed: i > 0 ? () => _guideTo(i - 1) : null,
                    child: Text(l10n.btnBack),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('guide_close'),
                    onPressed: () => _closeGuide(done: false),
                    child: Text(l10n.btnClose),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('guide_next'),
                    onPressed: () =>
                        last ? _closeGuide(done: true) : _guideTo(i + 1),
                    child: Text(l10n.btnDone),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          key: _ungroupedKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _fields(ungrouped, 1, card, character, entities, g),
        ),
        const SizedBox(height: 16),
      ],
      for (final grp in sortedGroups(card))
        if (fieldsIn(card, grp.groupId).isNotEmpty) ...[
          EntityCardCollapsibleGroupCard(
            key: _groupKeys.putIfAbsent(
              grp.groupId,
              GlobalKey<EntityCardCollapsibleGroupCardState>.new,
            ),
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
    _fieldRows = {
      for (final (i, r) in rows.indexed)
        if (r case EntityCardCollapsibleGroupCard(:final group))
          for (final f in fieldsIn(card, group.groupId)) f.fieldKey: i
        else if (r.key == _ungroupedKey)
          for (final f in ungrouped) f.fieldKey: i,
    };
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
                // Not a lazy ListView: see character_editor_screen.
                SingleChildScrollView(
                  controller: _sheetScroll,
                  // Bottom room so the dice button never covers the last row.
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        RepaintBoundary(key: _rowKeys[i], child: rows[i]),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: SectionJumpPad(
                    palette: palette,
                    sections: [for (final t in _navTargets) t.label],
                    onSelect: (i) =>
                        _jumpToRow(_navTargets[i].row),
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
      return _guided(
        f,
        !levelField || !g.cardsLoaded || _readOnly
            ? w
            : InkWell(
                key: const ValueKey('free_sheet_levels'),
                onTap: () => _editLevels(g.ctx),
                child: w,
              ),
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

  static const _ungroupedKey = ValueKey('free_sheet_ungrouped');

  /// [w] under its field's key, outlined while the guide shows it; the
  /// outline is drawn over it so nothing is rebuilt.
  Widget _guided(FieldSchema f, Widget w) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _guideField == f.fieldKey
          ? BoxDecoration(
              color: palette.featureCardAccent.withValues(alpha: 0.06),
              borderRadius: palette.br,
              border: Border.all(color: palette.featureCardAccent, width: 2),
            )
          : const BoxDecoration(),
      child: KeyedSubtree(
        key: _fieldKeys.putIfAbsent(f.fieldKey, GlobalKey.new),
        child: w,
      ),
    );
  }

  /// Scrolls row [index] to the top of the sheet; every row is mounted.
  Future<void> _jumpToRow(int index) async {
    final ctx = index < _rowKeys.length ? _rowKeys[index].currentContext : null;
    if (ctx != null) await Scrollable.ensureVisible(ctx, alignment: 0.02);
  }
}

/// What the sheet's field tiles need of the level system.
typedef _Grants = ({
  GrantContext ctx,
  GrantResult grants,
  Map<String, String> captions,
  bool cardsLoaded,
});
