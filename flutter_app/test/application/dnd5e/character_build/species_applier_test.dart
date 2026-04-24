import 'package:dungeon_master_tool/application/dnd5e/character_build/species_applier.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/species.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

Character _seed() => Character(
      id: 'char-1',
      name: 'Test',
      classLevels: [CharacterClassLevel(classId: 'srd:wizard', level: 1)],
      speciesId: 'srd:human',
      backgroundId: 'srd:sage',
      alignmentId: 'srd:neutral',
      abilities: AbilityScores(
        str: AbilityScore(10),
        dex: AbilityScore(12),
        con: AbilityScore(14),
        int_: AbilityScore(16),
        wis: AbilityScore(10),
        cha: AbilityScore(8),
      ),
      hp: HitPoints(current: 6, max: 6),
    );

void main() {
  group('SpeciesApplier', () {
    const applier = SpeciesApplier();

    test('applies ability score increases', () {
      final species = Species(
        id: 'srd:half-elf',
        name: 'Half-Elf',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        abilityIncreases: {
          Ability.charisma: 2,
          Ability.constitution: 1,
        },
      );
      final c = applier.apply(_seed(), species);
      expect(c.abilities.cha.value, 10); // 8 + 2
      expect(c.abilities.con.value, 15); // 14 + 1
      expect(c.abilities.str.value, 10); // unchanged
    });

    test('merges innate spells into prepared pool', () {
      final drow = Species(
        id: 'srd:drow',
        name: 'Drow',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        innateSpellIds: ['srd:dancing-lights', 'srd:faerie-fire'],
      );
      final c = applier.apply(_seed(), drow);
      expect(c.preparedSpells.contains('srd:dancing-lights'), true);
      expect(c.preparedSpells.contains('srd:faerie-fire'), true);
    });

    test('grants proficiencies from effects', () {
      final elf = Species(
        id: 'srd:elf',
        name: 'Elf',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:perception',
          ),
          GrantProficiency(
            kind: ProficiencyKind.language,
            targetId: 'srd:elvish',
          ),
        ],
      );
      final c = applier.apply(_seed(), elf);
      expect(c.proficiencies.skills['srd:perception'], Proficiency.full);
      expect(c.languageIds, contains('srd:elvish'));
    });

    test('ability score clamped at 30', () {
      final seed = _seed().copyWith(
        abilities: _seed().abilities.withBonus(Ability.strength, 20),
      );
      final species = Species(
        id: 'srd:titanic',
        name: 'Titanic',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        abilityIncreases: {Ability.strength: 5},
      );
      final c = applier.apply(seed, species);
      expect(c.abilities.str.value, 30);
    });
  });
}
