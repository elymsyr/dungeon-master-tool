// SRD 5.2.1 Monsters A–Z (pp. 258–343). Canonical sample shipped here:
// Aboleth (legendary), Goblin Warrior, Skeleton, Zombie, Giant Spider.
// Full pass over the remaining ~215 stat blocks is deferred — see plan.

import '_helpers.dart';

List<Map<String, dynamic>> srdMonsters() => [
      // ─── Aboleth (CR 10) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Aboleth',
        description:
            'An ancient aberration that lurks in lightless seas and underground lakes. The aboleth despises all other intelligent life and uses its psychic abilities to enslave them. Once a creature is enslaved by the aboleth, it can\'t willingly disobey the aboleth\'s telepathic commands.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Lawful Evil',
          'ac': 17,
          'initiative_modifier': 4,
          'initiative_score': 14,
          'hp_average': 150,
          'hp_dice': '20d10+40',
          'speed_walk_ft': 10,
          'speed_swim_ft': 40,
          'stat_block': {
            'STR': 21, 'DEX': 9, 'CON': 15, 'INT': 18, 'WIS': 15, 'CHA': 18,
          },
          'cr': '10',
          'xp': 5900,
          'proficiency_bonus': 4,
          'passive_perception': 16,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Deep Speech')],
          'telepathy_ft': 120,
          'condition_immunity_refs': [lookup('condition', 'Prone')],
          'trait_refs': [
            ref('trait', 'Amphibious'),
            ref('trait', 'Aboleth Telepathy'),
            ref('trait', 'Eldritch Restoration'),
            ref('trait', 'Legendary Resistance (3/Day)'),
            ref('trait', 'Mucous Cloud'),
            ref('trait', 'Probing Telepathy'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Tentacle (Aboleth)'),
            ref('creature-action', 'Psychic Drain'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Tail Swipe'),
            ref('creature-action', 'Psychic Slash'),
          ],
        },
      ),

      // ─── Goblin Warrior (CR 1/4) ────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Goblin Warrior',
        description:
            'A small, sneaky humanoid that lives in dark places. Goblins band together in raucous warbands.',
        attributes: {
          'size_ref': 'Small',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(goblinoid)',
          'alignment_ref': 'Chaotic Neutral',
          'ac': 12,
          'initiative_modifier': 2,
          'initiative_score': 12,
          'hp_average': 7,
          'hp_dice': '2d6',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 8, 'DEX': 14, 'CON': 10, 'INT': 10, 'WIS': 8, 'CHA': 8,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 9,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'language_refs': [
            lookup('language', 'Common'),
            lookup('language', 'Goblin'),
          ],
          'action_refs': [
            ref('creature-action', 'Scimitar (Goblin)'),
            ref('creature-action', 'Shortbow (Goblin)'),
          ],
          'bonus_action_refs': [
            ref('creature-action', 'Nimble Escape'),
          ],
        },
      ),

      // ─── Skeleton (CR 1/4) ──────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Skeleton',
        description:
            'A ghastly thing of bones, animated by dark magic. Skeletons lurk in old tombs and ruins, awaiting the bidding of their masters.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Lawful Evil',
          'ac': 13,
          'initiative_modifier': 3,
          'initiative_score': 13,
          'hp_average': 13,
          'hp_dice': '2d8+4',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 10, 'DEX': 16, 'CON': 15, 'INT': 6, 'WIS': 8, 'CHA': 5,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 9,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'vulnerability_refs': [lookup('damage-type', 'Bludgeoning')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Poisoned'),
          ],
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Shortsword (Skeleton)'),
            ref('creature-action', 'Shortbow (Skeleton)'),
          ],
        },
      ),

      // ─── Zombie (CR 1/4) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Zombie',
        description:
            'A reanimated corpse, slow and relentless. Zombies serve necromancers and vile priests as cheap labor and front-line fodder.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Neutral Evil',
          'ac': 8,
          'initiative_modifier': -2,
          'initiative_score': 8,
          'hp_average': 22,
          'hp_dice': '3d8+9',
          'speed_walk_ft': 20,
          'stat_block': {
            'STR': 13, 'DEX': 6, 'CON': 16, 'INT': 3, 'WIS': 6, 'CHA': 5,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 8,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [lookup('condition', 'Poisoned')],
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Undead Fortitude')],
          'action_refs': [
            ref('creature-action', 'Slam (Zombie)'),
          ],
        },
      ),

      // ─── Adult Red Dragon (CR 17) ───────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Adult Red Dragon',
        description:
            'A colossal scarlet wyrm whose mere presence radiates menace. Adult red dragons are the most fearsome of true dragons, ruling vast volcanic territories and hoarding mountains of treasure beneath their caves.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Dragon'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 19,
          'initiative_modifier': 12,
          'initiative_score': 22,
          'hp_average': 256,
          'hp_dice': '19d12+133',
          'speed_walk_ft': 40,
          'speed_climb_ft': 40,
          'speed_fly_ft': 80,
          'stat_block': {
            'STR': 27, 'DEX': 10, 'CON': 25, 'INT': 16, 'WIS': 13, 'CHA': 21,
          },
          'cr': '17',
          'xp': 18000,
          'proficiency_bonus': 6,
          'passive_perception': 23,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [
            lookup('language', 'Common'),
            lookup('language', 'Draconic'),
          ],
          'damage_immunity_refs': [lookup('damage-type', 'Fire')],
          'trait_refs': [
            ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Rend (Adult Red Dragon)'),
            ref('creature-action', 'Fire Breath'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Commanding Presence'),
            ref('creature-action', 'Frightful Presence'),
            ref('creature-action', 'Tail Attack'),
          ],
        },
      ),

      // ─── Lich (CR 21) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Lich',
        description:
            'An archmage who has cheated death by binding their soul to a phylactery. Liches pursue secrets of magic across centuries, undeterred by the loss of their flesh.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Neutral Evil',
          'ac': 20,
          'initiative_modifier': 10,
          'initiative_score': 20,
          'hp_average': 315,
          'hp_dice': '38d8+152',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 11, 'DEX': 16, 'CON': 18, 'INT': 21, 'WIS': 14, 'CHA': 16,
          },
          'cr': '21',
          'xp': 33000,
          'proficiency_bonus': 7,
          'passive_perception': 19,
          'senses': [
            {'sense': 'Truesight', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Common')],
          'resistance_refs': [
            lookup('damage-type', 'Cold'),
            lookup('damage-type', 'Lightning'),
            lookup('damage-type', 'Necrotic'),
          ],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [
            ref('trait', 'Legendary Resistance (3/Day)'),
            ref('trait', 'Spellcasting (Lich)'),
            ref('trait', 'Rejuvenation'),
            ref('trait', 'Turn Resistance'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Eldritch Burst'),
            ref('creature-action', 'Paralyzing Touch'),
          ],
          'legendary_action_uses': 3,
        },
      ),

      // ─── Beholder (CR 13) ───────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Beholder',
        description:
            'A floating spheroid aberration with a great central eye and ten smaller eyes on stalks, each producing a different magical ray. Beholders are paranoid masters of underground lairs.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Lawful Evil',
          'ac': 18,
          'initiative_modifier': 6,
          'initiative_score': 16,
          'hp_average': 180,
          'hp_dice': '19d10+76',
          'speed_walk_ft': 0,
          'speed_fly_ft': 20,
          'stat_block': {
            'STR': 10, 'DEX': 14, 'CON': 18, 'INT': 17, 'WIS': 15, 'CHA': 17,
          },
          'cr': '13',
          'xp': 10000,
          'proficiency_bonus': 5,
          'passive_perception': 22,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [
            lookup('language', 'Deep Speech'),
            lookup('language', 'Undercommon'),
          ],
          'condition_immunity_refs': [lookup('condition', 'Prone')],
          'trait_refs': [
            ref('trait', 'Antimagic Cone'),
            ref('trait', 'Legendary Resistance (3/Day)'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Beholder)'),
            ref('creature-action', 'Eye Rays'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Eye Ray (Lair)'),
          ],
        },
      ),

      // ─── Mind Flayer (CR 7) ─────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Mind Flayer',
        description:
            'A four-tentacled humanoid aberration with a head like a violet octopus. Mind flayers feed on the brains of sapient creatures and rule subterranean colonies through psychic enslavement.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Lawful Evil',
          'ac': 15,
          'initiative_modifier': 4,
          'initiative_score': 14,
          'hp_average': 75,
          'hp_dice': '10d8+30',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 11, 'DEX': 12, 'CON': 16, 'INT': 19, 'WIS': 17, 'CHA': 17,
          },
          'cr': '7',
          'xp': 2900,
          'proficiency_bonus': 3,
          'passive_perception': 17,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [
            lookup('language', 'Deep Speech'),
            lookup('language', 'Undercommon'),
          ],
          'telepathy_ft': 120,
          'trait_refs': [
            ref('trait', 'Creature Sense'),
            ref('trait', 'Magic Resistance (MF)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Tentacles'),
            ref('creature-action', 'Mind Blast'),
            ref('creature-action', 'Extract Brain'),
          ],
        },
      ),

      // ─── Ogre (CR 2) ────────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Ogre',
        description:
            'A hulking, dim-witted giant that pillages, kidnaps, and devours. Ogres revere strength and cruelty above all else.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Giant'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 11,
          'initiative_modifier': -1,
          'initiative_score': 9,
          'hp_average': 68,
          'hp_dice': '8d10+24',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 19, 'DEX': 8, 'CON': 16, 'INT': 5, 'WIS': 7, 'CHA': 7,
          },
          'cr': '2',
          'xp': 450,
          'proficiency_bonus': 2,
          'passive_perception': 8,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'language_refs': [
            lookup('language', 'Common'),
            lookup('language', 'Giant'),
          ],
          'action_refs': [
            ref('creature-action', 'Greatclub'),
            ref('creature-action', 'Javelin (Ogre)'),
          ],
        },
      ),

      // ─── Owlbear (CR 3) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Owlbear',
        description:
            'A monstrous predator with the body of a bear and the head and feathers of an owl. Owlbears are fierce, territorial, and impossible to tame.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Unaligned',
          'ac': 13,
          'initiative_modifier': 1,
          'initiative_score': 11,
          'hp_average': 59,
          'hp_dice': '7d10+21',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 20, 'DEX': 12, 'CON': 17, 'INT': 3, 'WIS': 12, 'CHA': 7,
          },
          'cr': '3',
          'xp': 700,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'trait_refs': [ref('trait', 'Keen Sight and Smell')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Beak (Owlbear)'),
            ref('creature-action', 'Claws (Owlbear)'),
          ],
        },
      ),

      // ─── Hobgoblin Warrior (CR 1/2) ─────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Hobgoblin Warrior',
        description:
            'A martial humanoid that wages war with disciplined precision. Hobgoblin warbands operate as professional soldiers under strict chains of command.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(goblinoid)',
          'alignment_ref': 'Lawful Evil',
          'ac': 18,
          'initiative_modifier': 1,
          'initiative_score': 11,
          'hp_average': 11,
          'hp_dice': '2d8+2',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 13, 'DEX': 12, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 9,
          },
          'cr': '1/2',
          'xp': 100,
          'proficiency_bonus': 2,
          'passive_perception': 10,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'language_refs': [
            lookup('language', 'Common'),
            lookup('language', 'Goblin'),
          ],
          'trait_refs': [ref('trait', 'Martial Advantage')],
          'action_refs': [
            ref('creature-action', 'Longsword (Hobgoblin)'),
            ref('creature-action', 'Longbow (Hobgoblin)'),
          ],
        },
      ),

      // ─── Bandit (CR 1/8) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Bandit',
        description:
            'A brigand who haunts roads and ruins, preying on travelers. Bandits work in gangs led by a captain or thug.',
        attributes: {
          'size_ref': 'Small',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Chaotic Neutral',
          'ac': 12,
          'initiative_modifier': 1,
          'initiative_score': 11,
          'hp_average': 11,
          'hp_dice': '2d8+2',
          'speed_walk_ft': 30,
          'stat_block': {
            'STR': 11, 'DEX': 12, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 10,
          },
          'cr': '1/8',
          'xp': 25,
          'proficiency_bonus': 2,
          'passive_perception': 10,
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Scimitar (Bandit)'),
            ref('creature-action', 'Light Crossbow (Bandit)'),
          ],
        },
      ),

      // ─── Giant Spider (CR 1) ────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Giant Spider',
        description:
            'A horse-sized arachnid that lurks in caves, jungle canopies, and the corners of haunted ruins. Its venom paralyzes prey.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': 'Unaligned',
          'ac': 14,
          'initiative_modifier': 3,
          'initiative_score': 13,
          'hp_average': 26,
          'hp_dice': '4d10+4',
          'speed_walk_ft': 30,
          'speed_climb_ft': 30,
          'stat_block': {
            'STR': 14, 'DEX': 16, 'CON': 12, 'INT': 2, 'WIS': 11, 'CHA': 4,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 10,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 10},
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Spider Climb'),
            ref('trait', 'Web Sense'),
            ref('trait', 'Web Walker'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Giant Spider)'),
            ref('creature-action', 'Web (Giant Spider)'),
          ],
        },
      ),

      // ─── Kobold (CR 1/8) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Kobold Warrior',
        description: 'A small reptilian humanoid that lives in tribes and traps. Kobolds favor ambushes and mob attacks.',
        attributes: {
          'size_ref': 'Small',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(kobold)',
          'alignment_ref': 'Lawful Evil',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 5, 'hp_dice': '2d6-2', 'speed_walk_ft': 30,
          'stat_block': {'STR': 7, 'DEX': 15, 'CON': 9, 'INT': 8, 'WIS': 7, 'CHA': 8},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 8,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')],
          'trait_refs': [ref('trait', 'Pack Tactics'), ref('trait', 'Sunlight Sensitivity')],
          'action_refs': [
            ref('creature-action', 'Dagger (Kobold)'),
            ref('creature-action', 'Sling (Kobold)'),
          ],
        },
      ),

      // ─── Orc (CR 1/2) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Orc',
        description: 'A bestial humanoid raider, savage and warlike. Orcs roam in war bands and worship gods of conquest.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 15, 'hp_dice': '2d8+6', 'speed_walk_ft': 30,
          'stat_block': {'STR': 16, 'DEX': 12, 'CON': 16, 'INT': 7, 'WIS': 11, 'CHA': 10},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Orc')],
          'trait_refs': [ref('trait', 'Aggressive')],
          'action_refs': [
            ref('creature-action', 'Greataxe (Orc)'),
            ref('creature-action', 'Javelin (Orc)'),
          ],
        },
      ),

      // ─── Gnoll (CR 1/2) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Gnoll',
        description: 'A vicious hyena-headed humanoid that hunts in packs and feasts on the slain.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Fiend'),
          'tags_line': '(gnoll)',
          'alignment_ref': 'Chaotic Evil',
          'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 14, 'DEX': 12, 'CON': 11, 'INT': 6, 'WIS': 10, 'CHA': 7},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Abyssal')],
          'action_refs': [
            ref('creature-action', 'Bite (Gnoll)'),
            ref('creature-action', 'Spear (Gnoll)'),
          ],
        },
      ),

      // ─── Bugbear (CR 1) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Bugbear Warrior',
        description: 'A stealthy goblinoid brute that strikes from ambush. Bugbears combine size with cunning.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(goblinoid)',
          'alignment_ref': 'Chaotic Evil',
          'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 27, 'hp_dice': '5d8+5', 'speed_walk_ft': 30,
          'stat_block': {'STR': 15, 'DEX': 14, 'CON': 13, 'INT': 8, 'WIS': 11, 'CHA': 9},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Goblin')],
          'action_refs': [
            ref('creature-action', 'Morningstar (Bugbear)'),
            ref('creature-action', 'Javelin (Bugbear)'),
          ],
        },
      ),

      // ─── Drow (CR 1/4) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Drow',
        description: 'A black-skinned, white-haired elf of the Underdark, schooled in stealth, poison, and cruel magic.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(elf)',
          'alignment_ref': 'Neutral Evil',
          'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 10, 'DEX': 14, 'CON': 10, 'INT': 11, 'WIS': 11, 'CHA': 12},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'language_refs': [lookup('language', 'Elvish'), lookup('language', 'Undercommon')],
          'trait_refs': [
            ref('trait', 'Fey Ancestry'),
            ref('trait', 'Sunlight Sensitivity'),
            ref('trait', 'Innate Spellcasting (Drow)'),
          ],
          'action_refs': [
            ref('creature-action', 'Rapier (Drow)'),
            ref('creature-action', 'Hand Crossbow (Drow)'),
          ],
        },
      ),

      // ─── Werewolf (CR 3) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Werewolf',
        description: 'A humanoid cursed with lycanthropy, transforming under the moon into a savage wolf-beast.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(human, shapechanger)',
          'alignment_ref': 'Chaotic Evil',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 58, 'hp_dice': '9d8+18', 'speed_walk_ft': 30,
          'stat_block': {'STR': 15, 'DEX': 13, 'CON': 14, 'INT': 10, 'WIS': 11, 'CHA': 10},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 14,
          'language_refs': [lookup('language', 'Common')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'trait_refs': [
            ref('trait', 'Shapechanger (Werewolf)'),
            ref('trait', 'Keen Hearing'),
            ref('trait', 'Keen Smell'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Werewolf)'),
            ref('creature-action', 'Claws (Werewolf)'),
          ],
        },
      ),

      // ─── Troll (CR 5) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Troll',
        description: 'A gangly, rubbery-skinned giant whose flesh regenerates from wounds unless seared with fire or acid.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Giant'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 15, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 84, 'hp_dice': '8d10+40', 'speed_walk_ft': 30,
          'stat_block': {'STR': 18, 'DEX': 13, 'CON': 20, 'INT': 7, 'WIS': 9, 'CHA': 7},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 12,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Giant')],
          'trait_refs': [
            ref('trait', 'Keen Smell'),
            ref('trait', 'Regeneration'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Troll)'),
            ref('creature-action', 'Claws (Troll)'),
          ],
        },
      ),

      // ─── Hydra (CR 8) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Hydra',
        description: 'A serpentine monstrosity with five heads. When one is severed, two grow in its place unless cauterized.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Unaligned',
          'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 172, 'hp_dice': '15d12+75', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 20, 'DEX': 12, 'CON': 20, 'INT': 2, 'WIS': 10, 'CHA': 7},
          'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 16,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'trait_refs': [
            ref('trait', 'Hold Breath'),
            ref('trait', 'Multiple Heads'),
            ref('trait', 'Reactive Heads'),
            ref('trait', 'Wakeful'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Hydra)'),
          ],
        },
      ),

      // ─── Vampire (CR 13) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Vampire',
        description: 'An undead lord that drinks the blood of the living. Vampires command the night, with shapechanging powers and dread mental dominance.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Lawful Evil',
          'ac': 16, 'initiative_modifier': 4, 'initiative_score': 14,
          'hp_average': 144, 'hp_dice': '17d8+68', 'speed_walk_ft': 30,
          'stat_block': {'STR': 18, 'DEX': 18, 'CON': 18, 'INT': 17, 'WIS': 15, 'CHA': 18},
          'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 17,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'language_refs': [lookup('language', 'Common')],
          'resistance_refs': [
            lookup('damage-type', 'Necrotic'),
          ],
          'trait_refs': [
            ref('trait', 'Legendary Resistance (3/Day)'),
            ref('trait', 'Regeneration'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Vampire Bite'),
            ref('creature-action', 'Charm (Vampire)'),
          ],
          'legendary_action_uses': 3,
        },
      ),

      // ─── Balor (CR 19) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Balor',
        description: 'A massive demon wreathed in flame, wielding a flaming whip and a lightning sword. The most fearsome of the demons that haunt the Abyss.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Fiend'),
          'tags_line': '(demon)',
          'alignment_ref': 'Chaotic Evil',
          'ac': 19, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 262, 'hp_dice': '21d12+126', 'speed_walk_ft': 40, 'speed_fly_ft': 80,
          'stat_block': {'STR': 26, 'DEX': 15, 'CON': 22, 'INT': 20, 'WIS': 16, 'CHA': 22},
          'cr': '19', 'xp': 22000, 'proficiency_bonus': 6, 'passive_perception': 13,
          'senses': [{'sense': 'Truesight', 'range_ft': 120}],
          'language_refs': [lookup('language', 'Abyssal')],
          'telepathy_ft': 120,
          'damage_immunity_refs': [
            lookup('damage-type', 'Fire'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Cold'),
            lookup('damage-type', 'Lightning'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [
            ref('trait', 'Fire Aura'),
            ref('trait', 'Magic Resistance (Strong)'),
            ref('trait', 'Demonic Restoration'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Flame Whip (Balor)'),
            ref('creature-action', 'Lightning Sword (Balor)'),
          ],
        },
      ),

      // ─── Pit Fiend (CR 20) ──────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Pit Fiend',
        description: 'The supreme commanders of the Nine Hells\' armies. Pit fiends are devils of cunning malevolence and crushing power.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Fiend'),
          'tags_line': '(devil)',
          'alignment_ref': 'Lawful Evil',
          'ac': 19, 'initiative_modifier': 4, 'initiative_score': 14,
          'hp_average': 337, 'hp_dice': '27d10+189', 'speed_walk_ft': 30, 'speed_fly_ft': 60,
          'stat_block': {'STR': 26, 'DEX': 14, 'CON': 24, 'INT': 22, 'WIS': 18, 'CHA': 24},
          'cr': '20', 'xp': 25000, 'proficiency_bonus': 6, 'passive_perception': 14,
          'senses': [
            {'sense': 'Truesight', 'range_ft': 120},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Infernal')],
          'telepathy_ft': 120,
          'damage_immunity_refs': [
            lookup('damage-type', 'Fire'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Cold'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [
            ref('trait', 'Magic Resistance (Strong)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Pit Fiend)'),
          ],
        },
      ),

      // ─── Air Elemental (CR 5) ───────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Air Elemental',
        description: 'A whirling vortex of wind summoned from the Plane of Air, dissolving solid forms with raging gusts.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Elemental'),
          'alignment_ref': 'Neutral',
          'ac': 15, 'initiative_modifier': 5, 'initiative_score': 15,
          'hp_average': 90, 'hp_dice': '12d10+24', 'speed_walk_ft': 0, 'speed_fly_ft': 90,
          'stat_block': {'STR': 14, 'DEX': 20, 'CON': 14, 'INT': 6, 'WIS': 10, 'CHA': 6},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Primordial')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Poison'),
            lookup('damage-type', 'Lightning'),
            lookup('damage-type', 'Thunder'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Unconscious'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Slam (Air Elemental)'),
          ],
        },
      ),

      // ─── Earth Elemental (CR 5) ─────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Earth Elemental',
        description: 'A walking mass of stone and earth from the Plane of Earth, slow but devastating in its blows.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Elemental'),
          'alignment_ref': 'Neutral',
          'ac': 17, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 126, 'hp_dice': '12d10+60', 'speed_walk_ft': 30, 'speed_burrow_ft': 30,
          'stat_block': {'STR': 20, 'DEX': 8, 'CON': 20, 'INT': 5, 'WIS': 10, 'CHA': 5},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
            {'sense': 'Tremorsense', 'range_ft': 60},
          ],
          'language_refs': [lookup('language', 'Primordial')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Unconscious'),
          ],
          'trait_refs': [ref('trait', 'Earth Glide'), ref('trait', 'Siege Monster')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Slam (Earth Elemental)'),
          ],
        },
      ),

      // ─── Fire Elemental (CR 5) ──────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Fire Elemental',
        description: 'A mass of writhing flame summoned from the Elemental Plane of Fire, igniting all it touches.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Elemental'),
          'alignment_ref': 'Neutral',
          'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 102, 'hp_dice': '12d10+36', 'speed_walk_ft': 50,
          'stat_block': {'STR': 10, 'DEX': 17, 'CON': 16, 'INT': 6, 'WIS': 10, 'CHA': 7},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Primordial')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Fire'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Unconscious'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Touch (Fire Elemental)'),
          ],
        },
      ),

      // ─── Water Elemental (CR 5) ─────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Water Elemental',
        description: 'A torrent of conscious water summoned from the Elemental Plane of Water, drowning enemies in its grip.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Elemental'),
          'alignment_ref': 'Neutral',
          'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 114, 'hp_dice': '12d10+48', 'speed_walk_ft': 30, 'speed_swim_ft': 90,
          'stat_block': {'STR': 18, 'DEX': 14, 'CON': 18, 'INT': 5, 'WIS': 10, 'CHA': 8},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Primordial')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'resistance_refs': [
            lookup('damage-type', 'Acid'),
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Unconscious'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Slam (Water Elemental)'),
          ],
        },
      ),

      // ─── Ghoul (CR 1) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Ghoul',
        description: 'A flesh-eating undead with a hunger for the dead and dying. Its claws can paralyze with a touch.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 13, 'DEX': 15, 'CON': 10, 'INT': 7, 'WIS': 10, 'CHA': 6},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Poisoned'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Ghoul)'),
            ref('creature-action', 'Claws (Ghoul)'),
          ],
        },
      ),

      // ─── Wight (CR 3) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Wight',
        description: 'A malevolent undead that drains the life from the living. Once a mortal who chose darkness over death.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Neutral Evil',
          'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 45, 'hp_dice': '6d8+18', 'speed_walk_ft': 30,
          'stat_block': {'STR': 15, 'DEX': 14, 'CON': 16, 'INT': 10, 'WIS': 13, 'CHA': 15},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 13,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'resistance_refs': [
            lookup('damage-type', 'Necrotic'),
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [ref('trait', 'Sunlight Sensitivity')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Life Drain'),
          ],
        },
      ),

      // ─── Specter (CR 1) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Specter',
        description: 'The incorporeal spirit of a soul filled with hatred for the living, draining life with its chilling touch.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 0, 'speed_fly_ft': 50,
          'stat_block': {'STR': 1, 'DEX': 14, 'CON': 11, 'INT': 10, 'WIS': 10, 'CHA': 11},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Necrotic'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Acid'),
            lookup('damage-type', 'Cold'),
            lookup('damage-type', 'Fire'),
            lookup('damage-type', 'Lightning'),
            lookup('damage-type', 'Thunder'),
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Unconscious'),
          ],
          'action_refs': [
            ref('creature-action', 'Life Drain (Specter)'),
          ],
        },
      ),

      // ─── Animated Armor (CR 1) ──────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Animated Armor',
        description: 'An empty suit of armor brought to life by magic, defending its master\'s home with relentless violence.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Construct'),
          'alignment_ref': 'Unaligned',
          'ac': 18, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 33, 'hp_dice': '6d8+6', 'speed_walk_ft': 25,
          'stat_block': {'STR': 14, 'DEX': 11, 'CON': 13, 'INT': 1, 'WIS': 3, 'CHA': 1},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 6,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
          ],
          'damage_immunity_refs': [
            lookup('damage-type', 'Poison'),
            lookup('damage-type', 'Psychic'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Blinded'),
            lookup('condition', 'Charmed'),
            lookup('condition', 'Deafened'),
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [ref('trait', 'False Appearance')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Slam (Animated Armor)'),
          ],
        },
      ),

      // ─── Stone Giant (CR 7) ─────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Stone Giant',
        description: 'A reclusive giant of mountain caverns, hurling boulders with uncanny precision.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Giant'),
          'alignment_ref': 'Neutral',
          'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 126, 'hp_dice': '11d12+55', 'speed_walk_ft': 40,
          'stat_block': {'STR': 23, 'DEX': 15, 'CON': 20, 'INT': 10, 'WIS': 12, 'CHA': 9},
          'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 14,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Giant')],
          'trait_refs': [ref('trait', 'Stone Camouflage')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Greatclub (Stone Giant)'),
            ref('creature-action', 'Rock (Stone Giant)'),
          ],
        },
      ),

      // ─── Hill Giant (CR 5) ──────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Hill Giant',
        description: 'A simple-minded brute that lumbers across hills and lowlands, smashing villages and herds for its supper.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Giant'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 13, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 105, 'hp_dice': '10d12+40', 'speed_walk_ft': 40,
          'stat_block': {'STR': 21, 'DEX': 8, 'CON': 19, 'INT': 5, 'WIS': 9, 'CHA': 6},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 12,
          'language_refs': [lookup('language', 'Giant')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Greatclub (Hill Giant)'),
            ref('creature-action', 'Rock (Hill Giant)'),
          ],
        },
      ),

      // ─── Manticore (CR 3) ───────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Manticore',
        description: 'A flying monstrosity with a lion\'s body, bat wings, a man\'s face, and a tail full of lethal spikes.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Lawful Evil',
          'ac': 14, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 68, 'hp_dice': '8d10+24', 'speed_walk_ft': 30, 'speed_fly_ft': 50,
          'stat_block': {'STR': 17, 'DEX': 16, 'CON': 17, 'INT': 7, 'WIS': 12, 'CHA': 8},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 11,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Manticore)'),
            ref('creature-action', 'Tail Spike'),
          ],
        },
      ),

      // ─── Minotaur (CR 3) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Minotaur',
        description: 'A bull-headed warrior bound to ancestral mazes. The minotaur charges its prey with deadly horns.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 76, 'hp_dice': '9d10+27', 'speed_walk_ft': 40,
          'stat_block': {'STR': 18, 'DEX': 11, 'CON': 16, 'INT': 6, 'WIS': 16, 'CHA': 9},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 17,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Abyssal')],
          'trait_refs': [ref('trait', 'Charge')],
          'action_refs': [
            ref('creature-action', 'Greataxe (Minotaur)'),
            ref('creature-action', 'Gore'),
          ],
        },
      ),

      // ─── Basilisk (CR 3) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Basilisk',
        description: 'An eight-legged reptilian monstrosity whose gaze can turn flesh to stone.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Unaligned',
          'ac': 15, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 52, 'hp_dice': '8d8+16', 'speed_walk_ft': 20,
          'stat_block': {'STR': 16, 'DEX': 8, 'CON': 15, 'INT': 2, 'WIS': 8, 'CHA': 7},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 9,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'action_refs': [
            ref('creature-action', 'Bite (Basilisk)'),
            ref('creature-action', 'Petrifying Gaze'),
          ],
        },
      ),

      // ─── Cockatrice (CR 1/2) ────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Cockatrice',
        description: 'A scaled rooster-like creature whose bite can slowly turn the living to stone.',
        attributes: {
          'size_ref': 'Small',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Unaligned',
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 22, 'hp_dice': '5d6+5', 'speed_walk_ft': 20, 'speed_fly_ft': 40,
          'stat_block': {'STR': 6, 'DEX': 12, 'CON': 12, 'INT': 2, 'WIS': 13, 'CHA': 5},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 11,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'action_refs': [
            ref('creature-action', 'Bite (Cockatrice)'),
          ],
        },
      ),

      // ─── Ettin (CR 4) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Ettin',
        description: 'A two-headed giant cousin to ogres, ill-tempered and always squabbling with itself.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Giant'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 12, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 85, 'hp_dice': '10d10+30', 'speed_walk_ft': 40,
          'stat_block': {'STR': 21, 'DEX': 8, 'CON': 17, 'INT': 6, 'WIS': 10, 'CHA': 8},
          'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 14,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Giant'), lookup('language', 'Orc')],
          'trait_refs': [ref('trait', 'Two Heads'), ref('trait', 'Wakeful')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Battleaxe (Ettin)'),
            ref('creature-action', 'Morningstar (Ettin)'),
          ],
        },
      ),

      // ─── Harpy (CR 1) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Harpy',
        description: 'A foul-tempered creature with a woman\'s torso and a vulture\'s wings. Its song lures victims to their doom.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 38, 'hp_dice': '7d8+7', 'speed_walk_ft': 20, 'speed_fly_ft': 40,
          'stat_block': {'STR': 12, 'DEX': 13, 'CON': 12, 'INT': 7, 'WIS': 10, 'CHA': 13},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10,
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Claws (Harpy)'),
            ref('creature-action', 'Luring Song'),
          ],
        },
      ),

      // ─── Will-o\'-Wisp (CR 2) ──────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Will-o\'-Wisp',
        description: 'A pale, glowing orb that drifts through swamps and battlefields, draining the life of those who follow.',
        attributes: {
          'size_ref': 'Tiny',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 19, 'initiative_modifier': 9, 'initiative_score': 19,
          'hp_average': 22, 'hp_dice': '9d4', 'speed_walk_ft': 0, 'speed_fly_ft': 50,
          'stat_block': {'STR': 1, 'DEX': 28, 'CON': 10, 'INT': 13, 'WIS': 14, 'CHA': 11},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'language_refs': [lookup('language', 'Common')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Lightning'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Acid'),
            lookup('damage-type', 'Cold'),
            lookup('damage-type', 'Fire'),
            lookup('damage-type', 'Necrotic'),
            lookup('damage-type', 'Thunder'),
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Poisoned'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Unconscious'),
          ],
          'action_refs': [
            ref('creature-action', 'Shock'),
          ],
        },
      ),

      // ─── Mummy (CR 3) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Mummy',
        description: 'An ancient corpse wrapped in funeral linen, animated by foul magic to guard a tomb or ruin.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': 'Lawful Evil',
          'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 58, 'hp_dice': '9d8+18', 'speed_walk_ft': 20,
          'stat_block': {'STR': 16, 'DEX': 8, 'CON': 15, 'INT': 6, 'WIS': 10, 'CHA': 12},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'vulnerability_refs': [lookup('damage-type', 'Fire')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Necrotic'),
            lookup('damage-type', 'Poison'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Poisoned'),
          ],
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Rotting Fist'),
            ref('creature-action', 'Dreadful Glare'),
          ],
        },
      ),

      // ─── Treant (CR 9) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Treant',
        description: 'An ancient awakened tree-being that protects forests and remembers all who pass beneath its branches.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Plant'),
          'alignment_ref': 'Chaotic Good',
          'ac': 16, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 138, 'hp_dice': '12d12+60', 'speed_walk_ft': 30,
          'stat_block': {'STR': 23, 'DEX': 8, 'CON': 21, 'INT': 12, 'WIS': 16, 'CHA': 12},
          'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 13,
          'language_refs': [
            lookup('language', 'Common'),
            lookup('language', 'Druidic'),
            lookup('language', 'Elvish'),
            lookup('language', 'Sylvan'),
          ],
          'vulnerability_refs': [lookup('damage-type', 'Fire')],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
          ],
          'trait_refs': [ref('trait', 'False Appearance'), ref('trait', 'Siege Monster')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Slam (Treant)'),
            ref('creature-action', 'Rock (Treant)'),
          ],
        },
      ),

      // ─── Adult Black Dragon (CR 14) ─────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Adult Black Dragon',
        description: 'A cruel chromatic dragon that dwells in fetid swamps and ruined keeps. Its breath is a deadly stream of acid.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Dragon'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 19, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 195, 'hp_dice': '17d12+85', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80,
          'stat_block': {'STR': 23, 'DEX': 14, 'CON': 21, 'INT': 14, 'WIS': 13, 'CHA': 17},
          'cr': '14', 'xp': 11500, 'proficiency_bonus': 5, 'passive_perception': 21,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')],
          'damage_immunity_refs': [lookup('damage-type', 'Acid')],
          'trait_refs': [
            ref('trait', 'Amphibious (Dragon)'),
            ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Adult Black Dragon)'),
            ref('creature-action', 'Claw (Adult Black Dragon)'),
            ref('creature-action', 'Acid Breath'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Tail (Adult Black Dragon)'),
            ref('creature-action', 'Wing Attack'),
            ref('creature-action', 'Frightful Presence (Dragon)'),
          ],
        },
      ),

      // ─── Adult Blue Dragon (CR 16) ──────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Adult Blue Dragon',
        description: 'A territorial chromatic dragon that rules deserts and arid plains. Its breath is a crackling line of lightning.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Dragon'),
          'alignment_ref': 'Lawful Evil',
          'ac': 19, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 225, 'hp_dice': '18d12+108', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_fly_ft': 80,
          'stat_block': {'STR': 25, 'DEX': 10, 'CON': 23, 'INT': 16, 'WIS': 15, 'CHA': 19},
          'cr': '16', 'xp': 15000, 'proficiency_bonus': 5, 'passive_perception': 22,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')],
          'damage_immunity_refs': [lookup('damage-type', 'Lightning')],
          'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Adult Blue Dragon)'),
            ref('creature-action', 'Claw (Adult Blue Dragon)'),
            ref('creature-action', 'Lightning Breath'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Tail (Adult Blue Dragon)'),
            ref('creature-action', 'Wing Attack'),
            ref('creature-action', 'Frightful Presence (Dragon)'),
          ],
        },
      ),

      // ─── Adult Green Dragon (CR 15) ─────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Adult Green Dragon',
        description: 'A cunning chromatic dragon of deep forests. Its poisonous breath corrupts everything it touches.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Dragon'),
          'alignment_ref': 'Lawful Evil',
          'ac': 19, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 207, 'hp_dice': '18d12+90', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80,
          'stat_block': {'STR': 23, 'DEX': 12, 'CON': 21, 'INT': 18, 'WIS': 15, 'CHA': 17},
          'cr': '15', 'xp': 13000, 'proficiency_bonus': 5, 'passive_perception': 22,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [lookup('condition', 'Poisoned')],
          'trait_refs': [
            ref('trait', 'Amphibious (Dragon)'),
            ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Adult Green Dragon)'),
            ref('creature-action', 'Claw (Adult Green Dragon)'),
            ref('creature-action', 'Poison Breath'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Tail (Adult Green Dragon)'),
            ref('creature-action', 'Wing Attack'),
            ref('creature-action', 'Frightful Presence (Dragon)'),
          ],
        },
      ),

      // ─── Adult White Dragon (CR 13) ─────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Adult White Dragon',
        description: 'A primitive chromatic dragon of glaciers and frozen peaks. Vicious and territorial.',
        attributes: {
          'size_ref': 'Huge',
          'creature_type_ref': lookup('creature-type', 'Dragon'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 18, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 200, 'hp_dice': '16d12+96', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_swim_ft': 40, 'speed_fly_ft': 80,
          'stat_block': {'STR': 22, 'DEX': 10, 'CON': 22, 'INT': 8, 'WIS': 12, 'CHA': 12},
          'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 21,
          'senses': [
            {'sense': 'Blindsight', 'range_ft': 60},
            {'sense': 'Darkvision', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')],
          'damage_immunity_refs': [lookup('damage-type', 'Cold')],
          'trait_refs': [
            ref('trait', 'Ice Walk'),
            ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Adult White Dragon)'),
            ref('creature-action', 'Claw (Adult White Dragon)'),
            ref('creature-action', 'Cold Breath'),
          ],
          'legendary_action_uses': 3,
          'legendary_action_refs': [
            ref('creature-action', 'Tail (Adult White Dragon)'),
            ref('creature-action', 'Wing Attack'),
            ref('creature-action', 'Frightful Presence (Dragon)'),
          ],
        },
      ),

      // ─── Chuul (CR 4) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Chuul',
        description: 'A horrid lobster-like aberration that lurks in submerged ruins serving ancient masters.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 16, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 76, 'hp_dice': '9d10+27', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 19, 'DEX': 10, 'CON': 16, 'INT': 5, 'WIS': 11, 'CHA': 5},
          'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 14,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Deep Speech')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'condition_immunity_refs': [lookup('condition', 'Poisoned')],
          'trait_refs': [
            ref('trait', 'Amphibious'),
            ref('trait', 'Sense Magic'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Pincer (Chuul)'),
          ],
          'bonus_action_refs': [ref('creature-action', 'Paralyzing Tentacles')],
        },
      ),

      // ─── Otyugh (CR 5) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Otyugh',
        description: 'A foul, three-legged aberration that lairs in middens, sewers, and refuse heaps.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Neutral',
          'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 114, 'hp_dice': '12d10+48', 'speed_walk_ft': 30,
          'stat_block': {'STR': 16, 'DEX': 11, 'CON': 19, 'INT': 6, 'WIS': 13, 'CHA': 6},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 17,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'language_refs': [lookup('language', 'Deep Speech')],
          'telepathy_ft': 120,
          'trait_refs': [ref('trait', 'Tentacles')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Otyugh)'),
            ref('creature-action', 'Tentacle (Otyugh)'),
          ],
        },
      ),

      // ─── Roper (CR 5) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Roper',
        description: 'A predatory aberration that perfectly mimics a stalagmite or stalactite, snaring prey with sticky tendrils.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Neutral Evil',
          'ac': 20, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 93, 'hp_dice': '11d10+33', 'speed_walk_ft': 10, 'speed_climb_ft': 10,
          'stat_block': {'STR': 18, 'DEX': 8, 'CON': 17, 'INT': 7, 'WIS': 16, 'CHA': 6},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 16,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'trait_refs': [
            ref('trait', 'False Appearance'),
            ref('trait', 'Spider Climb (Roper)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Roper)'),
            ref('creature-action', 'Tendril (Roper)'),
          ],
          'bonus_action_refs': [ref('creature-action', 'Reel In')],
        },
      ),

      // ─── Nothic (CR 2) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Nothic',
        description: 'A grotesque, one-eyed aberration cursed by failed magical ambition. It hoards arcane secrets.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': 'Neutral Evil',
          'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 45, 'hp_dice': '6d8+18', 'speed_walk_ft': 30,
          'stat_block': {'STR': 14, 'DEX': 16, 'CON': 16, 'INT': 13, 'WIS': 10, 'CHA': 8},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [
            {'sense': 'Truesight', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Undercommon')],
          'trait_refs': [ref('trait', 'Aversion to Light')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Claw (Nothic)'),
            ref('creature-action', 'Rotting Gaze'),
            ref('creature-action', 'Weird Insight'),
          ],
        },
      ),

      // ─── Dryad (CR 1) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Dryad',
        description: 'A fey spirit bound to a single tree. Beautiful and reclusive, dryads protect their forest homes.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Fey'),
          'alignment_ref': 'Neutral',
          'ac': 16, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 10, 'DEX': 12, 'CON': 11, 'INT': 14, 'WIS': 15, 'CHA': 18},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 14,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Elvish'), lookup('language', 'Sylvan')],
          'trait_refs': [
            ref('trait', 'Magic Resistance'),
            ref('trait', 'Speak with Beasts and Plants'),
            ref('trait', 'Tree Stride'),
          ],
          'action_refs': [
            ref('creature-action', 'Vine Whip (Dryad)'),
            ref('creature-action', 'Fey Charm'),
          ],
        },
      ),

      // ─── Gargoyle (CR 2) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Gargoyle',
        description: 'A grotesque stone-skinned elemental, often perched motionless on rooftops awaiting the chance to attack.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Elemental'),
          'alignment_ref': 'Chaotic Evil',
          'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 67, 'hp_dice': '9d8+27', 'speed_walk_ft': 30, 'speed_fly_ft': 60,
          'stat_block': {'STR': 15, 'DEX': 11, 'CON': 16, 'INT': 6, 'WIS': 11, 'CHA': 7},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'language_refs': [lookup('language', 'Primordial')],
          'damage_immunity_refs': [lookup('damage-type', 'Poison')],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Exhaustion'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Poisoned'),
          ],
          'trait_refs': [ref('trait', 'False Appearance (Gargoyle)')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Gargoyle)'),
            ref('creature-action', 'Claws (Gargoyle)'),
          ],
        },
      ),

      // ─── Couatl (CR 4) ──────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Couatl',
        description: 'A divine, feathered serpent — a benevolent celestial guardian created by the gods to watch over the world.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Celestial'),
          'alignment_ref': 'Lawful Good',
          'ac': 19, 'initiative_modifier': 5, 'initiative_score': 15,
          'hp_average': 60, 'hp_dice': '8d8+24', 'speed_walk_ft': 30, 'speed_fly_ft': 90,
          'stat_block': {'STR': 16, 'DEX': 20, 'CON': 17, 'INT': 18, 'WIS': 20, 'CHA': 18},
          'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 15,
          'senses': [
            {'sense': 'Truesight', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')],
          'telepathy_ft': 120,
          'damage_immunity_refs': [
            lookup('damage-type', 'Psychic'),
            lookup('damage-type', 'Radiant'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'trait_refs': [
            ref('trait', 'Shielded Mind'),
            ref('trait', 'Spell Resistance'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Couatl)'),
            ref('creature-action', 'Constrict (Couatl)'),
          ],
        },
      ),

      // ─── Sphinx of Lore / Wonder placeholder (CR 11 generic) ────────────
      packEntity(
        slug: 'monster',
        name: 'Sphinx',
        description: 'A guardian celestial with the body of a great cat and the head of a wise being. Sphinxes pose riddles to those they encounter.',
        attributes: {
          'size_ref': 'Large',
          'creature_type_ref': lookup('creature-type', 'Celestial'),
          'alignment_ref': 'Lawful Neutral',
          'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 199, 'hp_dice': '19d10+95', 'speed_walk_ft': 40, 'speed_fly_ft': 60,
          'stat_block': {'STR': 22, 'DEX': 10, 'CON': 20, 'INT': 16, 'WIS': 18, 'CHA': 23},
          'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 18,
          'senses': [
            {'sense': 'Truesight', 'range_ft': 120},
          ],
          'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')],
          'damage_immunity_refs': [
            lookup('damage-type', 'Necrotic'),
            lookup('damage-type', 'Radiant'),
          ],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Frightened'),
          ],
          'trait_refs': [
            ref('trait', 'Inscrutable'),
            ref('trait', 'Innate Spellcasting (Sphinx)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Claws (Sphinx)'),
            ref('creature-action', 'Roar (Sphinx)'),
          ],
        },
      ),

      // ─── Death Dog (CR 1) ───────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Death Dog',
        description: 'A two-headed dog that prowls deserts and ruins, infecting bite victims with a wasting disease.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Monstrosity'),
          'alignment_ref': 'Neutral Evil',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 39, 'hp_dice': '6d8+12', 'speed_walk_ft': 40,
          'stat_block': {'STR': 15, 'DEX': 14, 'CON': 14, 'INT': 3, 'WIS': 13, 'CHA': 6},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 15,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'trait_refs': [
            ref('trait', 'Pack Tactics (Death Dog)'),
            ref('trait', 'Two-Headed (Death Dog)'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Death Dog)'),
          ],
        },
      ),

      // ─── Knight (CR 3) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Knight',
        description: 'A heavily armored warrior bound by a code of chivalry to serve a noble lord, faith, or ideal.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Lawful Neutral',
          'ac': 18, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 52, 'hp_dice': '8d8+16', 'speed_walk_ft': 30,
          'stat_block': {'STR': 16, 'DEX': 11, 'CON': 14, 'INT': 11, 'WIS': 11, 'CHA': 15},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 12,
          'language_refs': [lookup('language', 'Common')],
          'condition_immunity_refs': [lookup('condition', 'Frightened')],
          'trait_refs': [ref('trait', 'Brave')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Greatsword (Knight)'),
            ref('creature-action', 'Heavy Crossbow (Knight)'),
          ],
          'bonus_action_refs': [ref('creature-action', 'Leadership')],
        },
      ),

      // ─── Veteran (CR 3) ────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Veteran',
        description: 'A seasoned mercenary fighter, hard-bitten and skilled with sword and crossbow.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral',
          'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 58, 'hp_dice': '9d8+18', 'speed_walk_ft': 30,
          'stat_block': {'STR': 16, 'DEX': 13, 'CON': 14, 'INT': 10, 'WIS': 11, 'CHA': 10},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 12,
          'language_refs': [lookup('language', 'Common')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Longsword (Veteran)'),
            ref('creature-action', 'Shortsword (Veteran)'),
            ref('creature-action', 'Heavy Crossbow (Veteran)'),
          ],
        },
      ),

      // ─── Gladiator (CR 5) ──────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Gladiator',
        description: 'A celebrated arena fighter — equal parts warrior, performer, and crowd-pleaser.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral',
          'ac': 16, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 112, 'hp_dice': '15d8+45', 'speed_walk_ft': 30,
          'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 10, 'WIS': 12, 'CHA': 15},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 11,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Brave')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Spear (Gladiator)'),
            ref('creature-action', 'Shield Bash'),
          ],
          'reaction_refs': [ref('creature-action', 'Parry')],
        },
      ),

      // ─── Mage (CR 6) ───────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Mage',
        description: 'A wizard versed in evocation and divination, often serving as advisor to nobles or kings.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral',
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 81, 'hp_dice': '18d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 9, 'DEX': 14, 'CON': 11, 'INT': 17, 'WIS': 12, 'CHA': 11},
          'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 11,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Spellcasting (Mage)')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Arcane Burst'),
          ],
        },
      ),

      // ─── Priest (CR 2) ─────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Priest',
        description: 'A devout cleric who serves a deity and ministers to a flock — and, when called upon, fights for the faith.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral',
          'ac': 13, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 38, 'hp_dice': '7d8+7', 'speed_walk_ft': 30,
          'stat_block': {'STR': 10, 'DEX': 10, 'CON': 12, 'INT': 13, 'WIS': 16, 'CHA': 13},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 13,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Spellcasting (Priest)')],
          'action_refs': [
            ref('creature-action', 'Mace (Priest)'),
            ref('creature-action', 'Radiance of the Dawn'),
          ],
        },
      ),

      // ─── Cult Fanatic (CR 2) ───────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Cult Fanatic',
        description: 'A zealous priest of a dark cause, willing to commit any atrocity in the name of their cause.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral Evil',
          'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 33, 'hp_dice': '6d8+6', 'speed_walk_ft': 30,
          'stat_block': {'STR': 11, 'DEX': 14, 'CON': 12, 'INT': 10, 'WIS': 13, 'CHA': 14},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Spellcasting (Cult Fanatic)')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Dagger (Fanatic)'),
          ],
        },
      ),

      // ─── Spy (CR 1) ────────────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Spy',
        description: 'An information-gatherer trained to deceive and infiltrate. Skilled in stealth and disguise.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral',
          'ac': 12, 'initiative_modifier': 4, 'initiative_score': 14,
          'hp_average': 27, 'hp_dice': '6d8', 'speed_walk_ft': 30,
          'stat_block': {'STR': 10, 'DEX': 15, 'CON': 10, 'INT': 12, 'WIS': 14, 'CHA': 16},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 16,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Cunning Action'), ref('trait', 'Sneak Attack')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Shortsword (Spy)'),
            ref('creature-action', 'Hand Crossbow (Spy)'),
          ],
        },
      ),

      // ─── Assassin (CR 8) ───────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Assassin',
        description: 'A trained killer schooled in stealth, poisons, and the precise placement of a blade.',
        attributes: {
          'size_ref': 'Medium',
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'alignment_ref': 'Neutral Evil',
          'ac': 15, 'initiative_modifier': 6, 'initiative_score': 16,
          'hp_average': 78, 'hp_dice': '12d8+24', 'speed_walk_ft': 30,
          'stat_block': {'STR': 11, 'DEX': 16, 'CON': 14, 'INT': 13, 'WIS': 11, 'CHA': 10},
          'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 13,
          'language_refs': [lookup('language', 'Common'), lookup('language', 'Thieves\' Cant')],
          'resistance_refs': [lookup('damage-type', 'Poison')],
          'trait_refs': [
            ref('trait', 'Cunning Action'),
            ref('trait', 'Evasion'),
            ref('trait', 'Sneak Attack'),
          ],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Shortsword (Assassin)'),
            ref('creature-action', 'Light Crossbow (Assassin)'),
          ],
        },
      ),
    ];
