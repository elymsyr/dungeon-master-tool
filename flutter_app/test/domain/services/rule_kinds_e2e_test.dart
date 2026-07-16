import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end proof that EVERY sheet-applied rule kind works when authored
/// exactly as the effect editor stores it (String-id `target_ref`, top-level
/// `value`, nested `payload`). A closing meta-test pins this table to
/// [CharacterResolver.sheetAppliedEffectKinds], so adding an applied kind
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

  /// Kinds this case proves (usually one; proficiency_grant proves one per
  /// target-kind variant but still one kind).
  final Set<String> kinds;
  final List<Map<String, dynamic>> effects;
  final List<Entity> entities;
  final void Function(EffectiveCharacter eff) verify;

  const _Case(this.name, this.kinds, this.effects, this.entities, this.verify);
}

final _cases = <_Case>[
  _Case(
    'class_level_grant adds class levels',
    {'class_level_grant'},
    [
      {'kind': 'class_level_grant', 'target_kind': 'class', 'target_ref': 'cls_x', 'value': 1},
    ],
    [_e('cls_x', 'class', 'Wizard')],
    (eff) => expect(eff.classLevels['cls_x'], 1),
  ),
  _Case(
    'ability_score_bonus raises the ability',
    {'ability_score_bonus'},
    [
      {'kind': 'ability_score_bonus', 'target_kind': 'ability', 'target_ref': 'ab_str', 'value': 1},
    ],
    [_e('ab_str', 'ability', 'Strength')],
    (eff) => expect(eff.effectiveAbilities['STR'], 11),
  ),
  _Case(
    'ac_bonus accumulates',
    {'ac_bonus'},
    [
      {'kind': 'ac_bonus', 'value': 2},
    ],
    [],
    (eff) => expect(eff.acBonus, 2),
  ),
  _Case(
    'speed_bonus accumulates',
    {'speed_bonus'},
    [
      {'kind': 'speed_bonus', 'value': 5},
    ],
    [],
    (eff) => expect(eff.speedBonus, 5),
  ),
  _Case(
    'hp_bonus_per_level accumulates',
    {'hp_bonus_per_level'},
    [
      {'kind': 'hp_bonus_per_level', 'value': 2},
    ],
    [],
    (eff) => expect(eff.hpBonusPerLevel, 2),
  ),
  _Case(
    'hp_bonus_flat and hp_max_bonus_total both add flat HP',
    {'hp_bonus_flat', 'hp_max_bonus_total'},
    [
      {'kind': 'hp_bonus_flat', 'value': 2},
      {'kind': 'hp_max_bonus_total', 'value': 3},
    ],
    [],
    (eff) => expect(eff.hpBonusFlat, 5),
  ),
  _Case(
    'initiative_bonus accumulates',
    {'initiative_bonus'},
    [
      {'kind': 'initiative_bonus', 'value': 5},
    ],
    [],
    (eff) => expect(eff.initiativeBonus, 5),
  ),
  _Case(
    'proficiency_grant works for every catalog target kind',
    {'proficiency_grant'},
    [
      {'kind': 'proficiency_grant', 'target_kind': 'skill', 'target_ref': 'sk_x'},
      {'kind': 'proficiency_grant', 'target_kind': 'tool', 'target_ref': 'tool_x'},
      {'kind': 'proficiency_grant', 'target_kind': 'saving_throw', 'target_ref': 'ab_wis'},
      {'kind': 'proficiency_grant', 'target_kind': 'ability', 'target_ref': 'ab_cha'},
      {'kind': 'proficiency_grant', 'target_kind': 'armor_category', 'target_ref': 'armorcat_light'},
      {'kind': 'proficiency_grant', 'target_kind': 'weapon_category', 'target_ref': 'weaponcat_martial'},
    ],
    [
      _e('sk_x', 'skill', 'Arcana'),
      _e('tool_x', 'tool', "Smith's Tools"),
      _e('ab_wis', 'ability', 'Wisdom'),
      _e('ab_cha', 'ability', 'Charisma'),
      _e('armorcat_light', 'armor-category', 'Light'),
      _e('weaponcat_martial', 'weapon-category', 'Martial Melee'),
    ],
    (eff) {
      expect(eff.proficiencies.skillIds, contains('sk_x'));
      expect(eff.proficiencies.toolIds, contains('tool_x'));
      expect(eff.proficiencies.savingThrowAbilityIds, contains('ab_wis'));
      expect(eff.proficiencies.savingThrowAbilityIds, contains('ab_cha'));
      expect(eff.proficiencies.armorCategoryIds, contains('armorcat_light'));
      expect(eff.proficiencies.weaponCategoryIds, contains('weaponcat_martial'));
    },
  ),
  _Case(
    'language_grant adds the language',
    {'language_grant'},
    [
      {'kind': 'language_grant', 'target_kind': 'language', 'target_ref': 'lang_x'},
    ],
    [_e('lang_x', 'language', 'Elvish')],
    (eff) => expect(eff.proficiencies.languageIds, contains('lang_x')),
  ),
  _Case(
    'spell/cantrip/always-prepared grants land in their lists',
    {'spell_grant', 'cantrip_grant', 'spell_always_prepared'},
    [
      {'kind': 'spell_grant', 'target_kind': 'spell', 'target_ref': 'sp_a'},
      {'kind': 'cantrip_grant', 'target_kind': 'cantrip', 'target_ref': 'sp_b'},
      {'kind': 'spell_always_prepared', 'target_kind': 'spell', 'target_ref': 'sp_c'},
    ],
    [
      _e('sp_a', 'spell', 'Misty Step'),
      _e('sp_b', 'spell', 'Fire Bolt'),
      _e('sp_c', 'spell', 'Detect Thoughts'),
    ],
    (eff) {
      expect(eff.grantedSpellIds, contains('sp_a'));
      expect(eff.grantedCantripIds, contains('sp_b'));
      expect(eff.alwaysPreparedSpellIds, contains('sp_c'));
    },
  ),
  _Case(
    'damage resistance/immunity/vulnerability + condition immunity',
    {
      'damage_resistance',
      'damage_immunity',
      'damage_vulnerability',
      'condition_immunity_grant',
    },
    [
      {'kind': 'damage_resistance', 'target_kind': 'damage-type', 'target_ref': 'd_a'},
      {'kind': 'damage_immunity', 'target_kind': 'damage-type', 'target_ref': 'd_b'},
      {'kind': 'damage_vulnerability', 'target_kind': 'damage-type', 'target_ref': 'd_c'},
      {'kind': 'condition_immunity_grant', 'target_kind': 'condition', 'target_ref': 'c_x'},
    ],
    [
      _e('d_a', 'damage-type', 'Fire'),
      _e('d_b', 'damage-type', 'Poison'),
      _e('d_c', 'damage-type', 'Cold'),
      _e('c_x', 'condition', 'Charmed'),
    ],
    (eff) {
      expect(eff.damageResistanceIds, contains('d_a'));
      expect(eff.damageImmunityIds, contains('d_b'));
      expect(eff.damageVulnerabilityIds, contains('d_c'));
      expect(eff.conditionImmunityIds, contains('c_x'));
    },
  ),
  _Case(
    'sense_grant with payload range',
    {'sense_grant'},
    [
      {
        'kind': 'sense_grant',
        'target_kind': 'sense',
        'target_ref': 'sense_dark',
        'payload': {'range_ft': 120},
      },
    ],
    [_e('sense_dark', 'sense', 'Darkvision')],
    (eff) {
      expect(eff.senseEntityIds, contains('sense_dark'));
      expect(eff.senseRanges['sense_dark'], 120);
    },
  ),
  _Case(
    'truesight/blindsight resolve by name without a target_ref',
    {'truesight_grant', 'blindsight_grant'},
    [
      {
        'kind': 'truesight_grant',
        'payload': {'range_ft': 60},
      },
      {
        'kind': 'blindsight_grant',
        'payload': {'range_ft': 10},
      },
    ],
    [
      _e('sense_true', 'sense', 'Truesight'),
      _e('sense_blind', 'sense', 'Blindsight'),
    ],
    (eff) {
      expect(eff.senseEntityIds, containsAll(['sense_true', 'sense_blind']));
      expect(eff.senseRanges['sense_true'], 60);
      expect(eff.senseRanges['sense_blind'], 10);
    },
  ),
  _Case(
    'expertise_grant adds the skill to expertise',
    {'expertise_grant'},
    [
      {'kind': 'expertise_grant', 'target_kind': 'skill', 'target_ref': 'sk_st'},
    ],
    [_e('sk_st', 'skill', 'Stealth')],
    (eff) => expect(eff.expertiseSkillIds, contains('sk_st')),
  ),
  _Case(
    'temp_hp_grant surfaces formula and trigger',
    {'temp_hp_grant'},
    [
      {
        'kind': 'temp_hp_grant',
        'payload': {'formula': '2d6', 'trigger': 'on_rage'},
      },
    ],
    [],
    (eff) {
      expect(eff.tempHpGrants, hasLength(1));
      expect(eff.tempHpGrants.first['formula'], '2d6');
      expect(eff.tempHpGrants.first['trigger'], 'on_rage');
    },
  ),
  _Case(
    'granted action/bonus action/reaction grants',
    {
      'granted_action_grant',
      'granted_bonus_action_grant',
      'granted_reaction_grant',
    },
    [
      {'kind': 'granted_action_grant', 'target_kind': 'creature-action', 'target_ref': 'act_a'},
      {'kind': 'granted_bonus_action_grant', 'target_kind': 'creature-action', 'target_ref': 'act_b'},
      {'kind': 'granted_reaction_grant', 'target_kind': 'creature-action', 'target_ref': 'act_c'},
    ],
    [
      _e('act_a', 'creature-action', 'Breath Weapon'),
      _e('act_b', 'creature-action', "Cloud's Jaunt"),
      _e('act_c', 'creature-action', "Stone's Endurance"),
    ],
    (eff) {
      expect(eff.grantedActionIds, contains('act_a'));
      expect(eff.grantedBonusActionIds, contains('act_b'));
      expect(eff.grantedReactionIds, contains('act_c'));
    },
  ),
  _Case(
    'unarmored_ac_formula feeds the AC computation',
    {'unarmored_ac_formula'},
    [
      {
        'kind': 'unarmored_ac_formula',
        'payload': {
          'base': 13,
          'ability_mods': ['DEX'],
        },
      },
    ],
    [],
    (eff) {
      expect(eff.unarmoredFormulas, hasLength(1));
      // base 13 + DEX mod 2 (DEX 14 in the shared base_abilities below).
      expect(eff.armorClass, 15);
    },
  ),
  _Case(
    'extra_attack_count and extra_attack_bump take the max',
    {'extra_attack_count', 'extra_attack_bump'},
    [
      {'kind': 'extra_attack_count', 'value': 2},
      {'kind': 'extra_attack_bump', 'value': 3},
    ],
    [],
    (eff) => expect(eff.extraAttackCount, 3),
  ),
  _Case(
    'crit_range_extend lowers the crit threshold',
    {'crit_range_extend'},
    [
      {
        'kind': 'crit_range_extend',
        'payload': {'threshold': 19},
      },
    ],
    [],
    (eff) => expect(eff.critRangeMin, 19),
  ),
  _Case(
    'resource_pool_grant creates the pool',
    {'resource_pool_grant'},
    [
      {
        'kind': 'resource_pool_grant',
        'payload': {'pool_ref': 'pool_x', 'count': 3, 'recharge': 'long_rest'},
      },
    ],
    [_e('pool_x', 'resource-pool', 'Rage')],
    (eff) {
      final pool = eff.resourcePools
          .firstWhere((p) => p['pool_ref'] == 'pool_x', orElse: () => const {});
      expect(pool['max'], 3);
      expect(pool['recharge'], 'long_rest');
    },
  ),
  _Case(
    'swim/climb equal walk, fly_speed explicit',
    {'swim_speed_equals_speed', 'climb_speed_equals_speed', 'fly_speed'},
    [
      {'kind': 'swim_speed_equals_speed'},
      {'kind': 'climb_speed_equals_speed'},
      {'kind': 'fly_speed', 'value': 60},
    ],
    [],
    (eff) {
      expect(eff.extraSpeeds['swim'], 30);
      expect(eff.extraSpeeds['climb'], 30);
      expect(eff.extraSpeeds['fly'], 60);
    },
  ),
];

void main() {
  group('every sheet-applied rule kind works end-to-end', () {
    for (final c in _cases) {
      test(c.name, () {
        final feat = _e('feat_case', 'feat', 'Case Feat', {
          'effects': c.effects,
        });
        final pc = _pc({
          'feat_ids': ['feat_case'],
          'base_abilities': const {
            'STR': 10, 'DEX': 14, 'CON': 10,
            'INT': 10, 'WIS': 10, 'CHA': 10,
          },
        });
        final eff = CharacterResolver.resolve(pc, {
          feat.id: feat,
          for (final e in c.entities) e.id: e,
        });
        c.verify(eff);
        expect(eff.warnings, isEmpty,
            reason: 'an applied kind must never produce warnings');
      });
    }

    test('the table covers EVERY sheet-applied kind (no untested rule)', () {
      final covered = <String>{for (final c in _cases) ...c.kinds};
      final missing =
          CharacterResolver.sheetAppliedEffectKinds.difference(covered);
      expect(missing, isEmpty,
          reason: 'add an e2e case above for newly applied kinds');
      final stale =
          covered.difference(CharacterResolver.sheetAppliedEffectKinds);
      expect(stale, isEmpty,
          reason: 'table claims kinds the resolver does not apply');
    });
  });
}
