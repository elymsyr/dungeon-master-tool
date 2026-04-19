import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/area_of_effect.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/casting_time.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_components.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_range.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ctx = 'srd:test';

  group('CastingTime codec', () {
    test('ActionCast / BonusActionCast round-trip', () {
      expect(decodeCastingTime(encodeCastingTime(const ActionCast()), ctx),
          const ActionCast());
      expect(
          decodeCastingTime(encodeCastingTime(const BonusActionCast()), ctx),
          const BonusActionCast());
    });

    test('ReactionCast carries trigger', () {
      final c = const ReactionCast('when an ally is hit');
      final back = decodeCastingTime(encodeCastingTime(c), ctx) as ReactionCast;
      expect(back.trigger, 'when an ally is hit');
    });

    test('MinutesCast + HoursCast round-trip', () {
      expect(decodeCastingTime(encodeCastingTime(MinutesCast(10)), ctx),
          MinutesCast(10));
      expect(decodeCastingTime(encodeCastingTime(HoursCast(8)), ctx),
          HoursCast(8));
    });

    test('unknown tag rejected', () {
      expect(() => decodeCastingTime({'t': 'bogus'}, ctx),
          throwsFormatException);
    });
  });

  group('SpellRange codec', () {
    test('all variants round-trip', () {
      expect(decodeSpellRange(encodeSpellRange(const SelfRange()), ctx),
          const SelfRange());
      expect(decodeSpellRange(encodeSpellRange(const TouchRange()), ctx),
          const TouchRange());
      expect(decodeSpellRange(encodeSpellRange(FeetRange(60)), ctx),
          FeetRange(60));
      expect(decodeSpellRange(encodeSpellRange(MilesRange(1)), ctx),
          MilesRange(1));
      expect(decodeSpellRange(encodeSpellRange(const SightRange()), ctx),
          const SightRange());
      expect(
          decodeSpellRange(encodeSpellRange(const UnlimitedRange()), ctx),
          const UnlimitedRange());
    });

    test('rejects unknown tag', () {
      expect(() => decodeSpellRange({'t': 'bogus'}, ctx),
          throwsFormatException);
    });

    test('FeetRange accepts int in numeric field', () {
      final r = decodeSpellRange({'t': 'feet', 'feet': 30}, ctx) as FeetRange;
      expect(r.feet, 30.0);
    });
  });

  group('AreaOfEffect codec', () {
    test('Sphere', () {
      final a = SphereAoE(20);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('Cone', () {
      final a = ConeAoE(15);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('Cube', () {
      final a = CubeAoE(10);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('Cylinder radius + height', () {
      final a = CylinderAoE(radiusFt: 10, heightFt: 40);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('Emanation', () {
      final a = EmanationAoE(5);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('Line length + width', () {
      final a = LineAoE(lengthFt: 60, widthFt: 5);
      expect(decodeAreaOfEffect(encodeAreaOfEffect(a), ctx), a);
    });

    test('rejects unknown tag', () {
      expect(() => decodeAreaOfEffect({'t': 'blob'}, ctx),
          throwsFormatException);
    });
  });

  group('SpellDuration codec', () {
    test('Instantaneous', () {
      expect(
          decodeSpellDuration(
              encodeSpellDuration(const SpellInstantaneous()), ctx),
          const SpellInstantaneous());
    });

    test('Rounds with concentration elided when false', () {
      final encoded = encodeSpellDuration(SpellRounds(rounds: 10));
      expect(encoded.containsKey('concentration'), false);
      final back = decodeSpellDuration(encoded, ctx) as SpellRounds;
      expect(back.rounds, 10);
      expect(back.concentration, false);
    });

    test('Minutes with concentration', () {
      final d = SpellMinutes(minutes: 1, concentration: true);
      final back = decodeSpellDuration(encodeSpellDuration(d), ctx)
          as SpellMinutes;
      expect(back.minutes, 1);
      expect(back.concentration, true);
    });

    test('Hours with concentration', () {
      final d = SpellHours(hours: 8, concentration: true);
      final back =
          decodeSpellDuration(encodeSpellDuration(d), ctx) as SpellHours;
      expect(back.hours, 8);
      expect(back.concentration, true);
    });

    test('Days', () {
      expect(decodeSpellDuration(encodeSpellDuration(SpellDays(7)), ctx),
          SpellDays(7));
    });

    test('UntilDispelled', () {
      expect(
          decodeSpellDuration(
              encodeSpellDuration(const SpellUntilDispelled()), ctx),
          const SpellUntilDispelled());
    });

    test('Special carries description', () {
      final d = const SpellSpecial('until the next dawn');
      final back =
          decodeSpellDuration(encodeSpellDuration(d), ctx) as SpellSpecial;
      expect(back.description, 'until the next dawn');
    });

    test('rejects unknown tag', () {
      expect(() => decodeSpellDuration({'t': 'forever'}, ctx),
          throwsFormatException);
    });
  });

  group('SpellComponent codec', () {
    test('V + S singletons round-trip', () {
      expect(decodeSpellComponent(encodeSpellComponent(const VerbalComponent()),
          ctx), const VerbalComponent());
      expect(
          decodeSpellComponent(
              encodeSpellComponent(const SomaticComponent()), ctx),
          const SomaticComponent());
    });

    test('Material with cost + consumed', () {
      final m = MaterialComponent(
          description: 'a diamond worth 500 gp',
          costCp: 50000,
          consumed: true);
      final back = decodeSpellComponent(encodeSpellComponent(m), ctx)
          as MaterialComponent;
      expect(back.description, 'a diamond worth 500 gp');
      expect(back.costCp, 50000);
      expect(back.consumed, true);
    });

    test('Material minimal', () {
      final m = MaterialComponent(description: 'a pinch of soot');
      final encoded = encodeSpellComponent(m);
      expect(encoded.containsKey('costCp'), false);
      expect(encoded.containsKey('consumed'), false);
      final back =
          decodeSpellComponent(encoded, ctx) as MaterialComponent;
      expect(back.costCp, isNull);
      expect(back.consumed, false);
    });

    test('rejects unknown tag', () {
      expect(() => decodeSpellComponent({'t': 'x'}, ctx),
          throwsFormatException);
    });
  });

  group('Spell top-level codec', () {
    test('minimal spell round-trips', () {
      final s = Spell(
        id: 'srd:magic-missile',
        name: 'Magic Missile',
        level: SpellLevel(1),
        schoolId: 'srd:evocation',
        castingTime: const ActionCast(),
        range: FeetRange(120),
        components: const [VerbalComponent(), SomaticComponent()],
        duration: const SpellInstantaneous(),
      );
      final back = spellFromEntry(spellToEntry(s));
      expect(back.id, s.id);
      expect(back.name, s.name);
      expect(back.level.value, 1);
      expect(back.schoolId, 'srd:evocation');
      expect(back.castingTime, const ActionCast());
      expect(back.range, FeetRange(120));
      expect(back.components,
          const [VerbalComponent(), SomaticComponent()]);
      expect(back.duration, const SpellInstantaneous());
      expect(back.area, isNull);
      expect(back.effects, isEmpty);
      expect(back.ritual, false);
      expect(back.classListIds, isEmpty);
      expect(back.description, '');
    });

    test('full fireball round-trips', () {
      final s = Spell(
        id: 'srd:fireball',
        name: 'Fireball',
        level: SpellLevel(3),
        schoolId: 'srd:evocation',
        castingTime: const ActionCast(),
        range: FeetRange(150),
        components: [
          const VerbalComponent(),
          const SomaticComponent(),
          MaterialComponent(description: 'a tiny ball of bat guano and sulfur'),
        ],
        duration: const SpellInstantaneous(),
        targets: const [SpellTarget.aoeOriginPoint],
        area: SphereAoE(20),
        effects: [
          GrantCondition(
            conditionId: 'srd:prone',
            duration: const UntilRemoved(),
            saveToResist: SaveSpec(ability: Ability.dexterity, dc: 15),
          ),
        ],
        classListIds: const ['srd:wizard', 'srd:sorcerer'],
        description: 'A bright streak flashes...',
      );
      final back = spellFromEntry(spellToEntry(s));
      expect(back.level.value, 3);
      expect(back.area, SphereAoE(20));
      expect(back.targets, [SpellTarget.aoeOriginPoint]);
      expect(back.components, hasLength(3));
      expect(back.components.last, isA<MaterialComponent>());
      expect(back.effects, hasLength(1));
      expect(back.effects.first, isA<GrantCondition>());
      expect(back.classListIds, ['srd:wizard', 'srd:sorcerer']);
      expect(back.description, 'A bright streak flashes...');
    });

    test('ritual spell + concentration duration', () {
      final s = Spell(
        id: 'srd:detect-magic',
        name: 'Detect Magic',
        level: SpellLevel(1),
        schoolId: 'srd:divination',
        castingTime: const ActionCast(),
        range: const SelfRange(),
        components: const [VerbalComponent(), SomaticComponent()],
        duration: SpellMinutes(minutes: 10, concentration: true),
        ritual: true,
      );
      final back = spellFromEntry(spellToEntry(s));
      expect(back.ritual, true);
      final dur = back.duration as SpellMinutes;
      expect(dur.concentration, true);
      expect(dur.minutes, 10);
    });

    test('rejects unknown target enum', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"level":0,"schoolId":"srd:x","castingTime":{"t":"action"},"range":{"t":"self"},"components":[],"duration":{"t":"instantaneous"},"targets":["bogusTarget"]}',
      );
      expect(() => spellFromEntry(e), throwsFormatException);
    });

    test('rejects non-object casting time', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"level":0,"schoolId":"srd:x","castingTime":"nope","range":{"t":"self"},"components":[],"duration":{"t":"instantaneous"}}',
      );
      expect(() => spellFromEntry(e), throwsFormatException);
    });

    test('rejects missing required field', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{"level":0}',
      );
      expect(() => spellFromEntry(e), throwsFormatException);
    });

    test('spell effects use nested EffectDescriptor codec', () {
      final s = Spell(
        id: 'srd:cure-wounds',
        name: 'Cure Wounds',
        level: SpellLevel(1),
        schoolId: 'srd:abjuration',
        castingTime: const ActionCast(),
        range: const TouchRange(),
        components: const [VerbalComponent(), SomaticComponent()],
        duration: const SpellInstantaneous(),
        effects: [Heal(dice: DiceExpression.parse('2d8'), flatBonus: 0)],
      );
      final back = spellFromEntry(spellToEntry(s));
      expect(back.effects.single, isA<Heal>());
      final h = back.effects.single as Heal;
      expect(h.dice, DiceExpression.parse('2d8'));
    });
  });
}
