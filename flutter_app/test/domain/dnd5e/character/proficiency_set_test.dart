import 'package:dungeon_master_tool/domain/dnd5e/character/proficiency_set.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProficiencySet', () {
    test('empty returns none for every query', () {
      final p = ProficiencySet.empty();
      expect(p.saveLevel(Ability.strength), Proficiency.none);
      expect(p.skillLevel('srd:athletics'), Proficiency.none);
    });

    test('invalid skill id rejected', () {
      expect(
          () => ProficiencySet(skills: {'athletics': Proficiency.full}),
          throwsArgumentError);
    });

    test('stores alert feat flag', () {
      final p = ProficiencySet(alertFeat: true);
      expect(p.alertFeat, isTrue);
    });

    test('saveLevel reads map', () {
      final p = ProficiencySet(saves: {Ability.wisdom: Proficiency.expertise});
      expect(p.saveLevel(Ability.wisdom), Proficiency.expertise);
    });
  });
}
