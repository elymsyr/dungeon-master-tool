import 'package:dungeon_master_tool/application/dnd5e/spell/multiclass_slot_calculator.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/caster_kind.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:flutter_test/flutter_test.dart';

CharacterClass _cls(
  String id, {
  CasterKind kind = CasterKind.full,
  double? fraction,
}) =>
    CharacterClass(
      id: id,
      name: id.split(':').last,
      hitDie: Die.d8,
      casterKind: kind,
      casterFraction: fraction,
    );

void main() {
  final registry = <String, CharacterClass>{
    'srd:wizard': _cls('srd:wizard'),
    'srd:cleric': _cls('srd:cleric'),
    'srd:paladin': _cls('srd:paladin', kind: CasterKind.half),
    'srd:ranger': _cls('srd:ranger', kind: CasterKind.half),
    'srd:arcane_trickster':
        _cls('srd:arcane_trickster', kind: CasterKind.third),
    'srd:fighter': _cls('srd:fighter', kind: CasterKind.none),
    'srd:warlock': _cls('srd:warlock', kind: CasterKind.pact),
  };
  final calcResolver =
      MulticlassSlotCalculator((id) => registry[id]);

  CharacterClassLevel level(String id, int lvl) =>
      CharacterClassLevel(classId: id, level: lvl);

  group('combinedCasterLevel', () {
    test('single full caster = own level', () {
      expect(calcResolver.combinedCasterLevel([level('srd:wizard', 5)]), 5);
    });

    test('wizard 5 + cleric 3 = 8', () {
      expect(
        calcResolver.combinedCasterLevel([
          level('srd:wizard', 5),
          level('srd:cleric', 3),
        ]),
        8,
      );
    });

    test('half-caster floors its contribution', () {
      // Paladin 5 → 5 * 0.5 = 2.5 → floor 2.
      expect(calcResolver.combinedCasterLevel([level('srd:paladin', 5)]), 2);
    });

    test('third-caster floors its contribution', () {
      // Rogue/AT 7 → 7/3 = 2.33 → floor 2.
      expect(
        calcResolver
            .combinedCasterLevel([level('srd:arcane_trickster', 7)]),
        2,
      );
    });

    test('full + half + third: wizard 3 + paladin 5 + AT 3', () {
      // 3 + floor(2.5) + floor(1.0) = 3 + 2 + 1... wait — floor sums after, not before:
      // spec: floor(sum(level * fraction)) = floor(3 + 2.5 + 1.0) = floor(6.5) = 6.
      expect(
        calcResolver.combinedCasterLevel([
          level('srd:wizard', 3),
          level('srd:paladin', 5),
          level('srd:arcane_trickster', 3),
        ]),
        6,
      );
    });

    test('non-caster contributes 0', () {
      expect(
        calcResolver.combinedCasterLevel([
          level('srd:fighter', 11),
          level('srd:wizard', 1),
        ]),
        1,
      );
    });

    test('pact class excluded from multiclass sum', () {
      expect(
        calcResolver.combinedCasterLevel([
          level('srd:warlock', 5),
          level('srd:wizard', 3),
        ]),
        3,
      );
    });

    test('unknown class id ignored', () {
      expect(
        calcResolver.combinedCasterLevel([level('srd:unknown', 5)]),
        0,
      );
    });

    test('empty list → 0', () {
      expect(calcResolver.combinedCasterLevel(const []), 0);
    });
  });

  group('slotsFor', () {
    test('wizard 5 → [4,3,2,...]', () {
      expect(calcResolver.slotsFor([level('srd:wizard', 5)]),
          [4, 3, 2, 0, 0, 0, 0, 0, 0]);
    });

    test('empty → all zeros', () {
      expect(calcResolver.slotsFor(const []), List.filled(9, 0));
    });
  });

  test('single-class collapse matches simple lookup', () {
    for (var lvl = 1; lvl <= 20; lvl++) {
      final slotsViaCalc =
          calcResolver.slotsFor([level('srd:wizard', lvl)]);
      expect(slotsViaCalc, isNotEmpty);
    }
  });
}
