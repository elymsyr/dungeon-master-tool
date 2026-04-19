import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbilityScore', () {
    test('accepts 1..30', () {
      expect(AbilityScore(1).value, 1);
      expect(AbilityScore(30).value, 30);
    });

    test('rejects out-of-range', () {
      expect(() => AbilityScore(0), throwsArgumentError);
      expect(() => AbilityScore(31), throwsArgumentError);
      expect(() => AbilityScore(-5), throwsArgumentError);
    });

    test('modifier matches SRD table', () {
      expect(AbilityScore(1).modifier, -5);
      expect(AbilityScore(3).modifier, -4);
      expect(AbilityScore(8).modifier, -1);
      expect(AbilityScore(9).modifier, -1);
      expect(AbilityScore(10).modifier, 0);
      expect(AbilityScore(11).modifier, 0);
      expect(AbilityScore(12).modifier, 1);
      expect(AbilityScore(15).modifier, 2);
      expect(AbilityScore(20).modifier, 5);
      expect(AbilityScore(30).modifier, 10);
    });

    test('== by value', () {
      expect(AbilityScore(15), equals(AbilityScore(15)));
      expect(AbilityScore(15).hashCode, AbilityScore(15).hashCode);
      expect(AbilityScore(15) == AbilityScore(16), isFalse);
    });
  });
}
