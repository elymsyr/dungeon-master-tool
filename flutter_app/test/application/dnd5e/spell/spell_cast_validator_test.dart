import 'package:dungeon_master_tool/application/dnd5e/spell/caster_context.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/casting_method.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/spell_cast_validator.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/pact_magic_slots.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/prepared_spells.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/spell_slots.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/casting_time.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_components.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_range.dart';
import 'package:flutter_test/flutter_test.dart';

Spell _spell({
  String id = 'srd:fireball',
  int level = 3,
  bool ritual = false,
  List<SpellComponent> components = const [VerbalComponent(), SomaticComponent()],
  SpellDuration? duration,
}) {
  return Spell(
    id: id,
    name: 'Fireball',
    level: SpellLevel(level),
    schoolId: 'srd:evocation',
    castingTime: const ActionCast(),
    range: FeetRange(150),
    components: components,
    duration: duration ?? const SpellInstantaneous(),
    ritual: ritual,
    classListIds: const ['srd:wizard'],
    description: 'boom',
  );
}

SpellSlots _slots({Map<int, ({int current, int max})>? overrides}) {
  return SpellSlots(overrides ??
      {
        1: (current: 4, max: 4),
        2: (current: 3, max: 3),
        3: (current: 2, max: 2),
      });
}

PreparedSpells _prepared(List<String> ids) {
  return PreparedSpells(
    ids.map((s) => PreparedSpellEntry(spellId: s, classId: 'srd:wizard')).toList(),
  );
}

void main() {
  const validator = SpellCastValidator();

  group('cantrip', () {
    test('passes regardless of slot/prepared/ritual', () {
      final cantrip = _spell(id: 'srd:fire_bolt', level: 0);
      final err = validator.validate(
        spell: cantrip,
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
      );
      expect(err, isNull);
    });

    test('still enforces verbal silenced', () {
      final cantrip = _spell(
        id: 'srd:fire_bolt',
        level: 0,
        components: const [VerbalComponent()],
      );
      final err = validator.validate(
        spell: cantrip,
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(silenced: true),
      );
      expect(err, contains('Verbal'));
    });
  });

  group('normal cast', () {
    test('happy path returns null', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, isNull);
    });

    test('slot level required', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: null,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, 'Slot level must be chosen');
    });

    test('slot too low rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 2,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, 'Slot too low');
    });

    test('upcast at higher slot allowed', () {
      final err = validator.validate(
        spell: _spell(level: 1),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, isNull);
    });

    test('out-of-range slot rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 10,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, 'Slot level invalid');
    });

    test('no slots remaining rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(overrides: {3: (current: 0, max: 2)}),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, 'No slots remaining at level 3');
    });

    test('not prepared rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
      );
      expect(err, 'Spell not prepared');
    });
  });

  group('ritual cast', () {
    test('non-ritual spell rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: null,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(err, 'Spell is not a ritual');
    });

    test('ritual + prepared returns null with no slot', () {
      final err = validator.validate(
        spell: _spell(ritual: true),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(err, isNull);
    });

    test('ritual book accepted even when not prepared', () {
      final err = validator.validate(
        spell: _spell(ritual: true),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        ritualBookSpellIds: const {'srd:fireball'},
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(err, isNull);
    });

    test('ritual neither prepared nor in book rejected', () {
      final err = validator.validate(
        spell: _spell(ritual: true),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(err, 'Spell not available for ritual');
    });
  });

  group('components', () {
    test('verbal silenced rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(silenced: true),
      );
      expect(err, contains('Verbal'));
    });

    test('somatic without free hand rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(hasFreeHand: false),
      );
      expect(err, contains('Somatic'));
    });

    test('non-consumed material with focus passes', () {
      final spell = _spell(components: [
        const VerbalComponent(),
        const SomaticComponent(),
        MaterialComponent(description: 'a tiny ball of bat guano and sulfur'),
      ]);
      final err = validator.validate(
        spell: spell,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(hasFocus: true),
      );
      expect(err, isNull);
    });

    test('non-consumed material with pouch passes', () {
      final spell = _spell(components: [
        const VerbalComponent(),
        MaterialComponent(description: 'pinch of sand'),
      ]);
      final err = validator.validate(
        spell: spell,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(hasComponentPouch: true),
      );
      expect(err, isNull);
    });

    test('non-consumed material missing all sources rejected', () {
      final spell = _spell(components: [
        MaterialComponent(description: 'a strand of hair'),
      ]);
      final err = validator.validate(
        spell: spell,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(err, 'Need a focus, pouch, or the specific material');
    });

    test('consumed material requires specific item even with focus', () {
      final spell = _spell(components: [
        MaterialComponent(
          description: 'a diamond worth 300+ gp',
          costCp: 30000,
          consumed: true,
        ),
      ]);
      final err = validator.validate(
        spell: spell,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(hasFocus: true, hasComponentPouch: true),
      );
      expect(err, 'Missing required material: a diamond worth 300+ gp');
    });

    test('consumed material in inventory passes', () {
      final spell = _spell(components: [
        MaterialComponent(
          description: 'a diamond worth 300+ gp',
          costCp: 30000,
          consumed: true,
        ),
      ]);
      final err = validator.validate(
        spell: spell,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(
          heldMaterialDescriptions: {'a diamond worth 300+ gp'},
        ),
      );
      expect(err, isNull);
    });
  });

  group('pact magic', () {
    PactMagicSlots pact({int level = 3, int current = 2, int max = 2}) =>
        PactMagicSlots(slotLevel: level, current: current, max: max);

    test('happy path: pact slot at correct level', () {
      final err = validator.validate(
        spell: _spell(level: 2),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(),
        usePactSlot: true,
      );
      expect(err, isNull);
    });

    test('usePactSlot without pactSlots rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        usePactSlot: true,
      );
      expect(err, 'Caster has no pact magic');
    });

    test('no pact slots remaining rejected', () {
      final err = validator.validate(
        spell: _spell(),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(current: 0),
        usePactSlot: true,
      );
      expect(err, 'No pact slots remaining');
    });

    test('spell level above pact level rejected', () {
      final err = validator.validate(
        spell: _spell(level: 4),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(level: 3),
        usePactSlot: true,
      );
      expect(err, 'Pact slot too low');
    });

    test('chosen slot level mismatching pact rejected', () {
      final err = validator.validate(
        spell: _spell(level: 2),
        slotLevelChosen: 2,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(level: 3),
        usePactSlot: true,
      );
      expect(err, 'Pact slot is L3, cannot cast at L2');
    });

    test('chosen slot equal to pact level accepted', () {
      final err = validator.validate(
        spell: _spell(level: 2),
        slotLevelChosen: 3,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(level: 3),
        usePactSlot: true,
      );
      expect(err, isNull);
    });

    test('not prepared on pact path rejected', () {
      final err = validator.validate(
        spell: _spell(level: 2),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
        pactSlots: pact(),
        usePactSlot: true,
      );
      expect(err, 'Spell not prepared');
    });

    test('cantrip ignores usePactSlot', () {
      final err = validator.validate(
        spell: _spell(id: 'srd:eldritch_blast', level: 0),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
        usePactSlot: true,
      );
      expect(err, isNull);
    });
  });
}
