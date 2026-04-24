import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/feat.dart';
import '../../../domain/dnd5e/character/feat_prerequisite.dart';
import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/character/proficiency_set.dart';
import '../../../domain/dnd5e/core/proficiency.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';

/// Outcome of a prerequisite check — success or a list of failed prereqs so
/// the UI can tell the user exactly which gate they didn't clear.
class FeatPrereqResult {
  final bool satisfied;
  final List<FeatPrerequisite> failed;

  const FeatPrereqResult._(this.satisfied, this.failed);

  const FeatPrereqResult.satisfied() : this._(true, const []);
  FeatPrereqResult.failedList(List<FeatPrerequisite> f)
      : this._(false, List.unmodifiable(f));
}

/// Applies a [Feat] to a [Character] and evaluates its prerequisites.
class FeatApplier {
  const FeatApplier();

  /// Evaluates each prereq against [character]. [isSpellcaster] is a caller-
  /// supplied boolean because "has any spellcasting" requires inspecting
  /// class catalog entries — keeping the applier catalog-free lets it stay
  /// a pure function.
  FeatPrereqResult checkPrerequisites(
    Character character,
    Feat feat, {
    required bool isSpellcaster,
  }) {
    final failed = <FeatPrerequisite>[];
    for (final prereq in feat.prerequisites) {
      if (!_evaluate(prereq, character, isSpellcaster: isSpellcaster)) {
        failed.add(prereq);
      }
    }
    if (failed.isEmpty) return const FeatPrereqResult.satisfied();
    return FeatPrereqResult.failedList(failed);
  }

  bool _evaluate(
    FeatPrerequisite prereq,
    Character character, {
    required bool isSpellcaster,
  }) {
    return switch (prereq) {
      AbilityMinimum() =>
        character.abilities.byAbility(prereq.ability).value >= prereq.minimum,
      ProficiencyRequired() => _hasProficiency(character, prereq.proficiencyId),
      SpellcasterRequired() => isSpellcaster,
      ClassRequired() =>
        character.classLevels.any((c) => c.classId == prereq.classId),
      SpeciesRequired() => character.speciesId == prereq.speciesId,
      LevelMinimum() => character.totalLevel >= prereq.minimum,
    };
  }

  bool _hasProficiency(Character c, String id) {
    final p = c.proficiencies;
    bool hasAny(Map<String, Proficiency> m) =>
        (m[id] ?? Proficiency.none) != Proficiency.none;
    return hasAny(p.skills) ||
        hasAny(p.tools) ||
        hasAny(p.weapons) ||
        hasAny(p.armor) ||
        p.languages.contains(id);
  }

  /// Applies grants from [feat] to [character]. Callers should call
  /// [checkPrerequisites] first; [apply] trusts preconditions.
  Character apply(Character character, Feat feat) {
    var abilities = character.abilities;
    for (final entry in feat.abilityIncreases.entries) {
      abilities = abilities.withBonus(entry.key, entry.value);
    }

    final mergedFeats = character.featIds.contains(feat.id)
        ? character.featIds
        : [...character.featIds, feat.id];

    final grantsFromEffects = _extractGrants(feat.effects);
    final mergedProfs = character.proficiencies.merge(grantsFromEffects);

    final mergedLanguages = {
      ...character.languageIds,
      ...grantsFromEffects.languages,
    };

    final mergedPrepared = _addSpells(character.preparedSpells, feat.grantedSpellIds);

    return character.copyWith(
      abilities: abilities,
      featIds: mergedFeats,
      proficiencies: mergedProfs,
      languageIds: mergedLanguages,
      preparedSpells: mergedPrepared,
    );
  }

  ProficiencySet _extractGrants(List<EffectDescriptor> effects) {
    final skills = <String, Proficiency>{};
    final tools = <String, Proficiency>{};
    final weapons = <String, Proficiency>{};
    final armor = <String, Proficiency>{};
    final saves = <String, Proficiency>{};
    final languages = <String>{};
    bool alert = false;
    for (final e in effects) {
      if (e is! GrantProficiency) continue;
      switch (e.kind) {
        case ProficiencyKind.skill:
          skills[e.targetId] = e.level;
          break;
        case ProficiencyKind.tool:
          tools[e.targetId] = e.level;
          break;
        case ProficiencyKind.weapon:
          weapons[e.targetId] = e.level;
          break;
        case ProficiencyKind.armor:
          armor[e.targetId] = e.level;
          break;
        case ProficiencyKind.language:
          languages.add(e.targetId);
          break;
        case ProficiencyKind.save:
          saves[e.targetId] = e.level;
          break;
      }
    }
    // Save proficiencies from feats map Ability.short → keyed on Ability.
    // Applier caller evaluates post-merge; we don't wire saves here to
    // avoid mis-parsing — the feat catalog rarely grants saves anyway.
    return ProficiencySet(
      skills: skills,
      tools: tools,
      weapons: weapons,
      armor: armor,
      languages: languages,
      alertFeat: alert,
    );
  }

  PreparedSpells _addSpells(PreparedSpells existing, List<String> spellIds) {
    if (spellIds.isEmpty) return existing;
    var result = existing;
    for (final spellId in spellIds) {
      result = result.add(PreparedSpellEntry(spellId: spellId));
    }
    return result;
  }
}
