// SRD 5.2.1 Class Features — authored as auto-granted feats.
//
// Each entry is a feat with:
//   • prose `description` / `benefits` — preserved verbatim from SRD class
//     prose for read-mode preview;
//   • structured `effects` consumed by CharacterResolver;
//   • `auto_granted_by` listing the class + level that grants it;
//   • `chooseable: false` so the feat is hidden from the player feat-picker.
//
// Resolver auto-grant walker (CharacterResolver Pass 4b) picks up every feat
// whose `auto_granted_by` matches the character's class levels / species /
// background and applies its effects exactly like a player-chosen feat.
//
// Narrative-only class features (Druidic, Thieves' Cant) live in
// `traits.dart` as Traits with `auto_granted_by` populated; the resolver
// skips them and the UI only shows the prose.

import '_helpers.dart';

/// Class-feature feat builder. Wraps `packEntity` with sensible defaults.
Map<String, dynamic> _cf({
  required String name,
  required String className,
  required int atLevel,
  required String description,
  String? benefits,
  List<Map<String, dynamic>> effects = const [],
  Map<String, dynamic>? activation,
  bool repeatable = false,
}) =>
    packEntity(
      slug: 'feat',
      name: name,
      description: description,
      attributes: {
        'category_ref': lookup('feat-category', 'Class Feature'),
        'chooseable': false,
        'auto_granted_by': [
          autoGrantBy(source: 'class', sourceName: className, atLevel: atLevel),
        ],
        'repeatable': repeatable,
        'effects': effects,
        'activation': ?activation,
        'benefits': benefits ?? description,
      },
    );

/// Subclass-feature feat builder.
Map<String, dynamic> _sf({
  required String name,
  required String subclassName,
  required int atLevel,
  required String description,
  String? benefits,
  List<Map<String, dynamic>> effects = const [],
  Map<String, dynamic>? activation,
}) =>
    packEntity(
      slug: 'feat',
      name: name,
      description: description,
      attributes: {
        'category_ref': lookup('feat-category', 'Subclass Feature'),
        'chooseable': false,
        'auto_granted_by': [
          autoGrantBy(
            source: 'subclass',
            sourceName: subclassName,
            atLevel: atLevel,
          ),
        ],
        'repeatable': false,
        'effects': effects,
        'activation': ?activation,
        'benefits': benefits ?? description,
      },
    );

/// Common shared damage type lookups — used as `target_ref` in resistance/
/// damage effects.
Map<String, String> _dt(String name) => lookup('damage-type', name);
Map<String, String> _ability(String name) => lookup('ability', name);
Map<String, String> _skill(String name) => lookup('skill', name);
Map<String, String> _state(String name) => lookup('character-state', name);
Map<String, String> _pool(String name) => lookup('resource-pool', name);
Map<String, String> _cond(String name) => lookup('condition', name);
Map<String, String> _sense(String name) => lookup('sense', name);

