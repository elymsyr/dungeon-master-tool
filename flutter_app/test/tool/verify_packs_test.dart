import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/open5e_import/verify.dart';

/// **Audit phase T1 — the source ⟷ asset verifier.**
///
/// The other three census binaries (`audit_packs`, `dupe_census`, `diff_packs`)
/// ship without tests: they count what is there, so a wrong count shows up in
/// the output. This one *judges*, and a verifier that quietly mis-judges is
/// worse than no verifier — the first run of it against the real corpus produced
/// 893 "disagreements" of which **every single one was a bug in the rule table**,
/// not in a mapper:
///
///   * the app pluralises its magic-item categories (`scroll` → "Scrolls");
///   * upstream writes class abilities as three-letter codes (`['wis','con']`);
///   * a5e calls transmutation "transformation";
///   * class hit dice are written `D10`, capitalised and countless;
///   * B9's pack-local Tier-0 rows are referenced by **resolved uuid**, not by a
///     `{_lookup, name}` placeholder, so a name comparison has to follow the id.
///
/// So the judgement matrix is pinned here over a hand-built one-document corpus:
/// every verdict is provoked at least once, and each of those five folds gets a
/// case that fails if the leniency is dropped.
void main() {
  late Directory root;
  late String dataDir;
  late String packDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('verify_packs_test');
    dataDir = p.join(root.path, 'data');
    packDir = p.join(root.path, 'packs');
    Directory(packDir).createSync(recursive: true);
    final docDir = p.join(dataDir, 'v2', 'test-pub', 'doc');
    Directory(docDir).createSync(recursive: true);
    _writeJson(p.join(docDir, 'Document.json'), [
      {
        'pk': 'doc',
        'fields': {
          'name': 'Test Doc',
          'publisher': 'open5e',
          'licenses': ['ogl-10a'],
          'gamesystem': '5e-2014',
        },
      },
    ]);
  });

  tearDown(() => root.deleteSync(recursive: true));

  void writeFixtures(String file, List<Map<String, dynamic>> rows) =>
      _writeJson(p.join(dataDir, 'v2', 'test-pub', 'doc', file), [
        for (final (i, f) in rows.indexed) {'pk': '$file$i', 'fields': f},
      ]);

  void writePack(List<Map<String, dynamic>> entities) => _writeJson(
        p.join(packDir, 'open5e-doc.pkg.json'),
        {
          'package_name': 'open5e-doc',
          'metadata': const <String, dynamic>{},
          'entities': {
            for (final (i, e) in entities.indexed) e['_id'] ?? 'e$i': e,
          },
        },
      );

  /// A fixture creature with every column the `monster` rules read filled.
  Map<String, dynamic> creature(String name, Map<String, dynamic> extra) => {
        'name': name,
        'size': 'medium',
        'type': 'humanoid',
        'armor_class': 15,
        'hit_points': 30,
        'hit_dice': '4d8+8',
        'walk': 30,
        'challenge_rating': 2,
        'languages': const <String>[],
        ...extra,
      };

  /// The entity a faithful mapper would build from [creature].
  Map<String, dynamic> monster(String name, Map<String, dynamic> attrs) => {
        'name': name,
        'type': 'monster',
        'attributes': {
          'ac': 15,
          'hp_average': 30,
          'hp_dice': '4d8+8',
          'speed_walk_ft': 30,
          'cr': '2',
          'size_ref': {'_lookup': 'size', 'name': 'Medium'},
          'creature_type_ref': {'_lookup': 'creature-type', 'name': 'Humanoid'},
          ...attrs,
        },
      };

  VerifyReport run({Set<String> only = const {}}) => verifyPacks(
        dataRoot: dataDir,
        packDir: packDir,
        only: only,
        examples: 3,
      );

  test('a faithfully mapped corpus is clean', () {
    writeFixtures('Creature.json', [creature('Goblin', const {})]);
    writePack([monster('Goblin', const {})]);

    final r = run();
    expect(r.count(Verdict.disagree), 0);
    expect(r.count(Verdict.absent), 0);
    expect(r.count(Verdict.unsourced), 0);
    expect(r.count(Verdict.ok), greaterThan(6));
    expect(r.coverageRows['open5e-doc|monster'], [1, 1, 1]);
  });

  test('a wrong value is a disagreement, with both sides in the example', () {
    writeFixtures('Creature.json', [creature('Goblin', {'armor_class': 15})]);
    writePack([monster('Goblin', const {'ac': 12})]);

    final r = run();
    expect(r.count(Verdict.disagree), 1);
    expect(r.count(Verdict.disagree, slug: 'monster', field: 'ac'), 1);
    expect(r.examplesFor(Verdict.disagree, 'monster', 'ac').single,
        'open5e-doc/Goblin: pack 12 ≠ source 15');
  });

  test('a value the source has and the pack lost is `absent`', () {
    writeFixtures(
        'Creature.json', [creature('Goblin', {'armor_detail': 'chain shirt'})]);
    writePack([monster('Goblin', const {})]);

    final r = run();
    expect(r.count(Verdict.absent, slug: 'monster', field: 'ac_note'), 1);
    expect(r.count(Verdict.disagree), 0);
    expect(r.examplesFor(Verdict.absent, 'monster', 'ac_note').single,
        contains('source chain shirt, pack (absent)'));
  });

  test('a value the pack invented is `unsourced` — the ⚠-const catcher', () {
    // The real finding this reproduces: `open5e-bfrd` has `hit_dice: null` on
    // all 360 of its creatures and the pack ships the mapper's `'1d4'` fallback
    // for every one, which `audit_packs` counts as 100% filled.
    writeFixtures('Creature.json', [
      creature('Goblin', const {'hit_dice': null}),
    ]);
    writePack([monster('Goblin', const {'hp_dice': '1d4'})]);

    final r = run();
    expect(r.count(Verdict.unsourced, slug: 'monster', field: 'hp_dice'), 1);
    expect(r.count(Verdict.disagree), 0);
    expect(r.examplesFor(Verdict.unsourced, 'monster', 'hp_dice').single,
        contains('pack 1d4, source (absent)'));
  });

  test('a field with no column at all is unsourced on every row', () {
    writeFixtures('MagicItem.json', [
      {
        'name': 'Bag of Holding',
        'category': 'wondrous-item',
        'rarity': 'uncommon',
      },
    ]);
    writePack([
      {
        'name': 'Bag of Holding',
        'type': 'magic-item',
        'attributes': {
          'is_cursed': false,
          'is_sentient': false,
          'activation': 'None',
          'rarity_ref': {'_lookup': 'rarity', 'name': 'Uncommon'},
          'magic_category_ref': {
            '_lookup': 'magic-item-category',
            'name': 'Wondrous Items',
          },
        },
      },
    ]);

    final r = run();
    expect(r.count(Verdict.unsourced, slug: 'magic-item'), 3,
        reason: 'is_cursed / is_sentient / activation have no source column');
    // …while the two fields that DO have a column agree, plural fold and all.
    expect(r.count(Verdict.disagree), 0);
  });

  test('a derived field is `unverifiable` and records its reason', () {
    writeFixtures('Creature.json', [
      creature('Goblin', const {'experience_points_integer': null}),
    ]);
    writePack([monster('Goblin', const {'xp': 450})]);

    final r = run();
    expect(r.count(Verdict.unsourced), 0,
        reason: 'a documented derivation is not a fabrication');
    expect(r.count(Verdict.unverifiable, slug: 'monster', field: 'xp'), 1);
    expect(r.reasonFor('monster', 'xp'), contains('CR→XP table'));
  });

  test('a list the pack partly dropped is `absent`, not a disagreement', () {
    writeFixtures('Creature.json', [
      creature('Goblin', const {
        'languages': ['common', 'void-speech'],
      }),
    ]);
    writePack([
      monster('Goblin', const {
        'language_refs': [
          {'_lookup': 'language', 'name': 'Common'},
        ],
      }),
    ]);

    final r = run();
    expect(r.count(Verdict.absent, slug: 'monster', field: 'language_refs'), 1);
    expect(r.count(Verdict.disagree), 0);
    expect(r.examplesFor(Verdict.absent, 'monster', 'language_refs').single,
        contains('drops part of source'));
  });

  test('a list member the source never listed IS a disagreement', () {
    writeFixtures('Creature.json', [
      creature('Goblin', const {
        'languages': ['common'],
      }),
    ]);
    writePack([
      monster('Goblin', const {
        'language_refs': [
          {'_lookup': 'language', 'name': 'Common'},
          {'_lookup': 'language', 'name': 'Draconic'},
        ],
      }),
    ]);

    expect(run().count(Verdict.disagree, slug: 'monster', field: 'language_refs'),
        1);
  });

  test('a pack-local Tier-0 row is followed by id, not read as a uuid', () {
    // B9 seeds genuinely-new third-party vocabulary as a pack-local Tier-0 row,
    // which pass 2 resolves to a bare uuid string. Comparing that string to
    // "void-speech" produced 89 false disagreements before the id index existed.
    writeFixtures('Creature.json', [
      creature('Goblin', const {
        'languages': ['void-speech'],
      }),
    ]);
    writePack([
      {
        '_id': 'seeded-id',
        'name': 'Void Speech',
        'type': 'language',
        'attributes': const <String, dynamic>{},
      },
      monster('Goblin', const {
        'language_refs': ['seeded-id'],
      }),
    ]);

    final r = run();
    expect(r.count(Verdict.disagree), 0);
    expect(r.count(Verdict.absent), 0);
  });

  test('the lookup-name fold survives case, slug punctuation and apostrophes',
      () {
    writeFixtures('Creature.json', [
      creature('Goblin', {
        'alignment': 'chaotic evil',
        'languages': const ['thieves-cant'],
      }),
    ]);
    writePack([
      monster('Goblin', const {
        'alignment_ref': {'_lookup': 'alignment', 'name': 'Chaotic Evil'},
        'language_refs': [
          {'_lookup': 'language', 'name': "Thieves' Cant"},
        ],
      }),
    ]);

    expect(run().count(Verdict.disagree), 0);
  });

  test('a5e\'s "transformation" school is not a disagreement', () {
    writeFixtures('Spell.json', [
      {
        'name': 'Haste',
        'level': 3,
        'school': 'transformation',
        'casting_time': 'action',
      },
    ]);
    writePack([
      {
        'name': 'Haste',
        'type': 'spell',
        'attributes': {
          'level': 3,
          'school_ref': {'_lookup': 'spell-school', 'name': 'Transmutation'},
          'is_ritual': false,
          'requires_concentration': false,
        },
      },
    ]);

    expect(run().count(Verdict.disagree), 0);
  });

  test('a capitalised, countless class hit die is read as a die size', () {
    writeFixtures('CharacterClass.json', [
      {
        'name': 'Marshal',
        'hit_dice': 'D10',
        'saving_throws': ['wis', 'con'],
        'primary_abilities': <String>[],
      },
    ]);
    writePack([
      {
        'name': 'Marshal',
        'type': 'class',
        'attributes': {
          'hit_die': 10,
          'saving_throw_refs': [
            {'_lookup': 'ability', 'name': 'Wisdom'},
            {'_lookup': 'ability', 'name': 'Constitution'},
          ],
        },
      },
    ]);

    final r = run();
    expect(r.count(Verdict.disagree), 0,
        reason: 'D10 → 10, and wis/con expand to full ability names');
    expect(r.count(Verdict.unsourced), 0);
  });

  test('"humanoid (elf)" splits into a type ref and a tags line', () {
    writeFixtures(
        'Creature.json', [creature('Elf Scout', const {'type': 'humanoid (elf)'})]);
    writePack([monster('Elf Scout', const {'tags_line': '(elf)'})]);

    final r = run();
    expect(r.count(Verdict.disagree), 0);
    expect(r.count(Verdict.unsourced), 0);
  });

  test('CR 0.5 is compared as the printed fraction', () {
    writeFixtures(
        'Creature.json', [creature('Goblin', const {'challenge_rating': 0.5})]);
    writePack([monster('Goblin', const {'cr': '1/2'})]);

    expect(run().count(Verdict.disagree), 0);
  });

  test('a speed of 0 upstream is an agreed absence, not a hole', () {
    writeFixtures('Creature.json', [creature('Goblin', const {'fly': 0})]);
    writePack([monster('Goblin', const {})]);

    final r = run();
    expect(r.count(Verdict.absent), 0);
    expect(r.count(Verdict.disagree), 0);
  });

  test('an entity with no fixture row is reported, never silently skipped', () {
    writeFixtures('Creature.json', [creature('Goblin', const {})]);
    writePack([
      monster('Goblin', const {}),
      monster('Ghost Of Upstream Past', const {}),
    ]);

    final r = run();
    expect(r.coverageRows['open5e-doc|monster'], [2, 1, 1]);
    expect(r.unmatchedIn('open5e-doc', 'monster'), ['Ghost Of Upstream Past']);
  });

  test('the "Npc: " prefix strip still finds the fixture row', () {
    writeFixtures(
        'Creature.json', [creature('Npc: Warlock Of The Genie Lord', const {})]);
    writePack([monster('Warlock of the Genie Lord', const {})]);

    final r = run();
    expect(r.unmatchedIn('open5e-doc', 'monster'), isEmpty);
    expect(r.count(Verdict.disagree), 0);
  });

  test('`only` narrows the categories checked', () {
    writeFixtures('Creature.json', [creature('Goblin', {'armor_class': 15})]);
    writeFixtures('MagicItem.json', [
      {'name': 'Bag of Holding', 'category': 'wondrous-item'},
    ]);
    writePack([
      monster('Goblin', const {'ac': 12}),
      {
        'name': 'Bag of Holding',
        'type': 'magic-item',
        'attributes': const {'is_cursed': false},
      },
    ]);

    final r = run(only: {'magic-item'});
    expect(r.count(Verdict.disagree), 0,
        reason: 'the monster disagreement is out of scope');
    expect(r.count(Verdict.unsourced), 1);
  });

  test('a pack with no source document is named, not silently passed', () {
    writeFixtures('Creature.json', [creature('Goblin', const {})]);
    _writeJson(p.join(packDir, 'open5e-ghost.pkg.json'), {
      'package_name': 'open5e-ghost',
      'entities': {'x': monster('Goblin', const {'ac': 1})},
    });
    writePack([monster('Goblin', const {})]);

    final r = run();
    expect(r.packsWithoutSource, ['open5e-ghost']);
    expect(r.count(Verdict.disagree), 0,
        reason: 'an unverifiable pack is skipped, not guessed at');
  });
}

void _writeJson(String path, Object value) =>
    File(path).writeAsStringSync(jsonEncode(value));
