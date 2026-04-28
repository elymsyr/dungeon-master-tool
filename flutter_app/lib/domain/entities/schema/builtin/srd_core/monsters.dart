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
          'bonus_action_refs': [ref('creature-action', 'Reel In (Roper)')],
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

      // ─── Gap closure: missing SRD 5.2.1 monsters ────────────────────────
      // Dragons: Wyrmlings (Medium, CR 1-3)
      packEntity(slug: 'monster', name: 'Black Dragon Wyrmling', description: 'A young black dragon, recently hatched. Cunning and cruel from birth.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 17, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 33, 'hp_dice': '6d8+6', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 14, 'CON': 13, 'INT': 10, 'WIS': 11, 'CHA': 13}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath')]}),
      packEntity(slug: 'monster', name: 'Blue Dragon Wyrmling', description: 'A young blue dragon, hatched in arid wastes.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 52, 'hp_dice': '8d8+16', 'speed_walk_ft': 30, 'speed_burrow_ft': 15, 'speed_fly_ft': 60, 'stat_block': {'STR': 17, 'DEX': 10, 'CON': 15, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath')]}),
      packEntity(slug: 'monster', name: 'Brass Dragon Wyrmling', description: 'A small metallic dragon prone to chatter.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 22, 'hp_dice': '4d8+4', 'speed_walk_ft': 30, 'speed_burrow_ft': 15, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 10, 'CON': 13, 'INT': 10, 'WIS': 11, 'CHA': 13}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Sleep Breath')]}),
      packEntity(slug: 'monster', name: 'Bronze Dragon Wyrmling', description: 'A young bronze dragon with a love for storms.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 32, 'hp_dice': '5d8+10', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 17, 'DEX': 10, 'CON': 15, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath'), ref('creature-action', 'Repulsion Breath')]}),
      packEntity(slug: 'monster', name: 'Copper Dragon Wyrmling', description: 'A copper-scaled trickster dragon.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 16, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 22, 'hp_dice': '4d8+4', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 12, 'CON': 13, 'INT': 14, 'WIS': 11, 'CHA': 13}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath'), ref('creature-action', 'Slowing Breath')]}),
      packEntity(slug: 'monster', name: 'Gold Dragon Wyrmling', description: 'The youngest and most regal of metallic dragons.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 60, 'hp_dice': '8d8+24', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 19, 'DEX': 14, 'CON': 17, 'INT': 14, 'WIS': 11, 'CHA': 16}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Weakening Breath')]}),
      packEntity(slug: 'monster', name: 'Green Dragon Wyrmling', description: 'A young green dragon, treacherous from hatching.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 38, 'hp_dice': '7d8+7', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 12, 'CON': 13, 'INT': 14, 'WIS': 11, 'CHA': 13}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Poison Breath')]}),
      packEntity(slug: 'monster', name: 'Red Dragon Wyrmling', description: 'A young red dragon brimming with arrogance and fire.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 75, 'hp_dice': '10d8+30', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 17, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath')]}),
      packEntity(slug: 'monster', name: 'Silver Dragon Wyrmling', description: 'A noble metallic dragon hatchling, kindly and curious.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 45, 'hp_dice': '6d8+18', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 17, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath'), ref('creature-action', 'Paralyzing Breath')]}),
      packEntity(slug: 'monster', name: 'White Dragon Wyrmling', description: 'A young white dragon, savage and slow-witted.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 16, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 32, 'hp_dice': '5d8+10', 'speed_walk_ft': 30, 'speed_burrow_ft': 15, 'speed_fly_ft': 60, 'speed_swim_ft': 30, 'stat_block': {'STR': 14, 'DEX': 10, 'CON': 14, 'INT': 5, 'WIS': 10, 'CHA': 11}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'action_refs': [ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath')]}),

      // Dragons: Young (Large, CR 5-10)
      packEntity(slug: 'monster', name: 'Young Black Dragon', description: 'An adolescent black dragon claiming a swamp lair.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 127, 'hp_dice': '15d10+45', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 19, 'DEX': 14, 'CON': 17, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath')]}),
      packEntity(slug: 'monster', name: 'Young Blue Dragon', description: 'An adolescent blue dragon ruling a desert canyon.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 152, 'hp_dice': '16d10+64', 'speed_walk_ft': 40, 'speed_burrow_ft': 20, 'speed_fly_ft': 80, 'stat_block': {'STR': 21, 'DEX': 10, 'CON': 19, 'INT': 14, 'WIS': 13, 'CHA': 17}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 17, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath')]}),
      packEntity(slug: 'monster', name: 'Young Brass Dragon', description: 'An adolescent brass dragon, garrulous and sociable.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 17, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 110, 'hp_dice': '13d10+39', 'speed_walk_ft': 40, 'speed_burrow_ft': 20, 'speed_fly_ft': 80, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 17, 'INT': 12, 'WIS': 11, 'CHA': 15}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Sleep Breath')]}),
      packEntity(slug: 'monster', name: 'Young Bronze Dragon', description: 'An adolescent bronze dragon, vigilant against evil.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 142, 'hp_dice': '15d10+60', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 21, 'DEX': 10, 'CON': 19, 'INT': 14, 'WIS': 13, 'CHA': 17}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 17, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath'), ref('creature-action', 'Repulsion Breath')]}),
      packEntity(slug: 'monster', name: 'Young Copper Dragon', description: 'An adolescent copper dragon prone to mischief.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 110, 'hp_dice': '13d10+39', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 19, 'DEX': 12, 'CON': 17, 'INT': 16, 'WIS': 13, 'CHA': 15}, 'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath'), ref('creature-action', 'Slowing Breath')]}),
      packEntity(slug: 'monster', name: 'Young Gold Dragon', description: 'An adolescent gold dragon of noble bearing.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 178, 'hp_dice': '17d10+85', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 23, 'DEX': 14, 'CON': 21, 'INT': 16, 'WIS': 13, 'CHA': 20}, 'cr': '10', 'xp': 5900, 'proficiency_bonus': 4, 'passive_perception': 17, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Weakening Breath')]}),
      packEntity(slug: 'monster', name: 'Young Green Dragon', description: 'An adolescent green dragon prowling primeval forests.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 5, 'initiative_score': 15, 'hp_average': 136, 'hp_dice': '16d10+48', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 19, 'DEX': 12, 'CON': 17, 'INT': 16, 'WIS': 13, 'CHA': 15}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Poison Breath')]}),
      packEntity(slug: 'monster', name: 'Young Red Dragon', description: 'An adolescent red dragon, prideful and brutal.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 178, 'hp_dice': '17d10+85', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 23, 'DEX': 10, 'CON': 21, 'INT': 14, 'WIS': 11, 'CHA': 19}, 'cr': '10', 'xp': 5900, 'proficiency_bonus': 4, 'passive_perception': 18, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath')]}),
      packEntity(slug: 'monster', name: 'Young Silver Dragon', description: 'An adolescent silver dragon, kindly and noble.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 168, 'hp_dice': '16d10+80', 'speed_walk_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 23, 'DEX': 10, 'CON': 21, 'INT': 14, 'WIS': 11, 'CHA': 19}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 17, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath'), ref('creature-action', 'Paralyzing Breath')]}),
      packEntity(slug: 'monster', name: 'Young White Dragon', description: 'An adolescent white dragon, savage hunter of frozen wastes.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 17, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 133, 'hp_dice': '14d10+56', 'speed_walk_ft': 40, 'speed_burrow_ft': 20, 'speed_fly_ft': 80, 'speed_swim_ft': 40, 'stat_block': {'STR': 18, 'DEX': 10, 'CON': 18, 'INT': 6, 'WIS': 11, 'CHA': 12}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath')]}),

      // Dragons: Adult metallic (Huge, CR 13-17). Adult chromatics already authored above.
      packEntity(slug: 'monster', name: 'Adult Brass Dragon', description: 'A garrulous metallic dragon ruling sun-baked deserts.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 18, 'initiative_modifier': 10, 'initiative_score': 20, 'hp_average': 172, 'hp_dice': '15d12+75', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_fly_ft': 80, 'stat_block': {'STR': 23, 'DEX': 10, 'CON': 21, 'INT': 14, 'WIS': 13, 'CHA': 17}, 'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 21, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Sleep Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Adult Bronze Dragon', description: 'A noble metallic dragon, defender of coastlines.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 19, 'initiative_modifier': 10, 'initiative_score': 20, 'hp_average': 212, 'hp_dice': '17d12+102', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 25, 'DEX': 10, 'CON': 23, 'INT': 16, 'WIS': 15, 'CHA': 19}, 'cr': '15', 'xp': 13000, 'proficiency_bonus': 5, 'passive_perception': 22, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath'), ref('creature-action', 'Repulsion Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Adult Copper Dragon', description: 'A trickster metallic dragon, master of sardonic humor.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 18, 'initiative_modifier': 9, 'initiative_score': 19, 'hp_average': 184, 'hp_dice': '16d12+80', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 23, 'DEX': 12, 'CON': 21, 'INT': 18, 'WIS': 15, 'CHA': 17}, 'cr': '14', 'xp': 11500, 'proficiency_bonus': 5, 'passive_perception': 22, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath'), ref('creature-action', 'Slowing Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Adult Gold Dragon', description: 'A regal metallic dragon, foe of evil tyranny.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 19, 'initiative_modifier': 10, 'initiative_score': 20, 'hp_average': 256, 'hp_dice': '19d12+133', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 14, 'CON': 25, 'INT': 16, 'WIS': 15, 'CHA': 24}, 'cr': '17', 'xp': 18000, 'proficiency_bonus': 6, 'passive_perception': 23, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Weakening Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Adult Silver Dragon', description: 'A noble metallic dragon, friend of mortals.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 19, 'initiative_modifier': 10, 'initiative_score': 20, 'hp_average': 243, 'hp_dice': '18d12+126', 'speed_walk_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 10, 'CON': 25, 'INT': 16, 'WIS': 13, 'CHA': 21}, 'cr': '16', 'xp': 15000, 'proficiency_bonus': 5, 'passive_perception': 22, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath'), ref('creature-action', 'Paralyzing Breath')], 'legendary_action_uses': 3}),

      // Dragons: Ancient (Gargantuan, CR 20-24)
      packEntity(slug: 'monster', name: 'Ancient Black Dragon', description: 'An ancient black dragon ruling fetid swamps for centuries.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 22, 'initiative_modifier': 16, 'initiative_score': 26, 'hp_average': 367, 'hp_dice': '21d20+147', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 14, 'CON': 25, 'INT': 16, 'WIS': 15, 'CHA': 19}, 'cr': '21', 'xp': 33000, 'proficiency_bonus': 7, 'passive_perception': 26, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Blue Dragon', description: 'An ancient blue dragon, tyrant of arid lands.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 22, 'initiative_modifier': 16, 'initiative_score': 26, 'hp_average': 481, 'hp_dice': '26d20+208', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_fly_ft': 80, 'stat_block': {'STR': 29, 'DEX': 10, 'CON': 27, 'INT': 18, 'WIS': 17, 'CHA': 21}, 'cr': '23', 'xp': 50000, 'proficiency_bonus': 7, 'passive_perception': 27, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Brass Dragon', description: 'An ancient brass dragon, sage of the desert wastes.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 20, 'initiative_modifier': 14, 'initiative_score': 24, 'hp_average': 297, 'hp_dice': '17d20+119', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 10, 'CON': 25, 'INT': 16, 'WIS': 15, 'CHA': 19}, 'cr': '20', 'xp': 25000, 'proficiency_bonus': 6, 'passive_perception': 25, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Sleep Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Bronze Dragon', description: 'An ancient bronze dragon, scourge of pirates and tyrants.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 22, 'initiative_modifier': 16, 'initiative_score': 26, 'hp_average': 444, 'hp_dice': '24d20+192', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 29, 'DEX': 10, 'CON': 27, 'INT': 18, 'WIS': 17, 'CHA': 21}, 'cr': '22', 'xp': 41000, 'proficiency_bonus': 7, 'passive_perception': 27, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Lightning Breath'), ref('creature-action', 'Repulsion Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Copper Dragon', description: 'An ancient copper dragon, master of riddles and stone.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Good', 'ac': 21, 'initiative_modifier': 15, 'initiative_score': 25, 'hp_average': 350, 'hp_dice': '20d20+140', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 12, 'CON': 25, 'INT': 20, 'WIS': 17, 'CHA': 19}, 'cr': '21', 'xp': 33000, 'proficiency_bonus': 7, 'passive_perception': 27, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Acid Breath'), ref('creature-action', 'Slowing Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Gold Dragon', description: 'An ancient gold dragon, paragon of just causes.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 22, 'initiative_modifier': 16, 'initiative_score': 26, 'hp_average': 546, 'hp_dice': '28d20+252', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 30, 'DEX': 14, 'CON': 29, 'INT': 18, 'WIS': 17, 'CHA': 28}, 'cr': '24', 'xp': 62000, 'proficiency_bonus': 7, 'passive_perception': 27, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath'), ref('creature-action', 'Weakening Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Green Dragon', description: 'An ancient green dragon, manipulative tyrant of forests.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Evil', 'ac': 21, 'initiative_modifier': 15, 'initiative_score': 25, 'hp_average': 385, 'hp_dice': '22d20+154', 'speed_walk_ft': 40, 'speed_swim_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 27, 'DEX': 12, 'CON': 25, 'INT': 20, 'WIS': 17, 'CHA': 19}, 'cr': '22', 'xp': 41000, 'proficiency_bonus': 7, 'passive_perception': 27, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Poison Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Red Dragon', description: 'An ancient red dragon, supreme tyrant of fire and pride.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 22, 'initiative_modifier': 14, 'initiative_score': 24, 'hp_average': 546, 'hp_dice': '28d20+252', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 30, 'DEX': 10, 'CON': 29, 'INT': 18, 'WIS': 15, 'CHA': 23}, 'cr': '24', 'xp': 62000, 'proficiency_bonus': 7, 'passive_perception': 26, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Fire Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient Silver Dragon', description: 'An ancient silver dragon, age-wise mentor of dragonkind.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Lawful Good', 'ac': 22, 'initiative_modifier': 16, 'initiative_score': 26, 'hp_average': 487, 'hp_dice': '25d20+225', 'speed_walk_ft': 40, 'speed_fly_ft': 80, 'stat_block': {'STR': 30, 'DEX': 10, 'CON': 29, 'INT': 18, 'WIS': 15, 'CHA': 23}, 'cr': '23', 'xp': 50000, 'proficiency_bonus': 7, 'passive_perception': 26, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath'), ref('creature-action', 'Paralyzing Breath')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Ancient White Dragon', description: 'An ancient white dragon, primeval terror of the frozen wastes.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Chaotic Evil', 'ac': 20, 'initiative_modifier': 14, 'initiative_score': 24, 'hp_average': 333, 'hp_dice': '18d20+144', 'speed_walk_ft': 40, 'speed_burrow_ft': 30, 'speed_fly_ft': 80, 'speed_swim_ft': 40, 'stat_block': {'STR': 26, 'DEX': 10, 'CON': 26, 'INT': 10, 'WIS': 13, 'CHA': 14}, 'cr': '20', 'xp': 25000, 'proficiency_bonus': 6, 'passive_perception': 23, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rend (Dragon)'), ref('creature-action', 'Cold Breath')], 'legendary_action_uses': 3}),

      // NPC humanoids
      packEntity(slug: 'monster', name: 'Archmage', description: 'A peerless wizard, advisor to royalty or master of a tower.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 17, 'initiative_modifier': 7, 'initiative_score': 17, 'hp_average': 110, 'hp_dice': '20d8+20', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 14, 'CON': 12, 'INT': 20, 'WIS': 15, 'CHA': 16}, 'cr': '12', 'xp': 8400, 'proficiency_bonus': 4, 'passive_perception': 12, 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'damage_immunity_refs': [lookup('damage-type', 'Force'), lookup('damage-type', 'Psychic')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Quarterstaff (Archmage)'), ref('creature-action', 'Spellcasting (Archmage)')]}),
      packEntity(slug: 'monster', name: 'Bandit Captain', description: 'A swashbuckling brigand leading a gang of cutthroats.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 65, 'hp_dice': '10d8+20', 'speed_walk_ft': 30, 'stat_block': {'STR': 15, 'DEX': 16, 'CON': 14, 'INT': 14, 'WIS': 11, 'CHA': 14}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Scimitar (Bandit Captain)'), ref('creature-action', 'Pistol (Bandit Captain)')]}),
      packEntity(slug: 'monster', name: 'Berserker', description: 'A frenzied warrior who fights with reckless abandon.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Neutral', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 67, 'hp_dice': '9d8+27', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 12, 'CON': 17, 'INT': 9, 'WIS': 11, 'CHA': 9}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Reckless')], 'action_refs': [ref('creature-action', 'Greataxe (Berserker)')]}),
      packEntity(slug: 'monster', name: 'Commoner', description: 'An ordinary villager — farmer, cooper, or laborer.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 4, 'hp_dice': '1d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Cudgel (Commoner)')]}),
      packEntity(slug: 'monster', name: 'Cultist', description: 'A devotee of dark powers, willing to spill blood in their name.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Evil', 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 9, 'hp_dice': '2d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 12, 'CON': 10, 'INT': 10, 'WIS': 11, 'CHA': 10}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 11, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Sickle (Cultist)')]}),
      packEntity(slug: 'monster', name: 'Cultist Fanatic', description: 'A zealous devotee, far more dangerous than ordinary cultists.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 33, 'hp_dice': '6d8+6', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 12, 'CON': 12, 'INT': 10, 'WIS': 13, 'CHA': 14}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Spellcasting (Cult Fanatic)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Sickle (Cultist)')]}),
      packEntity(slug: 'monster', name: 'Druid', description: 'A spellcaster of the wilds, channeling primordial nature magic.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 27, 'hp_dice': '5d8+5', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 12, 'CON': 13, 'INT': 12, 'WIS': 15, 'CHA': 11}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'language_refs': [lookup('language', 'Common'), lookup('language', 'Druidic')], 'trait_refs': [ref('trait', 'Innate Spellcasting (Druid)')], 'action_refs': [ref('creature-action', 'Sickle (Druid)'), ref('creature-action', 'Spellcasting (Druid NPC)')]}),
      packEntity(slug: 'monster', name: 'Guard', description: 'A sworn watchman patrolling town gates and noble courts.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Lawful Neutral', 'ac': 16, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 30, 'stat_block': {'STR': 13, 'DEX': 12, 'CON': 12, 'INT': 10, 'WIS': 11, 'CHA': 10}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 12, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Spear (Guard)')]}),
      packEntity(slug: 'monster', name: 'Guard Captain', description: 'A veteran officer commanding city watch or castle garrison.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Lawful Neutral', 'ac': 18, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 75, 'hp_dice': '10d8+30', 'speed_walk_ft': 30, 'stat_block': {'STR': 17, 'DEX': 12, 'CON': 16, 'INT': 12, 'WIS': 14, 'CHA': 14}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 14, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Halberd (Guard Captain)'), ref('creature-action', 'Heavy Crossbow (Guard Captain)')]}),
      packEntity(slug: 'monster', name: 'Hobgoblin Captain', description: 'A goblinoid commander leading hobgoblin troops with iron discipline.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(goblinoid)', 'alignment_ref': 'Lawful Evil', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 39, 'hp_dice': '6d8+12', 'speed_walk_ft': 30, 'stat_block': {'STR': 15, 'DEX': 14, 'CON': 14, 'INT': 12, 'WIS': 10, 'CHA': 13}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Goblin')], 'trait_refs': [ref('trait', 'Martial Advantage')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Longsword (Knight)'), ref('creature-action', 'Javelin (Bugbear)')]}),
      packEntity(slug: 'monster', name: 'Noble', description: 'An aristocrat — by blood, status, or fortune.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 15, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 9, 'hp_dice': '2d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 12, 'CON': 11, 'INT': 12, 'WIS': 14, 'CHA': 16}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 12, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Mace (Noble)')]}),
      packEntity(slug: 'monster', name: 'Pirate', description: 'A buccaneer of the high seas, equally at home in rigging or tavern brawl.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Neutral', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 14, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 12}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Scimitar (Pirate)')]}),
      packEntity(slug: 'monster', name: 'Pirate Captain', description: 'A swashbuckling raider commanding a vessel and crew.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral Evil', 'ac': 17, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 84, 'hp_dice': '13d8+26', 'speed_walk_ft': 30, 'stat_block': {'STR': 12, 'DEX': 18, 'CON': 14, 'INT': 14, 'WIS': 11, 'CHA': 16}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 11, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rapier (Pirate Captain)'), ref('creature-action', 'Pistol (Bandit Captain)')]}),
      packEntity(slug: 'monster', name: 'Priest Acolyte', description: 'A junior cleric of a temple, devoted to a chosen deity.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 9, 'hp_dice': '2d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 14, 'CHA': 11}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 12, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Mace (Priest Acolyte)')]}),
      packEntity(slug: 'monster', name: 'Sahuagin Warrior', description: 'A shark-like aquatic raider lurking in coral reefs.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(sahuagin)', 'alignment_ref': 'Lawful Evil', 'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 22, 'hp_dice': '4d8+4', 'speed_walk_ft': 30, 'speed_swim_ft': 40, 'stat_block': {'STR': 13, 'DEX': 11, 'CON': 12, 'INT': 12, 'WIS': 13, 'CHA': 9}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Blood Frenzy')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Trident (Sahuagin Warrior)'), ref('creature-action', 'Bite (Sahuagin Warrior)')]}),
      packEntity(slug: 'monster', name: 'Scout', description: 'A skilled tracker and ranger of wilderness paths.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 16, 'hp_dice': '3d8+3', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 14, 'CON': 12, 'INT': 11, 'WIS': 13, 'CHA': 11}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 15, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Shortsword (Scout)'), ref('creature-action', 'Longbow (Scout)')]}),
      packEntity(slug: 'monster', name: 'Warrior Infantry', description: 'A trained soldier in shield wall or column.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 30, 'stat_block': {'STR': 14, 'DEX': 12, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 10}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Spear (Warrior Infantry)')]}),
      packEntity(slug: 'monster', name: 'Warrior Veteran', description: 'A seasoned campaigner, sergeant or lieutenant of the line.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral', 'ac': 16, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 32, 'hp_dice': '5d8+10', 'speed_walk_ft': 30, 'stat_block': {'STR': 15, 'DEX': 13, 'CON': 14, 'INT': 11, 'WIS': 11, 'CHA': 11}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 11, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Longsword (Warrior Veteran)')]}),
      packEntity(slug: 'monster', name: 'Tough', description: 'A bare-knuckle brawler or street thug.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Neutral', 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 17, 'hp_dice': '3d8+3', 'speed_walk_ft': 30, 'stat_block': {'STR': 14, 'DEX': 12, 'CON': 13, 'INT': 10, 'WIS': 10, 'CHA': 11}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Spear (Tough)')]}),
      packEntity(slug: 'monster', name: 'Tough Boss', description: 'The leader of a gang of toughs, larger and meaner than the rest.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Chaotic Neutral', 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 39, 'hp_dice': '6d8+12', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 14, 'CON': 14, 'INT': 11, 'WIS': 11, 'CHA': 12}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Greatsword (Tough Boss)')]}),
      packEntity(slug: 'monster', name: 'Bugbear Stalker', description: 'A bugbear leader, master of ambush and butchery.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(goblinoid)', 'alignment_ref': 'Chaotic Evil', 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 65, 'hp_dice': '10d8+20', 'speed_walk_ft': 30, 'stat_block': {'STR': 17, 'DEX': 14, 'CON': 14, 'INT': 11, 'WIS': 12, 'CHA': 11}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Goblin')], 'trait_refs': [ref('trait', 'Brute')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Morningstar (Bugbear Stalker)'), ref('creature-action', 'Javelin (Bugbear)')]}),
      packEntity(slug: 'monster', name: 'Centaur Trooper', description: 'A horse-bodied warrior wandering plains and woodlands.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Neutral Good', 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 50, 'stat_block': {'STR': 18, 'DEX': 14, 'CON': 14, 'INT': 9, 'WIS': 13, 'CHA': 11}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 13, 'language_refs': [lookup('language', 'Elvish'), lookup('language', 'Sylvan')], 'trait_refs': [ref('trait', 'Charge')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Pike (Centaur Trooper)'), ref('creature-action', 'Hooves (Centaur Trooper)')]}),
      packEntity(slug: 'monster', name: 'Goblin Boss', description: 'A goblin leader extorting rule from rival warbands.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(goblinoid)', 'alignment_ref': 'Chaotic Evil', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 21, 'hp_dice': '6d6', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 14, 'CON': 10, 'INT': 10, 'WIS': 8, 'CHA': 10}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Goblin')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Goblin Boss Scimitar'), ref('creature-action', 'Shortbow (Goblin)')], 'bonus_action_refs': [ref('creature-action', 'Nimble Escape')]}),
      packEntity(slug: 'monster', name: 'Goblin Minion', description: 'The lowliest goblin foot soldier.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(goblinoid)', 'alignment_ref': 'Chaotic Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 1, 'hp_dice': '1d4', 'speed_walk_ft': 30, 'stat_block': {'STR': 8, 'DEX': 14, 'CON': 8, 'INT': 8, 'WIS': 8, 'CHA': 8}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Goblin')], 'action_refs': [ref('creature-action', 'Goblin Minion Sickle')]}),
      packEntity(slug: 'monster', name: 'Gnoll Warrior', description: 'A hyena-headed marauder following the call of demonic patrons.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(gnoll)', 'alignment_ref': 'Chaotic Evil', 'ac': 15, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 14, 'DEX': 12, 'CON': 11, 'INT': 6, 'WIS': 10, 'CHA': 7}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Abyssal')], 'action_refs': [ref('creature-action', 'Spear (Gnoll Warrior)'), ref('creature-action', 'Bite (Gnoll)')]}),
      packEntity(slug: 'monster', name: 'Merfolk Skirmisher', description: 'A coastal merfolk patrolling reefs and shallows.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(merfolk)', 'alignment_ref': 'Neutral', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 10, 'speed_swim_ft': 40, 'stat_block': {'STR': 10, 'DEX': 13, 'CON': 12, 'INT': 11, 'WIS': 11, 'CHA': 12}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10, 'language_refs': [lookup('language', 'Primordial'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Water Breathing')], 'action_refs': [ref('creature-action', 'Spear (Merfolk Skirmisher)')]}),
      packEntity(slug: 'monster', name: 'Merrow', description: 'A monstrous, twisted merfolk of the deeps.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 10, 'speed_swim_ft': 40, 'stat_block': {'STR': 18, 'DEX': 10, 'CON': 15, 'INT': 8, 'WIS': 10, 'CHA': 9}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Water Breathing')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Harpoon (Merrow)'), ref('creature-action', 'Bite (Merrow)')]}),

      // Devils
      packEntity(slug: 'monster', name: 'Lemure', description: 'The lowest form of devil, a writhing mass of corrupted soul-stuff.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 7, 'initiative_modifier': -3, 'initiative_score': 7, 'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 15, 'stat_block': {'STR': 10, 'DEX': 5, 'CON': 11, 'INT': 1, 'WIS': 11, 'CHA': 3}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold')], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'action_refs': [ref('creature-action', 'Sting (Lemure)')]}),
      packEntity(slug: 'monster', name: 'Imp', description: 'A tiny, malicious devil-familiar serving wizards and warlocks.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 21, 'hp_dice': '6d4+6', 'speed_walk_ft': 20, 'speed_fly_ft': 40, 'stat_block': {'STR': 6, 'DEX': 17, 'CON': 13, 'INT': 11, 'WIS': 12, 'CHA': 14}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Sting (Imp)')]}),
      packEntity(slug: 'monster', name: 'Bearded Devil', description: 'A barbed-bearded fiend whose poisonous beard infects with infernal disease.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 52, 'hp_dice': '8d8+16', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 15, 'CON': 15, 'INT': 9, 'WIS': 11, 'CHA': 11}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Trident (Bearded Devil)'), ref('creature-action', 'Beard (Bearded Devil)')]}),
      packEntity(slug: 'monster', name: 'Barbed Devil', description: 'A spike-skinned fiend that revels in cruelty.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 110, 'hp_dice': '13d8+52', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 17, 'CON': 18, 'INT': 12, 'WIS': 14, 'CHA': 14}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 18, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Glaive (Barbed Devil)'), ref('creature-action', 'Tail (Barbed Devil)')]}),
      packEntity(slug: 'monster', name: 'Chain Devil', description: 'A devil that wields animated chains as both weapon and tormentor.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 16, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 85, 'hp_dice': '10d8+40', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 18, 'INT': 11, 'WIS': 12, 'CHA': 14}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Spiked Chain (Chain Devil)')]}),
      packEntity(slug: 'monster', name: 'Bone Devil', description: 'A skeletal devil with a deadly venomous tail.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 19, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 142, 'hp_dice': '15d10+60', 'speed_walk_ft': 40, 'speed_fly_ft': 40, 'stat_block': {'STR': 18, 'DEX': 16, 'CON': 18, 'INT': 13, 'WIS': 14, 'CHA': 16}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Bone Devil)'), ref('creature-action', 'Sting (Bone Devil)')]}),
      packEntity(slug: 'monster', name: 'Horned Devil', description: 'A massive winged devil wielding flame and pitchfork.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 199, 'hp_dice': '19d10+95', 'speed_walk_ft': 20, 'speed_fly_ft': 60, 'stat_block': {'STR': 22, 'DEX': 17, 'CON': 21, 'INT': 12, 'WIS': 16, 'CHA': 17}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Fork (Horned Devil)'), ref('creature-action', 'Hurl Flame (Horned Devil)')]}),
      packEntity(slug: 'monster', name: 'Ice Devil', description: 'A freezing fiend of cold-spear and frozen breath.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 180, 'hp_dice': '19d10+76', 'speed_walk_ft': 40, 'stat_block': {'STR': 21, 'DEX': 14, 'CON': 18, 'INT': 18, 'WIS': 15, 'CHA': 18}, 'cr': '14', 'xp': 11500, 'proficiency_bonus': 5, 'passive_perception': 12, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}, {'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Devil\'s Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Ice Devil)'), ref('creature-action', 'Spear (Ice Devil)'), ref('creature-action', 'Tail (Ice Devil)')]}),
      packEntity(slug: 'monster', name: 'Erinyes', description: 'A fallen angel turned devil, scourge in hand.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(devil)', 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 153, 'hp_dice': '18d8+72', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 18, 'DEX': 18, 'CON': 18, 'INT': 14, 'WIS': 14, 'CHA': 18}, 'cr': '12', 'xp': 8400, 'proficiency_bonus': 4, 'passive_perception': 12, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Scourge (Erinyes)'), ref('creature-action', 'Longbow (Erinyes)')]}),

      // Demons
      packEntity(slug: 'monster', name: 'Quasit', description: 'A tiny demonic familiar shape-shifting between forms.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 7, 'hp_dice': '3d4', 'speed_walk_ft': 40, 'stat_block': {'STR': 5, 'DEX': 17, 'CON': 10, 'INT': 7, 'WIS': 10, 'CHA': 10}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Claws (Quasit)')]}),
      packEntity(slug: 'monster', name: 'Dretch', description: 'A bloated, foul-smelling lesser demon.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 18, 'hp_dice': '4d6+4', 'speed_walk_ft': 20, 'stat_block': {'STR': 11, 'DEX': 11, 'CON': 12, 'INT': 5, 'WIS': 8, 'CHA': 3}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Dretch)'), ref('creature-action', 'Claws (Dretch)')]}),
      packEntity(slug: 'monster', name: 'Vrock', description: 'A vulture-headed demon, raucous and pestilent.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 104, 'hp_dice': '11d10+44', 'speed_walk_ft': 40, 'speed_fly_ft': 60, 'stat_block': {'STR': 17, 'DEX': 15, 'CON': 18, 'INT': 8, 'WIS': 13, 'CHA': 8}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Beak (Vrock)'), ref('creature-action', 'Talons (Vrock)'), ref('creature-action', 'Spores (Vrock)')]}),
      packEntity(slug: 'monster', name: 'Hezrou', description: 'A hulking toad-like demon reeking with disease.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 16, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 136, 'hp_dice': '13d10+65', 'speed_walk_ft': 30, 'stat_block': {'STR': 19, 'DEX': 14, 'CON': 20, 'INT': 5, 'WIS': 12, 'CHA': 13}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Stench')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Hezrou)'), ref('creature-action', 'Claws (Hezrou)')]}),
      packEntity(slug: 'monster', name: 'Glabrezu', description: 'A massive four-armed demon, granter of corrupting wishes.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 157, 'hp_dice': '15d10+75', 'speed_walk_ft': 40, 'stat_block': {'STR': 20, 'DEX': 15, 'CON': 21, 'INT': 19, 'WIS': 17, 'CHA': 16}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 13, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Pincer (Glabrezu)')]}),
      packEntity(slug: 'monster', name: 'Nalfeshnee', description: 'A boar-headed demon-judge of the Abyss.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 18, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 184, 'hp_dice': '16d10+96', 'speed_walk_ft': 20, 'speed_fly_ft': 30, 'stat_block': {'STR': 21, 'DEX': 10, 'CON': 22, 'INT': 19, 'WIS': 12, 'CHA': 15}, 'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 13, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Nalfeshnee)'), ref('creature-action', 'Claws (Nalfeshnee)')]}),
      packEntity(slug: 'monster', name: 'Marilith', description: 'A six-armed demon of the Abyss, master swordfighter.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'tags_line': '(demon)', 'alignment_ref': 'Chaotic Evil', 'ac': 18, 'initiative_modifier': 5, 'initiative_score': 15, 'hp_average': 220, 'hp_dice': '21d10+105', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 20, 'CON': 20, 'INT': 18, 'WIS': 16, 'CHA': 20}, 'cr': '16', 'xp': 15000, 'proficiency_bonus': 5, 'passive_perception': 13, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Marilith)'), ref('creature-action', 'Longsword (Marilith)')]}),
      packEntity(slug: 'monster', name: 'Incubus', description: 'A male fiend that seduces and drains victims through dreams.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Neutral Evil', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 66, 'hp_dice': '12d8+12', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 8, 'DEX': 17, 'CON': 13, 'INT': 15, 'WIS': 12, 'CHA': 20}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Poison')], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common'), lookup('language', 'Infernal')], 'telepathy_ft': 60, 'action_refs': [ref('creature-action', 'Scimitar (Incubus)'), ref('creature-action', 'Charm (Succubus)')]}),
      packEntity(slug: 'monster', name: 'Succubus', description: 'A female fiend that seduces and drains victims through dreams.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Neutral Evil', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 66, 'hp_dice': '12d8+12', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 8, 'DEX': 17, 'CON': 13, 'INT': 15, 'WIS': 12, 'CHA': 20}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Poison')], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common'), lookup('language', 'Infernal')], 'telepathy_ft': 60, 'action_refs': [ref('creature-action', 'Claws (Succubus)'), ref('creature-action', 'Charm (Succubus)')]}),
      packEntity(slug: 'monster', name: 'Night Hag', description: 'A nightmare-spinning hag that haunts and harvests sleepers.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Neutral Evil', 'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 112, 'hp_dice': '15d8+45', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 16, 'WIS': 14, 'CHA': 16}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common'), lookup('language', 'Infernal'), lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Bite (Night Hag)')]}),
      packEntity(slug: 'monster', name: 'Sea Hag', description: 'A coastal hag haunting tide pools and ship-wreckers.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Chaotic Evil', 'ac': 14, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 52, 'hp_dice': '7d8+21', 'speed_walk_ft': 30, 'speed_swim_ft': 40, 'stat_block': {'STR': 16, 'DEX': 13, 'CON': 16, 'INT': 12, 'WIS': 12, 'CHA': 13}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Water Breathing')], 'action_refs': [ref('creature-action', 'Bite (Sea Hag)')]}),
      packEntity(slug: 'monster', name: 'Green Hag', description: 'A forest hag, deceiver and corrupter of innocents.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Neutral Evil', 'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 82, 'hp_dice': '11d8+33', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 12, 'CON': 16, 'INT': 13, 'WIS': 14, 'CHA': 14}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic'), lookup('language', 'Sylvan')], 'trait_refs': [ref('trait', 'Mimicry')], 'action_refs': [ref('creature-action', 'Claws (Green Hag)')]}),

      // Mephits and elementals
      packEntity(slug: 'monster', name: 'Dust Mephit', description: 'A small elemental of swirling sand and grit.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 17, 'hp_dice': '5d6', 'speed_walk_ft': 30, 'speed_fly_ft': 30, 'stat_block': {'STR': 5, 'DEX': 14, 'CON': 10, 'INT': 9, 'WIS': 11, 'CHA': 10}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Death Burst')], 'action_refs': [ref('creature-action', 'Claws (Dust Mephit)')]}),
      packEntity(slug: 'monster', name: 'Ice Mephit', description: 'A small elemental of jagged ice and bitter cold.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral Evil', 'ac': 11, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 21, 'hp_dice': '6d6', 'speed_walk_ft': 30, 'speed_fly_ft': 30, 'stat_block': {'STR': 7, 'DEX': 13, 'CON': 10, 'INT': 9, 'WIS': 11, 'CHA': 12}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Poison')], 'vulnerability_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Fire')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Death Burst')], 'action_refs': [ref('creature-action', 'Claws (Ice Mephit)')]}),
      packEntity(slug: 'monster', name: 'Magma Mephit', description: 'A small elemental of molten rock and hissing flame.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral Evil', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 22, 'hp_dice': '5d6+5', 'speed_walk_ft': 30, 'speed_fly_ft': 30, 'stat_block': {'STR': 8, 'DEX': 12, 'CON': 12, 'INT': 7, 'WIS': 10, 'CHA': 10}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Death Burst')], 'action_refs': [ref('creature-action', 'Claws (Magma Mephit)')]}),
      packEntity(slug: 'monster', name: 'Steam Mephit', description: 'A small elemental of scalding mist.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral Evil', 'ac': 10, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 21, 'hp_dice': '6d6', 'speed_walk_ft': 30, 'speed_fly_ft': 30, 'stat_block': {'STR': 5, 'DEX': 11, 'CON': 10, 'INT': 11, 'WIS': 10, 'CHA': 12}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Death Burst')], 'action_refs': [ref('creature-action', 'Claws (Steam Mephit)')]}),
      packEntity(slug: 'monster', name: 'Magmin', description: 'A small fire elemental of glowing magma.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Chaotic Neutral', 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 9, 'hp_dice': '2d6+2', 'speed_walk_ft': 30, 'stat_block': {'STR': 7, 'DEX': 15, 'CON': 12, 'INT': 8, 'WIS': 11, 'CHA': 10}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Death Burst'), ref('trait', 'Heated Body')], 'action_refs': [ref('creature-action', 'Sting (Magmin)')]}),
      packEntity(slug: 'monster', name: 'Azer Sentinel', description: 'A dwarf-like fire-being soldier from the Plane of Fire.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Lawful Neutral', 'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 39, 'hp_dice': '6d8+12', 'speed_walk_ft': 30, 'stat_block': {'STR': 17, 'DEX': 12, 'CON': 15, 'INT': 12, 'WIS': 13, 'CHA': 10}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Heated Body'), ref('trait', 'Magic Weapons')], 'action_refs': [ref('creature-action', 'Slam (Azer Sentinel)')]}),
      packEntity(slug: 'monster', name: 'Djinni', description: 'A noble genie of air, master of wind and lightning.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Chaotic Good', 'ac': 17, 'initiative_modifier': 6, 'initiative_score': 16, 'hp_average': 218, 'hp_dice': '19d10+114', 'speed_walk_ft': 30, 'speed_fly_ft': 90, 'stat_block': {'STR': 21, 'DEX': 15, 'CON': 22, 'INT': 15, 'WIS': 16, 'CHA': 20}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 13, 'damage_immunity_refs': [lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Scimitar (Djinni)')]}),
      packEntity(slug: 'monster', name: 'Efreeti', description: 'A noble genie of fire, prideful and tyrannical.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Lawful Evil', 'ac': 17, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 200, 'hp_dice': '16d10+112', 'speed_walk_ft': 40, 'speed_fly_ft': 60, 'stat_block': {'STR': 22, 'DEX': 12, 'CON': 24, 'INT': 16, 'WIS': 15, 'CHA': 16}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 12, 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Scimitar (Efreeti)')]}),
      packEntity(slug: 'monster', name: 'Salamander', description: 'A snake-like fire elemental with a flaming spear.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral Evil', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 90, 'hp_dice': '12d10+24', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 14, 'CON': 15, 'INT': 11, 'WIS': 10, 'CHA': 12}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'vulnerability_refs': [lookup('damage-type', 'Cold')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Heated Body')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Spear (Salamander)'), ref('creature-action', 'Tail (Salamander)')]}),
      packEntity(slug: 'monster', name: 'Invisible Stalker', description: 'A bound air elemental hunter, invisible and relentless.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 104, 'hp_dice': '16d8+32', 'speed_walk_ft': 50, 'speed_fly_ft': 50, 'stat_block': {'STR': 16, 'DEX': 19, 'CON': 14, 'INT': 10, 'WIS': 15, 'CHA': 11}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 18, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Air Form')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Invisible Stalker)')]}),

      // Giants
      packEntity(slug: 'monster', name: 'Cloud Giant', description: 'A giant of clouds and skylands, prideful arbiter of feasts.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Giant'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 200, 'hp_dice': '16d12+96', 'speed_walk_ft': 40, 'stat_block': {'STR': 27, 'DEX': 10, 'CON': 22, 'INT': 12, 'WIS': 16, 'CHA': 16}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 17, 'language_refs': [lookup('language', 'Common'), lookup('language', 'Giant')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Greataxe (Cloud Giant)'), ref('creature-action', 'Rock (Cloud Giant)')]}),
      packEntity(slug: 'monster', name: 'Fire Giant', description: 'A blacksmith-warrior giant of volcanic fortresses.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Giant'), 'alignment_ref': 'Lawful Evil', 'ac': 18, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 162, 'hp_dice': '13d12+78', 'speed_walk_ft': 30, 'stat_block': {'STR': 25, 'DEX': 9, 'CON': 23, 'INT': 10, 'WIS': 14, 'CHA': 13}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 16, 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Giant')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Greatsword (Fire Giant)'), ref('creature-action', 'Rock (Fire Giant)')]}),
      packEntity(slug: 'monster', name: 'Frost Giant', description: 'A frost-bearded raider of glacial steadings.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Giant'), 'alignment_ref': 'Neutral Evil', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 138, 'hp_dice': '12d12+60', 'speed_walk_ft': 40, 'stat_block': {'STR': 23, 'DEX': 9, 'CON': 21, 'INT': 9, 'WIS': 10, 'CHA': 12}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 13, 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'language_refs': [lookup('language', 'Giant')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Greataxe (Frost Giant)'), ref('creature-action', 'Rock (Frost Giant)')]}),
      packEntity(slug: 'monster', name: 'Storm Giant', description: 'A noble giant of stormclouds and thunder.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Giant'), 'alignment_ref': 'Chaotic Good', 'ac': 16, 'initiative_modifier': 8, 'initiative_score': 18, 'hp_average': 230, 'hp_dice': '20d12+100', 'speed_walk_ft': 50, 'speed_swim_ft': 50, 'stat_block': {'STR': 29, 'DEX': 14, 'CON': 20, 'INT': 16, 'WIS': 18, 'CHA': 18}, 'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 19, 'damage_immunity_refs': [lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder')], 'resistance_refs': [lookup('damage-type', 'Cold')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Giant')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Thunderous Greatsword (Storm Giant)'), ref('creature-action', 'Lightning Strike (Storm Giant)')]}),

      // Undead
      packEntity(slug: 'monster', name: 'Shadow', description: 'An incorporeal undead, child of darkness, drainer of strength.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Chaotic Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 16, 'hp_dice': '3d8+3', 'speed_walk_ft': 40, 'stat_block': {'STR': 6, 'DEX': 14, 'CON': 13, 'INT': 6, 'WIS': 10, 'CHA': 8}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'resistance_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder'), lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'trait_refs': [ref('trait', 'Sunlight Sensitivity (Acute)')], 'action_refs': [ref('creature-action', 'Strength-Draining Touch (Shadow)')]}),
      packEntity(slug: 'monster', name: 'Wraith', description: 'A spectral form of a corrupted soul, withering all it touches.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 67, 'hp_dice': '9d8+27', 'speed_walk_ft': 0, 'speed_fly_ft': 60, 'can_hover': true, 'stat_block': {'STR': 6, 'DEX': 16, 'CON': 16, 'INT': 12, 'WIS': 14, 'CHA': 15}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'resistance_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Withering Touch (Wraith)')]}),
      packEntity(slug: 'monster', name: 'Ghost', description: 'A restless spirit anchored to the world by unfinished business.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral', 'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 45, 'hp_dice': '10d8', 'speed_walk_ft': 0, 'speed_fly_ft': 40, 'can_hover': true, 'stat_block': {'STR': 7, 'DEX': 13, 'CON': 10, 'INT': 10, 'WIS': 12, 'CHA': 17}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'resistance_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder'), lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Slam (Ghost)'), ref('creature-action', 'Etherealness (Ghost)'), ref('creature-action', 'Horrifying Visage (Ghost)')]}),
      packEntity(slug: 'monster', name: 'Ghast', description: 'A more powerful, fouler ghoul, captain of the corpse-eating dead.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 36, 'hp_dice': '8d8', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 17, 'CON': 10, 'INT': 11, 'WIS': 10, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Stench')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Ghast)'), ref('creature-action', 'Claws (Ghast)')]}),
      packEntity(slug: 'monster', name: 'Mummy Lord', description: 'An ancient mummy ruler, undead-king of forgotten dynasties.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Lawful Evil', 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 97, 'hp_dice': '13d8+39', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 10, 'CON': 17, 'INT': 11, 'WIS': 18, 'CHA': 16}, 'cr': '15', 'xp': 13000, 'proficiency_bonus': 5, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Rejuvenation')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Rotting Fist (Mummy Lord)'), ref('creature-action', 'Spellcasting (Mummy Lord)')], 'legendary_action_uses': 3}),
      packEntity(slug: 'monster', name: 'Vampire Spawn', description: 'A lesser vampire, thrall to its master\'s will.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral Evil', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 82, 'hp_dice': '11d8+33', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 16, 'CON': 16, 'INT': 11, 'WIS': 10, 'CHA': 12}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Necrotic')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Spider Climb (Vampire)'), ref('trait', 'Vampire Weaknesses'), ref('trait', 'Regeneration')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Vampire Spawn)'), ref('creature-action', 'Bite (Vampire Spawn)')]}),
      packEntity(slug: 'monster', name: 'Vampire Familiar', description: 'A reduced, weakened vampire serving as a noble vampire\'s minion.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 38, 'hp_dice': '7d8+7', 'speed_walk_ft': 30, 'stat_block': {'STR': 14, 'DEX': 16, 'CON': 13, 'INT': 11, 'WIS': 10, 'CHA': 12}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Necrotic')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Spider Climb (Vampire)'), ref('trait', 'Vampire Weaknesses')], 'action_refs': [ref('creature-action', 'Bite (Vampire Familiar)')]}),
      packEntity(slug: 'monster', name: 'Ogre Zombie', description: 'A reanimated ogre corpse, slow and brutal.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral Evil', 'ac': 8, 'initiative_modifier': -2, 'initiative_score': 8, 'hp_average': 85, 'hp_dice': '9d10+36', 'speed_walk_ft': 30, 'stat_block': {'STR': 19, 'DEX': 6, 'CON': 18, 'INT': 3, 'WIS': 6, 'CHA': 5}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Giant')], 'trait_refs': [ref('trait', 'Undead Fortitude')], 'action_refs': [ref('creature-action', 'Slam (Ogre Zombie)')]}),
      packEntity(slug: 'monster', name: 'Minotaur Skeleton', description: 'A reanimated minotaur skeleton, swinging a great axe with deathly precision.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Lawful Evil', 'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 67, 'hp_dice': '9d10+18', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 11, 'CON': 15, 'INT': 6, 'WIS': 8, 'CHA': 5}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'vulnerability_refs': [lookup('damage-type', 'Bludgeoning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Exhaustion'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Shortsword (Minotaur Skeleton)')]}),
      packEntity(slug: 'monster', name: 'Warhorse Skeleton', description: 'A skeletal horse, charging with bony hooves.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Lawful Evil', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 22, 'hp_dice': '3d10+6', 'speed_walk_ft': 60, 'stat_block': {'STR': 18, 'DEX': 12, 'CON': 15, 'INT': 2, 'WIS': 8, 'CHA': 5}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'vulnerability_refs': [lookup('damage-type', 'Bludgeoning')], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Exhaustion'), lookup('condition', 'Poisoned')], 'action_refs': [ref('creature-action', 'Hooves (Warhorse Skeleton)')]}),
      packEntity(slug: 'monster', name: 'Swarm of Crawling Claws', description: 'A horrific swarm of severed, animated hands.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Neutral Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 49, 'hp_dice': '11d8', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 14, 'DEX': 14, 'CON': 11, 'INT': 5, 'WIS': 10, 'CHA': 4}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}], 'damage_immunity_refs': [lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned'), lookup('condition', 'Prone'), lookup('condition', 'Restrained'), lookup('condition', 'Stunned')], 'trait_refs': [ref('trait', 'Swarm')], 'action_refs': [ref('creature-action', 'Slams (Swarm of Crawling Claws)')]}),

      // Lycanthropes
      packEntity(slug: 'monster', name: 'Werebear', description: 'A shapechanger humanoid with the strength of a bear.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(shapechanger)', 'alignment_ref': 'Neutral Good', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 135, 'hp_dice': '18d8+54', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 17, 'INT': 11, 'WIS': 12, 'CHA': 12}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 17, 'damage_immunity_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)'), ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Werebear)'), ref('creature-action', 'Claws (Werebear)')]}),
      packEntity(slug: 'monster', name: 'Wereboar', description: 'A shapechanger humanoid with brute strength of a wild boar.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(shapechanger)', 'alignment_ref': 'Neutral Evil', 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 78, 'hp_dice': '12d8+24', 'speed_walk_ft': 30, 'stat_block': {'STR': 17, 'DEX': 10, 'CON': 15, 'INT': 10, 'WIS': 11, 'CHA': 8}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 12, 'damage_immunity_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)'), ref('trait', 'Charge')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Tusks (Wereboar)')]}),
      packEntity(slug: 'monster', name: 'Wererat', description: 'A shapechanger humanoid skulking in city sewers.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(shapechanger)', 'alignment_ref': 'Lawful Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 33, 'hp_dice': '6d8+6', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 15, 'CON': 12, 'INT': 11, 'WIS': 10, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)'), ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Wererat)'), ref('creature-action', 'Shortsword (Spy)')]}),
      packEntity(slug: 'monster', name: 'Weretiger', description: 'A shapechanger humanoid with the predatory grace of a tiger.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'tags_line': '(shapechanger)', 'alignment_ref': 'Neutral', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 120, 'hp_dice': '16d8+48', 'speed_walk_ft': 40, 'stat_block': {'STR': 17, 'DEX': 15, 'CON': 16, 'INT': 10, 'WIS': 13, 'CHA': 11}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 15, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)'), ref('trait', 'Pounce'), ref('trait', 'Keen Sight and Smell')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Weretiger)'), ref('creature-action', 'Claws (Weretiger)')]}),

      // Constructs
      packEntity(slug: 'monster', name: 'Animated Flying Sword', description: 'A sword animated by magic, fighting on its own.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 14, 'hp_dice': '3d6+3', 'speed_walk_ft': 0, 'speed_fly_ft': 50, 'can_hover': true, 'stat_block': {'STR': 12, 'DEX': 15, 'CON': 11, 'INT': 1, 'WIS': 5, 'CHA': 1}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 7, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison'), lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Bite (Animated Flying Sword)')]}),
      packEntity(slug: 'monster', name: 'Animated Rug of Smothering', description: 'A magic rug that wraps around victims and crushes the breath from them.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 33, 'hp_dice': '6d10', 'speed_walk_ft': 10, 'stat_block': {'STR': 17, 'DEX': 14, 'CON': 10, 'INT': 1, 'WIS': 3, 'CHA': 1}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 6, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison'), lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'False Appearance'), ref('trait', 'Damage Transfer')], 'action_refs': [ref('creature-action', 'Smother (Animated Rug of Smothering)')]}),
      packEntity(slug: 'monster', name: 'Clay Golem', description: 'A golem of consecrated clay, channeled by priestly magic.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 133, 'hp_dice': '14d10+56', 'speed_walk_ft': 20, 'stat_block': {'STR': 20, 'DEX': 9, 'CON': 18, 'INT': 3, 'WIS': 8, 'CHA': 1}, 'cr': '9', 'xp': 5000, 'proficiency_bonus': 4, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Poison'), lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'Magic Resistance'), ref('trait', 'Acid Absorption'), ref('trait', 'Immutable Form')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Clay Golem)')]}),
      packEntity(slug: 'monster', name: 'Flesh Golem', description: 'A patchwork construct of stitched corpses animated by lightning.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 9, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 93, 'hp_dice': '11d8+44', 'speed_walk_ft': 30, 'stat_block': {'STR': 19, 'DEX': 9, 'CON': 18, 'INT': 6, 'WIS': 10, 'CHA': 5}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Lightning'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Lightning Absorption'), ref('trait', 'Magic Resistance'), ref('trait', 'Immutable Form')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Flesh Golem)')]}),
      packEntity(slug: 'monster', name: 'Stone Golem', description: 'A massive stone construct of singular purpose.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 17, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 178, 'hp_dice': '17d10+85', 'speed_walk_ft': 30, 'stat_block': {'STR': 22, 'DEX': 9, 'CON': 20, 'INT': 3, 'WIS': 11, 'CHA': 1}, 'cr': '10', 'xp': 5900, 'proficiency_bonus': 4, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Poison'), lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons'), ref('trait', 'Immutable Form')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Stone Golem)')]}),
      packEntity(slug: 'monster', name: 'Iron Golem', description: 'An iron-clad construct of indomitable strength.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 20, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 252, 'hp_dice': '24d10+120', 'speed_walk_ft': 30, 'stat_block': {'STR': 24, 'DEX': 9, 'CON': 20, 'INT': 3, 'WIS': 11, 'CHA': 1}, 'cr': '16', 'xp': 15000, 'proficiency_bonus': 5, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison'), lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons'), ref('trait', 'Fire Absorption'), ref('trait', 'Immutable Form')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Iron Golem)'), ref('creature-action', 'Sword (Iron Golem)')]}),
      packEntity(slug: 'monster', name: 'Shield Guardian', description: 'A construct bound to a master\'s amulet, protecting and avenging.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 17, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 142, 'hp_dice': '15d10+60', 'speed_walk_ft': 30, 'stat_block': {'STR': 18, 'DEX': 8, 'CON': 18, 'INT': 7, 'WIS': 10, 'CHA': 3}, 'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Construct Nature'), ref('trait', 'Spell Storing (Lich)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Helmed Horror Shield Guardian)')]}),
      packEntity(slug: 'monster', name: 'Homunculus', description: 'A tiny construct created from a wizard\'s blood, telepathic mate.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Construct'), 'alignment_ref': 'Neutral', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 5, 'hp_dice': '2d4', 'speed_walk_ft': 20, 'speed_fly_ft': 40, 'stat_block': {'STR': 4, 'DEX': 15, 'CON': 11, 'INT': 10, 'WIS': 10, 'CHA': 7}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Poisoned')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Construct Nature')], 'action_refs': [ref('creature-action', 'Bite (Homunculus)')]}),

      // ─── Gap closure: misc monstrosities, oozes, fey, fiends ─────────────
      packEntity(slug: 'monster', name: 'Ankheg', description: 'A burrowing insectoid predator that ambushes from beneath the soil.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 39, 'hp_dice': '6d10+6', 'speed_walk_ft': 30, 'speed_burrow_ft': 10, 'stat_block': {'STR': 17, 'DEX': 11, 'CON': 13, 'INT': 1, 'WIS': 13, 'CHA': 6}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}, {'sense': 'Tremorsense', 'range_ft': 60}], 'action_refs': [ref('creature-action', 'Bite (Ankheg)'), ref('creature-action', 'Acid Spray (Ankheg)')]}),
      packEntity(slug: 'monster', name: 'Awakened Shrub', description: 'A shrub given sentience by an awaken spell or fey magic.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Plant'), 'alignment_ref': 'Neutral', 'ac': 9, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 10, 'hp_dice': '3d6', 'speed_walk_ft': 20, 'stat_block': {'STR': 3, 'DEX': 8, 'CON': 11, 'INT': 10, 'WIS': 10, 'CHA': 6}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 10, 'vulnerability_refs': [lookup('damage-type', 'Fire')], 'resistance_refs': [lookup('damage-type', 'Piercing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Slam (Awakened Shrub)')]}),
      packEntity(slug: 'monster', name: 'Awakened Tree', description: 'A tree given sentience and the ability to move by an awaken spell.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Plant'), 'alignment_ref': 'Neutral', 'ac': 13, 'initiative_modifier': -2, 'initiative_score': 8, 'hp_average': 59, 'hp_dice': '7d12+14', 'speed_walk_ft': 20, 'stat_block': {'STR': 19, 'DEX': 6, 'CON': 15, 'INT': 10, 'WIS': 10, 'CHA': 7}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'vulnerability_refs': [lookup('damage-type', 'Fire')], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Slam (Awakened Tree)')]}),
      packEntity(slug: 'monster', name: 'Axe Beak', description: 'A flightless dinosaur with a powerful axe-shaped beak.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 50, 'stat_block': {'STR': 14, 'DEX': 12, 'CON': 12, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10, 'action_refs': [ref('creature-action', 'Beak (Axe Beak)')]}),
      packEntity(slug: 'monster', name: 'Behir', description: 'A serpentine beast with twelve legs and crackling lightning breath.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral Evil', 'ac': 17, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 168, 'hp_dice': '16d12+64', 'speed_walk_ft': 50, 'speed_climb_ft': 40, 'stat_block': {'STR': 23, 'DEX': 16, 'CON': 18, 'INT': 7, 'WIS': 14, 'CHA': 12}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 16, 'senses': [{'sense': 'Darkvision', 'range_ft': 90}], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'language_refs': [lookup('language', 'Draconic')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Behir)'), ref('creature-action', 'Lightning Breath (Behir)')]}),
      packEntity(slug: 'monster', name: 'Black Pudding', description: 'An amorphous black ooze that dissolves flesh and metal.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Ooze'), 'alignment_ref': 'Unaligned', 'ac': 7, 'initiative_modifier': -3, 'initiative_score': 7, 'hp_average': 85, 'hp_dice': '10d10+30', 'speed_walk_ft': 20, 'speed_climb_ft': 20, 'stat_block': {'STR': 16, 'DEX': 5, 'CON': 16, 'INT': 1, 'WIS': 6, 'CHA': 1}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Cold'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'action_refs': [ref('creature-action', 'Pseudopod (Black Pudding)')]}),
      packEntity(slug: 'monster', name: 'Blink Dog', description: 'A fey hound that can teleport short distances.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Lawful Good', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 22, 'hp_dice': '4d8+4', 'speed_walk_ft': 40, 'stat_block': {'STR': 12, 'DEX': 17, 'CON': 12, 'INT': 10, 'WIS': 13, 'CHA': 11}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 13, 'language_refs': [lookup('language', 'Sylvan')], 'action_refs': [ref('creature-action', 'Bite (Blink Dog)'), ref('creature-action', 'Teleport (Blink Dog)')]}),
      packEntity(slug: 'monster', name: 'Bulette', description: 'A burrowing predator that bursts from the ground to feast.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 94, 'hp_dice': '9d10+45', 'speed_walk_ft': 40, 'speed_burrow_ft': 40, 'stat_block': {'STR': 19, 'DEX': 11, 'CON': 21, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}, {'sense': 'Tremorsense', 'range_ft': 60}], 'action_refs': [ref('creature-action', 'Bite (Bulette)')]}),
      packEntity(slug: 'monster', name: 'Chimera', description: 'A monstrous beast with three heads — lion, goat, and dragon.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 114, 'hp_dice': '12d10+48', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'stat_block': {'STR': 19, 'DEX': 11, 'CON': 19, 'INT': 3, 'WIS': 14, 'CHA': 10}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 18, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Chimera)'), ref('creature-action', 'Fire Breath (Chimera)')]}),
      packEntity(slug: 'monster', name: 'Cloaker', description: 'An aberration resembling a black cloak that wraps around prey.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Aberration'), 'alignment_ref': 'Chaotic Neutral', 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 78, 'hp_dice': '12d10+12', 'speed_walk_ft': 10, 'speed_fly_ft': 40, 'stat_block': {'STR': 17, 'DEX': 15, 'CON': 12, 'INT': 13, 'WIS': 12, 'CHA': 14}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Deep Speech'), lookup('language', 'Undercommon')], 'trait_refs': [ref('trait', 'Damage Transfer'), ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Cloaker)'), ref('creature-action', 'Tail (Cloaker)'), ref('creature-action', 'Attach (Cloaker)')]}),
      packEntity(slug: 'monster', name: 'Darkmantle', description: 'A small aberration that mimics stalactites and drops on prey.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Aberration'), 'alignment_ref': 'Unaligned', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 22, 'hp_dice': '5d6+5', 'speed_walk_ft': 10, 'speed_fly_ft': 30, 'stat_block': {'STR': 16, 'DEX': 12, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Echolocation'), ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Tentacles (Darkmantle)')]}),
      packEntity(slug: 'monster', name: 'Doppelganger', description: 'A shapechanger able to take on the appearance of any humanoid.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 52, 'hp_dice': '8d8+16', 'speed_walk_ft': 30, 'stat_block': {'STR': 11, 'DEX': 18, 'CON': 14, 'INT': 11, 'WIS': 12, 'CHA': 14}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 11, 'condition_immunity_refs': [lookup('condition', 'Charmed')], 'language_refs': [lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Doppelganger)'), ref('creature-action', 'Read Thoughts (Doppelganger)')]}),
      packEntity(slug: 'monster', name: 'Dragon Turtle', description: 'An immense dragon-like turtle that breathes scalding steam.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Neutral', 'ac': 20, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 341, 'hp_dice': '22d20+110', 'speed_walk_ft': 20, 'speed_swim_ft': 40, 'stat_block': {'STR': 25, 'DEX': 10, 'CON': 20, 'INT': 10, 'WIS': 12, 'CHA': 12}, 'cr': '17', 'xp': 18000, 'proficiency_bonus': 6, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Primordial'), lookup('language', 'Draconic')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Dragon Turtle)'), ref('creature-action', 'Steam Breath (Dragon Turtle)')]}),
      packEntity(slug: 'monster', name: 'Drider', description: 'A drow transformed by Lolth into a monstrous spider-bodied creature.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 19, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 123, 'hp_dice': '13d10+52', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 16, 'DEX': 16, 'CON': 18, 'INT': 13, 'WIS': 14, 'CHA': 12}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 17, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'language_refs': [lookup('language', 'Elvish'), lookup('language', 'Undercommon')], 'trait_refs': [ref('trait', 'Sunlight Sensitivity'), ref('trait', 'Spider Climb'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Drider)'), ref('creature-action', 'Web Bite (Drider)')]}),
      packEntity(slug: 'monster', name: 'Ettercap', description: 'A spider-folk lurking in webs and silk-slung forests.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 44, 'hp_dice': '8d8+8', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 14, 'DEX': 15, 'CON': 13, 'INT': 7, 'WIS': 12, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Spider Climb'), ref('trait', 'Web Sense'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Ettercap)'), ref('creature-action', 'Web (Ettercap)')]}),
      packEntity(slug: 'monster', name: 'Gelatinous Cube', description: 'A transparent cube-shaped ooze that engulfs anything in its path.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Ooze'), 'alignment_ref': 'Unaligned', 'ac': 6, 'initiative_modifier': -4, 'initiative_score': 6, 'hp_average': 84, 'hp_dice': '8d10+40', 'speed_walk_ft': 15, 'stat_block': {'STR': 14, 'DEX': 3, 'CON': 20, 'INT': 1, 'WIS': 6, 'CHA': 1}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Prone')], 'trait_refs': [ref('trait', 'Ooze Cube')], 'action_refs': [ref('creature-action', 'Engulf (Gelatinous Cube)')]}),
      packEntity(slug: 'monster', name: 'Gibbering Mouther', description: 'A mass of mouths and eyes that drives onlookers to madness.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Aberration'), 'alignment_ref': 'Chaotic Neutral', 'ac': 9, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 67, 'hp_dice': '9d8+27', 'speed_walk_ft': 10, 'speed_swim_ft': 10, 'stat_block': {'STR': 10, 'DEX': 8, 'CON': 16, 'INT': 3, 'WIS': 10, 'CHA': 6}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'condition_immunity_refs': [lookup('condition', 'Prone')], 'action_refs': [ref('creature-action', 'Bites (Gibbering Mouther)')]}),
      packEntity(slug: 'monster', name: 'Gorgon', description: 'An iron-plated bull that breathes petrifying gas.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 19, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 114, 'hp_dice': '12d10+48', 'speed_walk_ft': 40, 'stat_block': {'STR': 20, 'DEX': 11, 'CON': 18, 'INT': 2, 'WIS': 12, 'CHA': 7}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'condition_immunity_refs': [lookup('condition', 'Petrified')], 'trait_refs': [ref('trait', 'Trampling Charge')], 'action_refs': [ref('creature-action', 'Gore (Gorgon)'), ref('creature-action', 'Petrifying Breath (Gorgon)')]}),
      packEntity(slug: 'monster', name: 'Gray Ooze', description: 'A stone-like ooze that corrodes metal and dissolves armor.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Ooze'), 'alignment_ref': 'Unaligned', 'ac': 9, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 22, 'hp_dice': '3d8+9', 'speed_walk_ft': 10, 'speed_climb_ft': 10, 'stat_block': {'STR': 12, 'DEX': 6, 'CON': 16, 'INT': 1, 'WIS': 6, 'CHA': 2}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'action_refs': [ref('creature-action', 'Pseudopod (Gray Ooze)')]}),
      packEntity(slug: 'monster', name: 'Grick', description: 'A tentacled wormlike subterranean predator.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral', 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 27, 'hp_dice': '6d8', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 14, 'DEX': 14, 'CON': 11, 'INT': 3, 'WIS': 14, 'CHA': 5}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'trait_refs': [ref('trait', 'Stone Camouflage')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Tentacles (Grick)'), ref('creature-action', 'Beak (Grick)')]}),
      packEntity(slug: 'monster', name: 'Griffon', description: 'An eagle-headed lion-bodied creature, fierce and noble.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 59, 'hp_dice': '7d10+21', 'speed_walk_ft': 30, 'speed_fly_ft': 80, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 2, 'WIS': 13, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 15, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Keen Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Beak (Griffon)'), ref('creature-action', 'Claws (Griffon)')]}),
      packEntity(slug: 'monster', name: 'Grimlock', description: 'A blind subterranean humanoid that hunts by sound and smell.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Humanoid'), 'alignment_ref': 'Neutral Evil', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 12, 'CON': 12, 'INT': 9, 'WIS': 8, 'CHA': 6}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}], 'condition_immunity_refs': [lookup('condition', 'Blinded')], 'language_refs': [lookup('language', 'Undercommon')], 'trait_refs': [ref('trait', 'Stone Camouflage')], 'action_refs': [ref('creature-action', 'Claws (Grimlock)'), ref('creature-action', 'Stone Axe (Grimlock)')]}),
      packEntity(slug: 'monster', name: 'Guardian Naga', description: 'A serpentine guardian of sacred sites, lawful and wise.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 18, 'initiative_modifier': 5, 'initiative_score': 15, 'hp_average': 127, 'hp_dice': '15d10+45', 'speed_walk_ft': 40, 'stat_block': {'STR': 19, 'DEX': 18, 'CON': 16, 'INT': 16, 'WIS': 19, 'CHA': 18}, 'cr': '10', 'xp': 5900, 'proficiency_bonus': 4, 'passive_perception': 18, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Rejuvenation')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Spear (Guardian Naga)'), ref('creature-action', 'Spit Poison (Guardian Naga)'), ref('creature-action', 'Constrict (Guardian Naga)')]}),
      packEntity(slug: 'monster', name: 'Half-Dragon', description: 'A creature with mixed humanoid and dragon ancestry.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Neutral', 'ac': 18, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 105, 'hp_dice': '14d8+42', 'speed_walk_ft': 40, 'stat_block': {'STR': 19, 'DEX': 13, 'CON': 17, 'INT': 12, 'WIS': 11, 'CHA': 14}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 13, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Half-Dragon)'), ref('creature-action', 'Breath Weapon (Half-Dragon)')]}),
      packEntity(slug: 'monster', name: 'Hell Hound', description: 'A fiendish dog with fiery breath, often hunting in packs.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Lawful Evil', 'ac': 15, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 45, 'hp_dice': '7d8+14', 'speed_walk_ft': 50, 'stat_block': {'STR': 17, 'DEX': 12, 'CON': 14, 'INT': 6, 'WIS': 13, 'CHA': 6}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 15, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Hell Hound)'), ref('creature-action', 'Fire Breath (Hell Hound)')]}),
      packEntity(slug: 'monster', name: 'Hippogriff', description: 'A horse-eagle hybrid, swift and territorial.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 40, 'speed_fly_ft': 60, 'stat_block': {'STR': 17, 'DEX': 13, 'CON': 13, 'INT': 2, 'WIS': 12, 'CHA': 8}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 15, 'trait_refs': [ref('trait', 'Keen Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Beak (Hippogriff)'), ref('creature-action', 'Claws (Hippogriff)')]}),
      packEntity(slug: 'monster', name: 'Kraken', description: 'A colossal sea-monster, demigod-like in power.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 18, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 481, 'hp_dice': '26d20+208', 'speed_walk_ft': 30, 'speed_swim_ft': 60, 'stat_block': {'STR': 30, 'DEX': 11, 'CON': 26, 'INT': 22, 'WIS': 18, 'CHA': 20}, 'cr': '23', 'xp': 50000, 'proficiency_bonus': 7, 'passive_perception': 18, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Lightning')], 'condition_immunity_refs': [lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Restrained')], 'language_refs': [lookup('language', 'Primordial'), lookup('language', 'Common')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Amphibious'), ref('trait', 'Legendary Resistance (3/Day, or 4/Day in Lair)'), ref('trait', 'Siege Monster')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Tentacles (Kraken)'), ref('creature-action', 'Lightning Storm (Kraken)')]}),
      packEntity(slug: 'monster', name: 'Lamia', description: 'A part-lion, part-humanoid fey-touched seductress.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 97, 'hp_dice': '13d10+26', 'speed_walk_ft': 30, 'stat_block': {'STR': 16, 'DEX': 13, 'CON': 15, 'INT': 14, 'WIS': 15, 'CHA': 16}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Innate Spellcasting (Lamia)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Lamia)'), ref('creature-action', 'Charm (Lamia)')]}),
      packEntity(slug: 'monster', name: 'Medusa', description: 'A serpent-haired humanoid whose gaze petrifies the living.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Lawful Evil', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 127, 'hp_dice': '17d8+51', 'speed_walk_ft': 30, 'stat_block': {'STR': 10, 'DEX': 15, 'CON': 16, 'INT': 12, 'WIS': 13, 'CHA': 15}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 150}], 'language_refs': [lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Snake Hair (Medusa)'), ref('creature-action', 'Petrifying Gaze (Medusa)')]}),
      packEntity(slug: 'monster', name: 'Mimic', description: 'A shapeshifting predator that disguises itself as everyday objects.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral', 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 58, 'hp_dice': '9d8+18', 'speed_walk_ft': 15, 'stat_block': {'STR': 17, 'DEX': 12, 'CON': 15, 'INT': 5, 'WIS': 13, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Acid')], 'condition_immunity_refs': [lookup('condition', 'Prone')], 'trait_refs': [ref('trait', 'Shapechanger (Werecreature)'), ref('trait', 'False Appearance')], 'action_refs': [ref('creature-action', 'Pseudopod (Mimic)')]}),
      packEntity(slug: 'monster', name: 'Minotaur of Baphomet', description: 'A bull-headed humanoid champion of Baphomet, Lord of Beasts.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Chaotic Evil', 'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 76, 'hp_dice': '9d10+27', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 11, 'CON': 16, 'INT': 6, 'WIS': 16, 'CHA': 9}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 17, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Abyssal')], 'trait_refs': [ref('trait', 'Charge')], 'action_refs': [ref('creature-action', 'Greataxe (Minotaur of Baphomet)')]}),
      packEntity(slug: 'monster', name: 'Nightmare', description: 'A demonic black steed with flaming hooves and mane.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 68, 'hp_dice': '8d10+24', 'speed_walk_ft': 60, 'speed_fly_ft': 90, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 10, 'WIS': 13, 'CHA': 15}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 11, 'damage_immunity_refs': [lookup('damage-type', 'Fire')], 'language_refs': [lookup('language', 'Infernal')], 'action_refs': [ref('creature-action', 'Hooves (Nightmare)')]}),
      packEntity(slug: 'monster', name: 'Ochre Jelly', description: 'A yellow ooze that splits when struck.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Ooze'), 'alignment_ref': 'Unaligned', 'ac': 8, 'initiative_modifier': -2, 'initiative_score': 8, 'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 10, 'speed_climb_ft': 10, 'stat_block': {'STR': 15, 'DEX': 6, 'CON': 14, 'INT': 2, 'WIS': 6, 'CHA': 1}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Lightning')], 'resistance_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Charmed'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'action_refs': [ref('creature-action', 'Pseudopod (Ochre Jelly)')]}),
      packEntity(slug: 'monster', name: 'Oni', description: 'A giant ogre-mage from feywild, a cunning shape-shifter.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Lawful Evil', 'ac': 16, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 110, 'hp_dice': '13d10+39', 'speed_walk_ft': 30, 'speed_fly_ft': 30, 'stat_block': {'STR': 19, 'DEX': 11, 'CON': 16, 'INT': 14, 'WIS': 12, 'CHA': 15}, 'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Giant')], 'trait_refs': [ref('trait', 'Regeneration')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Oni)'), ref('creature-action', 'Glaive (Oni)')]}),
      packEntity(slug: 'monster', name: 'Pegasus', description: 'A winged horse, noble and intelligent.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Chaotic Good', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 59, 'hp_dice': '7d10+21', 'speed_walk_ft': 60, 'speed_fly_ft': 90, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 10, 'WIS': 15, 'CHA': 13}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 16, 'language_refs': [lookup('language', 'Celestial')], 'action_refs': [ref('creature-action', 'Hooves (Pegasus)'), ref('creature-action', 'Wing Attack (Pegasus)')]}),
      packEntity(slug: 'monster', name: 'Phase Spider', description: 'A spider that flickers between the Material and Ethereal Plane.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 32, 'hp_dice': '5d10+5', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 15, 'DEX': 16, 'CON': 12, 'INT': 6, 'WIS': 10, 'CHA': 6}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Spider Climb'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Bite (Phase Spider)')]}),
      packEntity(slug: 'monster', name: 'Pseudodragon', description: 'A small, friendly draconic creature often kept as a familiar.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Neutral Good', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 7, 'hp_dice': '2d4+2', 'speed_walk_ft': 15, 'speed_fly_ft': 60, 'stat_block': {'STR': 6, 'DEX': 15, 'CON': 13, 'INT': 10, 'WIS': 12, 'CHA': 10}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Draconic')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Pseudodragon)'), ref('creature-action', 'Sting (Pseudodragon)')]}),
      packEntity(slug: 'monster', name: 'Purple Worm', description: 'A massive subterranean worm that swallows prey whole.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 18, 'initiative_modifier': -2, 'initiative_score': 8, 'hp_average': 247, 'hp_dice': '15d20+90', 'speed_walk_ft': 50, 'speed_burrow_ft': 30, 'stat_block': {'STR': 28, 'DEX': 7, 'CON': 22, 'INT': 1, 'WIS': 8, 'CHA': 4}, 'cr': '15', 'xp': 13000, 'proficiency_bonus': 5, 'passive_perception': 9, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}, {'sense': 'Tremorsense', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Tunneler')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Purple Worm)'), ref('creature-action', 'Tail Stinger (Purple Worm)')]}),
      packEntity(slug: 'monster', name: 'Rakshasa', description: 'A tiger-headed fiend that schemes from the shadows of high society.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Lawful Evil', 'ac': 16, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 110, 'hp_dice': '13d8+52', 'speed_walk_ft': 40, 'stat_block': {'STR': 14, 'DEX': 17, 'CON': 18, 'INT': 13, 'WIS': 16, 'CHA': 20}, 'cr': '13', 'xp': 10000, 'proficiency_bonus': 5, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Piercing')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Infernal')], 'trait_refs': [ref('trait', 'Innate Spellcasting (Rakshasa)'), ref('trait', 'Limited Magic Immunity')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claws (Rakshasa)')]}),
      packEntity(slug: 'monster', name: 'Remorhaz', description: 'A massive armored worm whose body radiates intense heat.', attributes: {'size_ref': 'Huge', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 195, 'hp_dice': '17d12+85', 'speed_walk_ft': 30, 'speed_burrow_ft': 20, 'stat_block': {'STR': 24, 'DEX': 13, 'CON': 21, 'INT': 4, 'WIS': 10, 'CHA': 5}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}, {'sense': 'Tremorsense', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire')], 'trait_refs': [ref('trait', 'Heated Body')], 'action_refs': [ref('creature-action', 'Bite (Remorhaz)')]}),
      packEntity(slug: 'monster', name: 'Roc', description: 'An immense bird of prey large enough to carry off elephants.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 15, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 248, 'hp_dice': '16d20+80', 'speed_walk_ft': 20, 'speed_fly_ft': 120, 'stat_block': {'STR': 28, 'DEX': 10, 'CON': 20, 'INT': 3, 'WIS': 10, 'CHA': 9}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 14, 'trait_refs': [ref('trait', 'Keen Sight')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Beak (Roc)'), ref('creature-action', 'Talons (Roc)')]}),
      packEntity(slug: 'monster', name: 'Rust Monster', description: 'A bug-like creature whose antennae corrode iron and steel.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 14, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 27, 'hp_dice': '5d8+5', 'speed_walk_ft': 40, 'stat_block': {'STR': 13, 'DEX': 12, 'CON': 13, 'INT': 2, 'WIS': 13, 'CHA': 6}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Iron Scent')], 'action_refs': [ref('creature-action', 'Bite (Rust Monster)')]}),
      packEntity(slug: 'monster', name: 'Satyr', description: 'A goat-legged fey reveler that loves music and mischief.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Chaotic Neutral', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 31, 'hp_dice': '7d8', 'speed_walk_ft': 40, 'stat_block': {'STR': 12, 'DEX': 16, 'CON': 11, 'INT': 12, 'WIS': 10, 'CHA': 14}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 12, 'language_refs': [lookup('language', 'Common'), lookup('language', 'Elvish'), lookup('language', 'Sylvan')], 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Ram (Satyr)')]}),
      packEntity(slug: 'monster', name: 'Seahorse', description: 'A tiny ocean creature; some legends call them lucky charms.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': 'Unaligned', 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 1, 'hp_dice': '1', 'speed_walk_ft': 0, 'speed_swim_ft': 20, 'stat_block': {'STR': 1, 'DEX': 12, 'CON': 8, 'INT': 1, 'WIS': 10, 'CHA': 2}, 'cr': '0', 'xp': 0, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Water Breathing (Animal)')], 'action_refs': [ref('creature-action', 'Bite (Seahorse)')]}),
      packEntity(slug: 'monster', name: 'Shambling Mound', description: 'A walking mass of vegetation that smothers and absorbs prey.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Plant'), 'alignment_ref': 'Unaligned', 'ac': 15, 'initiative_modifier': -1, 'initiative_score': 9, 'hp_average': 136, 'hp_dice': '16d10+48', 'speed_walk_ft': 30, 'speed_swim_ft': 20, 'stat_block': {'STR': 18, 'DEX': 8, 'CON': 16, 'INT': 5, 'WIS': 10, 'CHA': 5}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Lightning')], 'resistance_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Fire')], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Deafened'), lookup('condition', 'Exhaustion')], 'trait_refs': [ref('trait', 'Lightning Absorption')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Shambling Mound)'), ref('creature-action', 'Engulf (Shambling Mound)')]}),
      packEntity(slug: 'monster', name: 'Shrieker Fungus', description: 'A subterranean fungus that emits a piercing wail when disturbed.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Plant'), 'alignment_ref': 'Unaligned', 'ac': 5, 'initiative_modifier': -5, 'initiative_score': 5, 'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 0, 'stat_block': {'STR': 1, 'DEX': 1, 'CON': 10, 'INT': 1, 'WIS': 3, 'CHA': 1}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 6, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Deafened'), lookup('condition', 'Frightened')], 'action_refs': [ref('creature-action', 'Spores (Shrieker Fungus)')]}),
      packEntity(slug: 'monster', name: 'Solar', description: 'The mightiest of angels, paragons of celestial radiance.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 21, 'initiative_modifier': 6, 'initiative_score': 16, 'hp_average': 297, 'hp_dice': '22d10+176', 'speed_walk_ft': 50, 'speed_fly_ft': 150, 'can_hover': true, 'stat_block': {'STR': 26, 'DEX': 22, 'CON': 26, 'INT': 25, 'WIS': 25, 'CHA': 30}, 'cr': '21', 'xp': 33000, 'proficiency_bonus': 7, 'passive_perception': 24, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Poison'), lookup('damage-type', 'Radiant')], 'resistance_refs': [lookup('damage-type', 'Necrotic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons'), ref('trait', 'Legendary Resistance (3/Day)'), ref('trait', 'Divine Awareness')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Slam (Solar)'), ref('creature-action', 'Slaying Longbow (Solar)')]}),
      packEntity(slug: 'monster', name: 'Planetar', description: 'A righteous angelic warrior of the upper planes.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 19, 'initiative_modifier': 5, 'initiative_score': 15, 'hp_average': 200, 'hp_dice': '16d10+112', 'speed_walk_ft': 40, 'speed_fly_ft': 120, 'can_hover': true, 'stat_block': {'STR': 24, 'DEX': 20, 'CON': 24, 'INT': 19, 'WIS': 22, 'CHA': 25}, 'cr': '16', 'xp': 15000, 'proficiency_bonus': 5, 'passive_perception': 22, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Radiant')], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Mace (Planetar)')]}),
      packEntity(slug: 'monster', name: 'Deva', description: 'A messenger angel that carries the will of the gods.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 17, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 136, 'hp_dice': '16d8+64', 'speed_walk_ft': 30, 'speed_fly_ft': 90, 'can_hover': true, 'stat_block': {'STR': 18, 'DEX': 18, 'CON': 18, 'INT': 17, 'WIS': 20, 'CHA': 20}, 'cr': '10', 'xp': 5900, 'proficiency_bonus': 4, 'passive_perception': 19, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'resistance_refs': [lookup('damage-type', 'Radiant')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'telepathy_ft': 120, 'trait_refs': [ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Greatsword (Deva)')]}),
      packEntity(slug: 'monster', name: 'Sphinx of Lore', description: 'A guardian sphinx that prizes ancient knowledge above all.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Neutral', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 170, 'hp_dice': '20d10+60', 'speed_walk_ft': 40, 'speed_fly_ft': 60, 'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 18, 'WIS': 18, 'CHA': 18}, 'cr': '11', 'xp': 7200, 'proficiency_bonus': 4, 'passive_perception': 18, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Inscrutable'), ref('trait', 'Magic Weapons'), ref('trait', 'Sphinx Spellcasting')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claw (Sphinx)'), ref('creature-action', 'Roar (Sphinx of Lore)')]}),
      packEntity(slug: 'monster', name: 'Sphinx of Valor', description: 'A guardian sphinx that defends sacred sites with strength and prowess.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Neutral', 'ac': 17, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 199, 'hp_dice': '19d10+95', 'speed_walk_ft': 40, 'speed_fly_ft': 60, 'stat_block': {'STR': 22, 'DEX': 10, 'CON': 20, 'INT': 16, 'WIS': 18, 'CHA': 23}, 'cr': '17', 'xp': 18000, 'proficiency_bonus': 6, 'passive_perception': 20, 'senses': [{'sense': 'Truesight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Psychic')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Inscrutable'), ref('trait', 'Magic Weapons'), ref('trait', 'Legendary Resistance (3/Day)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Claw (Sphinx)'), ref('creature-action', 'Roar (Sphinx)')]}),
      packEntity(slug: 'monster', name: 'Sphinx of Wonder', description: 'A small playful sphinx, herald of curiosity and mystery.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 24, 'hp_dice': '7d4+7', 'speed_walk_ft': 20, 'speed_fly_ft': 40, 'stat_block': {'STR': 6, 'DEX': 17, 'CON': 13, 'INT': 15, 'WIS': 12, 'CHA': 11}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Psychic'), lookup('damage-type', 'Radiant')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Common')], 'action_refs': [ref('creature-action', 'Claws (Sphinx of Wonder)')]}),
      packEntity(slug: 'monster', name: 'Spirit Naga', description: 'An evil naga whose spite burns long after its body has been slain.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fiend'), 'alignment_ref': 'Chaotic Evil', 'ac': 15, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 75, 'hp_dice': '10d10+20', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 17, 'CON': 14, 'INT': 14, 'WIS': 15, 'CHA': 16}, 'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Abyssal'), lookup('language', 'Common')], 'trait_refs': [ref('trait', 'Rejuvenation')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Spirit Naga)'), ref('creature-action', 'Constrict (Spirit Naga)')]}),
      packEntity(slug: 'monster', name: 'Sprite', description: 'A tiny fey scout, armed with shortbow and heart-detection.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Neutral Good', 'ac': 15, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 10, 'hp_dice': '4d4', 'speed_walk_ft': 10, 'speed_fly_ft': 40, 'stat_block': {'STR': 3, 'DEX': 18, 'CON': 10, 'INT': 14, 'WIS': 13, 'CHA': 11}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 13, 'language_refs': [lookup('language', 'Common'), lookup('language', 'Elvish'), lookup('language', 'Sylvan')], 'action_refs': [ref('creature-action', 'Shortbow (Sprite)'), ref('creature-action', 'Touch (Sprite)')]}),
      packEntity(slug: 'monster', name: 'Tarrasque', description: 'A legendary apocalyptic beast capable of leveling cities.', attributes: {'size_ref': 'Gargantuan', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Unaligned', 'ac': 25, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 676, 'hp_dice': '33d20+330', 'speed_walk_ft': 40, 'stat_block': {'STR': 30, 'DEX': 11, 'CON': 30, 'INT': 3, 'WIS': 11, 'CHA': 11}, 'cr': '30', 'xp': 155000, 'proficiency_bonus': 9, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 120}], 'damage_immunity_refs': [lookup('damage-type', 'Fire'), lookup('damage-type', 'Poison')], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Paralyzed'), lookup('condition', 'Poisoned')], 'trait_refs': [ref('trait', 'Legendary Resistance (3/Day)'), ref('trait', 'Magic Resistance'), ref('trait', 'Magic Weapons'), ref('trait', 'Reflective Carapace'), ref('trait', 'Siege Monster')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Tarrasque)'), ref('creature-action', 'Swallow (Tarrasque)')]}),
      packEntity(slug: 'monster', name: 'Troll Limb', description: 'A severed troll limb that continues to fight on its own.', attributes: {'size_ref': 'Small', 'creature_type_ref': lookup('creature-type', 'Giant'), 'alignment_ref': 'Chaotic Evil', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 14, 'hp_dice': '4d6', 'speed_walk_ft': 20, 'stat_block': {'STR': 14, 'DEX': 13, 'CON': 12, 'INT': 1, 'WIS': 7, 'CHA': 1}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Giant')], 'trait_refs': [ref('trait', 'Regeneration')], 'action_refs': [ref('creature-action', 'Slam (Troll Limb)')]}),
      packEntity(slug: 'monster', name: 'Unicorn', description: 'A horse-shaped celestial steed that aids the worthy in fey forests.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Celestial'), 'alignment_ref': 'Lawful Good', 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 75, 'hp_dice': '10d10+20', 'speed_walk_ft': 50, 'stat_block': {'STR': 18, 'DEX': 14, 'CON': 15, 'INT': 11, 'WIS': 17, 'CHA': 16}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'damage_immunity_refs': [lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Paralyzed'), lookup('condition', 'Poisoned')], 'language_refs': [lookup('language', 'Celestial'), lookup('language', 'Elvish'), lookup('language', 'Sylvan')], 'telepathy_ft': 60, 'trait_refs': [ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Hooves (Unicorn)'), ref('creature-action', 'Horn (Unicorn)')]}),
      packEntity(slug: 'monster', name: 'Violet Fungus', description: 'A purple-streaked fungus that lashes with rotting tentacles.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Plant'), 'alignment_ref': 'Unaligned', 'ac': 5, 'initiative_modifier': -5, 'initiative_score': 5, 'hp_average': 18, 'hp_dice': '4d8', 'speed_walk_ft': 5, 'stat_block': {'STR': 3, 'DEX': 1, 'CON': 10, 'INT': 1, 'WIS': 3, 'CHA': 1}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 6, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}], 'condition_immunity_refs': [lookup('condition', 'Blinded'), lookup('condition', 'Deafened'), lookup('condition', 'Frightened')], 'action_refs': [ref('creature-action', 'Spores (Violet Fungus)')]}),
      packEntity(slug: 'monster', name: 'Winter Wolf', description: 'A large arctic wolf with a frigid breath weapon.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Monstrosity'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 75, 'hp_dice': '10d10+20', 'speed_walk_ft': 50, 'stat_block': {'STR': 18, 'DEX': 13, 'CON': 14, 'INT': 7, 'WIS': 12, 'CHA': 8}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 15, 'damage_immunity_refs': [lookup('damage-type', 'Cold')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Giant')], 'trait_refs': [ref('trait', 'Pack Tactics'), ref('trait', 'Snow Camouflage')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Winter Wolf)'), ref('creature-action', 'Cold Breath (Winter Wolf)')]}),
      packEntity(slug: 'monster', name: 'Worg', description: 'An evil wolflike beast that hunts goblins and other creatures.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Neutral Evil', 'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 26, 'hp_dice': '4d10+4', 'speed_walk_ft': 50, 'stat_block': {'STR': 16, 'DEX': 13, 'CON': 13, 'INT': 7, 'WIS': 11, 'CHA': 8}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 14, 'language_refs': [lookup('language', 'Goblin')], 'trait_refs': [ref('trait', 'Keen Hearing')], 'action_refs': [ref('creature-action', 'Bite (Worg)')]}),
      packEntity(slug: 'monster', name: 'Wyvern', description: 'A two-legged dragonkin with a venomous stinger tail.', attributes: {'size_ref': 'Large', 'creature_type_ref': lookup('creature-type', 'Dragon'), 'alignment_ref': 'Unaligned', 'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 110, 'hp_dice': '13d10+39', 'speed_walk_ft': 30, 'speed_fly_ft': 80, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 16, 'INT': 5, 'WIS': 12, 'CHA': 6}, 'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Draconic')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Wyvern)'), ref('creature-action', 'Stinger (Wyvern)')]}),
      packEntity(slug: 'monster', name: 'Xorn', description: 'A three-armed earth elemental that devours gems and metals.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Elemental'), 'alignment_ref': 'Neutral', 'ac': 19, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 73, 'hp_dice': '7d8+42', 'speed_walk_ft': 20, 'speed_burrow_ft': 20, 'stat_block': {'STR': 17, 'DEX': 10, 'CON': 22, 'INT': 11, 'WIS': 10, 'CHA': 11}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 16, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}, {'sense': 'Tremorsense', 'range_ft': 60}], 'language_refs': [lookup('language', 'Primordial')], 'trait_refs': [ref('trait', 'Earth Glide (Xorn)'), ref('trait', 'Stone Camouflage (Xorn)'), ref('trait', 'Treasure Sense')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Xorn)'), ref('creature-action', 'Claws (Xorn)')]}),
      packEntity(slug: 'monster', name: 'Banshee', description: 'The vengeful spirit of an elf maiden cursed to wail at the moment of death.', attributes: {'size_ref': 'Medium', 'creature_type_ref': lookup('creature-type', 'Undead'), 'alignment_ref': 'Chaotic Evil', 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 58, 'hp_dice': '13d8', 'speed_walk_ft': 5, 'speed_fly_ft': 40, 'can_hover': true, 'stat_block': {'STR': 1, 'DEX': 14, 'CON': 10, 'INT': 12, 'WIS': 11, 'CHA': 17}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Acid'), lookup('damage-type', 'Fire'), lookup('damage-type', 'Lightning'), lookup('damage-type', 'Thunder')], 'damage_immunity_refs': [lookup('damage-type', 'Cold'), lookup('damage-type', 'Necrotic'), lookup('damage-type', 'Poison')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Exhaustion'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Poisoned'), lookup('condition', 'Prone'), lookup('condition', 'Restrained')], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Elvish')], 'trait_refs': [ref('trait', 'Incorporeal Movement')], 'action_refs': [ref('creature-action', 'Corrupting Touch (Banshee)'), ref('creature-action', 'Horrifying Visage (Banshee)'), ref('creature-action', 'Wail (Banshee)')]}),
      packEntity(slug: 'monster', name: 'Pixie', description: 'A diminutive sprite of mischief and protection, no taller than a hand.', attributes: {'size_ref': 'Tiny', 'creature_type_ref': lookup('creature-type', 'Fey'), 'alignment_ref': 'Neutral Good', 'ac': 15, 'initiative_modifier': 5, 'initiative_score': 15, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 10, 'speed_fly_ft': 30, 'stat_block': {'STR': 2, 'DEX': 20, 'CON': 8, 'INT': 10, 'WIS': 14, 'CHA': 15}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 14, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'language_refs': [lookup('language', 'Common'), lookup('language', 'Elvish'), lookup('language', 'Sylvan')], 'trait_refs': [ref('trait', 'Innate Spellcasting (Pixie)'), ref('trait', 'Magic Resistance')], 'action_refs': [ref('creature-action', 'Superior Invisibility (Pixie)')]}),
    ];
