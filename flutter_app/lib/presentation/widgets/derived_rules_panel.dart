import 'package:flutter/material.dart';

import '../../domain/entities/entity.dart';
import '../../domain/services/entity_ref.dart';
import '../../domain/services/rules/bound_rule.dart';
import '../../domain/services/rules/rule_compiler.dart';
import '../../domain/services/rules/rule_trigger.dart';

/// Read-only "Rules (compiled)" panel on rule-bearing entity cards (PR-R3).
///
/// Runs the same [RuleCompiler] the character resolver uses and lists EVERY
/// rule the card contributes — explicit rows plus the implicit rules derived
/// from its typed fields ("compiled from granted_skill_refs") — grouped by
/// trigger. Cards whose mechanics live only in prose get a "not mechanized"
/// badge (roadmap 1.3 placeholder state) so authors can see what the engine
/// will and won't enforce. Never editable; never persisted.
class DerivedRulesPanel extends StatelessWidget {
  final Entity entity;
  final Map<String, Entity> entities;

  const DerivedRulesPanel({
    super.key,
    required this.entity,
    required this.entities,
  });

  static const _attachmentBySlug = <String, RuleAttachment>{
    'class': RuleAttachment.classHeld,
    'subclass': RuleAttachment.subclass,
    'species': RuleAttachment.species,
    'subspecies': RuleAttachment.subspecies,
    'background': RuleAttachment.background,
    'feat': RuleAttachment.feat,
    'trait': RuleAttachment.trait,
    'weapon': RuleAttachment.equippedItem,
    'armor': RuleAttachment.equippedItem,
    'magic-item': RuleAttachment.equippedItem,
  };

  /// Whether this panel applies to [categorySlug] at all.
  static bool supports(String categorySlug) =>
      _attachmentBySlug.containsKey(categorySlug);

  String _describe(BoundRule r) {
    final eff = r.effect;
    final kind = (eff['kind'] ?? '?').toString();
    final parts = <String>[kind.replaceAll('_', ' ')];
    final targetId = resolveEntityRef(eff['target_ref'], entities);
    if (targetId != null) {
      parts.add(entities[targetId]?.name ?? targetId);
    } else if (eff['target_ref'] is Map &&
        (eff['target_ref'] as Map)['name'] is String) {
      parts.add((eff['target_ref'] as Map)['name'] as String);
    } else if (eff['target_kind'] is String) {
      parts.add((eff['target_kind'] as String).replaceAll('_', ' '));
    }
    final v = eff['value'];
    if (v is num) parts.add(v >= 0 ? '+$v' : '$v');
    if (v is Map && v.containsKey(r'$field')) {
      parts.add('← field ${v[r'$field']}');
    }
    if (eff['mode'] is String) parts.add(eff['mode'] as String);
    if (r.atLevel > 0) parts.add('(L${r.atLevel})');
    if (r.clauses.isNotEmpty) parts.add('· ${r.clauses.length} clause(s)');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final attachment = _attachmentBySlug[entity.categorySlug];
    if (attachment == null) return const SizedBox.shrink();

    final compiler = RuleCompiler(entitiesById: entities);
    final rules =
        compiler.compile(entity, attachment: attachment, gateLevel: 20);

    // "Not mechanized": a feature_row level with prose but no effect rules,
    // or (for feats/traits/items) no rules at all despite a description.
    final mechanicalRules =
        rules.where((r) => r.effect['kind'] != 'feature_row').toList();
    final featureLevelsWithEffects = {
      for (final r in mechanicalRules)
        if (r.derivedFromField == 'features') r.atLevel,
    };
    final unmechanizedFeatureLevels = {
      for (final r in rules)
        if (r.effect['kind'] == 'feature_row' &&
            (r.effect['description'] ?? '').toString().isNotEmpty &&
            !featureLevelsWithEffects.contains(r.atLevel))
          r.atLevel,
    };
    final proseOnly =
        mechanicalRules.isEmpty && entity.description.trim().isNotEmpty;

    if (mechanicalRules.isEmpty && unmechanizedFeatureLevels.isEmpty && !proseOnly) {
      return const SizedBox.shrink();
    }

    final outline = Theme.of(context).colorScheme.outline;
    final byTrigger = <RuleTrigger, List<BoundRule>>{};
    for (final r in mechanicalRules) {
      byTrigger.putIfAbsent(r.trigger, () => []).add(r);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, size: 14, color: outline),
              const SizedBox(width: 6),
              Text(
                'Rules (compiled) — ${mechanicalRules.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (proseOnly || unmechanizedFeatureLevels.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    proseOnly
                        ? 'not mechanized — prose only'
                        : 'not mechanized: L${(unmechanizedFeatureLevels.toList()..sort()).join(", L")}',
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
            ],
          ),
          for (final t in RuleTrigger.values)
            if (byTrigger[t] != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  t.wire,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: outline),
                ),
              ),
              for (final r in byTrigger[t]!)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Text.rich(
                    TextSpan(
                      text: '• ${_describe(r)}',
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: r.derived
                              ? '   compiled from ${r.derivedFromField ?? 'fields'}'
                              : '   authored',
                          style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
