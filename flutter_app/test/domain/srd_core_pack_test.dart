import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/lookups.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pack = buildSrdCorePack();
  final build = generateBuiltinDnd5eV2Schema();

  group('SRD Core Pack — integrity', () {
    test('every entity has required wire fields', () {
      for (final entry in pack.entities.entries) {
        final id = entry.key;
        final row = entry.value as Map;
        expect(row['name'], isA<String>(),
            reason: '$id missing name');
        expect((row['name'] as String).isNotEmpty, true,
            reason: '$id has empty name');
        expect(row['type'], isA<String>(),
            reason: '$id missing type');
        expect(row['attributes'], isA<Map>(),
            reason: '$id missing attributes');
      }
    });

    test('every Tier-1 row\'s attribute keys ⊆ category fieldKeys', () {
      final categories = {
        for (final c in build.schema.categories) c.slug: c,
      };
      for (final entry in pack.entities.entries) {
        final row = entry.value as Map;
        final slug = row['type'] as String;
        final cat = categories[slug];
        expect(cat, isNotNull,
            reason: 'unknown slug $slug for entity ${row['name']}');
        final allowedKeys = cat!.fields.map((f) => f.fieldKey).toSet();
        final attrs = row['attributes'] as Map;
        for (final key in attrs.keys) {
          expect(allowedKeys.contains(key), true,
              reason:
                  'entity ${row['name']} ($slug) has unknown attribute "$key"');
        }
      }
    });

    test('every _lookup placeholder names a real Tier-0 seeded row', () {
      final tier0Names = <String, Set<String>>{
        for (final entry in build.seedRows.entries)
          entry.key: {
            for (final r in entry.value)
              if (r['name'] is String) r['name'] as String,
          },
      };

      final problems = <String>[];
      void walk(dynamic value, String entityName) {
        if (value is Map) {
          final lookup = value['_lookup'];
          final name = value['name'];
          if (lookup is String && name is String) {
            if (!tier0Slugs.contains(lookup)) {
              problems.add(
                  '$entityName: _lookup "$lookup" is not a Tier-0 slug');
            } else if (!(tier0Names[lookup]?.contains(name) ?? false)) {
              problems.add(
                  '$entityName: _lookup $lookup → "$name" not in seed rows');
            }
            return;
          }
          for (final v in value.values) {
            walk(v, entityName);
          }
        } else if (value is List) {
          for (final v in value) {
            walk(v, entityName);
          }
        }
      }

      for (final entry in pack.entities.entries) {
        final row = entry.value as Map;
        walk(row['attributes'], row['name'] as String);
      }
      expect(problems, isEmpty);
    });

    test('every _ref placeholder is resolved (no leftover refs)', () {
      final problems = <String>[];
      void walk(dynamic value, String entityName) {
        if (value is Map) {
          if (value['_ref'] is String) {
            problems.add('$entityName: leftover _ref ${value['_ref']} → '
                '${value['name']}');
            return;
          }
          for (final v in value.values) {
            walk(v, entityName);
          }
        } else if (value is List) {
          for (final v in value) {
            walk(v, entityName);
          }
        }
      }

      for (final entry in pack.entities.entries) {
        final row = entry.value as Map;
        walk(row['attributes'], row['name'] as String);
      }
      expect(problems, isEmpty);
    });

    test('metadata carries SRD attribution + license + source tag', () {
      expect(pack.metadata['attribution'], isA<String>());
      expect(pack.metadata['license'], 'CC-BY-4.0');
      expect(pack.metadata['source'], 'SRD 5.2.1');
    });
  });
}
