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

  group('defaultSpellSlotsByLevel (SRD §1.5)', () {
    test('full caster L1 → {1:2}', () {
      expect(defaultSpellSlotsByLevel(CasterKind.full, 1), {1: 2});
    });
    test('full caster L5 → L1/L2/L3', () {
      expect(defaultSpellSlotsByLevel(CasterKind.full, 5),
          {1: 4, 2: 3, 3: 2});
    });
    test('full caster L20 → all 9 spell levels', () {
      expect(defaultSpellSlotsByLevel(CasterKind.full, 20),
          {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 2, 8: 1, 9: 1});
    });
    test('half caster L1 → empty (Paladin gets nothing yet)', () {
      expect(defaultSpellSlotsByLevel(CasterKind.half, 1), <int, int>{});
    });
    test('half caster L5 → {1:4, 2:2}', () {
      expect(defaultSpellSlotsByLevel(CasterKind.half, 5), {1: 4, 2: 2});
    });
    test('third caster L3 → {1:2}', () {
      expect(defaultSpellSlotsByLevel(CasterKind.third, 3), {1: 2});
    });
    test('third caster L1/L2 → empty', () {
      expect(defaultSpellSlotsByLevel(CasterKind.third, 1), <int, int>{});
      expect(defaultSpellSlotsByLevel(CasterKind.third, 2), <int, int>{});
    });
    test('pact slot level scales with character level', () {
      expect(defaultSpellSlotsByLevel(CasterKind.pact, 1), {1: 1});
      expect(defaultSpellSlotsByLevel(CasterKind.pact, 5), {3: 2});
      expect(defaultSpellSlotsByLevel(CasterKind.pact, 11), {5: 3});
      expect(defaultSpellSlotsByLevel(CasterKind.pact, 17), {5: 4});
    });
    test('none kind always empty', () {
      expect(defaultSpellSlotsByLevel(CasterKind.none, 5), <int, int>{});
    });
  });

  group('planLevelUp spell slot fields', () {
    test('non-caster has null slot maps', () {
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: _makeClass(name: 'Barb', hitDie: 'd12'),
        subclassEntity: null,
      );
      expect(p.prevSpellSlots, isNull);
      expect(p.newSpellSlots, isNull);
      expect(p.spellSlotsDelta, isEmpty);
    });

    test('full caster 4→5 unlocks L3 slot, bumps L1', () {
      final cls = _makeClass(
        name: 'Wizard',
        hitDie: 'd6',
        casterKind: 'Full',
      );
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.prevSpellSlots, {1: 4, 2: 3});
      expect(p.newSpellSlots, {1: 4, 2: 3, 3: 2});
      expect(p.spellSlotsDelta, {3: 2});
    });

    test('half caster 1→2 unlocks L1 slots from nothing', () {
      final cls = _makeClass(
        name: 'Paladin',
        hitDie: 'd10',
        casterKind: 'Half',
      );
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.prevSpellSlots, <int, int>{});
      expect(p.newSpellSlots, {1: 2});
      expect(p.spellSlotsDelta, {1: 2});
    });

    test('pact slot level scales: 4→5 swaps L2 for L3', () {
      final cls = _makeClass(
        name: 'Warlock',
        hitDie: 'd8',
        casterKind: 'Pact',
      );
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.prevSpellSlots, {2: 2});
      expect(p.newSpellSlots, {3: 2});
      // Slot level changed entirely — delta exposes only the new tier.
      expect(p.spellSlotsDelta, {3: 2});
    });

    test('authored class table overrides default', () {
      final cls = _makeClass(
        name: 'CustomFull',
        hitDie: 'd6',
        casterKind: 'Full',
        extraFields: {
          'spell_slots_by_level': {
            1: {1: 99},
          },
        },
      );
      final p = planLevelUp(
        fromLevel: 0,
        toLevel: 1,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.newSpellSlots, {1: 99});
    });
  });

  group('planLevelUp spell pick deltas', () {
    test('non-caster has zero cantrip and spell deltas', () {
      final p = planLevelUp(
        fromLevel: 1,
        toLevel: 2,
        classEntity: _makeClass(name: 'Barb', hitDie: 'd12'),
        subclassEntity: null,
      );
      expect(p.cantripsKnownDelta, 0);
      expect(p.preparedSpellsDelta, 0);
    });

    test('full caster L1 (from 0) opens initial pick budget', () {
      final p = planLevelUp(
        fromLevel: 0,
        toLevel: 1,
        classEntity: _makeClass(
          name: 'Wizard',
          hitDie: 'd6',
          casterKind: 'Full',
        ),
        subclassEntity: null,
      );
      expect(p.cantripsKnownAtPrevLevel, 0);
      expect(p.cantripsKnownDelta, p.cantripsKnownAtNewLevel);
      expect(p.preparedSpellsAtPrevLevel, 0);
      expect(p.preparedSpellsDelta, p.preparedSpellsAtNewLevel);
    });

    test('full caster 4→5: cantrips unchanged, spells +1 (Wizard-ish curve)', () {
      final cls = _makeClass(
        name: 'Wizard',
        hitDie: 'd6',
        casterKind: 'Full',
      );
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.cantripsKnownDelta, 0);
      expect(p.preparedSpellsDelta, 1); // default curve = level + 3
    });

    test('downgrade clamps deltas to 0', () {
      final p = planLevelUp(
        fromLevel: 5,
        toLevel: 4,
        classEntity: _makeClass(
          name: 'Wizard',
          hitDie: 'd6',
          casterKind: 'Full',
        ),
        subclassEntity: null,
      );
      expect(p.cantripsKnownDelta, 0);
      expect(p.preparedSpellsDelta, 0);
    });
  });

  group('planLevelUp save-proficiency grants (SRD §1.4)', () {
    test('feature with proficiency_grant surfaces ability name on LevelGain',
        () {
      final cls = _makeClass(
        name: 'Sorcerer',
        hitDie: 'd6',
        features: [
          {
            'level': 1,
            'name': 'Soul Save',
            'description': 'You gain Charisma save proficiency.',
            'effects': [
              {
                'kind': 'proficiency_grant',
                'target_kind': 'saving_throw',
                'target_ref': {'slug': 'ability', 'name': 'Charisma'},
              },
            ],
          },
        ],
      );
      final p = planLevelUp(
        fromLevel: 0,
        toLevel: 1,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.newFeatures, hasLength(1));
      expect(p.newFeatures.single.grantedSaveProficiencyNames, ['Charisma']);
    });

    test('subclass feature save grant surfaces too', () {
      final sub = _makeSubclass(
        name: 'Eldritch Knight',
        features: [
          {
            'level': 7,
            'name': 'War Magic',
            'description': 'You gain Wisdom save proficiency.',
            'effects': [
              {
                'kind': 'proficiency_grant',
                'target_kind': 'ability',
                'target_ref': {'slug': 'ability', 'name': 'Wisdom'},
              },
            ],
          },
        ],
      );
      final p = planLevelUp(
        fromLevel: 6,
        toLevel: 7,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: sub,
      );
      final eldritch =
          p.newFeatures.firstWhere((f) => f.source == 'Eldritch Knight');
      expect(eldritch.grantedSaveProficiencyNames, ['Wisdom']);
    });

    test('features without proficiency_grant leave list empty', () {
      final cls = _makeClass(
        name: 'Rogue',
        hitDie: 'd8',
        features: [
          {
            'level': 1,
            'name': 'Sneak Attack',
            'description': 'You deal extra damage.',
          },
        ],
      );
      final p = planLevelUp(
        fromLevel: 0,
        toLevel: 1,
        classEntity: cls,
        subclassEntity: null,
      );
      expect(p.newFeatures.single.grantedSaveProficiencyNames, isEmpty);
    });
  });

  group('planLevelUp extra-attack fields (SRD §1.5)', () {
    Entity featExtra({
      required String id,
      required String className,
      required int atLevel,
      required int value,
    }) =>
        Entity(
          id: id,
          name: 'Extra Attack $id',
          categorySlug: 'feat',
          fields: {
            'auto_granted_by': [
              {
                'source': 'class',
                'source_ref': {'slug': 'class', 'name': className},
                'at_level': atLevel,
              },
            ],
            'effects': [
              {'kind': 'extra_attack_count', 'value': value},
            ],
          },
        );

    Map<String, Entity> fighterFeats() {
      final l5 = featExtra(
        id: 'fighter-extra-5',
        className: 'Fighter',
        atLevel: 5,
        value: 2,
      );
      final l11 = featExtra(
        id: 'fighter-extra-11',
        className: 'Fighter',
        atLevel: 11,
        value: 3,
      );
      final l20 = featExtra(
        id: 'fighter-extra-20',
        className: 'Fighter',
        atLevel: 20,
        value: 4,
      );
      return {l5.id: l5, l11.id: l11, l20.id: l20};
    }

    test('Fighter 4→5 flags Extra Attack with count 0→2', () {
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: null,
        entities: fighterFeats(),
      );
      expect(p.prevExtraAttackCount, 0);
      expect(p.newExtraAttackCount, 2);
      expect(p.extraAttackCountDelta, 2);
      expect(p.isExtraAttackLevel, isTrue);
    });

    test('Fighter 10→11 flags Extra Attack with count 2→3', () {
      final p = planLevelUp(
        fromLevel: 10,
        toLevel: 11,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: null,
        entities: fighterFeats(),
      );
      expect(p.prevExtraAttackCount, 2);
      expect(p.newExtraAttackCount, 3);
      expect(p.extraAttackCountDelta, 1);
      expect(p.isExtraAttackLevel, isTrue);
    });

    test('Fighter 19→20 flags Extra Attack with count 3→4', () {
      final p = planLevelUp(
        fromLevel: 19,
        toLevel: 20,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: null,
        entities: fighterFeats(),
      );
      expect(p.prevExtraAttackCount, 3);
      expect(p.newExtraAttackCount, 4);
      expect(p.extraAttackCountDelta, 1);
      expect(p.isExtraAttackLevel, isTrue);
    });

    test('Paladin 4→5 fires fallback L5 flag with no scaling data', () {
      final p = planLevelUp(
        fromLevel: 4,
        toLevel: 5,
        classEntity: _makeClass(name: 'Paladin', hitDie: 'd10'),
        subclassEntity: null,
      );
      expect(p.isExtraAttackLevel, isTrue);
      expect(p.prevExtraAttackCount, 0);
      expect(p.newExtraAttackCount, 0);
    });

    test('Fighter 11→12 does not re-flag (no count change)', () {
      final p = planLevelUp(
        fromLevel: 11,
        toLevel: 12,
        classEntity: _makeClass(name: 'Fighter', hitDie: 'd10'),
        subclassEntity: null,
        entities: fighterFeats(),
      );
      expect(p.prevExtraAttackCount, 3);
      expect(p.newExtraAttackCount, 3);
      expect(p.extraAttackCountDelta, 0);
      expect(p.isExtraAttackLevel, isFalse);
    });
  });
}
