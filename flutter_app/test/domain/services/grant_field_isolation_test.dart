import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// **One field ⇒ one effect.**
///
/// `grant_contract_test.dart` proves the vocabulary is closed and unambiguous.
/// This one proves each word in it does exactly one thing: for every key in
/// [CharacterResolver.grantFieldKeys] a feat card is authored carrying *that
/// key alone*, resolved, and diffed slice-by-slice against the same card with
/// no grants at all. The set of slices that moved has to match the declared
/// set — no more (the field does not leak into a neighbouring stat) and no
/// less (the field is not silently ignored).
///
/// A key whose declared set is empty is a deliberate statement that the field
/// grants nothing on its own; the comment on each says why.

Entity _e(String id, String slug, String name,
        [Map<String, dynamic>? fields]) =>
    Entity(id: id, categorySlug: slug, name: name, fields: fields ?? const {});

/// Reference rows every case can point at.
final _world = <String, Entity>{
  'cls_a': _e('cls_a', 'class', 'Fighter'),
  'sk_x': _e('sk_x', 'skill', 'Arcana'),
  'tool_x': _e('tool_x', 'tool', 'Herbalism Kit'),
  'ab_str': _e('ab_str', 'ability', 'Strength'),
  'ab_dex': _e('ab_dex', 'ability', 'Dexterity'),
  'wcat_x': _e('wcat_x', 'weapon-category', 'Martial'),
  'acat_x': _e('acat_x', 'armor-category', 'Heavy'),
  'lang_x': _e('lang_x', 'language', 'Elvish'),
  'sp_a': _e('sp_a', 'spell', 'Misty Step'),
  'sp_b': _e('sp_b', 'spell', 'Mage Hand'),
  'sp_c': _e('sp_c', 'spell', 'Divine Smite'),
  'sp_d': _e('sp_d', 'spell', 'Faerie Fire'),
  'dt_fire': _e('dt_fire', 'damage-type', 'Fire'),
  'dt_cold': _e('dt_cold', 'damage-type', 'Cold'),
  'dt_acid': _e('dt_acid', 'damage-type', 'Acid'),
  'cond_x': _e('cond_x', 'condition', 'Charmed'),
  'sense_dv': _e('sense_dv', 'sense', 'Darkvision'),
  'act_a': _e('act_a', 'creature-action', 'Breath Weapon'),
  'act_b': _e('act_b', 'creature-action', 'Cunning Action'),
  'act_c': _e('act_c', 'creature-action', "Stone's Endurance"),
  // An empty trait: `trait_refs` must show up as an auto-granted trait
  // without dragging any other stat along with it.
  'trait_x': _e('trait_x', 'trait', 'Keen Senses'),
  'state_raging': _e('state_raging', 'character-state', 'state:raging'),
};

Character _pc(Map<String, dynamic> grants) => const Character(
      id: 'pc1',
      templateId: 'tpl',
      templateName: 'Tpl',
      worldId: 'w',
      createdAt: '0',
      updatedAt: '0',
      entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
        'feat_ids': ['feat_x'],
        'class_levels': {'cls_a': 5},
        'base_abilities': {
          'STR': 12, 'DEX': 14, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 10, //
        },
      }),
    );

EffectiveCharacter _resolve(Map<String, dynamic> grants) =>
    CharacterResolver.resolve(
      _pc(grants),
      {
        ..._world,
        'feat_x': _e('feat_x', 'feat', 'Test Feat', grants),
      },
    );

/// Every observable slice of a resolved sheet, keyed by the name used in the
/// expectations below.
///
/// `grantSources` is deliberately absent: it is a provenance index that moves
/// whenever any ref-shaped grant lands, so including it would say nothing
/// about isolation. `armorClass` *is* included — a field claiming to change AC
/// has to actually change it.
Map<String, Object?> _slices(EffectiveCharacter e) => {
      'skills': e.proficiencies.skillIds,
      'tools': e.proficiencies.toolIds,
      'saves': e.proficiencies.savingThrowAbilityIds,
      'languages': e.proficiencies.languageIds,
      'weaponCategories': e.proficiencies.weaponCategoryIds,
      'armorCategories': e.proficiencies.armorCategoryIds,
      'expertiseSkillIds': e.expertiseSkillIds,
      'grantedSpellIds': e.grantedSpellIds,
      'grantedCantripIds': e.grantedCantripIds,
      'alwaysPreparedSpellIds': e.alwaysPreparedSpellIds,
      'effectiveAbilities': e.effectiveAbilities,
      'acBonus': e.acBonus,
      'armorClass': e.armorClass,
      'speedBonus': e.speedBonus,
      'extraSpeeds': e.extraSpeeds,
      'hpBonusFlat': e.hpBonusFlat,
      'hpBonusPerLevel': e.hpBonusPerLevel,
      'initiativeBonus': e.initiativeBonus,
      'extraAttackCount': e.extraAttackCount,
      'critRangeMin': e.critRangeMin,
      'weaponMasteryCount': e.weaponMasteryCount,
      'unarmoredFormulas': e.unarmoredFormulas,
      'damageResistanceIds': e.damageResistanceIds,
      'damageImmunityIds': e.damageImmunityIds,
      'damageVulnerabilityIds': e.damageVulnerabilityIds,
      'conditionImmunityIds': e.conditionImmunityIds,
      'senseEntityIds': e.senseEntityIds,
      'senseRanges': e.senseRanges,
      'grantedActionIds': e.grantedActionIds,
      'grantedBonusActionIds': e.grantedBonusActionIds,
      'grantedReactionIds': e.grantedReactionIds,
      'autoGrantedTraitIds': e.autoGrantedTraitIds,
      'resourcePools': e.resourcePools,
      'mechanicalNotes': e.mechanicalNotes,
      'conditionalGrants': e.conditionalGrants,
      'warnings': e.warnings,
    };