List<Map<String, dynamic>> srdClassFeats() => [
      // ─── BARBARIAN ───────────────────────────────────────────────────────
      _cf(
        name: 'Rage',
        className: 'Barbarian',
        atLevel: 1,
        description:
            'You can imbue yourself with primal power as a Bonus Action while not in Heavy armor.',
        benefits:
            '**Bonus Action.** Activate Rage as a Bonus Action; you must not be wearing Heavy armor.\n\n'
            '**Damage Resistance.** While raging you have Resistance to Bludgeoning, Piercing, and Slashing damage.\n\n'
            '**Strength Advantage.** Advantage on Strength checks and Strength saving throws while raging.\n\n'
            '**Rage Damage.** When you make a Strength-based melee weapon attack, gain a damage bonus that scales with your Barbarian level (+2 at L1, +3 at L9, +4 at L16).\n\n'
            '**No Spells.** While raging you can\'t cast spells or maintain Concentration.\n\n'
            '**Duration.** Lasts up to 10 minutes; ends if you don\'t attack or take damage on your turn, you fall Unconscious, or you don Heavy armor.\n\n'
            '**Uses.** Per Long Rest: 2 (L1), 3 (L3), 4 (L6), 5 (L12), 6 (L17), unlimited (L20).',
        activation: activation(
          actionType: 'bonus_action',
          duration: {'kind': 'minutes', 'value': 10},
          uses: {
            'pool_ref': _pool('pool:rage_uses'),
            'recharge': 'long_rest',
          },
          triggersStateRef: 'state:raging',
          endConditions: const [
            'no_attack_or_damage_taken_last_turn',
            'incapacitated',
            'heavy_armor_donned',
            'manual',
          ],
        ),
        effects: [
          effect('damage_resistance',
              targetRef: _dt('Bludgeoning'),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('damage_resistance',
              targetRef: _dt('Piercing'),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('damage_resistance',
              targetRef: _dt('Slashing'),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('advantage_on',
              targetKind: 'check',
              targetRef: _ability('Strength'),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('advantage_on',
              targetKind: 'save',
              targetRef: _ability('Strength'),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('extra_damage_on_attack',
              payload: {
                'flat': 2,
                'when': 'str_melee',
                'type_ref': _dt('Bludgeoning'),
              },
              scalesWith: scalesByClass('Barbarian', [
                [1, 2], [9, 3], [16, 4],
              ]),
              predicates: [predicate('has_state', {'ref': 'state:raging'})]),
          effect('resource_pool_grant',
              payload: {'pool_ref': _pool('pool:rage_uses'), 'recharge': 'long_rest'},
              scalesWith: scalesByClass('Barbarian', [
                [1, 2], [3, 3], [6, 4], [12, 5], [17, 6], [20, 99],
              ])),
        ],
      ),
      _cf(
        name: 'Unarmored Defense (Barbarian)',
        className: 'Barbarian',
        atLevel: 1,
        description:
            'While not wearing armor, your AC equals 10 + Dex mod + Con mod. Shield allowed.',
        effects: [
          effect('unarmored_ac_formula',
              payload: {
                'base': 10,
                'ability_mods': ['DEX', 'CON'],
                'shield_allowed': true,
              },
              predicates: [predicate('equipped_armor_kind', {'value': 'none'})]),
        ],
      ),
      _cf(
        name: 'Weapon Mastery (Barbarian)',
        className: 'Barbarian',
        atLevel: 1,
        description:
            'You can use the mastery property of two kinds of Simple or Martial Melee weapons; swap one on each Long Rest.',
        effects: [
          effect('weapon_mastery_count_bonus', value: 2),
        ],
      ),
      _cf(
        name: 'Danger Sense',
        className: 'Barbarian',
        atLevel: 2,
        description:
            'You have Advantage on Dexterity saving throws unless you have the Incapacitated condition.',
        effects: [
          effect('advantage_on',
              targetKind: 'save',
              targetRef: _ability('Dexterity'),
              predicates: [predicate('not_incapacitated')]),
        ],
      ),
      _cf(
        name: 'Reckless Attack',
        className: 'Barbarian',
        atLevel: 2,
        description:
            'On your turn you can attack recklessly: gain Advantage on Strength-based melee attack rolls until your next turn, but attack rolls against you also have Advantage.',
        activation: activation(
          actionType: 'no_action',
          duration: {'kind': 'until_end_of_next_turn'},
          triggersStateRef: 'state:reckless_attacking',
        ),
        effects: [
          effect('advantage_on',
              targetKind: 'attack',
              targetRef: _ability('Strength'),
              predicates: [predicate('has_state', {'ref': 'state:reckless_attacking'})]),
        ],
      ),
      _cf(
        name: 'Primal Knowledge',
        className: 'Barbarian',
        atLevel: 3,
        description:
            'You gain proficiency in another skill of your choice from the Barbarian list. While raging you can substitute Strength for the ability score normally used to make checks with that skill.',
        effects: [
          effect('proficiency_grant', targetKind: 'skill'),
        ],
      ),
      _cf(
        name: 'Extra Attack (Barbarian)',
        className: 'Barbarian',
        atLevel: 5,
        description: 'You can attack twice when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 2)],
      ),
      _cf(
        name: 'Fast Movement',
        className: 'Barbarian',
        atLevel: 5,
        description:
            'Your Speed increases by 10 feet while you aren\'t wearing Heavy armor.',
        effects: [
          effect('speed_bonus',
              value: 10,
              predicates: [predicate('equipped_armor_kind', {'value': 'not_heavy'})]),
        ],
      ),
      _cf(
        name: 'Feral Instinct',
        className: 'Barbarian',
        atLevel: 7,
        description: 'You have Advantage on Initiative rolls.',
        effects: [
          effect('advantage_on', targetKind: 'check', targetRef: _ability('Dexterity')),
          effect('initiative_bonus', value: 0),
        ],
      ),
      _cf(
        name: 'Instinctive Pounce',
        className: 'Barbarian',
        atLevel: 7,
        description:
            'As part of the Bonus Action you take to enter your Rage, you can move up to half your Speed.',
      ),
      _cf(
        name: 'Brutal Strike',
        className: 'Barbarian',
        atLevel: 9,
        description:
            'When you Reckless Attack, you can forgo Advantage to deal +1d10 damage and apply one Brutal Strike effect (Forceful Blow / Hamstring Blow).',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'dice': '1d10',
                'when': 'str_melee',
                'requires_forgo_advantage': true,
              },
              predicates: [predicate('has_state', {'ref': 'state:reckless_attacking'})]),
        ],
      ),
      _cf(
        name: 'Relentless Rage',
        className: 'Barbarian',
        atLevel: 11,
        description:
            'When you would drop to 0 HP while raging and aren\'t killed outright, you can make a Constitution save (DC 10, +5 per use this rest); on success you drop to 1 HP instead.',
      ),
      _cf(
        name: 'Improved Brutal Strike',
        className: 'Barbarian',
        atLevel: 13,
        description:
            'Add Staggering Blow and Sundering Blow to the list of Brutal Strike effects.',
      ),
      _cf(
        name: 'Persistent Rage',
        className: 'Barbarian',
        atLevel: 15,
        description:
            'Your Rage lasts 10 minutes without needing to attack or take damage to extend it. When you roll Initiative, regain all expended Rage uses (1/Long Rest).',
      ),
      _cf(
        name: 'Improved Brutal Strike (II)',
        className: 'Barbarian',
        atLevel: 17,
        description:
            'Brutal Strike\'s damage die increases to 2d10, and you can apply two Brutal Strike effects per use.',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'dice': '2d10',
                'when': 'str_melee',
                'requires_forgo_advantage': true,
              },
              predicates: [predicate('has_state', {'ref': 'state:reckless_attacking'})]),
        ],
      ),
      _cf(
        name: 'Indomitable Might',
        className: 'Barbarian',
        atLevel: 18,
        description:
            'When you make a Strength check or Strength save, treat any roll lower than your Strength score as if it were equal to your Strength score.',
      ),
      _cf(
        name: 'Primal Champion',
        className: 'Barbarian',
        atLevel: 20,
        description:
            'Your Strength and Constitution increase by 4. Your maximum for those scores becomes 25.',
      ),

      // ─── BARD ────────────────────────────────────────────────────────────
      _cf(
        name: 'Bardic Inspiration',
        className: 'Bard',
        atLevel: 1,
        description:
            'As a Bonus Action, you can grant a creature within 60 feet (other than yourself) a Bardic Inspiration die — initially d6, increasing with level. Within 10 minutes the recipient adds it to one ability check, attack roll, or saving throw.',
        activation: activation(
          actionType: 'bonus_action',
          duration: {'kind': 'minutes', 'value': 10},
          uses: {
            'pool_ref': _pool('pool:bardic_inspiration'),
            'recharge': 'long_rest',
          },
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:bardic_inspiration'),
                'recharge': 'long_rest',
                'count_formula': 'cha_mod_min_1',
              }),
        ],
      ),
      _cf(
        name: 'Bard Spellcasting',
        className: 'Bard',
        atLevel: 1,
        description:
            'You know cantrips and spells from the Bard spell list. Charisma is your spellcasting ability. You can use a Musical Instrument or Bard Spellcasting Focus.',
      ),
      _cf(
        name: 'Expertise (Bard)',
        className: 'Bard',
        atLevel: 2,
        description:
            'Choose two skills with which you have Proficiency. Your Proficiency Bonus is doubled for any check you make with those skills.',
        effects: [
          effect('expertise_count', value: 2),
        ],
      ),
      _cf(
        name: 'Jack of All Trades',
        className: 'Bard',
        atLevel: 2,
        description:
            'You can add half your Proficiency Bonus (rounded down) to any ability check you make that uses a skill in which you lack Proficiency.',
        effects: [effect('half_proficiency_to_unproficient_checks')],
      ),
      _cf(
        name: 'Font of Inspiration',
        className: 'Bard',
        atLevel: 5,
        description:
            'Your Bardic Inspiration die is now a d8. You also regain expended uses on a Short Rest.',
      ),
      _cf(
        name: 'Countercharm',
        className: 'Bard',
        atLevel: 7,
        description:
            'When you or a creature within 30 feet that you can see fails a save vs. being Charmed or Frightened, you can use a Reaction to allow the save to be rerolled with Advantage.',
      ),
      _cf(
        name: 'Expertise (Bard II)',
        className: 'Bard',
        atLevel: 9,
        description: 'Two more proficient skills gain Expertise.',
        effects: [effect('expertise_count', value: 2)],
      ),
      _cf(
        name: 'Magical Secrets',
        className: 'Bard',
        atLevel: 10,
        description:
            'When you reach this level and at later milestones, replace one Bard spell you know with any spell of the same level from any class\'s spell list.',
      ),
      _cf(
        name: 'Bardic Inspiration (d10)',
        className: 'Bard',
        atLevel: 13,
        description: 'Your Bardic Inspiration die is now a d10.',
      ),
      _cf(
        name: 'Words of Creation',
        className: 'Bard',
        atLevel: 15,
        description:
            'You always have Power Word Heal and Power Word Kill prepared, and they can target two creatures rather than one.',
      ),
      _cf(
        name: 'Bardic Inspiration (d12)',
        className: 'Bard',
        atLevel: 17,
        description: 'Your Bardic Inspiration die is now a d12.',
      ),
      _cf(
        name: 'Superior Bardic Inspiration',
        className: 'Bard',
        atLevel: 20,
        description:
            'When you roll Initiative, you regain 2 expended Bardic Inspiration uses.',
      ),

      // ─── CLERIC ──────────────────────────────────────────────────────────
      _cf(
        name: 'Cleric Spellcasting',
        className: 'Cleric',
        atLevel: 1,
        description:
            'You know cantrips and prepare spells from the Cleric spell list. Wisdom is your spellcasting ability; you can use a Holy Symbol as a spellcasting focus.',
      ),
      _cf(
        name: 'Channel Divinity',
        className: 'Cleric',
        atLevel: 2,
        description:
            'You gain Divine Spark and Turn Undead as Channel Divinity options. You have 2 uses, regained on a Short or Long Rest.',
        activation: activation(
          actionType: 'action',
          uses: {
            'pool_ref': _pool('pool:channel_divinity'),
            'recharge': 'short_rest',
          },
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:channel_divinity'),
                'recharge': 'short_rest',
                'count': 2,
              }),
        ],
      ),
      _cf(
        name: 'Sear Undead',
        className: 'Cleric',
        atLevel: 5,
        description:
            'When you take the Magic action to use Turn Undead, you can deal Radiant damage to each affected Undead equal to your Cleric level (no save).',
      ),
      _cf(
        name: 'Blessed Strikes',
        className: 'Cleric',
        atLevel: 7,
        description:
            'Once on each of your turns, when you hit with a weapon attack or a cantrip you can deal an extra 1d8 Radiant damage to the target.',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'dice': '1d8',
                'when': 'first_hit_per_turn',
                'type_ref': _dt('Radiant'),
              }),
        ],
      ),
      _cf(
        name: 'Divine Intervention',
        className: 'Cleric',
        atLevel: 10,
        description:
            'As a Magic action, choose any Cleric spell of level 5 or lower; you cast it without expending a spell slot. 1/Long Rest.',
      ),
      _cf(
        name: 'Improved Blessed Strikes',
        className: 'Cleric',
        atLevel: 14,
        description: 'The Blessed Strikes damage increases to 2d8.',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'dice': '2d8',
                'when': 'first_hit_per_turn',
                'type_ref': _dt('Radiant'),
              }),
        ],
      ),
      _cf(
        name: 'Greater Divine Intervention',
        className: 'Cleric',
        atLevel: 20,
        description:
            'Divine Intervention can now grant any Cleric spell of any level without expending a slot.',
      ),

      // ─── DRUID ───────────────────────────────────────────────────────────
      _cf(
        name: 'Druid Spellcasting',
        className: 'Druid',
        atLevel: 1,
        description:
            'You know cantrips and prepare spells from the Druid spell list. Wisdom is your spellcasting ability; you can use a Druidic Focus.',
      ),
      _cf(
        name: 'Wild Shape',
        className: 'Druid',
        atLevel: 2,
        description:
            'As a Bonus Action you assume the form of a Beast you have seen (CR ≤ 1/4, no flying speed). Lasts a number of hours equal to half your Druid level. 2 uses per Short or Long Rest, scaling with level.',
        activation: activation(
          actionType: 'bonus_action',
          duration: {'kind': 'hours'},
          uses: {
            'pool_ref': _pool('pool:wild_shape'),
            'recharge': 'short_rest',
          },
          triggersStateRef: 'state:wild_shape_active',
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:wild_shape'),
                'recharge': 'short_rest',
                'count': 2,
              }),
        ],
      ),
      _cf(
        name: 'Wild Companion',
        className: 'Druid',
        atLevel: 2,
        description:
            'You can expend one use of Wild Shape to cast Find Familiar without a spell slot; the familiar lasts until you take a Long Rest.',
      ),
      _cf(
        name: 'Wild Resurgence',
        className: 'Druid',
        atLevel: 5,
        description:
            'Once per turn (no action) you can convert 2 unspent Wild Shape uses into one expended level-1 spell slot (or the reverse).',
      ),
      _cf(
        name: 'Improved Elemental Fury',
        className: 'Druid',
        atLevel: 15,
        description: 'Your Elemental Fury option scales (Potent Spellcasting → 2× Wis to cantrip damage; Primal Strike → +1d8 elemental damage).',
      ),
      _cf(
        name: 'Beast Spells',
        className: 'Druid',
        atLevel: 18,
        description:
            'While in a Wild Shape form you can cast your prepared Druid spells (Verbal and Somatic only).',
      ),
      _cf(
        name: 'Archdruid',
        className: 'Druid',
        atLevel: 20,
        description:
            'You can Wild Shape any number of times. While in Wild Shape you ignore Verbal, Somatic, and Material spell components, and you age 1 year per 10 elapsed.',
      ),

      // ─── FIGHTER ─────────────────────────────────────────────────────────
      _cf(
        name: 'Second Wind',
        className: 'Fighter',
        atLevel: 1,
        description:
            'On your turn, as a Bonus Action, you regain HP equal to 1d10 + your Fighter level. Uses scale: 2 (L1), 3 (L4), 4 (L10). Recharges on Short or Long Rest.',
        activation: activation(
          actionType: 'bonus_action',
          uses: {
            'pool_ref': _pool('pool:second_wind'),
            'recharge': 'short_rest',
          },
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:second_wind'),
                'recharge': 'short_rest',
              },
              scalesWith: scalesByClass('Fighter', [
                [1, 2], [4, 3], [10, 4],
              ])),
        ],
      ),
      _cf(
        name: 'Weapon Mastery (Fighter)',
        className: 'Fighter',
        atLevel: 1,
        description:
            'You can use the mastery property of three kinds of weapons. You can swap one on each Long Rest. Additional masteries unlock at higher levels.',
        effects: [effect('weapon_mastery_count_bonus', value: 3)],
      ),
      _cf(
        name: 'Action Surge',
        className: 'Fighter',
        atLevel: 2,
        description:
            'On your turn (no action) you can take one additional Attack action or Magic action. 1/Short Rest, 2/Short Rest at level 17.',
        activation: activation(
          actionType: 'free',
          uses: {
            'pool_ref': _pool('pool:action_surge'),
            'recharge': 'short_rest',
          },
          triggersStateRef: 'state:action_surge_used',
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:action_surge'),
                'recharge': 'short_rest',
              },
              scalesWith: scalesByClass('Fighter', [
                [1, 1], [17, 2],
              ])),
        ],
      ),
      _cf(
        name: 'Tactical Mind',
        className: 'Fighter',
        atLevel: 2,
        description:
            'When you fail an ability check, you can spend one Second Wind use (no HP gain) to roll 1d10 and add it to the check. If it still fails, the use isn\'t consumed.',
      ),
      _cf(
        name: 'Extra Attack (Fighter)',
        className: 'Fighter',
        atLevel: 5,
        description:
            'You can attack twice when you take the Attack action. Three times at L11; four times at L20.',
        effects: [effect('extra_attack_count', value: 2)],
      ),
      _cf(
        name: 'Tactical Shift',
        className: 'Fighter',
        atLevel: 9,
        description:
            'When you Second Wind you can move up to half your Speed without provoking Opportunity Attacks.',
      ),
      _cf(
        name: 'Two Extra Attacks',
        className: 'Fighter',
        atLevel: 11,
        description: 'You can attack three times when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 3)],
      ),
      _cf(
        name: 'Studied Attacks',
        className: 'Fighter',
        atLevel: 13,
        description:
            'When you miss a creature with an attack roll, you have Advantage on your next attack roll against it before the end of your next turn.',
      ),
      _cf(
        name: 'Three Extra Attacks',
        className: 'Fighter',
        atLevel: 20,
        description: 'You can attack four times when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 4)],
      ),

      // ─── MONK ────────────────────────────────────────────────────────────
      _cf(
        name: 'Martial Arts',
        className: 'Monk',
        atLevel: 1,
        description:
            'While you aren\'t wearing armor or wielding a Shield: use Dexterity instead of Strength for unarmed and Monk-weapon attack and damage rolls; Martial Arts die replaces the weapon\'s damage die (1d6 at L1, scales); after the Attack action, you can make one Unarmed Strike as a Bonus Action.',
      ),
      _cf(
        name: 'Unarmored Defense (Monk)',
        className: 'Monk',
        atLevel: 1,
        description:
            'While not wearing armor and not wielding a Shield, your AC equals 10 + Dex mod + Wis mod.',
        effects: [
          effect('unarmored_ac_formula',
              payload: {
                'base': 10,
                'ability_mods': ['DEX', 'WIS'],
                'shield_allowed': false,
              },
              predicates: [
                predicate('equipped_armor_kind', {'value': 'none'}),
                predicate('equipped_shield', {'value': 'false'}),
              ]),
        ],
      ),
      _cf(
        name: "Monk's Focus",
        className: 'Monk',
        atLevel: 2,
        description:
            'You gain Focus Points equal to your Monk level. You can spend them on Flurry of Blows, Patient Defense, or Step of the Wind. Regained on a Short or Long Rest.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:focus_points'),
                'recharge': 'short_rest',
                'count_formula': 'monk_level',
              }),
        ],
      ),
      _cf(
        name: 'Unarmored Movement',
        className: 'Monk',
        atLevel: 2,
        description:
            'Your Speed increases by 10 feet while you aren\'t wearing armor or wielding a Shield. Increases at higher levels.',
        effects: [
          effect('speed_bonus',
              value: 10,
              predicates: [
                predicate('equipped_armor_kind', {'value': 'none'}),
                predicate('equipped_shield', {'value': 'false'}),
              ],
              scalesWith: scalesByClass('Monk', [
                [2, 10], [6, 15], [10, 20], [14, 25], [18, 30],
              ])),
        ],
      ),
      _cf(
        name: 'Flurry of Blows',
        className: 'Monk',
        atLevel: 2,
        description:
            'Spend 1 Focus Point to make two Unarmed Strikes as a Bonus Action.',
      ),
      _cf(
        name: 'Patient Defense',
        className: 'Monk',
        atLevel: 2,
        description:
            'You can take the Disengage action as a Bonus Action. You can spend 1 Focus Point to also take the Dodge action as a Bonus Action.',
      ),
      _cf(
        name: 'Step of the Wind',
        className: 'Monk',
        atLevel: 2,
        description:
            'You can take the Dash action as a Bonus Action. You can spend 1 Focus Point to also jump twice as far on that turn and not provoke Opportunity Attacks.',
      ),
      _cf(
        name: 'Deflect Attacks',
        className: 'Monk',
        atLevel: 3,
        description:
            'When an attack reduces you below max HP and you can see the attacker, use your Reaction to reduce the damage by 1d10 + your Dex modifier + your Monk level. If the attack is a ranged weapon attack and you reduce the damage to 0, you can redirect it.',
      ),
      _cf(
        name: 'Slow Fall',
        className: 'Monk',
        atLevel: 4,
        description:
            'When you would take falling damage you can use your Reaction to reduce the damage by 5 × your Monk level.',
      ),
      _cf(
        name: 'Stunning Strike',
        className: 'Monk',
        atLevel: 5,
        description:
            'When you hit a creature with a Monk weapon or Unarmed Strike, you can spend 1 Focus Point to force a Constitution save (DC 8 + your PB + Wis mod) or be Stunned until the end of your next turn.',
      ),
      _cf(
        name: 'Extra Attack (Monk)',
        className: 'Monk',
        atLevel: 5,
        description: 'You can attack twice when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 2)],
      ),
      _cf(
        name: 'Empowered Strikes',
        className: 'Monk',
        atLevel: 6,
        description:
            'Your Unarmed Strikes count as magical for the purpose of overcoming resistance and immunity. You can change the damage type to Force.',
        effects: [effect('magical_unarmed_strikes')],
      ),
      _cf(
        name: 'Evasion (Monk)',
        className: 'Monk',
        atLevel: 7,
        description:
            'When subjected to an effect that allows a Dexterity save for half damage, you instead take no damage on a success and half damage on a failure.',
      ),
      _cf(
        name: 'Acrobatic Movement',
        className: 'Monk',
        atLevel: 9,
        description:
            'While you aren\'t wearing armor or wielding a Shield, you can move along vertical surfaces and across liquids on your turn without falling, provided you move 10+ feet.',
        effects: [
          effect('walk_on_liquid',
              predicates: [
                predicate('equipped_armor_kind', {'value': 'none'}),
                predicate('equipped_shield', {'value': 'false'}),
              ]),
        ],
      ),
      _cf(
        name: 'Deflect Energy',
        className: 'Monk',
        atLevel: 13,
        description:
            'You can use Deflect Attacks against attacks that deal Acid, Cold, Fire, Lightning, or Thunder damage.',
      ),
      _cf(
        name: 'Perfect Focus',
        className: 'Monk',
        atLevel: 15,
        description:
            'When you roll Initiative with fewer than 4 Focus Points, regain expended Focus Points until you have 4.',
      ),
      _cf(
        name: 'Superior Defense',
        className: 'Monk',
        atLevel: 18,
        description:
            'As a Bonus Action you can spend 3 Focus Points to gain Resistance to all damage except Force for 1 minute or until you have the Incapacitated condition.',
      ),
      _cf(
        name: 'Body and Mind',
        className: 'Monk',
        atLevel: 20,
        description:
            'Your Dexterity and Wisdom scores increase by 4. Your maximum for those scores becomes 25.',
      ),

      // ─── PALADIN ─────────────────────────────────────────────────────────
      _cf(
        name: 'Lay On Hands',
        className: 'Paladin',
        atLevel: 1,
        description:
            'You have a pool of healing power equal to your Paladin level × 5. As a Bonus Action you can touch a creature and restore HP from the pool, or spend 5 points to neutralize one disease or poison. The pool refreshes on a Long Rest.',
        activation: activation(
          actionType: 'bonus_action',
          uses: {
            'pool_ref': _pool('pool:lay_on_hands_hp'),
            'recharge': 'long_rest',
          },
        ),
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:lay_on_hands_hp'),
                'recharge': 'long_rest',
                'count_formula': 'paladin_level_x5',
              }),
        ],
      ),
      _cf(
        name: 'Paladin Spellcasting',
        className: 'Paladin',
        atLevel: 1,
        description:
            'Half-caster on the Paladin spell list. Charisma is your spellcasting ability; a Holy Symbol is your spellcasting focus.',
      ),
      _cf(
        name: 'Weapon Mastery (Paladin)',
        className: 'Paladin',
        atLevel: 1,
        description:
            'You can use the mastery property of two kinds of weapons; swap one on each Long Rest.',
        effects: [effect('weapon_mastery_count_bonus', value: 2)],
      ),
      _cf(
        name: "Paladin's Smite",
        className: 'Paladin',
        atLevel: 2,
        description:
            'You always have Divine Smite prepared. When you hit with a melee weapon or Unarmed Strike, you can expend a spell slot to deal an extra 2d8 Radiant damage to the target, plus 1d8 per slot level above 1 (max 5d8).',
        effects: [
          effect('spell_always_prepared', targetRef: ref('spell', 'Divine Smite')),
        ],
      ),
      _cf(
        name: 'Channel Divinity (Paladin)',
        className: 'Paladin',
        atLevel: 3,
        description:
            'You gain Channel Divinity options from your Oath. 2 uses, regained on a Short or Long Rest.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:channel_divinity'),
                'recharge': 'short_rest',
                'count': 2,
              }),
        ],
      ),
      _cf(
        name: 'Extra Attack (Paladin)',
        className: 'Paladin',
        atLevel: 5,
        description: 'You can attack twice when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 2)],
      ),
      _cf(
        name: 'Faithful Steed',
        className: 'Paladin',
        atLevel: 5,
        description: 'You always have Find Steed prepared.',
        effects: [
          effect('spell_always_prepared', targetRef: ref('spell', 'Find Steed')),
        ],
      ),
      _cf(
        name: 'Aura of Protection',
        className: 'Paladin',
        atLevel: 6,
        description:
            'You and friendly creatures within 10 feet of you have a bonus to saving throws equal to your Charisma modifier (min +1).',
      ),
      _cf(
        name: 'Abjure Foes',
        className: 'Paladin',
        atLevel: 9,
        description:
            'As a Magic action, force creatures of your choice within 60 feet to make a Wisdom save or be Frightened of you until the end of your next turn (1/Long Rest).',
      ),
      _cf(
        name: 'Radiant Strikes',
        className: 'Paladin',
        atLevel: 11,
        description:
            'Once on each of your turns, when you hit a creature with a weapon attack you deal an extra 1d8 Radiant damage.',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'dice': '1d8',
                'when': 'first_hit_per_turn',
                'type_ref': _dt('Radiant'),
              }),
        ],
      ),
      _cf(
        name: 'Restoring Touch',
        className: 'Paladin',
        atLevel: 14,
        description:
            'You can spend 5 Lay On Hands points to remove the Charmed, Frightened, Paralyzed, or Stunned condition from a creature you touch.',
      ),
      _cf(
        name: 'Aura Expansion',
        className: 'Paladin',
        atLevel: 18,
        description: 'Your Aura of Protection has a 30-foot radius.',
      ),

      // ─── RANGER ──────────────────────────────────────────────────────────
      _cf(
        name: 'Favored Enemy',
        className: 'Ranger',
        atLevel: 1,
        description:
            'You always have Hunter\'s Mark prepared. You can cast it without a spell slot a number of times equal to your Wisdom modifier (min 1) per Long Rest.',
        effects: [
          effect('spell_always_prepared',
              targetRef: ref('spell', "Hunter's Mark")),
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:hunters_mark_no_slot_uses'),
                'recharge': 'long_rest',
                'count_formula': 'wis_mod_min_1',
              }),
        ],
      ),
      _cf(
        name: 'Ranger Spellcasting',
        className: 'Ranger',
        atLevel: 1,
        description:
            'Half-caster on the Ranger spell list. Wisdom is your spellcasting ability; a Druidic Focus is a valid focus.',
      ),
      _cf(
        name: 'Weapon Mastery (Ranger)',
        className: 'Ranger',
        atLevel: 1,
        description:
            'You can use the mastery property of two kinds of weapons; swap one on each Long Rest.',
        effects: [effect('weapon_mastery_count_bonus', value: 2)],
      ),
      _cf(
        name: 'Deft Explorer',
        className: 'Ranger',
        atLevel: 2,
        description:
            'You gain Expertise in one proficient skill of your choice and learn one extra language. More benefits unlock at higher Ranger levels.',
        effects: [
          effect('expertise_count', value: 1),
          effect('language_grant'),
        ],
      ),
      _cf(
        name: 'Roving',
        className: 'Ranger',
        atLevel: 3,
        description:
            'Your Speed increases by 5 feet, and you gain Climb and Swim Speeds equal to your Speed.',
        effects: [
          effect('speed_bonus', value: 5),
          effect('climb_speed_equals_speed'),
          effect('swim_speed_equals_speed'),
        ],
      ),
      _cf(
        name: 'Extra Attack (Ranger)',
        className: 'Ranger',
        atLevel: 5,
        description: 'You can attack twice when you take the Attack action.',
        effects: [effect('extra_attack_count', value: 2)],
      ),
      _cf(
        name: 'Expertise (Ranger II)',
        className: 'Ranger',
        atLevel: 9,
        description: 'Two more proficient skills gain Expertise.',
        effects: [effect('expertise_count', value: 2)],
      ),
      _cf(
        name: 'Tireless',
        className: 'Ranger',
        atLevel: 10,
        description:
            'As a Magic action you grant yourself Temporary HP equal to 1d8 + your Wisdom modifier. Uses equal to your Wisdom modifier per Long Rest. Whenever you finish a Short Rest your Exhaustion level decreases by 1.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:tireless_temp_hp_uses'),
                'recharge': 'long_rest',
                'count_formula': 'wis_mod_min_1',
              }),
        ],
      ),
      _cf(
        name: 'Relentless Hunter',
        className: 'Ranger',
        atLevel: 13,
        description:
            'Damage you take doesn\'t break your Concentration on Hunter\'s Mark.',
        effects: [effect('concentration_immune_to_damage_break')],
      ),
      _cf(
        name: "Nature's Veil",
        className: 'Ranger',
        atLevel: 14,
        description:
            'As a Bonus Action you can expend a spell slot of level 1 or higher to give yourself the Invisible condition until the end of your next turn.',
      ),
      _cf(
        name: 'Feral Senses',
        className: 'Ranger',
        atLevel: 18,
        description:
            'You don\'t have Disadvantage on attack rolls against creatures you can\'t see if they aren\'t Hidden, and your attack rolls against creatures within 30 feet that you can\'t see don\'t have Disadvantage.',
      ),
      _cf(
        name: 'Foe Slayer',
        className: 'Ranger',
        atLevel: 20,
        description:
            'Hunter\'s Mark\'s damage die becomes a d10. Once per turn when you hit Hunter\'s Mark target with a weapon attack, add your Wisdom modifier as extra damage.',
      ),

      // ─── ROGUE ───────────────────────────────────────────────────────────
      _cf(
        name: 'Expertise (Rogue)',
        className: 'Rogue',
        atLevel: 1,
        description:
            'Choose two proficient skills. Your Proficiency Bonus is doubled for any check you make with those skills.',
        effects: [effect('expertise_count', value: 2)],
      ),
      _cf(
        name: 'Sneak Attack',
        className: 'Rogue',
        atLevel: 1,
        description:
            'Once per turn, you can deal extra damage to a target you hit with a Finesse or Ranged weapon attack if you have Advantage on the attack, or if another enemy of the target is within 5 feet of it (and that enemy isn\'t Incapacitated and you don\'t have Disadvantage on the attack). Damage scales by Rogue level (1d6 → 10d6).',
        effects: [
          effect('extra_damage_on_attack',
              payload: {
                'when': 'first_hit_per_turn',
                'requires': 'finesse_or_ranged',
              },
              scalesWith: scalesByClass('Rogue', [
                [1, '1d6'], [3, '2d6'], [5, '3d6'], [7, '4d6'], [9, '5d6'],
                [11, '6d6'], [13, '7d6'], [15, '8d6'], [17, '9d6'], [19, '10d6'],
              ])),
        ],
      ),
      _cf(
        name: 'Weapon Mastery (Rogue)',
        className: 'Rogue',
        atLevel: 1,
        description:
            'You can use the mastery property of two kinds of weapons; swap one on each Long Rest.',
        effects: [effect('weapon_mastery_count_bonus', value: 2)],
      ),
      _cf(
        name: 'Cunning Action',
        className: 'Rogue',
        atLevel: 2,
        description:
            'You can take the Dash, Disengage, or Hide action as a Bonus Action.',
      ),
      _cf(
        name: 'Steady Aim',
        className: 'Rogue',
        atLevel: 3,
        description:
            'As a Bonus Action you can give yourself Advantage on your next attack roll on the current turn. You can\'t have moved this turn, and your Speed becomes 0 until the end of the turn.',
      ),
      _cf(
        name: 'Cunning Strike',
        className: 'Rogue',
        atLevel: 5,
        description:
            'When you hit with Sneak Attack you can spend Sneak Attack dice to apply effects (Poison, Trip, Withdraw, etc.).',
      ),
      _cf(
        name: 'Uncanny Dodge',
        className: 'Rogue',
        atLevel: 5,
        description:
            'When an attacker that you can see hits you with an attack roll, you can use your Reaction to halve the damage.',
      ),
      _cf(
        name: 'Evasion (Rogue)',
        className: 'Rogue',
        atLevel: 7,
        description:
            'When subjected to an effect that allows a Dexterity save for half damage, you instead take no damage on a success and half damage on a failure.',
      ),
      _cf(
        name: 'Reliable Talent',
        className: 'Rogue',
        atLevel: 7,
        description:
            'When you make an ability check using a skill in which you have Proficiency, treat any d20 roll of 9 or lower as a 10.',
      ),
      _cf(
        name: 'Improved Cunning Strike',
        className: 'Rogue',
        atLevel: 11,
        description:
            'You can apply two Cunning Strike effects per Sneak Attack hit instead of one.',
      ),
      _cf(
        name: 'Devious Strikes',
        className: 'Rogue',
        atLevel: 14,
        description:
            'New Cunning Strike options become available: Daze, Knock Out, Obscure.',
      ),
      _cf(
        name: 'Slippery Mind',
        className: 'Rogue',
        atLevel: 15,
        description:
            'You gain proficiency in Wisdom and Charisma saving throws.',
        effects: [
          effect('proficiency_grant',
              targetKind: 'saving_throw',
              targetRef: _ability('Wisdom')),
          effect('proficiency_grant',
              targetKind: 'saving_throw',
              targetRef: _ability('Charisma')),
        ],
      ),
      _cf(
        name: 'Elusive',
        className: 'Rogue',
        atLevel: 18,
        description:
            'No attack roll has Advantage against you while you don\'t have the Incapacitated condition.',
      ),
      _cf(
        name: 'Stroke of Luck',
        className: 'Rogue',
        atLevel: 20,
        description:
            'When you miss an attack roll or fail an ability check you can turn it into a hit or treat the d20 as a 20. 1/Short or Long Rest.',
      ),

      // ─── SORCERER ────────────────────────────────────────────────────────
      _cf(
        name: 'Sorcerer Spellcasting',
        className: 'Sorcerer',
        atLevel: 1,
        description:
            'You know cantrips and spells from the Sorcerer spell list. Charisma is your spellcasting ability.',
      ),
      _cf(
        name: 'Innate Sorcery',
        className: 'Sorcerer',
        atLevel: 1,
        description:
            'As a Bonus Action you trigger Innate Sorcery for 1 minute: Advantage on Sorcerer spell attack rolls and +1 to your spell save DC. Uses equal to your Charisma modifier (min 1) per Long Rest.',
        activation: activation(
          actionType: 'bonus_action',
          duration: {'kind': 'minutes', 'value': 1},
          uses: {'recharge': 'long_rest', 'count_formula': 'cha_mod_min_1'},
          triggersStateRef: 'state:innate_sorcery_active',
        ),
      ),
      _cf(
        name: 'Font of Magic',
        className: 'Sorcerer',
        atLevel: 2,
        description:
            'You gain Sorcery Points equal to your Sorcerer level. You can convert Sorcery Points ↔ spell slots at progressive costs.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:sorcery_points'),
                'recharge': 'long_rest',
                'count_formula': 'sorcerer_level',
              }),
        ],
      ),
      _cf(
        name: 'Sorcerous Restoration',
        className: 'Sorcerer',
        atLevel: 5,
        description:
            'When you finish a Short Rest, you regain 4 expended Sorcery Points. 1/Short Rest.',
      ),
      _cf(
        name: 'Sorcery Incarnate',
        className: 'Sorcerer',
        atLevel: 7,
        description:
            'You can use Innate Sorcery as a free action when casting a Sorcerer spell, even if you have no uses remaining (cost: 2 Sorcery Points).',
      ),
      _cf(
        name: 'Arcane Apotheosis',
        className: 'Sorcerer',
        atLevel: 20,
        description:
            'While Innate Sorcery is active, you can apply one Metamagic to each spell you cast without expending Sorcery Points.',
      ),

      // ─── WARLOCK ─────────────────────────────────────────────────────────
      _cf(
        name: 'Pact Magic',
        className: 'Warlock',
        atLevel: 1,
        description:
            'Your spell slots regain on a Short or Long Rest. Charisma is your spellcasting ability.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:pact_slots'),
                'recharge': 'short_rest',
              }),
          effect('slot_recovery_short_rest'),
        ],
      ),
      _cf(
        name: 'Magical Cunning',
        className: 'Warlock',
        atLevel: 2,
        description:
            'When you finish a Short Rest you can regain expended Pact Magic spell slots equal to half your maximum (rounded up). 1/Long Rest.',
      ),
      _cf(
        name: 'Mystic Arcanum (Level 6 Spell)',
        className: 'Warlock',
        atLevel: 11,
        description:
            'You learn one level 6 Warlock spell as a Mystic Arcanum. You can cast it once without a slot per Long Rest.',
      ),
      _cf(
        name: 'Mystic Arcanum (Level 7 Spell)',
        className: 'Warlock',
        atLevel: 13,
        description:
            'You learn one level 7 Warlock spell as a Mystic Arcanum (1/Long Rest, no slot).',
      ),
      _cf(
        name: 'Mystic Arcanum (Level 8 Spell)',
        className: 'Warlock',
        atLevel: 15,
        description:
            'You learn one level 8 Warlock spell as a Mystic Arcanum (1/Long Rest, no slot).',
      ),
      _cf(
        name: 'Mystic Arcanum (Level 9 Spell)',
        className: 'Warlock',
        atLevel: 17,
        description:
            'You learn one level 9 Warlock spell as a Mystic Arcanum (1/Long Rest, no slot).',
      ),
      _cf(
        name: 'Eldritch Master',
        className: 'Warlock',
        atLevel: 13,
        description:
            'You can take 1 minute to plead with your patron and regain all expended Pact Magic spell slots. 1/Long Rest.',
      ),
      _cf(
        name: 'Eldritch Resilience',
        className: 'Warlock',
        atLevel: 20,
        description:
            'You gain bonus uses of Magical Cunning, and you can resist your patron sundering your bond.',
      ),

      // ─── WIZARD ──────────────────────────────────────────────────────────
      _cf(
        name: 'Wizard Spellcasting',
        className: 'Wizard',
        atLevel: 1,
        description:
            'You know cantrips and prepare wizard spells from your spellbook. Intelligence is your spellcasting ability.',
      ),
      _cf(
        name: 'Ritual Adept',
        className: 'Wizard',
        atLevel: 1,
        description:
            'You can cast any spell with the Ritual tag as a Ritual without expending a spell slot — even if you don\'t have it prepared, provided it\'s in your spellbook.',
      ),
      _cf(
        name: 'Arcane Recovery',
        className: 'Wizard',
        atLevel: 1,
        description:
            'Once per day after a Short Rest, you regain expended spell slots whose combined level ≤ half your Wizard level (rounded up); none can be 6th level or higher.',
        effects: [
          effect('resource_pool_grant',
              payload: {
                'pool_ref': _pool('pool:arcane_recovery_per_day'),
                'recharge': 'long_rest',
                'count': 1,
              }),
        ],
      ),
      _cf(
        name: 'Memorize Spell',
        className: 'Wizard',
        atLevel: 5,
        description:
            'When you finish a Short Rest you can swap one prepared wizard spell for another wizard spell of the same level from your spellbook.',
      ),
      _cf(
        name: 'Spell Mastery',
        className: 'Wizard',
        atLevel: 18,
        description:
            'Choose one level 1 and one level 2 wizard spell that you have prepared. You can cast each at its lowest level without expending a spell slot.',
      ),
      _cf(
        name: 'Signature Spells',
        className: 'Wizard',
        atLevel: 20,
        description:
            'Choose two level 3 wizard spells from your spellbook. They are always prepared and you can cast each once without a spell slot per Short or Long Rest.',
      ),
    ];

