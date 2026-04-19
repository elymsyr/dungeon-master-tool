import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_dc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConcentrationDc', () {
    test('low damage floors at 10', () {
      expect(ConcentrationDc.forDamage(0), 10);
      expect(ConcentrationDc.forDamage(1), 10);
      expect(ConcentrationDc.forDamage(19), 10);
    });

    test('half-damage formula for mid range', () {
      expect(ConcentrationDc.forDamage(20), 10);
      expect(ConcentrationDc.forDamage(21), 10);
      expect(ConcentrationDc.forDamage(30), 15);
      expect(ConcentrationDc.forDamage(44), 22);
    });

    test('caps at 30', () {
      expect(ConcentrationDc.forDamage(60), 30);
      expect(ConcentrationDc.forDamage(1000), 30);
    });

    test('rejects negative damage', () {
      expect(() => ConcentrationDc.forDamage(-1), throwsArgumentError);
    });
  });
}
