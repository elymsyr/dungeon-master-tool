import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/session.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/condition_badge.dart';
import '../../widgets/hp_bar.dart';

/// Session tab — Python ui/tabs/session_tab.py birebir karşılığı.
/// Sol: Combat Tracker + Dice grubu
/// Sağ: Session kontrolleri + Event log + Alt tab'lar (Notes, BattleMap, Player, EntityStats)
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  // Quick add controllers
  final _quickName = TextEditingController();
  final _quickInit = TextEditingController();
  final _quickHp = TextEditingController();

  // Session
  final _logInputController = TextEditingController();
  final _notesController = TextEditingController();

  // Bottom tabs
  int _bottomTabIndex = 0;

  final _rng = Random();

  @override
  void dispose() {
    _quickName.dispose();
    _quickInit.dispose();
    _quickHp.dispose();
    _logInputController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final combat = ref.watch(combatProvider);
    final screen = getScreenType(context);

    // İlk encounter yoksa oluştur
    if (combat.encounters.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(combatProvider.notifier).createEncounter('Encounter 1');
      });
    }

    final enc = combat.activeEncounter;

    if (screen == ScreenType.phone) {
      return _buildMobileLayout(palette, combat, enc);
    }

    // Desktop/Tablet: horizontal splitter — sol combat, sağ session controls
    return Row(
      children: [
        // SOL: Combat Tracker + Dice
        SizedBox(
          width: 400,
          child: _buildLeftPanel(palette, combat, enc),
        ),
        Container(width: 4, color: palette.sidebarDivider),
        // SAĞ: Session controls + Log + Bottom tabs
        Expanded(child: _buildRightPanel(palette, combat)),
      ],
    );
  }

  // ============================================================
  // SOL PANEL — Combat Tracker
  // ============================================================
  Widget _buildLeftPanel(DmToolColors palette, CombatState combat, Encounter? enc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('Combat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
        ),

        // === Encounter satırı ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Text('Encounter: ', style: TextStyle(fontSize: 12, color: palette.tabText)),
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
              // New encounter
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 18),
                onPressed: () => ref.read(combatProvider.notifier).createEncounter('Encounter ${combat.encounters.length + 1}'),
                visualDensity: VisualDensity.compact,
                tooltip: 'New Encounter',
              ),
              // Rename
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: enc == null ? null : () => _renameEncounter(enc),
                visualDensity: VisualDensity.compact,
                tooltip: 'Rename',
              ),
              // Delete
              IconButton(
                icon: Icon(Icons.delete, size: 16, color: palette.dangerBtnBg),
                onPressed: combat.encounters.length > 1 && enc != null ? () => ref.read(combatProvider.notifier).deleteEncounter(enc.id) : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete Encounter',
              ),
            ],
          ),
        ),

        // === Quick-add satırı ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Expanded(flex: 3, child: TextField(controller: _quickName, decoration: const InputDecoration(hintText: 'Name', isDense: true), style: const TextStyle(fontSize: 12), onSubmitted: (_) => _quickAdd())),
              const SizedBox(width: 4),
              SizedBox(width: 50, child: TextField(controller: _quickInit, decoration: const InputDecoration(hintText: 'Init', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 4),
              SizedBox(width: 50, child: TextField(controller: _quickHp, decoration: const InputDecoration(hintText: 'HP', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _quickAdd,
                style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, foregroundColor: Colors.white, minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Quick Add', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // === Round/Turn satırı ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: BorderRadius.circular(4)),
                child: Text('Round ${enc?.round ?? 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
                style: FilledButton.styleFrom(backgroundColor: palette.actionBtnBg, foregroundColor: palette.actionBtnText),
                child: const Text('Next Turn', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // === Action butonları satırı ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              _styledButton('Add', Icons.add, palette.primaryBtnBg, palette.primaryBtnText, () => _showAddDialog()),
              const SizedBox(width: 4),
              _styledButton('Add Players', Icons.group_add, palette.primaryBtnBg, palette.primaryBtnText, () => ref.read(combatProvider.notifier).addAllPlayers()),
              const SizedBox(width: 4),
              _styledButton('Roll Init', Icons.casino, palette.primaryBtnBg, palette.primaryBtnText, () => ref.read(combatProvider.notifier).rollInitiatives()),
              const SizedBox(width: 4),
              _styledButton('Clear All', Icons.delete_sweep, palette.dangerBtnBg, Colors.white, () => ref.read(combatProvider.notifier).clearAll()),
            ],
          ),
        ),

        Divider(height: 1, color: palette.sidebarDivider),

        // === Combat tablosu ===
        Expanded(
          child: enc == null || enc.combatants.isEmpty
              ? Center(child: Text('No combatants\nDrag entities from sidebar or use Quick Add', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
              : _buildCombatTable(palette, enc),
        ),

        Divider(height: 1, color: palette.sidebarDivider),

        // === Dice grubu ===
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabText)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [4, 6, 8, 10, 12, 20, 100].map((d) =>
                  OutlinedButton(
                    onPressed: () {
                      final roll = _rng.nextInt(d) + 1;
                      ref.read(combatProvider.notifier).addLog('d$d: $roll');
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Text('d$d', style: const TextStyle(fontSize: 11)),
                  ),
                ).toList(),
              ),
            ],
          ),
        ),
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

        // Event log + log input (üst bölüm)
        Expanded(
          flex: 3,
          child: Column(
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
        ),

        Divider(height: 1, color: palette.sidebarDivider),

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
        Expanded(
          flex: 4,
          child: _buildBottomTabContent(palette),
        ),
      ],
    );
  }

  Widget _bottomTab(String label, int index, DmToolColors palette) {
    final isActive = _bottomTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _bottomTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? palette.tabActiveBg : palette.tabBg,
            border: Border(bottom: BorderSide(color: isActive ? palette.tabIndicator : Colors.transparent, width: 2)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isActive ? palette.tabActiveText : palette.tabText, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ),
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
            decoration: InputDecoration(hintText: 'DM notes...', border: InputBorder.none, filled: false, hintStyle: TextStyle(color: palette.sidebarLabelSecondary)),
            style: TextStyle(fontSize: 13, color: palette.htmlText),
          ),
        );
      case 1: // Battle Map (placeholder)
        return Center(child: Text('Battle Map\n(Coming next)', textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
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
            onAcceptWithDetails: (details) => ref.read(combatProvider.notifier).addCombatantFromEntity(details.data),
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: candidateData.isNotEmpty
                    ? BoxDecoration(border: Border.all(color: palette.tabIndicator, width: 2))
                    : null,
                child: ListView.builder(
                  itemCount: enc.combatants.length,
                  itemBuilder: (context, index) => _buildCombatantRow(palette, enc, index),
                ),
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
                        child: const Center(child: Text('-', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)))),
                    ),
                    const SizedBox(width: 2),
                    Expanded(child: HpBar(hp: numVal, maxHp: maxVal > 0 ? maxVal : 1, palette: palette)),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () => _modifyStat(c, col.subFieldKey, 1, statsMap, cfg),
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.hpBtnIncreaseBg, borderRadius: BorderRadius.circular(3)),
                        child: const Center(child: Text('+', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)))),
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
  Widget _styledButton(String label, IconData icon, Color bg, Color fg, VoidCallback onPressed) {
    return Expanded(
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 10)),
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  void _quickAdd() {
    final name = _quickName.text.trim();
    if (name.isEmpty) return;
    ref.read(combatProvider.notifier).addDirectRow(name, int.tryParse(_quickInit.text) ?? 0, int.tryParse(_quickHp.text) ?? 10);
    _quickName.clear();
    _quickInit.clear();
    _quickHp.clear();
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
    final result = await showEntitySelectorDialog(
      context: context,
      ref: ref,
      allowedTypes: ['npc', 'monster', 'player'],
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
