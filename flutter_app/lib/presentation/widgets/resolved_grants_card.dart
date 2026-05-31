import 'package:flutter/material.dart';

import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';
import '../screens/database/entity_card.dart';

/// Read-only summary of grants computed by [CharacterResolver] but not always
/// mirrored on the PC entity's raw ref fields — senses, damage resistances /
/// immunities / vulnerabilities, and condition immunities. Renders as a
/// collapsible card so it doesn't push the editable schema fields down on
/// every sheet load.
class ResolvedGrantsCard extends StatelessWidget {
  final EffectiveCharacter effective;
  final Map<String, Entity> entities;
  final DmToolColors palette;

  /// Character level — drives the per-level HP bonus note (Tough +2/level).
  final int characterLevel;

  /// Resolver-granted skill / tool proficiency ids that are NOT already
  /// checked on the editable proficiency table (e.g. a feat's direct
  /// `proficiency_grant` effect that never wrote back to `skills.rows`).
  /// Pre-diffed by the caller so the card surfaces only the otherwise-hidden
  /// grants instead of duplicating the whole proficiency list.
  final List<String> extraSkillProfIds;
  final List<String> extraToolProfIds;

  /// Remaining-uses map for granted resource pools, keyed by entity id
  /// (e.g. innate spell id). Missing keys default to pool max.
  final Map<String, int> poolRemaining;

  /// Fires when player taps -/+ or rest button. Receives the full updated
  /// map (sparse — only non-default entries kept).
  final ValueChanged<Map<String, int>>? onPoolRemainingChanged;

  /// Current spell-slot state (remaining counts by spell level). Optional —
  /// when present the Sorcerer Font-of-Magic conversion button surfaces on
  /// the `pool:sorcery_points` row.
  final Map<int, int>? spellSlotsRemaining;
  final Map<int, int>? spellSlotsMax;

  /// Fires when Font of Magic conversion mutates the slot map. Receives the
  /// full updated remaining map.
  final ValueChanged<Map<int, int>>? onSpellSlotsRemainingChanged;

  const ResolvedGrantsCard({
    super.key,
    required this.effective,
    required this.entities,
    required this.palette,
    this.characterLevel = 1,
    this.extraSkillProfIds = const [],
    this.extraToolProfIds = const [],
    this.poolRemaining = const {},
    this.onPoolRemainingChanged,
    this.spellSlotsRemaining,
    this.spellSlotsMax,
    this.onSpellSlotsRemainingChanged,
  });

  String _nameOf(String id) => entities[id]?.name ?? id;

