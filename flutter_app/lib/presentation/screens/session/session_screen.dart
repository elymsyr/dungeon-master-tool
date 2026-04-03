import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/session.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/condition_badge.dart';
import '../../widgets/hp_bar.dart';
import '../../widgets/resizable_split.dart';
import '../battle_map/battle_map_screen.dart';

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

  // Bottom tabs
  int _bottomTabIndex = 0;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _bottomTabIndex = ref.read(uiStateProvider).sessionBottomTab;
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
              const Spacer(),
              // Actions dropdown
              PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'quick_add': _showQuickAddDialog();
                    case 'add': _showAddDialog();
                    case 'add_players': ref.read(combatProvider.notifier).addAllPlayers();
                    case 'roll_init': ref.read(combatProvider.notifier).rollInitiatives();
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
                        child: TextField(
                          controller: _logInputController,
                          decoration: const InputDecoration(hintText: 'Quick log entry...', isDense: true),
                          style: const TextStyle(fontSize: 12),
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
                  child: Row(
                    children: [
                      _bottomTab('Notes', 0, palette),
                      _bottomTab('Battle Map', 1, palette),
                      _bottomTab('Player Screen', 2, palette),
                      _bottomTab('Entity Stats', 3, palette),
                    ],
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
          child: TextField(
            controller: _notesController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(hintText: 'DM notes...', border: InputBorder.none, filled: false, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
            style: TextStyle(fontSize: 13, color: palette.htmlText),
          ),
        );
      case 1: // Battle Map
        final enc = ref.watch(combatProvider.select((s) => s.activeEncounter));
        if (enc == null) return Center(child: Text('No active encounter', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
        return BattleMapScreen(encounterId: enc.id);
      case 2: // Player Screen (placeholder)
        return Center(child: Text('Player Screen\n(Coming soon)', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
      case 3: // Entity Stats (placeholder)
        return Center(child: Text('Select a combatant\nto view stats', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // COMBAT TABLE
  // ============================================================
  Widget _buildCombatTable(DmToolColors palette, Encounter enc) {
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;

    return Column(
      children: [
        // Header — Name + dynamic columns + Conditions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: palette.tabBg,
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              ...cfg.columns.map((col) => SizedBox(
                width: col.width > 0 ? col.width.toDouble() : 60,
                child: Text(col.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Conditions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
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
                    itemBuilder: (context, index) => _buildCombatantRow(palette, enc, index),
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

  Widget _buildCombatantRow(DmToolColors palette, Encounter enc, int index) {
    final c = enc.combatants[index];
    final isActive = index == enc.turnIndex;
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;

    // Entity'den canlı combatStats oku
    final entities = ref.watch(entityProvider);
    final entity = c.entityId != null ? entities[c.entityId] : null;
    final combatStats = entity?.fields[cfg.combatStatsFieldKey];
    final statsMap = combatStats is Map ? Map<String, dynamic>.from(combatStats) : <String, dynamic>{};

    return Container(
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
          // Name
          Expanded(flex: 2, child: Text(c.name, style: TextStyle(fontSize: 13, color: palette.tabActiveText, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
          // Dynamic columns from encounterConfig
          ...cfg.columns.map((col) {
            final val = statsMap[col.subFieldKey]?.toString() ?? '';

            if (col.showButtons) {
              // HP-style column: − bar +
              final numVal = int.tryParse(val) ?? 0;
              final maxKey = 'max_${col.subFieldKey}';
              final maxVal = int.tryParse(statsMap[maxKey]?.toString() ?? '') ?? numVal;
              return SizedBox(
                width: col.width > 0 ? col.width.toDouble() : 130,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _modifyStat(c, col.subFieldKey, -1, statsMap, cfg),
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnDecreaseBg, borderRadius: BorderRadius.circular(3)),
                        child: Center(child: Text('-', style: TextStyle(fontSize: 14, color: palette.hpBtnText, fontWeight: FontWeight.bold)))),
                    ),
                    const SizedBox(width: 2),
                    Expanded(child: HpBar(hp: numVal, maxHp: maxVal > 0 ? maxVal : 1, palette: palette)),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () => _modifyStat(c, col.subFieldKey, 1, statsMap, cfg),
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: BorderRadius.circular(3)),
                        child: Center(child: Text('+', style: TextStyle(fontSize: 14, color: palette.hpBtnText, fontWeight: FontWeight.bold)))),
                    ),
                  ],
                ),
              );
            }

            // Normal column
            return SizedBox(
              width: col.width > 0 ? col.width.toDouble() : 60,
              child: Text(val, style: TextStyle(fontSize: 12, color: palette.tabActiveText, fontWeight: col.subFieldKey == cfg.initiativeSubField ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
            );
          }),
          const SizedBox(width: 8),
          // Conditions
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                ...c.conditions.map((cond) => ConditionBadge(
                  condition: cond,
                  palette: palette,
                  onRemove: () => ref.read(combatProvider.notifier).removeCondition(c.id, cond.name),
                )),
                InkWell(
                  onTap: () => _showAddConditionDialog(c.id, cfg.conditions),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(border: Border.all(color: palette.sidebarDivider), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.add, size: 12, color: palette.sidebarLabelSecondary),
                  ),
                ),
              ],
            ),
          ),
          // Delete
          IconButton(
            icon: Icon(Icons.close, size: 14, color: palette.sidebarLabelSecondary),
            onPressed: () => ref.read(combatProvider.notifier).deleteCombatant(c.id),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
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

  // ============================================================
  // MOBILE LAYOUT
  // ============================================================
  Widget _buildMobileLayout(DmToolColors palette, CombatState combat, Encounter? enc) {
    return Column(
      children: [
        // Encounter + Round bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: palette.tabBg,
          child: Row(
            children: [
              Text('Round ${enc?.round ?? 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const Spacer(),
              FilledButton(onPressed: () => ref.read(combatProvider.notifier).nextTurn(), child: const Text('Next Turn', style: TextStyle(fontSize: 11))),
            ],
          ),
        ),
        // Combat table
        Expanded(child: enc != null && enc.combatants.isNotEmpty ? _buildCombatTable(palette, enc) : Center(child: Text('No combatants', style: TextStyle(color: palette.sidebarLabelSecondary)))),
        // Log + Notes tabs
        Container(
          color: palette.tabBg,
          child: Row(children: [_bottomTab('Log', 0, palette), _bottomTab('Notes', 1, palette)]),
        ),
        SizedBox(
          height: 150,
          child: _bottomTabIndex == 0
              ? ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: combat.eventLog.length,
                  itemBuilder: (_, i) => Text(combat.eventLog[i], style: TextStyle(fontSize: 11, color: palette.htmlText)),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(controller: _notesController, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Notes...', border: InputBorder.none, filled: false), style: const TextStyle(fontSize: 12)),
                ),
        ),
      ],
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

  void _showAddConditionDialog(String combatantId, [List<String> predefined = const []]) {
    final nameController = TextEditingController();
    final durationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Condition', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined conditions
              if (predefined.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: predefined.map((name) => ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref.read(combatProvider.notifier).addCondition(combatantId, name, null);
                      Navigator.pop(ctx);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              // Custom condition
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Custom Condition'), autofocus: predefined.isEmpty),
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
