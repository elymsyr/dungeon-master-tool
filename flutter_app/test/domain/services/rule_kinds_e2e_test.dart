import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end proof that EVERY grant-block field works when authored on a
/// feat card exactly as the editor stores it. A closing meta-test pins this
/// table to [CharacterResolver.grantFieldKeys], so adding a grant field
/// without an e2e case here fails the suite.

Entity _e(String id, String slug, String name,
        [Map<String, dynamic>? fields]) =>
    Entity(id: id, categorySlug: slug, name: name, fields: fields ?? const {});

Character _pc(Map<String, dynamic> fields) => Character(
      id: 'pc1',
      templateId: 'tpl',
      templateName: 'Tpl',
      entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: fields),
      worldId: 'world',
      createdAt: '0',
      updatedAt: '0',
    );

class _Case {
  final String name;

  /// Grant-block field keys this case proves.
  final Set<String> keys;

  /// The feat card's fields (grant-block keys).
  final Map<String, dynamic> grants;
  final List<Entity> entities;
  final void Function(EffectiveCharacter eff) verify;

  const _Case(this.name, this.keys, this.grants, this.entities, this.verify);
}

final _cases = <_Case>[
  _Case(
    'proficiency ref lists land on the right buckets',
    {
      'granted_skill_proficiencies', 'granted_tool_proficiencies',
      'granted_save_proficiencies', 'granted_weapon_proficiencies',
      'granted_armor_proficiencies', //
    },
    {
      'granted_skill_proficiencies': ['sk_x'],
      'granted_tool_proficiencies': ['tool_x'],
      'granted_save_proficiencies': ['ab_str'],
      'granted_weapon_proficiencies': ['wcat_x'],
      'granted_armor_proficiencies': ['acat_x'],
    },
    [
      _e('sk_x', 'skill', 'Arcana'),
      _e('tool_x', 'tool', 'Herbalism Kit'),
      _e('ab_str', 'ability', 'Strength'),
      _e('wcat_x', 'weapon-category', 'Martial'),
      _e('acat_x', 'armor-category', 'Heavy'),
    ],
    (eff) {
      expect(eff.proficiencies.skillIds, contains('sk_x'));
      expect(eff.proficiencies.toolIds, contains('tool_x'));
      expect(eff.proficiencies.savingThrowAbilityIds, contains('ab_str'));
      expect(eff.proficiencies.weaponCategoryIds, contains('wcat_x'));
      expect(eff.proficiencies.armorCategoryIds, contains('acat_x'));
    },
  ),
  _Case(
    'expertise skills',
    {'granted_expertise_skills'},
    {
      'granted_expertise_skills': ['sk_x'],
    },
    [_e('sk_x', 'skill', 'Stealth')],
    (eff) => expect(eff.expertiseSkillIds, contains('sk_x')),
  ),
  _Case(
    'languages',
    {'granted_languages'},
    {
      'granted_languages': ['lang_x'],
    },
    [_e('lang_x', 'language', 'Elvish')],
    (eff) => expect(eff.proficiencies.languageIds, contains('lang_x')),
  ),
  _Case(
    'spells, cantrips and always-prepared spells',
    {
      'granted_spell_refs', 'granted_cantrip_refs',
      'always_prepared_spell_refs', //
    },
    {
      'granted_spell_refs': ['sp_x'],
      'granted_cantrip_refs': ['sp_c'],
      'always_prepared_spell_refs': ['sp_p'],
    },
    [
      _e('sp_x', 'spell', 'Misty Step'),
      _e('sp_c', 'spell', 'Mage Hand'),
      _e('sp_p', 'spell', 'Divine Smite'),
    ],
    (eff) {
      expect(eff.grantedSpellIds, contains('sp_x'));
      expect(eff.grantedCantripIds, contains('sp_c'));
      expect(eff.alwaysPreparedSpellIds, contains('sp_p'));
    },
  ),
  _Case(
    'ability bonuses respect the raised cap (Primal Champion pattern)',
    {'ability_bonuses', 'ability_bonus_cap'},
    {
      'ability_bonuses': {'STR': 8, 'DEX': 4},
      'ability_bonus_cap': 22,
    },
    [],
    (eff) {
      // Base 18 + 8 = 26 clamps at the raised cap of 22.
      expect(eff.effectiveAbilities['STR'], 22);
      // Base 14 + 4 = 18 fits under the cap.
      expect(eff.effectiveAbilities['DEX'], 18);
    },
  ),
  _Case(
    'numeric bonuses accumulate',
    {
      'ac_bonus', 'speed_bonus_ft', 'initiative_bonus', 'hp_bonus_flat',
      'hp_bonus_per_level', //
    },
    {
      'ac_bonus': 2,
      'speed_bonus_ft': 5,
      'initiative_bonus': 3,
      'hp_bonus_flat': 4,
      'hp_bonus_per_level': 2,
    },
    [],
    (eff) {
      expect(eff.acBonus, 2);
      expect(eff.speedBonus, 5);
      expect(eff.initiativeBonus, 3);
      expect(eff.hpBonusFlat, 4);
      expect(eff.hpBonusPerLevel, 2);
    },
  ),
  _Case(
    'extra attacks: flat count and class-level table',
    {'extra_attack_count', 'extra_attack_count_by_level'},
    {
      'extra_attack_count': 2,
      'extra_attack_count_by_level': {'5': 2, '11': 3},
      // No class_ref → total character level (5) → table row 5 → 2; the
      // flat value ties, the max wins either way.
    },
    [],
    (eff) => expect(eff.extraAttackCount, 2),
  ),
  _Case(
    'crit threshold takes the lowest authored value',
    {'crit_threshold'},
    {'crit_threshold': 19},
    [],
    (eff) => expect(eff.critRangeMin, 19),
  ),
  _Case(
    'weapon mastery slots accumulate',
    {'weapon_mastery_count'},
    {'weapon_mastery_count': 3},
    [],
    (eff) => expect(eff.weaponMasteryCount, 3),
  ),
  _Case(
    'unarmored AC formula surfaces payload-compatible entry',
    {
      'unarmored_ac_base', 'unarmored_ac_abilities',
      'unarmored_ac_shield_allowed', //
    },
    {
      'unarmored_ac_base': 13,
      'unarmored_ac_abilities': ['ab_dex'],
      'unarmored_ac_shield_allowed': true,
    },
    [_e('ab_dex', 'ability', 'Dexterity')],
    (eff) {
      expect(eff.unarmoredFormulas, hasLength(1));
      final payload = eff.unarmoredFormulas.single['payload'] as Map;
      expect(payload['base'], 13);
      expect(payload['ability_mods'], ['DEX']);
      expect(payload['shield_allowed'], isTrue);
      // Unarmored PC, DEX 14 (+2): 13 + 2 = 15 beats default 10 + 2.
      expect(eff.armorClass, 15);
    },
  ),
  _Case(
    'defense ref lists land on the resolved sheet',
    {
      'granted_damage_resistances', 'granted_damage_immunities',
      'granted_damage_vulnerabilities', 'granted_condition_immunities', //
    },
    {
      'granted_damage_resistances': ['dt_fire'],
      'granted_damage_immunities': ['dt_poison'],
      'granted_damage_vulnerabilities': ['dt_cold'],
      'granted_condition_immunities': ['cond_x'],
    },
    [
      _e('dt_fire', 'damage-type', 'Fire'),
      _e('dt_poison', 'damage-type', 'Poison'),
      _e('dt_cold', 'damage-type', 'Cold'),
      _e('cond_x', 'condition', 'Charmed'),
    ],
    (eff) {
      expect(eff.damageResistanceIds, contains('dt_fire'));
      expect(eff.damageImmunityIds, contains('dt_poison'));
      expect(eff.damageVulnerabilityIds, contains('dt_cold'));
      expect(eff.conditionImmunityIds, contains('cond_x'));
    },
  ),
  _Case(
    'senses rows carry ranges; largest range wins',
    {'granted_senses'},
    {
      'granted_senses': [
        {'sense_ref': 'sense_dv', 'range_ft': 60},
        {'sense_ref': 'sense_dv', 'range_ft': 120},
      ],
    },
    [_e('sense_dv', 'sense', 'Darkvision')],
    (eff) {
      expect(eff.senseEntityIds, contains('sense_dv'));
      expect(eff.senseRanges['sense_dv'], 120);
    },
  ),
  _Case(
    'alternate speeds: explicit feet and the -1 equals-walk sentinel',
    {'speed_fly_ft', 'speed_swim_ft', 'speed_climb_ft', 'speed_burrow_ft'},
    {
      'speed_fly_ft': 40,
      'speed_swim_ft': -1,
      'speed_climb_ft': -1,
      'speed_burrow_ft': 20,
    },
    [],
    (eff) {
      expect(eff.extraSpeeds['fly'], 40);
      expect(eff.extraSpeeds['burrow'], 20);
      // -1 resolves to walk speed (default 30) at the end of resolve.
      expect(eff.extraSpeeds['swim'], 30);
      expect(eff.extraSpeeds['climb'], 30);
    },
  ),
  _Case(
    'granted creature actions land in their buckets',
    {
      'granted_action_refs', 'granted_bonus_action_refs',
      'granted_reaction_refs', //
    },
    {
      'granted_action_refs': ['act_x'],
      'granted_bonus_action_refs': ['act_b'],
      'granted_reaction_refs': ['act_r'],
    },
    [
      _e('act_x', 'creature-action', 'Breath Weapon'),
      _e('act_b', 'creature-action', 'Cunning Action'),
      _e('act_r', 'creature-action', "Stone's Endurance"),
    ],
    (eff) {
      expect(eff.grantedActionIds, contains('act_x'));
      expect(eff.grantedBonusActionIds, contains('act_b'));
      expect(eff.grantedReactionIds, contains('act_r'));
    },
  ),
  _Case(
    'trait refs auto-grant the trait and apply its block',
    {'trait_refs'},
    {
      'trait_refs': ['trait_x'],
    },
    [
      _e('trait_x', 'trait', 'Dwarven Toughness', {'hp_bonus_per_level': 1}),
    ],
    (eff) {
      expect(eff.autoGrantedTraitIds, contains('trait_x'));
      expect(eff.hpBonusPerLevel, 1);
    },
  ),
  _Case(
    'resource pools: level table beats formula beats flat count',
    {'resource_pool_grants'},
    {
      'resource_pool_grants': [
        {
          'pool_ref': {'name': 'pool:rage_uses'},
          'recharge': 'long_rest',
          'count': 1,
          'count_by_level': {'1': 2, '3': 3},
        },
      ],
    },
    [],
    (eff) {
      expect(eff.resourcePools, hasLength(1));
      // Total level 5 → table row 3 → 3.
      expect(eff.resourcePools.single['max'], 3);
      expect(eff.resourcePools.single['recharge'], 'long_rest');
    },
  ),
  _Case(
    'active_while_state_ref routes defense to conditionalGrants and keeps '
    'pools + prefixed notes',
    {'active_while_state_ref'},
    {
      'active_while_state_ref': 'state_raging',
      'granted_damage_resistances': ['dt_fire'],
      'ac_bonus': 5, // gated numeric — must NOT hit the resting sheet
      'resource_pool_grants': [
        {
          'pool_ref': {'name': 'pool:rage_uses'},
          'recharge': 'long_rest',
          'count': 2,
        },
      ],
      'mechanical_notes': 'Advantage on Strength checks',
    },
    [
      _e('state_raging', 'character-state', 'state:raging'),
      _e('dt_fire', 'damage-type', 'Fire'),
    ],
    (eff) {
      expect(eff.acBonus, 0);
      expect(eff.damageResistanceIds, isEmpty);
      expect(eff.conditionalGrants, hasLength(1));
      expect(eff.conditionalGrants.single['state'], 'state:raging');
      expect(eff.conditionalGrants.single['ids'], ['dt_fire']);
      expect(eff.resourcePools.single['max'], 2);
      expect(eff.mechanicalNotes,
          contains('while raging: Advantage on Strength checks'));
    },
  ),
  _Case(
    'mechanical notes surface verbatim, one per line',
    {'mechanical_notes'},
    {
      'mechanical_notes': 'First rule\nSecond rule',
    },
    [],
    (eff) {
      expect(eff.mechanicalNotes, contains('First rule'));
      expect(eff.mechanicalNotes, contains('Second rule'));
    },
  ),
];