  /// Pretty display name for resource-pool entities whose canonical names use
  /// snake_case `pool:` prefixes (e.g. `pool:rage_uses` → "Rage Uses"). Other
  /// entity types (innate spells) pass through untouched.
  String _displayPoolName(String raw) {
    if (!raw.startsWith('pool:')) return raw;
    final core = raw.substring(5).replaceAll('_', ' ');
    return core
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Optional range suffix for sense chips (`Darkvision 120 ft`). Returns the
  /// raw name when no override is present so other chip kinds stay untouched.
  String _nameWithRange(String id) {
    final name = _nameOf(id);
    final r = effective.senseRanges[id];
    if (r == null || r <= 0) return name;
    return '$name $r ft';
  }

  String _chipLabel(String id, {bool withRange = false}) {
    final name = withRange ? _nameWithRange(id) : _nameOf(id);
    final sources = effective.grantSources[id];
    if (sources == null || sources.isEmpty) return name;
    return '$name — ${sources.join(', ')}';
  }

  Widget _chipRow(
    String label,
    List<String> ids,
    Color chipColor, {
    bool withRange = false,
  }) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final id in ids)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                _chipLabel(id, withRange: withRange),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Extra-speed row (fly/swim/climb/burrow). Renders as text chips of
  /// `mode N ft` since speeds aren't entity ids.
  Widget _extraSpeedsRow(Map<String, int> speeds, Color chipColor) {
    if (speeds.isEmpty) return const SizedBox.shrink();
    final entries = speeds.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Extra Speeds',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final e in entries)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                '${e.key} ${e.value} ft',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Generic label + plain-text chips row (values aren't entity ids). Used for
  /// the HP / initiative bonus notes. Hidden when [chips] is empty.
  Widget _textChipRow(String label, List<String> chips, Color chipColor) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final c in chips)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                c,
                style: TextStyle(fontSize: 12, color: palette.srdInk),
              ),
            ),
        ],
      ),
    );
  }

  /// Compose the feat HP-bonus note chips from the per-level + flat bonuses.
  /// Empty when the character carries no feat HP bonus.
  List<String> _hpBonusChips() {
    final perLevel = effective.hpBonusPerLevel;
    final flat = effective.hpBonusFlat;
    final total = perLevel * characterLevel + flat;
    if (total == 0) return const [];
    final sign = total > 0 ? '+' : '';
    if (perLevel != 0 && flat != 0) {
      return ['$sign$total max HP ($flat + $perLevel/level × $characterLevel)'];
    }
    if (perLevel != 0) {
      return ['$sign$total max HP ($perLevel/level × $characterLevel)'];
    }
    return ['$sign$total max HP'];
  }

  /// Render temp-HP grant sources as text rows — `source — formula (trigger)`.
  /// No counter buttons since these are runtime triggers, not stored pools;
  /// the actual write to PC `temp_hp` happens through the combat tracker or
  /// a dedicated trigger UI (future work).
  Widget _tempHpGrantsBlock(List<Map<String, dynamic>> grants) {
    if (grants.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Temp HP Grants',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final g in grants)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.pink.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                () {
                  final src = g['source']?.toString() ?? '';
                  final formula = g['formula']?.toString();
                  final trigger = g['trigger']?.toString();
                  final parts = <String>[
                    if (src.isNotEmpty) src,
                    if (formula != null && formula.isNotEmpty) formula,
                    if (trigger != null && trigger.isNotEmpty) '($trigger)',
                  ];
                  return parts.join(' · ');
                }(),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Render unarmored AC formula entries (Barbarian/Monk/Sorcerer Draconic
  /// Resilience). Sheet's AC field is manual — this row surfaces the formula
  /// so the player knows what to set it to when not wearing armor.
  Widget _unarmoredFormulasBlock(List<Map<String, dynamic>> formulas) {
    if (formulas.isEmpty) return const SizedBox.shrink();
    String describe(Map<String, dynamic> eff) {
      final payload = eff['payload'];
      if (payload is! Map) return 'Unarmored AC';
      final base = payload['base'];
      final mods = payload['ability_mods'];
      final shield = payload['shield_allowed'] == true;
      final parts = <String>[];
      if (base != null) parts.add('$base');
      if (mods is List) {
        for (final m in mods) {
          parts.add('${m.toString()}_mod');
        }
      }
      final formula = parts.join(' + ');
      return shield ? '$formula (+shield)' : formula;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Unarmored AC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final eff in formulas)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blueGrey.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                describe(eff),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Render each conditionalGrants entry as a chip prefixed by the gating
  /// state. Groups entries by `kind` so the player sees one labelled row per
  /// (kind, state) bucket. Uses the kind's normal chip colour.
  Widget _conditionalGrantsBlock(List<Map<String, dynamic>> grants) {
    if (grants.isEmpty) return const SizedBox.shrink();
    const colourForKind = <String, Color>{
      'damage_resistance': Colors.green,
      'damage_immunity': Colors.blue,
      'damage_vulnerability': Colors.deepOrange,
      'condition_immunity_grant': Colors.purple,
    };
    const labelForKind = <String, String>{
      'damage_resistance': 'Resistances',
      'damage_immunity': 'Immunities',
      'damage_vulnerability': 'Vulnerabilities',
      'condition_immunity_grant': 'Condition Imm.',
    };
    // Bucket by (kind, state) → ordered id list.
    final buckets = <String, List<String>>{};
    final order = <String>[];
    for (final g in grants) {
      final kind = g['kind']?.toString() ?? '';
      final state = g['state']?.toString() ?? '';
      final ids = g['ids'];
      if (ids is! List) continue;
      final key = '$kind|$state';
      final list = buckets.putIfAbsent(key, () {
        order.add(key);
        return <String>[];
      });
      for (final id in ids) {
        if (id is String && !list.contains(id)) list.add(id);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in order)
          () {
            final parts = key.split('|');
            final kind = parts[0];
            final state = parts.length > 1 ? parts[1] : '';
            final label = labelForKind[kind] ?? kind;
            final stateLabel = state.replaceFirst('state:', '');
            final fullLabel =
                stateLabel.isEmpty ? label : '$label (while $stateLabel)';
            return _chipRow(
              fullLabel,
              buckets[key]!,
              colourForKind[kind] ?? Colors.grey,
            );
          }(),
      ],
    );
  }

  /// Pool entries whose `pool_ref` resolves to a known entity id. Covers both
  /// innate-spell pools (pool_ref = spell id) and class pools (pool_ref =
  /// resource-pool Tier-0 id like `pool:rage_uses`). `_displayPoolName`
  /// pretty-prints the `pool:` prefix on render.
  List<Map<String, dynamic>> _grantedPoolEntries() {
    final out = <Map<String, dynamic>>[];
    for (final p in effective.resourcePools) {
      final ref = p['pool_ref'];
      if (ref is! String) continue;
      if (!entities.containsKey(ref)) continue;
      final maxRaw = p['max'];
      final max = maxRaw is int ? maxRaw : int.tryParse('$maxRaw') ?? 0;
      if (max <= 0) continue;
      out.add(p);
    }
    return out;
  }

  Widget _poolCounterRow(Map<String, dynamic> entry) {
    final id = entry['pool_ref'] as String;
    final maxRaw = entry['max'];
    final max = maxRaw is int ? maxRaw : int.tryParse('$maxRaw') ?? 1;
    final cur = poolRemaining[id] ?? max;
    final rawName = _nameOf(id);
    final name = _displayPoolName(rawName);
    final sources = effective.grantSources[id] ?? const <String>[];
    final sourceTxt = sources.isEmpty ? '' : ' — ${sources.join(', ')}';
    final readOnly = onPoolRemainingChanged == null;

    void emit(int next) {
      if (readOnly) return;
      final clamped = next.clamp(0, max);
      final updated = Map<String, int>.from(poolRemaining);
      if (clamped == max) {
        updated.remove(id);
      } else {
        updated[id] = clamped;
      }
      onPoolRemainingChanged!(updated);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name$sourceTxt',
              style: TextStyle(fontSize: 12, color: palette.srdInk),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 18,
            tooltip: 'Spend one',
            onPressed: readOnly || cur <= 0 ? null : () => emit(cur - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$cur / $max',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.srdInk,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 18,
            tooltip: 'Restore one',
            onPressed: readOnly || cur >= max ? null : () => emit(cur + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 18,
            tooltip: 'Reset (long rest)',
            onPressed: readOnly || cur >= max ? null : () => emit(max),
            icon: const Icon(Icons.bedtime_outlined),
          ),
          if (id == 'pool:sorcery_points' &&
              spellSlotsMax != null &&
              spellSlotsRemaining != null &&
              onSpellSlotsRemainingChanged != null &&
              !readOnly)
            Builder(
              builder: (context) => IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                tooltip: 'Font of Magic — convert',
                onPressed: () => _openFontOfMagic(context, id, cur, max),
                icon: const Icon(Icons.swap_horiz),
              ),
            ),
        ],
      ),
    );
  }

  // SRD §2.4 Sorcerer Font of Magic conversion table. Index = slot level.
  static const _spToSlotCost = <int, int>{1: 2, 2: 3, 3: 5, 4: 6, 5: 7};

  Future<void> _openFontOfMagic(
    BuildContext context,
    String poolId,
    int spCurrent,
    int spMax,
  ) async {
    final maxBySlot = Map<int, int>.from(spellSlotsMax!);
    final remBySlot = Map<int, int>.from(spellSlotsRemaining!);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void convertSlotToSp(int lvl) {
              final cur = remBySlot[lvl] ?? 0;
              if (cur <= 0) return;
              if (spCurrent + lvl > spMax) return;
              remBySlot[lvl] = cur - 1;
              spCurrent += lvl;
              onSpellSlotsRemainingChanged!(Map<int, int>.from(remBySlot));
              final updated = Map<String, int>.from(poolRemaining);
              if (spCurrent == spMax) {
                updated.remove(poolId);
              } else {
                updated[poolId] = spCurrent;
              }
              onPoolRemainingChanged!(updated);
              setState(() {});
            }

            void convertSpToSlot(int lvl) {
              final cost = _spToSlotCost[lvl];
              if (cost == null) return;
              if (spCurrent < cost) return;
              final cap = maxBySlot[lvl] ?? 0;
              final cur = remBySlot[lvl] ?? 0;
              if (cur >= cap) return;
              spCurrent -= cost;
              remBySlot[lvl] = cur + 1;
              onSpellSlotsRemainingChanged!(Map<int, int>.from(remBySlot));
              final updated = Map<String, int>.from(poolRemaining);
              if (spCurrent == spMax) {
                updated.remove(poolId);
              } else {
                updated[poolId] = spCurrent;
              }
              onPoolRemainingChanged!(updated);
              setState(() {});
            }

            return AlertDialog(
              title: const Text('Font of Magic'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sorcery Points: $spCurrent / $spMax'),
                    const SizedBox(height: 12),
                    const Text('Slot → SP (refund slot for SP equal to slot level):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final lvl
                            in (maxBySlot.keys.toList()..sort()))
                          ElevatedButton(
                            onPressed: ((remBySlot[lvl] ?? 0) > 0 &&
                                    spCurrent + lvl <= spMax)
                                ? () => convertSlotToSp(lvl)
                                : null,
                            child: Text(
                                'L$lvl → +$lvl SP (${remBySlot[lvl] ?? 0}/${maxBySlot[lvl] ?? 0})'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('SP → Slot (spend SP to create a slot):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in _spToSlotCost.entries)
                          if (maxBySlot.containsKey(entry.key))
                            ElevatedButton(
                              onPressed: (spCurrent >= entry.value &&
                                      (remBySlot[entry.key] ?? 0) <
                                          (maxBySlot[entry.key] ?? 0))
                                  ? () => convertSpToSlot(entry.key)
                                  : null,
                              child: Text(
                                  '${entry.value} SP → L${entry.key} slot'),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final senses = effective.senseEntityIds;
    final res = effective.damageResistanceIds;
    final imm = effective.damageImmunityIds;
    final vuln = effective.damageVulnerabilityIds;
    final cimm = effective.conditionImmunityIds;
    final traits = effective.autoGrantedTraitIds;
    final actions = effective.grantedActionIds;
    final bonusActions = effective.grantedBonusActionIds;
    final reactions = effective.grantedReactionIds;
    final pools = _grantedPoolEntries();
    final extraSpeeds = effective.extraSpeeds;
    final conditional = effective.conditionalGrants;
    final tempHpGrants = effective.tempHpGrants;
    final unarmoredFormulas = effective.unarmoredFormulas;
    final freeCast = effective.freeCastSpellIds;
    final ritualBook = effective.ritualBookSpellIds;
    final activeConditions = effective.activeConditionIds;
    final hpChips = _hpBonusChips();
    final initiative = effective.initiativeBonus;
    final initChips = initiative != 0
        ? <String>['${initiative > 0 ? '+' : ''}$initiative initiative']
        : const <String>[];
    final armorProf = effective.proficiencies.armorCategoryIds;
    final weaponProf = effective.proficiencies.weaponCategoryIds;
    if (senses.isEmpty &&
        res.isEmpty &&
        imm.isEmpty &&
        vuln.isEmpty &&
        cimm.isEmpty &&
        traits.isEmpty &&
        actions.isEmpty &&
        bonusActions.isEmpty &&
        reactions.isEmpty &&
        pools.isEmpty &&
        extraSpeeds.isEmpty &&
        conditional.isEmpty &&
        tempHpGrants.isEmpty &&
        unarmoredFormulas.isEmpty &&
        freeCast.isEmpty &&
        ritualBook.isEmpty &&
        activeConditions.isEmpty &&
        hpChips.isEmpty &&
        initChips.isEmpty &&
        extraSkillProfIds.isEmpty &&
        extraToolProfIds.isEmpty &&
        armorProf.isEmpty &&
        weaponProf.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(palette.cardBorderRadius),
          border: Border.all(color: palette.featureCardBorder, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityCardSectionHeading(
              title: 'Resolved Grants',
              palette: palette,
              leadingIcon: Icons.shield_outlined,
            ),
            const SizedBox(height: 8),
            _chipRow('Senses', senses, Colors.indigo, withRange: true),
            _extraSpeedsRow(extraSpeeds, Colors.lightBlue),
            _textChipRow('HP Bonus', hpChips, Colors.pink),
            _textChipRow('Initiative', initChips, Colors.lightGreen),
            _chipRow('Skill Prof.', extraSkillProfIds, Colors.lime),
            _chipRow('Tool Prof.', extraToolProfIds, Colors.brown),
            _chipRow('Armor Prof.', armorProf, Colors.blueGrey),
            _chipRow('Weapon Prof.', weaponProf, Colors.orange),
            _chipRow('Resistances', res, Colors.green),
            _chipRow('Immunities', imm, Colors.blue),
            _chipRow('Vulnerabilities', vuln, Colors.deepOrange),
            _chipRow('Condition Imm.', cimm, Colors.purple),
            _conditionalGrantsBlock(conditional),
            _chipRow('Traits', traits, Colors.teal),
            _chipRow('Actions', actions, Colors.red),
            _chipRow('Bonus Actions', bonusActions, Colors.amber),
            _chipRow('Reactions', reactions, Colors.cyan),
            _tempHpGrantsBlock(tempHpGrants),
            _unarmoredFormulasBlock(unarmoredFormulas),
            _chipRow('Free Casts', freeCast, Colors.deepPurple),
            _chipRow('Ritual Book', ritualBook, Colors.brown),
            _chipRow('Active Conditions', activeConditions, Colors.redAccent),
            if (pools.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Granted Pools',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              const SizedBox(height: 4),
              for (final p in pools) _poolCounterRow(p),
            ],
          ],
        ),
      ),
    );
  }
}
