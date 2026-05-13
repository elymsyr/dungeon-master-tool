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

  /// Remaining-uses map for granted resource pools, keyed by entity id
  /// (e.g. innate spell id). Missing keys default to pool max.
  final Map<String, int> poolRemaining;

  /// Fires when player taps -/+ or rest button. Receives the full updated
  /// map (sparse — only non-default entries kept).
  final ValueChanged<Map<String, int>>? onPoolRemainingChanged;

  const ResolvedGrantsCard({
    super.key,
    required this.effective,
    required this.entities,
    required this.palette,
    this.poolRemaining = const {},
    this.onPoolRemainingChanged,
  });

  String _nameOf(String id) => entities[id]?.name ?? id;

  String _chipLabel(String id) {
    final name = _nameOf(id);
    final sources = effective.grantSources[id];
    if (sources == null || sources.isEmpty) return name;
    return '$name — ${sources.join(', ')}';
  }

  Widget _chipRow(
    String label,
    List<String> ids,
    Color chipColor,
  ) {
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
                _chipLabel(id),
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

  /// Pool entries whose `pool_ref` resolves to a granted entity id (innate
  /// spells). Class pools use a Map for `pool_ref` and are skipped here.
  List<Map<String, dynamic>> _grantedPoolEntries() {
    final out = <Map<String, dynamic>>[];
    for (final p in effective.resourcePools) {
      final ref = p['pool_ref'];
      if (ref is String && entities.containsKey(ref)) out.add(p);
    }
    return out;
  }

  Widget _poolCounterRow(Map<String, dynamic> entry) {
    final id = entry['pool_ref'] as String;
    final maxRaw = entry['max'];
    final max = maxRaw is int ? maxRaw : int.tryParse('$maxRaw') ?? 1;
    final cur = poolRemaining[id] ?? max;
    final name = _nameOf(id);
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
        ],
      ),
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
    if (senses.isEmpty &&
        res.isEmpty &&
        imm.isEmpty &&
        vuln.isEmpty &&
        cimm.isEmpty &&
        traits.isEmpty &&
        actions.isEmpty &&
        bonusActions.isEmpty &&
        reactions.isEmpty &&
        pools.isEmpty) {
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
            _chipRow('Senses', senses, Colors.indigo),
            _chipRow('Resistances', res, Colors.green),
            _chipRow('Immunities', imm, Colors.blue),
            _chipRow('Vulnerabilities', vuln, Colors.deepOrange),
            _chipRow('Condition Imm.', cimm, Colors.purple),
            _chipRow('Traits', traits, Colors.teal),
            _chipRow('Actions', actions, Colors.red),
            _chipRow('Bonus Actions', bonusActions, Colors.amber),
            _chipRow('Reactions', reactions, Colors.cyan),
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