/// SRD subclass-feature feats. One subclass per class.
List<Map<String, dynamic>> srdSubclassFeats() => [
      // ─── Path of the Berserker (Barbarian) ───────────────────────────────
      _sf(
        name: 'Frenzy',
        subclassName: 'Path of the Berserker',
        atLevel: 3,
        description:
            'While raging, you can make one melee attack as a Bonus Action on each of your turns. You take 1 level of Exhaustion at the end of the Frenzy when the Rage ends (max 6).',
      ),
      _sf(
        name: 'Mindless Rage',
        subclassName: 'Path of the Berserker',
        atLevel: 6,
        description:
            'You can\'t be Charmed or Frightened while raging. If you are Charmed or Frightened when you enter your Rage, that condition ends.',
      ),
      _sf(
        name: 'Retaliation',
        subclassName: 'Path of the Berserker',
        atLevel: 10,
        description:
            'When you take damage from a creature within 5 feet, you can use your Reaction to make a melee weapon attack against that creature.',
      ),
      _sf(
        name: 'Intimidating Presence',
        subclassName: 'Path of the Berserker',
        atLevel: 14,
        description:
            'As a Bonus Action you can force a creature you can see within 30 feet to make a Wisdom save or be Frightened of you for 1 minute.',
      ),

      // ─── College of Lore (Bard) ──────────────────────────────────────────
      _sf(
        name: 'Bonus Proficiencies (Lore)',
        subclassName: 'College of Lore',
        atLevel: 3,
        description: 'You gain proficiency with three skills of your choice.',
      ),
      _sf(
        name: 'Cutting Words',
        subclassName: 'College of Lore',
        atLevel: 3,
        description:
            'When a creature within 60 feet that you can hear makes an attack roll, ability check, or damage roll, you can use your Reaction to expend a Bardic Inspiration die and subtract it from the roll.',
      ),
      _sf(
        name: 'Magical Discoveries',
        subclassName: 'College of Lore',
        atLevel: 6,
        description:
            'You learn two spells of your choice from any class. They count as Bard spells for you and don\'t count against the number of Bard spells you know.',
      ),
      _sf(
        name: 'Peerless Skill',
        subclassName: 'College of Lore',
        atLevel: 14,
        description:
            'When you make an ability check, you can expend a Bardic Inspiration die and add it to the check.',
      ),

      // ─── Life Domain (Cleric) ────────────────────────────────────────────
      _sf(
        name: 'Disciple of Life',
        subclassName: 'Life Domain',
        atLevel: 3,
        description:
            'Whenever you use a spell of level 1+ to restore HP to a creature, the creature regains additional HP equal to 2 + the spell\'s level.',
      ),
      _sf(
        name: 'Channel Divinity: Preserve Life',
        subclassName: 'Life Domain',
        atLevel: 3,
        description:
            'As a Magic action you spend a Channel Divinity to restore 5 × your Cleric level HP across creatures within 30 feet you can see (none above half max HP).',
      ),
      _sf(
        name: 'Blessed Healer',
        subclassName: 'Life Domain',
        atLevel: 6,
        description:
            'When you cast a spell of level 1+ that restores HP to a creature other than yourself, you also regain 2 + the spell\'s level HP.',
      ),
      _sf(
        name: 'Supreme Healing',
        subclassName: 'Life Domain',
        atLevel: 17,
        description:
            'When you would normally roll dice to restore HP with a spell, instead you use the highest possible result for each die.',
      ),

      // ─── Circle of the Land (Druid) ──────────────────────────────────────
      _sf(
        name: 'Circle Spells',
        subclassName: 'Circle of the Land',
        atLevel: 3,
        description:
            'Choose a land (Arctic, Coast, Desert, Forest, Grassland, Mountain, Swamp, Underdark). You learn additional spells associated with that land at levels 3, 5, 7, and 9. They are always prepared.',
      ),
      _sf(
        name: 'Land\'s Aid',
        subclassName: 'Circle of the Land',
        atLevel: 3,
        description:
            'As a Magic action you cause a 10-foot Emanation of nature\'s aid: each creature you choose either takes 2d6 Necrotic damage (Con save half) or regains 2d6 HP. Uses scale with proficiency bonus.',
      ),
      _sf(
        name: 'Natural Recovery',
        subclassName: 'Circle of the Land',
        atLevel: 6,
        description:
            'Once per day on a Short Rest, you regain expended spell slots whose combined level ≤ half your Druid level (rounded up); none can be 6th level or higher.',
      ),
      _sf(
        name: 'Nature\'s Ward',
        subclassName: 'Circle of the Land',
        atLevel: 10,
        description:
            'You are immune to the Frightened and Poisoned conditions. You\'re also immune to Poison damage and to disease.',
        effects: [
          effect('condition_immunity_grant', targetRef: _cond('Frightened')),
          effect('condition_immunity_grant', targetRef: _cond('Poisoned')),
          effect('damage_immunity', targetRef: _dt('Poison')),
        ],
      ),
      _sf(
        name: 'Nature\'s Sanctuary',
        subclassName: 'Circle of the Land',
        atLevel: 14,
        description:
            'When a Beast or Plant attacks you, that creature must make a Wisdom save or choose a different target. On a save, the creature is immune to this for 24 hours.',
      ),

      // ─── Champion (Fighter) ──────────────────────────────────────────────
      _sf(
        name: 'Improved Critical',
        subclassName: 'Champion',
        atLevel: 3,
        description: 'Your weapon attacks score a Critical Hit on a roll of 19 or 20.',
        effects: [
          effect('crit_range_extend', payload: {'threshold': 19}),
        ],
      ),
      _sf(
        name: 'Remarkable Athlete',
        subclassName: 'Champion',
        atLevel: 7,
        description:
            'You can add half your Proficiency Bonus (rounded up) to any Strength, Dexterity, or Constitution check you make that doesn\'t already use your PB.',
      ),
      _sf(
        name: 'Additional Fighting Style',
        subclassName: 'Champion',
        atLevel: 10,
        description: 'You gain another Fighting Style option of your choice.',
      ),
      _sf(
        name: 'Superior Critical',
        subclassName: 'Champion',
        atLevel: 15,
        description:
            'Your weapon attacks score a Critical Hit on a roll of 18, 19, or 20.',
        effects: [
          effect('crit_range_extend', payload: {'threshold': 18}),
        ],
      ),
      _sf(
        name: 'Survivor',
        subclassName: 'Champion',
        atLevel: 18,
        description:
            'At the start of each of your turns, if you have at least 1 HP but no more than half your HP, you regain HP equal to 5 + your Constitution modifier.',
      ),

      // ─── Warrior of the Open Hand (Monk) ─────────────────────────────────
      _sf(
        name: 'Open Hand Technique',
        subclassName: 'Warrior of the Open Hand',
        atLevel: 3,
        description:
            'Whenever you hit with one of the attacks granted by Flurry of Blows, you can impose one of: Knock Prone, Push 15 feet, or Disable Bonus Action / Reaction.',
      ),
      _sf(
        name: 'Wholeness of Body',
        subclassName: 'Warrior of the Open Hand',
        atLevel: 6,
        description:
            'As a Bonus Action you regain HP equal to 3 × your Monk level. Recharges on a Long Rest.',
      ),
      _sf(
        name: 'Fleet Step',
        subclassName: 'Warrior of the Open Hand',
        atLevel: 11,
        description:
            'As a Bonus Action you can take Step of the Wind followed by Flurry of Blows on the same turn.',
      ),
      _sf(
        name: 'Quivering Palm',
        subclassName: 'Warrior of the Open Hand',
        atLevel: 17,
        description:
            'When you hit a creature with an Unarmed Strike, you can spend 4 Focus Points to start imperceptible vibrations. Within 24 hours, you can use your Bonus Action to end them, forcing the creature to make a Constitution save or drop to 0 HP.',
      ),

      // ─── Oath of Devotion (Paladin) ──────────────────────────────────────
      _sf(
        name: 'Sacred Weapon',
        subclassName: 'Oath of Devotion',
        atLevel: 3,
        description:
            'As a Bonus Action you can spend Channel Divinity to imbue a weapon with positive energy: +Cha mod to attack, sheds Bright Light. Lasts 1 minute.',
      ),
      _sf(
        name: 'Aura of Devotion',
        subclassName: 'Oath of Devotion',
        atLevel: 7,
        description:
            'You and friendly creatures within 10 feet of you can\'t be Charmed.',
        effects: [
          effect('condition_immunity_grant', targetRef: _cond('Charmed')),
        ],
      ),
      _sf(
        name: 'Smite of Protection',
        subclassName: 'Oath of Devotion',
        atLevel: 15,
        description:
            'When you Divine Smite, you and all friendly creatures within your Aura of Protection have Half Cover for 1 minute.',
      ),
      _sf(
        name: 'Holy Nimbus',
        subclassName: 'Oath of Devotion',
        atLevel: 20,
        description:
            'As a Bonus Action you emanate divine light. Hostile creatures that start their turn in your Aura of Protection take 10 Radiant damage; you have Advantage on saving throws against spells cast by Fiends or Undead.',
      ),

      // ─── Hunter (Ranger) ─────────────────────────────────────────────────
      _sf(
        name: "Hunter's Lore",
        subclassName: 'Hunter',
        atLevel: 3,
        description:
            'When you mark a target with Hunter\'s Mark you learn one of: damage immunities, resistances, vulnerabilities of that target.',
      ),
      _sf(
        name: "Hunter's Prey",
        subclassName: 'Hunter',
        atLevel: 3,
        description:
            'Choose one of: Colossus Slayer (+1d8 once/turn vs. damaged target), Horde Breaker (extra attack vs. nearby creature), or Hunter\'s Lore.',
      ),
      _sf(
        name: 'Defensive Tactics',
        subclassName: 'Hunter',
        atLevel: 7,
        description:
            'Choose one of: Escape the Horde, Multiattack Defense, or Steel Will.',
      ),
      _sf(
        name: 'Superior Hunter\'s Defense',
        subclassName: 'Hunter',
        atLevel: 11,
        description:
            'Choose one of: Evasion, Stand Against the Tide, or Uncanny Dodge.',
      ),
      _sf(
        name: 'Multiattack',
        subclassName: 'Hunter',
        atLevel: 11,
        description:
            'Choose Volley (ranged AoE) or Whirlwind Attack (melee AoE).',
      ),
      _sf(
        name: 'Hunter\'s Strategy',
        subclassName: 'Hunter',
        atLevel: 15,
        description:
            'Each Hunter\'s Prey, Defensive Tactics, and Multiattack option is now available to you (no choice required).',
      ),

      // ─── Thief (Rogue) ───────────────────────────────────────────────────
      _sf(
        name: 'Fast Hands',
        subclassName: 'Thief',
        atLevel: 3,
        description:
            'You can use the Bonus Action granted by Cunning Action to make a Sleight of Hand check, use Thieves\' Tools, or take the Use an Object action.',
      ),
      _sf(
        name: 'Second-Story Work',
        subclassName: 'Thief',
        atLevel: 3,
        description:
            'You gain a Climb Speed equal to your walking Speed, and your jump distance increases by your Dex modifier × 1 ft.',
        effects: [effect('climb_speed_equals_speed')],
      ),
      _sf(
        name: 'Supreme Sneak',
        subclassName: 'Thief',
        atLevel: 9,
        description:
            'You have Advantage on Stealth checks if you move no more than half your Speed on the same turn.',
      ),
      _sf(
        name: 'Use Magic Device',
        subclassName: 'Thief',
        atLevel: 13,
        description:
            'You ignore class, race, and level requirements on the use of magic items.',
      ),
      _sf(
        name: 'Thief\'s Reflexes',
        subclassName: 'Thief',
        atLevel: 17,
        description:
            'On the first round of combat, you take two turns: one at your normal initiative and one at your initiative −10.',
      ),

      // ─── Draconic Sorcery (Sorcerer) ─────────────────────────────────────
      _sf(
        name: 'Draconic Resilience',
        subclassName: 'Draconic Sorcery',
        atLevel: 3,
        description:
            'Your HP maximum increases by 3, and increases by 1 each time you gain a Sorcerer level. While not wearing armor, your AC = 13 + your Dexterity modifier.',
        effects: [
          effect('hp_max_bonus_total', value: 3),
          effect('hp_bonus_per_level', value: 1),
          effect('unarmored_ac_formula',
              payload: {
                'base': 13,
                'ability_mods': ['DEX'],
                'shield_allowed': true,
              },
              predicates: [predicate('equipped_armor_kind', {'value': 'none'})]),
        ],
      ),
      _sf(
        name: 'Draconic Spells',
        subclassName: 'Draconic Sorcery',
        atLevel: 3,
        description:
            'You always have a fixed list of Draconic spells prepared (varies by ancestry choice).',
      ),
      _sf(
        name: 'Elemental Affinity',
        subclassName: 'Draconic Sorcery',
        atLevel: 6,
        description:
            'When you cast a spell that deals damage of the type associated with your Draconic Ancestry, you can add your Charisma modifier to one damage roll. You also gain Resistance to that damage type.',
      ),
      _sf(
        name: 'Dragon Wings',
        subclassName: 'Draconic Sorcery',
        atLevel: 14,
        description:
            'As a Bonus Action you sprout dragon wings, gaining a Fly Speed equal to your Speed for 1 hour. 1/Long Rest.',
      ),
      _sf(
        name: 'Draconic Presence',
        subclassName: 'Draconic Sorcery',
        atLevel: 18,
        description:
            'As a Magic action, spend 5 Sorcery Points to project a 60-foot Emanation that imposes Charmed or Frightened on creatures of your choice (Wis save).',
      ),

      // ─── Fiend Patron (Warlock) ──────────────────────────────────────────
      _sf(
        name: 'Dark One\'s Blessing',
        subclassName: 'Fiend Patron',
        atLevel: 3,
        description:
            'When you reduce a creature to 0 HP, you gain Temporary HP equal to your Charisma modifier + your Warlock level (min 1).',
      ),
      _sf(
        name: 'Fiendish Vigor',
        subclassName: 'Fiend Patron',
        atLevel: 3,
        description: 'You always have False Life prepared.',
        effects: [
          effect('spell_always_prepared', targetRef: ref('spell', 'False Life')),
        ],
      ),
      _sf(
        name: 'Dark One\'s Own Luck',
        subclassName: 'Fiend Patron',
        atLevel: 6,
        description:
            'When you make an ability check or saving throw, you can roll 1d10 and add it to the result. 1/Short or Long Rest.',
      ),
      _sf(
        name: 'Fiendish Resilience',
        subclassName: 'Fiend Patron',
        atLevel: 10,
        description:
            'On each Short or Long Rest you choose one damage type. You have Resistance to that damage type until you choose a different one.',
      ),
      _sf(
        name: 'Hurl Through Hell',
        subclassName: 'Fiend Patron',
        atLevel: 14,
        description:
            'When you hit a creature with an attack, you can banish it through the lower planes. The creature disappears and re-appears at the start of its next turn, taking 8d10 Psychic damage. 1/Long Rest.',
      ),

      // ─── Evoker (Wizard) ─────────────────────────────────────────────────
      _sf(
        name: 'Evocation Savant',
        subclassName: 'Evoker',
        atLevel: 3,
        description:
            'When you copy an Evocation spell into your spellbook, the time and gold cost are halved. You also learn an extra Evocation cantrip.',
      ),
      _sf(
        name: 'Potent Cantrip',
        subclassName: 'Evoker',
        atLevel: 3,
        description:
            'When a creature succeeds on a save against one of your cantrips that does not affect Constructs or Undead, the creature still takes half damage but suffers no other effect.',
      ),
      _sf(
        name: 'Sculpt Spells',
        subclassName: 'Evoker',
        atLevel: 6,
        description:
            'When you cast an Evocation spell that affects other creatures you can see, you can choose a number equal to 1 + the spell\'s level — they automatically succeed on saving throws against the spell and take no damage.',
      ),
      _sf(
        name: 'Empowered Evocation',
        subclassName: 'Evoker',
        atLevel: 10,
        description:
            'You can add your Intelligence modifier to one damage roll of an Evocation spell you cast.',
      ),
      _sf(
        name: 'Overchannel',
        subclassName: 'Evoker',
        atLevel: 14,
        description:
            'When you cast a wizard spell of levels 1–5 that deals damage, you can deal maximum damage. The first time you do this between rests is free; each subsequent use deals 2d12 Necrotic damage to you per level of the spell that you can\'t reduce.',
      ),
    ];
