import 'package:dungeon_master_tool/core/utils/parse_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseIsoOrNull', () {
    test('returns DateTime for valid ISO-8601 string', () {
      final result = parseIsoOrNull('2026-04-17T10:30:00Z');
      expect(result, isNotNull);
      expect(result!.toUtc().hour, 10);
    });

    test('returns null for null input', () {
      expect(parseIsoOrNull(null), isNull);
    });

    test('returns null for non-string input', () {
      expect(parseIsoOrNull(42), isNull);
      expect(parseIsoOrNull(const {}), isNull);
    });

    test('returns null for empty string', () {
      expect(parseIsoOrNull(''), isNull);
    });

    test('returns null for unparseable strings', () {
      expect(parseIsoOrNull('not-a-date'), isNull);
      expect(parseIsoOrNull('banana'), isNull);
    });
  });

  group('parseIsoOrNow', () {
    test('returns DateTime for valid ISO-8601 string', () {
      final result = parseIsoOrNow('2026-04-17T10:30:00Z');
      expect(result.toUtc().hour, 10);
    });

    test('falls back to now() for null', () {
      final before = DateTime.now();
      final result = parseIsoOrNow(null);
      final after = DateTime.now();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))) &&
            result.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('falls back to now() for malformed input', () {
      final result = parseIsoOrNow('garbage');
      expect(result, isA<DateTime>());
    });
  });
}
