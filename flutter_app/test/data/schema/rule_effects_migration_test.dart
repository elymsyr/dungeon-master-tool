import 'package:dungeon_master_tool/data/schema/rule_effects_migration.dart';
import 'package:flutter_test/flutter_test.dart';

/// The migration's core promise: every legacy `rule_effects` /
/// `granted_modifiers` / feat-`effects` row either lands on a named grant
/// field or becomes a readable `mechanical_notes` line — never a silent drop.

void main() {
  group('migrateRuleEffects', () {
    test('no legacy keys → identical map (zero-cost no-op)', () {
      final fields = {'ac_bonus': 1, 'description': 'x'};
      expect(identical(migrateRuleEffects(fields), fields), isTrue);
    });

    test('spell narrative `effects` field is not mistaken for the DSL', () {
      final fields = {
        'effects': [
          {'kind': 'damage', 'dice': '8d6', 'save_effect': 'half'},
        ],
      };
      expect(identical(migrateRuleEffects(fields), fields), isTrue);
    });

    test('ref-list kinds land on their named fields', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'damage_resistance', 'target_ref': 'dt_fire'},
          {'kind': 'condition_immunity_grant', 'target_ref': 'cond_x'},
          {'kind': 'spell_always_prepared', 'target_ref': 'sp_x'},
          {'kind': 'expertise_grant', 'target_ref': 'sk_x'},
          {'kind': 'language_grant', 'target_ref': 'lang_x'},
        ],
      });
      expect(out.containsKey('rule_effects'), isFalse);
      expect(out['granted_damage_resistances'], ['dt_fire']);
      expect(out['granted_condition_immunities'], ['cond_x']);
      expect(out['always_prepared_spell_refs'], ['sp_x']);
      expect(out['granted_expertise_skills'], ['sk_x']);
      expect(out['granted_languages'], ['lang_x']);
    });

    test('proficiency_grant routes by target_kind; save alias handled', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'proficiency_grant', 'target_kind': 'skill', 'target_ref': 'sk'},
          {'kind': 'proficiency_grant', 'target_kind': 'save', 'target_ref': 'ab'},
          {'kind': 'proficiency_grant', 'target_kind': 'armor_category', 'target_ref': 'ac'},
        ],
      });
      expect(out['granted_skill_proficiencies'], ['sk']);
      expect(out['granted_save_proficiencies'], ['ab']);
      expect(out['granted_armor_proficiencies'], ['ac']);
    });

    test('int kinds sum into their fields', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'ac_bonus', 'value': 1},
          {'kind': 'ac_bonus', 'value': 2},
          {'kind': 'hp_max_bonus_total', 'value': 3},
          {'kind': 'hp_bonus_flat', 'value': 2},
        ],
      });
      expect(out['ac_bonus'], 3);
      expect(out['hp_bonus_flat'], 5, reason: 'flat + total merge');
    });

    test('ability_score_bonus builds the bonuses map and raises the cap', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'ability_score_bonus', 'ability': 'STR', 'value': 4, 'max': 25},
          {'kind': 'ability_score_bonus', 'ability': 'Constitution', 'value': 4, 'max': 25},
        ],
      });
      expect(out['ability_bonuses'], {'STR': 4, 'CON': 4});
      expect(out['ability_bonus_cap'], 25);
    });

    test('sense_grant keeps the payload range', () {
      final out = migrateRuleEffects({
        'granted_modifiers': [
          {
            'kind': 'sense_grant',
            'target_ref': {'slug': 'sense', 'name': 'Darkvision'},
            'payload': {'range_ft': 120},
          },
        ],
      });
      final rows = out['granted_senses'] as List;
      expect((rows.single as Map)['range_ft'], 120);
    });

    test('unarmored_ac_formula splits into the three named fields', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {
            'kind': 'unarmored_ac_formula',
            'payload': {
              'base': 13,
              'ability_mods': ['DEX'],
              'shield_allowed': true,
            },
          },
        ],
      });
      expect(out['unarmored_ac_base'], 13);
      expect(out['unarmored_ac_shield_allowed'], isTrue);
      final mods = out['unarmored_ac_abilities'] as List;
      expect((mods.single as Map)['name'], 'Dexterity');
    });

    test('resource_pool_grant converts scales_with into count_by_level', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {
            'kind': 'resource_pool_grant',
            'payload': {
              'pool_ref': {'name': 'pool:rage_uses'},
              'recharge': 'long_rest',
            },
            'scales_with': {
              'kind': 'class_level',
              'class_ref': {'slug': 'class', 'name': 'Barbarian'},
              'table': [
                {'lvl': 1, 'v': 2},
                {'lvl': 3, 'v': 3},
              ],
            },
          },
        ],
      });
      final pool = (out['resource_pool_grants'] as List).single as Map;
      expect(pool['count_by_level'], {'1': 2, '3': 3});
      expect((pool['class_ref'] as Map)['name'], 'Barbarian');
    });

    test('choice_group payloads become player_choices rows', () {
      final out = migrateRuleEffects({
        'effects': [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'picks',
              'label': 'Skill or Tool',
              'pick_kind': 'skill_or_tool',
              'pick': 3,
            },
          },
        ],
      });
      final row = (out['player_choices'] as List).single as Map;
      expect(row['group_id'], 'picks');
      expect(row['pick'], 3);
    });

    test('speed kinds map to the -1 sentinel / explicit feet', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'climb_speed_equals_speed'},
          {'kind': 'fly_speed', 'value': 40},
        ],
      });
      expect(out['speed_climb_ft'], -1);
      expect(out['speed_fly_ft'], 40);
    });

    test('state-gated defense rows become the card-level gate', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {
            'kind': 'damage_resistance',
            'target_ref': 'dt_bludgeoning',
            'predicates': [
              {'kind': 'has_state', 'args': {'ref': 'state:raging'}},
            ],
          },
        ],
      });
      expect(out['active_while_state_ref'], 'state:raging');
      expect(out['granted_damage_resistances'], ['dt_bludgeoning']);
    });

    test('state-gated roll-time rows become prefixed notes', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {
            'kind': 'advantage_on',
            'target_kind': 'check',
            'target_ref': {'slug': 'ability', 'name': 'Strength'},
            'predicates': [
              {'kind': 'has_state', 'args': {'ref': 'state:raging'}},
            ],
          },
        ],
      });
      final notes = out['mechanical_notes'] as String;
      expect(notes, contains('While raging'));
      expect(notes, contains('Strength'));
    });

    test('every documented no-op kind produces a note, never a silent drop',
        () {
      for (final kind in legacyKindNotes.keys) {
        if (legacyKindNotes[kind]!.isEmpty) continue; // narrative-only rows
        final out = migrateRuleEffects({
          'rule_effects': [
            {'kind': kind, 'value': 2, 'target_ref': 'x'},
          ],
        });
        expect(out['mechanical_notes'], isNotNull,
            reason: '$kind must surface as a note');
      }
    });

    test('an unknown kind still survives as a note', () {
      final out = migrateRuleEffects({
        'rule_effects': [
          {'kind': 'homebrew_mystery_rule', 'target_ref': {'name': 'Fire'}},
        ],
      });
      expect(out['mechanical_notes'], contains('homebrew_mystery_rule'));
    });

    test('legacy granted_modifiers aliases resolve', () {
      final out = migrateRuleEffects({
        'granted_modifiers': [
          {'kind': 'resistance_grant', 'target_ref': 'dt_fire'},
          {'kind': 'spell_known_grant', 'target_ref': 'sp_x'},
          {'kind': 'feature_text', 'notes': 'narrative only'},
        ],
      });
      expect(out['granted_damage_resistances'], ['dt_fire']);
      expect(out['granted_spell_refs'], ['sp_x']);
      expect(out.containsKey('granted_modifiers'), isFalse);
    });

    test('existing named fields are appended to, not clobbered', () {
      final out = migrateRuleEffects({
        'granted_damage_resistances': ['dt_cold'],
        'rule_effects': [
          {'kind': 'damage_resistance', 'target_ref': 'dt_fire'},
        ],
      });
      expect(out['granted_damage_resistances'], ['dt_cold', 'dt_fire']);
    });
  });
}
