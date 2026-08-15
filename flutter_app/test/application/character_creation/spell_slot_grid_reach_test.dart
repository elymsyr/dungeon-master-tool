import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/character_creation/caster_progression.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase M4 — the spell-slot table lands on a sheet.**
///
/// M1 swept every mechanic *a pack writes* onto `EffectiveCharacter`. It
/// structurally could not see this one: `spell_slots_by_level`,
/// `cantrips_known_by_level` and `prepared_spells_by_level` never reach
/// `CharacterResolver` at all. The grid is computed **wizard-side** —
/// `spellSlotsForClass` (caster_progression.dart) is called once at creation
/// commit and again by the level-up planner, and the result is stored on the
/// character's own `spell_slots` field, which is what the sheet renders. So
/// the question "does the slot table reach a sheet" is answered here, at that
/// function, and not in `bundled_pack_resolve_test`.
///
/// Three things are pinned:
///   1. every caster class the app actually ships produces a non-empty grid;
///   2. an authored `spell_slots_by_level` **beats** the `caster_kind` preset —
///      today nothing else fails if the override is silently ignored;
///   3. the bundled packs ship **no** caster class (measured, not assumed), so
///      the day one arrives this file fails and the probe gets rewritten
///      against real data instead of a synthesised card.
void main() {
  final pack = buildSrdCorePack();

  List<Entity> builtinClasses() => [
        for (final row in pack.entities.values.cast<Map<String, dynamic>>())
          if (row['type'] == 'class')
            Entity(
              id: '${row['name']}',
              name: '${row['name']}',
              categorySlug: 'class',
              fields: Map<String, dynamic>.from(row['attributes'] as Map),
            ),
      ];

  /// The level a progression first hands out a slot: Full from 1, Half from 1
  /// (authored 5.2.1 table) or 2 (2014-shaped preset), Third from 3.
  int onsetOf(Entity cls) {
    for (var lvl = 1; lvl <= 20; lvl++) {
      if (spellSlotsForClass(cls, lvl).isNotEmpty) return lvl;
    }
    return -1;
  }

  group('M4 — the slot grid reaches the sheet', () {
    test('every shipped caster class produces a slot grid', () {
      final casters = [
        for (final c in builtinClasses())
          if (parseCasterKind(c.fields['caster_kind']) != CasterKind.none) c,
      ];
      expect(casters, hasLength(8),
          reason: 'SRD 5.2.1 casters: Bard/Cleric/Druid/Sorcerer/Wizard full, '
              'Warlock pact, Paladin/Ranger half. A new built-in caster class '
              'belongs in this count.');

      final onsets = <String, int>{};
      for (final c in casters) {
        final onset = onsetOf(c);
        onsets[c.name] = onset;
        expect(onset, greaterThan(0),
            reason: '${c.name} declares caster_kind '
                '"${c.fields['caster_kind']}" but never gets a slot');
        // The grid has to keep existing all the way up, not just at onset.
        expect(spellSlotsForClass(c, 20), isNotEmpty, reason: c.name);
      }
      // ignore: avoid_print
      print('M4: ${casters.length} built-in caster classes, first slot at '
          'level $onsets');
    });

    test('authored spell_slots_by_level beats the caster_kind preset', () {
      // Real shipped data, not a fixture: T2-2 authored the 5.2.1 half-caster
      // table on Paladin and Ranger, which gives 2 first-level slots at L1.
      // The preset in caster_progression is 2014-shaped and gives none. If the
      // override were silently ignored, both would read empty here.
      expect(defaultSpellSlotsByLevel(CasterKind.half, 1), isEmpty,
          reason: 'preset is 2014-shaped: no L1 half-caster slot');
      for (final name in ['Paladin', 'Ranger']) {
        final cls = builtinClasses().firstWhere((c) => c.name == name);
        expect(cls.fields['spell_slots_by_level'], isNotNull, reason: name);
        expect(spellSlotsForClass(cls, 1), {1: 2},
            reason: '$name: authored 5.2.1 table must win over the preset');
      }

      // The six full casters and the Warlock deliberately author nothing, so
      // the same call has to fall through to the preset.
      final wizard = builtinClasses().firstWhere((c) => c.name == 'Wizard');
      expect(wizard.fields['spell_slots_by_level'], isNull);
      expect(spellSlotsForClass(wizard, 5),
          defaultSpellSlotsByLevel(CasterKind.full, 5));
    });

    test('bundled packs ship no caster class — measured', () {
      final assets = Directory('assets/open5e_packs')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pkg.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(assets, hasLength(19));

      const slotFields = [
        'spell_slots_by_level',
        'cantrips_known_by_level',
        'prepared_spells_by_level',
      ];
      final classCards = <String>[];
      final casters = <String>[];
      final tableWriters = <String>[];

      for (final file in assets) {
        final root = jsonDecode(file.readAsStringSync()) as Map;
        (root['entities'] as Map).forEach((_, raw) {
          final row = raw as Map;
          if (row['type'] != 'class') return;
          final attrs = (row['attributes'] as Map?) ?? const {};
          final label = '${file.uri.pathSegments.last}/${row['name']}';
          classCards.add(label);
          if (parseCasterKind(attrs['caster_kind']) != CasterKind.none) {
            casters.add(label);
          }
          for (final f in slotFields) {
            final v = attrs[f];
            if (v is Map && v.isNotEmpty) tableWriters.add('$label.$f');
          }
        });
      }

      // ignore: avoid_print
      print('M4: ${classCards.length} packaged class cards '
          '(${classCards.join(', ')}), ${casters.length} casters, '
          '${tableWriters.length} authored level tables');
      expect(classCards, hasLength(2),
          reason: 'a5e-ag Marshal + bfrd Mechanist are the whole corpus');
      expect(casters, isEmpty,
          reason: 'a pack now ships a caster class — replace the synthesised '
              'card in the next test with that real one');
      expect(tableWriters, isEmpty,
          reason: 'a pack now authors a level table — assert it lands on the '
              'grid with real data instead of a synthesised override');
    });

    test('a packaged class card declaring a caster kind gets a grid', () {
      // Because the corpus has no caster (test above), the caster fields are
      // synthesised **onto a real pack card** rather than a fixture: same
      // installed shape, same single entry point the wizard commit uses.
      final root = jsonDecode(
              File('assets/open5e_packs/open5e-a5e-ag.pkg.json')
                  .readAsStringSync())
          as Map;
      final marshalRow = (root['entities'] as Map)
          .values
          .cast<Map>()
          .firstWhere((r) => r['type'] == 'class' && r['name'] == 'Marshal');
      final attrs = Map<String, dynamic>.from(marshalRow['attributes'] as Map);
      expect(attrs['caster_kind'], 'None',
          reason: 'Marshal is caster_type NONE upstream; if that changes the '
              'synthesis below is no longer needed');

      Entity marshal(Map<String, dynamic> extra) => Entity(
            id: 'marshal',
            name: 'Marshal',
            categorySlug: 'class',
            fields: {...attrs, ...extra},
          );

      // Non-caster as shipped: no grid, so the wizard writes no `spell_slots`.
      expect(spellSlotsForClass(marshal(const {}), 5), isEmpty);

      // Declared caster → preset grid.
      expect(spellSlotsForClass(marshal({'caster_kind': 'Full'}), 5),
          defaultSpellSlotsByLevel(CasterKind.full, 5));

      // Declared caster + authored table → the table, at the row it defines
      // and only there.
      final overridden = marshal({
        'caster_kind': 'Full',
        'spell_slots_by_level': {
          '5': {'1': 9, '2': 9},
        },
      });
      expect(spellSlotsForClass(overridden, 5), {1: 9, 2: 9});
      expect(spellSlotsForClass(overridden, 6),
          defaultSpellSlotsByLevel(CasterKind.full, 6));
    });
  });
}
