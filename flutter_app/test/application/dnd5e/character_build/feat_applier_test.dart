import 'package:dungeon_master_tool/application/dnd5e/character_build/feat_applier.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat_prerequisite.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/proficiency_set.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:flutter_test/flutter_test.dart';

Character _seed({
  int str = 10,
  int level = 1,
  ProficiencySet? proficiencies,
}) =>
    Character(
      id: 'char-1',
      name: 'Test',
      classLevels: [
        CharacterClassLevel(classId: 'srd:fighter', level: level),
      ],
      speciesId: 'srd:human',
      backgroundId: 'srd:soldier',
      alignmentId: 'srd:neutral',
      abilities: AbilityScores(
        str: AbilityScore(str),
        dex: AbilityScore(10),
        con: AbilityScore(10),
        int_: AbilityScore(10),
        wis: AbilityScore(10),
        cha: AbilityScore(10),
      ),
      proficiencies: proficiencies,
      hp: HitPoints(current: 10, max: 10),
    );

void main() {
  group('FeatApplier.checkPrerequisites', () {
    const applier = FeatApplier();

    test('AbilityMinimum passes when score meets threshold', () {
      final feat = Feat(
        id: 'srd:great-weapon-master',
        name: 'Great Weapon Master',
        category: FeatCategory.general,
        prerequisites: [
          const AbilityMinimum(ability: Ability.strength, minimum: 13),
        ],
      );
      final result = applier.checkPrerequisites(
        _seed(str: 13),
        feat,
        isSpellcaster: false,
      );
      expect(result.satisfied, true);
    });

    test('AbilityMinimum fails when score below threshold', () {
      final feat = Feat(
        id: 'srd:great-weapon-master',
        name: 'Great Weapon Master',
        category: FeatCategory.general,
        prerequisites: [
          const AbilityMinimum(ability: Ability.strength, minimum: 13),
        ],
      );
      final result = applier.checkPrerequisites(
        _seed(str: 10),
        feat,
        isSpellcaster: false,
      );
      expect(result.satisfied, false);
      expect(result.failed, hasLength(1));
      expect(result.failed.first, isA<AbilityMinimum>());
    });

    test('SpellcasterRequired respects caller flag', () {
      final feat = Feat(
        id: 'srd:war-caster',
        name: 'War Caster',
        category: FeatCategory.general,
        prerequisites: [const SpellcasterRequired()],
      );
      expect(
          applier
              .checkPrerequisites(_seed(), feat, isSpellcaster: false)
              .satisfied,
          false);
      expect(
          applier
              .checkPrerequisites(_seed(), feat, isSpellcaster: true)
              .satisfied,
          true);
    });

    test('LevelMinimum passes at or above level', () {
      final feat = Feat(
        id: 'srd:epic-boon',
        name: 'Epic Boon',
        category: FeatCategory.epicBoon,
        prerequisites: [const LevelMinimum(19)],
      );
      expect(
          applier
              .checkPrerequisites(_seed(level: 19), feat,
                  isSpellcaster: false)
              .satisfied,
          true);
      expect(
          applier
              .checkPrerequisites(_seed(level: 18), feat,
                  isSpellcaster: false)
              .satisfied,
          false);
    });

    test('ProficiencyRequired checks skills/tools/weapons/armor/languages', () {
      final feat = Feat(
        id: 'srd:medium-armor-master',
        name: 'Medium Armor Master',
        category: FeatCategory.general,
        prerequisites: [ProficiencyRequired('srd:medium-armor')],
      );
      final withProf = _seed(
        proficiencies: ProficiencySet(
          armor: {'srd:medium-armor': Proficiency.full},
        ),
      );
      expect(
          applier
              .checkPrerequisites(withProf, feat, isSpellcaster: false)
              .satisfied,
          true);
      expect(
          applier
              .checkPrerequisites(_seed(), feat, isSpellcaster: false)
              .satisfied,
          false);
    });

    test('multiple prereqs — all must pass', () {
      final feat = Feat(
        id: 'srd:multi-prereq',
        name: 'Multi',
        category: FeatCategory.general,
        prerequisites: [
          const AbilityMinimum(ability: Ability.strength, minimum: 13),
          const LevelMinimum(4),
        ],
      );
      final result = applier.checkPrerequisites(
        _seed(str: 15, level: 3), // str ok, level fails
        feat,
        isSpellcaster: false,
      );
      expect(result.satisfied, false);
      expect(result.failed, hasLength(1));
      expect(result.failed.first, isA<LevelMinimum>());
    });
  });

  group('FeatApplier.apply', () {
    const applier = FeatApplier();

    test('ability increases raise scores', () {
      final feat = Feat(
        id: 'srd:resilient-con',
        name: 'Resilient (Con)',
        category: FeatCategory.general,
        abilityIncreases: {Ability.constitution: 1},
      );
      final c = applier.apply(_seed(), feat);
      expect(c.abilities.con.value, 11);
    });

    test('feat id appended to character featIds', () {
      final feat = Feat(
        id: 'srd:lucky',
        name: 'Lucky',
        category: FeatCategory.general,
      );
      final c = applier.apply(_seed(), feat);
      expect(c.featIds, contains('srd:lucky'));
    });

    test('grantedSpellIds added to prepared pool', () {
      final feat = Feat(
        id: 'srd:magic-initiate',
        name: 'Magic Initiate',
        category: FeatCategory.origin,
        grantedSpellIds: ['srd:guidance', 'srd:cure-wounds'],
      );
      final c = applier.apply(_seed(), feat);
      expect(c.preparedSpells.contains('srd:guidance'), true);
      expect(c.preparedSpells.contains('srd:cure-wounds'), true);
    });
  });
}
