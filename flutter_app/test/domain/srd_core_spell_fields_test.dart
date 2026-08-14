import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/packs.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/spells.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase T2-3 — the four built-in spell fields + `pack.content_quantities`.**
///
/// The point of these tests is that none of the new data may be *invented*:
/// every area template and every upcast clause has to be recoverable from the
/// row's own description, and the Reaction spells have to be complete.
void main() {
  final spells = srdSpells();
  Map<String, dynamic> attrs(Map<String, dynamic> s) =>
      s['attributes'] as Map<String, dynamic>;
  String desc(Map<String, dynamic> s) => attrs(s)['description'] as String;
  String nameOf(Map<String, dynamic> s) => s['name'] as String;

  group('area_shape_ref / area_size_ft', () {
    test('every filled area is stated by the spell\'s own description', () {
      final filled =
          spells.where((s) => attrs(s).containsKey('area_shape_ref')).toList();
      expect(filled.length, greaterThanOrEqualTo(60));
      for (final s in filled) {
        final a = attrs(s);
        final shape = (a['area_shape_ref'] as Map)['name'] as String;
        final size = a['area_size_ft'] as int;
        expect(desc(s), contains(shape), reason: nameOf(s));
        expect(
          RegExp('\\b$size(?:-foot| feet)').hasMatch(desc(s)),
          isTrue,
          reason: '${nameOf(s)}: $size ft is not in the description',
        );
      }
    });

    test('the two fields are always filled together', () {
      for (final s in spells) {
        final a = attrs(s);
        expect(a.containsKey('area_shape_ref'), a.containsKey('area_size_ft'),
            reason: nameOf(s));
      }
    });

    test('no spell states a plain "N-foot Shape" template without carrying it',
        () {
      // Deliberately unfilled. Wall of Force / Private Sanctum: the shape is
      // the caster's choice at cast time, with no fixed template.
      // Antipathy/Sympathy: its Cubes are a size *limit on the target*, not an
      // area of effect.
      const freeform = {
        'Wall of Force',
        'Private Sanctum',
        'Antipathy/Sympathy',
      };
      final template = RegExp(
          r'\b\d+-foot[a-z-]*,? ?(?:\d+-foot[a-z-]*,? ?)?'
          r'(Cone|Cube|Cylinder|Line|Sphere|Emanation)\b');
      for (final s in spells) {
        if (freeform.contains(nameOf(s))) continue;
        if (!template.hasMatch(desc(s))) continue;
        expect(attrs(s).containsKey('area_shape_ref'), isTrue,
            reason: '${nameOf(s)} describes an area but ships no shape');
      }
    });
  });

  group('reaction_trigger', () {
    test('every Reaction-cast spell has one, and only those do', () {
      for (final s in spells) {
        final a = attrs(s);
        final isReaction =
            (a['casting_time_unit_ref'] as Map)['name'] == 'Reaction';
        expect(a.containsKey('reaction_trigger'), isReaction,
            reason: nameOf(s));
        if (isReaction) {
          final t = a['reaction_trigger'] as String;
          expect(t, startsWith('When '), reason: nameOf(s));
          expect(t, endsWith('.'), reason: nameOf(s));
        }
      }
    });
  });

  group('at_higher_levels_text', () {
    test('lifted verbatim from the description, keyed one slot above the spell',
        () {
      final filled = spells
          .where((s) => attrs(s).containsKey('at_higher_levels_text'))
          .toList();
      expect(filled.length, greaterThanOrEqualTo(45));
      for (final s in filled) {
        final level = attrs(s)['level'] as int;
        final table = attrs(s)['at_higher_levels_text'] as Map;
        expect(table.keys.single, '${level + 1}', reason: nameOf(s));
        final text = table.values.single as String;
        expect(text, isNotEmpty, reason: nameOf(s));
        expect(desc(s), endsWith(text), reason: nameOf(s));
      }
    });

    test('cantrips are excluded — their upgrade scales on character level', () {
      for (final s in spells.where((s) => attrs(s)['level'] == 0)) {
        expect(attrs(s).containsKey('at_higher_levels_text'), isFalse,
            reason: nameOf(s));
      }
    });
  });

  group('pack.content_quantities', () {
    test('one entry per content_ref, in order, matching the narrative', () {
      final packs = srdPacks();
      expect(packs.length, 7);
      for (final p in packs) {
        final a = p['attributes'] as Map<String, dynamic>;
        final refs = a['content_refs'] as List;
        final qty = a['content_quantities'] as Map;
        expect(qty.length, refs.length, reason: p['name'] as String);
        expect(qty.keys.toList(),
            [for (var i = 0; i < refs.length; i++) '$i'],
            reason: p['name'] as String);
        expect(qty.values.every((v) => v is int && v >= 1), isTrue,
            reason: p['name'] as String);
      }
    });

    test('Burglar\'s Pack counts 10 Candles at the Candle ref', () {
      final burglar =
          srdPacks().firstWhere((p) => p['name'] == "Burglar's Pack");
      final a = burglar['attributes'] as Map<String, dynamic>;
      final refs = (a['content_refs'] as List).cast<Map>();
      final i = refs.indexWhere((r) => r['name'] == 'Candle');
      expect((a['content_quantities'] as Map)['$i'], 10);
    });
  });
}
