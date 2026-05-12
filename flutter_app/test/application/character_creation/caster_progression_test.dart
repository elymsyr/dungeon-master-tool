import 'package:dungeon_master_tool/application/character_creation/caster_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCasterKind', () {
    test('maps schema enum strings', () {
      expect(parseCasterKind('Full'), CasterKind.full);
      expect(parseCasterKind('Half'), CasterKind.half);
      expect(parseCasterKind('Third'), CasterKind.third);
      expect(parseCasterKind('Pact'), CasterKind.pact);
    });
    test('unknown / null / Ritual → none', () {
      expect(parseCasterKind('None'), CasterKind.none);
      expect(parseCasterKind('Ritual'), CasterKind.none);
      expect(parseCasterKind(null), CasterKind.none);
      expect(parseCasterKind('NotACaster'), CasterKind.none);
    });
  });

  group('levelTableValue', () {
    test('reads int-keyed map', () {
      expect(levelTableValue({1: 3, 2: 4, 3: 4}, 2), 4);
    });
    test('reads string-keyed map', () {
      expect(levelTableValue({'1': 3, '2': 4}, 1), 3);
    });
    test('null/not-map → null', () {
      expect(levelTableValue(null, 1), isNull);
      expect(levelTableValue('not a map', 1), isNull);
    });
    test('missing level → null', () {
      expect(levelTableValue({1: 3}, 5), isNull);
    });
  });

  group('maxPreparableSpellLevel', () {
    test('Full caster: L1=1, L3=2, L5=3, L17=9', () {
      expect(maxPreparableSpellLevel(CasterKind.full, 1), 1);
      expect(maxPreparableSpellLevel(CasterKind.full, 3), 2);
      expect(maxPreparableSpellLevel(CasterKind.full, 5), 3);
      expect(maxPreparableSpellLevel(CasterKind.full, 17), 9);
      expect(maxPreparableSpellLevel(CasterKind.full, 20), 9);
    });
    test('Half caster: SRD progression L2/5/9/13/17 → 1/2/3/4/5', () {
      expect(maxPreparableSpellLevel(CasterKind.half, 1), 0);
      expect(maxPreparableSpellLevel(CasterKind.half, 2), 1);
      expect(maxPreparableSpellLevel(CasterKind.half, 5), 2);
      expect(maxPreparableSpellLevel(CasterKind.half, 9), 3);
      expect(maxPreparableSpellLevel(CasterKind.half, 13), 4);
      expect(maxPreparableSpellLevel(CasterKind.half, 17), 5);
    });
    test('Third caster: <3 → 0, L3=1', () {
      expect(maxPreparableSpellLevel(CasterKind.third, 1), 0);
      expect(maxPreparableSpellLevel(CasterKind.third, 2), 0);
      expect(maxPreparableSpellLevel(CasterKind.third, 3), 1);
    });
    test('Pact: L1=1, L17=5 (capped)', () {
      expect(maxPreparableSpellLevel(CasterKind.pact, 1), 1);
      expect(maxPreparableSpellLevel(CasterKind.pact, 17), 5);
    });
    test('None: always 0', () {
      expect(maxPreparableSpellLevel(CasterKind.none, 20), 0);
    });
  });

  group('defaultCantripsKnown', () {
    test('Full caster L1=3, L4=4, L10=5', () {
      expect(defaultCantripsKnown(CasterKind.full, 1), 3);
      expect(defaultCantripsKnown(CasterKind.full, 4), 4);
      expect(defaultCantripsKnown(CasterKind.full, 10), 5);
    });
    test('Half/Third/None → 0', () {
      expect(defaultCantripsKnown(CasterKind.half, 5), 0);
      expect(defaultCantripsKnown(CasterKind.third, 5), 0);
      expect(defaultCantripsKnown(CasterKind.none, 5), 0);
    });
    test('Pact: L1=2', () {
      expect(defaultCantripsKnown(CasterKind.pact, 1), 2);
    });
  });

  group('defaultPreparedSpells', () {
    test('Full caster L1=4, L5=8', () {
      expect(defaultPreparedSpells(CasterKind.full, 1), 4);
      expect(defaultPreparedSpells(CasterKind.full, 5), 8);
    });
    test('Half caster L1=0, L2=2', () {
      expect(defaultPreparedSpells(CasterKind.half, 1), 0);
      expect(defaultPreparedSpells(CasterKind.half, 2), 2);
    });
    test('None → 0', () {
      expect(defaultPreparedSpells(CasterKind.none, 20), 0);
    });
  });
}
