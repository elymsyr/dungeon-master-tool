import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DamageInstance', () {
    test('defaults cover common path', () {
      final d = DamageInstance(amount: 8, typeId: 'srd:fire');
      expect(d.amount, 8);
      expect(d.typeId, 'srd:fire');
      expect(d.isCritical, false);
      expect(d.fromSavedThrow, false);
    });

    test('rejects negative amount', () {
      expect(
        () => DamageInstance(amount: -1, typeId: 'srd:fire'),
        throwsArgumentError,
      );
    });

    test('rejects non-namespaced type id', () {
      expect(
        () => DamageInstance(amount: 1, typeId: 'fire'),
        throwsArgumentError,
      );
    });

    test('savedSucceeded requires fromSavedThrow', () {
      expect(
        () => DamageInstance(
          amount: 8,
          typeId: 'srd:fire',
          fromSavedThrow: false,
          savedSucceeded: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