void main() {
  group('grant-block e2e (feat card → resolved sheet)', () {
    for (final c in _cases) {
      test(c.name, () {
        final feat = Entity(
          id: 'feat_x',
          categorySlug: 'feat',
          name: 'Test Feat',
          fields: c.grants,
        );
        final entities = {
          'feat_x': feat,
          'cls_a': _e('cls_a', 'class', 'Fighter'),
          for (final e in c.entities) e.id: e,
        };
        final eff = CharacterResolver.resolve(
          _pc({
            'feat_ids': ['feat_x'],
            'class_levels': {'cls_a': 5},
            'base_abilities': {
              'STR': 18, 'DEX': 14, 'CON': 10,
              'INT': 10, 'WIS': 10, 'CHA': 10, //
            },
          }),
          entities,
        );
        c.verify(eff);
      });
    }

    test('every grant field key has an e2e case (or is choice-plumbing)', () {
      final covered = <String>{for (final c in _cases) ...c.keys};
      // `player_choices` is deliberately not resolver-applied — it queues
      // pending picks via pending_choices.dart (covered by its own tests).
      final expected = CharacterResolver.grantFieldKeys
          .difference(const {'player_choices'});
      expect(covered, expected,
          reason: 'add an e2e case when adding a grant field');
    });
  });
}
