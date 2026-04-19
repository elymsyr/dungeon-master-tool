import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbilityScores', () {
    test('allTens baseline', () {
      final s = AbilityScores.allTens();
      for (final a in Ability.values) {
        expect(s.byAbility(a).value, 10);
      }
    });

    test('byAbility dispatches', () {
      final s = AbilityScores(
        str: AbilityScore(18),
        dex: AbilityScore(14),
        con: AbilityScore(13),
        int_: AbilityScore(10),
        wis: AbilityScore(12),
        cha: AbilityScore(8),
      );
      expect(s.byAbility(Ability.strength).value, 18);
      expect(s.byAbility(Ability.charisma).value, 8);
    });

    test('withBonus returns new instance clamped', () {
      final s = AbilityScores.allTens();
      final buffed = s.withBonus(Ability.strength, 5);
      expect(buffed.str.value, 15);
      expect(s.str.value, 10, reason: 'original unchanged');
      expect(s.withBonus(Ability.strength, 50).str.value, 30);
      expect(s.withBonus(Ability.strength, -50).str.value, 1);
    });

    test('equality is structural', () {
      expect(AbilityScores.allTens() == AbilityScores.allTens(), isTrue);
      expect(AbilityScores.allTens().hashCode,
          AbilityScores.allTens().hashCode);
    });
  });
}
