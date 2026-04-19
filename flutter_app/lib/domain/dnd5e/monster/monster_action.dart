import '../catalog/content_reference.dart';
import '../core/ability.dart';
import '../core/dice_expression.dart';
import '../effect/effect_descriptor.dart';

/// Sealed monster action family — what an NPC can do on its turn.
sealed class MonsterAction {
  String get name;
  String get description;
}

class AttackAction implements MonsterAction {
  @override
  final String name;
  @override
  final String description;
  final int attackBonus;
  final int reachFt;
  final int? rangeNormalFt;
  final int? rangeLongFt;
  final DiceExpression damage;
  final String damageTypeId;

  AttackAction._(this.name, this.description, this.attackBonus, this.reachFt,
      this.rangeNormalFt, this.rangeLongFt, this.damage, this.damageTypeId);

  factory AttackAction({
    required String name,
    String description = '',
    required int attackBonus,
    int reachFt = 5,
    int? rangeNormalFt,
    int? rangeLongFt,
    required DiceExpression damage,
    required ContentReference damageTypeId,
  }) {
    if (name.isEmpty) throw ArgumentError('AttackAction.name must not be empty');
    if (reachFt < 0) throw ArgumentError('AttackAction.reachFt must be >= 0');
    validateContentId(damageTypeId);
    if ((rangeNormalFt == null) != (rangeLongFt == null)) {
      throw ArgumentError(
          'AttackAction: rangeNormalFt and rangeLongFt must both be set or both null');
    }
    if (rangeNormalFt != null && rangeLongFt! < rangeNormalFt) {
      throw ArgumentError(
          'AttackAction.rangeLongFt must be >= rangeNormalFt');
    }
    return AttackAction._(name, description, attackBonus, reachFt,
        rangeNormalFt, rangeLongFt, damage, damageTypeId);
  }
}

class MultiattackAction implements MonsterAction {
  @override
  final String name;
  @override
  final String description;
  final List<String> actionNames;

  MultiattackAction._(this.name, this.description, this.actionNames);

  factory MultiattackAction({
    String name = 'Multiattack',
    String description = '',
    required List<String> actionNames,
  }) {
    if (actionNames.isEmpty) {
      throw ArgumentError('MultiattackAction requires >=1 actionNames');
    }
    return MultiattackAction._(
        name, description, List.unmodifiable(actionNames));
  }
}

class SaveAction implements MonsterAction {
  @override
  final String name;
  @override
  final String description;
  final Ability ability;
  final int dc;
  final DiceExpression? damage;
  final String? damageTypeId;
  final bool halfOnSave;

  SaveAction._(this.name, this.description, this.ability, this.dc, this.damage,
      this.damageTypeId, this.halfOnSave);

  factory SaveAction({
    required String name,
    String description = '',
    required Ability ability,
    required int dc,
    DiceExpression? damage,
    ContentReference? damageTypeId,
    bool halfOnSave = true,
  }) {
    if (name.isEmpty) throw ArgumentError('SaveAction.name must not be empty');
    if (dc < 0) throw ArgumentError('SaveAction.dc must be >= 0');
    if (damageTypeId != null) validateContentId(damageTypeId);
    return SaveAction._(name, description, ability, dc, damage, damageTypeId,
        halfOnSave);
  }
}

class SpecialAction implements MonsterAction {
  @override
  final String name;
  @override
  final String description;
  final List<EffectDescriptor> effects;

  SpecialAction._(this.name, this.description, this.effects);

  factory SpecialAction({
    required String name,
    String description = '',
    List<EffectDescriptor> effects = const [],
  }) {
    if (name.isEmpty) {
      throw ArgumentError('SpecialAction.name must not be empty');
    }
    return SpecialAction._(name, description, List.unmodifiable(effects));
  }
}
