import 'package:dungeon_master_tool/application/character_creation/caster_progression.dart';
import 'package:dungeon_master_tool/application/character_creation/level_up_planner.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _makeClass({
  required String name,
  required String hitDie,
  String casterKind = 'None',
  List<Map<String, dynamic>> features = const [],
  Map<String, dynamic>? extraFields,
}) {
  return Entity(
    id: 'class-${name.toLowerCase()}',
    name: name,
    categorySlug: 'class',
    fields: {
      'hit_die': hitDie,
      'caster_kind': casterKind,
      'features': features,
      if (extraFields != null) ...extraFields,
    },
  );
}

Entity _makeSubclass({
  required String name,
  List<Map<String, dynamic>> features = const [],
}) {
  return Entity(
    id: 'subclass-${name.toLowerCase()}',
    name: name,
    categorySlug: 'subclass',
    fields: {'features': features},
  );
}

void main() {
  group('proficiencyBonusFor', () {
    test('tracks SRD progression', () {
      expect(proficiencyBonusFor(1), 2);
      expect(proficiencyBonusFor(4), 2);
      expect(proficiencyBonusFor(5), 3);
      expect(proficiencyBonusFor(8), 3);
      expect(proficiencyBonusFor(9), 4);
      expect(proficiencyBonusFor(13), 5);
      expect(proficiencyBonusFor(17), 6);
      expect(proficiencyBonusFor(20), 6);
    });
  });

  group('fixedHpFor', () {
    test('maps die strings to SRD averages', () {
      expect(fixedHpFor('d6'), 4);
      expect(fixedHpFor('d8'), 5);
      expect(fixedHpFor('d10'), 6);
      expect(fixedHpFor('d12'), 7);
    });
    test('unknown or null returns 0', () {
      expect(fixedHpFor(null), 0);
      expect(fixedHpFor('d20'), 0);
      expect(fixedHpFor(''), 0);
    });
  });

  group('planLevelUp', () {
    test('HP delta == average × levels gained', () {
      final cls = _makeClass(name: 'Fighter', hitDie: 'd10');
      final plan = planLevelUp(
        fromLevel: 3,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(plan.hpDelta, 12); // 2 levels × 6
      expect(plan.isLevelUp, true);
      expect(plan.pbDelta, 1); // 3 → 5 crosses the +3 threshold
    });

    test('no HP table → 0 delta but plan still returned', () {
      final cls = _makeClass(name: 'X', hitDie: 'd?');
      final plan = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(plan.hpDelta, 0);
      expect(plan.isLevelUp, true);
    });

    test('newFeatures includes only levels in (from, to]', () {
      final cls = _makeClass(
        name: 'Bard',
        hitDie: 'd8',
        features: const [
          {'level': 1, 'name': 'Bardic Inspiration', 'description': '—'},
          {'level': 2, 'name': 'Jack of All Trades', 'description': '—'},
          {'level': 3, 'name': 'Bard Subclass', 'description': '—'},
        ],
      );
      final plan = planLevelUp(
        fromLevel: 1,
        toLevel: 3,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(plan.newFeatures.length, 2);
      expect(plan.newFeatures.first.level, 2);
      expect(plan.newFeatures.last.level, 3);
    });

    test('subclass features merged + sorted by level', () {
      final cls = _makeClass(
        name: 'Cleric',
        hitDie: 'd8',
        features: const [
          {'level': 3, 'name': 'Class L3', 'description': '—'},
        ],
      );
      final sub = _makeSubclass(
        name: 'Life',
        features: const [
          {'level': 2, 'name': 'Subclass L2', 'description': '—'},
        ],
      );
      final plan = planLevelUp(
        fromLevel: 1,
        toLevel: 3,
        classEntity: cls,
        subclassEntity: sub,
      );
      expect(plan.newFeatures.map((f) => f.name).toList(),
          ['Subclass L2', 'Class L3']);
    });

    test('flags ASI at L4, L8, L12, L16, L19', () {
      final cls = _makeClass(name: 'X', hitDie: 'd8');
      for (final l in [4, 8, 12, 16, 19]) {
        final p = planLevelUp(
          fromLevel: l - 1,
          toLevel: l,
          classEntity: cls,
          subclassEntity: null,
        );
        expect(p.isAsiOrFeatLevel, true, reason: 'L$l should trigger ASI');
      }
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isAsiOrFeatLevel, false);
    });

    test('flags Extra Attack at L5', () {
      final cls = _makeClass(name: 'Fighter', hitDie: 'd10');
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isExtraAttackLevel, true);
    });

    test('flags Fighting Style via feature name match', () {
      final cls = _makeClass(
        name: 'Fighter',
        hitDie: 'd10',
        features: const [
          {'level': 1, 'name': 'Fighting Style', 'description': '—'},
        ],
      );
      final p = planLevelUp(
        fromLevel: 0,
        toLevel: 1,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isFightingStyleLevel, true);
    });

    test('flags Fighting Style via class table when feature name absent', () {
      final cls = _makeClass(
        name: 'Paladin',
        hitDie: 'd10',
        extraFields: const {
          'grants_fighting_style_at_levels': [2],
        },
      );
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isFightingStyleLevel, true);
    });

    test('Fighting Style flag false at unrelated level', () {
      final cls = _makeClass(name: 'Cleric', hitDie: 'd8');
      final p = planLevelUp(
        fromLevel: 2,
        toLevel: 3,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isFightingStyleLevel, false);
    });

    test('hitDieFaces parses common dice strings', () {
      expect(
        planLevelUp(
                fromLevel: 1,
                toLevel: 2,
                classEntity: _makeClass(name: 'A', hitDie: 'd8'),
                subclassEntity: null)
            .hitDieFaces,
        8,
      );
      expect(
        planLevelUp(
                fromLevel: 1,
                toLevel: 2,
                classEntity: _makeClass(name: 'B', hitDie: 'd12'),
                subclassEntity: null)
            .hitDieFaces,
        12,
      );
      expect(
        planLevelUp(
                fromLevel: 1,
                toLevel: 2,
                classEntity: _makeClass(name: 'C', hitDie: 'rubbish'),
                subclassEntity: null)
            .hitDieFaces,
        0,
      );
    });

    test('levelsGained reflects clamped delta', () {
      final cls = _makeClass(name: 'X', hitDie: 'd8');
      final p = planLevelUp(
        fromLevel: 3,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.levelsGained, 2);
    });

    test('caster fields populated for full casters', () {
      final cls = _makeClass(
        name: 'Wizard',
        hitDie: 'd6',
        casterKind: 'Full',
      );
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 3,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.casterKind, CasterKind.full);
      expect(p.cantripsKnownAtNewLevel, isNotNull);
      expect(p.preparedSpellsAtNewLevel, isNotNull);
      expect(p.maxSpellLevelAtNewLevel, 2);
    });

    test('caster fields null for non-casters', () {
      final cls = _makeClass(name: 'Barbarian', hitDie: 'd12');
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.casterKind, CasterKind.none);
      expect(p.cantripsKnownAtNewLevel, isNull);
      expect(p.preparedSpellsAtNewLevel, isNull);
      expect(p.maxSpellLevelAtNewLevel, isNull);
    });

    test('downgrade plan has isLevelUp == false', () {
      final cls = _makeClass(name: 'Fighter', hitDie: 'd10');
      final p = planLevelUp(
        fromLevel: 5,
        toLevel: 4,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.isLevelUp, false);
      expect(p.hpDelta, 0);
    });

    test('classEntity null produces empty plan', () {
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: null,
        subclassEntity: null,
      );
      expect(p.newFeatures, isEmpty);
      expect(p.hpDelta, 0);
      expect(p.hitDie, isNull);
    });
  });

  group('effectiveHpDelta (SRD CON-per-level)', () {
    final fighterPlan = planLevelUp(
      fromLevel: 3,
      toLevel: 5,
      classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
      subclassEntity: null,
    );

    test('adds CON modifier once per level gained', () {
      // 2 levels × (avg 6 + CON 2) = 16
      expect(
        effectiveHpDelta(plan: fighterPlan, conModifier: 2),
        16,
      );
    });

    test('zero CON modifier leaves planner delta untouched', () {
      expect(
        effectiveHpDelta(plan: fighterPlan, conModifier: 0),
        fighterPlan.hpDelta,
      );
    });

    test('negative CON modifier subtracts per level', () {
      // 2 levels × (avg 6 + CON -1) = 10
      expect(
        effectiveHpDelta(plan: fighterPlan, conModifier: -1),
        10,
      );
    });

    test('rolledTotal overrides average when provided', () {
      // Rolled 8 + 9 = 17, plus 2 × CON 1 = 19
      expect(
        effectiveHpDelta(
          plan: fighterPlan,
          conModifier: 1,
          rolledTotal: 17,
        ),
        19,
      );
    });

    test('multi-level jump compounds CON mod', () {
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 4,
        classEntity: _makeClass(name: 'Barb', hitDie: 'd12'),
        subclassEntity: null,
      );
      // 3 levels × (avg 7 + CON 3) = 30
      expect(effectiveHpDelta(plan: p, conModifier: 3), 30);
    });

    test('downgrade plan adds nothing', () {
      final p = planLevelUp(
        fromLevel: 5,
        toLevel: 4,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: null,
      );
      expect(effectiveHpDelta(plan: p, conModifier: 5), 0);
    });
  });
}
