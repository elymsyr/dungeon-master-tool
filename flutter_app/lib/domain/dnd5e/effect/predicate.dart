import '../catalog/content_reference.dart';
import '../catalog/condition.dart';
import '../catalog/damage_type.dart';
import '../catalog/weapon_property.dart';
import '../core/ability.dart';

/// Tier 2: boolean gating condition on an effect. Closed sealed family — no
/// runtime-evaluated strings, no reflection. Engine dispatches on case.
sealed class Predicate {
  const Predicate();
}

class Always extends Predicate {
  const Always();
  @override
  bool operator ==(Object other) => other is Always;
  @override
  int get hashCode => (Always).hashCode;
  @override
  String toString() => 'Always';
}

class All extends Predicate {
  final List<Predicate> all;
  All(List<Predicate> all) : all = List.unmodifiable(all);

  @override
  bool operator ==(Object other) =>
      other is All &&
      other.all.length == all.length &&
      _listEq(other.all, all);
  @override
  int get hashCode => Object.hashAll(['All', ...all]);
  @override
  String toString() => 'All($all)';
}

class Any extends Predicate {
  final List<Predicate> any;
  Any(List<Predicate> any) : any = List.unmodifiable(any);

  @override
  bool operator ==(Object other) =>
      other is Any &&
      other.any.length == any.length &&
      _listEq(other.any, any);
  @override
  int get hashCode => Object.hashAll(['Any', ...any]);
  @override
  String toString() => 'Any($any)';
}

class Not extends Predicate {
  final Predicate p;
  const Not(this.p);

  @override
  bool operator ==(Object other) => other is Not && other.p == p;
  @override
  int get hashCode => Object.hash('Not', p);
  @override
  String toString() => 'Not($p)';
}

class AttackerHasCondition extends Predicate {
  final ContentReference<Condition> id;
  const AttackerHasCondition(this.id);

  @override
  bool operator ==(Object other) =>
      other is AttackerHasCondition && other.id == id;
  @override
  int get hashCode => Object.hash('AttackerHasCondition', id);
  @override
  String toString() => 'AttackerHasCondition($id)';
}

class TargetHasCondition extends Predicate {
  final ContentReference<Condition> id;
  const TargetHasCondition(this.id);

  @override
  bool operator ==(Object other) =>
      other is TargetHasCondition && other.id == id;
  @override
  int get hashCode => Object.hash('TargetHasCondition', id);
  @override
  String toString() => 'TargetHasCondition($id)';
}

class AttackIsMelee extends Predicate {
  const AttackIsMelee();
  @override
  bool operator ==(Object other) => other is AttackIsMelee;
  @override
  int get hashCode => (AttackIsMelee).hashCode;
  @override
  String toString() => 'AttackIsMelee';
}

class AttackIsRanged extends Predicate {
  const AttackIsRanged();
  @override
  bool operator ==(Object other) => other is AttackIsRanged;
  @override
  int get hashCode => (AttackIsRanged).hashCode;
  @override
  String toString() => 'AttackIsRanged';
}

class AttackUsesAbility extends Predicate {
  final Ability ability;
  const AttackUsesAbility(this.ability);

  @override
  bool operator ==(Object other) =>
      other is AttackUsesAbility && other.ability == ability;
  @override
  int get hashCode => Object.hash('AttackUsesAbility', ability);
  @override
  String toString() => 'AttackUsesAbility($ability)';
}

class WeaponHasProperty extends Predicate {
  final ContentReference<WeaponProperty> id;
  const WeaponHasProperty(this.id);

  @override
  bool operator ==(Object other) =>
      other is WeaponHasProperty && other.id == id;
  @override
  int get hashCode => Object.hash('WeaponHasProperty', id);
  @override
  String toString() => 'WeaponHasProperty($id)';
}

class DamageTypeIs extends Predicate {
  final ContentReference<DamageType> id;
  const DamageTypeIs(this.id);

  @override
  bool operator ==(Object other) => other is DamageTypeIs && other.id == id;
  @override
  int get hashCode => Object.hash('DamageTypeIs', id);
  @override
  String toString() => 'DamageTypeIs($id)';
}

class IsCritical extends Predicate {
  const IsCritical();
  @override
  bool operator ==(Object other) => other is IsCritical;
  @override
  int get hashCode => (IsCritical).hashCode;
  @override
  String toString() => 'IsCritical';
}

class HasAdvantage extends Predicate {
  const HasAdvantage();
  @override
  bool operator ==(Object other) => other is HasAdvantage;
  @override
  int get hashCode => (HasAdvantage).hashCode;
  @override
  String toString() => 'HasAdvantage';
}

class EffectActive extends Predicate {
  final String effectId;
  const EffectActive(this.effectId);

  @override
  bool operator ==(Object other) =>
      other is EffectActive && other.effectId == effectId;
  @override
  int get hashCode => Object.hash('EffectActive', effectId);
  @override
  String toString() => 'EffectActive($effectId)';
}

bool _listEq(List<Predicate> a, List<Predicate> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
