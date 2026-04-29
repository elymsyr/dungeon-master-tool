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
          'category_ref': 'Origin',
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
          'category_ref': 'Origin',
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
          'category_ref': 'Origin',
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
          'category_ref': 'Origin',
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
          'category_ref': 'General',
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
          'category_ref': 'General',
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
          'category_ref': 'Fighting Style',
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
          'category_ref': 'Fighting Style',
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
          'category_ref': 'Fighting Style',
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
          'category_ref': 'Fighting Style',
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
          'category_ref': 'Epic Boon',
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
          'category_ref': 'Epic Boon',
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
          'category_ref': 'Epic Boon',
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
          'category_ref': 'Epic Boon',
          'prereq_min_character_level': 19,
          'prerequisite': 'Level 19+',
          'repeatable': false,
          'asi_ability_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'asi_amount': 1,
          'asi_max_score': 30,
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
          'category_ref': 'Epic Boon',
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
          'category_ref': 'Epic Boon',
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
          'category_ref': 'Epic Boon',
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
          'benefits':
              'You gain the following benefits.\n\n'
                  '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 30.\n\n'
                  '**Truesight.** You have Truesight with a range of 60 feet.',
        },
      ),

      // ─── More Origin Feats ──────────────────────────────────────────────
      packEntity(slug: 'feat', name: 'Crafter', description: 'You gain proficiency with three Artisan\'s Tools and craft items more efficiently.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'benefits': '**Tool Proficiency.** You gain proficiency with three different Artisan\'s Tools of your choice.\n\n**Discount.** Whenever you buy a nonmagical item, you receive a 20% discount.\n\n**Faster Crafting.** Whenever you craft a nonmagical item, you can do so in only a fifth of the normal crafting time.'}),
      packEntity(slug: 'feat', name: 'Healer', description: 'You can stabilize and heal others with great efficiency, restoring HP with a use of a Healer\'s Kit.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'benefits': '**Battle Medic.** If you have a Healer\'s Kit, you can take a Utilize action to expend one of its uses and tend to a creature within 5 feet of you. That creature can spend one of its Hit Point Dice, and you then roll that die. The creature regains a number of HP equal to the roll plus your Proficiency Bonus.\n\n**Healing Surge.** Once per turn when you roll a 1 on a Hit Point Die you spent during a Short or Long Rest, you can re-roll the die and use the higher result.'}),
      packEntity(slug: 'feat', name: 'Lucky', description: 'You have a knack for being in the right place. You can spend Luck Points to alter d20 Tests.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'benefits': '**Luck Points.** You have a number of Luck Points equal to your Proficiency Bonus, and you regain all expended Luck Points when you finish a Long Rest.\n\n**Advantage.** You can spend a Luck Point when you make a d20 Test (attack roll, ability check, or saving throw); you have Advantage on the roll.\n\n**Disadvantage on Attacker.** When another creature rolls an attack roll against you, you can spend a Luck Point to give them Disadvantage.'}),
      packEntity(slug: 'feat', name: 'Musician', description: 'You can inspire allies with music, granting Bardic-like inspiration once per Long Rest.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'benefits': '**Tool Proficiency.** You gain proficiency with three musical instruments of your choice.\n\n**Encouraging Song.** As you finish a Short or Long Rest, you can play a song on a musical instrument with which you have proficiency and give Heroic Inspiration to allies who hear the song. The number of allies you can affect equals your Proficiency Bonus.'}),
      packEntity(slug: 'feat', name: 'Tavern Brawler', description: 'You learned to fight with whatever\'s at hand — chairs, mugs, fists.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Constitution'], 'benefits': '**Ability Score Increase.** Increase your Strength or Constitution score by 1, to a maximum of 20.\n\n**Enhanced Unarmed Strike.** When you hit with your Unarmed Strike, you can deal Bludgeoning damage equal to 1d4 + your Strength modifier instead of normal damage.\n\n**Damaging Improvisation.** You are proficient with Improvised Weapons.\n\n**Push.** When you hit a creature with an Unarmed Strike as part of the Attack action on your turn, you can deal damage to the target and also push it 5 feet from you.'}),
      packEntity(slug: 'feat', name: 'Tough', description: 'Your HP maximum increases.', attributes: {'category_ref': 'Origin', 'repeatable': false, 'benefits': 'Your Hit Point maximum increases by an amount equal to twice your character level when you choose this feat. Whenever you gain a level thereafter, your HP maximum increases by an additional 2.'}),

      // ─── More General Feats ─────────────────────────────────────────────
      packEntity(slug: 'feat', name: 'Athlete', description: 'You hone your physique. Climbing and jumping become trivial.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Climbing.** Climbing doesn\'t cost you extra movement.\n\n**Jumping.** You can make a running long jump or a running high jump after moving only 5 feet on foot rather than 10 feet.\n\n**Standing Up.** Standing up from Prone uses only 5 feet of your movement rather than half your Speed.'}),
      packEntity(slug: 'feat', name: 'Charger', description: 'You can charge into battle and shove or strike at the end.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'benefits': '**Charge.** When you take the Attack action, you can replace one of the attacks with a special melee attack made after you move at least 10 feet straight toward a target. If your attack hits, the target takes an extra 2d8 damage of the attack\'s type, and you can push it up to 10 feet away from you.'}),
      packEntity(slug: 'feat', name: 'Crossbow Expert', description: 'Master of the crossbow, ignoring loading and gaining bonus shots.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Dexterity 13+', 'prereq_ability_ref': lookup('ability', 'Dexterity'), 'prereq_min_score': 13, 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Dexterity score by 1, to a maximum of 20.\n\n**Ignore Loading.** You ignore the Loading property of crossbows with which you are proficient.\n\n**Firing in Melee.** Being within 5 feet of an enemy doesn\'t impose Disadvantage on your ranged attack rolls with crossbows you are proficient with.\n\n**Bonus Crossbow Attack.** When you take the Attack action and attack with a one-handed weapon, you can use a Bonus Action to make a single attack with a Hand Crossbow you are holding.'}),
      packEntity(slug: 'feat', name: 'Defensive Duelist', description: 'When wielding a Finesse weapon, you can deflect attacks.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Dexterity 13+', 'prereq_ability_ref': lookup('ability', 'Dexterity'), 'prereq_min_score': 13, 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Dexterity score by 1, to a maximum of 20.\n\n**Parry.** When you\'re wielding a Finesse weapon and another creature hits you with a melee attack roll, you can take a Reaction to add your Proficiency Bonus to your AC against that attack, possibly causing it to miss you.'}),
      packEntity(slug: 'feat', name: 'Dual Wielder', description: 'You wield two weapons with skill, gaining AC and bonus attacks.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Bonus Attack.** When you take the Attack action and attack with a one-handed melee weapon that lacks the Two-Handed property, you can use a Bonus Action to make one melee attack with a different weapon you\'re holding (the second weapon doesn\'t need the Light property).\n\n**Drawing Weapons.** You can draw or stow two one-handed weapons when you would normally be able to draw or stow only one.\n\n**Enhanced Defense.** While you are holding a separate melee weapon in each hand, you gain a +1 bonus to AC.'}),
      packEntity(slug: 'feat', name: 'Durable', description: 'You are exceptionally hardy.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Constitution'], 'benefits': '**Ability Score Increase.** Increase your Constitution score by 1, to a maximum of 20.\n\n**Defy Death.** You have Advantage on Death Saves.\n\n**Speedy Recovery.** As a Bonus Action, you can expend one of your Hit Point Dice, roll the die, and regain HP equal to the roll plus your Constitution modifier (minimum of 1 HP). Once you use this benefit, you can\'t do so again until you finish a Short or Long Rest.'}),
      packEntity(slug: 'feat', name: 'Elemental Adept', description: 'You overcome resistance to one damage type and ignore zeroes.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Spellcasting Feature', 'prereq_requires_spellcasting': true, 'repeatable': true, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Energy Mastery.** Choose one of the following damage types: Acid, Cold, Fire, Lightning, or Thunder. Spells you cast ignore Resistance to damage of the chosen type. In addition, when you roll damage for a spell you cast that deals damage of that type, you can treat any 1 on a damage die as a 2.\n\n**Repeatable.** You can take this feat more than once, but you must choose a different damage type each time.'}),
      packEntity(slug: 'feat', name: 'Fey-Touched', description: 'You gain Misty Step and another Divination or Enchantment spell.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Magical Gift.** You learn the Misty Step spell and one level 1 spell of your choice from the Divination or Enchantment school of magic. You can cast each of these spells without expending a spell slot once per Long Rest. You can also cast these spells using spell slots you have. Intelligence, Wisdom, or Charisma is your spellcasting ability for these spells (choose when you take the feat).'}),
      packEntity(slug: 'feat', name: 'Great Weapon Master', description: 'You wield heavy weapons with deadly skill.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength'], 'benefits': '**Ability Score Increase.** Increase your Strength score by 1, to a maximum of 20.\n\n**Cleaving Strike.** Once on each of your turns when you score a Critical Hit with a melee weapon or reduce a creature to 0 HP with one, you can use a Bonus Action to make one melee weapon attack.\n\n**Heavy Hitter.** Once on each of your turns when you hit a creature with an attack using a Heavy weapon, you can deal an extra 1d12 damage of the same type as the weapon\'s damage.'}),
      packEntity(slug: 'feat', name: 'Heavy Armor Master', description: 'You can ignore some damage while wearing heavy armor.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; proficiency with Heavy Armor', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength'], 'benefits': '**Ability Score Increase.** Increase your Strength score by 1, to a maximum of 20.\n\n**Damage Resistance.** While you are wearing Heavy Armor and aren\'t Incapacitated, Bludgeoning, Piercing, and Slashing damage that you take from nonmagical attacks is reduced by an amount equal to your Proficiency Bonus.'}),
      packEntity(slug: 'feat', name: 'Inspiring Leader', description: 'You can inspire your allies with a stirring speech.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Charisma 13+', 'prereq_ability_ref': lookup('ability', 'Charisma'), 'prereq_min_score': 13, 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Charisma'], 'benefits': '**Ability Score Increase.** Increase your Charisma score by 1, to a maximum of 20.\n\n**Speech.** You can spend 10 minutes giving a stirring speech to up to six creatures within 30 feet who can hear and understand you. Each creature gains Temporary Hit Points equal to your character level + your Charisma modifier. A creature can\'t gain TempHP from this feat again until it has finished a Long Rest.'}),
      packEntity(slug: 'feat', name: 'Keen Mind', description: 'Your memory and reasoning are sharp.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence'], 'benefits': '**Ability Score Increase.** Increase your Intelligence score by 1, to a maximum of 20.\n\n**Perfect Recall.** You can perfectly remember anything you\'ve experienced or read in the past month. Whenever you make an Intelligence check that involves remembering something, you can add your Proficiency Bonus to the roll if you wouldn\'t already.'}),
      packEntity(slug: 'feat', name: 'Lightly Armored', description: 'You gain Light Armor proficiency.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Armor Training.** You gain training with Light Armor.'}),
      packEntity(slug: 'feat', name: 'Mage Slayer', description: 'You strike with skill against spellcasters.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Concentration Breaker.** When you damage a creature concentrating on a spell, the creature has Disadvantage on the saving throw it makes to maintain Concentration.\n\n**Guarded Mind.** If you fail an Intelligence, Wisdom, or Charisma save, you can spend 10 feet of movement to reroll, using the new roll.'}),
      packEntity(slug: 'feat', name: 'Martial Adept', description: 'You learn Maneuvers from Battle Master fighters.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Maneuvers.** You learn two Maneuvers of your choice from those available to the Battle Master. If a Maneuver requires a save, the DC equals 8 + your Proficiency Bonus + your Strength or Dex modifier (your choice).\n\n**Superiority Die.** You gain one Superiority Die (a d6). It is expended when you use it. You regain it when you finish a Short or Long Rest.'}),
      packEntity(slug: 'feat', name: 'Medium Armor Master', description: 'You wear medium armor with finesse.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; proficiency with Medium Armor', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Dexterity score by 1, to a maximum of 20.\n\n**Stealth Bonus.** Wearing Medium Armor doesn\'t impose Disadvantage on your Dex (Stealth) checks.\n\n**Dexterity Bonus.** When you wear Medium Armor, you can add 3, rather than 2, to your AC if your Dex is 16+.'}),
      packEntity(slug: 'feat', name: 'Mobile', description: 'You are exceptionally swift and agile.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Dexterity', 'Strength'], 'benefits': '**Ability Score Increase.** Increase your Dexterity or Strength score by 1, to a maximum of 20.\n\n**Nimble.** Your Speed increases by 10 feet.\n\n**Dash Across Difficult Terrain.** When you take the Dash action, Difficult Terrain doesn\'t cost you extra movement on that turn.\n\n**Avoid Opportunity Attacks.** When you make a melee attack against a creature, you don\'t provoke Opportunity Attacks from that creature for the rest of the turn.'}),
      packEntity(slug: 'feat', name: 'Moderately Armored', description: 'You gain Medium Armor and Shield training.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; proficiency with Light Armor', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Armor Training.** You gain training with Medium Armor and Shields.'}),
      packEntity(slug: 'feat', name: 'Mounted Combatant', description: 'You are a mounted warrior par excellence.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity', 'Wisdom'], 'benefits': '**Ability Score Increase.** Increase your Strength, Dexterity, or Wisdom score by 1, to a maximum of 20.\n\n**Mounted Strike.** You have Advantage on melee attack rolls against an unmounted creature smaller than your mount.\n\n**Veer.** As a Reaction when your mount is targeted by an attack while you are riding it, you can swap targets with the mount.\n\n**Leap Aside.** If your mount is subjected to an effect that allows it to make a Dex save for half damage, it instead takes no damage on a success and only half on a failure.'}),
      packEntity(slug: 'feat', name: 'Observant', description: 'Your senses are unusually sharp.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom'], 'benefits': '**Ability Score Increase.** Increase your Intelligence or Wisdom score by 1, to a maximum of 20.\n\n**Quick Search.** You can take the Search action as a Bonus Action.\n\n**Lipreading.** If you can see a creature\'s mouth while it is speaking a language you understand, you can interpret what it\'s saying.\n\n**Passive Bonuses.** You gain a +5 bonus to your Passive Perception and Passive Investigation.'}),
      packEntity(slug: 'feat', name: 'Polearm Master', description: 'You wield polearms with deadly precision.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Bonus Attack.** When you take the Attack action and attack with only a Glaive, Halberd, Pike, or Quarterstaff, you can use a Bonus Action to make a melee attack with the opposite end (deals 1d4 Bludgeoning damage).\n\n**Reaction Strike.** While wielding a Glaive, Halberd, Pike, or Quarterstaff, you can take an Opportunity Attack when a creature enters your reach.'}),
      packEntity(slug: 'feat', name: 'Resilient', description: 'You gain proficiency in saves with one ability.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': true, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity', 'Constitution', 'Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 20.\n\n**Save Proficiency.** You gain proficiency in saving throws made with the chosen ability.\n\n**Repeatable.** You can take this feat more than once, but you must choose a different ability each time.'}),
      packEntity(slug: 'feat', name: 'Ritual Caster', description: 'You learn rituals from any class.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Intelligence or Wisdom 13+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom'], 'benefits': '**Ability Score Increase.** Increase your Intelligence or Wisdom score by 1, to a maximum of 20.\n\n**Ritual Book.** You have a Ritual Book holding two level 1 spells with the Ritual tag. Choose any class\'s spell list. The chosen ability is your spellcasting ability for these spells.\n\n**Adding Rituals to the Book.** When you find a spell with the Ritual tag, you can add it to your book if its level is no more than half your character level (rounded up) and you spend 2 hours and 50 GP per level of the spell to copy it.'}),
      packEntity(slug: 'feat', name: 'Sentinel', description: 'You guard your allies with martial precision.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Stop the Foe.** When you hit a creature with an Opportunity Attack, the creature\'s Speed becomes 0 for the rest of the turn.\n\n**Bonus Opportunity Attacks.** Creatures provoke Opportunity Attacks from you even if they take the Disengage action before leaving your reach.\n\n**Distract the Foe.** When a creature within 5 feet of you makes an attack against a target other than you (and that target doesn\'t have this feat), you can use your Reaction to make a melee weapon attack against the attacker.'}),
      packEntity(slug: 'feat', name: 'Shadow-Touched', description: 'You gain Invisibility and a level 1 Illusion or Necromancy spell.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Magical Gift.** You learn the Invisibility spell and one level 1 spell of your choice from the Illusion or Necromancy school. You can cast each of these spells without expending a spell slot once per Long Rest. You can also cast these spells using spell slots you have.'}),
      packEntity(slug: 'feat', name: 'Sharpshooter', description: 'You are deadly with ranged weapons.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Dexterity score by 1, to a maximum of 20.\n\n**Long Range.** Attacking at long range doesn\'t impose Disadvantage on your ranged weapon attacks.\n\n**Cover.** Your ranged weapon attacks ignore Half Cover and Three-Quarters Cover.\n\n**Bullseye.** Once on each of your turns when you hit a creature with a ranged weapon attack, you can deal an extra 1d10 damage.'}),
      packEntity(slug: 'feat', name: 'Shield Master', description: 'You wield a Shield with skill, gaining bonus actions and reactions.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; proficiency with Shields', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength'], 'benefits': '**Ability Score Increase.** Increase your Strength score by 1, to a maximum of 20.\n\n**Shield Bash.** If you take the Attack action on your turn and are holding a Shield, you can use a Bonus Action to try to shove a creature within 5 feet of you with the Shield. The target must succeed on a Strength save or take 2d4 Bludgeoning damage and have the Prone condition, your choice.\n\n**Interpose Shield.** If you are subjected to an effect that allows you to make a Dex save to take only half damage, you can use your Reaction to take no damage if you succeed on the save and only half on a failure, provided you are wielding a Shield.'}),
      packEntity(slug: 'feat', name: 'Skill Expert', description: 'Your skills become more refined.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': true, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity', 'Constitution', 'Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase one ability score of your choice by 1, to a maximum of 20.\n\n**Skill Proficiency.** You gain proficiency in one skill of your choice.\n\n**Expertise.** Choose one skill in which you have proficiency but lack Expertise. You gain Expertise with that skill.'}),
      packEntity(slug: 'feat', name: 'Spell Sniper', description: 'You strike with magical precision at range.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Spellcasting Feature', 'prereq_requires_spellcasting': true, 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Spell Range.** When you cast a spell that requires you to make an attack roll, the spell\'s range is doubled.\n\n**Cover.** Your ranged spell attacks ignore Half Cover and Three-Quarters Cover.\n\n**Cantrip.** You learn one cantrip that requires an attack roll. Choose the cantrip from the spell list of any class.'}),
      packEntity(slug: 'feat', name: 'Telekinetic', description: 'You move objects with your mind.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Cantrip.** You learn the Mage Hand cantrip, except it is invisible and the hand has a range of 30 feet.\n\n**Telekinetic Shove.** As a Bonus Action, you can try to telekinetically shove one creature within 30 feet of you. The target must succeed on a Strength save or be moved 5 feet toward you or away from you.'}),
      packEntity(slug: 'feat', name: 'Telepathic', description: 'You communicate with others mind-to-mind.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Telepathic Speech.** You can speak telepathically to any creature you can see within 60 feet. You don\'t need to share a language with the creature for it to understand.\n\n**Detect Thoughts.** You can cast Detect Thoughts once per Long Rest without expending a spell slot.'}),
      packEntity(slug: 'feat', name: 'War Caster', description: 'You\'ve practiced casting in the chaos of battle.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+; Spellcasting Feature', 'prereq_requires_spellcasting': true, 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Intelligence', 'Wisdom', 'Charisma'], 'benefits': '**Ability Score Increase.** Increase your Intelligence, Wisdom, or Charisma score by 1, to a maximum of 20.\n\n**Concentration.** You have Advantage on saving throws to maintain Concentration.\n\n**Reactive Spell.** When a creature provokes an Opportunity Attack from you, you can take that Reaction to cast a spell at the creature rather than make a melee attack. The spell must have a casting time of Action and target only that creature.'}),
      packEntity(slug: 'feat', name: 'Weapon Master', description: 'You hone proficiency with several weapons.', attributes: {'category_ref': 'General', 'prereq_min_character_level': 4, 'prerequisite': 'Level 4+', 'repeatable': false, 'asi_amount': 1, 'asi_max_score': 20, 'asi_ability_options': ['Strength', 'Dexterity'], 'benefits': '**Ability Score Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n**Weapon Training.** You gain proficiency with four weapons of your choice.'}),

      // ─── More Fighting Style Feats ──────────────────────────────────────
      packEntity(slug: 'feat', name: 'Blind Fighting', description: 'You can fight without sight.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'You have Blindsight with a range of 10 feet. Within that range, you can effectively see anything that isn\'t behind Total Cover, even if you have the Blinded condition or are in Darkness. Moreover, in that range you can see a creature that is Invisible.'}),
      packEntity(slug: 'feat', name: 'Dueling', description: 'You wield a one-handed weapon with finesse.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.'}),
      packEntity(slug: 'feat', name: 'Interception', description: 'You protect allies from incoming attacks.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'When a creature you can see hits a target, other than you, within 5 feet of you with an attack roll, you can use your Reaction to reduce the damage the target takes by 1d10 + your Proficiency Bonus (to a minimum of 0 damage). You must be wielding a Shield or a Simple or Martial weapon to use this Reaction.'}),
      packEntity(slug: 'feat', name: 'Protection', description: 'You impose Disadvantage on attacks against allies.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'When a creature you can see attacks a target other than you that is within 5 feet of you, you can use your Reaction to impose Disadvantage on the attack roll. You must be wielding a Shield.'}),
      packEntity(slug: 'feat', name: 'Thrown Weapon Fighting', description: 'You hurl weapons with deadly skill.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'You can draw a weapon that has the Thrown property as part of the attack you make with the weapon. In addition, when you hit with a ranged attack using a Thrown weapon, you gain a +2 bonus to the damage roll.'}),
      packEntity(slug: 'feat', name: 'Unarmed Fighting', description: 'Your unarmed strikes deal more damage.', attributes: {'category_ref': 'Fighting Style', 'repeatable': false, 'benefits': 'Your Unarmed Strikes use a d6 for damage. The d6 becomes a d8 if you hit with the Unarmed Strike and aren\'t wielding any weapons or a Shield. When you Grapple a creature with your Unarmed Strike, you can deal Bludgeoning damage to the Grappled target equal to your Strength modifier.'}),
    ];
