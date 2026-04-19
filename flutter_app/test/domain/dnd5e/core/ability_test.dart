import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ability', () {
    test('short codes match SRD', () {
      expect(Ability.strength.short, 'STR');
      expect(Ability.dexterity.short, 'DEX');
      expect(Ability.constitution.short, 'CON');
      expect(Ability.intelligence.short, 'INT');
      expect(Ability.wisdom.short, 'WIS');
      expect(Ability.charisma.short, 'CHA');
    });

    test('fromShort round-trips', () {
      for (final a in Ability.values) {
        expect(Ability.fromShort(a.short), a);
      }
    });

    test('fromShort accepts lowercase', () {
      expect(Ability.fromShort('str'), Ability.strength);
    });

    test('fromShort rejects unknown', () {
      expect(() => Ability.fromShort('XXX'), throwsArgumentError);
    });
  });
}
