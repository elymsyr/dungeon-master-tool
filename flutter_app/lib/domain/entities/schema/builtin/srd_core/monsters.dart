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
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Aberration'),
          'alignment_ref': lookup('alignment', 'Lawful Evil'),
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
          'size_ref': lookup('size', 'Small'),
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'tags_line': '(goblinoid)',
          'alignment_ref': lookup('alignment', 'Chaotic Neutral'),
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
          'size_ref': lookup('size', 'Medium'),
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': lookup('alignment', 'Lawful Evil'),
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
          'size_ref': lookup('size', 'Medium'),
          'creature_type_ref': lookup('creature-type', 'Undead'),
          'alignment_ref': lookup('alignment', 'Neutral Evil'),
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

      // ─── Giant Spider (CR 1) ────────────────────────────────────────────
      packEntity(
        slug: 'monster',
        name: 'Giant Spider',
        description:
            'A horse-sized arachnid that lurks in caves, jungle canopies, and the corners of haunted ruins. Its venom paralyzes prey.',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
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
    ];
