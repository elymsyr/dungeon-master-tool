import 'package:dungeon_master_tool/domain/services/world_blueprint_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// `{lookup, match, value}` blueprint ref'i.
Map<String, dynamic> lk(String slug, String value) =>
    {'lookup': slug, 'match': 'name', 'value': value};

Map<String, dynamic> world(Map<String, List<Map<String, dynamic>>> cats) => {
      'categories': {
        for (final e in cats.entries)
          e.key: [
            for (final m in e.value) {'mapping': m},
          ],
      },
    };

WorldBlueprintConverter build({
  Map<String, Set<String>> fieldKeys = const {},
  Map<String, Map<String, Set<String>>> relationTargets = const {},
}) =>
    WorldBlueprintConverter(
      packageName: 'test-pack',
      sourceTitle: 'Test',
      tier0Slugs: const {'language', 'damage-type'},
      contentSlugs: const {'weapon', 'trait', 'npc', 'player-character'},
      knownNames: const {
        'language': {'Common'},
        'damage-type': {'Slashing'},
        'weapon': {'Longsword'},
      },
      fieldKeys: fieldKeys,
      relationTargets: relationTargets,
      mediaResolver: (rel) => rel == 'media/ok.webp' ? '/abs/media/ok.webp' : null,
    );

void main() {
  group('ref tiers', () {
    test('hand-written {slug, name} envelopes are validated, not trusted', () {
      // Regression: bunlar "zaten çözülmüş" sayılıp doğrulanmadan geçiriliyordu.
      // 99 Devils blueprint'inde `spell_refs` satırları
      // `{slug: 'gust-of-wind', name: 'Gust of Wind'}` — slug'da kategori değil
      // büyünün kendi adı — yazılmıştı; 26 NPC büyüsü/trait'i okuma anında
      // sessizce düşüyordu.
      final r = build().convert(
        worldBlueprint: world({
          'npc': [
            {
              'name': 'Guard',
              'trait_refs': [
                {'slug': 'gust-of-wind', 'name': 'Gust of Wind'},
              ],
            },
          ],
        }),
      );
      expect(r.hasErrors, isTrue);
      expect(r.errors.single.message, contains('gust-of-wind'));
    });

    test('a correct hand-written envelope still resolves', () {
      final r = build().convert(
        worldBlueprint: world({
          'npc': [
            {
              'name': 'Guard',
              'equipment_refs': [
                {'slug': 'weapon', 'name': 'Longsword', 'equipped': true},
              ],
            },
          ],
        }),
      );
      expect(r.hasErrors, isFalse);
      expect(r.entities.values.single['attributes']['equipment_refs'].single,
          {'slug': 'weapon', 'name': 'Longsword', 'equipped': true});
    });

    test('a ref outside the field\'s allowed relation targets errors', () {
      final r = build(
        relationTargets: const {
          'npc': {
            'equipment_refs': {'weapon'},
          },
        },
      ).convert(
        worldBlueprint: world({
          'trait': [
            {'name': 'Brave'},
          ],
          'npc': [
            {'name': 'Guard', 'equipment_refs': [lk('trait', 'Brave')]},
          ],
        }),
      );
      expect(r.hasErrors, isTrue);
      expect(r.errors.single.message, contains('only accepts weapon'));
    });

    test('Tier-0 seeded lookup → _lookup envelope, no issue', () {
      final r = build().convert(
        worldBlueprint: world({
          'npc': [
            {'name': 'Guard', 'language_refs': [lk('language', 'Common')]},
          ],
        }),
      );
      expect(r.hasErrors, isFalse);
      final npc = r.entities.values.single;
      expect(npc['attributes']['language_refs'].single,
          {'_lookup': 'language', 'name': 'Common'});
    });

    test('Tier-0 value declared in the blueprint resolves; undeclared errors',
        () {
      final ok = build().convert(
        worldBlueprint: world({
          'language': [
            {'name': 'Arabic'},
          ],
          'npc': [
            {'name': 'Guard', 'language_refs': [lk('language', 'Arabic')]},
          ],
        }),
      );
      expect(ok.hasErrors, isFalse);

      final bad = build().convert(
        worldBlueprint: world({
          'npc': [
            {'name': 'Guard', 'language_refs': [lk('language', 'Persian')]},
          ],
        }),
      );
      expect(bad.errors.single.field, 'language_refs[0]');
    });

    test('in-blueprint target → hard _ref; SRD target → soft {slug,name}', () {
      final r = build().convert(
        worldBlueprint: world({
          'weapon': [
            {'name': 'Cutlass'},
          ],
          'player-character': [],
        }),
        characterBlueprint: {
          'characters': [
            {
              'mapping': {
                'name': 'Pirate',
                'inventory': [
                  {...lk('weapon', 'Cutlass'), 'equipped': true},
                  lk('weapon', 'Longsword'),
                ],
              },
            },
          ],
        },
      );
      expect(r.hasErrors, isFalse);
      final pc = r.characters.single;
      expect(pc['fields']['inventory'], [
        {'_ref': 'weapon', 'name': 'Cutlass', 'equipped': true},
        {'slug': 'weapon', 'name': 'Longsword'},
      ]);
    });

    test('PCs land in characters, never in entities', () {
      // Regression: PC'ler world entity'si olarak yazılıyordu ve hiçbir
      // ekranda görünmüyorlardı — Database sekmesi `player-character`
      // kategorisini listesinden çıkarıyor, Characters sekmesi ise
      // `world_characters` okuyor.
      final r = build().convert(
        characterBlueprint: {
          'characters': [
            {
              'mapping': {'name': 'Pirate', 'imagePath': 'media/ok.webp'},
            },
          ],
        },
      );
      expect(r.hasErrors, isFalse);
      expect(r.entities, isEmpty);
      // `Entity.fromJson` bu biçimi bekliyor — wire satırının `type` /
      // `image_path` / `attributes` adlandırması değil.
      final pc = r.characters.single;
      expect(pc['categorySlug'], 'player-character');
      expect(pc['name'], 'Pirate');
      expect(pc['imagePath'], '/abs/media/ok.webp');
      expect(pc['fields'], isA<Map<String, dynamic>>());
      expect(pc['id'], isNotEmpty);
    });

    test('target in neither the blueprint nor the SRD pack is an error', () {
      final r = build().convert(
        worldBlueprint: world({
          'npc': [
            {'name': 'Guard', 'equipment_refs': [lk('weapon', 'Broadsword')]},
          ],
        }),
      );
      expect(r.errors.single.message, contains('unresolved ref'));
    });
  });

  test('a field the category schema does not declare is an error', () {
    final r = build(fieldKeys: {
      'npc': {'name', 'traits_md'},
    }).convert(
      worldBlueprint: world({
        'npc': [
          {'name': 'Guard', 'traits': 'sneaky'},
        ],
      }),
    );
    expect(r.errors.single.field, 'traits');
  });

  test('two entities sharing a name in one category is an error', () {
    // Ids are derived from `slug:name`, so the second row would overwrite
    // the first without a word.
    final r = build().convert(
      worldBlueprint: world({
        'weapon': [
          {'name': 'Cutlass'},
          {'name': 'Cutlass'},
        ],
      }),
    );
    expect(r.entities, hasLength(1));
    expect(r.errors.single.message, contains('duplicate name'));
  });

  test('media paths go through the resolver; a missing file is an error', () {
    final r = build().convert(
      worldBlueprint: world({
        'npc': [
          {'name': 'A', 'imagePath': 'media/ok.webp'},
          {'name': 'B', 'imagePath': 'media/gone.webp'},
        ],
      }),
    );
    final a = r.entities.values.firstWhere((e) => e['name'] == 'A');
    expect(a['image_path'], '/abs/media/ok.webp');
    expect(r.errors.single.message, contains('media file not found'));
  });

  test('ids are deterministic across runs', () {
    Map<String, Map<String, dynamic>> run() => build()
        .convert(worldBlueprint: world({
          'weapon': [
            {'name': 'Cutlass'},
          ],
        }))
        .entities;
    expect(run().keys, run().keys);
  });
}
