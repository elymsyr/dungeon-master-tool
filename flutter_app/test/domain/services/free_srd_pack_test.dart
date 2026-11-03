import 'package:collection/collection.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_pack.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// The free SRD package's converter, on the real SRD 5.2.1 cards
/// (docs/free-template/SRD-FREE-ALANLAR.md §8, §11).
void main() {
  final build = generateBuiltinDnd5eV2Schema();
  // The pack as the package rows hold it: `_lookup` placeholders unresolved.
  final raw = <String, Entity>{
    for (final MapEntry(key: slug, value: rows) in build.seedRows.entries)
      for (final r in rows)
        if (r['name'] case final String name when name.isNotEmpty)
          srdStableEntityId(slug, name): Entity(
            id: srdStableEntityId(slug, name),
            name: name,
            categorySlug: slug,
            description: (r['description'] as String?) ?? '',
            fields: Map<String, dynamic>.from(
              (r['fields'] as Map?) ?? const {},
            ),
          ),
    for (final MapEntry(:key, :value) in buildSrdCorePack().entities.entries)
      key: Entity(
        id: key,
        name: (value as Map)['name'] as String,
        categorySlug: value['type'] as String,
        description: (value['description'] as String?) ?? '',
        fields: Map<String, dynamic>.from(
          (value['attributes'] as Map?) ?? const {},
        ),
      ),
  };
  // The same cards as a world reads them (placeholders resolved).
  final world = buildBuiltinSrdEntities();
  final tier0 = <String, Map<String, String>>{
    for (final MapEntry(key: slug, value: rows) in build.seedRows.entries)
      slug: {
        for (final r in rows)
          if (r['name'] case final String name when name.isNotEmpty)
            name: srdStableEntityId(slug, name),
      },
  };
  final converted = {
    for (final c in raw.values)
      if (inFreeSrd(c.categorySlug)) c.id: freeSrdFields(c, raw),
  };
  // A card's fields as a world holds them: synthesis resolves every row's
  // placeholders (`buildBuiltinSrdEntities` leaves the Tier-0 rows' own).
  Map<String, dynamic> resolved(Map<String, dynamic> fields) =>
      PackageImportService.resolveLookupPlaceholder(fields, tier0)
          as Map<String, dynamic>;
  Map<String, dynamic> stored(String id) => resolved(converted[id]!);
  final cats = {for (final c in srdFreeTemplate.categories) c.slug: c};
  final builtin = {for (final c in build.schema.categories) c.slug: c};
  String id(String slug, String name) => raw.values
      .firstWhere((e) => e.categorySlug == slug && e.name == name)
      .id;

  const eq = DeepCollectionEquality();
  bool blank(Object? v) =>
      v == null ||
      v == '' ||
      v == false ||
      (v is List && v.isEmpty) ||
      (v is Map && v.isEmpty);
  bool same(Object? a, Object? b) => (blank(a) && blank(b)) || eq.equals(a, b);

  /// What a free card shows for [f]: the read, and a list the way the
  /// markdown field shows it.
  Object? shown(FieldSchema f, Map<String, dynamic> fields) {
    final v = freeFieldValue(f, fields, byId: world);
    return f.fieldType == FieldType.markdown && v is List
        ? structuredListAsMarkdown(v, (r) => entityRefName(r, world))
        : v;
  }

  group('A1', () {
    test('the stored free data shows what the SRD read showed', () {
      final diffs = <String>[];
      for (final c in raw.values) {
        final cat = cats[c.categorySlug];
        if (cat == null) continue;
        final s = stored(c.id);
        final today = resolved(world[c.id]!.fields);
        final ids = {for (final f in builtin[cat.slug]!.fields) f.fieldId};
        for (final f in cat.fields) {
          // A closed category's new lines (A2+) were never read from the SRD.
          if (freeSrdClosed.contains(cat.slug) && !ids.contains(f.fieldId)) {
            continue;
          }
          if (!same(shown(f, s), shown(f, today))) {
            diffs.add('${c.categorySlug} / ${c.name} / ${f.fieldKey}');
          }
        }
      }
      expect(diffs, isEmpty);
    });

    test('the stored data needs no read: a field shows what it holds', () {
      final diffs = <String>[];
      for (final c in raw.values) {
        final cat = cats[c.categorySlug];
        if (cat == null) continue;
        final s = stored(c.id);
        for (final f in cat.fields) {
          if (!same(shown(f, s), s[f.fieldKey])) {
            diffs.add('${c.categorySlug} / ${c.name} / ${f.fieldKey}');
          }
        }
      }
      expect(diffs, isEmpty);
    });

    test('class rows, a pool and a monster block, written as free values', () {
      final fighter = converted[id('class', 'Fighter')]!;
      expect((fighter['features'] as List).first, containsPair('_id', 'srd0'));
      final rage = converted[id('feat', 'Rage')]!['resource_pool_grants'];
      expect(rage, isA<List>());
      final goblin = converted[id('monster', 'Goblin Warrior')]!;
      expect(goblin['combat_stats'], {
        'hp': 7,
        'max_hp': 7,
        'ac': 12,
        'initiative': '1d20+2',
      });
      final acolyte = converted[id('background', 'Acolyte')]!;
      expect(acolyte['equipment_choice_groups'], isA<String>());
    });
  });

  group('guard (G7)', () {
    test('every filled field is declared in the copy, but the leftovers '
        'of later phases', () {
      // A5 takes the class slot override out, A6 the monster flat values.
      const leftovers = {
        'class': {'spell_slots_by_level'},
        'monster': {'ac', 'hp_average', 'initiative_modifier'},
        'animal': {'ac', 'hp_average', 'initiative_modifier'},
      };
      final found = <String, Set<String>>{};
      for (final c in raw.values.where((c) => converted.containsKey(c.id))) {
        final cat = cats[c.categorySlug];
        expect(cat, isNotNull, reason: c.categorySlug);
        final keys = {for (final f in cat!.fields) f.fieldKey};
        converted[c.id]!.forEach((k, v) {
          if (!blank(v) && !keys.contains(k)) {
            (found[c.categorySlug] ??= {}).add(k);
          }
        });
      }
      expect(found, leftovers);
    });

    test('no card links a category the copy lacks', () {
      final missing = <String>{};
      void walk(Object? v, String at) {
        if (v is Map) {
          final slug = v['_lookup'];
          if (slug is String && !cats.containsKey(slug)) missing.add('$at → $slug');
          for (final x in v.values) {
            walk(x, at);
          }
        } else if (v is List) {
          for (final x in v) {
            walk(x, at);
          }
        } else if (v is String) {
          final target = raw[v];
          if (target != null && !cats.containsKey(target.categorySlug)) {
            missing.add('$at → ${target.categorySlug}');
          }
        }
      }

      for (final c in raw.values.where((c) => converted.containsKey(c.id))) {
        walk(converted[c.id], '${c.categorySlug} / ${c.name}');
      }
      expect(missing, isEmpty);
    });

    test('a closed category has the field count of §5', () {
      const targets = {'spell': 10};
      expect(freeSrdClosed, targets.keys.toSet());
      expect({for (final s in targets.keys) s: cats[s]!.fields.length}, targets);
    });

    test('every field the copy adds is filled in some card', () {
      final withCards = {for (final c in raw.values) c.categorySlug};
      final empty = <String>[];
      for (final cat in srdFreeTemplate.categories) {
        if (!withCards.contains(cat.slug)) continue;
        final had = {for (final f in builtin[cat.slug]!.fields) f.fieldKey};
        for (final f in cat.fields) {
          if (had.contains(f.fieldKey)) continue;
          final filled = raw.values.any(
            (c) =>
                c.categorySlug == cat.slug &&
                !blank(converted[c.id]![f.fieldKey]),
          );
          if (!filled) empty.add('${cat.slug} / ${f.fieldKey}');
        }
      }
      expect(empty, isEmpty);
    });
  });

  group('A2 spell', () {
    // §5.1; the PDF's lines, but where the pack deviates (K13): Counterspell's
    // trigger is shorter, Bless's material is the 2014 one.
    const lines = {
      'Fireball': [
        'Action',
        '150 feet',
        'V, S, M (a ball of bat guano and sulfur)',
        'Instantaneous',
      ],
      'Counterspell': [
        'Reaction, which you take when you see a creature within 60 feet of '
            'yourself casting a spell',
        '60 feet',
        'S',
        'Instantaneous',
      ],
      'Shield': [
        'Reaction, which you take when you are hit by an attack roll or '
            'targeted by the Magic Missile spell',
        'Self',
        'V, S',
        '1 round',
      ],
      'Identify': [
        '1 minute or Ritual',
        'Touch',
        'V, S, M (a pearl worth 100+ GP)',
        'Instantaneous',
      ],
      'Raise Dead': [
        '1 hour',
        'Touch',
        'V, S, M (a diamond worth 500+ GP, which the spell consumes)',
        'Instantaneous',
      ],
      'Bless': [
        'Action',
        '30 feet',
        'V, S, M (a sprinkling of holy water)',
        'Concentration, up to 1 minute',
      ],
      'Sequester': [
        'Action',
        'Touch',
        'V, S, M (gem dust worth 5,000+ GP, which the spell consumes)',
        'Until dispelled',
      ],
      'Wish': ['Action', 'Self', 'V', 'Instantaneous'],
      'Fire Bolt': ['Action', '120 feet', 'V, S', 'Instantaneous'],
      // The cost is in no text (R4); the range was "Special".
      'Find Familiar': [
        '1 hour or Ritual',
        '10 feet',
        'V, S, M (charcoal, incense, and herbs that must be consumed by fire '
            'in a brass brazier, worth 10+ GP)',
        'Instantaneous',
      ],
      'Dream': [
        '1 minute',
        'Special',
        'V, S, M (a handful of sand, a dab of ink, and a writing quill '
            'plucked from a sleeping bird)',
        '8 hours',
      ],
    };
    const keys = ['casting_time', 'range', 'components', 'duration'];

    test('the header lines read as the SRD writes them', () {
      for (final MapEntry(key: name, value: want) in lines.entries) {
        final s = converted[id('spell', name)]!;
        expect([for (final k in keys) s[k]], want, reason: name);
      }
    });

    test('every spell has its four lines and only the copy\'s fields', () {
      final fields = [for (final f in cats['spell']!.fields) f.fieldKey];
      expect(fields, [
        'level',
        'school_ref',
        'class_refs',
        ...keys,
        'is_ritual',
        'requires_concentration',
        'description',
      ]);
      final spells = raw.values.where((c) => c.categorySlug == 'spell');
      expect(spells, hasLength(341));
      for (final c in spells) {
        final s = converted[c.id]!;
        for (final k in keys) {
          expect(s[k], isA<String>().having((v) => v.isEmpty, 'empty', false),
              reason: '${c.name} / $k');
        }
        expect(s.keys.toSet().difference(fields.toSet()), isEmpty,
            reason: c.name);
      }
    });

    test('the description goes, and it was only the rules text again (S1)',
        () {
      for (final c in raw.values.where((c) => c.categorySlug == 'spell')) {
        expect(c.description, c.fields['description'], reason: c.name);
        expect(freeSrdDescription(c), '');
      }
    });

    test('the unit and component lookups leave the copy and the package', () {
      for (final slug in ['duration-unit', 'casting-time-unit',
          'casting-component']) {
        expect(cats.containsKey(slug), isFalse, reason: slug);
        expect(inFreeSrd(slug), isFalse);
      }
      expect(build.seedRows.keys, contains('duration-unit'));
    });
  });
}
