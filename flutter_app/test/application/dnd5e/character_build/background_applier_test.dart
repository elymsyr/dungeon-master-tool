import 'package:dungeon_master_tool/application/dnd5e/character_build/background_applier.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/background.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
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
      backgroundId: 'srd:acolyte',
      alignmentId: 'srd:neutral',
      abilities: AbilityScores.allTens(),
      hp: HitPoints(current: 6, max: 6),
    );

void main() {
  group('BackgroundApplier', () {
    test('grants skill + tool proficiencies from effects', () {
      final background = Background(
        id: 'srd:acolyte',
        name: 'Acolyte',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:insight',
          ),
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:religion',
          ),
          GrantProficiency(
            kind: ProficiencyKind.tool,
            targetId: 'srd:calligraphers-supplies',
          ),
        ],
      );
      final c = const BackgroundApplier().apply(_seed(), background);
      expect(c.proficiencies.skills['srd:insight'], Proficiency.full);
      expect(c.proficiencies.skills['srd:religion'], Proficiency.full);
      expect(c.proficiencies.tools['srd:calligraphers-supplies'],
          Proficiency.full);
    });

    test('grants languages from effects', () {
      final background = Background(
        id: 'srd:hermit',
        name: 'Hermit',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.language,
            targetId: 'srd:celestial',
          ),
        ],
      );
      final c = const BackgroundApplier().apply(_seed(), background);
      expect(c.proficiencies.languages, contains('srd:celestial'));
      expect(c.languageIds, contains('srd:celestial'));
    });

    test('appends grantedFeatId to character featIds', () {
      final background = Background(
        id: 'srd:soldier',
        name: 'Soldier',
        grantedFeatId: 'srd:savage-attacker',
      );
      final c = const BackgroundApplier().apply(_seed(), background);
      expect(c.featIds, contains('srd:savage-attacker'));
    });

    test('de-duplicates featId when already present', () {
      final background = Background(
        id: 'srd:soldier',
        name: 'Soldier',
        grantedFeatId: 'srd:already-have',
      );
      final seed = _seed().copyWith(featIds: ['srd:already-have']);
      final c = const BackgroundApplier().apply(seed, background);
      expect(c.featIds.where((id) => id == 'srd:already-have').length, 1);
    });

    test('seeds starting equipment into inventory', () {
      final background = Background(
        id: 'srd:acolyte',
        name: 'Acolyte',
        startingEquipmentIds: ['srd:holy-symbol', 'srd:prayer-book'],
      );
      final c = const BackgroundApplier().apply(_seed(), background);
      expect(c.inventory.entries.map((e) => e.itemId),
          containsAll(['srd:holy-symbol', 'srd:prayer-book']));
    });

    test('applies full Acolyte: skills + languages + feat + equipment', () {
      final acolyte = Background(
        id: 'srd:acolyte',
        name: 'Acolyte',
        grantedFeatId: 'srd:magic-initiate-cleric',
        startingEquipmentIds: ['srd:holy-symbol'],
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:insight',
          ),
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:religion',
          ),
          GrantProficiency(
            kind: ProficiencyKind.language,
            targetId: 'srd:celestial',
          ),
        ],
      );
      final c = const BackgroundApplier().apply(_seed(), acolyte);
      expect(c.proficiencies.skills.keys,
          containsAll(['srd:insight', 'srd:religion']));
      expect(c.languageIds, contains('srd:celestial'));
      expect(c.featIds, contains('srd:magic-initiate-cleric'));
      expect(c.inventory.entries.map((e) => e.itemId),
          contains('srd:holy-symbol'));
    });
  });
}
