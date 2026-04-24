import '../catalog/content_reference.dart';
import '../core/ability.dart';

/// Structured prerequisite for a [Feat]. Content authors compose a list of
/// these on `Feat.prerequisites`; the builder rejects the feat unless every
/// entry evaluates true for the target character. Evaluation lives on the
/// `FeatApplier` service — this type is pure data.
sealed class FeatPrerequisite {
  const FeatPrerequisite();
}

/// Ability score must meet or exceed [minimum].
class AbilityMinimum extends FeatPrerequisite {
  final Ability ability;
  final int minimum;

  const AbilityMinimum({required this.ability, required this.minimum});

  @override
  bool operator ==(Object other) =>
      other is AbilityMinimum &&
      other.ability == ability &&
      other.minimum == minimum;

  @override
  int get hashCode => Object.hash('AbilityMinimum', ability, minimum);

  @override
  String toString() => 'AbilityMinimum(${ability.short} >= $minimum)';
}

/// Character must have proficiency in [proficiencyId] (skill/tool/weapon/armor).
class ProficiencyRequired extends FeatPrerequisite {
  final String proficiencyId;

  ProficiencyRequired(this.proficiencyId) {
    validateContentId(proficiencyId);
  }

  @override
  bool operator ==(Object other) =>
      other is ProficiencyRequired && other.proficiencyId == proficiencyId;

  @override
  int get hashCode => Object.hash('ProficiencyRequired', proficiencyId);

  @override
  String toString() => 'ProficiencyRequired($proficiencyId)';
}

/// Character must be able to cast at least one spell (any caster class or
/// subclass). Matches SRD "Spellcasting or Pact Magic feature".
class SpellcasterRequired extends FeatPrerequisite {
  const SpellcasterRequired();

  @override
  bool operator ==(Object other) => other is SpellcasterRequired;

  @override
  int get hashCode => (SpellcasterRequired).hashCode;

  @override
  String toString() => 'SpellcasterRequired';
}

/// Character must have at least one level in [classId].
class ClassRequired extends FeatPrerequisite {
  final ContentReference classId;

  ClassRequired(this.classId) {
    validateContentId(classId);
  }

  @override
  bool operator ==(Object other) =>
      other is ClassRequired && other.classId == classId;

  @override
  int get hashCode => Object.hash('ClassRequired', classId);

  @override
  String toString() => 'ClassRequired($classId)';
}

/// Character's species must match [speciesId].
class SpeciesRequired extends FeatPrerequisite {
  final ContentReference speciesId;

  SpeciesRequired(this.speciesId) {
    validateContentId(speciesId);
  }

  @override
  bool operator ==(Object other) =>
      other is SpeciesRequired && other.speciesId == speciesId;

  @override
  int get hashCode => Object.hash('SpeciesRequired', speciesId);

  @override
  String toString() => 'SpeciesRequired($speciesId)';
}

/// Character total level must be >= [minimum].
class LevelMinimum extends FeatPrerequisite {
  final int minimum;

  const LevelMinimum(this.minimum);

  @override
  bool operator ==(Object other) =>
      other is LevelMinimum && other.minimum == minimum;

  @override
  int get hashCode => Object.hash('LevelMinimum', minimum);

  @override
  String toString() => 'LevelMinimum($minimum)';
}
