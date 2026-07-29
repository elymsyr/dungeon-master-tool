import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// **One mechanic ⇒ exactly one field.**
///
/// The old engine let the same mechanic be written three ways (a `rule_effects`
/// row, a `granted_modifiers` row, or a named field), so an author could not
/// tell which one the sheet would actually read. The grant block replaced all
/// of that with a closed set of plainly named fields.
///
/// This file guards that property structurally — schema, resolver and shipped
/// content have to agree — while `grant_field_isolation_test.dart` proves the
/// behavioural half (one field moves one number).
void main() {
  final build = generateBuiltinDnd5eV2Schema();
  final schema = build.schema;
  final pack = buildSrdCorePack();

  Set<String> declaredKeys(String slug) => schema.categories
      .firstWhere((c) => c.slug == slug)
      .fields
      .map((f) => f.fieldKey)
      .toSet();

  Map<String, EntityCategorySchema> byslug = {
    for (final c in schema.categories) c.slug: c,
  };

  group('grant contract — schema side', () {
    test('every contract key is editable on a Feat card', () {
      // `feat` is the one category that takes the whole block, so it is the
      // proof that no contract key is resolver-only (readable but with no
      // field a DM can fill in).
      final missing =
          CharacterResolver.grantFieldKeys.difference(declaredKeys('feat'));
      expect(missing, isEmpty,
          reason: 'grant keys with no schema field — invisible in the editor');
    });

    test('every field type the schema uses has a real editor', () {
      // The widget factory ends in `_ => _TextFieldWidget`, so a new
      // FieldType without its own arm does not crash — it quietly renders as
      // a text box and the structured value is unauthorable. Adding
      // `spellsAtLevel` without its widget looked exactly like that.
      final factory = File(
        'lib/presentation/widgets/field_widgets/field_widget_factory.dart',
      ).readAsStringSync();
      final arms = RegExp(r'FieldType\.([A-Za-z_]+)\s*=>')
          .allMatches(factory)
          .map((m) => m.group(1)!)
          .toSet();
      // A float is a number in a box; the generic text input is the editor.
      const textIsTheEditor = {'float_'};
      final used = <String>{
        for (final c in schema.categories)
          for (final f in c.fields) f.fieldType.name,
      };
      expect(used.difference(arms).difference(textIsTheEditor), isEmpty,
          reason: 'field type with no editor — falls through to a text box');
    });

    test('every grant field on every category is in the contract', () {
      // The inverse: a category must not offer a grant-looking field the
      // resolver has never heard of, which would silently do nothing.
      final offenders = <String>[];
      for (final c in schema.categories) {
        for (final f in c.fields) {
          final k = f.fieldKey;
          if (!k.startsWith('granted_') &&
              !k.startsWith('unarmored_ac_') &&
              !k.startsWith('active_while_')) {
            continue;
          }
          if (CharacterResolver.grantFieldKeys.contains(k)) continue;
          // Class/background name their own unconditional grants; these are
          // read by the class and background passes, not by the grant block.
          if (const {
            // Class / background name their own unconditional grants.
            'granted_skill_refs',
            'granted_tool_refs',
            'granted_languages',
            'granted_language_count',
            'granted_tool_variant_group',
            // Not grants at all — `granted_` here reads as "included in".
            'granted_at_level',
            'granted_magic_items',
          }.contains(k)) {
            continue;
          }
          offenders.add('${c.slug}.$k');
        }
      }
      expect(offenders, isEmpty,
          reason: 'grant-shaped field outside the contract — nothing reads it');
    });

    test('no category offers two fields for the same mechanic', () {
      // The exact failure mode the rule removal was aimed at: an author
      // opening one card and finding two places to type the same thing.
      const synonyms = <String, List<String>>{
        'skill proficiency': [
          'granted_skill_proficiencies',
          'granted_skill_refs',
        ],
        'tool proficiency': [
          'granted_tool_proficiencies',
          'granted_tool_refs',
        ],
        'saving throw proficiency': [
          'granted_save_proficiencies',
          'saving_throw_refs',
        ],
        'weapon proficiency': [
          'granted_weapon_proficiencies',
          'weapon_proficiency_categories',
        ],
        'armor proficiency': [
          'granted_armor_proficiencies',
          'armor_training_refs',
        ],
        'flat spell grant': ['granted_spell_refs', 'granted_spells'],
      };
      final clashes = <String>[];
      for (final c in schema.categories) {
        final keys = c.fields.map((f) => f.fieldKey).toSet();
        synonyms.forEach((mechanic, names) {
          final hit = names.where(keys.contains).toList();
          if (hit.length > 1) clashes.add('${c.slug}: $mechanic → $hit');
        });
      }
      expect(clashes, isEmpty,
          reason: 'two fields for one mechanic on the same card');
    });

    test('the retired effect DSLs are gone from every category', () {
      // `effects` survives as a field *name* in three unrelated places — the
      // Tier-0 glossary body, a magic item's narrative text, and the separate
      // spell/creature-action `spellEffectList` (explicitly out of scope).
      // What must be gone is the per-card rule language: the `rule_effects` /
      // `granted_modifiers` keys anywhere, and `effects` on a Feat.
      const retired = {'rule_effects', 'granted_modifiers', 'feat_effects'};
      final found = <String>[];
      for (final c in schema.categories) {
        for (final f in c.fields) {
          if (retired.contains(f.fieldKey)) found.add('${c.slug}.${f.fieldKey}');
          if (c.slug == 'feat' && f.fieldKey == 'effects') {
            found.add('feat.effects');
          }
        }
      }
      expect(found, isEmpty);
      // The field *types* that rendered those editors are gone too, so the
      // shape cannot come back through a custom template either.
      final typeNames = FieldType.values.map((t) => t.name).toSet();
      expect(typeNames, isNot(contains('featEffectList')));
      expect(typeNames, isNot(contains('grantedModifiers')));
    });
  });

  group('grant contract — resolver side', () {
    test('the grant reader touches no key outside the contract', () {
      // Source-level guard: `granted_spells_at_level` was read here for months
      // while being absent from both the contract and the schema, so nobody
      // could author it. Reading the source is the only way to catch the next
      // one before it ships.
      final src =
          File('lib/domain/services/character_resolver.dart').readAsStringSync();
      const startMark = 'void applyResourcePools(';
      const endMark = '// ── 4b. Auto-grant walker';
      final start = src.indexOf(startMark);
      final end = src.indexOf(endMark);
      expect(start, greaterThan(-1),
          reason: 'marker moved — update this test, not the marker');
      expect(end, greaterThan(start),
          reason: 'marker moved — update this test, not the marker');
      final body = src.substring(start, end);

      final keys = RegExp(r"(?<![A-Za-z0-9_])f\['([a-z_]+)'\]")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet()
        // Not a card field: the unarmored-formula entry the reader itself
        // built a few lines earlier.
        ..remove('payload');
      final unknown = keys.difference(CharacterResolver.grantFieldKeys);
      expect(unknown, isEmpty,
          reason: 'read by the resolver but not in grantFieldKeys');
    });
  });

  group('grant contract — content side', () {
    test('every attribute the SRD authors has a field on its category', () {
      // Anything not declared cannot be seen or edited in the app, and the
      // importer drops it on the next round-trip.
      final offenders = <String>[];
      for (final raw in pack.entities.values) {
        final row = raw as Map;
        final slug = row['type'] as String;
        final cat = byslug[slug];
        if (cat == null) {
          offenders.add('unknown category $slug');
          continue;
        }
        final allowed = cat.fields.map((f) => f.fieldKey).toSet();
        for (final key in (row['attributes'] as Map).keys) {
          if (!allowed.contains(key)) {
            offenders.add('$slug.${row['name']} → $key');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('no shipped card still carries a retired DSL row', () {
      // Same scoping as the schema check: `effects` on a magic item is the
      // narrative blurb, on a spell it is the (kept) spell DSL. The per-card
      // rule language is what must be absent.
      const retired = {'rule_effects', 'granted_modifiers'};
      final offenders = <String>[];
      for (final raw in pack.entities.values) {
        final row = raw as Map;
        final slug = row['type'] as String;
        for (final key in (row['attributes'] as Map).keys) {
          if (retired.contains(key) || (slug == 'feat' && key == 'effects')) {
            offenders.add('$slug.${row['name']} → $key');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('no bundled pack asset ships a retired DSL row', () {
      // The built-in SRD pack is Dart source and moved with the removal; the
      // Open5e packs are pre-generated JSON assets that did not, and sat on
      // the old shape for months. `PackagePayloadImporter` converts them on
      // install so they worked, which is exactly why nobody noticed.
      // `tool/migrate_pack_assets.dart` brings them forward.
      final dir = Directory('assets/open5e_packs');
      expect(dir.existsSync(), isTrue,
          reason: 'bundled packs missing — this test would pass vacuously');

      final offenders = <String>[];
      var scanned = 0;
      for (final file in dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pkg.json'))) {
        final root = jsonDecode(file.readAsStringSync());
        final entities = (root as Map)['entities'];
        if (entities is! Map) continue;
        for (final row in entities.values) {
          if (row is! Map) continue;
          final attrs = row['attributes'];
          if (attrs is! Map) continue;
          scanned++;
          final slug = row['type']?.toString() ?? '';
          for (final key in const ['rule_effects', 'granted_modifiers']) {
            if (attrs.containsKey(key)) {
              offenders.add('${file.uri.pathSegments.last}: '
                  '$slug/${row['name']} → $key');
            }
          }
          // `effects` is still live as a magic item's narrative blurb and as
          // the spell / creature-action `spellEffectList`. Anywhere else, a
          // list of `{kind: …}` rows is the retired feat DSL.
          const liveEffects = {'magic-item', 'spell', 'creature-action'};
          final effects = attrs['effects'];
          if (!liveEffects.contains(slug) &&
              effects is List &&
              effects.any((r) => r is Map && r.containsKey('kind'))) {
            offenders.add('${file.uri.pathSegments.last}: '
                '$slug/${row['name']} → effects');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'run `dart run tool/migrate_pack_assets.dart`');
      expect(scanned, greaterThan(1000),
          reason: 'scanned too few rows to mean anything');
    });

    test('grant keys the SRD uses are a subset of the contract', () {
      final used = <String>{};
      for (final raw in pack.entities.values) {
        used.addAll(((raw as Map)['attributes'] as Map)
            .keys
            .map((k) => k.toString())
            .where(CharacterResolver.grantFieldKeys.contains));
      }
      expect(used.difference(CharacterResolver.grantFieldKeys), isEmpty);
      // Sanity: the shipped content really does exercise the block, so this
      // test cannot pass by finding nothing.
      expect(used.length, greaterThan(20));
    });
  });
}
