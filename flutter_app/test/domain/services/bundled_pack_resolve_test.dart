import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// **The bundled third-party packs actually resolve.**
///
/// `grant_contract_test` proves no bundled asset still ships a retired DSL row.
/// That is a statement about the file, not about the app: a pack could be free
/// of legacy keys and still grant nothing, because its `_lookup` placeholders
/// point at Tier-0 rows that do not exist, or because the converted field name
/// is one the resolver never reads.
///
/// This file closes that gap for the three packs `tool/migrate_pack_assets.dart`
/// rewrote. It walks the asset the way an install does — resolve every
/// `{_lookup, name}` placeholder against the campaign's Tier-0 rows, then hand
/// the entity to `CharacterResolver` — and asserts the mechanic lands on the
/// sheet.
void main() {
  final srd = buildBuiltinSrdEntities();

  /// `tier0NameToId[slug][rowName] = uuid`, exactly the map
  /// `PackageImportService` builds at import time.
  final tier0 = <String, Map<String, String>>{};
  for (final e in srd.values) {
    tier0.putIfAbsent(e.categorySlug, () => <String, String>{})[e.name] = e.id;
  }

  /// Load a bundled pack and return its rows as [Entity]s with placeholders
  /// resolved, keyed by a synthetic id — i.e. what lands in the world after an
  /// install.
  Map<String, Entity> installPack(String assetName) {
    final file = File('assets/open5e_packs/$assetName');
    expect(file.existsSync(), isTrue, reason: 'missing asset $assetName');
    final root = jsonDecode(file.readAsStringSync()) as Map;
    final entities = root['entities'] as Map;
    final out = <String, Entity>{};
    entities.forEach((id, raw) {
      final row = raw as Map;
      final attrs = Map<String, dynamic>.from(
          (row['attributes'] as Map?) ?? const <String, dynamic>{});
      final resolved = <String, dynamic>{
        for (final e in attrs.entries)
          e.key: PackageImportService.resolveLookupPlaceholder(e.value, tier0),
      };
      out['$id'] = Entity(
        id: '$id',
        categorySlug: row['type']?.toString() ?? '?',
        name: row['name']?.toString() ?? '',
        fields: resolved,
      );
    });
    return out;
  }

  /// A subspecies names its parent as a cross-pack soft ref (`{slug, name}`),
  /// resolved by name at runtime — not by `resolveLookupPlaceholder`, which
  /// only rewrites Tier-0 `_lookup` envelopes. The wizard stores the id it
  /// resolves to, so the test has to do the same.
  String parentSpeciesId(Map<String, Entity> world, Entity sub) {
    final id = resolveEntityRef(sub.fields['parent_species_ref'], world);
    expect(id, isNotNull,
        reason: '${sub.name}: parent species '
            '${sub.fields['parent_species_ref']} is not installed');
    return id!;
  }

  Entity find(Map<String, Entity> world, String slug, String name) =>
      world.values.firstWhere(
        (e) => e.categorySlug == slug && e.name == name,
        orElse: () => throw StateError('missing $slug/$name'),
      );

  Character pc(Map<String, dynamic> fields) => Character(
        id: 'pc1',
        templateId: 'tpl',
        templateName: 'Tpl',
        worldId: 'w',
        createdAt: '0',
        updatedAt: '0',
        entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
          'base_abilities': const {
            'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10, //
          },
          ...fields,
        }),
      );

  group('open5e-toh (converted ability_score_bonus rows)', () {
    late final world = {...srd, ...installPack('open5e-toh.pkg.json')};

    test('Alseid grants DEX +2 / WIS +1 and Stealth proficiency', () {
      final alseid = find(world, 'species', 'Alseid');
      final eff = CharacterResolver.resolve(
        pc({'race_id': alseid.id}),
        world,
      );
      expect(eff.effectiveAbilities['DEX'], 12);
      expect(eff.effectiveAbilities['WIS'], 11);
      expect(eff.proficiencies.skillIds.map((i) => world[i]?.name),
          contains('Stealth'));
      expect(eff.warnings, isEmpty);
    });

    test('every converted species/subspecies bumps at least one ability', () {
      // 35 rows were converted; a silent failure would show up as a species
      // whose `ability_bonuses` map resolved to nothing.
      var checked = 0;
      for (final e in world.values) {
        if (e.categorySlug != 'species' && e.categorySlug != 'subspecies') {
          continue;
        }
        final bonuses = e.fields['ability_bonuses'];
        if (bonuses is! Map || bonuses.isEmpty) continue;
        checked++;
        final eff = e.categorySlug == 'species'
            ? CharacterResolver.resolve(pc({'race_id': e.id}), world)
            : CharacterResolver.resolve(
                pc({
                  'race_id': parentSpeciesId(world, e),
                  'subspecies_id': e.id,
                }),
                world,
              );
        final bumped = eff.effectiveAbilities.entries
            .where((x) => x.value != 10)
            .length;
        expect(bumped, greaterThan(0),
            reason: '${e.categorySlug}/${e.name} granted no ability bonus');
      }
      expect(checked, greaterThanOrEqualTo(30),
          reason: 'found too few converted rows to mean anything');
    });
  });

  group('open5e-a5e-ag (converted feat effect rows)', () {
    late final world = {...srd, ...installPack('open5e-a5e-ag.pkg.json')};

    test('Heavily Outfitted grants heavy armor proficiency', () {
      final feat = find(world, 'feat', 'Heavily Outfitted');
      final eff = CharacterResolver.resolve(
        pc({'feat_ids': [feat.id]}),
        world,
      );
      expect(eff.proficiencies.armorCategoryIds.map((i) => world[i]?.name),
          contains('Heavy'));
      expect(eff.warnings, isEmpty);
    });

    test('Moderately Outfitted grants both Medium and Shield', () {
      final feat = find(world, 'feat', 'Moderately Outfitted');
      final eff = CharacterResolver.resolve(
        pc({'feat_ids': [feat.id]}),
        world,
      );
      final names =
          eff.proficiencies.armorCategoryIds.map((i) => world[i]?.name).toList();
      expect(names, containsAll(['Medium', 'Shield']));
    });

    test('Crafting Expert still queues its deferred pick', () {
      // `choice_group` → `player_choices`: the row survives conversion in a
      // shape `pending_choices.dart` understands.
      final feat = find(world, 'feat', 'Crafting Expert');
      final rows = feat.fields['player_choices'];
      expect(rows, isA<List>());
      final row = (rows as List).single as Map;
      expect(row['pick'], 2);
      expect(row['pick_kind'], 'skill_or_tool');
      expect(row['group_id'], isNotEmpty);
    });
  });

  group('open5e-open5e (converted subspecies row)', () {
    late final world = {...srd, ...installPack('open5e-open5e.pkg.json')};

    test('Stoor Halfling grants CON +1', () {
      final sub = find(world, 'subspecies', 'Stoor Halfling');
      final eff = CharacterResolver.resolve(
        pc({
          'race_id': parentSpeciesId(world, sub),
          'subspecies_id': sub.id,
        }),
        world,
      );
      expect(eff.effectiveAbilities['CON'], 11);
    });
  });

  // L3: a magic item names the mundane weapon/armor it is built on with a
  // softRef into the built-in pack. The pack ships no base items itself, so
  // every one of these has to land on a built-in card or the link is dead.
  group('open5e-vom (base_item_ref)', () {
    late final pack = installPack('open5e-vom.pkg.json');
    late final world = {...srd, ...pack};

    test('her base_item_ref gömülü bir temel eşyaya çözülür', () {
      const allowed = {'weapon', 'armor', 'adventuring-gear'};
      final withRef = <Entity>[
        for (final e in pack.values)
          if (e.fields['base_item_ref'] != null) e,
      ];
      expect(withRef, hasLength(379));
      final broken = <String>[];
      for (final item in withRef) {
        final id = resolveEntityRef(item.fields['base_item_ref'], world);
        final target = id == null ? null : world[id];
        if (target == null || !allowed.contains(target.categorySlug)) {
          broken.add('${item.name} → ${item.fields['base_item_ref']}');
        }
      }
      expect(broken, isEmpty);
    });

    test('Akaasit Blade temel eşya olarak Dagger gösterir', () {
      final blade = find(world, 'magic-item', 'Akaasit Blade');
      final base =
          world[resolveEntityRef(blade.fields['base_item_ref'], world)];
      expect(base?.name, 'Dagger');
      expect(base?.categorySlug, 'weapon');
    });
  });

  group('placeholders in bundled packs point at rows that exist', () {
    test('no converted grant field resolves to an empty ref', () {
      // `resolveLookupPlaceholder` returns '' for a Tier-0 row the campaign
      // does not have — the grant then vanishes with no warning at install
      // time. Catch it here instead.
      final broken = <String>[];
      for (final asset in const [
        'open5e-toh.pkg.json',
        'open5e-a5e-ag.pkg.json',
        'open5e-open5e.pkg.json',
      ]) {
        final world = installPack(asset);
        for (final e in world.values) {
          for (final key in CharacterResolver.grantFieldKeys) {
            final v = e.fields[key];
            if (v is List && v.contains('')) {
              broken.add('$asset: ${e.categorySlug}/${e.name} → $key');
            }
          }
        }
      }
      expect(broken, isEmpty,
          reason: 'grant ref names a Tier-0 row the app does not ship');
    });
  });
}
