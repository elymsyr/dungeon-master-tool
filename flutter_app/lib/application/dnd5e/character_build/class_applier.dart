import '../../../domain/dnd5e/character/character_class.dart';
import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/inventory.dart';
import '../../../domain/dnd5e/character/proficiency_set.dart';
import '../../../domain/dnd5e/character/subclass.dart';
import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/core/proficiency.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';

/// Applies a [CharacterClass] (+ optional [Subclass]) at a given [level] to
/// a character. Applies:
/// - Save proficiencies from class.savingThrows (at level 1 only).
/// - Starting armor / weapon / tool / equipment proficiencies.
/// - Feature effects from featureTable rows up to [level].
/// - Subclass feature effects from its featureTable rows up to [level].
/// - Subclass bonus spells that become prepared at levels ≤ [level].
///
/// Skill choices (grantedSkillChoiceCount from grantedSkillOptions) are NOT
/// applied here — the orchestrator merges those separately from the
/// draft's `chosenSkillIds`.
class ClassApplier {
  const ClassApplier();

  Character apply(
    Character character,
    CharacterClass cls, {
    required int level,
    Subclass? subclass,
    bool isFirstClass = true,
  }) {
    // Save proficiencies only applied for the character's first class,
    // per SRD multiclass rules.
    final savesMap = <Ability, Proficiency>{};
    if (isFirstClass) {
      for (final ab in cls.savingThrows) {
        savesMap[ab] = Proficiency.full;
      }
    }

    // Starting armor/weapon/tool/equipment — only when joining class for
    // first time, not on re-apply.
    final startingProfs = isFirstClass
        ? ProficiencySet(
            armor: {for (final id in cls.startingArmorIds) id: Proficiency.full},
            weapons: {
              for (final id in cls.startingWeaponIds) id: Proficiency.full,
            },
            tools: {
              for (final id in cls.startingToolIds) id: Proficiency.full,
            },
          )
        : ProficiencySet.empty();

    // Feature effects from class rows up to `level`.
    final allEffects = <EffectDescriptor>[];
    for (final row in cls.featureTable) {
      if (row.level > level) continue;
      allEffects.addAll(row.effects);
    }
    if (subclass != null) {
      for (final row in subclass.featureTable) {
        if (row.level > level) continue;
        allEffects.addAll(row.effects);
      }
    }
    final grantsFromEffects = _extractGrants(allEffects);

    var mergedProfs = character.proficiencies.merge(startingProfs);
    mergedProfs = mergedProfs.merge(grantsFromEffects);
    // Ability saves are keyed by the Ability enum, not a string — carry
    // them in a dedicated ProficiencySet built from the short codes.
    if (savesMap.isNotEmpty) {
      mergedProfs = mergedProfs.merge(ProficiencySet(saves: savesMap));
    }

    final mergedLanguages = {
      ...character.languageIds,
      ...grantsFromEffects.languages,
    };

    final mergedPrepared = _applySubclassBonusSpells(
      character.preparedSpells,
      subclass,
      level,
      cls.id,
    );

    final mergedInventory = isFirstClass
        ? _seedInventory(character.inventory, cls.startingEquipmentIds)
        : character.inventory;

    return character.copyWith(
      proficiencies: mergedProfs,
      languageIds: mergedLanguages,
      preparedSpells: mergedPrepared,
      inventory: mergedInventory,
    );
  }

  PreparedSpells _applySubclassBonusSpells(
    PreparedSpells existing,
    Subclass? subclass,
    int level,
    String classId,
  ) {
    if (subclass == null) return existing;
    var result = existing;
    for (final entry in subclass.bonusSpellIds.entries) {
      if (entry.key > level) continue;
      for (final spellId in entry.value) {
        result = result.add(
          PreparedSpellEntry(spellId: spellId, classId: classId),
        );
      }
    }
    return result;
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