class _Iso {
  /// The single grant-block key under test and the value authored for it.
  final Map<String, dynamic> field;

  /// Slice names that must differ from the no-grants baseline. Everything
  /// else must be byte-identical.
  final Set<String> moves;

  /// Extra assertions on the resolved value, so the test proves the field is
  /// right and not merely non-empty.
  final void Function(EffectiveCharacter eff)? check;

  const _Iso(this.field, this.moves, [this.check]);
}

final _cases = <String, _Iso>{
  // A gate, not a grant: on its own it has nothing to make conditional.
  'active_while_state_ref': const _Iso({'active_while_state_ref': 'state_raging'}, {}),

  'granted_skill_proficiencies': _Iso(
    {'granted_skill_proficiencies': ['sk_x']},
    {'skills'},
    (e) => expect(e.proficiencies.skillIds, ['sk_x']),
  ),
  'granted_tool_proficiencies': _Iso(
    {'granted_tool_proficiencies': ['tool_x']},
    {'tools'},
    (e) => expect(e.proficiencies.toolIds, ['tool_x']),
  ),
  'granted_save_proficiencies': _Iso(
    {'granted_save_proficiencies': ['ab_str']},
    {'saves'},
    (e) => expect(e.proficiencies.savingThrowAbilityIds, ['ab_str']),
  ),
  'granted_weapon_proficiencies': _Iso(
    {'granted_weapon_proficiencies': ['wcat_x']},
    {'weaponCategories'},
    (e) => expect(e.proficiencies.weaponCategoryIds, ['wcat_x']),
  ),
  'granted_armor_proficiencies': _Iso(
    {'granted_armor_proficiencies': ['acat_x']},
    {'armorCategories'},
    (e) => expect(e.proficiencies.armorCategoryIds, ['acat_x']),
  ),
  'granted_expertise_skills': _Iso(
    {'granted_expertise_skills': ['sk_x']},
    // Expertise is its own list; it must NOT also make you proficient — that
    // is the card author's separate decision.
    {'expertiseSkillIds'},
    (e) => expect(e.expertiseSkillIds, ['sk_x']),
  ),
  'granted_languages': _Iso(
    {'granted_languages': ['lang_x']},
    {'languages'},
    (e) => expect(e.proficiencies.languageIds, ['lang_x']),
  ),
  'granted_spell_refs': _Iso(
    {'granted_spell_refs': ['sp_a']},
    {'grantedSpellIds'},
    (e) => expect(e.grantedSpellIds, ['sp_a']),
  ),
  'granted_cantrip_refs': _Iso(
    {'granted_cantrip_refs': ['sp_b']},
    {'grantedCantripIds'},
    (e) => expect(e.grantedCantripIds, ['sp_b']),
  ),
  'always_prepared_spell_refs': _Iso(
    {'always_prepared_spell_refs': ['sp_c']},
    // Always-prepared is a preparation state, not a new spell known.
    {'alwaysPreparedSpellIds'},
    (e) => expect(e.alwaysPreparedSpellIds, ['sp_c']),
  ),
  'granted_spells_at_level': _Iso(
    {
      'granted_spells_at_level': [
        {'spell_ref': 'sp_d', 'at_level': 3},
        // Above the character's level 5 — must not land.
        {'spell_ref': 'sp_a', 'at_level': 9},
      ],
    },
    {'grantedSpellIds'},
    (e) => expect(e.grantedSpellIds, ['sp_d']),
  ),

  'ability_bonuses': _Iso(
    {'ability_bonuses': {'STR': 2}},
    // STR only — a DEX bump would legitimately move armorClass too, which
    // would blur what this case is proving.
    {'effectiveAbilities'},
    (e) => expect(e.effectiveAbilities['STR'], 14),
  ),
  // A ceiling with nothing pushing against it.
  'ability_bonus_cap': const _Iso({'ability_bonus_cap': 24}, {}),
  'ac_bonus': _Iso(
    {'ac_bonus': 2},
    {'acBonus', 'armorClass'},
    (e) => expect(e.armorClass, 14), // 10 + DEX 2 + 2
  ),
  'speed_bonus_ft': _Iso(
    {'speed_bonus_ft': 5},
    {'speedBonus'},
    (e) => expect(e.speedBonus, 5),
  ),
  'initiative_bonus': _Iso(
    {'initiative_bonus': 3},
    {'initiativeBonus'},
    (e) => expect(e.initiativeBonus, 3),
  ),
  'hp_bonus_flat': _Iso(
    {'hp_bonus_flat': 4},
    {'hpBonusFlat'},
    (e) => expect(e.hpBonusFlat, 4),
  ),
  'hp_bonus_per_level': _Iso(
    {'hp_bonus_per_level': 1},
    {'hpBonusPerLevel'},
    (e) => expect(e.hpBonusPerLevel, 1),
  ),
  'extra_attack_count': _Iso(
    {'extra_attack_count': 2},
    {'extraAttackCount'},
    (e) => expect(e.extraAttackCount, 2),
  ),
  'extra_attack_count_by_level': _Iso(
    // Character is level 5: the row at 5 applies, the row at 11 does not.
    {'extra_attack_count_by_level': {'5': 2, '11': 3}},
    {'extraAttackCount'},
    (e) => expect(e.extraAttackCount, 2),
  ),
  'crit_threshold': _Iso(
    {'crit_threshold': 19},
    {'critRangeMin'},
    (e) => expect(e.critRangeMin, 19),
  ),
  'weapon_mastery_count': _Iso(
    {'weapon_mastery_count': 3},
    {'weaponMasteryCount'},
    (e) => expect(e.weaponMasteryCount, 3),
  ),

  'unarmored_ac_base': _Iso(
    {'unarmored_ac_base': 13},
    {'unarmoredFormulas', 'armorClass'},
    // Base alone, with no `unarmored_ac_abilities`, is a flat 13 — it does not
    // silently keep the DEX term the default 10 + DEX formula had.
    (e) => expect(e.armorClass, 13),
  ),
  // The two modifiers below describe a formula; with no base there is no
  // formula to modify, so on their own they are correctly inert.
  'unarmored_ac_abilities': const _Iso({'unarmored_ac_abilities': ['ab_dex']}, {}),
  'unarmored_ac_shield_allowed':
      const _Iso({'unarmored_ac_shield_allowed': true}, {}),

  'granted_damage_resistances': _Iso(
    {'granted_damage_resistances': ['dt_fire']},
    {'damageResistanceIds'},
    (e) => expect(e.damageResistanceIds, ['dt_fire']),
  ),
  'granted_damage_immunities': _Iso(
    {'granted_damage_immunities': ['dt_cold']},
    {'damageImmunityIds'},
    (e) => expect(e.damageImmunityIds, ['dt_cold']),
  ),
  'granted_damage_vulnerabilities': _Iso(
    {'granted_damage_vulnerabilities': ['dt_acid']},
    {'damageVulnerabilityIds'},
    (e) => expect(e.damageVulnerabilityIds, ['dt_acid']),
  ),
  'granted_condition_immunities': _Iso(
    {'granted_condition_immunities': ['cond_x']},
    {'conditionImmunityIds'},
    (e) => expect(e.conditionImmunityIds, ['cond_x']),
  ),
  'granted_senses': _Iso(
    {
      'granted_senses': [
        {'sense_ref': 'sense_dv', 'range_ft': 60},
      ],
    },
    {'senseEntityIds', 'senseRanges'},
    (e) => expect(e.senseRanges['sense_dv'], 60),
  ),

  'speed_fly_ft': _Iso(
    {'speed_fly_ft': 40},
    {'extraSpeeds'},
    (e) => expect(e.extraSpeeds, {'fly': 40}),
  ),
  'speed_swim_ft': _Iso(
    {'speed_swim_ft': 30},
    {'extraSpeeds'},
    (e) => expect(e.extraSpeeds, {'swim': 30}),
  ),
  'speed_climb_ft': _Iso(
    // The "equal to walking speed" sentinel resolves against the base 30.
    {'speed_climb_ft': -1},
    {'extraSpeeds'},
    (e) => expect(e.extraSpeeds, {'climb': 30}),
  ),
  'speed_burrow_ft': _Iso(
    {'speed_burrow_ft': 20},
    {'extraSpeeds'},
    (e) => expect(e.extraSpeeds, {'burrow': 20}),
  ),

  'granted_action_refs': _Iso(
    {'granted_action_refs': ['act_a']},
    {'grantedActionIds'},
    (e) => expect(e.grantedActionIds, ['act_a']),
  ),
  'granted_bonus_action_refs': _Iso(
    {'granted_bonus_action_refs': ['act_b']},
    {'grantedBonusActionIds'},
    (e) => expect(e.grantedBonusActionIds, ['act_b']),
  ),
  'granted_reaction_refs': _Iso(
    {'granted_reaction_refs': ['act_c']},
    {'grantedReactionIds'},
    (e) => expect(e.grantedReactionIds, ['act_c']),
  ),
  'trait_refs': _Iso(
    {'trait_refs': ['trait_x']},
    {'autoGrantedTraitIds'},
    (e) => expect(e.autoGrantedTraitIds, ['trait_x']),
  ),

  'resource_pool_grants': _Iso(
    {
      'resource_pool_grants': [
        {
          'pool_ref': {'name': 'pool:rage_uses'},
          'recharge': 'long_rest',
          'count': 2,
        },
      ],
    },
    {'resourcePools'},
    (e) => expect(e.resourcePools.single['max'], 2),
  ),
  // Chargen plumbing: `pending_choices.dart` reads these rows off the card,
  // so a resolved sheet is expected to be untouched by them.
  'player_choices': const _Iso(
    {
      'player_choices': [
        {'group_id': 'g1', 'label': 'Pick a skill', 'pick_kind': 'skill', 'pick': 1},
      ],
    },
    {},
  ),

  'mechanical_notes': _Iso(
    {'mechanical_notes': 'Advantage on Strength checks'},
    {'mechanicalNotes'},
    (e) => expect(e.mechanicalNotes, ['Advantage on Strength checks']),
  ),
};

