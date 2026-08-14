import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B10 — compound alignment is prose, not a coerced pick.**
///
/// `Creature.alignment` is free text. 70 rows across 29 distinct expressions
/// never resolve to one of the nine canonical alignments, and none of them
/// reduce to one either: they are wildcards (`any evil alignment`), compounds
/// (`chaotic neutral or chaotic evil`) and weighted pairs. `alignment_ref` is a
/// single Tier-0 relation with no home for those, so they ship as
/// `alignment_note` beside a null ref — picking one arm of an "or" would be
/// B11's fabricated `hp_dice` all over again.
///
/// Three source rows (`Titan)`, `Shapechanger)` ×2) are corrupt in
/// `Creature.json` itself and are not alignments at all; they stay dropped and
/// logged rather than shipping as prose.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture creature(String name, String alignment) => <String, dynamic>{
        '_pk': 'test_${name.toLowerCase()}',
        'name': name,
        'type': 'humanoid',
        'alignment': alignment,
        'armor_class': 12,
        'hit_points': 9,
        'challenge_rating': 1.0,
      };

  void run(Fixture c) => mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: [c],
        actions: const [],
        attacks: const [],
        traits: const [],
      );

  Map<String, dynamic> attrs(String name) => pack.entities.values
          .cast<Map<String, dynamic>>()
          .firstWhere(
              (e) => e['type'] == 'monster' && e['name'] == name)['attributes']
      as Map<String, dynamic>;

  test('a canonical alignment still takes the relation and writes no note', () {
    run(creature('Acolyte', 'lawful good'));
    expect(attrs('Acolyte')['alignment_ref'], isNotNull);
    expect(attrs('Acolyte').containsKey('alignment_note'), isFalse);
  });

  test('a wildcard ships as prose with no ref', () {
    run(creature('Fext', 'any alignment'));
    expect(attrs('Fext')['alignment_note'], 'any alignment');
    expect(attrs('Fext').containsKey('alignment_ref'), isFalse);
  });

  test('a compound is never coerced to one of its arms', () {
    run(creature('Kappa', 'chaotic neutral or chaotic evil'));
    expect(attrs('Kappa')['alignment_note'], 'chaotic neutral or chaotic evil');
    expect(attrs('Kappa').containsKey('alignment_ref'), isFalse);
  });

  test('mixed case and weights survive as written', () {
    run(creature('Thursir', 'Neutral Evil (50%) or Lawful Evil (50%)'));
    expect(attrs('Thursir')['alignment_note'],
        'Neutral Evil (50%) or Lawful Evil (50%)');
  });

  test('source-corrupt values are dropped and logged, not shipped as prose',
      () {
    run(creature('Hraesvelgr', 'Titan)'));
    expect(attrs('Hraesvelgr').containsKey('alignment_note'), isFalse);
    expect(attrs('Hraesvelgr').containsKey('alignment_ref'), isFalse);
    expect(norm.unmapped.toJson()['alignment'], isNotEmpty);
  });

  test('an empty alignment logs nothing at all', () {
    run(creature('Frog', '  '));
    expect(norm.unmapped.toJson()['alignment'], isNull);
  });
}
