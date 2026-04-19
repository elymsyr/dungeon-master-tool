import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/item/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RangePair', () {
    test('long >= normal', () {
      expect(() => RangePair(normal: 30, long: 20), throwsArgumentError);
      expect(RangePair(normal: 30, long: 120).long, 120);
    });
    test('normal > 0', () {
      expect(() => RangePair(normal: 0, long: 0), throwsArgumentError);
    });
  });

  group('Weapon', () {
    test('ranged weapon requires range', () {
      expect(
          () => Weapon(
                id: 'srd:shortbow',
                name: 'Shortbow',
                rarityId: 'srd:common',
                category: WeaponCategory.simple,
                type: WeaponType.ranged,
                damage: DiceExpression.parse('1d6'),
                damageTypeId: 'srd:piercing',
              ),
          throwsArgumentError);
    });

    test('melee weapon may omit range', () {
      final w = Weapon(
        id: 'srd:longsword',
        name: 'Longsword',
        rarityId: 'srd:common',
        category: WeaponCategory.martial,
        type: WeaponType.melee,
        damage: DiceExpression.parse('1d8'),
        damageTypeId: 'srd:slashing',
      );
      expect(w.range, isNull);
    });

    test('validates damage type id', () {
      expect(
          () => Weapon(
                id: 'srd:x',
                name: 'X',
                rarityId: 'srd:common',
                category: WeaponCategory.simple,
                type: WeaponType.melee,
                damage: DiceExpression.parse('1d4'),
                damageTypeId: 'slashing',
              ),
          throwsArgumentError);
    });
  });

  group('Armor', () {
    test('baseAc >= 10', () {
      expect(
          () => Armor(
                id: 'srd:rags',
                name: 'Rags',
                rarityId: 'srd:common',
                categoryId: 'srd:light',
                baseAc: 9,
              ),
          throwsArgumentError);
    });
    test('strengthRequirement in [1, 30]', () {
      expect(
          () => Armor(
                id: 'srd:plate',
                name: 'Plate',
                rarityId: 'srd:common',
                categoryId: 'srd:heavy',
                baseAc: 18,
                strengthRequirement: 0,
              ),
          throwsArgumentError);
    });
  });

  group('MagicItem', () {
    test('attunementPrereq requires requiresAttunement', () {
      expect(
          () => MagicItem(
                id: 'srd:holy_avenger',
                name: 'Holy Avenger',
                rarityId: 'srd:legendary',
                attunementPrereq: const AttunementByClass('srd:paladin'),
              ),
          throwsArgumentError);
    });

    test('validates baseItemId when given', () {
      expect(
          () => MagicItem(
                id: 'srd:plate_plus_one',
                name: '+1 Plate',
                rarityId: 'srd:rare',
                baseItemId: 'plate',
              ),
          throwsArgumentError);
    });
  });

  test('Ammunition.quantityPerStack > 0', () {
    expect(
        () => Ammunition(
              id: 'srd:arrows',
              name: 'Arrows',
              rarityId: 'srd:common',
              quantityPerStack: 0,
            ),
        throwsArgumentError);
  });
}
