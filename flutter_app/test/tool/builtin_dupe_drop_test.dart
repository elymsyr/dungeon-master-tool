import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/dupe.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase L4 — a card the built-in pack already ships is not re-emitted,
/// and every pointer at it is re-aimed rather than broken.**
///
/// Two halves, and the second is the one that makes L4 a rewrite instead of a
/// filter. Deleting a duplicate is easy; the defect it can introduce is a
/// monster whose `trait_refs` now name nothing. The rule of thumb the phase
/// states is that the reference *count* before and after must match and only
/// the target changes — so these tests assert the survivor resolves, not merely
/// that the duplicate is gone.
///
/// The drop set on the pinned snapshot is 7 rows (3 `creature-action`,
/// 4 `trait`), all of them monster-owned children in `open5e-a5e-mm` and
/// `open5e-bfrd`. They are asserted **by name**, the same contract as
/// `gate.dart`'s `_actionlessUpstream`: a rebuild that drops a *different* card
/// has to come back here and say so.
void main() {
  group('dropBuiltinDuplicates (unit)', () {
    late Map<String, BuiltinCard> builtin;

    setUp(() {
      builtin = {
        identityKey('trait', 'Amphibious'): const BuiltinCard(
            'trait', 'Amphibious', 'It can breathe air and water.'),
      };
    });

    Map<String, dynamic> row(String slug, String name, String desc,
            [Map<String, dynamic>? attrs]) =>
        <String, dynamic>{
          'type': slug,
          'name': name,
          'description': desc,
          'attributes': attrs ?? <String, dynamic>{'description': desc},
        };

    test('drops a verbatim copy and retargets the pointer at it', () {
      final pack = PackBuilder('test-pack');
      pack.add(row('trait', 'Amphibious', 'It can breathe air and water.'));
      pack.add(row('monster', 'Boloti', '', <String, dynamic>{
        'trait_refs': [
          {'_ref': 'trait', 'name': 'Amphibious'}
        ],
      }));

      final report = dropBuiltinDuplicates(pack, builtin);

      expect(report.dropped, hasLength(1));
      expect(report.retargeted, 1);
      expect(pack.has('trait', 'Amphibious'), isFalse);

      // The survivor is a soft ref by name — never a hard ref to a deleted id.
      final monster = pack.entities.values
          .firstWhere((e) => (e as Map)['name'] == 'Boloti') as Map;
      expect((monster['attributes'] as Map)['trait_refs'], [
        {'slug': 'trait', 'name': 'Amphibious'}
      ]);

      // And pass 2 still completes: a stale index entry would fail the build.
      expect(pack.resolveRefs(), isEmpty);
    });

    test('a shared name with different prose is kept — the A5E restat case',
        () {
      final pack = PackBuilder('test-pack');
      pack.add(row(
          'trait',
          'Amphibious',
          'It breathes air and water, and it gains advantage while '
              'submerged.'));
      pack.add(row('monster', 'Boloti', '', <String, dynamic>{
        'trait_refs': [
          {'_ref': 'trait', 'name': 'Amphibious'}
        ],
      }));

      final report = dropBuiltinDuplicates(pack, builtin);

      expect(report.isEmpty, isTrue,
          reason: 'name-only matching would delete a genuine restat');
      expect(pack.has('trait', 'Amphibious'), isTrue);
    });

    test('blank prose on both sides is not evidence of a duplicate', () {
      final pack = PackBuilder('test-pack');
      pack.add(row('trait', 'Amphibious', ''));

      final blank = {
        identityKey('trait', 'Amphibious'):
            const BuiltinCard('trait', 'Amphibious', ''),
      };

      expect(dropBuiltinDuplicates(pack, blank).isEmpty, isTrue);
      expect(pack.has('trait', 'Amphibious'), isTrue);
    });

    test('the retarget uses the built-in spelling, not the copy', () {
      final pack = PackBuilder('test-pack');
      pack.add(row('trait', 'AMPHIBIOUS', 'It can breathe air and water.'));
      pack.add(row('monster', 'Boloti', '', <String, dynamic>{
        'trait_refs': [
          {'_ref': 'trait', 'name': 'AMPHIBIOUS'}
        ],
      }));

      dropBuiltinDuplicates(pack, builtin);

      final monster = pack.entities.values
          .firstWhere((e) => (e as Map)['name'] == 'Boloti') as Map;
      // `findEntityIdByName` is case-sensitive, so echoing the copy's casing
      // would ship a dangling soft ref.
      expect(((monster['attributes'] as Map)['trait_refs'] as List).single,
          {'slug': 'trait', 'name': 'Amphibious'});
    });
  });

  group('the shipped assets (L4 exit)', () {
    final srd = buildBuiltinSrdEntities();

    Map<String, Entity> loadPack(String slug) {
      final file = File('assets/open5e_packs/$slug.pkg.json');
      expect(file.existsSync(), isTrue, reason: 'missing asset $slug');
      final entities =
          (jsonDecode(file.readAsStringSync()) as Map)['entities'] as Map;
      return {
        for (final e in entities.entries)
          '${e.key}': Entity(
            id: '${e.key}',
            categorySlug: (e.value as Map)['type']?.toString() ?? '?',
            name: (e.value as Map)['name']?.toString() ?? '',
            fields: Map<String, dynamic>.from(
                ((e.value as Map)['attributes'] as Map?) ??
                    const <String, dynamic>{}),
          ),
      };
    }

    /// The seven rows the build drops, as `(pack, slug, name)`.
    const dropped = <(String, String, String)>[
      ('open5e-a5e-mm', 'creature-action', 'Nimble Escape'),
      ('open5e-a5e-mm', 'creature-action', 'Teleport (Blink Dog)'),
      ('open5e-bfrd', 'creature-action', 'Nimble Escape'),
      ('open5e-bfrd', 'trait', 'False Appearance (Gargoyle)'),
      ('open5e-bfrd', 'trait', 'Hold Breath (Octopus)'),
      ('open5e-bfrd', 'trait', 'Speak with Beasts and Plants'),
      ('open5e-bfrd', 'trait', 'Spider Climb (Roper)'),
    ];

    test('no bundled pack re-ships a card the built-in pack has verbatim', () {
      for (final (pack, slug, name) in dropped) {
        final rows = loadPack(pack)
            .values
            .where((e) => e.categorySlug == slug && e.name == name);
        expect(rows, isEmpty,
            reason: '$pack still ships $slug "$name", which the built-in pack '
                'already has word for word');
      }
    });

    test('two packs that both shipped a dropped name list it exactly once', () {
      // `Nimble Escape` was in a5e-mm *and* bfrd, so installing both used to
      // put three copies in front of the DM (theirs, theirs, and the built-in
      // one that was always in scope).
      final world = <String, Entity>{
        ...srd,
        ...loadPack('open5e-a5e-mm'),
        ...loadPack('open5e-bfrd'),
      };
      final listed = world.values.where((e) =>
          e.categorySlug == 'creature-action' && e.name == 'Nimble Escape');
      expect(listed, hasLength(1));
      expect(srd.containsKey(listed.single.id), isTrue,
          reason: 'the survivor must be the built-in card');
    });

    test('a monster that named a dropped card now lands on the built-in one',
        () {
      // The retarget half. Blink Dog's teleport is the worked example: its
      // `bonus_action_refs` used to hold an in-pack uuid that no longer exists,
      // so if the drop had not re-aimed it the dog would have lost the ability
      // entirely.
      final pack = loadPack('open5e-a5e-mm');
      final world = <String, Entity>{...srd, ...pack};
      final dog = pack.values.firstWhere(
          (e) => e.categorySlug == 'monster' && e.name == 'Blink Dog');

      final refs = dog.fields['bonus_action_refs'];
      expect(refs, isA<List>());
      final resolved = resolveEntityRefList(refs, world);
      expect(resolved, hasLength((refs as List).length),
          reason: 'every ref must still resolve — the count may not drop');

      final teleport = resolved
          .map((id) => world[id]!)
          .where((e) => e.name == 'Teleport (Blink Dog)');
      expect(teleport, hasLength(1));
      expect(srd.containsKey(teleport.single.id), isTrue,
          reason: 'the ref must now point at the built-in card');
    });
  });
}
