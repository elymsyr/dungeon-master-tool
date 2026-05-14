import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';

EntityCategorySchema _loadPlayerCat() {
  final build = generateBuiltinDnd5eV2Schema();
  final cat = findPlayerCategory(build.schema);
  if (cat == null) {
    throw StateError('builtin v2 template must expose a Player category');
  }
  return cat;
}

Entity _mkEntity({
  required String id,
  required String slug,
  String name = 'X',
  Map<String, dynamic> fields = const {},
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: slug,
      fields: fields,
    );

void main() {
  final playerCat = _loadPlayerCat();

  group('buildSeedFields — race grants', () {
    test('Dwarf-style race writes poison resistance & darkvision onto PC',
        () {
      final race = _mkEntity(
        id: 'race-dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: const {
          'speed_ft': 30,
          'granted_senses': ['sense-darkvision'],
          'granted_damage_resistances': ['dmg-poison'],
        },
      );
      final klass = _mkEntity(
        id: 'class-barbarian',
        slug: 'class',
        name: 'Barbarian',
        fields: const {'hit_die': 'd12'},
      );
      const draft = CharacterDraft(
        level: 1,
        raceId: 'race-dwarf',
        classId: 'class-barbarian',
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: race,
        characterClass: klass,
        background: null,
        entities: {race.id: race, klass.id: klass},
      );

      expect(out['senses'], contains('sense-darkvision'));
      expect(out['resistance_refs'], contains('dmg-poison'));
    });
  });

  group('buildSeedFields — class & subclass top-level grants', () {
    test('class & subclass granted_* lists land on PC ref fields', () {
      final klass = _mkEntity(
        id: 'class-paladin',
        slug: 'class',
        name: 'Paladin',
        fields: const {
          'hit_die': 'd10',
          'granted_damage_immunities': ['dmg-poison-imm'],
          'granted_condition_immunities': ['cond-charmed'],
        },
      );
      final subclass = _mkEntity(
        id: 'subclass-devotion',
        slug: 'subclass',
        name: 'Oath of Devotion',
        fields: const {
          'granted_senses': ['sense-truesight'],
          'granted_damage_resistances': ['dmg-radiant'],
        },
      );
      const draft = CharacterDraft(
        level: 3,
        classId: 'class-paladin',
        subclassId: 'subclass-devotion',
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: null,
        characterClass: klass,
        background: null,
        entities: {klass.id: klass, subclass.id: subclass},
      );

      expect(out['damage_immunity_refs'], contains('dmg-poison-imm'));
      expect(out['condition_immunity_refs'], contains('cond-charmed'));
      expect(out['senses'], contains('sense-truesight'));
      expect(out['resistance_refs'], contains('dmg-radiant'));
    });
  });

  group('buildSeedFields — per-level feature row grants', () {
    test('only rows with level <= draft.level are absorbed', () {
      final klass = _mkEntity(
        id: 'class-monk',
        slug: 'class',
        name: 'Monk',
        fields: const {
          'hit_die': 'd8',
          'features': [
            {
              'level': 1,
              'description': 'Unarmored Defense',
              'granted_damage_resistances': ['dmg-bludgeoning'],
            },
            {
              'level': 5,
              'description': 'Stunning Strike',
              'granted_condition_immunities': ['cond-stunned'],
            },
          ],
        },
      );
      const draft = CharacterDraft(
        level: 3,
        classId: 'class-monk',
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: null,
        characterClass: klass,
        background: null,
        entities: {klass.id: klass},
      );

      expect(out['resistance_refs'], contains('dmg-bludgeoning'));
      // L5 row must NOT have leaked into L3 character.
      final cimm = out['condition_immunity_refs'];
      expect(
        cimm == null || (cimm is List && !cimm.contains('cond-stunned')),
        isTrue,
        reason: 'L5 stunned-immunity should not be granted at L3',
      );
    });

    test('traits/actions/bonus_actions/reactions copy from species + features',
        () {
      final race = _mkEntity(
        id: 'race-elf',
        slug: 'species',
        name: 'Elf',
        fields: const {
          'speed_ft': 30,
          'trait_refs': ['trait-fey-ancestry'],
          'granted_action_refs': ['act-elf-step'],
          'granted_reaction_refs': ['rxn-trance-defy'],
        },
      );
      final klass = _mkEntity(
        id: 'class-fighter',
        slug: 'class',
        name: 'Fighter',
        fields: const {
          'hit_die': 'd10',
          'features': [
            {
              'level': 1,
              'description': 'Second Wind',
              'granted_bonus_action_refs': ['ba-second-wind'],
            },
            {
              'level': 2,
              'description': 'Action Surge',
              'granted_action_refs': ['act-action-surge'],
            },
          ],
        },
      );
      const draft = CharacterDraft(
        level: 2,
        raceId: 'race-elf',
        classId: 'class-fighter',
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: race,
        characterClass: klass,
        background: null,
        entities: {race.id: race, klass.id: klass},
      );

      expect(out['trait_refs'], contains('trait-fey-ancestry'),
          reason: 'species trait_refs should copy onto PC');
      expect(out['action_refs'], contains('act-elf-step'),
          reason: 'species granted_action_refs should copy onto PC.action_refs');
      expect(out['reaction_refs'], contains('rxn-trance-defy'),
          reason: 'species granted_reaction_refs should copy onto PC.reaction_refs');
      expect(out['bonus_action_refs'], contains('ba-second-wind'),
          reason: 'class feature row granted_bonus_action_refs should land');
      expect(out['action_refs'], contains('act-action-surge'),
          reason: 'class feature row granted_action_refs should land');
    });

    test('rows up to and including draft.level land on PC', () {
      final klass = _mkEntity(
        id: 'class-druid',
        slug: 'class',
        name: 'Druid',
        fields: const {
          'hit_die': 'd8',
          'features': [
            {
              'level': 1,
              'description': 'Druidic',
              'granted_languages': ['lang-druidic'],
            },
            {
              'level': 5,
              'description': 'Storm Soul',
              'granted_damage_resistances': ['dmg-lightning'],
            },
          ],
        },
      );
      const draft = CharacterDraft(
        level: 5,
        classId: 'class-druid',
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: null,
        characterClass: klass,
        background: null,
        entities: {klass.id: klass},
      );

      expect(out['language_refs'] ?? out['languages'],
          contains('lang-druidic'));
      expect(out['resistance_refs'], contains('dmg-lightning'));
    });
  });
}
