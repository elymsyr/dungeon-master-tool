import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency_bonus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Proficiency.applyTo', () {
    test('none = 0', () {
      expect(Proficiency.none.applyTo(5), 0);
    });
    test('half = floor(PB/2)', () {
      expect(Proficiency.half.applyTo(2), 1);
      expect(Proficiency.half.applyTo(3), 1);
      expect(Proficiency.half.applyTo(5), 2);
    });
    test('full = PB', () {
      expect(Proficiency.full.applyTo(4), 4);
    });
    test('expertise = 2*PB', () {
      expect(Proficiency.expertise.applyTo(3), 6);
    });
  });

  group('ProficiencyBonus.forLevel', () {
    test('SRD table', () {
      expect(ProficiencyBonus.forLevel(1), 2);
      expect(ProficiencyBonus.forLevel(4), 2);
      expect(ProficiencyBonus.forLevel(5), 3);
      expect(ProficiencyBonus.forLevel(8), 3);
      expect(ProficiencyBonus.forLevel(9), 4);
      expect(ProficiencyBonus.forLevel(12), 4);
      expect(ProficiencyBonus.forLevel(13), 5);
      expect(ProficiencyBonus.forLevel(16), 5);
      expect(ProficiencyBonus.forLevel(17), 6);
      expect(ProficiencyBonus.forLevel(20), 6);
    });
    test('rejects out of range', () {
      expect(() => ProficiencyBonus.forLevel(0), throwsArgumentError);
      expect(() => ProficiencyBonus.forLevel(21), throwsArgumentError);
    });
  });

  group('ProficiencyBonus.forChallengeRating', () {
    test('CR bands', () {
      expect(ProficiencyBonus.forChallengeRating(0), 2);
      expect(ProficiencyBonus.forChallengeRating(4), 2);
      expect(ProficiencyBonus.forChallengeRating(5), 3);
      expect(ProficiencyBonus.forChallengeRating(12), 4);
      expect(ProficiencyBonus.forChallengeRating(20), 6);
      expect(ProficiencyBonus.forChallengeRating(24), 7);
      expect(ProficiencyBonus.forChallengeRating(30), 9);
    });
  });
}
