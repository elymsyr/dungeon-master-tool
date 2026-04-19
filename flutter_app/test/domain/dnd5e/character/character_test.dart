import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/proficiency_set.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:flutter_test/flutter_test.dart';

AbilityScores _stdAbilities() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(14),
      con: AbilityScore(12),
      int_: AbilityScore(10),
      wis: AbilityScore(14),
      cha: AbilityScore(10),
    );

Character _build({
  List<CharacterClassLevel>? classLevels,
  ProficiencySet? proficiencies,
}) =>
    Character(
      id: 'char-1',
      name: 'Test',
      classLevels: classLevels ??
          [CharacterClassLevel(classId: 'srd:wizard', level: 1)],
      speciesId: 'srd:human',
      backgroundId: 'srd:sage',
      alignmentId: 'srd:neutral',
      abilities: _stdAbilities(),
      proficiencies: proficiencies,
      hp: HitPoints(current: 6, max: 6),
    );

void main() {
  group('Character factory', () {
    test('rejects empty classLevels', () {
      expect(
          () => Character(
                id: 'x',
                name: 'X',
                classLevels: const [],
                speciesId: 'srd:human',
                backgroundId: 'srd:sage',
                alignmentId: 'srd:neutral',
                abilities: _stdAbilities(),
                hp: HitPoints(current: 1, max: 1),
              ),
          throwsArgumentError);
    });

    test('rejects total level > 20', () {
      expect(
          () => _build(classLevels: [
                CharacterClassLevel(classId: 'srd:wizard', level: 20),
                CharacterClassLevel(classId: 'srd:cleric', level: 1),
              ]),
          throwsArgumentError);
    });

    test('rejects malformed species/background/alignment', () {
      expect(
          () => Character(
                id: 'x',
                name: 'X',
                classLevels: [
                  CharacterClassLevel(classId: 'srd:wizard', level: 1)
                ],
                speciesId: 'human',
                backgroundId: 'srd:sage',
                alignmentId: 'srd:neutral',
                abilities: _stdAbilities(),
                hp: HitPoints(current: 1, max: 1),
              ),
          throwsArgumentError);
    });

    test('defaults empty containers', () {
      final c = _build();
      expect(c.featIds, isEmpty);
      expect(c.languageIds, isEmpty);
      expect(c.activeConditionIds, isEmpty);
      expect(c.hasInspiration, isFalse);
    });
  });

  group('derived getters', () {
    test('totalLevel sums classLevels', () {
      final c = _build(classLevels: [
        CharacterClassLevel(classId: 'srd:wizard', level: 3),
        CharacterClassLevel(classId: 'srd:cleric', level: 2),
      ]);
      expect(c.totalLevel, 5);
    });

    test('proficiencyBonus at level 5 = 3', () {
      final c = _build(classLevels: [
        CharacterClassLevel(classId: 'srd:wizard', level: 5)
      ]);
      expect(c.proficiencyBonus, 3);
    });

    test('initiativeMod = DEX mod without Alert', () {
      final c = _build();
      expect(c.initiativeMod, 2); // DEX 14 → +2
    });

    test('initiativeMod adds PB when Alert feat', () {
      final c = _build(
        proficiencies: ProficiencySet(alertFeat: true),
      );
      expect(c.initiativeMod, 2 + 2); // PB at L1 = 2
    });

    test('passive perception applies proficiency when present', () {
      final c = _build(
        proficiencies: ProficiencySet(
          skills: {'srd:perception': Proficiency.full},
        ),
      );
      // 10 + WIS(+2) + PB(2) = 14
      expect(c.passivePerception, 14);
    });

    test('passive perception without perception prof = 10 + WIS mod', () {
      final c = _build();
      expect(c.passivePerception, 12);
    });
  });

  test('equality by id', () {
    final a = _build();
    final b = _build();
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
