import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/spell.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B4 — the two spell columns the mapper never read.**
///
/// Unlike B9/B8/B3/B2, this phase's filed premise survived contact with the
/// pinned snapshot: `shape_type` is a clean 5-value enum (cone/cube/cylinder/
/// line/sphere) whose every value is already a built-in `area-shape` Tier-0
/// row, `shape_size` is always feet (no other unit exists anywhere in the
/// snapshot, and no row carries a size without a shape), and
/// `reaction_condition` is non-empty on exactly the rows whose casting time is
/// `reaction`.
///
/// B4's third clause — load `SpellCastingOption.json` → `at_higher_levels_text`
/// — was already struck by A1 and is not tested here: there is nothing to load.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture spell(String name, Map<String, dynamic> extra) => <String, dynamic>{
        '_pk': name,
        'name': name,
        'desc': 'It does a thing.',
        'level': 3,
        'school': 'evocation',
        'casting_time': 'action',
        'range_unit': 'feet',
        'range': 120,
        ...extra,
      };

  Map<String, dynamic> attrsOf(String name) => (pack.entities.values
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['name'] == name)['attributes'] as Map)
      .cast<String, dynamic>();

  void run(List<Fixture> spells) =>
      mapSpells(pack: pack, norm: norm, source: 'Test Doc', spells: spells);

  group('area of effect', () {
    test('shape + size become an area-shape lookup and a foot count', () {
      run([
        spell('Fireball', {'shape_type': 'sphere', 'shape_size': 20}),
      ]);
      final a = attrsOf('Fireball');
      expect(a['area_shape_ref'], {'_lookup': 'area-shape', 'name': 'Sphere'});
      expect(a['area_size_ft'], 20);
    });

    test('every shape upstream uses resolves — nothing reaches the sink', () {
      run([
        for (final s in ['cone', 'cube', 'cylinder', 'line', 'sphere'])
          spell(s, {'shape_type': s, 'shape_size': 15}),
      ]);
      expect(
        [for (final s in ['cone', 'cube', 'cylinder', 'line', 'sphere'])
          (attrsOf(s)['area_shape_ref'] as Map)['name']],
        ['Cone', 'Cube', 'Cylinder', 'Line', 'Sphere'],
      );
      expect(norm.unmapped.toJson(), isEmpty,
          reason: 'all five shapes are built-in area-shape rows');
    });

    test('sizes arrive as int, double and numeric string alike', () {
      run([
        spell('A', {'shape_type': 'cube', 'shape_size': 10}),
        spell('B', {'shape_type': 'cube', 'shape_size': 10.0}),
        spell('C', {'shape_type': 'cube', 'shape_size': '10', 'shape_size_unit': 'ft'}),
      ]);
      for (final n in ['A', 'B', 'C']) {
        expect(attrsOf(n)['area_size_ft'], 10, reason: n);
      }
    });

    test('a shape with no size still emits the shape', () {
      run([spell('Wall', {'shape_type': 'line'})]);
      final a = attrsOf('Wall');
      expect((a['area_shape_ref'] as Map)['name'], 'Line');
      expect(a.containsKey('area_size_ft'), isFalse);
    });

    test('a spell with no shape gains neither field', () {
      run([spell('Magic Missile', const {})]);
      final a = attrsOf('Magic Missile');
      expect(a.containsKey('area_shape_ref'), isFalse);
      expect(a.containsKey('area_size_ft'), isFalse);
    });
  });

  group('reaction trigger', () {
    test('the dangling "which you take" lead-in is dropped', () {
      run([
        spell('Shield', {
          'casting_time': 'reaction',
          'reaction_condition':
              'which you take when you are hit by an attack or targeted by '
                  'the spell magic missile',
        }),
      ]);
      expect(
        attrsOf('Shield')['reaction_trigger'],
        'When you are hit by an attack or targeted by the spell magic missile.',
      );
    });

    test('the "that you take" variant is dropped too', () {
      run([
        spell('Anchoring Rope', {
          'casting_time': 'reaction',
          'reaction_condition': 'that you take while falling',
        }),
      ]);
      expect(attrsOf('Anchoring Rope')['reaction_trigger'], 'While falling.');
    });

    test('a row that already reads standalone only gains sentence punctuation',
        () {
      run([
        spell('Force of Will', {
          'casting_time': 'reaction',
          'reaction_condition': 'when a creature you can see casts a spell',
        }),
      ]);
      expect(attrsOf('Force of Will')['reaction_trigger'],
          'When a creature you can see casts a spell.');
    });

    test('existing terminal punctuation is not doubled', () {
      run([
        spell('X', {
          'casting_time': 'reaction',
          'reaction_condition': 'which you take when you fall.',
        }),
      ]);
      expect(attrsOf('X')['reaction_trigger'], 'When you fall.');
    });

    test('an empty or absent condition emits no field', () {
      run([
        spell('Blank', {'casting_time': 'reaction', 'reaction_condition': ''}),
        spell('None', {'casting_time': 'reaction'}),
        spell('Plain', const {}),
      ]);
      for (final n in ['Blank', 'None', 'Plain']) {
        expect(attrsOf(n).containsKey('reaction_trigger'), isFalse, reason: n);
      }
    });
  });

  test('B4 changes nothing else about a spell', () {
    run([
      spell('Fireball', {
        'shape_type': 'sphere',
        'shape_size': 20,
        'damage_types': ['fire'],
        'saving_throw_ability': 'dexterity',
      }),
    ]);
    final a = attrsOf('Fireball');
    expect(a['level'], 3);
    expect(a['description'], 'It does a thing.');
    expect((a['school_ref'] as Map)['name'], 'Evocation');
    expect(a['range_type'], 'Ranged');
    expect(a['range_ft'], 120);
    expect((a['damage_type_refs'] as List).single['name'], 'Fire');
    expect((a['save_ability_ref'] as Map)['name'], 'Dexterity');
  });
}
