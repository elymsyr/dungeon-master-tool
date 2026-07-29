import 'package:dungeon_master_tool/data/schema/auto_grant_inversion.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// **One card owns "who grants this, and when".**
///
/// A feat used to declare its own source (`auto_granted_by: [{class, at_level}]`)
/// while the class card carried an unrelated narrative row for the same
/// feature. Two statements of one fact — and in the shipped SRD they disagreed
/// on nine of them. The edge now points one way only: the Class / Subclass
/// `features` row names the feat, and the feat says nothing.
///
/// `grant_field_isolation_test` proves each grant field moves one number;
/// this file proves there is exactly one place to declare *when* it arrives.
void main() {
  group('schema — the field is gone', () {
    final schema = generateBuiltinDnd5eV2Schema().schema;

    test('no category offers an auto_granted_by field', () {
      final offenders = [
        for (final c in schema.categories)
          for (final f in c.fields)
            if (f.fieldKey == 'auto_granted_by') '${c.slug}.${f.fieldKey}',
      ];
      expect(offenders, isEmpty,
          reason: 'the inverse edge is retired — a card states its own grants');
    });

    test('the FieldType that rendered it is gone too', () {
      // Otherwise a custom template could reintroduce the shape.
      expect(
        schema.categories
            .expand((c) => c.fields)
            .map((f) => f.fieldType.name)
            .toSet(),
        isNot(contains('autoGrantSources')),
      );
    });

    test('every card that can grant a feat has a field for it', () {
      Set<String> keys(String slug) => schema.categories
          .firstWhere((c) => c.slug == slug)
          .fields
          .map((f) => f.fieldKey)
          .toSet();
      // Level-gated sources carry the level table…
      expect(keys('class'), contains('features'));
      expect(keys('subclass'), contains('features'));
      // …flat sources carry a plain list.
      expect(keys('species'), contains('granted_feat_refs'));
      expect(keys('subspecies'), contains('granted_feat_refs'));
      expect(keys('background'), contains('origin_feat_ref'));
    });
  });

  group('shipped SRD content', () {
    final pack = buildSrdCorePack();
    final rows = pack.entities.values.cast<Map>().toList();

    Iterable<Map> ofType(String slug) => rows.where((r) => r['type'] == slug);

    test('no shipped card carries auto_granted_by', () {
      final offenders = [
        for (final r in rows)
          if ((r['attributes'] as Map).containsKey('auto_granted_by'))
            '${r['type']}/${r['name']}',
      ];
      expect(offenders, isEmpty);
    });

    test('every class-feature feat is reachable from exactly one level row',
        () {
      // The inversion is only correct if nothing was dropped on the floor and
      // nothing was wired twice.
      final granted = <String, int>{};
      for (final card in [...ofType('class'), ...ofType('subclass')]) {
        for (final row in ((card['attributes'] as Map)['features'] as List?) ??
            const []) {
          for (final id in ((row as Map)['granted_feat_refs'] as List?) ??
              const []) {
            granted['$id'] = (granted['$id'] ?? 0) + 1;
          }
        }
      }

      final classFeatureIds = <String>{};
      pack.entities.forEach((id, raw) {
        final row = raw as Map;
        if (row['type'] != 'feat') return;
        // Class/subclass features are exactly the non-chooseable feats that
        // are not per-feature option picks (Metamagic, Invocations, …), which
        // are chosen through the pending-choice dialog instead.
        if (row['attributes']['chooseable'] != false) return;
        final cat = row['attributes']['category_ref'];
        final catName = cat is Map ? cat['name']?.toString() ?? '' : '';
        if (!catName.endsWith('Feature')) return;
        classFeatureIds.add(id);
      });

      expect(classFeatureIds.length, greaterThan(150),
          reason: 'found too few class-feature feats to mean anything');
      final unreachable = classFeatureIds.difference(granted.keys.toSet());
      expect(unreachable, isEmpty,
          reason: 'class-feature feat no class card grants — dead content');
      final twice = [
        for (final e in granted.entries)
          if (e.value > 1) e.key,
      ];
      expect(twice, isEmpty, reason: 'feat wired into two level rows');
    });

    test('every granted_feat_refs entry resolves to a real feat', () {
      final byId = pack.entities;
      final broken = <String>[];
      for (final card in [...ofType('class'), ...ofType('subclass')]) {
        for (final row in ((card['attributes'] as Map)['features'] as List?) ??
            const []) {
          for (final id in ((row as Map)['granted_feat_refs'] as List?) ??
              const []) {
            final hit = byId['$id'];
            if (hit == null || (hit as Map)['type'] != 'feat') {
              broken.add('${card['name']} L${row['level']} → "$id"');
            }
          }
        }
      }
      expect(broken, isEmpty);
    });

    test('every features row carries a name', () {
      // The row name is now the feature's identity — it is what the editor
      // shows and what `featureName:` matches against.
      final nameless = <String>[];
      for (final card in [...ofType('class'), ...ofType('subclass')]) {
        for (final row in ((card['attributes'] as Map)['features'] as List?) ??
            const []) {
          final n = (row as Map)['name'];
          if (n == null || '$n'.isEmpty) {
            nameless.add('${card['name']} L${row['level']}');
          }
        }
      }
      expect(nameless, isEmpty);
    });
  });

  group('pack build guards', () {
    test('the level tables the inversion had to correct are pinned', () {
      // Each entry is a real disagreement between the class table and the
      // feature feat that the one-way edge exposed. Resolved toward the feat's
      // level, which is what the resolver applied before the change — so
      // sheets are unaffected and only the displayed table moved. Content
      // review may well decide some of these belong at the other level; this
      // list is the record of what to review, and it must not grow silently.
      final drifted = wireFeatureGrants(srdRawRowsBySlug());
      expect(drifted, hasLength(15));
      expect(
        drifted,
        containsAll(const [
          'Fighter L11 "Two Extra Attacks" (satır yoktu, eklendi)',
          'Warlock "Mystic Arcanum (Level 6 Spell)" L5 → L11 '
              '(feat seviyesine hizalandı)',
          'Champion "Remarkable Athlete" L3 → L7 (feat seviyesine hizalandı)',
          'Evoker "Potent Cantrip" L6 → L3 (feat seviyesine hizalandı)',
        ]),
      );
    });

    test('pack entity ids are unique, so no row silently overwrites another',
        () {
      // Ids are `slug:name` derived. "Uncanny Dodge" (Rogue L5 vs a Hunter
      // option) and "Fiendish Vigor" (Fiend Patron L3 vs a Warlock invocation)
      // both shipped as collisions before the builder started throwing.
      expect(buildSrdCorePack, returnsNormally);
    });
  });

  group('migration — old worlds convert', () {
    test('a class-sourced feat moves onto the class level row', () {
      final world = <String, dynamic>{
        'cls': {
          'name': 'Paladin',
          'type': 'class',
          'attributes': {
            'features': [
              {'level': 9, 'name': 'Abjure Foes', 'description': 'x'},
            ],
          },
        },
        'ft': {
          'name': 'Abjure Foes',
          'type': 'feat',
          'attributes': {
            'auto_granted_by': [
              {'source': 'class', 'source_ref': 'cls', 'at_level': 9},
            ],
          },
        },
      };
      expect(invertAutoGrants(world), 1);
      final rows = world['cls']['attributes']['features'] as List;
      expect(rows.single['granted_feat_refs'], ['ft']);
      expect(world['ft']['attributes'].containsKey('auto_granted_by'), isFalse);
    });

    test('a level with no row yet gets one', () {
      final world = <String, dynamic>{
        'cls': {
          'name': 'Fighter',
          'type': 'class',
          'attributes': <String, dynamic>{},
        },
        'ft': {
          'name': 'Two Extra Attacks',
          'type': 'feat',
          'attributes': {
            'auto_granted_by': [
              {'source': 'class', 'source_ref': 'cls', 'at_level': 11},
            ],
          },
        },
      };
      expect(invertAutoGrants(world), 1);
      final rows = world['cls']['attributes']['features'] as List;
      expect(rows.single['level'], 11);
      expect(rows.single['name'], 'Two Extra Attacks');
      expect(rows.single['granted_feat_refs'], ['ft']);
    });

    test('a species source lands on the flat list, with no level', () {
      final world = <String, dynamic>{
        'sp': {
          'name': 'Elf',
          'type': 'species',
          'attributes': <String, dynamic>{},
        },
        'ft': {
          'name': 'Fey Ancestry',
          'type': 'feat',
          'attributes': {
            'auto_granted_by': [
              {
                'source': 'species',
                'source_ref': {'slug': 'species', 'name': 'Elf'},
              },
            ],
          },
        },
      };
      expect(invertAutoGrants(world), 1);
      expect(world['sp']['attributes']['granted_feat_refs'], ['ft']);
    });

    test('a trait lands on granted_trait_refs, not granted_feat_refs', () {
      final world = <String, dynamic>{
        'cls': {
          'name': 'Druid',
          'type': 'class',
          'attributes': <String, dynamic>{},
        },
        'tr': {
          'name': 'Druidic',
          'type': 'trait',
          'attributes': {
            'auto_granted_by': [
              {'source': 'class', 'source_ref': 'cls', 'at_level': 1},
            ],
          },
        },
      };
      expect(invertAutoGrants(world), 1);
      final row = (world['cls']['attributes']['features'] as List).single;
      expect(row['granted_trait_refs'], ['tr']);
      expect(row.containsKey('granted_feat_refs'), isFalse);
    });

    test('a source card that is not installed is reported, not dropped', () {
      final world = <String, dynamic>{
        'ft': {
          'name': 'Orphan',
          'type': 'feat',
          'attributes': {
            'auto_granted_by': [
              {'source': 'class', 'source_ref': 'missing', 'at_level': 3},
            ],
          },
        },
      };
      expect(invertAutoGrants(world), 0);
      expect(world['ft']['attributes']['mechanical_notes'],
          contains('Auto-granted by class (card not installed)'));
      expect(world['ft']['attributes'].containsKey('auto_granted_by'), isFalse);
    });

    test('converted data is left completely alone', () {
      final world = <String, dynamic>{
        'cls': {
          'name': 'Paladin',
          'type': 'class',
          'attributes': {
            'features': [
              {
                'level': 9,
                'name': 'Abjure Foes',
                'granted_feat_refs': ['ft'],
              },
            ],
          },
        },
        'ft': {'name': 'Abjure Foes', 'type': 'feat', 'attributes': {}},
      };
      expect(invertAutoGrants(world), 0);
      final rows = world['cls']['attributes']['features'] as List;
      expect(rows.single['granted_feat_refs'], ['ft']);
    });
  });
}
