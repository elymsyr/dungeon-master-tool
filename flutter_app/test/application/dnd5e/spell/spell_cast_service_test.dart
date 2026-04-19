import 'package:dungeon_master_tool/application/dnd5e/spell/caster_context.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/casting_method.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/spell_cast_service.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/pact_magic_slots.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/prepared_spells.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/spell_slots.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
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
  const service = SpellCastService();

  group('failure passthrough', () {
    test('validator error short-circuits — slots untouched', () {
      final slots = _slots();
      final out = service.cast(
        spell: _spell(),
        slotLevelChosen: 2,
        slots: slots,
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(out.success, isFalse);
      expect(out.error, 'Slot too low');
      expect(out.slots, slots);
      expect(out.slotConsumed, isFalse);
      expect(out.concentration, isNull);
    });

    test('failure preserves prior concentration', () {
      final prior = Concentration(
        spellId: 'srd:bless',
        castAtLevel: SpellLevel(1),
      );
      final out = service.cast(
        spell: _spell(),
        slotLevelChosen: null,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        currentConcentration: prior,
      );
      expect(out.success, isFalse);
      expect(out.concentration, prior);
      expect(out.droppedConcentration, isNull);
    });
  });

  group('slot accounting', () {
    test('normal cast spends one slot at chosen level', () {
      final out = service.cast(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(out.success, isTrue);
      expect(out.slotConsumed, isTrue);
      expect(out.slots.currentOf(3), 1);
      expect(out.slots.currentOf(2), 3);
    });

    test('upcast spends slot at higher level, not spell base level', () {
      final out = service.cast(
        spell: _spell(level: 1),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(out.success, isTrue);
      expect(out.slots.currentOf(3), 1);
      expect(out.slots.currentOf(1), 4);
    });

    test('cantrip never spends a slot', () {
      final slots = _slots();
      final out = service.cast(
        spell: _spell(id: 'srd:fire_bolt', level: 0),
        slotLevelChosen: null,
        slots: slots,
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
      );
      expect(out.success, isTrue);
      expect(out.slotConsumed, isFalse);
      expect(out.slots, slots);
    });

    test('ritual cast never spends a slot', () {
      final slots = _slots();
      final out = service.cast(
        spell: _spell(ritual: true),
        slotLevelChosen: null,
        slots: slots,
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(out.success, isTrue);
      expect(out.slotConsumed, isFalse);
      expect(out.slots, slots);
    });
  });

  group('concentration transitions', () {
    test('non-concentration spell does not start concentration', () {
      final out = service.cast(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
      );
      expect(out.concentration, isNull);
      expect(out.droppedConcentration, isNull);
    });

    test('non-concentration cast preserves prior concentration', () {
      final prior = Concentration(
        spellId: 'srd:bless',
        castAtLevel: SpellLevel(1),
      );
      final out = service.cast(
        spell: _spell(),
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        currentConcentration: prior,
      );
      expect(out.concentration, prior);
      expect(out.droppedConcentration, isNull);
    });

    test('concentration spell starts concentration at slot level', () {
      final hold = _spell(
        id: 'srd:hold_person',
        level: 2,
        duration: SpellMinutes(minutes: 1, concentration: true),
      );
      final out = service.cast(
        spell: hold,
        slotLevelChosen: 3,
        slots: _slots(),
        prepared: _prepared(['srd:hold_person']),
        context: const CasterContext(),
      );
      expect(out.concentration?.spellId, 'srd:hold_person');
      expect(out.concentration?.castAtLevel, SpellLevel(3));
      expect(out.droppedConcentration, isNull);
    });

    test('starting new concentration drops the old', () {
      final prior = Concentration(
        spellId: 'srd:bless',
        castAtLevel: SpellLevel(1),
      );
      final hold = _spell(
        id: 'srd:hold_person',
        level: 2,
        duration: SpellMinutes(minutes: 1, concentration: true),
      );
      final out = service.cast(
        spell: hold,
        slotLevelChosen: 2,
        slots: _slots(),
        prepared: _prepared(['srd:hold_person']),
        context: const CasterContext(),
        currentConcentration: prior,
      );
      expect(out.concentration?.spellId, 'srd:hold_person');
      expect(out.droppedConcentration, prior);
    });

    test('ritual cast of concentration spell uses base spell level', () {
      final detect = _spell(
        id: 'srd:detect_magic',
        level: 1,
        ritual: true,
        duration: SpellMinutes(minutes: 10, concentration: true),
      );
      final out = service.cast(
        spell: detect,
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:detect_magic']),
        context: const CasterContext(),
        method: CastingMethod.ritual,
      );
      expect(out.success, isTrue);
      expect(out.concentration?.spellId, 'srd:detect_magic');
      expect(out.concentration?.castAtLevel, SpellLevel(1));
    });
  });

  group('pact magic', () {
    PactMagicSlots pact({int level = 3, int current = 2, int max = 2}) =>
        PactMagicSlots(slotLevel: level, current: current, max: max);

    test('pact slot spent decrements pactSlots, not regular slots', () {
      final slots = _slots();
      final out = service.cast(
        spell: _spell(level: 2),
        slotLevelChosen: null,
        slots: slots,
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pact(),
        usePactSlot: true,
      );
      expect(out.success, isTrue);
      expect(out.pactSlotConsumed, isTrue);
      expect(out.slotConsumed, isFalse);
      expect(out.pactSlots!.current, 1);
      expect(out.slots, slots);
    });

    test('failed pact cast echoes pactSlots unchanged', () {
      final pactIn = pact(current: 0);
      final out = service.cast(
        spell: _spell(level: 2),
        slotLevelChosen: null,
        slots: _slots(),
        prepared: _prepared(['srd:fireball']),
        context: const CasterContext(),
        pactSlots: pactIn,
        usePactSlot: true,
      );
      expect(out.success, isFalse);
      expect(out.error, 'No pact slots remaining');
      expect(out.pactSlots, pactIn);
      expect(out.pactSlotConsumed, isFalse);
    });

    test('pact concentration cast records pact slot level as castAtLevel', () {
      final hold = _spell(
        id: 'srd:hold_person',
        level: 2,
        duration: SpellMinutes(minutes: 1, concentration: true),
      );
      final out = service.cast(
        spell: hold,
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: _prepared(['srd:hold_person']),
        context: const CasterContext(),
        pactSlots: pact(level: 5),
        usePactSlot: true,
      );
      expect(out.success, isTrue);
      expect(out.concentration?.spellId, 'srd:hold_person');
      expect(out.concentration?.castAtLevel, SpellLevel(5));
    });

    test('cantrip with usePactSlot does not spend pact slot', () {
      final pactIn = pact();
      final out = service.cast(
        spell: _spell(id: 'srd:eldritch_blast', level: 0),
        slotLevelChosen: null,
        slots: SpellSlots.empty(),
        prepared: PreparedSpells.empty(),
        context: const CasterContext(),
        pactSlots: pactIn,
        usePactSlot: true,
      );
      expect(out.success, isTrue);
      expect(out.pactSlotConsumed, isFalse);
      expect(out.pactSlots, pactIn);
    });
  });
}
