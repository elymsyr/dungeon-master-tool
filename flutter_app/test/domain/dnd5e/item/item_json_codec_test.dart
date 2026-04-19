import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/item/item.dart';
import 'package:dungeon_master_tool/domain/dnd5e/item/item_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Weapon codec', () {
    test('melee weapon round-trips full profile', () {
      final w = Weapon(
        id: 'srd:longsword',
        name: 'Longsword',
        weightLb: 3,
        costCp: 1500,
        rarityId: 'srd:common',
        category: WeaponCategory.martial,
        type: WeaponType.melee,
        damage: DiceExpression.parse('1d8'),
        damageTypeId: 'srd:slashing',
        propertyIds: const {'srd:versatile'},
        masteryId: 'srd:sap',
        versatileDamage: DiceExpression.parse('1d10'),
      );
      final back = itemFromEntry(itemToEntry(w)) as Weapon;
      expect(back.category, WeaponCategory.martial);
      expect(back.type, WeaponType.melee);
      expect(back.damage, DiceExpression.parse('1d8'));
      expect(back.damageTypeId, 'srd:slashing');
      expect(back.propertyIds, {'srd:versatile'});
      expect(back.masteryId, 'srd:sap');
      expect(back.versatileDamage, DiceExpression.parse('1d10'));
      expect(back.range, isNull);
      expect(back.weightLb, 3);
      expect(back.costCp, 1500);
    });

    test('ranged weapon carries range', () {
      final w = Weapon(
        id: 'srd:longbow',
        name: 'Longbow',
        weightLb: 2,
        costCp: 5000,
        rarityId: 'srd:common',
        category: WeaponCategory.martial,
        type: WeaponType.ranged,
        damage: DiceExpression.parse('1d8'),
        damageTypeId: 'srd:piercing',
        range: RangePair(normal: 150, long: 600),
      );
      final back = itemFromEntry(itemToEntry(w)) as Weapon;
      expect(back.type, WeaponType.ranged);
      expect(back.range, RangePair(normal: 150, long: 600));
    });

    test('weapon property ids sorted for stable output', () {
      final w = Weapon(
        id: 'srd:rapier',
        name: 'Rapier',
        rarityId: 'srd:common',
        category: WeaponCategory.martial,
        type: WeaponType.melee,
        damage: DiceExpression.parse('1d8'),
        damageTypeId: 'srd:piercing',
        propertyIds: const {'srd:thrown', 'srd:finesse', 'srd:light'},
      );
      final body = itemToEntry(w).bodyJson;
      expect(body.contains('["srd:finesse","srd:light","srd:thrown"]'), true);
    });

    test('defaults elided on encode', () {
      final w = Weapon(
        id: 'srd:club',
        name: 'Club',
        rarityId: 'srd:common',
        category: WeaponCategory.simple,
        type: WeaponType.melee,
        damage: DiceExpression.parse('1d4'),
        damageTypeId: 'srd:bludgeoning',
      );
      final body = itemToEntry(w).bodyJson;
      expect(body.contains('weightLb'), false);
      expect(body.contains('costCp'), false);
      expect(body.contains('propertyIds'), false);
      expect(body.contains('masteryId'), false);
      expect(body.contains('range'), false);
      expect(body.contains('versatileDamage'), false);
    });
  });

  group('Armor codec', () {
    test('round-trips with strength requirement', () {
      final a = Armor(
        id: 'srd:plate',
        name: 'Plate',
        weightLb: 65,
        costCp: 150000,
        rarityId: 'srd:common',
        categoryId: 'srd:heavy',
        baseAc: 18,
        strengthRequirement: 15,
      );
      final back = itemFromEntry(itemToEntry(a)) as Armor;
      expect(back.categoryId, 'srd:heavy');
      expect(back.baseAc, 18);
      expect(back.strengthRequirement, 15);
    });

    test('null strength requirement omits field', () {
      final a = Armor(
        id: 'srd:leather',
        name: 'Leather',
        rarityId: 'srd:common',
        categoryId: 'srd:light',
        baseAc: 11,
      );
      final body = itemToEntry(a).bodyJson;
      expect(body.contains('strengthRequirement'), false);
      final back = itemFromEntry(itemToEntry(a)) as Armor;
      expect(back.strengthRequirement, isNull);
    });
  });

  group('Shield codec', () {
    test('default acBonus=2 elided on encode', () {
      final s = Shield(
        id: 'srd:shield',
        name: 'Shield',
        rarityId: 'srd:common',
      );
      final body = itemToEntry(s).bodyJson;
      expect(body.contains('acBonus'), false);
      final back = itemFromEntry(itemToEntry(s)) as Shield;
      expect(back.acBonus, 2);
    });

    test('non-default acBonus round-trips', () {
      final s = Shield(
        id: 'srd:tower',
        name: 'Tower',
        rarityId: 'srd:rare',
        acBonus: 3,
      );
      final back = itemFromEntry(itemToEntry(s)) as Shield;
      expect(back.acBonus, 3);
    });
  });

  group('Gear codec', () {
    test('description round-trips', () {
      final g = Gear(
        id: 'srd:rope',
        name: 'Rope (50 ft)',
        weightLb: 10,
        costCp: 200,
        rarityId: 'srd:common',
        description: 'Hempen rope',
      );
      final back = itemFromEntry(itemToEntry(g)) as Gear;
      expect(back.description, 'Hempen rope');
    });

    test('empty description omitted', () {
      final g = Gear(
        id: 'srd:torch',
        name: 'Torch',
        rarityId: 'srd:common',
      );
      final body = itemToEntry(g).bodyJson;
      expect(body.contains('description'), false);
    });
  });

  group('Tool codec', () {
    test('proficiencyId round-trips', () {
      final t = Tool(
        id: 'srd:thieves-tools',
        name: "Thieves' Tools",
        rarityId: 'srd:common',
        proficiencyId: 'srd:thieves-tools-prof',
      );
      final back = itemFromEntry(itemToEntry(t)) as Tool;
      expect(back.proficiencyId, 'srd:thieves-tools-prof');
    });
  });

  group('Ammunition codec', () {
    test('default quantityPerStack=1 elided', () {
      final a = Ammunition(
        id: 'srd:arrow',
        name: 'Arrow',
        rarityId: 'srd:common',
      );
      final body = itemToEntry(a).bodyJson;
      expect(body.contains('quantityPerStack'), false);
    });

    test('quantityPerStack>1 round-trips', () {
      final a = Ammunition(
        id: 'srd:arrows-20',
        name: 'Arrows (20)',
        costCp: 100,
        rarityId: 'srd:common',
        quantityPerStack: 20,
      );
      final back = itemFromEntry(itemToEntry(a)) as Ammunition;
      expect(back.quantityPerStack, 20);
    });
  });

  group('MagicItem codec', () {
    test('simple magic item without attunement', () {
      final mi = MagicItem(
        id: 'srd:bag-of-holding',
        name: 'Bag of Holding',
        rarityId: 'srd:uncommon',
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.requiresAttunement, false);
      expect(back.attunementPrereq, isNull);
      expect(back.effects, isEmpty);
    });

    test('attunement by class', () {
      final mi = MagicItem(
        id: 'srd:staff-of-power',
        name: 'Staff of Power',
        rarityId: 'srd:veryRare',
        baseItemId: 'srd:quarterstaff',
        requiresAttunement: true,
        attunementPrereq: const AttunementByClass('srd:wizard'),
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.requiresAttunement, true);
      expect(back.baseItemId, 'srd:quarterstaff');
      expect(back.attunementPrereq, isA<AttunementByClass>());
      expect((back.attunementPrereq as AttunementByClass).classId, 'srd:wizard');
    });

    test('attunement by species', () {
      final mi = MagicItem(
        id: 'srd:dwarven-thrower',
        name: 'Dwarven Thrower',
        rarityId: 'srd:veryRare',
        requiresAttunement: true,
        attunementPrereq: const AttunementBySpecies('srd:dwarf'),
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.attunementPrereq, isA<AttunementBySpecies>());
      expect((back.attunementPrereq as AttunementBySpecies).speciesId,
          'srd:dwarf');
    });

    test('attunement by alignment', () {
      final mi = MagicItem(
        id: 'srd:holy-avenger',
        name: 'Holy Avenger',
        rarityId: 'srd:legendary',
        requiresAttunement: true,
        attunementPrereq: const AttunementByAlignment('srd:lg'),
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.attunementPrereq, isA<AttunementByAlignment>());
      expect((back.attunementPrereq as AttunementByAlignment).alignmentId,
          'srd:lg');
    });

    test('attunement by spellcaster', () {
      final mi = MagicItem(
        id: 'srd:wand-of-wonder',
        name: 'Wand of Wonder',
        rarityId: 'srd:rare',
        requiresAttunement: true,
        attunementPrereq: const AttunementBySpellcaster(),
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.attunementPrereq, isA<AttunementBySpellcaster>());
    });

    test('effects list routes through EffectDescriptor codec', () {
      final mi = MagicItem(
        id: 'srd:ring-of-protection',
        name: 'Ring of Protection',
        rarityId: 'srd:rare',
        requiresAttunement: true,
        effects: [
          const ModifyAc(flat: 1),
          ModifySave(ability: Ability.wisdom, flatBonus: 1),
        ],
      );
      final back = itemFromEntry(itemToEntry(mi)) as MagicItem;
      expect(back.effects, hasLength(2));
      expect(back.effects[0], isA<ModifyAc>());
      expect(back.effects[1], isA<ModifySave>());
    });

    test('rejects unknown attunement prereq tag', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"t":"magicItem","rarityId":"srd:common","requiresAttunement":true,"attunementPrereq":{"t":"bogus"}}',
      );
      expect(() => itemFromEntry(e), throwsFormatException);
    });
  });

  group('Item top-level', () {
    test('rejects unknown item tag', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{"t":"bogus","rarityId":"srd:common"}',
      );
      expect(() => itemFromEntry(e), throwsFormatException);
    });

    test('rejects missing rarityId', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{"t":"gear"}',
      );
      expect(() => itemFromEntry(e), throwsFormatException);
    });

    test('rejects non-object body', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '[]');
      expect(() => itemFromEntry(e), throwsFormatException);
    });

    test('error messages carry entry id prefix', () {
      final e = CatalogEntry(
        id: 'srd:broken',
        name: 'X',
        bodyJson: '{"t":"weapon"}',
      );
      expect(
        () => itemFromEntry(e),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:broken'))),
      );
    });
  });
}

