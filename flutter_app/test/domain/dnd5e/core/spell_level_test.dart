import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpellLevel', () {
    test('0..9 ok', () {
      for (var i = 0; i <= 9; i++) {
        expect(SpellLevel(i).value, i);
      }
    });

    test('rejects out of range', () {
      expect(() => SpellLevel(-1), throwsArgumentError);
      expect(() => SpellLevel(10), throwsArgumentError);
    });

    test('cantrip detection', () {
      expect(SpellLevel.cantrip.isCantrip, isTrue);
      expect(SpellLevel(0).isCantrip, isTrue);
      expect(SpellLevel(1).isCantrip, isFalse);
    });

    test('equality', () {
      expect(SpellLevel(3) == SpellLevel(3), isTrue);
      expect(SpellLevel(3) == SpellLevel(4), isFalse);
    });
  });
}
