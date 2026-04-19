import '../../../domain/dnd5e/catalog/condition.dart';
import '../../../domain/dnd5e/catalog/content_reference.dart';
import '../../../domain/dnd5e/catalog/damage_type.dart';
import '../../../domain/dnd5e/catalog/weapon_property.dart';
import '../../../domain/dnd5e/core/ability.dart';

/// Attack reach kind. `none` means the predicate fires outside an attack
/// resolution (e.g. a passive feature checking the carrier's own conditions).
enum AttackReach { none, melee, ranged }

/// Snapshot of the world the engine inspects when evaluating a [Predicate]
/// or accumulating a list of [EffectDescriptor]. Constructed by the caller —
/// usually a combat or spell service — by flattening live combatant state.
///
/// Pure value type. No mutation, no live references. Pass slimmed sets.
class EffectContext {
  final Set<ContentReference<Condition>> attackerConditions;
  final Set<ContentReference<Condition>> targetConditions;
  final AttackReach attackReach;
  final Ability? attackAbility;
  final Set<ContentReference<WeaponProperty>> weaponProperties;
  final ContentReference<DamageType>? damageTypeId;
  final bool isCritical;
  final bool hasAdvantage;
  final Set<String> activeEffectIds;

  EffectContext({
    Set<ContentReference<Condition>> attackerConditions = const {},
    Set<ContentReference<Condition>> targetConditions = const {},
    this.attackReach = AttackReach.none,
    this.attackAbility,
    Set<ContentReference<WeaponProperty>> weaponProperties = const {},
    this.damageTypeId,
    this.isCritical = false,
    this.hasAdvantage = false,
    Set<String> activeEffectIds = const {},
  })  : attackerConditions = Set.unmodifiable(attackerConditions),
        targetConditions = Set.unmodifiable(targetConditions),
        weaponProperties = Set.unmodifiable(weaponProperties),
        activeEffectIds = Set.unmodifiable(activeEffectIds);
}
