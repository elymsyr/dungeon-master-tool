import '../../../domain/dnd5e/character/background.dart';
import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/inventory.dart';
import '../../../domain/dnd5e/character/proficiency_set.dart';
import '../../../domain/dnd5e/core/proficiency.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';

/// Applies a [Background]'s grants to a [Character]. Pure function — returns
/// a new Character. All grants flow through canonical character fields so
/// downstream systems (combat resolver, spell resolver, sheet rendering)
/// see a uniform picture. [Background.effects] stay in place for per-roll
/// mechanics; this applier only consumes the grant-shaped ones.
///
/// [chosenSkillIds] is not consumed directly here — the character-build
/// orchestrator merges that after background grants, because skill choices
/// can come from any source (class, background, feat).
class BackgroundApplier {
  const BackgroundApplier();

  Character apply(Character character, Background background) {
    final existingFeatIds = character.featIds.toSet();
    final mergedFeats = [...character.featIds];
    if (background.grantedFeatId != null &&
        !existingFeatIds.contains(background.grantedFeatId)) {
      mergedFeats.add(background.grantedFeatId!);
    }

    // Merge background effects' GrantProficiency entries into the character's
    // ProficiencySet. Non-grant effects are ignored here — they still live
    // on the Background for the combat resolver to find.
    final grantsFromEffects = _extractGrants(background.effects);
    final mergedProfs = character.proficiencies.merge(grantsFromEffects);

    final mergedLanguages = {
      ...character.languageIds,
      ...background.languageIds,
    };

    final mergedInventory = _seedInventory(
      character.inventory,
      background.startingEquipmentIds,
    );

    return character.copyWith(
      proficiencies: mergedProfs,
      featIds: mergedFeats,
      languageIds: mergedLanguages,
      inventory: mergedInventory,
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
          // Save proficiencies come from class, not background per SRD.
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

  Inventory _seedInventory(Inventory existing, List<String> equipmentIds) {
    if (equipmentIds.isEmpty) return existing;
    final existingItemIds = {for (final e in existing.entries) e.itemId};
    final added = <InventoryEntry>[];
    for (final itemId in equipmentIds) {
      if (existingItemIds.contains(itemId)) continue;
      added.add(InventoryEntry(itemId: itemId));
    }
    if (added.isEmpty) return existing;
    return existing.copyWith(entries: [...existing.entries, ...added]);
  }
}
