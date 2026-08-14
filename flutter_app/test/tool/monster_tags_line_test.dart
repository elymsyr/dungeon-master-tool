import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B5 — `tags_line` is a v1 backfill, like B8's actions.**
///
/// `_creatureType` splits `"humanoid (elf)"` into the type ref plus the tag —
/// correct code that shipped 0 tags on 2,885 monsters, because the
/// parenthesised form occurs on **0 of 3,541** v2 `Creature.type` rows: the v2
/// conversion moved the subtype into its own column and then dropped it. v1's
/// `Monster.subtype` still carries it for 367 rows, 293 of them in documents
/// that ship. The v2 tag still wins where one exists, so the backfill can never
/// override a sourced value.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture creature(String name, String type) => <String, dynamic>{
        '_pk': 'test_${name.toLowerCase()}',
        'name': name,
        'type': type,
        'armor_class': 12,
        'hit_points': 9,
        'challenge_rating': 1.0,
      };

  void run(Fixture c, {Map<String, String> v1 = const {}}) => mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: [c],
        actions: const [],
        attacks: const [],
        traits: const [],
        v1Subtypes: v1,
      );

  Map<String, dynamic> attrs(String name) => pack.entities.values
          .cast<Map<String, dynamic>>()
          .firstWhere(
              (e) => e['type'] == 'monster' && e['name'] == name)['attributes']
      as Map<String, dynamic>;

  test('the v1 subtype fills tags_line when v2 has only a bare type', () {
    run(creature('Acolyte', 'humanoid'), v1: {'acolyte': 'any race'});
    expect(attrs('Acolyte')['tags_line'], '(any race)');
  });

  test('no v1 row means no tags_line — never a fabricated one', () {
    run(creature('Frog', 'beast'), v1: {'acolyte': 'any race'});
    expect(attrs('Frog').containsKey('tags_line'), isFalse);
  });

  test('a blank v1 subtype is treated as absent', () {
    run(creature('Frog', 'beast'), v1: {'frog': '  '});
    expect(attrs('Frog').containsKey('tags_line'), isFalse);
  });

  test('a parenthesised v2 type still wins over the v1 column', () {
    run(creature('Balor', 'fiend (demon)'), v1: {'balor': 'devil'});
    expect(attrs('Balor')['tags_line'], '(demon)');
  });

  test('the lookup is name-keyed case-insensitively', () {
    run(creature('Bandit Captain', 'humanoid'),
        v1: {'bandit captain': 'any race'});
    expect(attrs('Bandit Captain')['tags_line'], '(any race)');
  });
}
