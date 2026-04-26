// SRD 5.2.1 Feats (pp. 87–88: Origin / General / Fighting Style / Epic Boon).
//
// Per-feat fields populated:
//   category_ref → Tier-0 feat-category lookup (Origin / General / Fighting
//     Style / Epic Boon).
//   prereq_min_character_level — parsed from "Level N+" prerequisite.
//   prereq_requires_spellcasting — true when "Spellcasting Feature" listed.
//   prereq_ability_ref + prereq_min_score — when "<Ability> N+" listed.
//   prerequisite — narrative repeat of the prereq line.
//   repeatable + repeatable_limit (null = unlimited).
//   asi_ability_options + asi_amount + asi_max_score — typed ASI gate.
//   benefits — markdown body.

import '_helpers.dart';

List<Map<String, dynamic>> srdFeats() => [
      // ─── Origin Feats ────────────────────────────────────────────────────
      packEntity(
        slug: 'feat',
        name: 'Alert',
        description:
            'You spot trouble before it happens and can swap places with an ally at the start of combat.',
        attributes: {
          'category_ref': lookup('feat-category', 'Origin'),
          'repeatable': false,
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Initiative Proficiency.** When you roll Initiative, you can add your Proficiency Bonus to the roll.\n\n'
                  '**Initiative Swap.** Immediately after you roll Initiative, you can swap your Initiative with the Initiative of one willing ally in the same combat. You can\'t make this swap if you or the ally has the Incapacitated condition.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Magic Initiate',
        description:
            'You learn two cantrips and a level 1 spell from the Cleric, Druid, or Wizard list.',
        attributes: {
          'category_ref': lookup('feat-category', 'Origin'),
          'repeatable': true,
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Two Cantrips.** You learn two cantrips of your choice from the Cleric, Druid, or Wizard spell list. Intelligence, Wisdom, or Charisma is your spellcasting ability for this feat\'s spells (choose when you select this feat).\n\n'
                  '**Level 1 Spell.** Choose a level 1 spell from the same list you selected for this feat\'s cantrips. You always have that spell prepared. You can cast it once without a spell slot, and you regain the ability to cast it in that way when you finish a Long Rest. You can also cast the spell using any spell slots you have.\n\n'
                  '**Spell Change.** Whenever you gain a new level, you can replace one of the spells you chose for this feat with a different spell of the same level from the chosen spell list.\n\n'
                  '**Repeatable.** You can take this feat more than once, but you must choose a different spell list each time.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Savage Attacker',
        description:
            'Once per turn you can re-roll a weapon\'s damage and use either result.',
        attributes: {
          'category_ref': lookup('feat-category', 'Origin'),
          'repeatable': false,
          'benefits':
              'You\'ve trained to deal particularly damaging strikes. Once per turn when you hit a target with a weapon, you can roll the weapon\'s damage dice twice and use either roll against the target.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Skilled',
        description:
            'You gain proficiency with three skills or tools of your choice.',
        attributes: {
          'category_ref': lookup('feat-category', 'Origin'),
          'repeatable': true,
          'benefits':
              'You gain proficiency in any combination of three skills or tools of your choice.\n\n'
                  '**Repeatable.** You can take this feat more than once.',
        },
      ),

      // ─── General Feats ───────────────────────────────────────────────────
      packEntity(
        slug: 'feat',
        name: 'Ability Score Improvement',
        description:
            'Increase one ability score by 2 or two ability scores by 1 (max 20).',
        attributes: {
          'category_ref': lookup('feat-category', 'General'),
          'prereq_min_character_level': 4,
          'prerequisite': 'Level 4+',
          'repeatable': true,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 2,
          'asi_max_score': 20,
          'ability_score_increase':
              'Increase one ability score of your choice by 2, or increase two ability scores of your choice by 1. This feat can\'t increase an ability score above 20.',
          'benefits':
              'Increase one ability score of your choice by 2, or increase two ability scores of your choice by 1. This feat can\'t increase an ability score above 20.\n\n'
                  '**Repeatable.** You can take this feat more than once.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Grappler',
        description:
            'Your Unarmed Strikes can both damage and grapple, with Advantage on attacks against creatures you\'ve grappled.',
        attributes: {
          'category_ref': lookup('feat-category', 'General'),
          'prereq_min_character_level': 4,
          'prerequisite':
              'Level 4+, Strength or Dexterity 13+',
          'prereq_min_score': 13,
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'asi_amount': 1,
          'asi_max_score': 20,
          'ability_score_increase':
              'Increase your Strength or Dexterity score by 1, to a maximum of 20.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n'
                  '**Punch and Grab.** When you hit a creature with an Unarmed Strike as part of the Attack action on your turn, you can use both the Damage and the Grapple option. You can use this benefit only once per turn.\n\n'
                  '**Attack Advantage.** You have Advantage on attack rolls against a creature Grappled by you.\n\n'
                  '**Fast Wrestler.** You don\'t have to spend extra movement to move a creature Grappled by you if the creature is your size or smaller.',
        },
      ),

      // ─── Fighting Style Feats ────────────────────────────────────────────
      packEntity(
        slug: 'feat',
        name: 'Archery',
        description: '+2 to attack rolls with Ranged weapons.',
        attributes: {
          'category_ref': lookup('feat-category', 'Fighting Style'),
          'prerequisite': 'Fighting Style Feature',
          'repeatable': false,
          'benefits':
              'You gain a +2 bonus to attack rolls you make with Ranged weapons.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Defense',
        description: '+1 AC while wearing armor.',
        attributes: {
          'category_ref': lookup('feat-category', 'Fighting Style'),
          'prerequisite': 'Fighting Style Feature',
          'repeatable': false,
          'benefits':
              'While you\'re wearing Light, Medium, or Heavy armor, you gain a +1 bonus to Armor Class.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Great Weapon Fighting',
        description:
            'Treat 1s and 2s on damage dice as 3s when wielding a two-handed melee weapon.',
        attributes: {
          'category_ref': lookup('feat-category', 'Fighting Style'),
          'prerequisite': 'Fighting Style Feature',
          'repeatable': false,
          'benefits':
              'When you roll damage for an attack you make with a Melee weapon that you are holding with two hands, you can treat any 1 or 2 on a damage die as a 3. The weapon must have the Two-Handed or Versatile property to gain this benefit.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Two-Weapon Fighting',
        description:
            'Add your ability modifier to the damage of the off-hand attack.',
        attributes: {
          'category_ref': lookup('feat-category', 'Fighting Style'),
          'prerequisite': 'Fighting Style Feature',
          'repeatable': false,
          'benefits':
              'When you make an extra attack as a result of using a weapon that has the Light property, you can add your ability modifier to the damage of that attack if you aren\'t already adding it to the damage.',
        },
      ),

      // ─── Epic Boon Feats ─────────────────────────────────────────────────
      packEntity(
        slug: 'feat',
        name: 'Boon of Combat Prowess',
        description:
            'Once per turn convert a missed attack into a hit.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase one ability score of your choice by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Peerless Aim.** When you miss with an attack roll, you can hit instead. Once you use this benefit, you can\'t use it again until the start of your next turn.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of Dimensional Travel',
        description:
            'After Attack or Magic action, teleport up to 30 feet.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase one ability score of your choice by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Blink Steps.** Immediately after you take the Attack action or the Magic action, you can teleport up to 30 feet to an unoccupied space you can see.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of Fate',
        description:
            'Roll 2d4 to alter the result of a D20 Test you witness.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase one ability score of your choice by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Improve Fate.** When you or another creature within 60 feet of you succeeds on or fails a D20 Test, you can roll 2d4 and apply the total rolled as a bonus or penalty to the d20 roll. Once you use this benefit, you can\'t use it again until you roll Initiative or finish a Short or Long Rest.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of Irresistible Offense',
        description:
            'Damage ignores Resistance; crits deal extra damage equal to the boosted ability score.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase your Strength or Dexterity score by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 30.\n\n'
                  '**Overcome Defenses.** The Bludgeoning, Piercing, and Slashing damage you deal always ignores Resistance.\n\n'
                  '**Overwhelming Strike.** When you roll a 20 on the d20 for an attack roll, you can deal extra damage to the target equal to the ability score increased by this feat. The extra damage\'s type is the same as the attack\'s type.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of Spell Recall',
        description:
            'Roll 1d4 each spell cast with a level 1–4 slot; on a match the slot isn\'t expended.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prereq_requires_spellcasting': true,
          'prerequisite': 'Level 19+, Spellcasting Feature',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 30.\n\n'
                  '**Free Casting.** Whenever you cast a spell with a level 1–4 spell slot, roll 1d4. If the number you roll is the same as the slot\'s level, the slot isn\'t expended.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of the Night Spirit',
        description:
            'Become Invisible in dim light or darkness and take Resistance to most damage.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase one ability score of your choice by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Merge with Shadows.** While within Dim Light or Darkness, you can give yourself the Invisible condition as a Bonus Action. The condition ends on you immediately after you take an action, a Bonus Action, or a Reaction.\n\n'
                  '**Shadowy Form.** While within Dim Light or Darkness, you have Resistance to all damage except Psychic and Radiant.',
        },
      ),
      packEntity(
        slug: 'feat',
        name: 'Boon of Truesight',
        description: 'Gain Truesight 60 feet.',
        attributes: {
          'category_ref': lookup('feat-category', 'Epic Boon'),
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
          'ability_score_increase':
              'Increase one ability score of your choice by 1, to a maximum of 30.',
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Truesight.** You have Truesight with a range of 60 feet.',
        },
      ),
    ];
