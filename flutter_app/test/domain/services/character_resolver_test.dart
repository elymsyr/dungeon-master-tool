import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_config.dart';
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
      worldId: 'world',
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

    test('Tough-style hp_bonus_per_level aggregates', () {
      final feat = _e(
        id: 'feat_tough',
        slug: 'feat',
        name: 'Tough',
        fields: {'hp_bonus_per_level': 2},
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
        fields: {'initiative_bonus': 5},
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
        // Choices are stored scoped by source entity id (`$sourceId:$groupId`).
        'equipment_choices': {'cls_barb:starting_kit': 'A'},
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        greataxe.id: greataxe,
      });
      expect(eff.inventory.length, 1);
      expect(eff.inventory.first.entityId, 'w_greataxe');
    });

    test('background equipment_choice_groups pick lands in inventory', () {
      final symbol =
          _e(id: 'g_holy', slug: 'adventuring-gear', name: 'Holy Symbol');
      final bg = _e(
        id: 'bg_acolyte',
        slug: 'background',
        name: 'Acolyte',
        fields: {
          'equipment_choice_groups': [
            {
              'group_id': 'bg-equipment',
              'label': 'Starting Equipment',
              'options': [
                {
                  'option_id': 'A',
                  'label': 'Holy Symbol',
                  'items': [
                    {
                      'ref': {'_ref': 'adventuring-gear', 'name': 'Holy Symbol'},
                      'quantity': 1,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'background_id': 'bg_acolyte',
        // Scoped key — background group_id collides with class 'bg-equipment'
        // only if unscoped, which is exactly the bug this guards.
        'equipment_choices': {'bg_acolyte:bg-equipment': 'A'},
      });
      final eff = CharacterResolver.resolve(pc, {
        bg.id: bg,
        symbol.id: symbol,
      });
      expect(eff.inventory.length, 1);
      expect(eff.inventory.first.entityId, 'g_holy');
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

    test('subspecies row speed_bonus_ft stacks with base speed', () {
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Wood Elf',
              'speed_bonus_ft': 5,
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

    test('species ability_bonuses raises the target ability', () {
      final dwarf = _e(
        id: 'species_dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: {
          'ability_bonuses': {'CON': 2},
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_dwarf',
        'base_abilities': {
          'STR': 10, 'DEX': 10, 'CON': 14,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {dwarf.id: dwarf});
      expect(eff.effectiveAbilities['CON'], 16);
    });

    test('ability_bonuses accepts a full ability name + clamps at 20', () {
      final boon = _e(
        id: 'species_boon',
        slug: 'species',
        name: 'Boon',
        fields: {
          // Full ability names are accepted alongside the STR/DEX/... form.
          'ability_bonuses': {'Strength': 5},
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_boon',
        'base_abilities': {
          'STR': 18, 'DEX': 10, 'CON': 10,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {boon.id: boon});
      expect(eff.effectiveAbilities['STR'], 20);
    });

    test('subspecies ability_bonuses stack with the species bonus', () {
      final dwarf = _e(
        id: 'species_dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: {
          'ability_bonuses': {'CON': 2},
          'subspecies_options': [
            {
              'name': 'Hill',
              'ability_bonuses': {'WIS': 1},
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_dwarf',
        'subspecies_id': 'Hill',
        'base_abilities': {
          'STR': 10, 'DEX': 10, 'CON': 14,
          'INT': 10, 'WIS': 12, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {dwarf.id: dwarf});
      expect(eff.effectiveAbilities['CON'], 16);
      expect(eff.effectiveAbilities['WIS'], 13);
    });

    test('species trait_refs populate autoGrantedTraitIds', () {
      final trait = _e(
        id: 'trait_resilience',
        slug: 'trait',
        name: 'Dwarven Resilience',
      );
      final dwarf = _e(
        id: 'species_dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: {
          'trait_refs': [
            {'slug': 'trait', 'name': 'Dwarven Resilience'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {'race_id': 'species_dwarf'});
      final eff = CharacterResolver.resolve(pc, {
        dwarf.id: dwarf,
        trait.id: trait,
      });
      expect(eff.autoGrantedTraitIds, contains('trait_resilience'));
      expect(eff.grantSources['trait_resilience'], contains('Dwarf'));
    });

    test('species granted_action_refs populate grantedActionIds', () {
      final breath = _e(
        id: 'action_breath',
        slug: 'creature-action',
        name: 'Breath Weapon',
      );
      final dragonborn = _e(
        id: 'species_dragonborn',
        slug: 'species',
        name: 'Dragonborn',
        fields: {
          'granted_action_refs': [
            {'slug': 'creature-action', 'name': 'Breath Weapon'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {'race_id': 'species_dragonborn'});
      final eff = CharacterResolver.resolve(pc, {
        dragonborn.id: dragonborn,
        breath.id: breath,
      });
      expect(eff.grantedActionIds, contains('action_breath'));
    });

    test('subspecies action/bonus_action/reaction refs fold in', () {
      final relentless = _e(
        id: 'action_relentless',
        slug: 'creature-action',
        name: "Stone's Endurance",
      );
      final jaunt = _e(
        id: 'action_jaunt',
        slug: 'creature-action',
        name: "Cloud's Jaunt",
      );
      final burn = _e(
        id: 'action_burn',
        slug: 'creature-action',
        name: "Fire's Burn",
      );
      final goliath = _e(
        id: 'species_goliath',
        slug: 'species',
        name: 'Goliath',
        fields: {
          'subspecies_options': [
            {
              'name': 'Hill Giant',
              'granted_action_refs': [
                {'slug': 'creature-action', 'name': "Fire's Burn"},
              ],
              'granted_bonus_action_refs': [
                {'slug': 'creature-action', 'name': "Cloud's Jaunt"},
              ],
              'granted_reaction_refs': [
                {'slug': 'creature-action', 'name': "Stone's Endurance"},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_goliath',
        'subspecies_id': 'Hill Giant',
      });
      final eff = CharacterResolver.resolve(pc, {
        goliath.id: goliath,
        relentless.id: relentless,
        jaunt.id: jaunt,
        burn.id: burn,
      });
      expect(eff.grantedActionIds, contains('action_burn'));
      expect(eff.grantedBonusActionIds, contains('action_jaunt'));
      expect(eff.grantedReactionIds, contains('action_relentless'));
    });

    test('background_asi bumps abilities gated by ability_score_options', () {
      final str = _e(id: 'ab_str', slug: 'ability', name: 'Strength');
      final con = _e(id: 'ab_con', slug: 'ability', name: 'Constitution');
      final dex = _e(id: 'ab_dex', slug: 'ability', name: 'Dexterity');
      final bg = _e(
        id: 'bg_soldier',
        slug: 'background',
        name: 'Soldier',
        fields: {
          'ability_score_options': [
            {'slug': 'ability', 'name': 'Strength'},
            {'slug': 'ability', 'name': 'Constitution'},
            {'slug': 'ability', 'name': 'Dexterity'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'background_id': 'bg_soldier',
        'background_asi': {'STR': 2, 'CON': 1},
        'base_abilities': {
          'STR': 13, 'DEX': 12, 'CON': 14,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {
        bg.id: bg,
        str.id: str,
        con.id: con,
        dex.id: dex,
      });
      expect(eff.effectiveAbilities['STR'], 15);
      expect(eff.effectiveAbilities['CON'], 15);
      expect(eff.effectiveAbilities['DEX'], 12);
    });

    test('background_asi rejects abilities not in ability_score_options', () {
      final str = _e(id: 'ab_str', slug: 'ability', name: 'Strength');
      final bg = _e(
        id: 'bg_acolyte',
        slug: 'background',
        name: 'Acolyte',
        fields: {
          'ability_score_options': [
            {'slug': 'ability', 'name': 'Strength'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'background_id': 'bg_acolyte',
        'background_asi': {'CHA': 2},
        'base_abilities': {
          'STR': 10, 'DEX': 10, 'CON': 10,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {bg.id: bg, str.id: str});
      expect(eff.effectiveAbilities['CHA'], 10);
      expect(eff.warnings, anyElement(contains('background_asi CHA')));
    });

    test('background_asi caps at 20', () {
      final str = _e(id: 'ab_str', slug: 'ability', name: 'Strength');
      final bg = _e(
        id: 'bg_x',
        slug: 'background',
        name: 'X',
        fields: {
          'ability_score_options': [
            {'slug': 'ability', 'name': 'Strength'},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'background_id': 'bg_x',
        'background_asi': {'STR': 5},
        'base_abilities': {
          'STR': 18, 'DEX': 10, 'CON': 10,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {bg.id: bg, str.id: str});
      expect(eff.effectiveAbilities['STR'], 20);
    });

    test('species + subspecies innate spells fold into granted spells/cantrips', () {
      final firebolt = _e(id: 'sp_firebolt', slug: 'spell', name: 'Fire Bolt');
      final hellish = _e(id: 'sp_hellish', slug: 'spell', name: 'Hellish Rebuke');
      final tiefling = _e(
        id: 'species_tiefling',
        slug: 'species',
        name: 'Tiefling',
        fields: {
          'subspecies_options': [
            {
              'name': 'Infernal',
              'granted_cantrip_refs': [
                {'slug': 'spell', 'name': 'Fire Bolt'},
              ],
              'granted_spell_refs': [
                {'slug': 'spell', 'name': 'Hellish Rebuke'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_tiefling',
        'subspecies_id': 'Infernal',
      });
      final eff = CharacterResolver.resolve(pc, {
        tiefling.id: tiefling,
        firebolt.id: firebolt,
        hellish.id: hellish,
      });
      expect(eff.grantedCantripIds, contains('sp_firebolt'));
      expect(eff.grantedSpellIds, contains('sp_hellish'));
      expect(eff.grantSources['sp_firebolt'], contains('Infernal Tiefling'));
    });

    test('granted_spells_at_level gates by total character level', () {
      final faerie = _e(id: 'sp_faerie', slug: 'spell', name: 'Faerie Fire');
      final darkness = _e(id: 'sp_darkness', slug: 'spell', name: 'Darkness');
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Drow',
              'granted_spells_at_level': [
                {
                  'spell_ref': {'slug': 'spell', 'name': 'Faerie Fire'},
                  'at_level': 3,
                },
                {
                  'spell_ref': {'slug': 'spell', 'name': 'Darkness'},
                  'at_level': 5,
                },
              ],
            },
          ],
        },
      );
      final cls = _e(id: 'cls_wizard', slug: 'class', name: 'Wizard');
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_elf',
        'subspecies_id': 'Drow',
        'class_levels': {'cls_wizard': 3},
      });
      final eff = CharacterResolver.resolve(pc, {
        elf.id: elf,
        faerie.id: faerie,
        darkness.id: darkness,
        cls.id: cls,
      });
      expect(eff.grantedSpellIds, contains('sp_faerie'));
      expect(eff.grantedSpellIds, isNot(contains('sp_darkness')));
    });

    test('granted_spells_at_level with is_cantrip routes to cantrip list', () {
      final firebolt = _e(id: 'sp_firebolt', slug: 'spell', name: 'Fire Bolt');
      final tief = _e(
        id: 'species_tief',
        slug: 'species',
        name: 'Tiefling',
        fields: {
          'subspecies_options': [
            {
              'name': 'Infernal',
              'granted_spells_at_level': [
                {
                  'spell_ref': {'slug': 'spell', 'name': 'Fire Bolt'},
                  'at_level': 1,
                  'is_cantrip': true,
                },
              ],
            },
          ],
        },
      );
      final cls = _e(id: 'cls_x', slug: 'class', name: 'X');
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_tief',
        'subspecies_id': 'Infernal',
        'class_levels': {'cls_x': 1},
      });
      final eff = CharacterResolver.resolve(pc, {
        tief.id: tief,
        firebolt.id: firebolt,
        cls.id: cls,
      });
      expect(eff.grantedCantripIds, contains('sp_firebolt'));
      expect(eff.grantedSpellIds, isNot(contains('sp_firebolt')));
    });

    test('granted_spells_at_level uses_per_long_rest creates resource pool', () {
      final faerie = _e(id: 'sp_faerie', slug: 'spell', name: 'Faerie Fire');
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Drow',
              'granted_spells_at_level': [
                {
                  'spell_ref': {'slug': 'spell', 'name': 'Faerie Fire'},
                  'at_level': 3,
                  'uses_per_long_rest': 1,
                },
              ],
            },
          ],
        },
      );
      final cls = _e(id: 'cls_x', slug: 'class', name: 'X');
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_elf',
        'subspecies_id': 'Drow',
        'class_levels': {'cls_x': 3},
      });
      final eff = CharacterResolver.resolve(pc, {
        elf.id: elf,
        faerie.id: faerie,
        cls.id: cls,
      });
      final pool = eff.resourcePools.firstWhere(
        (p) => p['pool_ref'] == 'sp_faerie',
        orElse: () => const {},
      );
      expect(pool['max'], 1);
      expect(pool['recharge'], 'long_rest');
    });

    test('Drow Superior Darkvision overrides base 60ft to 120ft', () {
      final darkvision = _e(
        id: 'sense_darkvision',
        slug: 'sense',
        name: 'Darkvision',
        fields: {'default_range_ft': 60},
      );
      final elf = _e(
        id: 'species_elf',
        slug: 'species',
        name: 'Elf',
        fields: {
          'granted_senses': [
            {'sense_ref': 'sense_darkvision', 'range_ft': 60},
          ],
          'subspecies_options': [
            {
              'name': 'Drow',
              'granted_senses': [
                {'sense_ref': 'sense_darkvision', 'range_ft': 120},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_elf',
        'subspecies_id': 'Drow',
      });
      final eff = CharacterResolver.resolve(pc, {
        elf.id: elf,
        darkvision.id: darkvision,
      });
      expect(eff.senseEntityIds, contains('sense_darkvision'));
      expect(eff.senseRanges['sense_darkvision'], 120);
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
              'speed_bonus_ft': 5,
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

    test('Hill Dwarf legacy subspecies grants Insight skill proficiency', () {
      final insight = _e(id: 'sk_insight', slug: 'skill', name: 'Insight');
      final dwarf = _e(
        id: 'species_dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Hill Dwarf',
              'granted_skill_proficiencies': [
                {'slug': 'skill', 'name': 'Insight'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_dwarf',
        'subspecies_id': 'Hill Dwarf',
      });
      final eff = CharacterResolver.resolve(pc, {
        dwarf.id: dwarf,
        insight.id: insight,
      });
      expect(eff.proficiencies.skillIds, contains('sk_insight'));
    });

    test('Mountain Dwarf legacy subspecies grants +2 flat HP', () {
      final dwarf = _e(
        id: 'species_dwarf',
        slug: 'species',
        name: 'Dwarf',
        fields: {
          'subspecies_options': [
            {
              'name': 'Mountain Dwarf',
              'hp_bonus_flat': 2,
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_dwarf',
        'subspecies_id': 'Mountain Dwarf',
      });
      final eff = CharacterResolver.resolve(pc, {dwarf.id: dwarf});
      expect(eff.hpBonusFlat, 2);
    });

    test('Lightfoot Halfling legacy subspecies grants Stealth proficiency', () {
      final stealth = _e(id: 'sk_stealth', slug: 'skill', name: 'Stealth');
      final hf = _e(
        id: 'species_halfling',
        slug: 'species',
        name: 'Halfling',
        fields: {
          'subspecies_options': [
            {
              'name': 'Lightfoot Halfling',
              'granted_skill_proficiencies': [
                {'slug': 'skill', 'name': 'Stealth'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_halfling',
        'subspecies_id': 'Lightfoot Halfling',
      });
      final eff = CharacterResolver.resolve(pc, {
        hf.id: hf,
        stealth.id: stealth,
      });
      expect(eff.proficiencies.skillIds, contains('sk_stealth'));
    });

    test('Stout Halfling legacy subspecies grants poison damage resistance',
        () {
      final poison = _e(id: 'dmg_poison', slug: 'damage-type', name: 'Poison');
      final hf = _e(
        id: 'species_halfling',
        slug: 'species',
        name: 'Halfling',
        fields: {
          'subspecies_options': [
            {
              'name': 'Stout Halfling',
              'granted_damage_resistances': [
                {'slug': 'damage-type', 'name': 'Poison'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_halfling',
        'subspecies_id': 'Stout Halfling',
      });
      final eff = CharacterResolver.resolve(pc, {
        hf.id: hf,
        poison.id: poison,
      });
      expect(eff.damageResistanceIds, contains('dmg_poison'));
    });

    test('Standard Human legacy subspecies grants +1 to all six abilities',
        () {
      final human = _e(
        id: 'species_human',
        slug: 'species',
        name: 'Human',
        fields: {
          'subspecies_options': [
            {
              'name': 'Standard Human',
              'ability_bonuses': {
                'STR': 1, 'DEX': 1, 'CON': 1,
                'INT': 1, 'WIS': 1, 'CHA': 1,
              },
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_human',
        'subspecies_id': 'Standard Human',
        'base_abilities': {
          'STR': 10, 'DEX': 10, 'CON': 10,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      final eff = CharacterResolver.resolve(pc, {human.id: human});
      for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
        expect(eff.effectiveAbilities[k], 11, reason: 'ability $k');
      }
    });

    test('Half-Orc legacy subspecies grants Intimidation proficiency', () {
      final intim = _e(
        id: 'sk_intimidation',
        slug: 'skill',
        name: 'Intimidation',
      );
      final orc = _e(
        id: 'species_orc',
        slug: 'species',
        name: 'Orc',
        fields: {
          'subspecies_options': [
            {
              'name': 'Half-Orc',
              'granted_skill_proficiencies': [
                {'slug': 'skill', 'name': 'Intimidation'},
              ],
            },
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {
        'race_id': 'species_orc',
        'subspecies_id': 'Half-Orc',
      });
      final eff = CharacterResolver.resolve(pc, {
        orc.id: orc,
        intim.id: intim,
      });
      expect(eff.proficiencies.skillIds, contains('sk_intimidation'));
    });

    test('subclass class-feature feat folds in its save proficiency', () {
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
              'description': 'CHA save prof.',
              'granted_feat_refs': ['feat_soul_save'],
            },
          ],
        },
      );
      final featureFeat = _e(
        id: 'feat_soul_save',
        slug: 'feat',
        name: 'Soul Save',
        fields: {'granted_save_proficiencies': ['ab_cha']},
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_sorcerer': 1},
        'subclass_id': 'sub_soul',
      });
      final eff = CharacterResolver.resolve(pc, {
        cls.id: cls,
        sub.id: sub,
        chaAbility.id: chaAbility,
        featureFeat.id: featureFeat,
      });
      expect(eff.proficiencies.savingThrowAbilityIds, contains('ab_cha'));
    });

    test('the class level table applies a feat once its level is reached', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
        fields: {
          'features': [
            {
              'level': 1,
              'name': 'Unarmored Defense',
              'granted_feat_refs': ['feat_unarmored_barb'],
            },
          ],
        },
      );
      final feat = _e(
        id: 'feat_unarmored_barb',
        slug: 'feat',
        name: 'Unarmored Defense (Barbarian)',
        fields: {
          // "While not wearing armor" is carried by the field names, so no
          // predicate is needed — _computeArmorClass only consults these when
          // no armor is equipped.
          'unarmored_ac_base': 10,
          'unarmored_ac_abilities': ['ab_dex', 'ab_con'],
          'unarmored_ac_shield_allowed': true,
        },
      );
      final dex = _e(id: 'ab_dex', slug: 'ability', name: 'Dexterity');
      final con = _e(id: 'ab_con', slug: 'ability', name: 'Constitution');
      final pc = _pc(id: 'pc_barb', fields: {
        'class_levels': {'cls_barb': 1},
      });
      final eff = CharacterResolver.resolve(
          pc, {cls.id: cls, feat.id: feat, dex.id: dex, con.id: con});
      expect(eff.autoGrantedFeatIds, contains('feat_unarmored_barb'));
      expect(eff.unarmoredFormulas, isNotEmpty);
      expect(
        (eff.unarmoredFormulas.first['payload'] as Map)['ability_mods'],
        ['DEX', 'CON'],
      );
    });

    test('a level table row above the character level does not apply', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
        fields: {
          'features': [
            {
              'level': 9,
              'name': 'Brutal Strike',
              'granted_feat_refs': ['feat_brutal_strike'],
            },
          ],
        },
      );
      final feat = _e(
        id: 'feat_brutal_strike',
        slug: 'feat',
        name: 'Brutal Strike',
        fields: {'granted_damage_resistances': ['d_b']},
      );
      final pc = _pc(id: 'pc1', fields: {
        'class_levels': {'cls_barb': 5},
      });
      final eff = CharacterResolver.resolve(pc, {cls.id: cls, feat.id: feat});
      expect(eff.autoGrantedFeatIds, isNot(contains('feat_brutal_strike')));
    });

    test('resistance / immunity / condition-immunity grants flow', () {
      final dmgB = _e(id: 'd_b', slug: 'damage-type', name: 'Bludgeoning');
      final dmgF = _e(id: 'd_f', slug: 'damage-type', name: 'Fire');
      final condC = _e(id: 'c_charm', slug: 'condition', name: 'Charmed');
      final feat = _e(
        id: 'feat_x',
        slug: 'feat',
        name: 'Hardiness',
        fields: {
          'granted_damage_resistances': ['d_b'],
          'granted_damage_immunities': ['d_f'],
          'granted_condition_immunities': ['c_charm'],
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
        fields: {'extra_attack_count': 2},
      );
      final featB = _e(
        id: 'fb', slug: 'feat', name: 'B',
        fields: {'extra_attack_count': 3},
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['fa', 'fb']});
      final eff = CharacterResolver.resolve(pc, {featA.id: featA, featB.id: featB});
      expect(eff.extraAttackCount, 3);
    });

    test('the features row level is the gate for a grant', () {
      final cls = _e(
        id: 'cls_barb',
        slug: 'class',
        name: 'Barbarian',
        fields: {
          'features': [
            {
              'level': 9,
              'name': 'Late',
              'granted_feat_refs': ['feat_late'],
            },
          ],
        },
      );
      final dmgB = _e(id: 'd_b', slug: 'damage-type', name: 'Bludgeoning');
      final feat = _e(
        id: 'feat_late',
        slug: 'feat',
        name: 'Late',
        fields: {'granted_damage_resistances': ['d_b']},
      );
      // L5: below the gate — the card is not granted at all.
      final pc5 = _pc(id: 'pc5', fields: {'class_levels': {'cls_barb': 5}});
      final eff5 = CharacterResolver.resolve(pc5, {
        cls.id: cls, dmgB.id: dmgB, feat.id: feat,
      });
      expect(eff5.autoGrantedFeatIds, isNot(contains('feat_late')));
      expect(eff5.damageResistanceIds, isNot(contains('d_b')));
      // L9: gate passes; the resistance applies.
      final pc9 = _pc(id: 'pc9', fields: {'class_levels': {'cls_barb': 9}});
      final eff9 = CharacterResolver.resolve(pc9, {
        cls.id: cls, dmgB.id: dmgB, feat.id: feat,
      });
      expect(eff9.autoGrantedFeatIds, contains('feat_late'));
      expect(eff9.damageResistanceIds, contains('d_b'));
    });

    test('a class-granted trait surfaces in autoGrantedTraitIds', () {
      final cls = _e(
        id: 'cls_druid',
        slug: 'class',
        name: 'Druid',
        fields: {
          'features': [
            {
              'level': 1,
              'name': 'Druidic',
              'granted_trait_refs': ['trait_druidic'],
            },
          ],
        },
      );
      final trait = _e(
        id: 'trait_druidic',
        slug: 'trait',
        name: 'Druidic',
        fields: {
          'description': 'You know Druidic, the secret language of druids.',
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

  group('CharacterResolver grant-block behaviour', () {
    test('-1 on an alternate speed means "equal to walking speed"', () {
      final feat = _e(
        id: 'feat_swim',
        slug: 'feat',
        name: 'Amphibious',
        fields: {'speed_swim_ft': -1, 'speed_climb_ft': -1},
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_swim']});
      final eff = CharacterResolver.resolve(pc, {feat.id: feat});
      expect(eff.extraSpeeds['swim'], 30);
      expect(eff.extraSpeeds['climb'], 30);
    });

    test('an explicit fly speed beats a "= walking speed" grant', () {
      final wings = _e(
        id: 'feat_wings', slug: 'feat', name: 'Wings',
        fields: {'speed_fly_ft': 60},
      );
      final glide = _e(
        id: 'feat_glide', slug: 'feat', name: 'Glide',
        fields: {'speed_fly_ft': -1},
      );
      final pc = _pc(id: 'pc1', fields: {
        'feat_ids': ['feat_glide', 'feat_wings'],
      });
      final eff = CharacterResolver.resolve(
          pc, {wings.id: wings, glide.id: glide});
      expect(eff.extraSpeeds['fly'], 60);
    });

    test('granted_senses keeps the largest range per sense', () {
      final dark = _e(id: 'sense_dark', slug: 'sense', name: 'Darkvision');
      final a = _e(
        id: 'feat_a', slug: 'feat', name: 'A',
        fields: {
          'granted_senses': [
            {'sense_ref': 'sense_dark', 'range_ft': 60},
          ],
        },
      );
      final b = _e(
        id: 'feat_b', slug: 'feat', name: 'B',
        fields: {
          'granted_senses': [
            {'sense_ref': 'sense_dark', 'range_ft': 120},
          ],
        },
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_a', 'feat_b']});
      final eff =
          CharacterResolver.resolve(pc, {dark.id: dark, a.id: a, b.id: b});
      expect(eff.senseEntityIds, contains('sense_dark'));
      expect(eff.senseRanges['sense_dark'], 120);
    });

    test('a bare ref in granted_senses is a sense with no stated range', () {
      final dark = _e(id: 'sense_dark', slug: 'sense', name: 'Darkvision');
      final feat = _e(
        id: 'feat_a', slug: 'feat', name: 'A',
        fields: {'granted_senses': ['sense_dark']},
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_a']});
      final eff = CharacterResolver.resolve(pc, {dark.id: dark, feat.id: feat});
      expect(eff.senseEntityIds, contains('sense_dark'));
      expect(eff.senseRanges['sense_dark'], isNull);
    });

    test('crit_threshold applies; an absurd value is refused with a warning',
        () {
      final champ = _e(
        id: 'feat_champ', slug: 'feat', name: 'Improved Critical',
        fields: {'crit_threshold': 19},
      );
      final broken = _e(
        id: 'feat_broken', slug: 'feat', name: 'Broken Crit',
        fields: {'crit_threshold': 1},
      );
      final ok = CharacterResolver.resolve(
          _pc(id: 'pc1', fields: {'feat_ids': ['feat_champ']}),
          {champ.id: champ});
      expect(ok.critRangeMin, 19);
      final bad = CharacterResolver.resolve(
          _pc(id: 'pc2', fields: {'feat_ids': ['feat_broken']}),
          {broken.id: broken});
      expect(bad.critRangeMin, 20, reason: 'threshold 1 must be ignored');
      expect(bad.warnings, anyElement(contains('crit_threshold')));
    });

    test('active_while_state_ref routes defenses to conditionalGrants', () {
      final fire = _e(id: 'd_fire', slug: 'damage-type', name: 'Fire');
      final raging =
          _e(id: 'state_raging', slug: 'character-state', name: 'state:raging');
      final feat = _e(
        id: 'feat_rage_res',
        slug: 'feat',
        name: 'Rage Resistance',
        fields: {
          'active_while_state_ref': 'state_raging',
          'granted_damage_resistances': ['d_fire'],
          // A numeric bonus on a gated card must NOT reach the resting sheet.
          'speed_bonus_ft': 10,
        },
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_rage_res']});
      final eff = CharacterResolver.resolve(pc, {
        fire.id: fire, raging.id: raging, feat.id: feat,
      });
      expect(eff.damageResistanceIds, isNot(contains('d_fire')));
      expect(
        eff.conditionalGrants.any((g) =>
            g['state'] == 'state:raging' &&
            g['kind'] == 'damage_resistance' &&
            (g['ids'] as List).contains('d_fire')),
        isTrue,
      );
      expect(eff.speedBonus, 0);
    });

    test('a gated card still contributes its mechanical notes, state-labelled',
        () {
      final raging =
          _e(id: 'state_raging', slug: 'character-state', name: 'state:raging');
      final feat = _e(
        id: 'feat_rage', slug: 'feat', name: 'Rage',
        fields: {
          'active_while_state_ref': 'state_raging',
          'mechanical_notes': 'Advantage on Strength checks and saves',
        },
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_rage']});
      final eff =
          CharacterResolver.resolve(pc, {raging.id: raging, feat.id: feat});
      expect(
        eff.mechanicalNotes,
        contains('while raging: Advantage on Strength checks and saves'),
      );
    });

    test('mechanical_notes split on newlines and de-duplicate', () {
      final a = _e(
        id: 'feat_a', slug: 'feat', name: 'A',
        fields: {'mechanical_notes': 'Line one\n\nLine two\n'},
      );
      final b = _e(
        id: 'feat_b', slug: 'feat', name: 'B',
        fields: {'mechanical_notes': 'Line one'},
      );
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_a', 'feat_b']});
      final eff = CharacterResolver.resolve(pc, {a.id: a, b.id: b});
      expect(eff.mechanicalNotes, ['Line one', 'Line two']);
    });

    test('no card grants anything → no warnings and empty totals', () {
      final feat = _e(id: 'feat_x', slug: 'feat', name: 'Plain');
      final pc = _pc(id: 'pc1', fields: {'feat_ids': ['feat_x']});
      final eff = CharacterResolver.resolve(pc, {feat.id: feat});
      expect(eff.warnings, isEmpty);
      expect(eff.extraSpeeds, isEmpty);
      expect(eff.mechanicalNotes, isEmpty);
    });

    test('RuleConfig acUnarmoredBase override feeds unarmored AC', () {
      final pc = _pc(id: 'pc1', fields: {
        'base_abilities': {
          'STR': 10, 'DEX': 14, 'CON': 10,
          'INT': 10, 'WIS': 10, 'CHA': 10,
        },
      });
      const config = RuleConfig(
        asiLevels: [4, 8, 12, 16, 19],
        hitDieToHp: {'d6': 4, 'd8': 5, 'd10': 6, 'd12': 7},
        acUnarmoredBase: 12,
        acShieldBonus: 2,
        proficiencyBonusBreakpoints: [5, 9, 13, 17],
      );
      final base = CharacterResolver.resolve(pc, const {});
      final tuned = CharacterResolver.resolve(pc, const {}, config: config);
      expect(base.armorClass, 12, reason: '10 base + 2 DEX mod');
      expect(tuned.armorClass, 14, reason: '12 base + 2 DEX mod');
    });
  });
}
