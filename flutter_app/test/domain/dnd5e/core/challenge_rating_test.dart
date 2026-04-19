import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChallengeRating.parse', () {
    test('fractional CRs', () {
      for (final s in ['0', '1/8', '1/4', '1/2']) {
        expect(ChallengeRating.parse(s).canonical, s);
      }
    });
    test('integer CRs 1..30', () {
      for (var i = 1; i <= 30; i++) {
        expect(ChallengeRating.parse('$i').canonical, '$i');
      }
    });
    test('rejects garbage', () {
      expect(() => ChallengeRating.parse('31'), throwsArgumentError);
      expect(() => ChallengeRating.parse('1/3'), throwsArgumentError);
      expect(() => ChallengeRating.parse('banana'), throwsArgumentError);
    });
  });

  group('ChallengeRating.fromDouble', () {
    test('fractional', () {
      expect(ChallengeRating.fromDouble(0).canonical, '0');
      expect(ChallengeRating.fromDouble(0.125).canonical, '1/8');
      expect(ChallengeRating.fromDouble(0.25).canonical, '1/4');
      expect(ChallengeRating.fromDouble(0.5).canonical, '1/2');
    });
    test('integer', () {
      expect(ChallengeRating.fromDouble(5).canonical, '5');
      expect(ChallengeRating.fromDouble(30).canonical, '30');
    });
    test('rejects non-canonical', () {
      expect(() => ChallengeRating.fromDouble(0.375), throwsArgumentError);
    });
  });

  test('toDouble round-trips', () {
    expect(ChallengeRating.parse('1/4').toDouble(), 0.25);
    expect(ChallengeRating.parse('5').toDouble(), 5);
  });

  group('XP table', () {
    test('spot checks', () {
      expect(ChallengeRating.parse('0').xp, 10);
      expect(ChallengeRating.parse('1/4').xp, 50);
      expect(ChallengeRating.parse('1').xp, 200);
      expect(ChallengeRating.parse('10').xp, 5900);
      expect(ChallengeRating.parse('20').xp, 25000);
      expect(ChallengeRating.parse('30').xp, 155000);
    });
  });
}
