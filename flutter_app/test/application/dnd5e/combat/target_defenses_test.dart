import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetDefenses', () {
    test('defaults produce an empty-set PC shell', () {
      final t = TargetDefenses(currentHp: 10, maxHp: 10);
      expect(t.tempHp, 0);
      expect(t.resistances, isEmpty);
      expect(t.isPlayer, false);
    });

    test('rejects bad HP ranges', () {
      expect(() => TargetDefenses(currentHp: 0, maxHp: 0),
          throwsArgumentError);
      expect(() => TargetDefenses(currentHp: 11, maxHp: 10),
          throwsArgumentError);
      expect(() => TargetDefenses(currentHp: -1, maxHp: 10),
          throwsArgumentError);
    });

    test('rejects negative tempHp', () {
      expect(
        () => TargetDefenses(currentHp: 10, maxHp: 10, tempHp: -1),
        throwsArgumentError,
      );
    });

    test('rejects non-namespaced damage-type ids', () {
      expect(
        () => TargetDefenses(
          currentHp: 10,
          maxHp: 10,
          resistances: const {'fire'},
        ),
        throwsArgumentError,
      );
    });

    test('collections are unmodifiable', () {
      final t = TargetDefenses(
        currentHp: 10,
        maxHp: 10,
        resistances: const {'srd:fire'},
      );
      expect(() => t.resistances.add('srd:cold'), throwsUnsupportedError);
    });
  });
}
