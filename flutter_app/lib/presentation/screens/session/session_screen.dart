import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/character_provider.dart';
import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/world_characters_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/session.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/condition_badge.dart';
import '../../widgets/hp_bar.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/projection/projection_panel.dart';
import '../../widgets/resizable_split.dart';
import '../battle_map/battle_map_screen.dart';
import '../database/entity_card.dart';

/// Session tab — Python ui/tabs/session_tab.py birebir karşılığı.
/// Sol: Combat Tracker + Dice grubu
/// Sağ: Session kontrolleri + Event log + Alt tab'lar (Notes, BattleMap, Player, EntityStats)
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  // Session
  final _logInputController = TextEditingController();
  final _notesController = TextEditingController();
  // Debounce window for piping note edits into combatProvider. Edits ride the
  // combat_state settings patch (PendingWriteBuffer combatTick), so we batch
  // local keystrokes here before the per-state copyWith fires.
  Timer? _notesDebounce;
  // Captured in initState while `ref` is valid; dispose()/_onNotesChanged use
  // this instead of `ref.read` — `ref` is unsafe once the element is
  // deactivated. Mirrors the `late final BattleMapNotifier` pattern in
  // battle_map_screen.dart.
  late final CombatNotifier _combatNotifier;

  // Bottom tabs (desktop/tablet)
  int _bottomTabIndex = 0;
  // Lazy-mount: only tabs visited at least once are built; rest stay as
  // SizedBox.shrink() inside the IndexedStack until first activation. After
  // visit they remain mounted, so switching is just an index swap.
  final Set<int> _visitedBottomTabs = <int>{};
  // Mobile tabs: 0=Combat, 1=Log, 2=BattleMap
  int _mobileTabIndex = 0;
  // Log sub-tab: 0=EventLog, 1=Notes
  int _logSubTabIndex = 0;
  String? _selectedCombatantId;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _bottomTabIndex = ref.read(uiStateProvider).sessionBottomTab;
    _mobileTabIndex = ref.read(uiStateProvider).sessionMobileTab;
    _visitedBottomTabs.add(_bottomTabIndex);
    _combatNotifier = ref.read(combatProvider.notifier);
    _notesController.text = ref.read(combatProvider).sessionNotes;
    _notesController.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _combatNotifier.updateSessionNotes(_notesController.text);
    });
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesController.removeListener(_onNotesChanged);
    // Flush any pending edit so closing the screen doesn't lose the last
    // keystrokes within the debounce window. Uses the notifier captured in
    // initState — `ref` is unsafe here (element already deactivated).
    _combatNotifier.updateSessionNotes(_notesController.text);
    _logInputController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);

    // World swap (Fix A): combatProvider rebuilds when campaignRevisionProvider
    // bumps → fresh notifier carries the newly-loaded sessionNotes. Sync the
    // local controller; guard with text equality so user typing doesn't
    // trigger a feedback loop (controller change → addListener → notifier →
    // listen → controller).
    ref.listen<String>(
      combatProvider.select((s) => s.sessionNotes),
      (_, next) {
        if (_notesController.text != next) _notesController.text = next;
      },
    );

    // Auto-select entity when turn advances (without switching tab)
    ref.listen<int?>(
      combatProvider.select((s) => s.activeEncounter?.turnIndex),
      (previous, next) {
        if (previous == null || next == null || next < 0) return;
        final enc = ref.read(combatProvider).activeEncounter;
        if (enc == null || next >= enc.combatants.length) return;
        final entityId = enc.combatants[next].entityId;
        if (entityId != null) {
          setState(() {
            _selectedCombatantId = entityId;
          });
        }
      },
    );

    // İlk encounter yoksa oluştur
    final isEmpty = ref.watch(combatProvider.select((s) => s.encounters.isEmpty));
    if (isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(combatProvider.notifier).createEncounter('Encounter 1');
      });
    }

    if (screen == ScreenType.phone) {
      final combat = ref.watch(combatProvider);
      return _buildMobileLayout(palette, combat, combat.activeEncounter);
    }

    // Desktop/Tablet: ResizableSplit build sadece 1 kere çalışır.
    // İçerideki Consumer widget'lar kendi watch'larıyla rebuild olur.
    final uiState = ref.read(uiStateProvider);
    return ResizableSplit(
      axis: Axis.horizontal,
      initialRatio: uiState.sessionMainSplitterRatio,
      minFirstSize: 300,
      minSecondSize: 300,
      palette: palette,
      onRatioChanged: (r) {
        ref.read(uiStateProvider.notifier).update((s) => s.copyWith(sessionMainSplitterRatio: r));
      },
      first: Consumer(builder: (context, ref, _) {
        final (encounters, enc) = ref.watch(combatProvider.select(
          (s) => (s.encounters, s.activeEncounter),
        ));
        return _buildLeftPanel(palette, encounters, enc);
      }),
      second: Consumer(builder: (context, ref, _) {
        final eventLog =
            ref.watch(combatProvider.select((s) => s.eventLog));
        return _buildRightPanel(palette, eventLog);
      }),
    );
  }

  // ============================================================
  // SOL PANEL — Combat Tracker
  // ============================================================
  Widget _buildLeftPanel(
      DmToolColors palette, List<Encounter> encounters, Encounter? enc) {
    final l10n = L10n.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === Encounter satırı ===
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: enc?.id,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13, color: palette.tabActiveText, fontWeight: FontWeight.w600),
                    dropdownColor: palette.uiPopupBg,
                    items: encounters.map((e) =>
                      DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 13)))
                    ).toList(),
                    onChanged: (id) { if (id != null) ref.read(combatProvider.notifier).switchEncounter(id); },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => ref.read(combatProvider.notifier).createEncounter('Encounter ${encounters.length + 1}'),
                tooltip: l10n.sessionNewEncounter,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: enc == null ? null : () => _renameEncounter(enc),
                tooltip: l10n.sessionRename,
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: palette.dangerBtnBg),
                onPressed: encounters.length > 1 && enc != null ? () => ref.read(combatProvider.notifier).deleteEncounter(enc.id) : null,
                tooltip: l10n.btnDelete,
              ),
            ],
          ),
        ),

        Divider(height: 1, color: palette.sidebarDivider),

        // === Combat tablosu (DragTarget her zaman aktif) ===
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) => ref.read(combatProvider.notifier).canAddToEncounter(details.data),
            onAcceptWithDetails: (details) => ref.read(combatProvider.notifier).addCombatantFromEntity(details.data),
            builder: (context, candidateData, rejectedData) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  enc == null || enc.combatants.isEmpty
                      ? Center(child: Text(l10n.sessionNoCombatants, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
                      : _buildCombatTable(palette, enc),
                  if (candidateData.isNotEmpty)
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: palette.tabIndicator, width: 2)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        Divider(height: 1, color: palette.sidebarDivider),

        // === Alt kontrol çubuğu: Round + NextTurn + Players + Actions ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Round badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: palette.chr),
                  child: Text(l10n.sessionRound(enc?.round ?? 1), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                ),
                const SizedBox(width: 8),
                // Next Turn
                FilledButton.icon(
                  onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: Text(l10n.sessionNextTurn, style: const TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.actionBtnBg,
                    foregroundColor: palette.actionBtnText,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions dropdown — everything (Players opens own sub-dialog)
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'quick_add': _showQuickAddDialog();
                      case 'add': _showAddDialog();
                      case 'add_players': _showAddPlayersDialog();
                      case 'roll_init': _promptRollInitiative();
                      case 'clear_all': ref.read(combatProvider.notifier).clearAll();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'quick_add', child: _popupItem(Icons.bolt, l10n.sessionQuickAdd, palette.successBtnBg)),
                    PopupMenuItem(value: 'add', child: _popupItem(Icons.person_add, l10n.sessionAddFromDatabase, palette.primaryBtnBg)),
                    PopupMenuItem(value: 'add_players', child: _popupItem(Icons.group_add, l10n.sessionAddPlayersMenu, palette.primaryBtnBg)),
                    PopupMenuItem(value: 'roll_init', child: _popupItem(Icons.casino, l10n.sessionRollInitiative, palette.primaryBtnBg)),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'clear_all', child: _popupItem(Icons.delete_sweep, l10n.sessionClearAll, palette.dangerBtnBg)),
                  ],
                  child: FilledButton.icon(
                    onPressed: null, // PopupMenuButton handles the tap
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: Text(l10n.sessionActions, style: const TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // === Dice grubu === (left padding aligned with Round badge above)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [4, 6, 8, 10, 12, 20, 100].map((d) =>
              OutlinedButton(
                onPressed: () {
                  final roll = _rng.nextInt(d) + 1;
                  ref.read(combatProvider.notifier).addLog('d$d: $roll');
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: Text('d$d', style: const TextStyle(fontSize: 12)),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }

  /// Owned player chars in the active world. Online: pull from
  /// `worldCharactersProvider` (mirror covers other-player chars the local
  /// `characterListProvider` doesn't hydrate). Offline: filter the local
  /// list by worldId + ownerId.
  List<Character> _ownedWorldCharacters() {
    final worldId = ref.read(activeCampaignIdProvider).valueOrNull;
    final onlineIds = ref.read(onlineWorldIdsProvider);
    if (worldId != null && onlineIds.contains(worldId)) {
      final rows =
          ref.read(worldCharactersProvider(worldId)).valueOrNull ?? const [];
      final out = <Character>[];
      for (final r in rows) {
        if (r.ownerId == null || r.ownerId!.isEmpty) continue;
        try {
          final decoded = jsonDecode(r.payloadJson);
          if (decoded is Map<String, dynamic>) {
            out.add(Character.fromJson(decoded).copyWith(
              worldId: r.worldId,
              ownerId: r.ownerId,
            ));
          }
        } catch (_) {/* skip malformed */}
      }
      return out;
    }
    final list = ref.read(characterListProvider).valueOrNull ?? const [];
    return list
        .where((c) =>
            c.ownerId != null &&
            c.ownerId!.isNotEmpty &&
            (worldId == null || c.worldId == null || c.worldId == worldId))
        .toList();
  }

  /// Minimal theme-aware dialog opened from Actions → Add Players. Compact
  /// list: "Add all" row + one row per owned char. No extra chrome.
  Future<void> _showAddPlayersDialog() async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final chars = _ownedWorldCharacters();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: palette.uiPopupBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: palette.br,
            side: BorderSide(color: palette.featureCardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    l10n.sessionAddPlayersTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
                Divider(height: 1, color: palette.sidebarDivider),
                if (chars.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Text(
                      l10n.sessionNoOwnedChars,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  )
                else ...[
                  _addPlayersRow(
                    palette: palette,
                    icon: Icons.group_add,
                    label: l10n.sessionAddAll,
                    onTap: () {
                      for (final c in chars) {
                        ref
                            .read(combatProvider.notifier)
                            .addCombatantForCharacter(c);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  Divider(height: 1, color: palette.sidebarDivider),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: chars.length,
                      itemBuilder: (_, i) {
                        final c = chars[i];
                        return _addPlayersRow(
                          palette: palette,
                          icon: Icons.person,
                          label: c.entity.name,
                          onTap: () {
                            ref
                                .read(combatProvider.notifier)
                                .addCombatantForCharacter(c);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addPlayersRow({
    required DmToolColors palette,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: palette.tabActiveText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.tabActiveText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _popupItem(IconData icon, String label, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // ============================================================
  // SAĞ PANEL — Session Controls + Log + Bottom Tabs
  // ============================================================
  Widget _buildRightPanel(DmToolColors palette, List<String> eventLog) {
    final l10n = L10n.of(context)!;
    return Column(
      children: [
        // Session control bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: palette.tabBg,
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(l10n.sessionSession, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText))),
              // Multi-session selector intentionally deferred — app currently
              // owns a single implicit session per campaign.
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save, size: 14),
                label: Text(l10n.btnSave, style: const TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 28)),
              ),
            ],
          ),
        ),

        // Event log (üst) + Bottom tabs (alt) — resizable vertical split
        Expanded(
          child: ResizableSplit(
            axis: Axis.vertical,
            initialRatio: ref.read(uiStateProvider).sessionRightSplitterRatio,
            minFirstSize: 100,
            minSecondSize: 100,
            palette: palette,
            onRatioChanged: (r) {
              ref.read(uiStateProvider.notifier).update((s) => s.copyWith(sessionRightSplitterRatio: r));
            },
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(l10n.sessionEventLog, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
                ),
                Expanded(
                  child: eventLog.isEmpty
                      ? Center(child: Text(l10n.sessionNoEvents, style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: eventLog.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(eventLog[index], style: TextStyle(fontSize: 12, color: palette.htmlText)),
                            );
                          },
                        ),
                ),
                // Log input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: MarkdownTextArea(
                          controller: _logInputController,
                          decoration: InputDecoration(hintText: l10n.sessionQuickLogHint, isDense: true),
                          textStyle: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          onSubmitted: (_) => _addLogEntry(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _addLogEntry,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
                        child: Text(l10n.sessionAddLog, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bottom tabs (Notes / BattleMap / Player / EntityStats)
                Container(
                  color: palette.tabBg,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _bottomTab(l10n.sessionNotes, 0, palette),
                        _bottomTab(l10n.sessionBattleMap, 1, palette),
                        _bottomTab(l10n.sessionPlayerScreen, 2, palette),
                        _bottomTab(l10n.sessionEntityStats, 3, palette),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _buildBottomTabContent(palette)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomTab(String label, int index, DmToolColors palette) {
    final isActive = _bottomTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _bottomTabIndex = index;
          _visitedBottomTabs.add(index);
        });
        ref.read(uiStateProvider.notifier).update((s) => s.copyWith(sessionBottomTab: index));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? palette.tabActiveBg : palette.tabBg,
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isActive ? palette.tabActiveText : palette.tabText, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBottomTabContent(DmToolColors palette) {
    // IndexedStack keeps visited tabs mounted, so switching back is instant
    // (no remount, no provider re-init, no scroll/state loss). Unvisited
    // slots are SizedBox.shrink() — built on first activation only.
    Widget slot(int idx, Widget Function() build) {
      if (!_visitedBottomTabs.contains(idx)) return const SizedBox.shrink();
      return build();
    }

    return IndexedStack(
      index: _bottomTabIndex,
      sizing: StackFit.expand,
      children: [
        // 0: Notes — no provider watch in build; controller is shared state.
        slot(
          0,
          () => Padding(
            padding: const EdgeInsets.all(12),
            child: MarkdownTextArea(
              controller: _notesController,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(hintText: L10n.of(context)!.sessionDmNotesHint, border: InputBorder.none, filled: false, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
              textStyle: TextStyle(fontSize: 13, color: palette.htmlText),
            ),
          ),
        ),
        // 1: Battle Map — encounter watch scoped to inner Consumer so
        // SessionScreen.build doesn't rebuild on every combat tick. Key
        // ValueKey(encId) forces remount only when the active encounter
        // actually changes; plain tab switches keep the same notifier state.
        slot(
          1,
          () => Consumer(builder: (context, ref, _) {
            final encId = ref.watch(combatProvider.select((s) => s.activeEncounter?.id));
            if (encId == null) {
              return Center(child: Text(L10n.of(context)!.sessionNoActiveEncounter, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
            }
            return BattleMapScreen(key: ValueKey(encId), encounterId: encId);
          }),
        ),
        // 2: Player Screen — const, no watches.
        slot(2, () => const ProjectionPanel()),
        // 3: Entity Stats — schema + entity watches scoped to inner Consumer.
        slot(3, () => _EntityStatsTab(
              selectedCombatantId: _selectedCombatantId,
              palette: palette,
            )),
      ],
    );
  }

  // ============================================================
  // COMBAT TABLE
  // ============================================================

  /// Sentinel `subFieldKey` for the special "Conditions" column. Lets the
  /// user position the condition badges anywhere in the table column list
  /// from the encounter settings editor instead of the legacy "always at
  /// the end" placement. Detected by both the header and row builders.
  static const String conditionsColumnKey = '__conditions__';

  /// Returns the column list for the combat tracker, falling back to a
  /// hardcoded legacy default (Init / AC / HP) when the loaded schema's
  /// `encounterConfig.columns` is empty — guarantees the table still shows
  /// the basic combat stats on legacy / un-configured campaigns. The
  /// fallback intentionally omits `level`: it used to live here and would
  /// silently re-appear after a user removed it from the template, which
  /// looked like a bug.
  static const List<EncounterColumnConfig> _fallbackCombatColumns = [
    EncounterColumnConfig(subFieldKey: 'initiative', label: 'Init', editable: true, width: 48),
    EncounterColumnConfig(subFieldKey: 'ac',         label: 'AC',  editable: true, width: 36),
    EncounterColumnConfig(subFieldKey: 'hp',         label: 'HP',  editable: true, showButtons: true, width: 130),
  ];

  static List<EncounterColumnConfig> _effectiveColumns(EncounterConfig cfg) =>
      cfg.columns.isNotEmpty ? cfg.columns : _fallbackCombatColumns;

  /// True when the user has explicitly placed a Conditions column via the
  /// encounter settings editor. Used by the renderer to skip the legacy
  /// "always at the end" Conditions block — the user-positioned one
  /// already shows them.
  static bool _hasConditionsColumn(List<EncounterColumnConfig> cols) =>
      cols.any((c) => c.subFieldKey == conditionsColumnKey);

  Widget _buildCombatTable(DmToolColors palette, Encounter enc) {
    final l10n = L10n.of(context)!;
    // `watch` (not `read`) so the table rebuilds when the lazy template
    // sync flow swaps the world schema in place — otherwise edits to the
    // template's columns / labels never reach this screen until a full
    // restart.
    final schema = ref.watch(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    final cols = _effectiveColumns(cfg);
    // When the user has placed a conditions column explicitly via the
    // table-columns editor, that column owns the condition badges and the
    // legacy "always at the end" block is skipped. Otherwise the legacy
    // block keeps showing up so existing campaigns don't lose conditions.
    final hasConditions = _hasConditionsColumn(cols);

    return Column(
      children: [
        // Header — Name + dynamic columns (with optional Conditions column).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: palette.tabBg,
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(l10n.sessionName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              ...cols.map((col) {
                if (col.subFieldKey == conditionsColumnKey) {
                  // Conditions column lives in the user-chosen position;
                  // give it `Expanded` so the badges have room to wrap.
                  return Expanded(
                    flex: 2,
                    child: Text(col.label.isEmpty ? l10n.sessionConditions : col.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText)),
                  );
                }
                return SizedBox(
                  width: col.width > 0 ? col.width.toDouble() : 60,
                  child: Text(col.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center),
                );
              }),
              if (!hasConditions) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text(l10n.sessionConditions, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              ],
              const SizedBox(width: 28),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) => ref.read(combatProvider.notifier).canAddToEncounter(details.data),
            onAcceptWithDetails: (details) => ref.read(combatProvider.notifier).addCombatantFromEntity(details.data),
            builder: (context, candidateData, rejectedData) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ListView.builder(
                    itemCount: enc.combatants.length,
                    itemBuilder: (context, index) => _CombatantRow(
                      key: ValueKey(enc.combatants[index].id),
                      combatant: enc.combatants[index],
                      index: index,
                      turnIndex: enc.turnIndex,
                      palette: palette,
                      onSelect: (entityId) => setState(() {
                        _selectedCombatantId = entityId;
                        _bottomTabIndex = 3;
                        ref.read(uiStateProvider.notifier).update((s) => s.copyWith(sessionBottomTab: 3));
                      }),
                      onModifyStat: (c, subKey, delta, stats, cfg) => _modifyStat(c, subKey, delta, stats, cfg),
                      onSetStat: (c, subKey, newVal, cfg) => _setStat(c, subKey, newVal, cfg),
                      onShowAddCondition: (combatantId, _) => _showAddConditionDialog(combatantId),
                    ),
                  ),
                  if (candidateData.isNotEmpty)
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: palette.tabIndicator, width: 2)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Adjust a combat-stat subfield by [delta]. Only mutates the combatant
  /// snapshot — the source entity is never touched (encounter is a COPY).
  void _modifyStat(Combatant c, String subKey, int delta, Map<String, dynamic> stats, EncounterConfig cfg) {
    if (subKey == 'hp') {
      ref.read(combatProvider.notifier).modifyHp(c.id, delta);
      return;
    }
    final currentVal = int.tryParse(stats[subKey]?.toString() ?? '') ?? 0;
    final maxKey = 'max_$subKey';
    final maxVal = int.tryParse(stats[maxKey]?.toString() ?? '') ?? 9999;
    final newVal = (currentVal + delta).clamp(0, maxVal);
    ref.read(combatProvider.notifier)
        .setStat(c.id, subKey, newVal.toString());
  }

  /// Set a combat-stat subfield to a raw string. Combatant-only write.
  void _setStat(Combatant c, String subKey, String newVal, EncounterConfig cfg) {
    ref.read(combatProvider.notifier).setStat(c.id, subKey, newVal);
  }

  /// Roll initiative for every combatant. d20 fixed — no dice picker. PC
  /// chars roll 1d20 + modifier; monsters with a flat `initiative_score`
  /// skip the roll and use that score directly.
  void _promptRollInitiative() {
    ref.read(combatProvider.notifier).rollInitiatives();
  }

  // ============================================================
  // MOBILE LAYOUT
  // ============================================================
  Widget _buildMobileLayout(DmToolColors palette, CombatState combat, Encounter? enc) {
    return Stack(
      children: [
        Column(
          children: [
            // Top tab bar: Combat | Log | Map
            _buildMobileTabBar(palette),
            // Tab content — full remaining height
            Expanded(
              child: LazyIndexedStack(
                index: _mobileTabIndex,
                children: [
                  _buildMobileCombatTab(palette, combat, enc),
                  _buildMobileLogTab(palette, combat),
                  _buildMobileBattleMapTab(palette, enc),
                  const ProjectionPanel(),
                  _buildMobileEntityStatsTab(palette),
                ],
              ),
            ),
          ],
        ),
        // Dice FAB only on Combat tab
        if (_mobileTabIndex == 0)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'session_screen_dice_fab',
              mini: true,
              onPressed: () => _showDiceBottomSheet(palette),
              child: const Icon(Icons.casino),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTabBar(DmToolColors palette) {
    final l10n = L10n.of(context)!;
    return Container(
      color: palette.tabBg,
      child: Row(
        children: [
          _mobileTab(l10n.sessionCombat, Icons.shield, 0, palette),
          _mobileTab(l10n.sessionLog, Icons.list_alt, 1, palette),
          _mobileTab(l10n.sessionMap, Icons.map, 2, palette),
          _mobileTab(l10n.sessionPlayer, Icons.tv, 3, palette),
          _mobileTab(l10n.sessionStats, Icons.assessment, 4, palette),
        ],
      ),
    );
  }

  Widget _mobileTab(String label, IconData icon, int index, DmToolColors palette) {
    final isActive = _mobileTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _mobileTabIndex = index);
          ref.read(uiStateProvider.notifier).update(
            (s) => s.copyWith(sessionMobileTab: index),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? palette.tabActiveBg : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? palette.tabActiveText : palette.tabText),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                fontSize: 12,
                color: isActive ? palette.tabActiveText : palette.tabText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // --- Combat Tab ---
  Widget _buildMobileCombatTab(DmToolColors palette, CombatState combat, Encounter? enc) {
    final l10n = L10n.of(context)!;
    return Column(
      children: [
        // Encounter selector + Round bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: palette.tabBg,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: combat.activeEncounterId,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(fontSize: 12, color: palette.tabActiveText),
                    dropdownColor: palette.uiPopupBg,
                    items: combat.encounters.map((e) =>
                      DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 12)))
                    ).toList(),
                    onChanged: (id) { if (id != null) ref.read(combatProvider.notifier).switchEncounter(id); },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: palette.chr),
                child: Text(l10n.sessionRoundShort(enc?.round ?? 1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(l10n.sessionNext, style: const TextStyle(fontSize: 11)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'quick_add': _showQuickAddDialog();
                    case 'add': _showAddDialog();
                    case 'add_players': _showAddPlayersDialog();
                    case 'roll_init': _promptRollInitiative();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'quick_add', child: Text(l10n.sessionQuickAdd, style: const TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'add', child: Text(l10n.sessionAddFromDatabase, style: const TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'add_players', child: Text(l10n.sessionAddPlayersMenu, style: const TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'roll_init', child: Text(l10n.sessionRollInitiative, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
        // Combat cards — full remaining height
        Expanded(
          child: enc != null && enc.combatants.isNotEmpty
              ? _buildMobileCombatList(palette, enc)
              : Center(child: Text(l10n.sessionNoCombatantsShort, style: TextStyle(color: palette.sidebarLabelSecondary))),
        ),
      ],
    );
  }

  // --- Log Tab ---
  Widget _buildMobileLogTab(DmToolColors palette, CombatState combat) {
    return Column(
      children: [
        // Sub-tab toggle: Event Log | Notes
        Container(
          color: palette.tabBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _logSubTab(L10n.of(context)!.sessionEventLog, 0, palette),
              const SizedBox(width: 8),
              _logSubTab(L10n.of(context)!.sessionNotes, 1, palette),
            ],
          ),
        ),
        Expanded(
          child: _logSubTabIndex == 0
              ? _buildFullScreenEventLog(palette, combat)
              : _buildFullScreenNotes(palette),
        ),
      ],
    );
  }

  Widget _logSubTab(String label, int index, DmToolColors palette) {
    final isActive = _logSubTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _logSubTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? palette.tabActiveBg : Colors.transparent,
          borderRadius: palette.br,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          color: isActive ? palette.tabActiveText : palette.tabText,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }

  Widget _buildFullScreenEventLog(DmToolColors palette, CombatState combat) {
    return Column(
      children: [
        Expanded(
          child: combat.eventLog.isEmpty
              ? Center(child: Text(L10n.of(context)!.sessionNoEvents, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: combat.eventLog.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(combat.eventLog[i], style: TextStyle(fontSize: 13, color: palette.htmlText)),
                  ),
                ),
        ),
        // Log input pinned at bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: MarkdownTextArea(
                  controller: _logInputController,
                  decoration: InputDecoration(hintText: L10n.of(context)!.sessionQuickLogHint, isDense: true, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
                  textStyle: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  onSubmitted: (_) => _addLogEntry(),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _addLogEntry,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                child: Text(L10n.of(context)!.sessionAdd, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullScreenNotes(DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: MarkdownTextArea(
        controller: _notesController,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: L10n.of(context)!.sessionDmNotesHint,
          border: InputBorder.none,
          filled: false,
          hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
        ),
        textStyle: TextStyle(fontSize: 14, color: palette.htmlText),
      ),
    );
  }

  // --- Battle Map Tab ---
  Widget _buildMobileBattleMapTab(DmToolColors palette, Encounter? enc) {
    if (enc == null) {
      return Center(
        child: Text(L10n.of(context)!.sessionNoActiveEncounter, style: TextStyle(color: palette.sidebarLabelSecondary)),
      );
    }
    return BattleMapScreen(encounterId: enc.id);
  }

  // --- Entity Stats Tab (mobile) ---
  Widget _buildMobileEntityStatsTab(DmToolColors palette) {
    if (_selectedCombatantId == null) {
      return Center(
        child: Text(L10n.of(context)!.sessionSelectCombatantStats,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.sidebarLabelSecondary)),
      );
    }
    final schema = ref.watch(worldSchemaProvider);
    final entity = ref.watch(
      entityProvider.select((map) => map[_selectedCombatantId]),
    );
    if (entity == null) {
      return Center(
        child: Text(L10n.of(context)!.sessionEntityNotFound,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.sidebarLabelSecondary)),
      );
    }
    final catSchema = schema.categories
        .where((c) => c.slug == entity.categorySlug)
        .firstOrNull;
    // EntityCard already wraps content in a SingleChildScrollView; nesting
    // another scroll view here swallows the drag gesture and locks the body.
    return EntityCard(
      entityId: _selectedCombatantId!,
      categorySchema: catSchema,
      readOnly: true,
    );
  }

  Widget _buildMobileCombatList(DmToolColors palette, Encounter enc) {
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;

    // Resolve condition sub-fields ONCE per list build (was running
    // per-item, O(N · categories · fields) under combat updates).
    List<Map<String, String>>? condSubFields;
    for (final cat in schema.categories) {
      for (final f in cat.fields) {
        if (f.fieldKey == cfg.conditionStatsFieldKey) {
          condSubFields = f.subFields;
          break;
        }
      }
      if (condSubFields != null) break;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: enc.combatants.length,
      itemBuilder: (context, index) {
        final c = enc.combatants[index];
        // Encounter is a COPY — read stats from combatant snapshot, not the
        // live entity. Source entity may not be in `entities` map (other
        // player's owned char) and never updates after add anyway.
        final statsMap = Map<String, dynamic>.from(c.stats);

        return _MobileCombatCard(
          key: ValueKey(c.id),
          combatant: c,
          isActive: index == enc.turnIndex,
          palette: palette,
          config: cfg,
          statsMap: statsMap,
          onTap: () {
            setState(() {
              _selectedCombatantId = c.entityId;
              _mobileTabIndex = 4;
            });
            ref.read(uiStateProvider.notifier).update(
              (s) => s.copyWith(sessionMobileTab: 4),
            );
          },
          onModifyStat: (subKey, delta) => _modifyStat(c, subKey, delta, statsMap, cfg),
          onDelete: () => ref.read(combatProvider.notifier).deleteCombatant(c.id),
          onAddCondition: (id) => _showAddConditionDialog(id),
          onRemoveCondition: (id, name) => ref.read(combatProvider.notifier).removeCondition(id, name),
          onUpdateConditionDuration: (id, name, dur) => ref.read(combatProvider.notifier).updateConditionDuration(id, name, dur),
          conditionStatsSubFields: condSubFields,
          getConditionStats: (entityId) {
            if (entityId == null) return {};
            final allEntities = ref.read(entityProvider);
            final e = allEntities[entityId];
            final raw = e?.fields[cfg.conditionStatsFieldKey];
            return raw is Map ? Map<String, dynamic>.from(raw) : {};
          },
        );
      },
    );
  }

  void _showDiceBottomSheet(DmToolColors palette) {
    int? lastRoll;
    String? lastDie;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(palette.cardBorderRadius)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lastRoll != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$lastDie: $lastRoll',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: palette.tabActiveText),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [4, 6, 8, 10, 12, 20, 100].map((d) =>
                  SizedBox(
                    width: 72,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        final roll = _rng.nextInt(d) + 1;
                        ref.read(combatProvider.notifier).addLog('d$d: $roll');
                        setSheetState(() {
                          lastRoll = roll;
                          lastDie = 'd$d';
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.featureCardBg,
                        foregroundColor: palette.tabActiveText,
                      ),
                      child: Text('d$d', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showQuickAddDialog() {
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    final nameController = TextEditingController();
    final nameFocus = FocusNode();
    int quantity = 1;
    // Dinamik alan controller'ları — encounterConfig columns'dan + max_hp
    final statControllers = <String, TextEditingController>{};
    for (final col in cfg.columns) {
      statControllers[col.subFieldKey] = TextEditingController();
    }
    final hasMaxHpColumn = cfg.columns.any((c) => c.subFieldKey == 'max_hp');
    if (!hasMaxHpColumn) {
      statControllers['max_hp'] = TextEditingController();
    }

    // Dialog mount + IME açılışını aynı frame'e bindirmek mobilde
    // gözle görülür gecikme yaratıyor; transition bitince focus iste.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (nameFocus.canRequestFocus) nameFocus.requestFocus();
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l10n.sessionQuickAdd, style: const TextStyle(fontSize: 14)),
            content: SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextField(
                      controller: nameController,
                      focusNode: nameFocus,
                      decoration: InputDecoration(labelText: l10n.sessionName),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Quantity
                    Row(
                      children: [
                        Text(l10n.sessionQuantity, style: TextStyle(fontSize: 12, color: palette.tabText)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: quantity > 1
                              ? () => setDialogState(() => quantity--)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.featureCardBg,
                            borderRadius: palette.chr,
                          ),
                          child: Text('$quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: quantity < 20
                              ? () => setDialogState(() => quantity++)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: palette.sidebarDivider),
                    const SizedBox(height: 4),
                    Text(l10n.sessionCombatStats, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
                    const SizedBox(height: 8),
                    // Dinamik stat alanları
                    ...cfg.columns.map((col) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: statControllers[col.subFieldKey],
                        decoration: InputDecoration(
                          labelText: col.label,
                          hintText: col.subFieldKey == 'hp' ? '10' : '0',
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
                    // Max HP (columns'da yoksa ekstra göster)
                    if (!hasMaxHpColumn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: statControllers['max_hp'],
                          decoration: InputDecoration(
                            labelText: l10n.sessionMaxHp,
                            hintText: l10n.sessionHpHintSameAs,
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                        ),
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
              FilledButton.icon(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  // Stat map oluştur
                  final stats = <String, String>{};
                  for (final col in cfg.columns) {
                    final val = statControllers[col.subFieldKey]?.text.trim() ?? '';
                    if (val.isNotEmpty) stats[col.subFieldKey] = val;
                  }

                  // Quantity kadar ekle
                  final notifier = ref.read(combatProvider.notifier);
                  if (quantity == 1) {
                    notifier.addDirectRow(name, stats: stats);
                  } else {
                    for (int i = 1; i <= quantity; i++) {
                      notifier.addDirectRow('$name $i', stats: stats);
                    }
                  }

                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(quantity > 1 ? l10n.sessionAddWithQuantity(quantity) : l10n.sessionAdd, style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.successBtnBg,
                  foregroundColor: palette.successBtnText,
                ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      for (final c in statControllers.values) {
        c.dispose();
      }
    });
  }

  void _addLogEntry() {
    final text = _logInputController.text.trim();
    if (text.isEmpty) return;
    ref.read(combatProvider.notifier).addLog(text);
    _logInputController.clear();
  }

  void _renameEncounter(Encounter enc) {
    final controller = TextEditingController(text: enc.name);
    final l10n = L10n.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionRenameEncounterTitle, style: const TextStyle(fontSize: 14)),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: l10n.sessionName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty && name != enc.name) {
              ref.read(combatProvider.notifier).renameEncounter(enc.id, name);
            }
            Navigator.pop(ctx);
          }, child: Text(l10n.sessionRename)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showAddDialog() async {
    final combatSlugs = ref.read(combatProvider.notifier).combatCapableSlugs.toList();
    final result = await showEntitySelectorDialog(
      context: context,
      ref: ref,
      allowedTypes: combatSlugs,
      multiSelect: true,
    );
    if (result != null) {
      for (final id in result) {
        ref.read(combatProvider.notifier).addCombatantFromEntity(id);
      }
    }
  }

  void _showAddConditionDialog(String combatantId) {
    final nameController = TextEditingController();
    final durationController = TextEditingController();

    // Find condition entities (those with conditionStats field)
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    final conditionSlugs = <String>{};
    for (final cat in schema.categories) {
      if (cat.fields.any((f) => f.fieldKey == cfg.conditionStatsFieldKey)) {
        conditionSlugs.add(cat.slug);
      }
    }
    final entities = ref.read(entityProvider);
    final conditionEntities = entities.values
        .where((e) => conditionSlugs.contains(e.categorySlug))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final l10n = L10n.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionAddConditionTitle, style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Entity-based conditions
              if (conditionEntities.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: conditionEntities.map((e) {
                        final stats = e.fields[cfg.conditionStatsFieldKey];
                        final defaultDuration = stats is Map ? int.tryParse('${stats['default_duration'] ?? ''}') : null;
                        final hasImage = e.imagePath.isNotEmpty || e.images.isNotEmpty;
                        final imgPath = e.imagePath.isNotEmpty ? e.imagePath : (e.images.isNotEmpty ? e.images.first : null);
                        return ActionChip(
                          avatar: hasImage && imgPath != null
                              ? CircleAvatar(
                                  backgroundImage: FileImage(File(imgPath)),
                                  radius: 10,
                                )
                              : null,
                          label: Text(e.name, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            ref.read(combatProvider.notifier).addCondition(combatantId, e.name, defaultDuration, entityId: e.id);
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              // Custom condition
              TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.sessionCustomCondition), autofocus: conditionEntities.isEmpty),
              const SizedBox(height: 8),
              TextField(controller: durationController, decoration: InputDecoration(labelText: l10n.sessionDurationHint), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            ref.read(combatProvider.notifier).addCondition(combatantId, name, int.tryParse(durationController.text));
            Navigator.pop(ctx);
          }, child: Text(l10n.sessionAddCustom)),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
      durationController.dispose();
    });
  }
}

/// Compact mobile combat card showing combatant stats in a card layout.
class _MobileCombatCard extends StatelessWidget {
  final Combatant combatant;
  final bool isActive;
  final DmToolColors palette;
  final EncounterConfig config;
  final Map<String, dynamic> statsMap;
  final VoidCallback onTap;
  final void Function(String subKey, int delta) onModifyStat;
  final VoidCallback onDelete;
  final void Function(String combatantId) onAddCondition;
  final void Function(String combatantId, String conditionName) onRemoveCondition;
  final void Function(String combatantId, String condName, int? newDuration) onUpdateConditionDuration;
  final List<Map<String, String>>? conditionStatsSubFields;
  final Map<String, dynamic> Function(String? entityId) getConditionStats;

  const _MobileCombatCard({
    super.key,
    required this.combatant,
    required this.isActive,
    required this.palette,
    required this.config,
    required this.statsMap,
    required this.onTap,
    required this.onModifyStat,
    required this.onDelete,
    required this.onAddCondition,
    required this.onRemoveCondition,
    required this.onUpdateConditionDuration,
    required this.getConditionStats,
    this.conditionStatsSubFields,
  });

  @override
  Widget build(BuildContext context) {
    final hp = int.tryParse(statsMap['hp']?.toString() ?? '') ?? 0;
    final maxHp = int.tryParse(statsMap['max_hp']?.toString() ?? '') ?? (hp > 0 ? hp : 1);
    final ac = statsMap['ac']?.toString() ?? '-';
    final init = statsMap[config.initiativeSubField]?.toString() ?? '-';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? palette.tokenBorderActive.withValues(alpha: 0.08) : palette.featureCardBg,
          borderRadius: palette.cbr,
          border: Border.all(
            color: isActive ? palette.tokenBorderActive : palette.featureCardBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Name + Init badge + AC + delete
            Row(
              children: [
                // Initiative badge
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: palette.tabBg,
                    borderRadius: palette.chr,
                  ),
                  child: Center(
                    child: Text(init, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  ),
                ),
                const SizedBox(width: 8),
                // Name
                Expanded(
                  child: Text(
                    combatant.name,
                    style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: palette.tabActiveText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // AC badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.tabBg,
                    borderRadius: palette.chr,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 12, color: palette.tabText),
                      const SizedBox(width: 2),
                      Text(ac, style: TextStyle(fontSize: 11, color: palette.tabActiveText, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Delete
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.close, size: 16, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // HP bar with +/- buttons
            Row(
              children: [
                InkWell(
                  onTap: () => onModifyStat('hp', -1),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: palette.hpBtnDecreaseBg, borderRadius: palette.br),
                    child: Center(child: Text('-', style: TextStyle(fontSize: 16, color: palette.hpBtnText, fontWeight: FontWeight.bold))),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: HpBar(hp: hp, maxHp: maxHp > 0 ? maxHp : 1, palette: palette)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onModifyStat('hp', 1),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: palette.br),
                    child: Center(child: Text('+', style: TextStyle(fontSize: 16, color: palette.hpBtnText, fontWeight: FontWeight.bold))),
                  ),
                ),
              ],
            ),
            // Conditions
            if (combatant.conditions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: combatant.conditions.map((cond) => ConditionBadge(
                  condition: cond,
                  combatantId: combatant.id,
                  palette: palette,
                  conditionStats: getConditionStats(cond.entityId),
                  conditionStatsSubFields: conditionStatsSubFields,
                  onRemove: () => onRemoveCondition(combatant.id, cond.name),
                  onUpdateDuration: (dur) => onUpdateConditionDuration(combatant.id, cond.name, dur),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Extracted combatant row — own ConsumerWidget so entity watch is per-row.
// Only rebuilds when THIS combatant's entity changes, not all entities.
// =============================================================================

class _CombatantRow extends ConsumerWidget {
  final Combatant combatant;
  final int index;
  final int turnIndex;
  final DmToolColors palette;
  /// Selects this combatant — highlights the row and switches the bottom
  /// tab to Entity Stats. Fired on any tap on the row that isn't absorbed
  /// by an InkWell on an editable cell.
  final void Function(String? entityId) onSelect;
  final void Function(Combatant c, String subKey, int delta, Map<String, dynamic> stats, EncounterConfig cfg) onModifyStat;
  /// Sets a combat stat to a raw string value (for inline editing).
  final void Function(Combatant c, String subKey, String newVal, EncounterConfig cfg) onSetStat;
  final void Function(String combatantId, List<String> conditions) onShowAddCondition;

  const _CombatantRow({
    super.key,
    required this.combatant,
    required this.index,
    required this.turnIndex,
    required this.palette,
    required this.onSelect,
    required this.onModifyStat,
    required this.onSetStat,
    required this.onShowAddCondition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = combatant;
    final isActive = index == turnIndex;
    // `watch` (not `read`) so combatant rows rebuild after a template
    // sync — otherwise their column layout / labels stay frozen on the
    // pre-update schema until a hot restart.
    final schema = ref.watch(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    final cols = _SessionScreenState._effectiveColumns(cfg);

    // Encounter is a COPY — stats come from the combatant snapshot, not the
    // live entity. `c.entityId` is retained only so the row can open the
    // original DB card on tap.
    final statsMap = Map<String, dynamic>.from(c.stats);

    return GestureDetector(
      onTap: () => onSelect(c.entityId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? palette.tokenBorderActive.withValues(alpha: 0.08) : null,
          border: Border(
            left: isActive ? BorderSide(color: palette.tokenBorderActive, width: 3) : BorderSide.none,
            bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            // Name — tapping the row (including the name) selects the
            // combatant and switches the bottom tab to Entity Stats.
            Expanded(
              flex: 2,
              child: Text(
                c.name,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.tabActiveText,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Dynamic columns from encounterConfig (with legacy fallback
            // when the loaded schema's columns list is empty).
            ...cols.map((col) {
              // Conditions sentinel column — render the same condition
              // wrap that the legacy "always at the end" block uses, but
              // at the user-chosen position. `Expanded` so the badges
              // have room to wrap regardless of `col.width`.
              if (col.subFieldKey == _SessionScreenState.conditionsColumnKey) {
                return Expanded(
                  flex: 2,
                  child: _buildConditionsCell(context, ref, c, cfg, schema),
                );
              }

              final val = statsMap[col.subFieldKey]?.toString() ?? '';

              if (col.showButtons) {
                final numVal = int.tryParse(val) ?? 0;
                final maxKey = 'max_${col.subFieldKey}';
                final maxVal = int.tryParse(statsMap[maxKey]?.toString() ?? '') ?? numVal;
                return SizedBox(
                  width: col.width > 0 ? col.width.toDouble() : 130,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => onModifyStat(c, col.subFieldKey, -1, statsMap, cfg),
                        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnDecreaseBg, borderRadius: palette.br),
                          child: Center(child: Text('-', style: TextStyle(fontSize: 14, color: palette.hpBtnText, fontWeight: FontWeight.bold)))),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showInlineEdit(
                            context,
                            label: col.label,
                            initial: val,
                            onSubmit: (v) =>
                                onSetStat(c, col.subFieldKey, v, cfg),
                          ),
                          child: HpBar(hp: numVal, maxHp: maxVal > 0 ? maxVal : 1, palette: palette),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => onModifyStat(c, col.subFieldKey, 1, statsMap, cfg),
                        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: palette.br),
                          child: Center(child: Text('+', style: TextStyle(fontSize: 14, color: palette.hpBtnText, fontWeight: FontWeight.bold)))),
                      ),
                    ],
                  ),
                );
              }

              // Plain cell — tap to inline-edit.
              //
              // Special case: the initiative column should display the
              // **rolled** combatant init (`c.init`), not the entity's
              // dice spec. The dice spec is what we want to *edit*
              // though, so on tap we still pop the inline-edit dialog
              // with the spec as the initial value.
              final isInitCol = col.subFieldKey == cfg.initiativeSubField;
              final display = isInitCol ? c.init.toString() : val;
              return SizedBox(
                width: col.width > 0 ? col.width.toDouble() : 60,
                child: InkWell(
                  onTap: () => _showInlineEdit(
                    context,
                    label: col.label,
                    initial: val,
                    onSubmit: (v) => onSetStat(c, col.subFieldKey, v, cfg),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(
                      display.isEmpty ? '—' : display,
                      style: TextStyle(
                        fontSize: 12,
                        color: display.isEmpty
                            ? palette.sidebarLabelSecondary
                            : palette.tabActiveText,
                        fontWeight:
                            isInitCol ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }),
            // Legacy "always at the end" Conditions slot — only shown when
            // the user has NOT placed a conditions column explicitly via
            // the encounter settings editor. Keeps existing campaigns
            // working without forcing them to opt-in.
            if (!_SessionScreenState._hasConditionsColumn(cols)) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildConditionsCell(context, ref, c, cfg, schema),
              ),
            ],
            // Delete
            IconButton(
              icon: Icon(Icons.close, size: 14, color: palette.sidebarLabelSecondary),
              onPressed: () => ref.read(combatProvider.notifier).deleteCombatant(c.id),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the wrap of condition badges + the "add condition" button
  /// for [c]. Extracted so the same widget can be used in two places:
  /// (1) inline at the position of the user-placed conditions column, or
  /// (2) the legacy "always at the end" slot when no such column exists.
  Widget _buildConditionsCell(
    BuildContext context,
    WidgetRef ref,
    Combatant c,
    EncounterConfig cfg,
    WorldSchema schema,
  ) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        ...c.conditions.map((cond) {
          // Look up condition entity stats for tooltip
          Map<String, dynamic>? condStats;
          if (cond.entityId != null) {
            final condEntity = ref.watch(entityProvider.select((m) => m[cond.entityId]));
            final raw = condEntity?.fields[cfg.conditionStatsFieldKey];
            if (raw is Map) condStats = Map<String, dynamic>.from(raw);
          }
          // Get sub-field definitions for labels
          List<Map<String, String>>? condSubFields;
          for (final cat in schema.categories) {
            for (final f in cat.fields) {
              if (f.fieldKey == cfg.conditionStatsFieldKey) {
                condSubFields = f.subFields;
                break;
              }
            }
            if (condSubFields != null) break;
          }
          return ConditionBadge(
            condition: cond,
            combatantId: c.id,
            palette: palette,
            conditionStats: condStats,
            conditionStatsSubFields: condSubFields,
            onRemove: () => ref.read(combatProvider.notifier).removeCondition(c.id, cond.name),
            onUpdateDuration: (dur) => ref.read(combatProvider.notifier).updateConditionDuration(c.id, cond.name, dur),
          );
        }),
        InkWell(
          onTap: () => onShowAddCondition(c.id, cfg.conditions),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(border: Border.all(color: palette.sidebarDivider), borderRadius: palette.cbr),
            child: Icon(Icons.add, size: 12, color: palette.sidebarLabelSecondary),
          ),
        ),
      ],
    );
  }

  /// Pops a tiny inline-edit dialog with a single text field. Used for
  /// every editable cell in the encounter table — the user types a value
  /// and the new string is written back to the entity's combat_stats via
  /// [onSetStat].
  void _showInlineEdit(
    BuildContext context, {
    required String label,
    required String initial,
    required void Function(String value) onSubmit,
  }) {
    final controller = TextEditingController(text: initial);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) {
            onSubmit(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.of(context)!.btnCancel),
          ),
          FilledButton(
            onPressed: () {
              onSubmit(controller.text);
              Navigator.pop(ctx);
            },
            child: Text(L10n.of(context)!.btnSave),
          ),
        ],
      ),
    );
  }
}

/// Entity Stats bottom-tab content. Scoped to its own Consumer so the
/// expensive worldSchema + entity watches don't bubble up to
/// SessionScreen.build on every entity edit.
class _EntityStatsTab extends ConsumerWidget {
  final String? selectedCombatantId;
  final DmToolColors palette;

  const _EntityStatsTab({
    required this.selectedCombatantId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    if (selectedCombatantId == null) {
      return Center(child: Text(l10n.sessionSelectCombatantStats, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
    }
    final schema = ref.watch(worldSchemaProvider);
    final entity = ref.watch(
      entityProvider.select((map) => map[selectedCombatantId]),
    );
    if (entity == null) {
      return Center(child: Text(l10n.sessionEntityNotFound, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
    }
    final catSchema = schema.categories
        .where((c) => c.slug == entity.categorySlug)
        .firstOrNull;
    return EntityCard(
      entityId: selectedCombatantId!,
      categorySchema: catSchema,
      readOnly: true,
    );
  }
}
