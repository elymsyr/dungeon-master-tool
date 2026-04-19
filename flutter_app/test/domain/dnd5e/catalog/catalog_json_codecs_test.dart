import 'package:dungeon_master_tool/domain/dnd5e/catalog/alignment.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/armor_category.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/condition.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/creature_type.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/damage_type.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/language.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/rarity.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/size.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/skill.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/spell_school.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_mastery.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property_flag.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Condition codec', () {
    test('round-trips', () {
      final c = Condition(
        id: 'srd:stunned',
        name: 'Stunned',
        description: 'Incapacitated and can\'t move.',
      );
      final back = conditionFromEntry(conditionToEntry(c));
      expect(back, c);
      expect(back.description, c.description);
      expect(back.effects, isEmpty);
    });

    test('missing description decodes as empty', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '{}');
      expect(conditionFromEntry(e).description, '');
    });

    test('rejects non-object body', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '[]');
      expect(() => conditionFromEntry(e), throwsFormatException);
    });

    test('effects round-trip via effect codec', () {
      final c = Condition(
        id: 'srd:prone',
        name: 'Prone',
        effects: [
          ConditionInteraction(
            imposedAdvantageOnAttacksAgainst: true,
            attacksHaveDisadvantage: true,
          ),
        ],
      );
      final back = conditionFromEntry(conditionToEntry(c));
      expect(back.effects, hasLength(1));
      final first = back.effects.single as ConditionInteraction;
      expect(first.imposedAdvantageOnAttacksAgainst, true);
      expect(first.attacksHaveDisadvantage, true);
    });

    test('empty effects omitted from encoded body', () {
      final c = Condition(id: 'srd:x', name: 'X');
      final body = conditionToEntry(c).bodyJson;
      expect(body.contains('effects'), false);
    });

    test('rejects non-array effects field', () {
      final e = CatalogEntry(
          id: 'srd:x', name: 'X', bodyJson: '{"effects":"bogus"}');
      expect(() => conditionFromEntry(e), throwsFormatException);
    });

    test('rejects unknown effect tag in effects list', () {
      final e = CatalogEntry(
          id: 'srd:x',
          name: 'X',
          bodyJson: '{"effects":[{"t":"bogusEffect"}]}');
      expect(() => conditionFromEntry(e), throwsFormatException);
    });
  });

  group('DamageType codec', () {
    test('physical round-trips', () {
      final d = DamageType(id: 'srd:slashing', name: 'Slashing', physical: true);
      final back = damageTypeFromEntry(damageTypeToEntry(d));
      expect(back.physical, true);
    });

    test('defaults physical to false when absent', () {
      final e = CatalogEntry(id: 'srd:fire', name: 'Fire', bodyJson: '{}');
      expect(damageTypeFromEntry(e).physical, false);
    });
  });

  group('Skill codec', () {
    test('round-trips via Ability.name', () {
      final s = Skill(id: 'srd:stealth', name: 'Stealth', ability: Ability.dexterity);
      final entry = skillToEntry(s);
      expect(entry.bodyJson, contains('"dexterity"'));
      expect(skillFromEntry(entry).ability, Ability.dexterity);
    });

    test('rejects unknown ability name', () {
      final e = CatalogEntry(
          id: 'srd:x', name: 'X', bodyJson: '{"ability":"bogus"}');
      expect(() => skillFromEntry(e), throwsFormatException);
    });

    test('rejects missing ability', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '{}');
      expect(() => skillFromEntry(e), throwsFormatException);
    });
  });

  group('Size codec', () {
    test('round-trips doubles', () {
      final s = Size(
          id: 'srd:large', name: 'Large', spaceFt: 10, tokenScale: 2);
      final back = sizeFromEntry(sizeToEntry(s));
      expect(back.spaceFt, 10);
      expect(back.tokenScale, 2);
    });

    test('accepts int in numeric field', () {
      final e = CatalogEntry(
          id: 'srd:med',
          name: 'Medium',
          bodyJson: '{"spaceFt":5,"tokenScale":1}');
      final back = sizeFromEntry(e);
      expect(back.spaceFt, 5.0);
    });
  });

  group('CreatureType codec', () {
    test('round-trips with empty body', () {
      final c = CreatureType(id: 'srd:humanoid', name: 'Humanoid');
      expect(creatureTypeFromEntry(creatureTypeToEntry(c)), c);
    });
  });

  group('Alignment codec', () {
    test('round-trips both axes', () {
      final a = Alignment(
        id: 'srd:lg',
        name: 'Lawful Good',
        lawChaos: LawChaosAxis.lawful,
        goodEvil: GoodEvilAxis.good,
      );
      final back = alignmentFromEntry(alignmentToEntry(a));
      expect(back.lawChaos, LawChaosAxis.lawful);
      expect(back.goodEvil, GoodEvilAxis.good);
    });

    test('rejects unknown axis value', () {
      final e = CatalogEntry(
          id: 'srd:x',
          name: 'X',
          bodyJson: '{"lawChaos":"weird","goodEvil":"good"}');
      expect(() => alignmentFromEntry(e), throwsFormatException);
    });
  });

  group('Language codec', () {
    test('round-trips written language', () {
      final l = Language(id: 'srd:dwarvish', name: 'Dwarvish', script: 'Dethek');
      expect(languageFromEntry(languageToEntry(l)).script, 'Dethek');
    });

    test('round-trips null script', () {
      final l = Language(id: 'srd:druidic', name: 'Druidic');
      expect(languageFromEntry(languageToEntry(l)).script, isNull);
    });
  });

  group('SpellSchool codec', () {
    test('round-trips color', () {
      final s =
          SpellSchool(id: 'srd:evocation', name: 'Evocation', color: '#FF5533');
      expect(spellSchoolFromEntry(spellSchoolToEntry(s)).color, '#FF5533');
    });

    test('color absent decodes as null', () {
      final e =
          CatalogEntry(id: 'srd:abj', name: 'Abjuration', bodyJson: '{}');
      expect(spellSchoolFromEntry(e).color, isNull);
    });
  });

  group('WeaponProperty codec', () {
    test('round-trips flags set', () {
      final w = WeaponProperty(
        id: 'srd:versatile',
        name: 'Versatile',
        flags: {PropertyFlag.versatile},
        description: 'Use one or two hands.',
      );
      final back = weaponPropertyFromEntry(weaponPropertyToEntry(w));
      expect(back.flags, {PropertyFlag.versatile});
      expect(back.description, 'Use one or two hands.');
    });

    test('serializes flags sorted for stable output', () {
      final w = WeaponProperty(
        id: 'srd:x',
        name: 'X',
        flags: {PropertyFlag.thrown, PropertyFlag.finesse, PropertyFlag.light},
      );
      // sorted: finesse, light, thrown
      expect(weaponPropertyToEntry(w).bodyJson,
          contains('["finesse","light","thrown"]'));
    });

    test('rejects non-array flags', () {
      final e = CatalogEntry(
          id: 'srd:x', name: 'X', bodyJson: '{"flags":"finesse"}');
      expect(() => weaponPropertyFromEntry(e), throwsFormatException);
    });

    test('rejects unknown flag', () {
      final e = CatalogEntry(
          id: 'srd:x', name: 'X', bodyJson: '{"flags":["bogus"]}');
      expect(() => weaponPropertyFromEntry(e), throwsFormatException);
    });
  });

  group('WeaponMastery codec', () {
    test('round-trips description', () {
      final w = WeaponMastery(
        id: 'srd:cleave',
        name: 'Cleave',
        description: 'Adjacent creature takes damage.',
      );
      expect(weaponMasteryFromEntry(weaponMasteryToEntry(w)).description,
          'Adjacent creature takes damage.');
    });
  });

  group('ArmorCategory codec', () {
    test('round-trips flags and cap', () {
      final a = ArmorCategory(
        id: 'srd:medium',
        name: 'Medium',
        stealthDisadvantage: true,
        maxDexCap: 2,
      );
      final back = armorCategoryFromEntry(armorCategoryToEntry(a));
      expect(back.stealthDisadvantage, true);
      expect(back.maxDexCap, 2);
    });

    test('null maxDexCap round-trips', () {
      final a =
          ArmorCategory(id: 'srd:light', name: 'Light', stealthDisadvantage: false);
      expect(armorCategoryFromEntry(armorCategoryToEntry(a)).maxDexCap, isNull);
    });
  });

  group('Rarity codec', () {
    test('round-trips order + tier', () {
      final r = Rarity(
        id: 'srd:uncommon',
        name: 'Uncommon',
        sortOrder: 1,
        attunementTierReq: 1,
      );
      final back = rarityFromEntry(rarityToEntry(r));
      expect(back.sortOrder, 1);
      expect(back.attunementTierReq, 1);
    });

    test('rejects missing sortOrder', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '{}');
      expect(() => rarityFromEntry(e), throwsFormatException);
    });
  });

  group('FormatException shape', () {
    test('errors are prefixed with entry id', () {
      final e = CatalogEntry(id: 'srd:broken', name: 'X', bodyJson: '{nope');
      expect(
        () => conditionFromEntry(e),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:broken'))),
      );
    });
  });
}
