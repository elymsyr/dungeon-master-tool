import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/character_provider.dart';
import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/world_characters_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../widgets/dice/dice_fab.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/session.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/battle_map/battle_map_mobile_toolbar.dart';
import '../../widgets/condition_badge.dart';
import '../../widgets/hp_bar.dart';
import '../../widgets/markdown_text_area.dart';
import '../battle_map/battle_map_screen.dart';

/// Session tab: the battle map fills it. The encounter (combatant list)
/// opens from the left, its controls sit in a bottom bar that is always on
/// screen, and the event log floats bottom right like a game chat.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  // Left encounter panel; null = default: open on desktop/tablet, closed on
  // a phone, where it covers the map.
  bool? _encounterOpen;
  // Phone only: the event log can be hidden from the combat bar.
  bool _logVisible = true;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final phone = getScreenType(context) == ScreenType.phone;
    final open = _encounterOpen ?? !phone;

    // İlk encounter yoksa oluştur
    final isEmpty = ref.watch(combatProvider.select((s) => s.encounters.isEmpty));
    if (isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(combatProvider.notifier).createEncounter('Encounter 1');
      });
    }

    return LayoutBuilder(builder: (context, constraints) {
      final panelWidth = phone ? min(constraints.maxWidth * 0.8, 320.0) : 380.0;
      final mapLeft = open && !phone ? panelWidth : 0.0;
      // Buttons sit straight on the map, clear of the phone map bar and the
      // dice button; the log sits above them and the dice button on the right.
      final barBottom = (phone ? kBattleMapMobileToolbarHeight : 0.0) + 8;
      const barHeight = 40.0;
      final chatWidth = min(constraints.maxWidth - 24, 320.0);
      return Stack(
        children: [
          // Map — pushed aside by the panel on wide screens, under it on a
          // phone. Always the first child, so it never remounts.
          Positioned(left: mapLeft, top: 0, right: 0, bottom: 0, child: const _SessionBattleMap()),
          if (open)
            Positioned(
              left: 0,
              top: 0,
              bottom: phone ? barBottom + barHeight + 4 : 0,
              width: panelWidth,
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: Border(right: BorderSide(color: palette.sidebarDivider)),
                child: Consumer(builder: (context, ref, _) {
                  final (encounters, enc) = ref.watch(combatProvider.select(
                    (s) => (s.encounters, s.activeEncounter),
                  ));
                  return _buildEncounterPanel(palette, encounters, enc, phone: phone);
                }),
              ),
            ),
          // Event log, over everything.
          if (!phone || (!open && _logVisible))
            Positioned(
              right: 12,
              bottom: max(barBottom + barHeight + 4, kAboveDiceFab),
              width: chatWidth,
              child: const _SessionChat(),
            ),
          Positioned(
            left: mapLeft + 8,
            bottom: barBottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: max(0.0, constraints.maxWidth - mapLeft - 8 - kDiceFabLane)),
              child: Consumer(builder: (context, ref, _) {
                final round = ref.watch(combatProvider.select((s) => s.activeEncounter?.round ?? 1));
                return _buildCombatBar(palette, round, open: open, phone: phone);
              }),
            ),
          ),
        ],
      );
    });
  }

  // ============================================================
  // ENCOUNTER PANELİ — soldan açılır
  // ============================================================
  Widget _buildEncounterPanel(
      DmToolColors palette, List<Encounter> encounters, Encounter? enc, {required bool phone}) {
    final l10n = L10n.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === Encounter satırı ===
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
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

        // === Combatants (DragTarget her zaman aktif) ===
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) => ref.read(combatProvider.notifier).canAddToEncounter(details.data),
            onAcceptWithDetails: (details) => ref.read(combatProvider.notifier).addCombatantFromEntity(details.data),
            builder: (context, candidateData, rejectedData) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  enc == null || enc.combatants.isEmpty
                      ? Center(child: Text(phone ? l10n.sessionNoCombatantsShort : l10n.sessionNoCombatants, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)))
                      : phone
                          ? _buildMobileCombatList(palette, enc)
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

      ],
    );
  }

  // ============================================================
  // SAVAŞ BUTONLARI — haritanın üstünde, panel kapalıyken de görünür
  // ============================================================

  /// Panel toggle · round · Next turn · Roll initiative · Add ▾ · ⋮, with no
  /// background of their own.
  Widget _buildCombatBar(DmToolColors palette, int round, {required bool open, required bool phone}) {
    final l10n = L10n.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            icon: Icon(open ? Icons.menu_open : Icons.menu, size: 18),
            tooltip: l10n.sessionCombat,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _encounterOpen = !open),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: palette.featureCardBg, borderRadius: palette.chr),
            child: Text(
              phone ? l10n.sessionRoundShort(round) : l10n.sessionRound(round),
              style: TextStyle(fontSize: phone ? 11 : 12, fontWeight: FontWeight.bold, color: palette.tabActiveText),
            ),
          ),
          const SizedBox(width: 6),
          ..._combatButtons(palette, compact: phone),
        ],
      ),
    );
  }

  void _onCombatAction(String action) {
    switch (action) {
      case 'quick_add': _showQuickAddDialog();
      case 'add': _showAddDialog();
      case 'add_players': _showAddPlayersDialog();
      case 'reset_init': _promptResetInitiative();
      case 'clear_all': ref.read(combatProvider.notifier).clearAll();
    }
  }

  /// Next turn · Roll initiative · Add ▾ · ⋮ — shared by desktop and phone.
  /// [compact] (phone) drops the labels except on Next.
  List<Widget> _combatButtons(DmToolColors palette, {required bool compact}) {
    final l10n = L10n.of(context)!;
    final height = compact ? 30.0 : 36.0;
    final text = TextStyle(fontSize: compact ? 11 : 12);
    final compactIcon = IconButton.styleFrom(visualDensity: VisualDensity.compact);
    return [
      FilledButton.icon(
        onPressed: () => ref.read(combatProvider.notifier).nextTurn(),
        icon: const Icon(Icons.skip_next, size: 18),
        label: Text(compact ? l10n.sessionNext : l10n.sessionNextTurn, style: text),
        style: FilledButton.styleFrom(
          backgroundColor: palette.actionBtnBg,
          foregroundColor: palette.actionBtnText,
          minimumSize: Size(0, height),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        ),
      ),
      SizedBox(width: compact ? 2 : 6),
      if (compact)
        IconButton(
          onPressed: _promptRollInitiative,
          icon: const Icon(Icons.casino, size: 18),
          tooltip: l10n.sessionRollInitiative,
          style: compactIcon,
        )
      else ...[
        OutlinedButton.icon(
          onPressed: _promptRollInitiative,
          icon: const Icon(Icons.casino, size: 18),
          label: Text(l10n.sessionRollInitiative, style: text),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
        const SizedBox(width: 6),
      ],
      PopupMenuButton<String>(
        tooltip: l10n.sessionAdd,
        onSelected: _onCombatAction,
        itemBuilder: (_) => [
          PopupMenuItem(value: 'quick_add', child: _popupItem(Icons.bolt, l10n.sessionQuickAdd, palette.successBtnBg)),
          PopupMenuItem(value: 'add', child: _popupItem(Icons.person_add, l10n.sessionAddFromDatabase, palette.primaryBtnBg)),
          PopupMenuItem(value: 'add_players', child: _popupItem(Icons.group_add, l10n.sessionAddPlayersMenu, palette.primaryBtnBg)),
        ],
        icon: compact ? const Icon(Icons.person_add, size: 18) : null,
        style: compact ? compactIcon : null,
        // PopupMenuButton handles the tap; IgnorePointer keeps the button
        // looking enabled without stealing it.
        child: compact
            ? null
            : IgnorePointer(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(l10n.sessionAdd, style: text),
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, height),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
      ),
      if (compact)
        IconButton(
          onPressed: () => setState(() => _logVisible = !_logVisible),
          icon: Icon(_logVisible ? Icons.speaker_notes : Icons.speaker_notes_off, size: 18),
          tooltip: l10n.sessionEventLog,
          style: compactIcon,
        ),
      PopupMenuButton<String>(
        tooltip: l10n.sessionActions,
        icon: const Icon(Icons.more_vert, size: 18),
        style: compact ? compactIcon : null,
        onSelected: _onCombatAction,
        itemBuilder: (_) => [
          PopupMenuItem(value: 'reset_init', child: _popupItem(Icons.replay, l10n.sessionResetInitiative, palette.primaryBtnBg)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'clear_all', child: _popupItem(Icons.delete_sweep, l10n.sessionClearAll, palette.dangerBtnBg)),
        ],
      ),
    ];
  }

  /// Player chars in the active world. Online: pull from
  /// `worldCharactersProvider` (mirror covers other-player chars the local
  /// `characterListProvider` doesn't hydrate). Offline: filter the local
  /// list by worldId.
  List<Character> _ownedWorldCharacters() {
    final worldId = ref.read(activeCampaignIdProvider).valueOrNull;
    final onlineIds = ref.read(onlineWorldIdsProvider);
    if (worldId != null && onlineIds.contains(worldId)) {
      final rows =
          ref.read(worldCharactersProvider(worldId)).valueOrNull ?? const [];
      final out = <Character>[];
      for (final r in rows) {
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
        .where(
            (c) => worldId == null || c.worldId == null || c.worldId == worldId)
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

  /// Sub-field labels of the schema's condition-stats field, for badge
  /// tooltips.
  static List<Map<String, String>>? _conditionSubFields(WorldSchema schema) {
    final key = schema.encounterConfig.conditionStatsFieldKey;
    for (final cat in schema.categories) {
      for (final f in cat.fields) {
        if (f.fieldKey == key) return f.subFields;
      }
    }
    return null;
  }

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
        // Rows — drops land on the panel's DragTarget.
        Expanded(
          child: ListView.builder(
            itemCount: enc.combatants.length,
            itemBuilder: (context, index) => _CombatantRow(
              key: ValueKey(enc.combatants[index].id),
              combatant: enc.combatants[index],
              index: index,
              turnIndex: enc.turnIndex,
              palette: palette,
              onModifyStat: (c, subKey, delta, stats, cfg) => _modifyStat(c, subKey, delta, stats, cfg),
              onSetStat: (c, subKey, newVal, cfg) => _setStat(c, subKey, newVal, cfg),
              onShowAddCondition: (combatantId, _) => _showAddConditionDialog(combatantId),
            ),
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

  /// Reset every combatant's initiative back to its flat modifier (no roll).
  void _promptResetInitiative() {
    ref.read(combatProvider.notifier).resetInitModifiers();
  }

  Widget _buildMobileCombatList(DmToolColors palette, Encounter enc) {
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    // Once per list build, not per item.
    final condSubFields = _conditionSubFields(schema);

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
          statsMap: statsMap,
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

    // Find condition categories. The legacy schema marks them with a
    // `condition_stats` field, but the builtin v2 schema models `condition` as
    // a Tier-0 lookup WITHOUT that field — so also match well-known condition
    // slugs, else builtin conditions never show up in the picker.
    const knownConditionSlugs = {'condition', 'conditions'};
    final schema = ref.read(worldSchemaProvider);
    final cfg = schema.encounterConfig;
    final conditionSlugs = <String>{};
    for (final cat in schema.categories) {
      if (knownConditionSlugs.contains(cat.slug) ||
          cat.fields.any((f) => f.fieldKey == cfg.conditionStatsFieldKey)) {
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
                            Navigator.pop(ctx);
                            _showConditionDurationDialog(combatantId, e.name,
                                defaultDuration, entityId: e.id);
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
              // Custom condition — duration asked in a follow-up dialog.
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.sessionCustomCondition),
                autofocus: conditionEntities.isEmpty,
                onSubmitted: (_) {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  _showConditionDurationDialog(combatantId, name, null);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            _showConditionDurationDialog(combatantId, name, null);
          }, child: Text(l10n.sessionAddCustom)),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
    });
  }

  /// Second-step dialog: asks the condition's duration (rounds) after a
  /// condition is picked or a custom name is entered. Empty = indefinite.
  void _showConditionDurationDialog(
    String combatantId,
    String name,
    int? initialDuration, {
    String? entityId,
  }) {
    final durationController =
        TextEditingController(text: initialDuration?.toString() ?? '');
    final l10n = L10n.of(context)!;
    void submit() {
      ref.read(combatProvider.notifier).addCondition(
            combatantId,
            name,
            int.tryParse(durationController.text.trim()),
            entityId: entityId,
          );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: durationController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.sessionDurationHint),
          onSubmitted: (_) {
            submit();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () {
            submit();
            Navigator.pop(ctx);
          }, child: Text(l10n.btnAdd)),
        ],
      ),
    ).whenComplete(() {
      durationController.dispose();
    });
  }
}

