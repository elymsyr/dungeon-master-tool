// SRD 5.2.1 Animals (pp. 344–364). Animals share the monster stat-block
// shape but live under a separate slug so the Beast listing on p. 344
// filters cleanly. Sample shipped here: Wolf, Brown Bear. Full pass over
// the remaining ~75 animals is deferred — see plan.

import '_helpers.dart';

List<Map<String, dynamic>> srdAnimals() => [
      packEntity(
        slug: 'animal',
        name: 'Wolf',
        description:
            'A swift hunter with a haunting howl. Wolves run in packs and use coordination to bring down prey larger than themselves.',
        attributes: {
          'size_ref': lookup('size', 'Medium'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12,
          'initiative_modifier': 2,
          'initiative_score': 12,
          'hp_average': 11,
          'hp_dice': '2d8+2',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 12, 'DEX': 15, 'CON': 12, 'INT': 3, 'WIS': 12, 'CHA': 6,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'trait_refs': [
            ref('trait', 'Pack Tactics'),
            ref('trait', 'Keen Smell'),
            ref('trait', 'Keen Hearing'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Wolf)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Brown Bear',
        description:
            'A massive omnivore that wanders forests and mountain slopes, defending its territory with savage claws and a punishing bite.',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11,
          'initiative_modifier': 1,
          'initiative_score': 11,
          'hp_average': 34,
          'hp_dice': '4d10+12',
          'speed_walk_ft': 40,
          'speed_climb_ft': 30,
          'stat_block': {
            'STR': 19, 'DEX': 10, 'CON': 16, 'INT': 2, 'WIS': 13, 'CHA': 7,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'trait_refs': [ref('trait', 'Keen Smell')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Brown Bear)'),
            ref('creature-action', 'Claws (Brown Bear)'),
          ],
        },
      ),
    ];
