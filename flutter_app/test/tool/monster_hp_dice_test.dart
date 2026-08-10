import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B11 — `hp_dice` is copied or absent, never invented.**
///
/// `_monsterRow` used to write `hit_dice ?? '1d4'`, and `open5e-bfrd` has
/// `hit_dice: null` on all 360 of its creatures — so the whole pack shipped a
/// `1d4` die pool, including a 165-HP Aboleth whose own `hp_average` sat beside
/// it and contradicted it. No census could see it: the field was a filled
/// string on every row, so `audit_packs` read 100%. T1's `unsourced` column is
/// what caught it.
///
/// Of the two honest shapes — omit, or derive from `hp_average` + CON + size —
/// this takes **omit**: deriving is inference, not source, and would owe an
/// `unverifiable` rule in `verify.dart` declaring the field unmeasurable.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  /// Aboleth's real bfrd row, trimmed to what the mapper reads.
  Fixture creature(String name, {Object? hitDice = _unset}) =>
      <String, dynamic>{
        '_pk': 'bfrd_${name.toLowerCase()}',
        'name': name,
        'armor_class': 17,
        'hit_points': 165,
        'challenge_rating': 10.0,
        if (hitDice != _unset) 'hit_dice': hitDice,
      };

  void run(List<Fixture> creatures) => mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: creatures,
        actions: const [],
        attacks: const [],
        traits: const [],
      );

  Map<String, dynamic> attrs(String name) => pack.entities.values
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['type'] == 'monster' && e['name'] == name)['attributes']
          as Map<String, dynamic>;

  test('a null hit_dice column ships no hp_dice at all', () {
    run([creature('Aboleth', hitDice: null)]);
    final a = attrs('Aboleth');
    expect(a.containsKey('hp_dice'), isFalse);
    expect(a['hp_average'], 165); // the sourced value still lands
  });

  test('a missing hit_dice key ships no hp_dice either', () {
    run([creature('Aboleth')]);
    expect(attrs('Aboleth').containsKey('hp_dice'), isFalse);
  });

  test('a blank hit_dice column is treated as absent', () {
    run([creature('Aboleth', hitDice: '   ')]);
    expect(attrs('Aboleth').containsKey('hp_dice'), isFalse);
  });

  test('a real hit_dice column is copied verbatim, trimmed', () {
    run([creature('Aboleth', hitDice: ' 18d10+72 ')]);
    expect(attrs('Aboleth')['hp_dice'], '18d10+72');
  });
}

const Object _unset = Object();
