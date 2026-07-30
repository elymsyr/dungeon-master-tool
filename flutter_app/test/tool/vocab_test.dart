import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';
import '../../tool/open5e_import/vocab.dart';

/// **Audit phase B9 — Open5e's own Tier-0 vocabulary becomes canon.**
///
/// Content fixtures point at Tier-0 rows by **fixture pk**, and `normalize.dart`
/// used to match those pks against the built-in canon by title-casing them. Two
/// things fall through that: a pk whose display name is not a mechanical
/// title-casing (`thieves-cant` → `Thieves' Cant`, which the built-in pack *does*
/// ship) and genuinely new third-party vocabulary (`void-speech`, `titanic`).
/// Both used to land in `unmapped_report.json` with the field dropped.
///
/// These fixtures are the real upstream rows from the pinned snapshot
/// (`d4276c58`), trimmed to the fields the code reads.
void main() {
  late Directory root;

  /// Writes a Django-fixture file the way `loadFixtures` expects it.
  void writeVocab(String doc, String file, List<Map<String, dynamic>> rows) {
    final dir = Directory('${root.path}/v2/$doc')..createSync(recursive: true);
    File('${dir.path}/$file').writeAsStringSync(jsonEncode([
      for (final r in rows)
        {
          'model': 'api_v2.x',
          'pk': r['pk'],
          'fields': {...r}..remove('pk'),
        }
    ]));
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('b9-vocab');
    writeVocab('open5e/core', 'Language.json', [
      {'pk': 'common', 'name': 'Common', 'is_exotic': false, 'is_secret': false},
      {
        'pk': 'thieves-cant',
        'name': "Thieves' Cant",
        'is_exotic': false,
        'is_secret': true,
      },
    ]);
    writeVocab('open5e/core', 'Size.json', [
      {'pk': 'huge', 'name': 'Huge', 'space_diameter': 15.0,
        'suggested_hit_dice': 'd12'},
    ]);
    // Per-document extensions, in other publishers' directories.
    writeVocab('kobold-press/tob', 'Language.json', [
      {
        'pk': 'void-speech',
        'name': 'Void Speech',
        'desc': 'Void speech is a rename of Deep Speech from Tome of Beasts.',
        'is_exotic': true,
        'is_secret': false,
        'script_language': null,
      },
    ]);
    writeVocab('en-publishing/a5e-mm', 'Size.json', [
      {'pk': 'titanic', 'name': 'Titanic', 'rank': 7, 'space_diameter': 25.0,
        'suggested_hit_dice': 'd20'},
    ]);
    writeVocab('en-publishing/a5e-ag', 'Condition.json', [
      {'pk': 'a5e-ag_bloodied', 'name': 'Bloodied'},
    ]);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// A normalizer wired the way `build_packs` wires it, plus the pack the
  /// seeder writes into.
  (Normalizer, PackBuilder) wired() {
    final pack = PackBuilder('test-pack');
    final norm = Normalizer()..vocab = Vocabulary.load(root.path);
    norm.tier0Seeder = (slug, name) => seedTier0Row(pack, norm.vocab,
        slug: slug, name: name, source: 'Test Doc');
    return (norm, pack);
  }

  Map<String, dynamic> onlyEntity(PackBuilder pack, String type) =>
      Map<String, dynamic>.from(pack.entities.values
          .cast<Map>()
          .singleWhere((e) => e['type'] == type));

  test('reads vocabulary from every publisher, not just the core document', () {
    final v = Vocabulary.load(root.path);
    expect(v.name('language', 'void-speech'), 'Void Speech');
    expect(v.name('size', 'titanic'), 'Titanic');
    expect(v.name('language', 'common'), 'Common');
  });

  test('indexes a pk with its document prefix stripped', () {
    final v = Vocabulary.load(root.path);
    expect(v.name('condition', 'a5e-ag_bloodied'), 'Bloodied');
    expect(v.name('condition', 'bloodied'), 'Bloodied');
    // The display name itself is an alias too.
    expect(v.name('condition', 'BLOODIED'), 'Bloodied');
  });

  test('Environment has no Tier-0 home and is not read', () {
    writeVocab('kobold-press/tob', 'Environment.json', [
      {'pk': 'tob_badlands', 'name': 'Badlands'},
    ]);
    final v = Vocabulary.load(root.path);
    expect(v.name('environment', 'tob_badlands'), isNull);
  });

  test("a pk the built-in canon holds under another spelling maps to it, "
      'and ships nothing new', () {
    final (norm, pack) = wired();
    // `titleCase('thieves-cant')` is "Thieves Cant" — the apostrophe is only
    // knowable from the fixture.
    expect(norm.lookupRef('language', 'thieves-cant'),
        {'_lookup': 'language', 'name': "Thieves' Cant"});
    expect(pack.entities, isEmpty);
    expect(norm.unmapped.isEmpty, isTrue);
  });

  test('genuinely new vocabulary is seeded into the pack and hard-refs it', () {
    final (norm, pack) = wired();
    final r = norm.lookupRef('language', 'void-speech');
    expect(r, {'_ref': 'language', 'name': 'Void Speech'});
    expect(norm.unmapped.isEmpty, isTrue);

    final row = onlyEntity(pack, 'language');
    expect(row['name'], 'Void Speech');
    expect(row['source'], 'Test Doc');
    // `is_exotic` is Open5e's only tier signal.
    expect((row['attributes'] as Map)['tier'], 'Rare');
    expect((row['attributes'] as Map)['summary'],
        contains('rename of Deep Speech'));

    // The ref is build-gated: pass 2 resolves it to the seeded id.
    expect(pack.resolveRefs(), isEmpty);
  });

  test('size carries the scalar columns upstream states', () {
    final (norm, pack) = wired();
    expect(norm.lookupRef('size', 'titanic'),
        {'_ref': 'size', 'name': 'Titanic'});
    final attrs = onlyEntity(pack, 'size')['attributes'] as Map;
    expect(attrs['space_ft'], 25.0);
    expect(attrs['hit_die_size'], 20); // from 'd20'
    // Extrapolated from the built-in ladder (L 2, H 4, G 8) — the one derived
    // value B9 writes, and only above Gargantuan's 20 ft.
    expect(attrs['carrying_multiplier'], 16.0);
  });

  test('seeding is idempotent per (slug, name)', () {
    final (norm, pack) = wired();
    norm.lookupRefList('language', ['void-speech', 'void-speech', 'common']);
    expect(pack.entities.values.where((e) => (e as Map)['type'] == 'language'),
        hasLength(1));
  });

  test('a value the built-in canon already has never consults the vocabulary',
      () {
    final (norm, pack) = wired();
    expect(norm.lookupRef('language', 'common'),
        {'_lookup': 'language', 'name': 'Common'});
    expect(norm.lookupRef('size', 'huge'), {'_lookup': 'size', 'name': 'Huge'});
    expect(pack.entities, isEmpty);
  });

  test('a value no fixture defines is still unmapped', () {
    final (norm, pack) = wired();
    expect(norm.lookupRef('language', 'klingon', context: 'Worf'), isNull);
    expect(pack.entities, isEmpty);
    expect(norm.unmapped.toJson()['language'],
        [{'value': 'klingon  (Worf)', 'count': 1}]);
  });

  test('without a seeder the old drop-and-log behaviour is unchanged', () {
    final norm = Normalizer()..vocab = Vocabulary.load(root.path);
    expect(norm.lookupRef('language', 'void-speech'), isNull);
    expect(norm.unmapped.isEmpty, isFalse);
  });
}