/// Compact mobile combat card showing combatant stats in a card layout.
class _MobileCombatCard extends StatelessWidget {
  final Combatant combatant;
  final bool isActive;
  final DmToolColors palette;
  final Map<String, dynamic> statsMap;
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
    required this.statsMap,
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
    // Show the rolled/current initiative (`combatant.init`), not the entity's
    // dice spec stored in stats — matches the desktop encounter table.
    final init = combatant.init.toString();

    return Container(
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
    // live entity.
    final statsMap = Map<String, dynamic>.from(c.stats);

    // HP dice spec for the roll button: snapshot copy first, then the
    // source entity's flat `hp_dice`. Watched per-row so the button appears
    // for freshly-added monsters without a snapshot copy too.
    final hpEntity = ref.watch(
      entityProvider.select((m) => c.entityId != null ? m[c.entityId] : null),
    );
    final hpDiceSpec = _hpDiceSpec(statsMap, hpEntity);

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
                        onTap: () => col.subFieldKey == 'hp'
                            ? _showHpEditDialog(context, ref, c, cfg, statsMap, hpDiceSpec, col.label)
                            : _showInlineEdit(
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
                onTap: () {
                  if (col.subFieldKey == 'hp') {
                    _showHpEditDialog(context, ref, c, cfg, statsMap, hpDiceSpec, col.label);
                    return;
                  }
                  _showInlineEdit(
                    context,
                    label: col.label,
                    // Initiative opens empty — the dice spec it would prefill
                    // is never what a DM wants to keep; they type the score.
                    initial: isInitCol ? '' : val,
                    onSubmit: (v) => onSetStat(c, col.subFieldKey, v, cfg),
                  );
                },
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
    final condSubFields = c.conditions.isEmpty
        ? null
        : _SessionScreenState._conditionSubFields(schema);
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

  /// HP editor: current + max HP fields, plus a roll button that renews max
  /// HP from the creature's `hp_dice` spec and fills the bar by setting HP
  /// equal to it. Both values are committed on Save via [onSetStat].
  void _showHpEditDialog(
    BuildContext context,
    WidgetRef ref,
    Combatant c,
    EncounterConfig cfg,
    Map<String, dynamic> statsMap,
    String? hpDiceSpec,
    String label,
  ) {
    final hpController =
        TextEditingController(text: statsMap['hp']?.toString() ?? '');
    final maxHpController =
        TextEditingController(text: statsMap['max_hp']?.toString() ?? '');
    final l10n = L10n.of(context)!;

    void applyRoll() {
      final rolled = ref.read(combatProvider.notifier).rollHpDice(c.id);
      if (rolled == null) return;
      hpController.text = '$rolled';
      maxHpController.text = '$rolled';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.editNamed(label), style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hpController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: maxHpController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.sessionMaxHp,
                suffixIcon: hpDiceSpec != null
                    ? Tooltip(
                        message: l10n.sessionRollHpDice,
                        child: IconButton(
                          icon: const Icon(Icons.casino),
                          onPressed: applyRoll,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () {
              final hp = hpController.text.trim();
              final maxHp = maxHpController.text.trim();
              // Max first so the hp clamp below never fights the new max.
              if (maxHp.isNotEmpty) onSetStat(c, 'max_hp', maxHp, cfg);
              if (hp.isNotEmpty) onSetStat(c, 'hp', hp, cfg);
              Navigator.pop(ctx);
            },
            child: Text(l10n.btnSave),
          ),
        ],
      ),
    ).whenComplete(() {
      hpController.dispose();
      maxHpController.dispose();
    });
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
        title: Text(L10n.of(context)!.editNamed(label)),
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

  /// Resolve the HP dice spec shown on the row's roll button: the snapshot's
  /// `hp_dice` copy first, then the source entity's flat `hp_dice` field.
  /// Null → no roll button (nothing to roll).
  String? _hpDiceSpec(Map<String, dynamic> statsMap, Entity? entity) {
    final snapshot = statsMap['hp_dice']?.toString() ?? '';
    if (snapshot.trim().isNotEmpty) return snapshot;
    final v = entity?.fields['hp_dice'];
    return v?.toString();
  }
}

/// Battle map of the active encounter, under the combatant list on desktop
/// and phone. Const, so combat ticks rebuilding the encounter panel don't
/// rebuild it; ValueKey(encId) remounts only on an encounter switch.
class _SessionBattleMap extends ConsumerWidget {
  const _SessionBattleMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encId = ref.watch(combatProvider.select((s) => s.activeEncounter?.id));
    if (encId == null) {
      final palette = Theme.of(context).extension<DmToolColors>()!;
      return Center(child: Text(L10n.of(context)!.sessionNoActiveEncounter, textAlign: TextAlign.center, style: TextStyle(color: palette.sidebarLabelSecondary)));
    }
    return BattleMapScreen(key: ValueKey(encId), encounterId: encId);
  }
}

/// Event log as a game chat: no background, faded until its input has focus.
/// Enter anywhere on the session tab (outside other text fields) focuses it;
/// Enter sends and lets it fade again, as does clicking elsewhere.
class _SessionChat extends ConsumerStatefulWidget {
  const _SessionChat();

