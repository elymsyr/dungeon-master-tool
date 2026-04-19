import 'package:dungeon_master_tool/domain/dnd5e/effect/duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EffectDuration', () {
    test('Instantaneous and UntilRemoved are value-equal singletons', () {
      expect(const Instantaneous(), const Instantaneous());
      expect(const UntilRemoved(), const UntilRemoved());
    });

    test('RoundsDuration positive invariant', () {
      expect(() => RoundsDuration(0), throwsArgumentError);
      expect(() => RoundsDuration(-1), throwsArgumentError);
      expect(RoundsDuration(3).rounds, 3);
    });

    test('MinutesDuration positive invariant', () {
      expect(() => MinutesDuration(0), throwsArgumentError);
      expect(MinutesDuration(10).minutes, 10);
    });

    test('UntilRest remembers rest kind', () {
      expect(const UntilRest(RestKind.longRest).kind, RestKind.longRest);
      expect(const UntilRest(RestKind.shortRest),
          const UntilRest(RestKind.shortRest));
    });

    test('ConcentrationDuration wraps inner duration', () {
      final c = ConcentrationDuration(MinutesDuration(10));
      expect(c.max, MinutesDuration(10));
      expect(c, ConcentrationDuration(MinutesDuration(10)));
    });

    test('different rounds are not equal', () {
      expect(RoundsDuration(2) == RoundsDuration(3), isFalse);
    });
  });
}
