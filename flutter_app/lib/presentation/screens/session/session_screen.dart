import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/session.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/condition_badge.dart';
import '../../widgets/hp_bar.dart';
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

  // Bottom tabs (desktop/tablet)
  int _bottomTabIndex = 0;
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
  }

  @override
  void dispose() {
    _logInputController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);

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
      final combat = ref.read(combatProvider);
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
        final combat = ref.watch(combatProvider);
        return _buildLeftPanel(palette, combat, combat.activeEncounter);
      }),
      second: Consumer(builder: (context, ref, _) {
        final combat = ref.watch(combatProvider);
        return _buildRightPanel(palette, combat);
      }),
    );
  }

  // ============================================================
  // SOL PANEL — Combat Tracker
  // ============================================================
  Widget _buildLeftPanel(DmToolColors palette, CombatState combat, Encounter? enc) {
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
                    value: combat.activeEncounterId,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13, color: palette.tabActiveText, fontWeight: FontWeight.w600),
                    dropdownColor: palette.uiPopupBg,
                    items: combat.encounters.map((e) =>
                      DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 13)))
                    ).toList(),
                    onChanged: (id) { if (id != null) ref.read(combatProvider.notifier).switchEncounter(id); },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => ref.read(combatProvider.notifier).createEncounter('Encounter ${combat.encounters.length + 1}'),
                tooltip: 'New Encounter',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: enc == null ? null : () => _renameEncounter(enc),
                tooltip: 'Rename',
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: palette.dangerBtnBg),
                onPressed: combat.encounters.length > 1 && enc != null ? () => ref.read(combatProvider.notifier).deleteEncounter(enc.id) : null,
                tooltip: 'Delete',
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
                      ? Center(child: Text('No combatants\nDrag entities from sidebar or use Quick Add', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
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

        // === Alt kontrol çubuğu: Round+NextTurn (sol) | Actions dropdown (sağ) ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Round badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: BorderRadius.circular(6)),
                  child: Text('Round ${enc?.round ?? 1}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                ),
                const SizedBox(width: 8),
                // Next Turn
                FilledButton.icon(
                  onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: const Text('Next Turn', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.actionBtnBg,
                    foregroundColor: palette.actionBtnText,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions dropdown
                PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'quick_add': _showQuickAddDialog();
                    case 'add': _showAddDialog();
                    case 'add_players': ref.read(combatProvider.notifier).addAllPlayers();
                    case 'roll_init': _promptRollInitiative();
                    case 'clear_all': ref.read(combatProvider.notifier).clearAll();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'quick_add', child: _popupItem(Icons.bolt, 'Quick Add', palette.successBtnBg)),
                  PopupMenuItem(value: 'add', child: _popupItem(Icons.person_add, 'Add from Database', palette.primaryBtnBg)),
                  PopupMenuItem(value: 'add_players', child: _popupItem(Icons.group_add, 'Add All Players', palette.primaryBtnBg)),
                  PopupMenuItem(value: 'roll_init', child: _popupItem(Icons.casino, 'Roll Initiative', palette.primaryBtnBg)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'clear_all', child: _popupItem(Icons.delete_sweep, 'Clear All', palette.dangerBtnBg)),
                ],
                child: FilledButton.icon(
                  onPressed: null, // PopupMenuButton handles the tap
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Actions', style: TextStyle(fontSize: 13)),
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

        // === Dice grubu ===
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
  Widget _buildRightPanel(DmToolColors palette, CombatState combat) {
    return Column(
      children: [
        // Session control bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: palette.tabBg,
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Session', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText))),
              // TODO: Session selector dropdown (şimdilik tek session)
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save, size: 14),
                label: const Text('Save', style: TextStyle(fontSize: 11)),
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
                  child: Text('Event Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
                ),
                Expanded(
                  child: combat.eventLog.isEmpty
                      ? Center(child: Text('No events yet', style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: combat.eventLog.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(combat.eventLog[index], style: TextStyle(fontSize: 12, color: palette.htmlText)),
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
                          decoration: const InputDecoration(hintText: 'Quick log entry... (@ to mention)', isDense: true),
                          textStyle: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          onSubmitted: (_) => _addLogEntry(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _addLogEntry,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
                        child: const Text('Add Log', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            second: Column(
              children: [
                // Bottom tabs (Notes / BattleMap / Player / EntityStats)
                Container(
                  color: palette.tabBg,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _bottomTab('Notes', 0, palette),
                        _bottomTab('Battle Map', 1, palette),
                        _bottomTab('Player Screen', 2, palette),
                        _bottomTab('Entity Stats', 3, palette),
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
        setState(() => _bottomTabIndex = index);
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
    switch (_bottomTabIndex) {
      case 0: // Notes
        return Padding(
          padding: const EdgeInsets.all(12),
          child: MarkdownTextArea(
            controller: _notesController,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(hintText: 'DM notes... (@ to mention)', border: InputBorder.none, filled: false, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
            textStyle: TextStyle(fontSize: 13, color: palette.htmlText),
          ),
        );
      case 1: // Battle Map
        final enc = ref.watch(combatProvider.select((s) => s.activeEncounter));
        if (enc == null) return Center(child: Text('No active encounter', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
        return BattleMapScreen(encounterId: enc.id);
      case 2: // Player Screen — projection panel
        return const ProjectionPanel();
      case 3: // Entity Stats
        if (_selectedCombatantId == null) {
          return Center(child: Text('Select a combatant\nto view stats', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
        }
        final schema = ref.watch(worldSchemaProvider);
        final entity = ref.watch(
          entityProvider.select((map) => map[_selectedCombatantId]),
        );
        if (entity == null) {
          return Center(child: Text('Entity not found', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
        }
        final catSchema = schema.categories
            .where((c) => c.slug == entity.categorySlug)
            .firstOrNull;
        return EntityCard(
          entityId: _selectedCombatantId!,
          categorySchema: catSchema,
          readOnly: true,
        );
      default:
        return const SizedBox.shrink();
    }
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
              Expanded(flex: 2, child: Text('Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              ...cols.map((col) {
                if (col.subFieldKey == conditionsColumnKey) {
                  // Conditions column lives in the user-chosen position;
                  // give it `Expanded` so the badges have room to wrap.
                  return Expanded(
                    flex: 2,
                    child: Text(col.label.isEmpty ? 'Conditions' : col.label,
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
                Expanded(flex: 2, child: Text('Conditions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
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

  /// Combat stats'taki bir değeri +/- ile değiştir ve entity'ye sync et
  void _modifyStat(Combatant c, String subKey, int delta, Map<String, dynamic> stats, EncounterConfig cfg) {
    if (c.entityId == null) return;
    final entities = ref.read(entityProvider);
    final entity = entities[c.entityId];
    if (entity == null) return;

    final currentVal = int.tryParse(stats[subKey]?.toString() ?? '') ?? 0;
    final maxKey = 'max_$subKey';
    final maxVal = int.tryParse(stats[maxKey]?.toString() ?? '') ?? 9999;
    final newVal = (currentVal + delta).clamp(0, maxVal);

    // Entity'deki combatStats güncelle
    final combatStats = entity.fields[cfg.combatStatsFieldKey];
    if (combatStats is Map) {
      final updated = Map<String, dynamic>.from(combatStats);
      updated[subKey] = newVal.toString();
      final newFields = Map<String, dynamic>.from(entity.fields);
      newFields[cfg.combatStatsFieldKey] = updated;
      ref.read(entityProvider.notifier).update(entity.copyWith(fields: newFields));
    }

    // Combatant HP de güncelle (hardcoded hp alanı için)
    if (subKey == 'hp') {
      ref.read(combatProvider.notifier).modifyHp(c.id, delta);
    }
  }

  /// Set a combat stat to a raw value (for inline-editable cells). Unlike
  /// [_modifyStat] this does NOT clamp or assume the value is numeric — it
  /// writes whatever string the user typed back to the entity. HP/maxHP
  /// updates are also propagated to the live combatant.
  void _setStat(Combatant c, String subKey, String newVal, EncounterConfig cfg) {
    if (c.entityId == null) return;
    final entities = ref.read(entityProvider);
    final entity = entities[c.entityId];
    if (entity == null) return;

    final combatStats = entity.fields[cfg.combatStatsFieldKey];
    final updated = combatStats is Map
        ? Map<String, dynamic>.from(combatStats)
        : <String, dynamic>{};
    updated[subKey] = newVal;
    final newFields = Map<String, dynamic>.from(entity.fields);
    newFields[cfg.combatStatsFieldKey] = updated;
    ref.read(entityProvider.notifier).update(entity.copyWith(fields: newFields));

    // Live HP/maxHP propagation to the combatant in the active encounter.
    final asInt = int.tryParse(newVal);
    if (asInt != null) {
      if (subKey == 'hp') {
        final delta = asInt - c.hp;
        if (delta != 0) ref.read(combatProvider.notifier).modifyHp(c.id, delta);
      }
    }
  }

  /// Show a small dice-picker dialog (d4–d20) and re-roll initiative for
  /// every combatant with the chosen die. Each combatant's new init is
  /// 1d[chosen] + the evaluated dice-spec from their entity's
  /// `combat_stats[<initiativeSubField>]`.
  Future<void> _promptRollInitiative() async {
    const dice = [4, 6, 8, 10, 12, 20];
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Roll Initiative'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in dice)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, d),
                child: Text('d$d'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen != null) {
      ref.read(combatProvider.notifier).rollInitiatives(dSides: chosen);
    }
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
              child: IndexedStack(
                index: _mobileTabIndex,
                children: [
                  _buildMobileCombatTab(palette, combat, enc),
                  _buildMobileLogTab(palette, combat),
                  _buildMobileBattleMapTab(palette, enc),
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
              mini: true,
              onPressed: () => _showDiceBottomSheet(palette),
              child: const Icon(Icons.casino),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTabBar(DmToolColors palette) {
    return Container(
      color: palette.tabBg,
      child: Row(
        children: [
          _mobileTab('Combat', Icons.shield, 0, palette),
          _mobileTab('Log', Icons.list_alt, 1, palette),
          _mobileTab('Map', Icons.map, 2, palette),
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
                decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: BorderRadius.circular(4)),
                child: Text('R${enc?.round ?? 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Next', style: TextStyle(fontSize: 11)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'quick_add': _showQuickAddDialog();
                    case 'add': _showAddDialog();
                    case 'add_players': ref.read(combatProvider.notifier).addAllPlayers();
                    case 'roll_init': _promptRollInitiative();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'quick_add', child: Text('Quick Add', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'add', child: Text('Add from Database', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'add_players', child: Text('Add All Players', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'roll_init', child: Text('Roll Initiative', style: TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
        // Combat cards — full remaining height
        Expanded(
          child: enc != null && enc.combatants.isNotEmpty
              ? _buildMobileCombatList(palette, enc)
              : Center(child: Text('No combatants', style: TextStyle(color: palette.sidebarLabelSecondary))),
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
              _logSubTab('Event Log', 0, palette),
              const SizedBox(width: 8),
              _logSubTab('Notes', 1, palette),
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
          borderRadius: BorderRadius.circular(4),
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
              ? Center(child: Text('No events yet', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)))
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
                  decoration: InputDecoration(hintText: 'Quick log entry... (@ to mention)', isDense: true, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
                  textStyle: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  onSubmitted: (_) => _addLogEntry(),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _addLogEntry,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                child: const Text('Add', style: TextStyle(fontSize: 12)),
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
          hintText: 'DM notes... (@ to mention)',
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
        child: Text('No active encounter', style: TextStyle(color: palette.sidebarLabelSecondary)),
      );
    }
    return BattleMapScreen(encounterId: enc.id);
  }

  // --- Entity Stats Bottom Sheet ---
  void _showMobileEntityStatsSheet(DmToolColors palette) {
    if (_selectedCombatantId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: _buildMobileEntityStats(palette),
        ),
      ),
    );
  }

  Widget _buildMobileCombatList(DmToolColors palette, Encounter enc) {
    // Only watch entities referenced by current encounter combatants
    final combatantEntityIds = enc.combatants.map((c) => c.entityId).whereType<String>().toSet();
    final entities = ref.watch(entityProvider.select((map) =>
      Map.fromEntries(map.entries.where((e) => combatantEntityIds.contains(e.key))),
    ));
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: enc.combatants.length,
      itemBuilder: (context, index) {
        final c = enc.combatants[index];
        final entity = c.entityId != null ? entities[c.entityId] : null;
        final combatStats = entity?.fields[cfg.combatStatsFieldKey];
        final statsMap = combatStats is Map ? Map<String, dynamic>.from(combatStats) : <String, dynamic>{};

        // Resolve condition sub-fields once per list build
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

        return _MobileCombatCard(
          key: ValueKey(c.id),
          combatant: c,
          isActive: index == enc.turnIndex,
          palette: palette,
          config: cfg,
          statsMap: statsMap,
          onTap: () {
            setState(() => _selectedCombatantId = c.entityId);
            _showMobileEntityStatsSheet(palette);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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

  Widget _buildMobileEntityStats(DmToolColors palette) {
    if (_selectedCombatantId == null) {
      return Center(child: Text('Tap a combatant to view stats', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)));
    }
    final entity = ref.watch(
      entityProvider.select((map) => map[_selectedCombatantId]),
    );
    if (entity == null) {
      return Center(child: Text('Entity not found', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)));
    }
    // Simple stats view
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entity.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
          Text(entity.categorySlug, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
          if (entity.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entity.description, style: TextStyle(fontSize: 12, color: palette.htmlText), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          ...entity.fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty && e.value is! Map && e.value is! List).map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(e.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabText))),
                  Expanded(child: Text(e.value.toString(), style: TextStyle(fontSize: 11, color: palette.htmlText), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
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

    final nameController = TextEditingController();
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Quick Add', style: TextStyle(fontSize: 14)),
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
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Name'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Quantity
                    Row(
                      children: [
                        Text('Quantity', style: TextStyle(fontSize: 12, color: palette.tabText)),
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
                            borderRadius: BorderRadius.circular(4),
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
                    Text('Combat Stats', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
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
                          decoration: const InputDecoration(
                            labelText: 'Max HP',
                            hintText: 'Same as HP if empty',
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
                child: const Text('Cancel'),
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
                label: Text('Add${quantity > 1 ? ' ($quantity)' : ''}', style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.successBtnBg,
                  foregroundColor: palette.successBtnText,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addLogEntry() {
    final text = _logInputController.text.trim();
    if (text.isEmpty) return;
    ref.read(combatProvider.notifier).addLog(text);
    _logInputController.clear();
  }

  void _renameEncounter(Encounter enc) {
    final controller = TextEditingController(text: enc.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Encounter', style: TextStyle(fontSize: 14)),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            // TODO: rename encounter in provider
            Navigator.pop(ctx);
          }, child: const Text('Rename')),
        ],
      ),
    );
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Condition', style: TextStyle(fontSize: 14)),
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
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Custom Condition'), autofocus: conditionEntities.isEmpty),
              const SizedBox(height: 8),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (rounds, optional)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            ref.read(combatProvider.notifier).addCondition(combatantId, name, int.tryParse(durationController.text));
            Navigator.pop(ctx);
          }, child: const Text('Add Custom')),
        ],
      ),
    );
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
          borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(4),
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
                    decoration: BoxDecoration(color: palette.hpBtnDecreaseBg, borderRadius: BorderRadius.circular(4)),
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
                    decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: BorderRadius.circular(4)),
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

    // Selective watch — only this combatant's entity
    final entity = c.entityId != null
        ? ref.watch(entityProvider.select((m) => m[c.entityId]))
        : null;
    final combatStats = entity?.fields[cfg.combatStatsFieldKey];
    final statsMap = combatStats is Map ? Map<String, dynamic>.from(combatStats) : <String, dynamic>{};

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
                        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnDecreaseBg, borderRadius: BorderRadius.circular(3)),
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
                        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: BorderRadius.circular(3)),
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
            decoration: BoxDecoration(border: Border.all(color: palette.sidebarDivider), borderRadius: BorderRadius.circular(12)),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onSubmit(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
