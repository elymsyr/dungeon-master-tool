import 'package:dungeon_master_tool/application/character_creation/multiclass_helper.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _classEntity({
  required String id,
  required String name,
  required List<String> prereqAbilities,
  int minScore = 13,
  bool anyOf = false,
  String? casterKind,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'class',
      fields: {
        if (casterKind != null) 'caster_kind': casterKind,
        'multiclass_prereq_ability_refs': [
          for (final a in prereqAbilities) {'slug': 'ability', 'name': a},
        ],
        'multiclass_prereq_min_score': minScore,
        if (anyOf) 'multiclass_prereq_any_of': true,
      },
    );

void main() {
  group('checkMulticlassPrereq', () {
    test('single-ability AND prereq passes when score ≥ min', () {
      final fighter = _classEntity(
        id: 'class-barbarian',
        name: 'Barbarian',
        prereqAbilities: ['Strength'],
      );
      final res = checkMulticlassPrereq(
        classEntity: fighter,
        entities: const {},
        abilityScores: {'STR': 14},
      );
      expect(res.met, isTrue);
    });

    test('single-ability AND prereq fails when score < min', () {
      final wiz = _classEntity(
        id: 'class-wizard',
        name: 'Wizard',
        prereqAbilities: ['Intelligence'],
      );
      final res = checkMulticlassPrereq(
        classEntity: wiz,
        entities: const {},
        abilityScores: {'INT': 12},
      );
      expect(res.met, isFalse);
      expect(res.reason, contains('Intelligence'));
      expect(res.reason, contains('13'));
    });

    test('multi-ability AND prereq needs all of them', () {
      final pal = _classEntity(
        id: 'class-paladin',
        name: 'Paladin',
        prereqAbilities: ['Strength', 'Charisma'],
      );
      final ok = checkMulticlassPrereq(
        classEntity: pal,
        entities: const {},
        abilityScores: {'STR': 14, 'CHA': 13},
      );
      expect(ok.met, isTrue);

      final partial = checkMulticlassPrereq(
        classEntity: pal,
        entities: const {},
        abilityScores: {'STR': 14, 'CHA': 12},
      );
      expect(partial.met, isFalse);
      expect(partial.reason, contains('Charisma'));
    });

    test('any_of prereq passes when one ability meets min', () {
      final fighter = _classEntity(
        id: 'class-fighter',
        name: 'Fighter',
        prereqAbilities: ['Strength', 'Dexterity'],
        anyOf: true,
      );
      final res = checkMulticlassPrereq(
        classEntity: fighter,
        entities: const {},
        abilityScores: {'STR': 9, 'DEX': 14},
      );
      expect(res.met, isTrue);
    });

    test('class with no multiclass refs is allowed unconditionally', () {
      final cls = Entity(
        id: 'class-x',
        name: 'X',
        categorySlug: 'class',
        fields: const {},
      );
      final res = checkMulticlassPrereq(
        classEntity: cls,
        entities: const {},
        abilityScores: const {},
      );
      expect(res.met, isTrue);
    });
  });

  group('totalCharacterLevel', () {
    test('sums every class level', () {
      expect(totalCharacterLevel(const {'a': 3, 'b': 2}), 5);
    });
    test('zero on empty', () {
      expect(totalCharacterLevel(const {}), 0);
    });
  });

  group('combinedCasterLevel', () {
    final wizard = _classEntity(
      id: 'class-wizard',
      name: 'Wizard',
      prereqAbilities: const [],
      casterKind: 'full',
    );
    final paladin = _classEntity(
      id: 'class-paladin',
      name: 'Paladin',
      prereqAbilities: const [],
      casterKind: 'half',
    );
    final ek = _classEntity(
      id: 'class-eldritch-knight',
      name: 'Eldritch Knight',
      prereqAbilities: const [],
      casterKind: 'third',
    );
    final fighter = _classEntity(
      id: 'class-fighter',
      name: 'Fighter',
      prereqAbilities: const [],
      casterKind: 'none',
    );
    final entities = {
      wizard.id: wizard,
      paladin.id: paladin,
      ek.id: ek,
      fighter.id: fighter,
    };

    test('single full caster = full level', () {
      expect(
        combinedCasterLevel(
          classLevels: {wizard.id: 5},
          entities: entities,
        ),
        5,
      );
    });

    test('half caster contributes floor(level/2), nothing at L1', () {
      expect(
        combinedCasterLevel(
          classLevels: {paladin.id: 1},
          entities: entities,
        ),
        0,
      );
      expect(
        combinedCasterLevel(
          classLevels: {paladin.id: 5},
          entities: entities,
        ),
        2,
      );
    });

    test('third caster contributes floor(level/3), nothing below L3', () {
      expect(
        combinedCasterLevel(
          classLevels: {ek.id: 2},
          entities: entities,
        ),
        0,
      );
      expect(
        combinedCasterLevel(
          classLevels: {ek.id: 6},
          entities: entities,
        ),
        2,
      );
    });

    test('non-caster contributes 0', () {
      expect(
        combinedCasterLevel(
          classLevels: {fighter.id: 5},
          entities: entities,
        ),
        0,
      );
    });

    test('multi-class sums each contribution', () {
      // Wizard 3 (full=3) + Paladin 4 (half=2) + Fighter 5 (0) = 5
      expect(
        combinedCasterLevel(
          classLevels: {
            wizard.id: 3,
            paladin.id: 4,
            fighter.id: 5,
          },
          entities: entities,
        ),
        5,
      );
    });
  });
}
