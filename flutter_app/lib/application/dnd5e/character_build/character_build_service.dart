import '../../../domain/dnd5e/character/background.dart';
import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/character_class.dart';
import '../../../domain/dnd5e/character/feat.dart';
import '../../../domain/dnd5e/character/proficiency_set.dart';
import '../../../domain/dnd5e/character/species.dart';
import '../../../domain/dnd5e/character/subclass.dart';
import '../../../domain/dnd5e/core/proficiency.dart';
import 'background_applier.dart';
import 'class_applier.dart';
import 'feat_applier.dart';
import 'species_applier.dart';

/// The per-class selection a character author has made: which class, at what
/// level, its (optional) subclass, and the skills the user chose from the
/// class's skill-option pool.
class ClassSelection {
  final CharacterClass cls;
  final int level;
  final Subclass? subclass;
  final List<String> chosenSkillIds;

  const ClassSelection({
    required this.cls,
    required this.level,
    this.subclass,
    this.chosenSkillIds = const [],
  });
}

/// The per-feat selection: the feat and the skills/tools/languages the user
/// picked from its option pool (feats like Skilled grant choice-of).
class FeatSelection {
  final Feat feat;
  final List<String> chosenSkillIds;

  const FeatSelection({required this.feat, this.chosenSkillIds = const []});
}

/// Orchestrator for building a fully-resolved [Character] from a [Character]
/// seed + catalog references. Calls appliers in canonical order so grants
/// from later sources merge on top of earlier ones (merge is idempotent, so
/// order mostly doesn't matter for proficiencies — but ability-increase
/// ordering makes a difference for totals, so species-before-background is
/// the 2024 SRD rule).
class CharacterBuildService {
  final BackgroundApplier _background;
  final SpeciesApplier _species;
  final ClassApplier _classApplier;
  final FeatApplier _featApplier;

  const CharacterBuildService({
    BackgroundApplier background = const BackgroundApplier(),
    SpeciesApplier species = const SpeciesApplier(),
    ClassApplier classApplier = const ClassApplier(),
    FeatApplier featApplier = const FeatApplier(),
  })  : _background = background,
        _species = species,
        _classApplier = classApplier,
        _featApplier = featApplier;

  /// Builds a resolved character. [seed] carries the identity + core fields
  /// (name, abilities, hp, etc.); the appliers layer on grants.
  Character build({
    required Character seed,
    Species? species,
    Background? background,
    List<String> backgroundChosenSkillIds = const [],
    List<ClassSelection> classes = const [],
    List<FeatSelection> feats = const [],
    List<String> chosenLanguageIds = const [],
  }) {
    var character = seed;

    if (species != null) {
      character = _species.apply(character, species);
    }
    if (background != null) {
      character = _background.apply(character, background);
      if (backgroundChosenSkillIds.isNotEmpty) {
        character =
            _grantChosenSkills(character, backgroundChosenSkillIds);
      }
    }
    for (var i = 0; i < classes.length; i++) {
      final sel = classes[i];
      character = _classApplier.apply(
        character,
        sel.cls,
        level: sel.level,
        subclass: sel.subclass,
        isFirstClass: i == 0,
      );
      if (sel.chosenSkillIds.isNotEmpty) {
        character = _grantChosenSkills(character, sel.chosenSkillIds);
      }
    }
    for (final featSel in feats) {
      character = _featApplier.apply(character, featSel.feat);
      if (featSel.chosenSkillIds.isNotEmpty) {
        character = _grantChosenSkills(character, featSel.chosenSkillIds);
      }
    }
    if (chosenLanguageIds.isNotEmpty) {
      character = character.copyWith(languageIds: {
        ...character.languageIds,
        ...chosenLanguageIds,
      });
    }

    return character;
  }

  /// Merges user-chosen skills into character proficiencies at [Proficiency.full].
  Character _grantChosenSkills(Character c, List<String> skillIds) {
    final skills = <String, Proficiency>{
      for (final id in skillIds) id: Proficiency.full,
    };
    return c.copyWith(
      proficiencies: c.proficiencies.merge(ProficiencySet(skills: skills)),
    );
  }

  /// Convenience — true if any class in [classes] is a spellcaster. Exposed
  /// so callers can pass [FeatApplier.checkPrerequisites] the right boolean.
  bool isSpellcaster(List<ClassSelection> classes) {
    for (final sel in classes) {
      if (sel.cls.spellcastingAbility != null) return true;
    }
    return false;
  }
}

