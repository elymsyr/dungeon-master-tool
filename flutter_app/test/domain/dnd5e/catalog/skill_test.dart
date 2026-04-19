import 'package:dungeon_master_tool/domain/dnd5e/catalog/skill.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skill', () {
    test('stores governing ability', () {
      final s = Skill(
          id: 'srd:athletics', name: 'Athletics', ability: Ability.strength);
      expect(s.ability, Ability.strength);
    });

    test('rejects empty name', () {
      expect(
          () => Skill(id: 'srd:x', name: '', ability: Ability.strength),
          throwsArgumentError);
    });

    test('rejects bad id', () {
      expect(
          () => Skill(id: 'athletics', name: 'x', ability: Ability.strength),
          throwsArgumentError);
    });

    test('copyWith retains ability', () {
      final s = Skill(
          id: 'srd:x', name: 'X', ability: Ability.wisdom);
      expect(s.copyWith(name: 'Y').ability, Ability.wisdom);
    });
  });
}
