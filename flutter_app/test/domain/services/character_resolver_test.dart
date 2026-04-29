import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _e({
  required String id,
  required String slug,
  required String name,
  Map<String, dynamic>? fields,
}) =>
    Entity(
      id: id,
      categorySlug: slug,
      name: name,
      fields: fields ?? const {},
    );

Character _pc({
  required String id,
  required Map<String, dynamic> fields,
}) =>
    Character(
      id: id,
      templateId: 'tpl',
      templateName: 'Tpl',
      entity: Entity(id: '${id}_e', categorySlug: 'player', fields: fields),
      worldName: 'world',
      createdAt: '0',
      updatedAt: '0',
    );

void main() {
  group('CharacterResolver', () {
    test('Fighter L5 collects features with level <= 5', () {
      final fighter = _e(
        id: 'cls_fighter',
        slug: 'class',
        name: 'Fighter',
        fields: {
          'hit_die': 'd10',
          'features': [
            {'level': 1, 'name': 'Second Wind'},
            {'level': 2, 'name': 'Action Surge'},
            {'level': 5, 'name': 'Extra Attack'},
            {'level': 11, 'name': 'Improved Critical'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_fighter': 5},
      });
      final eff = CharacterResolver.resolve(pc, {fighter.id: fighter});
      final names = eff.activeFeatures.map((r) => r.name).toList();
      expect(names, containsAll(['Second Wind', 'Action Surge', 'Extra Attack']));
      expect(names, isNot(contains('Improved Critical')));
    });

    test('feat with class_level_grant bumps effective class level', () {
      final wizard = _e(
        id: 'cls_wiz',
        slug: 'class',
        name: 'Wizard',
        fields: {
          'features': [
            {'level': 1, 'name': 'Wizard Spellcasting'},
          ],
        },
      );
      final feat = _e(
        id: 'feat_levelgrant',
        slug: 'feat',
        name: 'Squire of the Tower',
        fields: {
          'effects': [
            {
              'kind': 'class_level_grant',
              'target_ref': {'_ref': 'class', 'name': 'Wizard'},
              'value': 1,
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': const <String, int>{},
        'feat_ids': ['feat_levelgrant'],
      });
      final eff = CharacterResolver.resolve(pc, {
        wizard.id: wizard,
        feat.id: feat,
      });
      expect(eff.classLevels['cls_wiz'], 1);
      expect(
        eff.activeFeatures.any((r) => r.name == 'Wizard Spellcasting'),
        true,
      );
    });

    test('Tough-style hp_bonus_per_level effect aggregates', () {
      final feat = _e(
        id: 'feat_tough',
        slug: 'feat',
        name: 'Tough',
        fields: {
          'effects': [
            {'kind': 'hp_bonus_per_level', 'value': 2},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'feat_ids': ['feat_tough'],
      });
      final eff = CharacterResolver.resolve(pc, {feat.id: feat});
      expect(eff.hpBonusPerLevel, 2);
    });

    test('ASI on feat respects asi_max_score cap', () {
      final feat = _e(
        id: 'feat_asi',
        slug: 'feat',
        name: 'ASI',
        fields: {
          'asi_amount': 2,
          'asi_max_score': 20,
          'asi_ability_options': [
            {'_lookup': 'ability', 'name': 'Strength'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'feat_ids': ['feat_asi'],
        'base_abilities': const {'STR': 19, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
      });
      final eff = CharacterResolver.resolve(pc, {feat.id: feat});
      // Should not bump beyond cap of 20: 19 + 2 = 21 > 20 → skipped.
      expect(eff.effectiveAbilities['STR'], 19);
    });

    test('Alert-style initiative_bonus accumulates', () {
      final feat = _e(
        id: 'feat_alert',
        slug: 'feat',
        name: 'Alert',
        fields: {
          'effects': [
            {'kind': 'initiative_bonus', 'value': 5},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'feat_ids': ['feat_alert'],
      });
      final eff = CharacterResolver.resolve(pc, {feat.id: feat});
      expect(eff.initiativeBonus, 5);
    });

    test('equipment_choice_groups merges chosen option items into inventory', () {
      final greataxe = _e(id: 'w_greataxe', slug: 'weapon', name: 'Greataxe');
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
        fields: {
          'equipment_choice_groups': [
            {
              'group_id': 'starting_kit',
              'label': 'Starting Equipment',
              'options': [
                {
                  'option_id': 'A',
                  'label': 'Greataxe',
                  'items': [
                    {
                      'ref': {'_ref': 'weapon', 'name': 'Greataxe'},
                      'quantity': 1,
                    },
                  ],
                },
                {'option_id': 'B', 'label': 'Gold', 'gold_gp': 75},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_barb': 1},
        'equipment_choices': {'starting_kit': 'A'},
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        greataxe.id: greataxe,
      });
      expect(eff.inventory.length, 1);
      expect(eff.inventory.first.entityId, 'w_greataxe');
    });

    test('subclass features only apply when level >= granted_at_level', () {
      final cls = _e(
        id: 'cls_cleric',
        slug: 'class',
        name: 'Cleric',
        fields: {
          'features': [
            {'level': 1, 'name': 'Spellcasting'},
          ],
        },
      );
      final sub = _e(
        id: 'sub_life',
        slug: 'subclass',
        name: 'Life Domain',
        fields: {
          'parent_class_ref': 'cls_cleric',
          'granted_at_level': 3,
          'features': [
            {'level': 3, 'name': 'Disciple of Life'},
          ],
        },
      );
      // Below threshold
      final pcLow = _pc(id: 'pcLow', fields: {
        'class_levels': {'cls_cleric': 1},
        'subclass_id': 'sub_life',
      });
      final effLow =
          CharacterResolver.resolve(pcLow, {cls.id: cls, sub.id: sub});
      expect(
        effLow.activeFeatures.any((r) => r.name == 'Disciple of Life'),
        false,
      );
      // At threshold
      final pcHi = _pc(id: 'pcHi', fields: {
        'class_levels': {'cls_cleric': 3},
        'subclass_id': 'sub_life',
      });
      final effHi =
          CharacterResolver.resolve(pcHi, {cls.id: cls, sub.id: sub});
      expect(
        effHi.activeFeatures.any((r) => r.name == 'Disciple of Life'),
        true,
      );
    });

    test('class saving_throw_refs become proficient saves', () {
      final cls = _e(
        id: 'cls_fighter',
        slug: 'class',
        name: 'Fighter',
        fields: {
          'saving_throw_refs': [
            {'_lookup': 'ability', 'name': 'Strength'},
          ],
          'weapon_proficiency_categories': ['Simple', 'Martial'],
          'armor_training_refs': ['Light', 'Medium', 'Heavy', 'Shield'],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_fighter': 1},
      });
      final eff = CharacterResolver.resolve(pc, {cls.id: cls});
      expect(eff.proficiencies.weaponCategoryIds, containsAll(['Simple', 'Martial']));
      expect(
        eff.proficiencies.armorCategoryIds,
        containsAll(['Light', 'Medium', 'Heavy', 'Shield']),
      );
    });

    test('feat level_grant fixed-point terminates with mutual cycle', () {
      final wizard = _e(id: 'cls_wiz', slug: 'class', name: 'Wizard');
      final fighter = _e(id: 'cls_ftr', slug: 'class', name: 'Fighter');
      final featA = _e(
        id: 'feat_a',
        slug: 'feat',
        name: 'A',
        fields: {
          'effects': [
            {
              'kind': 'class_level_grant',
              'target_ref': {'_ref': 'class', 'name': 'Wizard'},
              'value': 1,
            },
          ],
        },
      );
      final featB = _e(
        id: 'feat_b',
        slug: 'feat',
        name: 'B',
        fields: {
          'effects': [
            {
              'kind': 'class_level_grant',
              'target_ref': {'_ref': 'class', 'name': 'Fighter'},
              'value': 1,
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'feat_ids': ['feat_a', 'feat_b'],
      });
      // Should not infinite-loop. Each feat applies value=1 PER iteration —
      // resolver caps at 3 fixed-point iterations, so both classes hit 3.
      final eff = CharacterResolver.resolve(pc, {
        wizard.id: wizard,
        fighter.id: fighter,
        featA.id: featA,
        featB.id: featB,
      });
      expect(eff.classLevels['cls_wiz'], greaterThanOrEqualTo(1));
      expect(eff.classLevels['cls_ftr'], greaterThanOrEqualTo(1));
    });
  });
}
