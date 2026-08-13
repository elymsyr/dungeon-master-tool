import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase L3 — the one ref that already dangled.**
///
/// `toh`'s Favored subspecies grants "the spare the dying cantrip". The prose
/// parser ran the name through `titleCase`, which capitalises every word, so the
/// pack shipped a soft ref to `"Spare The Dying"` against a corpus that spells it
/// `"Spare the Dying"` — and the resolver is case-sensitive, so it resolved to
/// nothing. `titleCaseName` keeps interior minor words lowercase.
void main() {
  test('a prose-derived spell name keeps its articles lowercase', () {
    expect(titleCaseName('spare the dying'), 'Spare the Dying');
    expect(titleCaseName('protection from evil and good'),
        'Protection from Evil and Good');
    expect(titleCaseName('hellish rebuke'), 'Hellish Rebuke');
    // First and last word are always capitalised, however minor.
    expect(titleCaseName('the fool'), 'The Fool');
    expect(titleCaseName('speak with animals'), 'Speak with Animals');
  });

  test('the Favored grant resolves against the real spell name', () {
    final pack = PackBuilder('test-pack');
    mapSpecies(
      pack: pack,
      norm: Normalizer(),
      source: 'Tome of Heroes',
      species: [
        <String, dynamic>{
          '_pk': 'toh_favored',
          'name': 'Favored',
          'desc': 'A favored one.',
        },
      ],
      traits: [
        <String, dynamic>{
          '_pk': 't1',
          'parent': 'toh_favored',
          'name': 'Blessed',
          'desc': 'You know the spare the dying cantrip.',
        },
      ],
    );
    final sub = pack.entities.values
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['name'] == 'Favored');
    expect((sub['attributes'] as Map)['granted_cantrip_refs'],
        [{'slug': 'spell', 'name': 'Spare the Dying'}]);
  });
}