  @override
  ConsumerState<_SessionChat> createState() => _SessionChatState();
}

class _SessionChatState extends ConsumerState<_SessionChat> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || _focus.hasFocus) return false;
    if (e.logicalKey != LogicalKeyboardKey.enter &&
        e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    // Only while the session tab is on screen with nothing modal over it,
    // and never while another text field is being typed in.
    if (!mounted || !Visibility.of(context)) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    _focus.requestFocus();
    return true;
  }

  void _send(String _) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(combatProvider.notifier).addLog(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final log = ref.watch(combatProvider.select((s) => s.eventLog));
    final active = _focus.hasFocus;
    const lineStyle = TextStyle(
      fontSize: 11,
      color: Colors.white,
      shadows: [Shadow(blurRadius: 3, color: Colors.black)],
    );
    // Tap region: scrolling the log doesn't count as "tapped outside".
    return TextFieldTapRegion(
      child: AnimatedOpacity(
        opacity: active ? 1 : 0.55,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Faded log lets the map take the pointer underneath.
            IgnorePointer(
              ignoring: !active,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  reverse: true,
                  shrinkWrap: true,
                  itemCount: log.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(log[log.length - 1 - i], style: lineStyle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            MarkdownTextArea(
              controller: _input,
              focusNode: _focus,
              maxLines: 1,
              decoration: InputDecoration(hintText: l10n.sessionQuickLogHint, isDense: true),
              textStyle: const TextStyle(fontSize: 11),
              onSubmitted: _send,
            ),
          ],
        ),
      ),
    );
  }
}
