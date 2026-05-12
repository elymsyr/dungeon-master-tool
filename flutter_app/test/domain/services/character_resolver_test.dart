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
            {'level': 1, 'description': 'Second Wind'},
            {'level': 2, 'description': 'Action Surge'},
            {'level': 5, 'description': 'Extra Attack'},
            {'level': 11, 'description': 'Improved Critical'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_fighter': 5},
      });
      final eff = CharacterResolver.resolve(pc, {fighter.id: fighter});
      final descs = eff.activeFeatures.map((r) => r.description).toList();
      expect(descs, containsAll(['Second Wind', 'Action Surge', 'Extra Attack']));
      expect(descs, isNot(contains('Improved Critical')));
    });

    test('feat with class_level_grant bumps effective class level', () {
      final wizard = _e(
        id: 'cls_wiz',
        slug: 'class',
        name: 'Wizard',
        fields: {
          'features': [
            {'level': 1, 'description': 'Wizard Spellcasting'},
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
        eff.activeFeatures.any((r) => r.description == 'Wizard Spellcasting'),
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
            {'level': 1, 'description': 'Spellcasting'},
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
            {'level': 3, 'description': 'Disciple of Life'},
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
        effLow.activeFeatures.any((r) => r.description == 'Disciple of Life'),
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
        effHi.activeFeatures.any((r) => r.description == 'Disciple of Life'),
        true,
      );
    });

    test('multiclass: subclass features gate on parent class level, not max', () {
      // Cleric 2 / Wizard 5. Life Domain (Cleric subclass) grants at L3.
      // Old heuristic used max(class_levels)=5 and would have wrongly fired
      // the subclass feature; SRD §1.10 says subclass gates on parent class.
      final cleric = _e(
        id: 'cls_cleric',
        slug: 'class',
        name: 'Cleric',
        fields: const {},
      );
      final wizard = _e(
        id: 'cls_wizard',
        slug: 'class',
        name: 'Wizard',
        fields: const {},
      );
      final life = _e(
        id: 'sub_life',
        slug: 'subclass',
        name: 'Life Domain',
        fields: {
          'parent_class_ref': 'cls_cleric',
          'granted_at_level': 3,
          'features': [
            {'level': 3, 'description': 'Disciple of Life'},
          ],
        },
      );
      final pc = _pc(id: 'pcMc', fields: {
        'class_levels': {'cls_cleric': 2, 'cls_wizard': 5},
        'subclass_id': 'sub_life',
      });
      final eff = CharacterResolver.resolve(
        pc,
        {cleric.id: cleric, wizard.id: wizard, life.id: life},
      );
      expect(
        eff.activeFeatures.any((r) => r.description == 'Disciple of Life'),
        isFalse,
        reason: 'Cleric 2 < granted_at_level 3 — subclass must not fire even '
            'though Wizard 5 > 3.',
      );
    });

    test('multiclass: subclass fires at parent class level once it crosses gate', () {
      final cleric = _e(
        id: 'cls_cleric',
        slug: 'class',
        name: 'Cleric',
        fields: const {},
      );
      final wizard = _e(
        id: 'cls_wizard',
        slug: 'class',
        name: 'Wizard',
        fields: const {},
      );
      final life = _e(
        id: 'sub_life',
        slug: 'subclass',
        name: 'Life Domain',
        fields: {
          'parent_class_ref': 'cls_cleric',
          'granted_at_level': 3,
          'features': [
            {'level': 3, 'description': 'Disciple of Life'},
          ],
        },
      );
      final pc = _pc(id: 'pcMc2', fields: {
        'class_levels': {'cls_cleric': 3, 'cls_wizard': 1},
        'subclass_id': 'sub_life',
      });
      final eff = CharacterResolver.resolve(
        pc,
        {cleric.id: cleric, wizard.id: wizard, life.id: life},
      );
      expect(
        eff.activeFeatures.any((r) => r.description == 'Disciple of Life'),
        isTrue,
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

    test('subclass saving_throw_refs add proficient saves beyond class', () {
      final strAbility = _e(
        id: 'ab_str',
        slug: 'ability',
        name: 'Strength',
      );
      final wisAbility = _e(
        id: 'ab_wis',
        slug: 'ability',
        name: 'Wisdom',
      );
      final cls = _e(
        id: 'cls_fighter',
        slug: 'class',
        name: 'Fighter',
        fields: {
          'saving_throw_refs': [
            {'slug': 'ability', 'name': 'Strength'},
          ],
        },
      );
      final sub = _e(
        id: 'sub_eldritch_knight',
        slug: 'subclass',
        name: 'Eldritch Knight',
        fields: {
          'granted_at_level': 3,
          'saving_throw_refs': [
            {'slug': 'ability', 'name': 'Wisdom'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_fighter': 3},
        'subclass_id': 'sub_eldritch_knight',
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        sub.id: sub,
        strAbility.id: strAbility,
        wisAbility.id: wisAbility,
      });
      expect(
        eff.proficiencies.savingThrowAbilityIds,
        containsAll(['ab_str', 'ab_wis']),
      );
    });

    test('subspecies row folds granted_damage_resistances into character', () {
      final fire = _e(
        id: 'dmg_fire',
        slug: 'damage-type',
        name: 'Fire',
      );
      final dragonborn = _e(
        id: 'species_dragonborn',
        slug: 'species',
        name: 'Dragonborn',
        fields: {
          'subspecies_options': [
            {
              'name': 'Red',
              'granted_damage_resistances': [
                {'slug': 'damage-type', 'name': 'Fire'},
              ],
            },
            {
              'name': 'Black',
              'granted_damage_resistances': [
                {'slug': 'damage-type', 'name': 'Acid'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_dragonborn',
        'subspecies_id': 'Red',
      });
      final eff = CharacterResolver.resolve(pc, {
        dragonborn.id: dragonborn,
        fire.id: fire,
      });
      expect(eff.damageResistanceIds, contains('dmg_fire'));
    });

    test('subspecies row speed_bonus modifier stacks with base speed', () {
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Wood Elf',
              'granted_modifiers': [
                {'kind': 'speed_bonus', 'value': 5},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_elf',
        'subspecies_id': 'Wood Elf',
      });
      final eff = CharacterResolver.resolve(pc, {elf.id: elf});
      expect(eff.speedBonus, 5);
    });

    test('subspecies_id with no matching row is a no-op', () {
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Wood Elf',
              'granted_modifiers': [
                {'kind': 'speed_bonus', 'value': 5},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_elf',
        'subspecies_id': 'High Elf',
      });
      final eff = CharacterResolver.resolve(pc, {elf.id: elf});
      expect(eff.speedBonus, 0);
    });

    test('subclass feature with proficiency_grant (saving_throw) folds in', () {
      final chaAbility = _e(
        id: 'ab_cha',
        slug: 'ability',
        name: 'Charisma',
      );
      final cls = _e(
        id: 'cls_sorcerer',
        slug: 'class',
        name: 'Sorcerer',
      );
      final sub = _e(
        id: 'sub_soul',
        slug: 'subclass',
        name: 'Soul of Sorcery',
        fields: {
          'granted_at_level': 1,
          'features': [
            {
              'level': 1,
              'name': 'Soul Save',
              'effects': [
                {
                  'kind': 'proficiency_grant',
                  'target_kind': 'saving_throw',
                  'target_ref': {'slug': 'ability', 'name': 'Charisma'},
                },
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_sorcerer': 1},
        'subclass_id': 'sub_soul',
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        sub.id: sub,
        chaAbility.id: chaAbility,
      });
      expect(eff.proficiencies.savingThrowAbilityIds, contains('ab_cha'));
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

    test('auto_granted_by walker applies feat when class level matches', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
      );
      final feat = _e(
        id: 'feat_unarmored_barb',
        slug: 'feat',
        name: 'Unarmored Defense (Barbarian)',
        fields: {
          'auto_granted_by': [
            {
              'source': 'class',
              'source_ref': 'cls_barb',
              'at_level': 1,
            },
          ],
          'effects': [
            {
              'kind': 'unarmored_ac_formula',
              'payload': {
                'base': 10,
                'ability_mods': ['DEX', 'CON'],
                'shield_allowed': true,
              },
              'predicates': [
                {'kind': 'equipped_armor_kind', 'args': {'value': 'none'}},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc_barb', fields: {
        'class_levels': {'cls_barb': 1},
      });
      final eff = CharacterResolver.resolve(pc, {cls.id: cls, feat.id: feat});
      expect(eff.autoGrantedFeatIds, contains('feat_unarmored_barb'));
      expect(eff.unarmoredFormulas, isNotEmpty);
      expect(eff.unarmoredFormulas.first['kind'], 'unarmored_ac_formula');
    });

    test('auto_granted_by below required level does not apply', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
      );
      final feat = _e(
        id: 'feat_brutal_strike',
        slug: 'feat',
        name: 'Brutal Strike',
        fields: {
          'auto_granted_by': [
            {'source': 'class', 'source_ref': 'cls_barb', 'at_level': 9},
          ],
          'effects': [
            {'kind': 'damage_resistance', 'target_ref': 'd_b'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_barb': 5},
      });
      final eff = CharacterResolver.resolve(pc, {cls.id: cls, feat.id: feat});
      expect(eff.autoGrantedFeatIds, isNot(contains('feat_brutal_strike')));
    });

    test('damage_resistance + damage_immunity + condition_immunity flow', () {
      final dmgB = _e(id: 'd_b', slug: 'damage-type', name: 'Bludgeoning');
      final dmgF = _e(id: 'd_f', slug: 'damage-type', name: 'Fire');
      final condC = _e(id: 'c_charm', slug: 'condition', name: 'Charmed');
      final feat = _e(
        id: 'feat_x',
        slug: 'feat',
        name: 'Hardiness',
        fields: {
          'effects': [
            {'kind': 'damage_resistance', 'target_ref': 'd_b'},
            {'kind': 'damage_immunity', 'target_ref': 'd_f'},
            {'kind': 'condition_immunity_grant', 'target_ref': 'c_charm'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_x']});
      final eff = CharacterResolver.resolve(pc, {
        dmgB.id: dmgB, dmgF.id: dmgF, condC.id: condC, feat.id: feat,
      });
      expect(eff.damageResistanceIds, contains('d_b'));
      expect(eff.damageImmunityIds, contains('d_f'));
      expect(eff.conditionImmunityIds, contains('c_charm'));
    });

    test('extra_attack_count multiclass takes max not sum', () {
      final featA = _e(
        id: 'fa', slug: 'feat', name: 'A',
        fields: {'effects': [{'kind': 'extra_attack_count', 'value': 2}]},
      );
      final featB = _e(
        id: 'fb', slug: 'feat', name: 'B',
        fields: {'effects': [{'kind': 'extra_attack_count', 'value': 3}]},
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['fa', 'fb']});
      final eff = CharacterResolver.resolve(pc, {featA.id: featA, featB.id: featB});
      expect(eff.extraAttackCount, 3);
    });

    test('class_level_at_least predicate gates effect', () {
      final cls = _e(id: 'cls_barb', slug: 'class', name: 'Barbarian');
      final dmgB = _e(id: 'd_b', slug: 'damage-type', name: 'Bludgeoning');
      final feat = _e(
        id: 'feat_late',
        slug: 'feat',
        name: 'Late',
        fields: {
          'auto_granted_by': [
            {'source': 'class', 'source_ref': 'cls_barb', 'at_level': 1},
          ],
          'effects': [
            {
              'kind': 'damage_resistance',
              'target_ref': 'd_b',
              'predicates': [
                {
                  'kind': 'class_level_at_least',
                  'args': {'class_ref': 'cls_barb', 'level': 9},
                },
              ],
            },
          ],
        },
      );
      // L5: feat is auto-granted but the per-effect predicate fails.
      final pc5 = _pc(id: 'pc5', fields: {'class_levels': {'cls_barb': 5}});
      final eff5 = CharacterResolver.resolve(pc5, {
        cls.id: cls, dmgB.id: dmgB, feat.id: feat,
      });
      expect(eff5.autoGrantedFeatIds, contains('feat_late'));
      expect(eff5.damageResistanceIds, isNot(contains('d_b')));
      // L9: predicate passes; resistance applies.
      final pc9 = _pc(id: 'pc9', fields: {'class_levels': {'cls_barb': 9}});
      final eff9 = CharacterResolver.resolve(pc9, {
        cls.id: cls, dmgB.id: dmgB, feat.id: feat,
      });
      expect(eff9.damageResistanceIds, contains('d_b'));
    });

    test('trait auto_granted_by surfaces in autoGrantedTraitIds', () {
      final cls = _e(
        id: 'cls_druid',
        slug: 'class',
        name: 'Druid',
        fields: {'features': const <Map<String, dynamic>>[]},
      );
      final trait = _e(
        id: 'trait_druidic',
        slug: 'trait',
        name: 'Druidic',
        fields: {
          'description': 'You know Druidic, the secret language of druids.',
          'auto_granted_by': [
            {
              'source': 'class',
              'source_ref': {'_ref': 'class', 'name': 'Druid'},
              'at_level': 1,
            }
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_druid': 1},
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        trait.id: trait,
      });
      expect(eff.autoGrantedTraitIds, contains('trait_druidic'));
      // Trait must NOT be in autoGrantedFeatIds.
      expect(eff.autoGrantedFeatIds, isNot(contains('trait_druidic')));
    });

    test('level row surfaces level + description only (no ref fields)', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
        fields: {
          'features': [
            {
              'level': 1,
              'feat_ref': {'_ref': 'feat', 'name': 'Rage'}, // legacy, ignored
              'description': 'Rage / Unarmored Defense / Weapon Mastery.',
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_barb': 1},
      });
      final eff = CharacterResolver.resolve(pc, {cls.id: cls});
      final row = eff.activeFeatures.firstWhere((r) => r.level == 1);
      expect(row.description, 'Rage / Unarmored Defense / Weapon Mastery.');
      expect(row.sourceEntityId, 'cls_barb');
    });
  });
}
