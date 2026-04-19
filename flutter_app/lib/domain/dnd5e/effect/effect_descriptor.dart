import '../catalog/condition.dart';
import '../catalog/content_reference.dart';
import '../catalog/damage_type.dart';
import '../core/ability.dart';
import '../core/advantage_state.dart';
import '../core/dice_expression.dart';
import '../core/proficiency.dart';
import 'duration.dart';
import 'predicate.dart';

/// Who the effect applies to on an attack-roll modification.
enum EffectTarget { attacker, targeted }

/// ModifyResistances kind.
enum ResistanceKind { resistance, immunity, vulnerability }

/// GrantProficiency subject kind.
enum ProficiencyKind { save, skill, tool, weapon, armor, language }

/// GrantSenseOrSpeed subject kind.
enum SenseOrSpeedKind {
  darkvision,
  blindsight,
  tremorsense,
  truesight,
  walk,
  fly,
  swim,
  climb,
  burrow,
}

/// Pair of dice expression + damage type for extra-dice bonuses on damage rolls.
class TypedDice {
  final DiceExpression dice;
  final ContentReference<DamageType> damageTypeId;

  TypedDice({required this.dice, required this.damageTypeId}) {
    validateContentId(damageTypeId);
  }

  @override
  bool operator ==(Object other) =>
      other is TypedDice &&
      other.dice == dice &&
      other.damageTypeId == damageTypeId;
  @override
  int get hashCode => Object.hash(dice, damageTypeId);
  @override
  String toString() => 'TypedDice($dice, $damageTypeId)';
}

/// Save-to-resist spec attached to [GrantCondition].
class SaveSpec {
  final Ability ability;
  final int dc;
  final bool halfOnSuccess;

  SaveSpec({required this.ability, required this.dc, this.halfOnSuccess = false}) {
    if (dc < 0) throw ArgumentError('SaveSpec.dc must be >= 0');
  }

  @override
  bool operator ==(Object other) =>
      other is SaveSpec &&
      other.ability == ability &&
      other.dc == dc &&
      other.halfOnSuccess == halfOnSuccess;
  @override
  int get hashCode => Object.hash(ability, dc, halfOnSuccess);
  @override
  String toString() => 'SaveSpec($ability, DC $dc, half: $halfOnSuccess)';
}

/// AC formula variants the engine supports.
sealed class AcFormula {
  const AcFormula();
}

class AcFlat extends AcFormula {
  final int value;
  const AcFlat(this.value);
  @override
  bool operator ==(Object other) => other is AcFlat && other.value == value;
  @override
  int get hashCode => Object.hash('AcFlat', value);
}

class AcNaturalPlusDex extends AcFormula {
  final int base;
  final int? maxDex;
  const AcNaturalPlusDex({required this.base, this.maxDex});
  @override
  bool operator ==(Object other) =>
      other is AcNaturalPlusDex && other.base == base && other.maxDex == maxDex;
  @override
  int get hashCode => Object.hash('AcNaturalPlusDex', base, maxDex);
}

class AcUnarmored extends AcFormula {
  final Ability ability;
  const AcUnarmored(this.ability);
  @override
  bool operator ==(Object other) =>
      other is AcUnarmored && other.ability == ability;
  @override
  int get hashCode => Object.hash('AcUnarmored', ability);
}

class AcMageArmor extends AcFormula {
  const AcMageArmor();
  @override
  bool operator ==(Object other) => other is AcMageArmor;
  @override
  int get hashCode => (AcMageArmor).hashCode;
}

/// Tier 2: sealed family of rule-engine descriptors. Content authors embed
/// these on Tier 1 entities (Condition, Spell, Feat, MagicItem) to declare
/// behavior. Engine code in `application/dnd5e/services/` interprets them.
sealed class EffectDescriptor {
  const EffectDescriptor();
}

class ModifyAttackRoll extends EffectDescriptor {
  final Predicate when;
  final int flatBonus;
  final AdvantageState advantage;
  final DiceExpression? extraDice;
  final EffectTarget appliesTo;

  const ModifyAttackRoll({
    this.when = const Always(),
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    this.extraDice,
    this.appliesTo = EffectTarget.attacker,
  });
}

class ModifyDamageRoll extends EffectDescriptor {
  final Predicate when;
  final int flatBonus;
  final DiceExpression? extraDice;
  final List<TypedDice> extraTypedDice;
  final ContentReference<DamageType>? damageTypeOverride;

