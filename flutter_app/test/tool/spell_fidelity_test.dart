import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/spell.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Stage R phase R1 — the spell mapper stops rounding.**
///
/// Eight findings of the Stage F sweep, one failure: a regex took the first
/// number it saw and wrote a confident wrong value where the source had said
/// something the schema cannot state. Every fixture below is a real string from
/// the pinned snapshot (`open5e-api-staging/data/v2/*/*/Spell.json`); the
/// finding id is on the test.
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

  /// `(amount, unit-name)` of a spell mapped with just this duration string.
  (dynamic, dynamic) dur(String text) {
    final p = PackBuilder('d');
    mapSpells(
        pack: p,
        norm: Normalizer(),
        source: 'Test Doc',
        spells: [spell('S', {'duration': text})]);
    final a = (p.entities.values.first as Map)['attributes'] as Map;
    return (a['duration_amount'], (a['duration_unit_ref'] as Map?)?['name']);
  }

  group('duration — a number only when the source stated one', () {
    test('F-pass0-11: permanent is Special, not Until Dispelled', () {
      expect(dur('permanent'), (null, 'Special'));
      expect(dur('permanent until discharged'), (null, 'Special'));
      expect(dur('permanent; one generation'), (null, 'Special'));
      // The genuine article still resolves.
      expect(dur('Until dispelled'), (null, 'Until Dispelled'));
    });

    test('F-wz-01: a per-level scale is Special, not its first term', () {
      expect(dur('1 hour/caster level'), (null, 'Special'));
    });

    test('F-pass0-12: year/week/month convert to days, keeping the number', () {
      expect(dur('1 year'), (365, 'Days'));
      expect(dur('2 weeks'), (14, 'Days'));
      expect(dur('1 month'), (30, 'Days'));
    });

    test('F-pass0-13: ranges, dice and conditions are Special', () {
      expect(dur('2-12 hours'), (null, 'Special'));
      expect(dur('1d10 hours'), (null, 'Special'));
      expect(dur('1d4+2 rounds'), (null, 'Special'));
      expect(dur('1 minute or 1 hour'), (null, 'Special'));
      expect(dur('1 hour or until triggered'), (null, 'Special'));
      expect(dur('1 minute, until expended'), (null, 'Special'));
      expect(
          dur('24 hours or until the target attempts a third death saving '
              'throw'),
          (null, 'Special'));
    });

    test('plain durations are untouched', () {
      expect(dur('1 minute'), (1, 'Minutes'));
      expect(dur('up to 8 hours'), (8, 'Hours'));
      expect(dur('10 days'), (10, 'Days'));
      expect(dur('Instantaneous'), (null, 'Instantaneous'));
      expect(dur(''), (null, 'Special'));
    });
  });

  group('F-wz-02 — concentration', () {
    test('duration prose overrides a false column', () {
      run([
        spell('Order of Revenge',
            {'duration': 'concentration + 1 round', 'concentration': false}),
      ]);
      final a = attrsOf('Order of Revenge');
      expect(a['requires_concentration'], isTrue);
      expect(a['duration_amount'], 1);
    });

    test('a spell with neither stays false', () {
      run([
        spell('Fireball', {'duration': 'instantaneous'}),
      ]);
      expect(attrsOf('Fireball')['requires_concentration'], isFalse);
    });
  });

  group('material cost — 0 means unknown, not free', () {
    Map<String, dynamic> mat(String name, dynamic col, String text) {
      run([
        spell(name,
            {'material': true, 'material_cost': col, 'material_specified': text})
      ]);
      return attrsOf(name);
    }

    test('F-spells-that-dont-suck-02: a 0 column reads the price from prose',
        () {
      expect(mat('A', '0', 'a ruby worth at least 665 gp')['material_cost_gp'],
          665);
    });

    test('F-pass0-16: a null column reads the price from prose', () {
      expect(mat('B', null, 'a gem worth 1,250 gp')['material_cost_gp'], 1250);
      expect(mat('C', null, 'a diamond worth 250+ GP')['material_cost_gp'], 250);
      expect(mat('D', null, 'dust worth at least 100gp')['material_cost_gp'],
          100);
    });

    test('sp and cp convert to gp', () {
      expect(mat('E', null, 'chalk worth at least 1 sp')['material_cost_gp'],
          closeTo(0.1, 1e-9));
      expect(mat('F', '0', 'a pebble worth at least 1 cp')['material_cost_gp'],
          closeTo(0.01, 1e-9));
    });

    test('a filled column still wins, and a priceless component stays empty',
        () {
      expect(mat('G', 1500, 'a gem worth 1,500 gp')['material_cost_gp'], 1500);
      expect(mat('H', null, 'a pinch of soot').containsKey('material_cost_gp'),
          isFalse);
    });
  });

  group('F-spells-that-dont-suck-01 — the area hidden in the range prose', () {
    test('self (N-foot radius) becomes a Sphere of N feet', () {
      run([
        spell('Aura', {
          'range_unit': null,
          'range': 0,
          'range_text': 'Self (60-foot radius)',
        }),
      ]);
      final a = attrsOf('Aura');
      expect(a['range_type'], 'Self');
      expect(a['area_shape_ref'], {'_lookup': 'area-shape', 'name': 'Sphere'});
      expect(a['area_size_ft'], 60);
    });

    test('miles convert; a non-canonical shape word claims nothing', () {
      run([
        spell('Far', {
          'range_unit': null,
          'range': 0,
          'range_text': 'Self (1-mile radius)',
        }),
        spell('Dome', {
          'range_unit': null,
          'range': 0,
          'range_text': 'Self (10-foot dome)',
        }),
        spell('Bare', {
          'range_unit': null,
          'range': 0,
          'range_text': 'Self (60 feet)',
        }),
      ]);
      expect(attrsOf('Far')['area_size_ft'], 5280);
      expect(attrsOf('Dome').containsKey('area_size_ft'), isFalse);
      expect(attrsOf('Bare').containsKey('area_size_ft'), isFalse);
    });

    test('an upstream shape is never overwritten', () {
      run([
        spell('Cone', {
          'range_unit': null,
          'range': 0,
          'range_text': 'Self (30-foot radius)',
          'shape_type': 'cone',
          'shape_size': 15,
        }),
      ]);
      final a = attrsOf('Cone');
      expect(a['area_shape_ref'], {'_lookup': 'area-shape', 'name': 'Cone'});
      expect(a['area_size_ft'], 15);
    });
  });
}
