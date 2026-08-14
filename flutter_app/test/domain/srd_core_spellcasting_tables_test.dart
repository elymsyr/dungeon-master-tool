import 'package:dungeon_master_tool/application/character_creation/caster_progression.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase T2-2 — the SRD 5.2.1 spellcasting tables.**
///
/// Harvested from the pinned snapshot's `srd-2024/ClassFeatureItem.json` into
/// `srd_core/classes.dart`. Two things are pinned here: the authored numbers,
/// and the rule that decided which ones get authored — the `caster_kind`
/// preset in `caster_progression.dart` is the authority for Full/Pact slots
/// (it agrees with the source on all 20 levels), the data is the authority for
/// cantrips, prepared spells, and Half-caster slots (where 5.2.1 and the
/// 2014-shaped preset disagree at level 1).
void main() {
  final pack = buildSrdCorePack();

  Entity cls(String name) {
    final row = pack.entities.values.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['type'] == 'class' && e['name'] == name,
        orElse: () => throw StateError('no built-in class $name'));
    return Entity(
      id: name,
      name: name,
      categorySlug: 'class',
      fields: Map<String, dynamic>.from(row['attributes'] as Map),
    );
  }

  int? cantrips(String name, int level) =>
      levelTableValue(cls(name).fields['cantrips_known_by_level'], level);
  int? prepared(String name, int level) =>
      levelTableValue(cls(name).fields['prepared_spells_by_level'], level);

  test('cantrips known are per-class, not the preset guess', () {
    // The preset returns one number for every full caster (3/4/5); the SRD
    // gives the Sorcerer 4 at level 1 and the Bard 2.
    expect(cantrips('Sorcerer', 1), 4);
    expect(cantrips('Bard', 1), 2);
    expect(cantrips('Cleric', 1), 3);
    expect(cantrips('Wizard', 20), 5);
    expect(cantrips('Warlock', 10), 4);
    expect(defaultCantripsKnown(CasterKind.full, 1), 3,
        reason: 'the preset is still the fallback for packaged casters');

    // Half casters have no cantrips in 5.2.1 and must not claim otherwise.
    expect(cls('Paladin').fields['cantrips_known_by_level'], isNull);
    expect(cls('Ranger').fields['cantrips_known_by_level'], isNull);
  });

  test('prepared spells follow each class curve', () {
    expect(prepared('Wizard', 1), 4);
    expect(prepared('Wizard', 20), 25); // the one full caster that outruns 22
    expect(prepared('Sorcerer', 1), 2);
    expect(prepared('Paladin', 1), 2);
    expect(prepared('Warlock', 20), 15);
    expect(defaultPreparedSpells(CasterKind.full, 20), 23,
        reason: 'the flat preset curve is what the authored table replaces');
  });

  test('half casters get their level-1 slots — the preset does not give them',
      () {
    expect(spellSlotsForClass(cls('Paladin'), 1), {1: 2});
    expect(spellSlotsForClass(cls('Ranger'), 1), {1: 2});
    expect(defaultSpellSlotsByLevel(CasterKind.half, 1), isEmpty);
    // …and the authored table still agrees with the preset above level 1.
    for (var level = 2; level <= 20; level++) {
      expect(spellSlotsForClass(cls('Paladin'), level),
          defaultSpellSlotsByLevel(CasterKind.half, level),
          reason: 'half-caster level $level');
    }
  });

  test('full and pact casters ship no slot table — the preset owns them', () {
    for (final name in const [
      'Bard',
      'Cleric',
      'Druid',
      'Sorcerer',
      'Wizard',
      'Warlock',
    ]) {
      expect(cls(name).fields['spell_slots_by_level'], isNull, reason: name);
    }
    expect(spellSlotsForClass(cls('Wizard'), 5), {1: 4, 2: 3, 3: 2});
    expect(spellSlotsForClass(cls('Warlock'), 5), {3: 2});
  });
}
