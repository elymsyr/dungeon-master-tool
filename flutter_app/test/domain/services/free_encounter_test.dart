import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_encounter.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-22T00:00:00Z';

/// ROADMAP Faz 9: the free encounter reads the template (DESIGN §14).
void main() {
  final builtin = generateBuiltinDnd5eV2Schema().schema;
  final srd = copyAsFreeTemplate(builtin, id: 'copy', name: 'SRD', now: _now);

  /// [s] with the encounter preset (and so every bound block) set to [spec].
  WorldSchema withPreset(WorldSchema s, CombatStatsSpec spec) =>
      replacePreset(s, spec.applyTo(encounterPreset(s)!));

  group('SRD copy defaults (DESIGN §14.1, §14.6)', () {
    test('monster, animal, NPC and the player card join; Encounter, Trap not',
        () {
      final slugs = encounterCategories(srd).map((c) => c.slug).toSet();
      expect(slugs, containsAll(['monster', 'animal', 'npc', 'player-character']));
      expect(slugs, isNot(contains('encounter')));
      expect(slugs, isNot(contains('trap')));
      for (final c in encounterCategories(srd)) {
        expect(combatBlockOf(c), isNotNull, reason: c.slug);
      }
    });

    test('columns: Init. (sort), AC, HP, Conditions; XP hidden', () {
      final cfg = encounterConfigOf(srd);
      expect(cfg.columns.map((c) => c.subFieldKey), [
        'initiative',
        'ac',
        combatHpKey,
        encounterConditionsColumn,
      ]);
      expect(cfg.initiativeSubField, 'initiative');
      expect(cfg.sortDirection, 'desc');
      expect(cfg.columns.firstWhere((c) => c.subFieldKey == 'hp').showButtons,
          isTrue);
      expect(canRollEncounter(srd), isTrue);
    });

    test('the encounter reads the Combat Stats preset', () {
      final p = encounterPreset(srd)!;
      expect(p.fieldType, FieldType.combatStats);
      expect(presetsOf(srd), contains(p));
    });

    test('battle maps from Location', () {
      expect(battlemapFieldsOf(srd), builtinBattlemapFields);
    });

    test('built-in schemas pass through', () {
      expect(encounterConfigOf(builtin), builtin.encounterConfig);
      expect(battlemapFieldsOf(builtin), builtinBattlemapFields);
      expect(canRollEncounter(builtin), isTrue);
    });
  });

  group('columns from the preset (DESIGN §14.2)', () {
    test('a hidden value has no column; HP is always there', () {
      final s = withPreset(
        srd,
        const CombatStatsSpec(values: [
          CombatValue(key: 'ac', label: 'AC', encounter: false),
          CombatValue(key: 'speed', label: 'Speed', width: 40),
        ]),
      );
      final cols = encounterConfigOf(s).columns;
      expect(cols.map((c) => c.subFieldKey), ['speed', combatHpKey]);
      expect(cols.first.width, 40);
      expect(encounterSortValue(s), isNull);
      expect(canRollEncounter(s), isFalse);
    });

    test('no preset chosen: only HP, nothing to sort by', () {
      final s = srd.copyWith(
        encounterConfig: srd.encounterConfig.copyWith(combatPresetId: null),
      );
      expect(encounterPreset(s), isNull);
      expect(encounterConfigOf(s).columns.single.subFieldKey, combatHpKey);
      expect(canRollEncounter(s), isFalse);
    });
  });

  group('combatant values (DESIGN §14.4)', () {
    const goblin = Entity(
      id: 'g',
      name: 'Goblin',
      categorySlug: 'monster',
      fields: {'hp_average': 7, 'ac': 15, 'initiative_modifier': 2},
    );

    test("the SRD monster's flat fields fill the block", () {
      final v = freeCombatantValues(srd, goblin);
      expect((v.hp, v.maxHp), (7, 7));
      expect(v.stats['ac'], 15);
      expect(v.stats['initiative'], '1d20+2');
      expect(freeSortSpec(srd, v.stats), '1d20+2');
    });

    test('a blank current HP is the Max HP; a stored one stays', () {
      const hero = Entity(
        id: 'h',
        categorySlug: 'player-character',
        fields: {
          'combat_stats': {'max_hp': 38},
        },
      );
      expect(freeCombatantValues(srd, hero).hp, 38);
      final hurt = hero.copyWith(fields: const {
        'combat_stats': {'hp': 31, 'max_hp': 38},
      });
      expect(freeCombatantValues(srd, hurt).hp, 31);
    });

    test('a category without a block comes in with empty HP', () {
      const trap = Entity(id: 't', categorySlug: 'trap');
      final v = freeCombatantValues(srd, trap);
      expect((v.hp, v.maxHp), (0, 0));
      expect(v.stats, isEmpty);
    });
  });

  group('sort and roll (V18)', () {
    WorldSchema numberSort({String? dice}) {
      final s = withPreset(
        srd,
        const CombatStatsSpec(values: [CombatValue(key: 'init', label: 'Init')]),
      );
      return s.copyWith(
        encounterConfig: s.encounterConfig.copyWith(
          sortBySubField: 'init',
          sortDice: dice,
        ),
      );
    }

    test('a Number with the template dice', () {
      final s = numberSort(dice: '1d20');
      expect(canRollEncounter(s), isTrue);
      expect(freeSortSpec(s, const {'init': 3}), '1d20+3');
      expect(freeSortSpec(s, const {'init': -1}), '1d20-1');
      expect(freeSortSpec(s, const {}), '1d20');
    });

    test('a Number without dice: no roll button, the value sorts', () {
      final s = numberSort();
      expect(canRollEncounter(s), isFalse);
      expect(freeSortSpec(s, const {'init': 12}), '12');
      expect(freeSortSpec(s, const {}), isNull);
    });

    test('a Dice value rolls as it is; blank has nothing', () {
      expect(freeSortSpec(srd, const {'initiative': '2d6'}), '2d6');
      expect(freeSortSpec(srd, const {'initiative': ' '}), isNull);
    });
  });

  test('battle map images: in field order, once each', () {
    const loc = Entity(
      id: 'l',
      categorySlug: 'location',
      fields: {
        'battlemaps': ['a', 'b'],
        'map': 'a',
        'map_per_era': {'e1': 'c'},
      },
    );
    expect(battlemapImages(loc, builtinBattlemapFields['location']!),
        ['a', 'b', 'c']);
    expect(battlemapImages(loc, const ['map']), ['a']);
  });

  group('editor: the block the encounter needs (DESIGN §14.1)', () {
    final presetId = srd.encounterConfig.combatPresetId!;

    test("bound to the encounter's preset; once", () {
      final trap = srd.categories.firstWhere((c) => c.slug == 'trap');
      final s = addCombatBlock(srd, trap.categoryId, presetId,
          id: 'b1', now: _now);
      final block =
          combatBlockOf(s.categories.firstWhere((c) => c.slug == 'trap'))!;
      expect(block.presetId, presetId);
      expect(block.fieldKey, 'combat_stats');
      final again = addCombatBlock(s, trap.categoryId, presetId,
          id: 'b2', now: _now);
      expect(
        again.categories
            .firstWhere((c) => c.slug == 'trap')
            .fields
            .where((f) => f.fieldType == FieldType.combatStats),
        hasLength(1),
      );
    });

    test('nothing without the preset', () {
      final empty = emptyFreeTemplate(
        id: 'e',
        name: 'E',
        playerCardName: 'Hero',
        now: _now,
      );
      final pc = empty.categories.single;
      final s = addCombatBlock(empty, pc.categoryId, 'missing',
          id: 'b', now: _now);
      expect(combatBlockOf(s.categories.single), isNull);
    });
  });
}
