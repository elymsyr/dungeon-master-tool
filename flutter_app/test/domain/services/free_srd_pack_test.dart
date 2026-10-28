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
            fields: Map<String, dynamic>.from(
              (r['fields'] as Map?) ?? const {},
            ),
          ),
    for (final MapEntry(:key, :value) in buildSrdCorePack().entities.entries)
      key: Entity(
        id: key,
        name: (value as Map)['name'] as String,
        categorySlug: value['type'] as String,
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
    for (final c in raw.values) c.id: freeSrdFields(c, raw),
  };
  // A card's fields as a world holds them: synthesis resolves every row's
  // placeholders (`buildBuiltinSrdEntities` leaves the Tier-0 rows' own).
  Map<String, dynamic> resolved(Map<String, dynamic> fields) =>
      PackageImportService.resolveLookupPlaceholder(fields, tier0)
          as Map<String, dynamic>;
  Map<String, dynamic> stored(String id) => resolved(converted[id]!);
  final cats = {for (final c in srdFreeTemplate.categories) c.slug: c};

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
        for (final f in cat.fields) {
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
      String id(String slug, String name) => raw.values
          .firstWhere((e) => e.categorySlug == slug && e.name == name)
          .id;
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
      for (final c in raw.values) {
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

      for (final c in raw.values) {
        walk(converted[c.id], '${c.categorySlug} / ${c.name}');
      }
      expect(missing, isEmpty);
    });

    test('every field the copy adds is filled in some card', () {
      final builtin = {for (final c in build.schema.categories) c.slug: c};
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
}
