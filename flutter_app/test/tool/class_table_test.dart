import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B2 — the class-table columns B1 left behind.**
///
/// B1 correctly refused to emit a `ClassFeatureItem` column as 20 identical
/// "features" and filed the columns to B2. Nothing then picked them up, so 171
/// rows were dropped — and not silently: the owning `ClassFeature` carries no
/// prose of its own (`''` in `a5e-ag`, the literal `'[Column data]'` in
/// `bfrd`), so the fold shipped empty `### Maneuvers Known` headings and three
/// `[Column data]` paragraphs into the Marshal's and Mechanist's descriptions.
///
/// B2 was filed as `CORE_TRAITS_TABLE` + `column_value` →
/// `cantrips_known_by_level` / `prepared_spells_by_level` /
/// `spell_slots_by_level` / `extra_attack_count_by_level`. **None of that is
/// reachable**: on the pinned snapshot `CORE_TRAITS_TABLE` exists in exactly one
/// document (`srd-2024`) and `SPELL_SLOTS` in two (`srd-2014`, `srd-2024`) — all
/// of them skipped by the publisher-wide SRD rule. What actually ships is 7
/// bespoke columns across 2 classes with no schema field, so they are rendered
/// back into the description as a markdown table.
///
/// Fixture shapes are the real ones, trimmed to the fields the mapper reads.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture klass(String pk, String name) => <String, dynamic>{
        '_pk': pk,
        'name': name,
        'desc': 'A commander.',
        'hit_dice': '1d10',
      };

  Fixture feature(String pk, String parent, String name,
          {String? type, String desc = ''}) =>
      <String, dynamic>{
        '_pk': pk,
        'parent': parent,
        'name': name,
        'desc': desc,
        'feature_type': ?type,
      };

  /// A class-table column: one item per level, each carrying a `column_value`.
  List<Fixture> column(String feat, Map<int, String> byLevel) => [
        for (final e in byLevel.entries)
          <String, dynamic>{
            '_pk': '$feat-${e.key}',
            'parent': feat,
            'level': e.key,
            'column_value': e.value,
          },
      ];

  /// A granted feature: items carry a level and no `column_value`.
  List<Fixture> granted(String feat, List<int> levels) => [
        for (final l in levels)
          <String, dynamic>{'_pk': '$feat-$l', 'parent': feat, 'level': l},
      ];

  String describe(String name) => (pack.entities.values
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['name'] == name)['attributes']
      as Map)['description'] as String;

  void run(List<Fixture> classes, List<Fixture> features, List<Fixture> items) =>
      mapClasses(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        classes: classes,
        features: features,
        featureItems: items,
      );

  test('columns become one markdown table on the class description', () {
    run(
      [klass('c1', 'Marshal')],
      [
        feature('f1', 'c1', 'Maneuvers Known', type: 'CLASS_TABLE_DATA'),
        feature('f2', 'c1', 'Maneuver Degree', type: 'CLASS_TABLE_DATA'),
      ],
      [
        ...column('f1', {2: '2', 3: '3'}),
        ...column('f2', {2: '1st', 3: '1st'}),
      ],
    );
    final d = describe('Marshal');
    expect(d, contains('### Class Table'));
    expect(d, contains('| Level | Maneuvers Known | Maneuver Degree |'));
    expect(d, contains('| 2 | 2 | 1st |'));
    expect(d, contains('| 3 | 3 | 1st |'));
  });

  test('a column absent at a level renders an em dash, not a blank', () {
    // Marshal's Followers starts at 5; Commanding Presence starts at 1.
    run(
      [klass('c1', 'Marshal')],
      [
        feature('f1', 'c1', 'Commanding Presence', type: 'CLASS_TABLE_DATA'),
        feature('f2', 'c1', 'Followers', type: 'CLASS_TABLE_DATA'),
      ],
      [
        ...column('f1', {1: '10 feet', 5: '20 feet'}),
        ...column('f2', {5: '1'}),
      ],
    );
    final d = describe('Marshal');
    expect(d, contains('| 1 | 10 feet | — |'));
    expect(d, contains('| 5 | 20 feet | 1 |'));
  });

  test('the standard proficiency bonus column is dropped, not rendered', () {
    // The app computes it (`proficiencyTableDefault`); shipping it as content
    // would duplicate a derived value. Both snapshot columns are standard.
    run(
      [klass('c1', 'Marshal')],
      [feature('f1', 'c1', 'Proficiency Bonus', type: 'PROFICIENCY_BONUS')],
      [
        ...column('f1', {
          for (var l = 1; l <= 20; l++) l: '+${((l - 1) ~/ 4) + 2}',
        }),
      ],
    );
    expect(describe('Marshal'), isNot(contains('Class Table')));
  });

  test('a proficiency bonus that deviates from standard IS rendered', () {
    run(
      [klass('c1', 'Marshal')],
      [feature('f1', 'c1', 'Proficiency Bonus', type: 'PROFICIENCY_BONUS')],
      [...column('f1', {1: '+3', 2: '+3'})],
    );
    final d = describe('Marshal');
    expect(d, contains('| Level | Proficiency Bonus |'));
    expect(d, contains('| 1 | +3 |'));
  });

  test('two columns sharing a name are numbered, never merged', () {
    // `bfrd`'s Mechanist ships two distinct `Augment Effects Known` columns.
    run(
      [klass('c1', 'Mechanist')],
      [
        feature('f1', 'c1', 'Augment Effects Known',
            type: 'CLASS_TABLE_DATA', desc: '[Column data]'),
        feature('f2', 'c1', 'Augment Effects Known',
            type: 'CLASS_TABLE_DATA', desc: '[Column data]'),
      ],
      [
        ...column('f1', {2: '2'}),
        ...column('f2', {2: '3'}),
      ],
    );
    final d = describe('Mechanist');
    expect(d,
        contains('| Level | Augment Effects Known | Augment Effects Known (2) |'));
    expect(d, contains('| 2 | 2 | 3 |'));
  });

  test('a table column never folds its placeholder prose into the description',
      () {
    run(
      [klass('c1', 'Mechanist')],
      [
        feature('f1', 'c1', 'Augment Effects Known',
            type: 'CLASS_TABLE_DATA', desc: '[Column data]'),
        feature('f2', 'c1', 'Tinkerer', desc: 'You repair things.'),
      ],
      [
        ...column('f1', {2: '2'}),
        ...granted('f2', [1]),
      ],
    );
    final d = describe('Mechanist');
    expect(d, isNot(contains('[Column data]')),
        reason: 'the placeholder shipped in the description before B2');
    expect(d, isNot(contains('### Augment Effects Known')));
    expect(d, contains('### Tinkerer'));
    expect(d, contains('You repair things.'));
  });

  test('a class with no column table is byte-identical to pre-B2', () {
    run(
      [klass('c1', 'Marshal')],
      [feature('f1', 'c1', 'Second Wind', desc: 'You catch your breath.')],
      [...granted('f1', [1, 5])],
    );
    final d = describe('Marshal');
    expect(d, 'A commander.\n\n### Second Wind\n\nYou catch your breath.');
  });

  test('columns stay out of `features`, and granted features stay in', () {
    run(
      [klass('c1', 'Marshal')],
      [
        feature('f1', 'c1', 'Maneuvers Known', type: 'CLASS_TABLE_DATA'),
        feature('f2', 'c1', 'Second Wind', desc: 'You catch your breath.'),
      ],
      [
        ...column('f1', {2: '2', 3: '3'}),
        ...granted('f2', [1]),
      ],
    );
    final attrs = pack.entities.values
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['name'] == 'Marshal')['attributes'] as Map;
    expect(
      [for (final r in attrs['features'] as List) r['name']],
      ['Second Wind'],
      reason: "B1's exclusion must survive B2 — a column is not a feature",
    );
  });

  test('a subclass table renders too', () {
    run(
      [
        klass('c1', 'Marshal'),
        <String, dynamic>{
          '_pk': 'c2',
          'name': 'Vanguard',
          'subclass_of': 'c1',
          'desc': 'A shock trooper.',
        },
      ],
      [feature('f1', 'c2', 'Lessons Known', type: 'CLASS_TABLE_DATA')],
      [...column('f1', {3: '1', 6: '2'})],
    );
    final d = describe('Vanguard');
    expect(d, contains('*Subclass of Marshal.*'));
    expect(d, contains('| Level | Lessons Known |'));
    expect(d, contains('| 6 | 2 |'));
  });
}
