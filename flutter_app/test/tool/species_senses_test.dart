import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B5 — `granted_senses` carries its range.**
///
/// The old test was `name == 'darkvision'` with no range parse: the two
/// `Superior Darkvision` species (toh's derro and drow) got **no sense at all**
/// and the other 7 shipped a rangeless row next to built-in SRD cards that
/// carry 60/120. All 9 sense-bearing SpeciesTrait rows in shipping documents
/// state their range in prose, so the range is sourced, never guessed.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  List<Object?>? sensesOf(String name, List<(String, String)> traits) {
    mapSpecies(
      pack: pack,
      norm: norm,
      source: 'Test Doc',
      species: [
        <String, dynamic>{'_pk': 'sp', 'name': name},
      ],
      traits: [
        for (final (n, d) in traits)
          <String, dynamic>{'parent': 'sp', 'name': n, 'desc': d},
      ],
    );
    final e = pack.entities.values
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['name'] == name);
    return (e['attributes'] as Map)['granted_senses'] as List?;
  }

  test('range comes out of the trait prose', () {
    expect(
      sensesOf('Catfolk', [
        ('Darkvision', 'You can see in dim light within 60 feet of you as if '
            'it were bright light, and in darkness as if it were dim light.'),
      ]),
      [
        {
          'sense_ref': {'_lookup': 'sense', 'name': 'Darkvision'},
          'range_ft': 60,
        }
      ],
    );
  });

  test('a qualified sense name still grants the sense', () {
    final rows = sensesOf('Derro', [
      ('Superior Darkvision',
          'you can see in dim light within 120 feet of you …'),
    ]);
    expect(rows, hasLength(1));
    expect((rows!.first as Map)['range_ft'], 120);
  });

  test('no stated range leaves the row rangeless rather than inventing one', () {
    final rows = sensesOf('Erina', [
      ('Darkvision', 'You see well in the dark.'),
    ]);
    expect(rows, [
      {
        'sense_ref': {'_lookup': 'sense', 'name': 'Darkvision'}
      }
    ]);
  });

  test('a non-sense trait grants nothing', () {
    expect(sensesOf('Human', [('Ambitious', 'You gain one skill.')]), isNull);
  });
}
