import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/core/ability.dart';
import 'effect_context.dart';

/// Pure builder. Flattens [Combatant] state into the value-typed [EffectContext]
/// the predicate engine and accumulator consume. The builder owns the small
/// translation rules (e.g. on a self-save the saver's conditions populate the
/// `attackerConditions` slot — that slot reads as "the conditions of the
/// carrier of this side of the effect" rather than "the active turn taker").
class EffectContextBuilder {
  const EffectContextBuilder();

  /// Builds the context for an attack roll between [attacker] and [target].
  EffectContext forAttack({
    required Combatant attacker,
    required Combatant target,
    required AttackReach reach,
    Ability? attackAbility,
    Set<String> weaponProperties = const {},
    String? damageTypeId,
    bool isCritical = false,
    bool hasAdvantage = false,
    Set<String> activeEffectIds = const {},
  }) {
    return EffectContext(
      attackerConditions: attacker.conditionIds,
      targetConditions: target.conditionIds,
      attackReach: reach,
      attackAbility: attackAbility,
      weaponProperties: weaponProperties,
      damageTypeId: damageTypeId,
      isCritical: isCritical,
      hasAdvantage: hasAdvantage,
      activeEffectIds: activeEffectIds,
    );
  }

  /// Builds the context for a damage roll. No attack reach; damage type drives
  /// `DamageTypeIs`-style predicates.
  EffectContext forDamage({
    required Combatant attacker,
    required Combatant target,
    required String damageTypeId,
    bool isCritical = false,
    Set<String> activeEffectIds = const {},
  }) {
    return EffectContext(
      attackerConditions: attacker.conditionIds,
      targetConditions: target.conditionIds,
      attackReach: AttackReach.none,
      damageTypeId: damageTypeId,
      isCritical: isCritical,
      activeEffectIds: activeEffectIds,
    );
  }

  /// Builds the context for a self-save. The saver's conditions go into the
  /// `attackerConditions` slot since they are the carrier of the relevant
  /// attribute being checked by [Predicate]s.
  EffectContext forSelfSave({
    required Combatant saver,
    Set<String> activeEffectIds = const {},
  }) {
    return EffectContext(
      attackerConditions: saver.conditionIds,
      attackReach: AttackReach.none,
      activeEffectIds: activeEffectIds,
    );
  }
}