  ModifyDamageRoll({
    this.when = const Always(),
    this.flatBonus = 0,
    this.extraDice,
    List<TypedDice> extraTypedDice = const [],
    this.damageTypeOverride,
  }) : extraTypedDice = List.unmodifiable(extraTypedDice) {
    if (damageTypeOverride != null) validateContentId(damageTypeOverride!);
  }
}

class ModifySave extends EffectDescriptor {
  final Predicate when;
  final Ability ability;
  final int flatBonus;
  final AdvantageState advantage;
  final bool autoSucceed;
  final bool autoFail;

  ModifySave({
    this.when = const Always(),
    required this.ability,
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    this.autoSucceed = false,
    this.autoFail = false,
  }) {
    if (autoSucceed && autoFail) {
      throw ArgumentError('ModifySave cannot be both autoSucceed and autoFail');
    }
  }
}

class ModifyAc extends EffectDescriptor {
  final Predicate when;
  final int flat;
  final AcFormula? formula;

  const ModifyAc({
    this.when = const Always(),
    this.flat = 0,
    this.formula,
  });
}

class ModifyResistances extends EffectDescriptor {
  final Set<ContentReference<DamageType>> add;
  final Set<ContentReference<DamageType>> remove;
  final ResistanceKind kind;

  ModifyResistances({
    required this.kind,
    Set<ContentReference<DamageType>> add = const {},
    Set<ContentReference<DamageType>> remove = const {},
  })  : add = Set.unmodifiable(add),
        remove = Set.unmodifiable(remove) {
    for (final id in add) {
      validateContentId(id);
    }
    for (final id in remove) {
      validateContentId(id);
    }
  }
}

class GrantCondition extends EffectDescriptor {
  final ContentReference<Condition> conditionId;
  final EffectDuration duration;
  final SaveSpec? saveToResist;

  GrantCondition({
    required this.conditionId,
    required this.duration,
    this.saveToResist,
  }) {
    validateContentId(conditionId);
  }
}

class GrantProficiency extends EffectDescriptor {
  final ProficiencyKind kind;
  final String targetId;
  final Proficiency level;

  GrantProficiency({
    required this.kind,
    required this.targetId,
    this.level = Proficiency.full,
  }) {
    if (targetId.isEmpty) {
      throw ArgumentError('GrantProficiency.targetId must not be empty');
    }
    // Save proficiency targets are Ability.short codes (STR/DEX/...),
    // everything else must be namespaced.
    if (kind != ProficiencyKind.save) {
      validateContentId(targetId);
    }
  }
}

class GrantSenseOrSpeed extends EffectDescriptor {
  final SenseOrSpeedKind kind;
  final int value;

  GrantSenseOrSpeed({required this.kind, required this.value}) {
    if (value < 0) {
      throw ArgumentError('GrantSenseOrSpeed.value must be >= 0');
    }
  }
}

class Heal extends EffectDescriptor {
  final DiceExpression? dice;
  final int flatBonus;

  const Heal({this.dice, this.flatBonus = 0});
}

/// Meta descriptor used by [Condition.effects] to declare what being under the
/// condition does. Closed struct — extensions require cross-doc approval
/// (Doc 01 §Open Questions Q5).
class ConditionInteraction extends EffectDescriptor {
  final bool incapacitated;
  final bool speedZero;
  final Set<Ability> autoFailSavesOf;
  final bool imposedAdvantageOnAttacksAgainst;
  final bool attacksHaveDisadvantage;
  final bool cannotTakeActions;
  final bool cannotTakeReactions;
  final bool grappled;
  final bool restrained;
  final bool invisibleToSight;

  ConditionInteraction({
    this.incapacitated = false,
    this.speedZero = false,
    Set<Ability> autoFailSavesOf = const {},
    this.imposedAdvantageOnAttacksAgainst = false,
    this.attacksHaveDisadvantage = false,
    this.cannotTakeActions = false,
    this.cannotTakeReactions = false,
    this.grappled = false,
    this.restrained = false,
    this.invisibleToSight = false,
  }) : autoFailSavesOf = Set.unmodifiable(autoFailSavesOf);
}

/// Dart-backed custom effect bridge. Resolves [implementationId] against
/// [CustomEffectRegistry]; unknown ids fail at package import.
class CustomEffect extends EffectDescriptor {
  final String implementationId;
  final Map<String, Object?> parameters;

  CustomEffect({
    required this.implementationId,
    Map<String, Object?> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters) {
    if (implementationId.isEmpty) {
      throw ArgumentError('CustomEffect.implementationId must not be empty');
    }
    validateContentId(implementationId);
  }
}
