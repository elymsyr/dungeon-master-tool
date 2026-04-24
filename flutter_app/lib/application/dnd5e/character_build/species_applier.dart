import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/character/proficiency_set.dart';
import '../../../domain/dnd5e/character/species.dart';
import '../../../domain/dnd5e/core/proficiency.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';

/// Applies a [Species]'s grants to a [Character]. Proficiencies + languages
/// flow through [GrantProficiency] effects (same pipeline as Background).
/// Ability-score increases, innate spells, and damage resistances come from
/// the first-class fields on [Species].
///
/// 2024 SRD moves ability-score increases from species to background, so
/// [Species.abilityIncreases] is typically empty for SRD content but the
/// applier respects it for homebrew + pre-2024 imports.
class SpeciesApplier {
  const SpeciesApplier();

  Character apply(Character character, Species species) {
    var abilities = character.abilities;
    for (final entry in species.abilityIncreases.entries) {
      abilities = abilities.withBonus(entry.key, entry.value);
    }

    final grantsFromEffects = _extractGrants(species.effects);
    final mergedProfs = character.proficiencies.merge(grantsFromEffects);

    final mergedLanguages = {
      ...character.languageIds,
      ...grantsFromEffects.languages,
    };

    final mergedPrepared =
        _addInnateSpells(character.preparedSpells, species.innateSpellIds);

    return character.copyWith(
      abilities: abilities,
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
    final languages = <String>{};
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
          break;
      }
    }
    return ProficiencySet(
      skills: skills,
      tools: tools,
      weapons: weapons,
      armor: armor,
      languages: languages,
    );
  }

  PreparedSpells _addInnateSpells(
      PreparedSpells existing, List<String> innateSpellIds) {
    if (innateSpellIds.isEmpty) return existing;
    // Innate spells are always-prepared, not class-bound — classId null.
    // Duplicate add is a no-op (PreparedSpells.add is idempotent).
    var result = existing;
    for (final spellId in innateSpellIds) {
      result = result.add(PreparedSpellEntry(spellId: spellId));
    }
    return result;
  }
}