void main() {
  final baseline = _slices(_resolve(const {}));

  group('grant field isolation (one field ⇒ one effect)', () {
    test('the case table covers the whole contract, exactly', () {
      expect(_cases.keys.toSet(), CharacterResolver.grantFieldKeys,
          reason: 'add an isolation case when adding or removing a grant field');
    });

    _cases.forEach((key, c) {
      test('$key moves ${c.moves.isEmpty ? "nothing" : c.moves.join(" + ")}',
          () {
        expect(c.field.keys, [key],
            reason: 'an isolation case must author exactly its own key');

        final eff = _resolve(c.field);
        final after = _slices(eff);
        final moved = <String>{
          for (final slice in baseline.keys)
            if (after[slice].toString() != baseline[slice].toString()) slice,
        };

        expect(moved, c.moves,
            reason: moved.difference(c.moves).isNotEmpty
                ? '$key leaked into ${moved.difference(c.moves)}'
                : '$key failed to move ${c.moves.difference(moved)}');
        expect(eff.warnings, isEmpty, reason: 'a valid grant must not warn');
        c.check?.call(eff);
      });
    });

    test('the baseline card really is inert', () {
      // Guards the whole file: if an empty feat already moved something, every
      // diff above would be measured against the wrong zero.
      expect(baseline['warnings'], isEmpty);
      expect(baseline['acBonus'], 0);
      expect(baseline['mechanicalNotes'], isEmpty);
      expect(baseline['resourcePools'], isEmpty);
      expect(baseline['extraSpeeds'], isEmpty);
    });
  });

  group('no second path into the sheet', () {
    // The point of the removal: the old row languages must be inert now, not
    // merely unused by shipped content. A world that still carries them (or a
    // pack imported before the converter ran) must resolve to nothing rather
    // than to a stale, half-understood mechanic.
    for (final legacy in const [
      {
        'rule_effects': [
          {'kind': 'proficiency_grant', 'target_kind': 'skill', 'target_ref': 'sk_x'},
          {'kind': 'ac_bonus', 'value': 5},
        ],
      },
      {
        'granted_modifiers': [
          {'kind': 'hp_bonus_per_level', 'value': 3},
          {'kind': 'damage_resistance', 'target_ref': 'dt_fire'},
        ],
      },
      {
        'effects': [
          {'kind': 'speed_bonus', 'value': 10},
        ],
      },
    ]) {
      test('a legacy ${legacy.keys.single} row changes nothing', () {
        final after = _slices(_resolve(Map<String, dynamic>.from(legacy)));
        expect(after, baseline);
      });
    }

    test('an unknown grant key is ignored without warning', () {
      final after = _slices(_resolve(const {
        'granted_luck_points': 3,
        'ac_bonus_typo': 2,
      }));
      expect(after, baseline);
    });
  });
}
