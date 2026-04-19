import 'package:dungeon_master_tool/application/dnd5e/combat/typed_damage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypedDamage', () {
    test('sums types for totalPreMitigation', () {
      final d = TypedDamage(byType: const {
        'srd:slashing': 7,
        'srd:fire': 4,
      });
      expect(d.totalPreMitigation, 11);
    });

    test('rejects empty byType', () {
      expect(
        () => TypedDamage(byType: const {}),
        throwsArgumentError,
      );
    });

    test('rejects negative amount', () {
      expect(
        () => TypedDamage(byType: const {'srd:fire': -1}),
        throwsArgumentError,
      );
    });

    test('rejects non-namespaced type id', () {
      expect(
        () => TypedDamage(byType: const {'fire': 4}),
        throwsArgumentError,
      );
    });

    test('savedSucceeded requires fromSavedThrow', () {
      expect(
        () => TypedDamage(
          byType: const {'srd:fire': 8},
          savedSucceeded: true,
        ),
        throwsArgumentError,
      );
    });

    test('byType is unmodifiable', () {
      final d = TypedDamage(byType: const {'srd:fire': 4});
      expect(() => d.byType['srd:cold'] = 1, throwsUnsupportedError);
    });
  });
}
