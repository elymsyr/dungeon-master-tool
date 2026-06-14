// SRD 5.2.1 Animals (pp. 344–364). Animals share the monster stat-block
// shape but live under a separate slug so the Beast listing on p. 344
// filters cleanly. Full roster (97 Beasts) shipped. Each card carries a
// complete player-facing Markdown `description` (flavour intro + ###
// Statistics + ### Traits + ### Actions, with trait/action prose inlined
// from traits.dart / creature_actions.dart) so the creature is fully
// readable without the engine — Phase-3 Wave-1 description enrichment.

import '_helpers.dart';

List<Map<String, dynamic>> srdAnimals() => [
      packEntity(
        slug: 'animal',
        name: 'Wolf',
        description: r'''A swift hunter with a haunting howl. Wolves run in packs and use coordination to bring down prey larger than themselves.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 11 (2d8+2)
- **Speed** walk 40 ft.
- **STR** 12 (+1) · **DEX** 15 (+2) · **CON** 12 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Piercing damage. If the target is a Large or smaller creature, it must succeed on a DC 11 Strength save or have the Prone condition.''',
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
        name: 'Giant Eagle',
        description: r'''A noble raptor of mountain heights, larger than a horse and intelligent enough to speak in Auran and Common.

### Statistics
- **Large Beast**, Neutral Good
- **AC** 13 · **HP** 26 (4d10+4)
- **Speed** walk 10 ft., fly 80 ft.
- **STR** 16 (+3) · **DEX** 17 (+3) · **CON** 13 (+1) · **INT** 8 (-1) · **WIS** 14 (+2) · **CHA** 10 (+0)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 16
- **Languages** Common

### Traits
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Talons.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Neutral Good'),
          'ac': 13,
          'initiative_modifier': 3,
          'initiative_score': 13,
          'hp_average': 26,
          'hp_dice': '4d10+4',
          'speed_walk_ft': 10,
          'speed_fly_ft': 80,
          'stat_block': {
            'STR': 16, 'DEX': 17, 'CON': 13, 'INT': 8, 'WIS': 14, 'CHA': 10,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 16,
          'language_refs': [lookup('language', 'Common')],
          'trait_refs': [ref('trait', 'Keen Sight')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Talons (Giant Eagle)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Dire Wolf',
        description: r'''A wolf as large as a riding horse, with a shaggy coat and bone-crushing jaws. Dire wolves run in packs and are favored mounts of goblin chiefs.

### Statistics
- **Large Beast**, Unaligned
- **AC** 14 · **HP** 22 (3d10+6)
- **Speed** walk 50 ft.
- **STR** 17 (+3) · **DEX** 15 (+2) · **CON** 15 (+2) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage. If the target is a Large or smaller creature, it must succeed on a DC 13 Strength save or have the Prone condition.''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 14,
          'initiative_modifier': 2,
          'initiative_score': 12,
          'hp_average': 22,
          'hp_dice': '3d10+6',
          'speed_walk_ft': 50,
          'stat_block': {
            'STR': 17, 'DEX': 15, 'CON': 15, 'INT': 3, 'WIS': 12, 'CHA': 7,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'trait_refs': [
            ref('trait', 'Pack Tactics'),
            ref('trait', 'Keen Smell'),
            ref('trait', 'Keen Hearing'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Dire Wolf)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Tiger',
        description: r'''A solitary apex predator of jungles and grasslands. The tiger stalks prey from cover, then pounces with terrible speed.

### Statistics
- **Large Beast**, Unaligned
- **AC** 13 · **HP** 30 (4d10+8)
- **Speed** walk 40 ft.
- **STR** 17 (+3) · **DEX** 16 (+3) · **CON** 14 (+2) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 8 (-1)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 60 ft.

### Traits
- **Pounce.** If the creature moves at least 20 feet straight toward a creature and then hits it with a Claws attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Bite attack against it as a Bonus Action.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (1d10 + 3) Piercing damage.

### Bonus Actions
- **Claws.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13,
          'initiative_modifier': 3,
          'initiative_score': 13,
          'hp_average': 30,
          'hp_dice': '4d10+8',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 17, 'DEX': 16, 'CON': 14, 'INT': 3, 'WIS': 12, 'CHA': 8,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'senses': [
            {'sense': 'Darkvision', 'range_ft': 60},
          ],
          'trait_refs': [ref('trait', 'Pounce')],
          'action_refs': [
            ref('creature-action', 'Bite (Tiger)'),
          ],
          'bonus_action_refs': [
            ref('creature-action', 'Claws (Tiger)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Lion',
        description: r'''The royal predator of the savanna, hunting in coordinated prides. A lion charges from cover and uses its weight to pin prey.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 26 (4d10+4)
- **Speed** walk 50 ft.
- **STR** 17 (+3) · **DEX** 15 (+2) · **CON** 13 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 8 (-1)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.
- **Pounce.** If the creature moves at least 20 feet straight toward a creature and then hits it with a Claws attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Bite attack against it as a Bonus Action.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Running Leap.** With a 10-foot running start, the creature can long jump up to 25 feet.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12,
          'initiative_modifier': 2,
          'initiative_score': 12,
          'hp_average': 26,
          'hp_dice': '4d10+4',
          'speed_walk_ft': 50,
          'stat_block': {
            'STR': 17, 'DEX': 15, 'CON': 13, 'INT': 3, 'WIS': 12, 'CHA': 8,
          },
          'cr': '1',
          'xp': 200,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'trait_refs': [
            ref('trait', 'Pack Tactics'),
            ref('trait', 'Pounce'),
            ref('trait', 'Keen Smell'),
            ref('trait', 'Running Leap'),
          ],
          'action_refs': [
            ref('creature-action', 'Bite (Lion)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Crocodile',
        description: r'''A scaled ambush predator of rivers and swamps, dragging its prey beneath the water to drown.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 19 (3d10+3)
- **Speed** walk 20 ft., swim 30 ft.
- **STR** 15 (+2) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Hold Breath.** The creature can hold its breath for 15 minutes.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage, and the target has the Grappled condition (escape DC 12).''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12,
          'initiative_modifier': 0,
          'initiative_score': 10,
          'hp_average': 19,
          'hp_dice': '3d10+3',
          'speed_walk_ft': 20,
          'speed_swim_ft': 30,
          'stat_block': {
            'STR': 15, 'DEX': 10, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 5,
          },
          'cr': '1/2',
          'xp': 100,
          'proficiency_bonus': 2,
          'passive_perception': 10,
          'trait_refs': [ref('trait', 'Hold Breath')],
          'action_refs': [
            ref('creature-action', 'Bite (Crocodile)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Boar',
        description: r'''A bristly forest pig with sharp tusks. Boars charge straight at threats and gore them with surprising power.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 11 · **HP** 11 (2d8+2)
- **Speed** walk 40 ft.
- **STR** 13 (+1) · **DEX** 11 (+0) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 9 (-1) · **CHA** 5 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.

### Actions
- **Tusk.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Slashing damage. If the boar moved 20+ ft. straight toward the target before the hit, the damage is increased by 3 (1d6) and the target must succeed on a DC 11 Strength save or have the Prone condition.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11,
          'initiative_modifier': 0,
          'initiative_score': 10,
          'hp_average': 11,
          'hp_dice': '2d8+2',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 13, 'DEX': 11, 'CON': 12, 'INT': 2, 'WIS': 9, 'CHA': 5,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 9,
          'trait_refs': [ref('trait', 'Charge')],
          'action_refs': [
            ref('creature-action', 'Tusk (Boar)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Mastiff',
        description: r'''A large hunting hound, loyal and fierce. Mastiffs are favored as guard dogs and battlefield companions.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 5 (1d8+1)
- **Speed** walk 40 ft.
- **STR** 13 (+1) · **DEX** 14 (+2) · **CON** 12 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage. If the target is a Medium or smaller creature, it must succeed on a DC 11 Strength save or have the Prone condition.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12,
          'initiative_modifier': 2,
          'initiative_score': 12,
          'hp_average': 5,
          'hp_dice': '1d8+1',
          'speed_walk_ft': 40,
          'stat_block': {
            'STR': 13, 'DEX': 14, 'CON': 12, 'INT': 3, 'WIS': 12, 'CHA': 7,
          },
          'cr': '1/8',
          'xp': 25,
          'proficiency_bonus': 2,
          'passive_perception': 13,
          'trait_refs': [ref('trait', 'Keen Hearing'), ref('trait', 'Keen Smell')],
          'action_refs': [
            ref('creature-action', 'Bite (Mastiff)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Riding Horse',
        description: r'''A common steed bred for endurance and steadiness in travel. Most adventurers acquire one for the road.

### Statistics
- **Large Beast**, Unaligned
- **AC** 10 · **HP** 13 (2d10+2)
- **Speed** walk 60 ft.
- **STR** 16 (+3) · **DEX** 10 (+0) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 7 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Actions
- **Hooves.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 6 (2d4 + 1) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'),
          'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 10,
          'initiative_modifier': 0,
          'initiative_score': 10,
          'hp_average': 13,
          'hp_dice': '2d10+2',
          'speed_walk_ft': 60,
          'stat_block': {
            'STR': 16, 'DEX': 10, 'CON': 12, 'INT': 2, 'WIS': 11, 'CHA': 7,
          },
          'cr': '1/4',
          'xp': 50,
          'proficiency_bonus': 2,
          'passive_perception': 10,
          'action_refs': [
            ref('creature-action', 'Hooves (Riding Horse)'),
          ],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Cat',
        description: r'''A common house cat, swift and aloof.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 12 · **HP** 2 (1d4)
- **Speed** walk 40 ft., climb 30 ft.
- **STR** 3 (-4) · **DEX** 15 (+2) · **CON** 10 (+0) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 2, 'hp_dice': '1d4', 'speed_walk_ft': 40, 'speed_climb_ft': 30,
          'stat_block': {'STR': 3, 'DEX': 15, 'CON': 10, 'INT': 3, 'WIS': 12, 'CHA': 7},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13,
          'trait_refs': [ref('trait', 'Keen Smell')],
          'action_refs': [ref('creature-action', 'Bite (Cat)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Rat',
        description: r'''A small disease-carrying rodent of city sewers and old grain stores.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 10 · **HP** 1 (1d4-1)
- **Speed** walk 20 ft.
- **STR** 2 (-4) · **DEX** 11 (+0) · **CON** 9 (-1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Darkvision 30 ft.

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 20,
          'stat_block': {'STR': 2, 'DEX': 11, 'CON': 9, 'INT': 2, 'WIS': 10, 'CHA': 4},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'trait_refs': [ref('trait', 'Keen Smell')],
          'action_refs': [ref('creature-action', 'Bite (Rat)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Giant Rat',
        description: r'''A wolf-sized rodent with mangy fur and yellowed teeth, found in dungeons and sewers.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 7 (2d6)
- **Speed** walk 30 ft.
- **STR** 7 (-2) · **DEX** 15 (+2) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Darkvision 60 ft.

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 7, 'hp_dice': '2d6', 'speed_walk_ft': 30,
          'stat_block': {'STR': 7, 'DEX': 15, 'CON': 11, 'INT': 2, 'WIS': 10, 'CHA': 4},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'trait_refs': [ref('trait', 'Keen Smell'), ref('trait', 'Pack Tactics')],
          'action_refs': [ref('creature-action', 'Bite (Giant Rat)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Hawk',
        description: r'''A small raptor with keen eyes, common to many lands.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 13 · **HP** 1 (1d4-1)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 5 (-3) · **DEX** 16 (+3) · **CON** 8 (-1) · **INT** 2 (-4) · **WIS** 14 (+2) · **CHA** 6 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14

### Traits
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.

### Actions
- **Talons.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 1 Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 10, 'speed_fly_ft': 60,
          'stat_block': {'STR': 5, 'DEX': 16, 'CON': 8, 'INT': 2, 'WIS': 14, 'CHA': 6},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 14,
          'trait_refs': [ref('trait', 'Keen Sight')],
          'action_refs': [ref('creature-action', 'Talons (Hawk)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Eagle',
        description: r'''A keen-eyed bird of prey of mountains and open lands.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 3 (1d6)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 6 (-2) · **DEX** 15 (+2) · **CON** 10 (+0) · **INT** 2 (-4) · **WIS** 14 (+2) · **CHA** 7 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14

### Traits
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.

### Actions
- **Talons.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 3, 'hp_dice': '1d6', 'speed_walk_ft': 10, 'speed_fly_ft': 60,
          'stat_block': {'STR': 6, 'DEX': 15, 'CON': 10, 'INT': 2, 'WIS': 14, 'CHA': 7},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 14,
          'trait_refs': [ref('trait', 'Keen Sight')],
          'action_refs': [ref('creature-action', 'Talons (Eagle)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Owl',
        description: r'''A nocturnal raptor that hunts in silence.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 11 · **HP** 1 (1d4-1)
- **Speed** walk 5 ft., fly 60 ft.
- **STR** 3 (-4) · **DEX** 13 (+1) · **CON** 8 (-1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 120 ft.

### Traits
- **Flyby.** The creature doesn't provoke Opportunity Attacks when it flies out of an enemy's reach.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.

### Actions
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 1 Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 5, 'speed_fly_ft': 60,
          'stat_block': {'STR': 3, 'DEX': 13, 'CON': 8, 'INT': 2, 'WIS': 12, 'CHA': 7},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13,
          'senses': [{'sense': 'Darkvision', 'range_ft': 120}],
          'trait_refs': [ref('trait', 'Flyby'), ref('trait', 'Keen Hearing'), ref('trait', 'Keen Sight')],
          'action_refs': [ref('creature-action', 'Bite (Owl)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Pony',
        description: r'''A small horse breed favored by halflings and gnomes.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 11 (2d8+2)
- **Speed** walk 40 ft.
- **STR** 15 (+2) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 7 (-2)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 40,
          'stat_block': {'STR': 15, 'DEX': 10, 'CON': 13, 'INT': 2, 'WIS': 11, 'CHA': 7},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10,
          'action_refs': [ref('creature-action', 'Bite (Pony)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Camel',
        description: r'''A hardy desert beast of burden capable of many days without water.

### Statistics
- **Large Beast**, Unaligned
- **AC** 9 · **HP** 15 (2d10+4)
- **Speed** walk 50 ft.
- **STR** 16 (+3) · **DEX** 8 (-1) · **CON** 14 (+2) · **INT** 2 (-4) · **WIS** 8 (-1) · **CHA** 5 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 9, 'initiative_modifier': -1, 'initiative_score': 9,
          'hp_average': 15, 'hp_dice': '2d10+4', 'speed_walk_ft': 50,
          'stat_block': {'STR': 16, 'DEX': 8, 'CON': 14, 'INT': 2, 'WIS': 8, 'CHA': 5},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 9,
          'action_refs': [ref('creature-action', 'Bite (Camel)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Elephant',
        description: r'''A massive grass-eating mammal that defends its herd with charging tusks.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 12 · **HP** 76 (8d12+24)
- **Speed** walk 40 ft.
- **STR** 22 (+6) · **DEX** 9 (-1) · **CON** 17 (+3) · **INT** 3 (-4) · **WIS** 11 (+0) · **CHA** 6 (-2)
- **CR** 4 (1100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.
- **Siege Monster.** The creature deals double damage to objects and structures.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Stomp.** *Melee Attack Roll:* +8, reach 5 ft. (only against creature that is Prone). *Hit:* 22 (3d10 + 6) Bludgeoning damage.
- **Gore.** *Melee Attack Roll:* +8, reach 5 ft. *Hit:* 19 (3d8 + 6) Piercing damage. If the elephant moved 20+ ft. straight toward the target before the hit, the target takes an extra 9 (2d8) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 76, 'hp_dice': '8d12+24', 'speed_walk_ft': 40,
          'stat_block': {'STR': 22, 'DEX': 9, 'CON': 17, 'INT': 3, 'WIS': 11, 'CHA': 6},
          'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 10,
          'trait_refs': [ref('trait', 'Charge'), ref('trait', 'Siege Monster')],
          'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Stomp (Elephant)'), ref('creature-action', 'Gore (Elephant)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Ape',
        description: r'''A great forest ape that lives in family bands and defends its territory with thrown rocks.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 19 (3d8+6)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 16 (+3) · **DEX** 14 (+2) · **CON** 14 (+2) · **INT** 6 (-2) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Fist.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage.
- **Rock.** *Ranged Attack Roll:* +5, range 25/50 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 19, 'hp_dice': '3d8+6', 'speed_walk_ft': 30, 'speed_climb_ft': 30,
          'stat_block': {'STR': 16, 'DEX': 14, 'CON': 14, 'INT': 6, 'WIS': 12, 'CHA': 7},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 13,
          'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Fist (Ape)'), ref('creature-action', 'Rock (Ape)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Constrictor Snake',
        description: r'''A large serpent that subdues prey by squeezing it to death.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 13 (2d10+2)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 15 (+2) · **DEX** 14 (+2) · **CON** 12 (+1) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Blindsight 10 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.
- **Constrict.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage. The target has the Grappled condition (escape DC 14) and the Restrained condition until the grapple ends.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 13, 'hp_dice': '2d10+2', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 15, 'DEX': 14, 'CON': 12, 'INT': 1, 'WIS': 10, 'CHA': 3},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Blindsight', 'range_ft': 10}],
          'action_refs': [ref('creature-action', 'Bite (Constrictor)'), ref('creature-action', 'Constrict (Constrictor)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Giant Constrictor Snake',
        description: r'''An enormous serpent capable of crushing the largest prey.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 12 · **HP** 60 (8d12+8)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 19 (+4) · **DEX** 14 (+2) · **CON** 12 (+1) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Blindsight 10 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 10 ft. *Hit:* 8 (1d8 + 4) Piercing damage plus 10 (3d6) Poison damage. The target must succeed on a DC 11 Con save or be Poisoned for 1 hour.
- **Constrict.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage. The target has the Grappled condition (escape DC 14) and the Restrained condition until the grapple ends.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 60, 'hp_dice': '8d12+8', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 19, 'DEX': 14, 'CON': 12, 'INT': 1, 'WIS': 10, 'CHA': 3},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Blindsight', 'range_ft': 10}],
          'action_refs': [ref('creature-action', 'Bite (Giant Snake)'), ref('creature-action', 'Constrict (Constrictor)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Frog',
        description: r'''A small amphibian found in marshes and ponds.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 11 · **HP** 1 (1d4-1)
- **Speed** walk 20 ft., swim 20 ft.
- **STR** 1 (-5) · **DEX** 13 (+1) · **CON** 8 (-1) · **INT** 1 (-5) · **WIS** 8 (-1) · **CHA** 3 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Darkvision 30 ft.

### Traits
- **Amphibious.** The creature can breathe air and water.
- **Standing Leap.** The creature's long jump is up to 30 feet and its high jump is up to 15 feet, with or without a running start.

### Actions
- **Bite.** *Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 20, 'speed_swim_ft': 20,
          'stat_block': {'STR': 1, 'DEX': 13, 'CON': 8, 'INT': 1, 'WIS': 8, 'CHA': 3},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 9,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'trait_refs': [ref('trait', 'Amphibious'), ref('trait', 'Standing Leap')],
          'action_refs': [ref('creature-action', 'Bite (Frog)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Giant Frog',
        description: r'''A horse-sized frog that lurks in fetid pools, swallowing prey whole.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 11 · **HP** 18 (4d8)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 12 (+1) · **DEX** 13 (+1) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Darkvision 30 ft.

### Traits
- **Amphibious.** The creature can breathe air and water.
- **Standing Leap.** The creature's long jump is up to 30 feet and its high jump is up to 15 feet, with or without a running start.

### Actions
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage. The target has the Grappled condition (escape DC 11). Until the grapple ends, the target is also Restrained.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 18, 'hp_dice': '4d8', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 12, 'DEX': 13, 'CON': 11, 'INT': 2, 'WIS': 10, 'CHA': 3},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'trait_refs': [ref('trait', 'Amphibious'), ref('trait', 'Standing Leap')],
          'action_refs': [ref('creature-action', 'Bite (Giant Frog)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Giant Centipede',
        description: r'''A car-sized arthropod with venomous bite, lurking in dark caves.

### Statistics
- **Small Beast**, Unaligned
- **AC** 13 · **HP** 4 (1d6+1)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 5 (-3) · **DEX** 14 (+2) · **CON** 12 (+1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 3 (-4)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Blindsight 30 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 10 (3d6) Poison damage. The target must succeed on a DC 11 Con save or be Poisoned for 1 hour.''',
        attributes: {
          'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 4, 'hp_dice': '1d6+1', 'speed_walk_ft': 30, 'speed_climb_ft': 30,
          'stat_block': {'STR': 5, 'DEX': 14, 'CON': 12, 'INT': 1, 'WIS': 7, 'CHA': 3},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 8,
          'senses': [{'sense': 'Blindsight', 'range_ft': 30}],
          'action_refs': [ref('creature-action', 'Bite (Giant Centipede)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Giant Lizard',
        description: r'''A donkey-sized reptile, often used as a mount or beast of burden in the Underdark.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 19 (3d10+3)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 15 (+2) · **DEX** 12 (+1) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Darkvision 30 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 30, 'speed_climb_ft': 30,
          'stat_block': {'STR': 15, 'DEX': 12, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 5},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'action_refs': [ref('creature-action', 'Bite (Giant Lizard)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Polar Bear',
        description: r'''A massive white bear of arctic regions, hunting seals and the unwary.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 42 (5d10+15)
- **Speed** walk 40 ft., swim 30 ft.
- **STR** 20 (+5) · **DEX** 10 (+0) · **CON** 16 (+3) · **INT** 2 (-4) · **WIS** 13 (+1) · **CHA** 7 (-2)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Snow Camouflage.** The creature has Advantage on Dexterity (Stealth) checks made to hide in snowy terrain.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +7, reach 5 ft. *Hit:* 9 (1d8 + 5) Piercing damage.
- **Claws.** *Melee Attack Roll:* +7, reach 5 ft. *Hit:* 12 (2d6 + 5) Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 42, 'hp_dice': '5d10+15', 'speed_walk_ft': 40, 'speed_swim_ft': 30,
          'stat_block': {'STR': 20, 'DEX': 10, 'CON': 16, 'INT': 2, 'WIS': 13, 'CHA': 7},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 13,
          'trait_refs': [ref('trait', 'Keen Smell'), ref('trait', 'Snow Camouflage')],
          'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Polar Bear)'), ref('creature-action', 'Claws (Polar Bear)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Warhorse',
        description: r'''A heavy horse trained for battle, faster and more aggressive than a riding horse.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 19 (3d10+3)
- **Speed** walk 60 ft.
- **STR** 18 (+4) · **DEX** 12 (+1) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.

### Actions
- **Hooves.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 60,
          'stat_block': {'STR': 18, 'DEX': 12, 'CON': 13, 'INT': 2, 'WIS': 12, 'CHA': 7},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 11,
          'trait_refs': [ref('trait', 'Charge')],
          'action_refs': [ref('creature-action', 'Hooves (Warhorse)')],
        },
      ),
      packEntity(
        slug: 'animal', name: 'Octopus',
        description: r'''A small cephalopod with sucker-tipped tentacles, capable of squeezing through the smallest gaps.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 3 (1d6)
- **Speed** walk 5 ft., swim 30 ft.
- **STR** 4 (-3) · **DEX** 15 (+2) · **CON** 11 (+0) · **INT** 3 (-4) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Darkvision 30 ft.

### Traits
- **Hold Breath.** The creature can hold its breath for 15 minutes.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 3, 'hp_dice': '1d6', 'speed_walk_ft': 5, 'speed_swim_ft': 30,
          'stat_block': {'STR': 4, 'DEX': 15, 'CON': 11, 'INT': 3, 'WIS': 10, 'CHA': 4},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'trait_refs': [ref('trait', 'Hold Breath')],
          'action_refs': [ref('creature-action', 'Bite (Octopus)')],
        },
      ),
      packEntity(
        slug: 'animal',
        name: 'Brown Bear',
        description: r'''A massive omnivore that wanders forests and mountain slopes, defending its territory with savage claws and a punishing bite.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 34 (4d10+12)
- **Speed** walk 40 ft., climb 30 ft.
- **STR** 19 (+4) · **DEX** 10 (+0) · **CON** 16 (+3) · **INT** 2 (-4) · **WIS** 13 (+1) · **CHA** 7 (-2)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage.
- **Claws.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage.''',
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

      // ─── Tyrannosaurus Rex (CR 8) ────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Tyrannosaurus Rex',
        description: r'''A colossal apex predator dinosaur with massive jaws and surprisingly small forelimbs.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 13 · **HP** 136 (13d12+52)
- **Speed** walk 50 ft.
- **STR** 25 (+7) · **DEX** 10 (+0) · **CON** 19 (+4) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 9 (-1)
- **CR** 8 (3900 XP) · **Proficiency Bonus** +3 · **Passive Perception** 14

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +10, reach 10 ft. *Hit:* 33 (4d12 + 7) Piercing damage. If the target is a Medium or smaller creature, it has the Grappled condition (escape DC 17). The T-Rex can grapple only one target at a time.
- **Tail.** *Melee Attack Roll:* +10, reach 10 ft. *Hit:* 20 (3d8 + 7) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 136, 'hp_dice': '13d12+52', 'speed_walk_ft': 50,
          'stat_block': {'STR': 25, 'DEX': 10, 'CON': 19, 'INT': 2, 'WIS': 12, 'CHA': 9},
          'cr': '8', 'xp': 3900, 'proficiency_bonus': 3, 'passive_perception': 14,
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (T-Rex)'),
            ref('creature-action', 'Tail (T-Rex)'),
          ],
        },
      ),

      // ─── Triceratops (CR 5) ──────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Triceratops',
        description: r'''A heavy-bodied herbivorous dinosaur with three horns and a bony frill protecting its neck.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 13 · **HP** 95 (10d12+30)
- **Speed** walk 50 ft.
- **STR** 22 (+6) · **DEX** 9 (-1) · **CON** 17 (+3) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 5 (-3)
- **CR** 5 (1800 XP) · **Proficiency Bonus** +3 · **Passive Perception** 10

### Traits
- **Trampling Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Stomp attack against it as a Bonus Action.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Gore.** *Melee Attack Roll:* +9, reach 5 ft. *Hit:* 24 (4d8 + 6) Piercing damage.
- **Stomp.** *Melee Attack Roll:* +9, reach 5 ft, one Prone creature. *Hit:* 17 (2d10 + 6) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 95, 'hp_dice': '10d12+30', 'speed_walk_ft': 50,
          'stat_block': {'STR': 22, 'DEX': 9, 'CON': 17, 'INT': 2, 'WIS': 11, 'CHA': 5},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10,
          'trait_refs': [ref('trait', 'Trampling Charge')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Gore (Triceratops)'),
            ref('creature-action', 'Stomp (Triceratops)'),
          ],
        },
      ),

      // ─── Allosaurus (CR 2) ───────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Allosaurus',
        description: r'''A swift bipedal predator dinosaur, smaller than a tyrannosaurus but no less savage.

### Statistics
- **Large Beast**, Unaligned
- **AC** 13 · **HP** 51 (6d10+18)
- **Speed** walk 60 ft.
- **STR** 19 (+4) · **DEX** 13 (+1) · **CON** 17 (+3) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 15

### Traits
- **Pounce.** If the creature moves at least 20 feet straight toward a creature and then hits it with a Claws attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Bite attack against it as a Bonus Action.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 15 (2d10 + 4) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 51, 'hp_dice': '6d10+18', 'speed_walk_ft': 60,
          'stat_block': {'STR': 19, 'DEX': 13, 'CON': 17, 'INT': 2, 'WIS': 12, 'CHA': 5},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 15,
          'trait_refs': [ref('trait', 'Pounce')],
          'action_refs': [
            ref('creature-action', 'Multiattack'),
            ref('creature-action', 'Bite (Allosaurus)'),
          ],
        },
      ),

      // ─── Pteranodon (CR 1/4) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Pteranodon',
        description: r'''A flying reptile with a long beak and a wingspan greater than a Medium humanoid is tall.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 13 (3d8)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 12 (+1) · **DEX** 15 (+2) · **CON** 10 (+0) · **INT** 2 (-4) · **WIS** 9 (-1) · **CHA** 5 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9

### Traits
- **Flyby.** The creature doesn't provoke Opportunity Attacks when it flies out of an enemy's reach.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 10, 'speed_fly_ft': 60,
          'stat_block': {'STR': 12, 'DEX': 15, 'CON': 10, 'INT': 2, 'WIS': 9, 'CHA': 5},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 9,
          'trait_refs': [ref('trait', 'Flyby')],
          'action_refs': [
            ref('creature-action', 'Bite (Pteranodon)'),
          ],
        },
      ),

      // ─── Plesiosaurus (CR 2) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Plesiosaurus',
        description: r'''A long-necked aquatic reptile that hunts the deep waters of prehistoric seas.

### Statistics
- **Large Beast**, Unaligned
- **AC** 13 · **HP** 68 (8d10+24)
- **Speed** walk 20 ft., swim 40 ft.
- **STR** 18 (+4) · **DEX** 15 (+2) · **CON** 16 (+3) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 15

### Traits
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 10 ft. *Hit:* 14 (3d6 + 4) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 68, 'hp_dice': '8d10+24', 'speed_walk_ft': 20, 'speed_swim_ft': 40,
          'stat_block': {'STR': 18, 'DEX': 15, 'CON': 16, 'INT': 2, 'WIS': 12, 'CHA': 5},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 15,
          'trait_refs': [ref('trait', 'Hold Breath (Crocodile)')],
          'action_refs': [
            ref('creature-action', 'Bite (Plesiosaurus)'),
          ],
        },
      ),

      // ─── Mammoth (CR 6) ──────────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Mammoth',
        description: r'''A great shaggy elephant of cold climates, with massive curved tusks.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 13 · **HP** 126 (11d12+55)
- **Speed** walk 40 ft.
- **STR** 24 (+7) · **DEX** 9 (-1) · **CON** 21 (+5) · **INT** 3 (-4) · **WIS** 11 (+0) · **CHA** 6 (-2)
- **CR** 6 (2300 XP) · **Proficiency Bonus** +3 · **Passive Perception** 10

### Traits
- **Trampling Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Stomp attack against it as a Bonus Action.

### Actions
- **Gore.** *Melee Attack Roll:* +10, reach 10 ft. *Hit:* 24 (4d8 + 6) Piercing damage.
- **Stomp.** *Melee Attack Roll:* +10, reach 5 ft, one Prone creature. *Hit:* 28 (4d10 + 6) Bludgeoning damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 126, 'hp_dice': '11d12+55', 'speed_walk_ft': 40,
          'stat_block': {'STR': 24, 'DEX': 9, 'CON': 21, 'INT': 3, 'WIS': 11, 'CHA': 6},
          'cr': '6', 'xp': 2300, 'proficiency_bonus': 3, 'passive_perception': 10,
          'trait_refs': [ref('trait', 'Trampling Charge')],
          'action_refs': [
            ref('creature-action', 'Gore (Mammoth)'),
            ref('creature-action', 'Stomp (Mammoth)'),
          ],
        },
      ),

      // ─── Rhinoceros (CR 2) ───────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Rhinoceros',
        description: r'''A great herbivore with a single horn, known for an aggressive charge.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 45 (6d10+12)
- **Speed** walk 40 ft.
- **STR** 21 (+5) · **DEX** 8 (-1) · **CON** 15 (+2) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.

### Actions
- **Gore.** *Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 40,
          'stat_block': {'STR': 21, 'DEX': 8, 'CON': 15, 'INT': 2, 'WIS': 12, 'CHA': 6},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 11,
          'trait_refs': [ref('trait', 'Charge')],
          'action_refs': [ref('creature-action', 'Gore (Rhinoceros)')],
        },
      ),

      // ─── Killer Whale (CR 3) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Killer Whale',
        description: r'''A large oceanic apex predator. Despite the name, killer whales are intelligent and social.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 12 · **HP** 90 (12d12+12)
- **Speed** swim 60 ft.
- **STR** 19 (+4) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 3 (700 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14
- **Senses** Blindsight 120 ft.

### Traits
- **Echolocation.** The creature can't use its Blindsight while Deafened.
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 21 (5d6 + 5) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 90, 'hp_dice': '12d12+12', 'speed_walk_ft': 0, 'speed_swim_ft': 60,
          'stat_block': {'STR': 19, 'DEX': 10, 'CON': 13, 'INT': 3, 'WIS': 12, 'CHA': 7},
          'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 14,
          'senses': [{'sense': 'Blindsight', 'range_ft': 120}],
          'trait_refs': [
            ref('trait', 'Echolocation'),
            ref('trait', 'Hold Breath (Crocodile)'),
            ref('trait', 'Keen Hearing'),
          ],
          'action_refs': [ref('creature-action', 'Bite (Killer Whale)')],
        },
      ),

      // ─── Stirge (CR 1/8) ─────────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Stirge',
        description: r'''A bat-winged blood-drinking parasite the size of a small bird.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 14 · **HP** 5 (2d4)
- **Speed** walk 10 ft., fly 40 ft.
- **STR** 4 (-3) · **DEX** 16 (+3) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 8 (-1) · **CHA** 6 (-2)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Darkvision 60 ft.

### Actions
- **Proboscis.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage, and the stirge attaches to the target. While attached, the stirge can't attack, and at the start of each of the stirge's turns, the target loses 5 (1d4 + 3) HP.''',
        attributes: {
          'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 14, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 5, 'hp_dice': '2d4', 'speed_walk_ft': 10, 'speed_fly_ft': 40,
          'stat_block': {'STR': 4, 'DEX': 16, 'CON': 11, 'INT': 2, 'WIS': 8, 'CHA': 6},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 9,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'action_refs': [ref('creature-action', 'Proboscis (Stirge)')],
        },
      ),

      // ─── Giant Crab (CR 1/8) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Giant Crab',
        description: r'''A crab the size of a large dog, with massive crushing claws.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 15 · **HP** 13 (3d8)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 13 (+1) · **DEX** 11 (+0) · **CON** 11 (+0) · **INT** 1 (-5) · **WIS** 9 (-1) · **CHA** 3 (-4)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Blindsight 30 ft.

### Traits
- **Amphibious.** The creature can breathe air and water.

### Actions
- **Claw.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage. The target has the Grappled condition (escape DC 11). The crab has two claws, each grappling one target.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 15, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 30, 'speed_swim_ft': 30,
          'stat_block': {'STR': 13, 'DEX': 11, 'CON': 11, 'INT': 1, 'WIS': 9, 'CHA': 3},
          'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 9,
          'senses': [{'sense': 'Blindsight', 'range_ft': 30}],
          'trait_refs': [ref('trait', 'Amphibious')],
          'action_refs': [ref('creature-action', 'Claw (Giant Crab)')],
        },
      ),

      // ─── Giant Octopus (CR 1) ────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Giant Octopus',
        description: r'''A massive cephalopod hunting in coastal seas.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 52 (8d10+8)
- **Speed** walk 10 ft., swim 60 ft.
- **STR** 17 (+3) · **DEX** 13 (+1) · **CON** 13 (+1) · **INT** 4 (-3) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14
- **Senses** Darkvision 60 ft.

### Traits
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Tentacles.** *Melee Attack Roll:* +5, reach 15 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage. The target has the Grappled condition (escape DC 16) and the Restrained condition until the grapple ends.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 52, 'hp_dice': '8d10+8', 'speed_walk_ft': 10, 'speed_swim_ft': 60,
          'stat_block': {'STR': 17, 'DEX': 13, 'CON': 13, 'INT': 4, 'WIS': 10, 'CHA': 4},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 14,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'trait_refs': [
            ref('trait', 'Hold Breath (Crocodile)'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Tentacles (Giant Octopus)')],
        },
      ),

      // ─── Giant Shark (CR 5) ──────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Giant Shark',
        description: r'''A 30-foot apex predator of the deep, scenting prey miles away.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 13 · **HP** 126 (11d12+55)
- **Speed** swim 50 ft.
- **STR** 23 (+6) · **DEX** 11 (+0) · **CON** 21 (+5) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 5 (1800 XP) · **Proficiency Bonus** +3 · **Passive Perception** 13
- **Senses** Blindsight 60 ft.

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 20 (3d10 + 4) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 126, 'hp_dice': '11d12+55', 'speed_walk_ft': 0, 'speed_swim_ft': 50,
          'stat_block': {'STR': 23, 'DEX': 11, 'CON': 21, 'INT': 1, 'WIS': 10, 'CHA': 5},
          'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 13,
          'senses': [{'sense': 'Blindsight', 'range_ft': 60}],
          'trait_refs': [
            ref('trait', 'Blood Frenzy'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Bite (Giant Shark)')],
        },
      ),

      // ─── Hunter Shark (CR 2) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Hunter Shark',
        description: r'''A solitary deep-water shark, dangerous and aggressive.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 45 (6d10+12)
- **Speed** swim 40 ft.
- **STR** 18 (+4) · **DEX** 13 (+1) · **CON** 15 (+2) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Blindsight 30 ft.

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 13 (2d8 + 4) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11,
          'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 0, 'speed_swim_ft': 40,
          'stat_block': {'STR': 18, 'DEX': 13, 'CON': 15, 'INT': 1, 'WIS': 10, 'CHA': 4},
          'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Blindsight', 'range_ft': 30}],
          'trait_refs': [
            ref('trait', 'Blood Frenzy'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Bite (Hunter Shark)')],
        },
      ),

      // ─── Reef Shark (CR 1/2) ─────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Reef Shark',
        description: r'''A smaller predatory shark of warm coastal waters, often hunting in groups.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 22 (4d8+4)
- **Speed** swim 40 ft.
- **STR** 14 (+2) · **DEX** 13 (+1) · **CON** 13 (+1) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 4 (-3)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Blindsight 30 ft.

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 22, 'hp_dice': '4d8+4', 'speed_walk_ft': 0, 'speed_swim_ft': 40,
          'stat_block': {'STR': 14, 'DEX': 13, 'CON': 13, 'INT': 1, 'WIS': 10, 'CHA': 4},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 12,
          'senses': [{'sense': 'Blindsight', 'range_ft': 30}],
          'trait_refs': [
            ref('trait', 'Pack Tactics'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Bite (Reef Shark)')],
        },
      ),

      // ─── Quipper (CR 0) ──────────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Quipper',
        description: r'''A small carnivorous fish that hunts in vicious swarms.

### Statistics
- **Small Beast**, Unaligned
- **AC** 13 · **HP** 1 (1d4)
- **Speed** swim 40 ft.
- **STR** 2 (-4) · **DEX** 16 (+3) · **CON** 9 (-1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 2 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Darkvision 60 ft.

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 1, 'hp_dice': '1d4', 'speed_walk_ft': 0, 'speed_swim_ft': 40,
          'stat_block': {'STR': 2, 'DEX': 16, 'CON': 9, 'INT': 1, 'WIS': 7, 'CHA': 2},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 8,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'trait_refs': [
            ref('trait', 'Blood Frenzy'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Bite (Quipper)')],
        },
      ),

      // ─── Swarm of Bats (CR 1/4) ─────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Swarm of Bats',
        description: r'''A cloud of fluttering bats moves and attacks as a single creature.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 22 (5d8)
- **Speed** fly 30 ft.
- **STR** 5 (-3) · **DEX** 15 (+2) · **CON** 10 (+0) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 4 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11
- **Senses** Blindsight 60 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Echolocation.** The creature can't use its Blindsight while Deafened.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.

### Actions
- **Bites.** *Melee Attack Roll:* +4, reach 0 ft. *Hit:* 10 (4d4) Piercing damage, or 5 (2d4) if the swarm has half its HP or fewer.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 0, 'speed_fly_ft': 30,
          'stat_block': {'STR': 5, 'DEX': 15, 'CON': 10, 'INT': 2, 'WIS': 12, 'CHA': 4},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 11,
          'senses': [{'sense': 'Blindsight', 'range_ft': 60}],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Stunned'),
          ],
          'trait_refs': [
            ref('trait', 'Echolocation'),
            ref('trait', 'Keen Hearing'),
            ref('trait', 'Swarm'),
          ],
          'action_refs': [ref('creature-action', 'Bites (Swarm of Bats)')],
        },
      ),

      // ─── Swarm of Insects (CR 1/2) ──────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Swarm of Insects',
        description: r'''A horde of biting, stinging, or burrowing insects acts as one creature.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 22 (5d8)
- **Speed** walk 20 ft., climb 20 ft.
- **STR** 3 (-4) · **DEX** 13 (+1) · **CON** 10 (+0) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 1 (-5)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Blindsight 10 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.

### Actions
- **Bites.** *Melee Attack Roll:* +3, reach 0 ft. *Hit:* 10 (4d4) Piercing damage, or 5 (2d4) if the swarm has half its HP or fewer.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12,
          'hp_average': 22, 'hp_dice': '5d8', 'speed_walk_ft': 20, 'speed_climb_ft': 20,
          'stat_block': {'STR': 3, 'DEX': 13, 'CON': 10, 'INT': 1, 'WIS': 7, 'CHA': 1},
          'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 8,
          'senses': [{'sense': 'Blindsight', 'range_ft': 10}],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Stunned'),
          ],
          'trait_refs': [ref('trait', 'Swarm')],
          'action_refs': [ref('creature-action', 'Bites (Swarm of Insects)')],
        },
      ),

      // ─── Swarm of Rats (CR 1/4) ─────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Swarm of Rats',
        description: r'''A boiling mass of rats — small, fast, and dangerous in numbers.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 24 (7d8-7)
- **Speed** walk 30 ft.
- **STR** 9 (-1) · **DEX** 11 (+0) · **CON** 9 (-1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Darkvision 30 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.

### Actions
- **Bites.** *Melee Attack Roll:* +4, reach 0 ft. *Hit:* 7 (2d6) Piercing damage, or 3 (1d6) if the swarm has half its HP or fewer.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 24, 'hp_dice': '7d8-7', 'speed_walk_ft': 30,
          'stat_block': {'STR': 9, 'DEX': 11, 'CON': 9, 'INT': 2, 'WIS': 10, 'CHA': 3},
          'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10,
          'senses': [{'sense': 'Darkvision', 'range_ft': 30}],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Stunned'),
          ],
          'trait_refs': [
            ref('trait', 'Keen Smell'),
            ref('trait', 'Swarm'),
          ],
          'action_refs': [ref('creature-action', 'Bites (Swarm of Rats)')],
        },
      ),

      // ─── Swarm of Quippers (CR 1) ───────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Swarm of Quippers',
        description: r'''A school of carnivorous fish that strips prey to bone in moments.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 28 (8d8-8)
- **Speed** swim 40 ft.
- **STR** 13 (+1) · **DEX** 16 (+3) · **CON** 9 (-1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 2 (-4)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Darkvision 60 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bites.** *Melee Attack Roll:* +5, reach 0 ft. *Hit:* 14 (4d6) Piercing damage, or 7 (2d6) if the swarm has half its HP or fewer.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13,
          'hp_average': 28, 'hp_dice': '8d8-8', 'speed_walk_ft': 0, 'speed_swim_ft': 40,
          'stat_block': {'STR': 13, 'DEX': 16, 'CON': 9, 'INT': 1, 'WIS': 7, 'CHA': 2},
          'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 8,
          'senses': [{'sense': 'Darkvision', 'range_ft': 60}],
          'resistance_refs': [
            lookup('damage-type', 'Bludgeoning'),
            lookup('damage-type', 'Piercing'),
            lookup('damage-type', 'Slashing'),
          ],
          'condition_immunity_refs': [
            lookup('condition', 'Charmed'),
            lookup('condition', 'Frightened'),
            lookup('condition', 'Grappled'),
            lookup('condition', 'Paralyzed'),
            lookup('condition', 'Petrified'),
            lookup('condition', 'Prone'),
            lookup('condition', 'Restrained'),
            lookup('condition', 'Stunned'),
          ],
          'trait_refs': [
            ref('trait', 'Blood Frenzy'),
            ref('trait', 'Swarm'),
            ref('trait', 'Water Breathing'),
          ],
          'action_refs': [ref('creature-action', 'Bites (Swarm of Quippers)')],
        },
      ),

      // ─── Vulture (CR 0) ──────────────────────────────────────────────────
      packEntity(
        slug: 'animal',
        name: 'Vulture',
        description: r'''A scavenging bird with keen eyes and a strong beak.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 5 (1d8+1)
- **Speed** walk 10 ft., fly 50 ft.
- **STR** 7 (-2) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 4 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Sight and Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on sight or smell.
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Talons.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 1 Slashing damage.''',
        attributes: {
          'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'),
          'alignment_ref': lookup('alignment', 'Unaligned'),
          'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10,
          'hp_average': 5, 'hp_dice': '1d8+1', 'speed_walk_ft': 10, 'speed_fly_ft': 50,
          'stat_block': {'STR': 7, 'DEX': 10, 'CON': 13, 'INT': 2, 'WIS': 12, 'CHA': 4},
          'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13,
          'trait_refs': [
            ref('trait', 'Keen Sight and Smell'),
            ref('trait', 'Pack Tactics'),
          ],
          'action_refs': [ref('creature-action', 'Talons (Hawk)')],
        },
      ),

      // ─── Animal roster — batch 1 (compact entries) ───────────────────────
      packEntity(slug: 'animal', name: 'Ankylosaurus', description: r'''A massive armored herbivorous dinosaur with a heavy clubbed tail.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 15 · **HP** 68 (8d12+16)
- **Speed** walk 30 ft.
- **STR** 19 (+4) · **DEX** 11 (+0) · **CON** 15 (+2) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 3 (700 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Actions
- **Tail.** *Melee Attack Roll:* +7, reach 10 ft. *Hit:* 18 (4d6 + 4) Bludgeoning damage. If the target is a Huge or smaller creature, it must succeed on a DC 14 Strength save or have the Prone condition.''', attributes: {'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 15, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 68, 'hp_dice': '8d12+16', 'speed_walk_ft': 30, 'stat_block': {'STR': 19, 'DEX': 11, 'CON': 15, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 11, 'action_refs': [ref('creature-action', 'Tail (Ankylosaurus)')]}),
      packEntity(slug: 'animal', name: 'Archelon', description: r'''An immense prehistoric sea turtle with a hardened shell.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 17 · **HP** 90 (12d12+12)
- **Speed** walk 20 ft., swim 40 ft.
- **STR** 19 (+4) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 4 (-3)
- **CR** 4 (1100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.

### Actions
- **Bite.** *Melee Attack Roll:* +7, reach 5 ft. *Hit:* 15 (2d10 + 4) Piercing damage. If the target is a Large or smaller creature, it has the Grappled condition (escape DC 14).''', attributes: {'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 17, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 90, 'hp_dice': '12d12+12', 'speed_walk_ft': 20, 'speed_swim_ft': 40, 'stat_block': {'STR': 19, 'DEX': 10, 'CON': 13, 'INT': 2, 'WIS': 11, 'CHA': 4}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Hold Breath (Crocodile)')], 'action_refs': [ref('creature-action', 'Bite (Archelon)')]}),
      packEntity(slug: 'animal', name: 'Baboon', description: r'''A medium primate with sharp teeth and quick reflexes that travels in troops.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 3 (1d6)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 8 (-1) · **DEX** 14 (+2) · **CON** 11 (+0) · **INT** 4 (-3) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Bite.** *Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 (1d4 − 1) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 3, 'hp_dice': '1d6', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 8, 'DEX': 14, 'CON': 11, 'INT': 4, 'WIS': 12, 'CHA': 6}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 11, 'trait_refs': [ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Bite (Baboon)')]}),
      packEntity(slug: 'animal', name: 'Badger', description: r'''A small burrowing mammal with strong claws and a tenacious bite.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 10 · **HP** 3 (1d4+1)
- **Speed** walk 20 ft.
- **STR** 4 (-3) · **DEX** 11 (+0) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 30 ft.

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 3, 'hp_dice': '1d4+1', 'speed_walk_ft': 20, 'stat_block': {'STR': 4, 'DEX': 11, 'CON': 12, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Bite (Badger)')]}),
      packEntity(slug: 'animal', name: 'Bat', description: r'''A flying mammal that navigates using echolocation.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 12 · **HP** 1 (1d4-1)
- **Speed** walk 5 ft., fly 30 ft.
- **STR** 2 (-4) · **DEX** 15 (+2) · **CON** 8 (-1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 4 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11
- **Senses** Blindsight 60 ft.

### Traits
- **Echolocation.** The creature can't use its Blindsight while Deafened.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.

### Actions
- **Bite.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 5, 'speed_fly_ft': 30, 'stat_block': {'STR': 2, 'DEX': 15, 'CON': 8, 'INT': 2, 'WIS': 12, 'CHA': 4}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Echolocation'), ref('trait', 'Keen Hearing')], 'action_refs': [ref('creature-action', 'Bite (Bat)')]}),
      packEntity(slug: 'animal', name: 'Black Bear', description: r'''A medium-sized bear common in forested regions, fierce when threatened.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 11 · **HP** 19 (3d8+6)
- **Speed** walk 40 ft., climb 30 ft.
- **STR** 15 (+2) · **DEX** 10 (+0) · **CON** 14 (+2) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage.
- **Claws.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 6 (2d4 + 1) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 19, 'hp_dice': '3d8+6', 'speed_walk_ft': 40, 'speed_climb_ft': 30, 'stat_block': {'STR': 15, 'DEX': 10, 'CON': 14, 'INT': 2, 'WIS': 12, 'CHA': 7}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Black Bear)'), ref('creature-action', 'Claws (Black Bear)')]}),
      packEntity(slug: 'animal', name: 'Blood Hawk', description: r'''A predatory bird that hunts in flocks for prey larger than itself.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 7 (2d6)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 6 (-2) · **DEX** 14 (+2) · **CON** 10 (+0) · **INT** 3 (-4) · **WIS** 14 (+2) · **CHA** 5 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14

### Traits
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Beak.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 7, 'hp_dice': '2d6', 'speed_walk_ft': 10, 'speed_fly_ft': 60, 'stat_block': {'STR': 6, 'DEX': 14, 'CON': 10, 'INT': 3, 'WIS': 14, 'CHA': 5}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 14, 'trait_refs': [ref('trait', 'Keen Sight'), ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Beak (Blood Hawk)')]}),
      packEntity(slug: 'animal', name: 'Crab', description: r'''A small crustacean common in coastal areas.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 11 · **HP** 2 (1d4)
- **Speed** walk 20 ft., swim 20 ft.
- **STR** 2 (-4) · **DEX** 11 (+0) · **CON** 10 (+0) · **INT** 1 (-5) · **WIS** 8 (-1) · **CHA** 2 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Blindsight 30 ft.

### Traits
- **Amphibious.** The creature can breathe air and water.

### Actions
- **Claws.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 2, 'hp_dice': '1d4', 'speed_walk_ft': 20, 'speed_swim_ft': 20, 'stat_block': {'STR': 2, 'DEX': 11, 'CON': 10, 'INT': 1, 'WIS': 8, 'CHA': 2}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Blindsight', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Amphibious')], 'action_refs': [ref('creature-action', 'Claws (Crab)')]}),
      packEntity(slug: 'animal', name: 'Deer', description: r'''A graceful hoofed mammal common in woodlands.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 4 (1d8)
- **Speed** walk 50 ft.
- **STR** 11 (+0) · **DEX** 16 (+3) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 14 (+2) · **CHA** 5 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12

### Actions
- **Ram.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 4, 'hp_dice': '1d8', 'speed_walk_ft': 50, 'stat_block': {'STR': 11, 'DEX': 16, 'CON': 11, 'INT': 2, 'WIS': 14, 'CHA': 5}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 12, 'action_refs': [ref('creature-action', 'Ram (Deer)')]}),
      packEntity(slug: 'animal', name: 'Draft Horse', description: r'''A large working horse bred for hauling.

### Statistics
- **Large Beast**, Unaligned
- **AC** 10 · **HP** 19 (3d10+3)
- **Speed** walk 40 ft.
- **STR** 18 (+4) · **DEX** 10 (+0) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 7 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Beast of Burden.** The creature is considered Large for the purpose of determining its carrying capacity.

### Actions
- **Hooves.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 10, 'CON': 12, 'INT': 2, 'WIS': 11, 'CHA': 7}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Beast of Burden')], 'action_refs': [ref('creature-action', 'Hooves (Draft Horse)')]}),
      packEntity(slug: 'animal', name: 'Elk', description: r'''A large deer with imposing antlers, capable of charging foes.

### Statistics
- **Large Beast**, Unaligned
- **AC** 10 · **HP** 13 (2d10+2)
- **Speed** walk 50 ft.
- **STR** 16 (+3) · **DEX** 10 (+0) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 6 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12

### Actions
- **Ram.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Bludgeoning damage. If the elk moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage and must succeed on a DC 12 Strength save or have the Prone condition.
- **Hooves.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 13, 'hp_dice': '2d10+2', 'speed_walk_ft': 50, 'stat_block': {'STR': 16, 'DEX': 10, 'CON': 12, 'INT': 2, 'WIS': 10, 'CHA': 6}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 12, 'action_refs': [ref('creature-action', 'Ram (Elk)'), ref('creature-action', 'Hooves (Elk)')]}),
      packEntity(slug: 'animal', name: 'Flying Snake', description: r'''A small winged serpent with venomous fangs.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 14 · **HP** 5 (2d4)
- **Speed** walk 30 ft., fly 60 ft., swim 30 ft.
- **STR** 4 (-3) · **DEX** 18 (+4) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11
- **Senses** Blindsight 10 ft.

### Traits
- **Flyby.** The creature doesn't provoke Opportunity Attacks when it flies out of an enemy's reach.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 1 Piercing damage plus 7 (3d4) Poison damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 5, 'hp_dice': '2d4', 'speed_walk_ft': 30, 'speed_fly_ft': 60, 'speed_swim_ft': 30, 'stat_block': {'STR': 4, 'DEX': 18, 'CON': 11, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}], 'trait_refs': [ref('trait', 'Flyby')], 'action_refs': [ref('creature-action', 'Bite (Flying Snake)')]}),
      packEntity(slug: 'animal', name: 'Giant Ape', description: r'''A massive primate of jungle and mountain, capable of hurling boulders.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 12 · **HP** 157 (15d12+60)
- **Speed** walk 40 ft., climb 40 ft.
- **STR** 23 (+6) · **DEX** 14 (+2) · **CON** 18 (+4) · **INT** 7 (-2) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 7 (2900 XP) · **Proficiency Bonus** +3 · **Passive Perception** 14

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Fist.** *Melee Attack Roll:* +6, reach 10 ft. *Hit:* 22 (3d10 + 6) Bludgeoning damage.
- **Rock.** *Ranged Attack Roll:* +6, range 50/100 ft. *Hit:* 30 (7d6 + 6) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 157, 'hp_dice': '15d12+60', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'stat_block': {'STR': 23, 'DEX': 14, 'CON': 18, 'INT': 7, 'WIS': 12, 'CHA': 7}, 'cr': '7', 'xp': 2900, 'proficiency_bonus': 3, 'passive_perception': 14, 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Fist (Giant Ape)'), ref('creature-action', 'Rock (Giant Ape)')]}),
      packEntity(slug: 'animal', name: 'Giant Badger', description: r'''An oversized badger that burrows aggressively.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 13 (2d8+4)
- **Speed** walk 30 ft., burrow 10 ft.
- **STR** 13 (+1) · **DEX** 10 (+0) · **CON** 15 (+2) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 30 ft.

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Piercing damage.
- **Claw.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 6 (2d4 + 1) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 13, 'hp_dice': '2d8+4', 'speed_walk_ft': 30, 'speed_burrow_ft': 10, 'stat_block': {'STR': 13, 'DEX': 10, 'CON': 15, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Badger)'), ref('creature-action', 'Claw (Giant Badger)')]}),
      packEntity(slug: 'animal', name: 'Giant Bat', description: r'''A bat the size of a large dog, hunting in caves.

### Statistics
- **Large Beast**, Unaligned
- **AC** 13 · **HP** 22 (4d10)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 15 (+2) · **DEX** 16 (+3) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11
- **Senses** Blindsight 60 ft.

### Traits
- **Echolocation.** The creature can't use its Blindsight while Deafened.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 22, 'hp_dice': '4d10', 'speed_walk_ft': 10, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 16, 'CON': 11, 'INT': 2, 'WIS': 12, 'CHA': 6}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 11, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Echolocation'), ref('trait', 'Keen Hearing')], 'action_refs': [ref('creature-action', 'Bite (Giant Bat)')]}),
      packEntity(slug: 'animal', name: 'Giant Boar', description: r'''A massive wild pig with razor-sharp tusks and a savage charge.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 42 (5d10+15)
- **Speed** walk 40 ft.
- **STR** 17 (+3) · **DEX** 10 (+0) · **CON** 16 (+3) · **INT** 2 (-4) · **WIS** 7 (-2) · **CHA** 5 (-3)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.

### Actions
- **Tusk.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage. If the boar moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 42, 'hp_dice': '5d10+15', 'speed_walk_ft': 40, 'stat_block': {'STR': 17, 'DEX': 10, 'CON': 16, 'INT': 2, 'WIS': 7, 'CHA': 5}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 8, 'trait_refs': [ref('trait', 'Charge')], 'action_refs': [ref('creature-action', 'Tusk (Giant Boar)')]}),
      packEntity(slug: 'animal', name: 'Giant Crocodile', description: r'''A monstrous reptile of riverbeds and swamps.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 14 · **HP** 85 (9d12+27)
- **Speed** walk 30 ft., swim 50 ft.
- **STR** 21 (+5) · **DEX** 9 (-1) · **CON** 17 (+3) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 7 (-2)
- **CR** 5 (1800 XP) · **Proficiency Bonus** +3 · **Passive Perception** 10

### Traits
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Bite.** *Melee Attack Roll:* +8, reach 5 ft. *Hit:* 21 (3d10 + 5) Piercing damage. If the target is a Huge or smaller creature, it has the Grappled condition (escape DC 16).
- **Tail.** *Melee Attack Roll:* +8, reach 10 ft. *Hit:* 14 (2d8 + 5) Bludgeoning damage. If the target is a Large or smaller creature, it has the Prone condition.''', attributes: {'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 85, 'hp_dice': '9d12+27', 'speed_walk_ft': 30, 'speed_swim_ft': 50, 'stat_block': {'STR': 21, 'DEX': 9, 'CON': 17, 'INT': 2, 'WIS': 10, 'CHA': 7}, 'cr': '5', 'xp': 1800, 'proficiency_bonus': 3, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Hold Breath (Crocodile)')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Bite (Giant Crocodile)'), ref('creature-action', 'Tail (Giant Crocodile)')]}),
      packEntity(slug: 'animal', name: 'Giant Elk', description: r'''An enormous elk with majestic antlers and incredible speed.

### Statistics
- **Huge Beast**, Unaligned
- **AC** 14 · **HP** 42 (5d12+10)
- **Speed** walk 60 ft.
- **STR** 19 (+4) · **DEX** 16 (+3) · **CON** 14 (+2) · **INT** 7 (-2) · **WIS** 14 (+2) · **CHA** 10 (+0)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14

### Actions
- **Ram.** *Melee Attack Roll:* +6, reach 10 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage. If the elk moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage and must succeed on a DC 14 Strength save or have the Prone condition.
- **Hooves.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (4d4 + 4) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Huge'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 42, 'hp_dice': '5d12+10', 'speed_walk_ft': 60, 'stat_block': {'STR': 19, 'DEX': 16, 'CON': 14, 'INT': 7, 'WIS': 14, 'CHA': 10}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 14, 'action_refs': [ref('creature-action', 'Ram (Giant Elk)'), ref('creature-action', 'Hooves (Giant Elk)')]}),
      packEntity(slug: 'animal', name: 'Giant Fire Beetle', description: r'''A glowing beetle that sheds light from luminescent glands.

### Statistics
- **Small Beast**, Unaligned
- **AC** 13 · **HP** 4 (1d6+1)
- **Speed** walk 30 ft.
- **STR** 8 (-1) · **DEX** 10 (+0) · **CON** 12 (+1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 3 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Darkvision 30 ft.

### Traits
- **Light.** The beetle sheds Bright Light in a 10-foot radius and Dim Light for an additional 10 feet.

### Actions
- **Bite.** *Melee Attack Roll:* +1, reach 5 ft. *Hit:* 3 (1d6) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 4, 'hp_dice': '1d6+1', 'speed_walk_ft': 30, 'stat_block': {'STR': 8, 'DEX': 10, 'CON': 12, 'INT': 1, 'WIS': 7, 'CHA': 3}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Light (Fire Beetle)')], 'action_refs': [ref('creature-action', 'Bite (Giant Fire Beetle)')]}),
      packEntity(slug: 'animal', name: 'Giant Goat', description: r'''A massive goat capable of charging foes.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 19 (3d10+3)
- **Speed** walk 40 ft.
- **STR** 17 (+3) · **DEX** 11 (+0) · **CON** 12 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.
- **Sure-Footed.** The creature has Advantage on Strength and Dexterity saving throws made against effects that would knock it Prone.

### Actions
- **Ram.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (2d4 + 3) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 40, 'stat_block': {'STR': 17, 'DEX': 11, 'CON': 12, 'INT': 3, 'WIS': 12, 'CHA': 6}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 11, 'trait_refs': [ref('trait', 'Charge'), ref('trait', 'Sure-Footed')], 'action_refs': [ref('creature-action', 'Ram (Giant Goat)')]}),
      packEntity(slug: 'animal', name: 'Giant Hyena', description: r'''A monstrous hyena with bone-crushing jaws.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 45 (6d10+12)
- **Speed** walk 50 ft.
- **STR** 16 (+3) · **DEX** 14 (+2) · **CON** 14 (+2) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Reckless.** At the start of its turn, the creature can gain Advantage on all melee weapon attack rolls during that turn, but attack rolls against it have Advantage until the start of its next turn.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 45, 'hp_dice': '6d10+12', 'speed_walk_ft': 50, 'stat_block': {'STR': 16, 'DEX': 14, 'CON': 14, 'INT': 2, 'WIS': 12, 'CHA': 7}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Reckless')], 'action_refs': [ref('creature-action', 'Bite (Giant Hyena)')]}),
      packEntity(slug: 'animal', name: 'Giant Owl', description: r'''A wise giant owl that speaks Common, Elvish, and Sylvan.

### Statistics
- **Large Beast**, Neutral
- **AC** 12 · **HP** 19 (3d10+3)
- **Speed** walk 5 ft., fly 60 ft.
- **STR** 13 (+1) · **DEX** 15 (+2) · **CON** 12 (+1) · **INT** 8 (-1) · **WIS** 13 (+1) · **CHA** 10 (+0)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 15
- **Senses** Darkvision 120 ft.

### Traits
- **Flyby.** The creature doesn't provoke Opportunity Attacks when it flies out of an enemy's reach.
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Keen Sight.** The creature has Advantage on Wisdom (Perception) checks that rely on sight.

### Actions
- **Talons.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 8 (2d6 + 1) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Neutral'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 19, 'hp_dice': '3d10+3', 'speed_walk_ft': 5, 'speed_fly_ft': 60, 'stat_block': {'STR': 13, 'DEX': 15, 'CON': 12, 'INT': 8, 'WIS': 13, 'CHA': 10}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 15, 'senses': [{'sense': 'Darkvision', 'range_ft': 120}], 'trait_refs': [ref('trait', 'Flyby'), ref('trait', 'Keen Hearing'), ref('trait', 'Keen Sight')], 'action_refs': [ref('creature-action', 'Talons (Giant Owl)')]}),
      packEntity(slug: 'animal', name: 'Giant Scorpion', description: r'''A massive armored arachnid with deadly venom in its tail.

### Statistics
- **Large Beast**, Unaligned
- **AC** 15 · **HP** 52 (7d10+14)
- **Speed** walk 40 ft.
- **STR** 15 (+2) · **DEX** 13 (+1) · **CON** 15 (+2) · **INT** 1 (-5) · **WIS** 9 (-1) · **CHA** 3 (-4)
- **CR** 3 (700 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Blindsight 60 ft.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Sting.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage. The target must make a DC 12 Constitution save, taking 22 (4d10) Poison damage on a failure or half on a success.
- **Claw.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Bludgeoning damage. The target has the Grappled condition (escape DC 12).''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 15, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 52, 'hp_dice': '7d10+14', 'speed_walk_ft': 40, 'stat_block': {'STR': 15, 'DEX': 13, 'CON': 15, 'INT': 1, 'WIS': 9, 'CHA': 3}, 'cr': '3', 'xp': 700, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Blindsight', 'range_ft': 60}], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Sting (Giant Scorpion)'), ref('creature-action', 'Claw (Giant Scorpion)')]}),
      packEntity(slug: 'animal', name: 'Giant Seahorse', description: r'''An enormous seahorse capable of charging through water.

### Statistics
- **Large Beast**, Unaligned
- **AC** 13 · **HP** 16 (3d10)
- **Speed** swim 40 ft.
- **STR** 12 (+1) · **DEX** 15 (+2) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 11

### Traits
- **Water Breathing.** The creature can breathe only underwater.
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.

### Actions
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage. If the seahorse moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 16, 'hp_dice': '3d10', 'speed_walk_ft': 0, 'speed_swim_ft': 40, 'stat_block': {'STR': 12, 'DEX': 15, 'CON': 11, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 11, 'trait_refs': [ref('trait', 'Water Breathing (Animal)'), ref('trait', 'Charge')], 'action_refs': [ref('creature-action', 'Bite (Giant Seahorse)')]}),
      packEntity(slug: 'animal', name: 'Giant Spider', description: r'''A horse-sized arachnid that spins enormous webs and ambushes prey.

### Statistics
- **Large Beast**, Unaligned
- **AC** 14 · **HP** 26 (4d10+4)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 14 (+2) · **DEX** 16 (+3) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 11 (+0) · **CHA** 4 (-3)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Blindsight 10 ft., Darkvision 60 ft.

### Traits
- **Spider Climb.** The creature can climb difficult surfaces, including upside down on ceilings, without an ability check.
- **Web Sense.** While in contact with a web, the creature knows the exact location of any other creature in contact with the same web.
- **Web Walker.** The creature ignores movement restrictions caused by webbing.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 9 (2d8) Poison damage, and the target must succeed on a DC 11 Constitution save or be Poisoned for 1 hour.
- **Web.** *Ranged*, range 30/60 ft. *Dexterity Saving Throw:* DC 11. *Failure:* The target has the Restrained condition until the web is destroyed (AC 10, HP 5; immune to Poison and Psychic damage). (Recharge 5–6).''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 26, 'hp_dice': '4d10+4', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 14, 'DEX': 16, 'CON': 12, 'INT': 2, 'WIS': 11, 'CHA': 4}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Spider Climb'), ref('trait', 'Web Sense'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Bite (Giant Spider)'), ref('creature-action', 'Web (Giant Spider)')]}),
      packEntity(slug: 'animal', name: 'Giant Toad', description: r'''A massive toad that swallows prey whole.

### Statistics
- **Large Beast**, Unaligned
- **AC** 11 · **HP** 39 (6d10+6)
- **Speed** walk 20 ft., swim 40 ft.
- **STR** 15 (+2) · **DEX** 13 (+1) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Darkvision 30 ft.

### Traits
- **Amphibious.** The creature can breathe air and water.
- **Standing Leap.** The creature's long jump is up to 30 feet and its high jump is up to 15 feet, with or without a running start.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage plus 5 (2d4) Poison damage. The target has the Grappled condition (escape DC 13). While Grappled, the target is also Restrained.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 39, 'hp_dice': '6d10+6', 'speed_walk_ft': 20, 'speed_swim_ft': 40, 'stat_block': {'STR': 15, 'DEX': 13, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 3}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Amphibious'), ref('trait', 'Standing Leap')], 'action_refs': [ref('creature-action', 'Bite (Giant Toad)')]}),
      packEntity(slug: 'animal', name: 'Giant Venomous Snake', description: r'''A constrictor-sized serpent with deadly venom.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 14 · **HP** 11 (2d8+2)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 10 (+0) · **DEX** 18 (+4) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Blindsight 10 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 10 ft. *Hit:* 6 (1d4 + 4) Piercing damage plus 10 (3d6) Poison damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'stat_block': {'STR': 10, 'DEX': 18, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 3}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}], 'action_refs': [ref('creature-action', 'Bite (Giant Venomous Snake)')]}),
      packEntity(slug: 'animal', name: 'Giant Vulture', description: r'''An enormous scavenger bird with limited intelligence.

### Statistics
- **Large Beast**, Neutral Evil
- **AC** 10 · **HP** 22 (3d10+6)
- **Speed** walk 10 ft., fly 60 ft.
- **STR** 15 (+2) · **DEX** 10 (+0) · **CON** 15 (+2) · **INT** 6 (-2) · **WIS** 12 (+1) · **CHA** 7 (-2)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Sight and Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on sight or smell.
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Multiattack.** The creature makes multiple attacks; the exact mix is given in its stat block.
- **Beak.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.
- **Talons.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (2d4 + 3) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Neutral Evil'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 22, 'hp_dice': '3d10+6', 'speed_walk_ft': 10, 'speed_fly_ft': 60, 'stat_block': {'STR': 15, 'DEX': 10, 'CON': 15, 'INT': 6, 'WIS': 12, 'CHA': 7}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Keen Sight and Smell'), ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Multiattack'), ref('creature-action', 'Beak (Blood Hawk)'), ref('creature-action', 'Talons (Giant Vulture)')]}),
      packEntity(slug: 'animal', name: 'Giant Wasp', description: r'''A horse-sized wasp with a paralyzing sting.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 13 (3d8)
- **Speed** walk 10 ft., fly 50 ft.
- **STR** 10 (+0) · **DEX** 14 (+2) · **CON** 10 (+0) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/2 (100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Actions
- **Sting.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 14 (4d6) Poison damage. The target must succeed on a DC 11 Constitution save or have the Poisoned condition for 1 hour.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 10, 'speed_fly_ft': 50, 'stat_block': {'STR': 10, 'DEX': 14, 'CON': 10, 'INT': 1, 'WIS': 10, 'CHA': 3}, 'cr': '1/2', 'xp': 100, 'proficiency_bonus': 2, 'passive_perception': 10, 'action_refs': [ref('creature-action', 'Sting (Giant Wasp)')]}),
      packEntity(slug: 'animal', name: 'Giant Weasel', description: r'''A wolf-sized weasel with a quick bite.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 9 (2d8)
- **Speed** walk 40 ft.
- **STR** 11 (+0) · **DEX** 16 (+3) · **CON** 10 (+0) · **INT** 4 (-3) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 60 ft.

### Traits
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 9, 'hp_dice': '2d8', 'speed_walk_ft': 40, 'stat_block': {'STR': 11, 'DEX': 16, 'CON': 10, 'INT': 4, 'WIS': 12, 'CHA': 5}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Keen Hearing'), ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Bite (Giant Weasel)')]}),
      packEntity(slug: 'animal', name: 'Giant Wolf Spider', description: r'''A wolf-sized hunting spider with venomous fangs.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 11 (2d8+2)
- **Speed** walk 40 ft., climb 40 ft.
- **STR** 12 (+1) · **DEX** 16 (+3) · **CON** 13 (+1) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 4 (-3)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Blindsight 10 ft., Darkvision 60 ft.

### Traits
- **Spider Climb.** The creature can climb difficult surfaces, including upside down on ceilings, without an ability check.
- **Web Sense.** While in contact with a web, the creature knows the exact location of any other creature in contact with the same web.
- **Web Walker.** The creature ignores movement restrictions caused by webbing.

### Actions
- **Bite.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage plus 7 (2d6) Poison damage. The target must make a DC 11 Constitution save: on a fail, it has the Poisoned condition for 1 hour.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 40, 'speed_climb_ft': 40, 'stat_block': {'STR': 12, 'DEX': 16, 'CON': 13, 'INT': 3, 'WIS': 12, 'CHA': 4}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}, {'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Spider Climb'), ref('trait', 'Web Sense'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Bite (Giant Wolf Spider)')]}),
      packEntity(slug: 'animal', name: 'Goat', description: r'''A common domesticated goat.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 4 (1d8)
- **Speed** walk 40 ft.
- **STR** 12 (+1) · **DEX** 10 (+0) · **CON** 11 (+0) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Charge.** If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature's STR mod + PB) or be knocked Prone.
- **Sure-Footed.** The creature has Advantage on Strength and Dexterity saving throws made against effects that would knock it Prone.

### Actions
- **Ram.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 4, 'hp_dice': '1d8', 'speed_walk_ft': 40, 'stat_block': {'STR': 12, 'DEX': 10, 'CON': 11, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Charge'), ref('trait', 'Sure-Footed')], 'action_refs': [ref('creature-action', 'Ram (Goat)')]}),
      packEntity(slug: 'animal', name: 'Hippopotamus', description: r'''A massive semi-aquatic mammal with bone-crushing jaws.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 76 (8d10+32)
- **Speed** walk 40 ft., swim 30 ft.
- **STR** 21 (+5) · **DEX** 10 (+0) · **CON** 19 (+4) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 4 (1100 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Hold Breath.** The crocodile can hold its breath for 30 minutes.

### Actions
- **Bite.** *Melee Attack Roll:* +8, reach 5 ft. *Hit:* 21 (3d10 + 5) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 76, 'hp_dice': '8d10+32', 'speed_walk_ft': 40, 'speed_swim_ft': 30, 'stat_block': {'STR': 21, 'DEX': 10, 'CON': 19, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '4', 'xp': 1100, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Hold Breath (Crocodile)')], 'action_refs': [ref('creature-action', 'Bite (Hippopotamus)')]}),
      packEntity(slug: 'animal', name: 'Hyena', description: r'''A scavenging carnivore that hunts in cackling packs.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 11 · **HP** 5 (1d8+1)
- **Speed** walk 50 ft.
- **STR** 11 (+0) · **DEX** 13 (+1) · **CON** 12 (+1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 5 (-3)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Bite.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 3 (1d6) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 1, 'initiative_score': 11, 'hp_average': 5, 'hp_dice': '1d8+1', 'speed_walk_ft': 50, 'stat_block': {'STR': 11, 'DEX': 13, 'CON': 12, 'INT': 2, 'WIS': 12, 'CHA': 5}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Bite (Hyena)')]}),
      packEntity(slug: 'animal', name: 'Jackal', description: r'''A small wild canine that scavenges in groups.

### Statistics
- **Small Beast**, Unaligned
- **AC** 12 · **HP** 3 (1d6)
- **Speed** walk 40 ft.
- **STR** 8 (-1) · **DEX** 15 (+2) · **CON** 11 (+0) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Keen Hearing.** The creature has Advantage on Wisdom (Perception) checks that rely on hearing.
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.
- **Pack Tactics.** The creature has Advantage on attack rolls against a creature if at least one of the creature's allies is within 5 feet of the target and the ally doesn't have the Incapacitated condition.

### Actions
- **Bite.** *Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 (1d4 − 1) Piercing damage.''', attributes: {'size_ref': lookup('size', 'Small'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 3, 'hp_dice': '1d6', 'speed_walk_ft': 40, 'stat_block': {'STR': 8, 'DEX': 15, 'CON': 11, 'INT': 3, 'WIS': 12, 'CHA': 6}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Keen Hearing'), ref('trait', 'Keen Smell'), ref('trait', 'Pack Tactics')], 'action_refs': [ref('creature-action', 'Bite (Jackal)')]}),
      packEntity(slug: 'animal', name: 'Lizard', description: r'''A small reptile common in warm climates.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 10 · **HP** 2 (1d4)
- **Speed** walk 20 ft., climb 20 ft.
- **STR** 2 (-4) · **DEX** 11 (+0) · **CON** 10 (+0) · **INT** 1 (-5) · **WIS** 8 (-1) · **CHA** 3 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Darkvision 30 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 2, 'hp_dice': '1d4', 'speed_walk_ft': 20, 'speed_climb_ft': 20, 'stat_block': {'STR': 2, 'DEX': 11, 'CON': 10, 'INT': 1, 'WIS': 8, 'CHA': 3}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'action_refs': [ref('creature-action', 'Bite (Lizard)')]}),
      packEntity(slug: 'animal', name: 'Mule', description: r'''A sturdy hybrid pack animal, common as a beast of burden.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 10 · **HP** 11 (2d8+2)
- **Speed** walk 40 ft.
- **STR** 14 (+2) · **DEX** 10 (+0) · **CON** 13 (+1) · **INT** 2 (-4) · **WIS** 10 (+0) · **CHA** 5 (-3)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10

### Traits
- **Beast of Burden.** The creature is considered Large for the purpose of determining its carrying capacity.
- **Sure-Footed.** The creature has Advantage on Strength and Dexterity saving throws made against effects that would knock it Prone.

### Actions
- **Hooves.** *Melee Attack Roll:* +2, reach 5 ft. *Hit:* 4 (1d4 + 2) Bludgeoning damage.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 10, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 11, 'hp_dice': '2d8+2', 'speed_walk_ft': 40, 'stat_block': {'STR': 14, 'DEX': 10, 'CON': 13, 'INT': 2, 'WIS': 10, 'CHA': 5}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10, 'trait_refs': [ref('trait', 'Beast of Burden'), ref('trait', 'Sure-Footed')], 'action_refs': [ref('creature-action', 'Hooves (Mule)')]}),
      packEntity(slug: 'animal', name: 'Panther', description: r'''A sleek black predator that ambushes prey from above.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 13 (3d8)
- **Speed** walk 50 ft., climb 40 ft.
- **STR** 14 (+2) · **DEX** 15 (+2) · **CON** 10 (+0) · **INT** 3 (-4) · **WIS** 14 (+2) · **CHA** 7 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 14

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.
- **Pounce.** If the panther moves at least 20 feet straight toward a creature and then hits it with a Bite attack on the same turn, the target must succeed on a DC 12 Strength save or have the Prone condition. If the target has the Prone condition, the panther can make one Bite attack against it as a Bonus Action.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 13, 'hp_dice': '3d8', 'speed_walk_ft': 50, 'speed_climb_ft': 40, 'stat_block': {'STR': 14, 'DEX': 15, 'CON': 10, 'INT': 3, 'WIS': 14, 'CHA': 7}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 14, 'trait_refs': [ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Bite (Panther)'), ref('creature-action', 'Pounce (Panther)')]}),
      packEntity(slug: 'animal', name: 'Piranha', description: r'''A toothy fish notorious for swarming prey.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 13 · **HP** 1 (1d4-1)
- **Speed** swim 40 ft.
- **STR** 2 (-4) · **DEX** 16 (+3) · **CON** 9 (-1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 2 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Darkvision 60 ft.

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bite.** *Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage, or 0 if the piranha has half its HP or fewer.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 0, 'speed_swim_ft': 40, 'stat_block': {'STR': 2, 'DEX': 16, 'CON': 9, 'INT': 1, 'WIS': 7, 'CHA': 2}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'trait_refs': [ref('trait', 'Blood Frenzy'), ref('trait', 'Water Breathing (Animal)')], 'action_refs': [ref('creature-action', 'Bite (Piranha)')]}),
      packEntity(slug: 'animal', name: 'Raven', description: r'''A clever black bird capable of mimicking sounds.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 12 · **HP** 1 (1d4-1)
- **Speed** walk 10 ft., fly 50 ft.
- **STR** 2 (-4) · **DEX** 14 (+2) · **CON** 8 (-1) · **INT** 4 (-3) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13

### Traits
- **Mimicry.** The creature can mimic simple sounds it has heard, such as a person whispering, a baby crying, or an animal chittering. A creature can discern the sounds are imitations with a successful Wisdom (Insight) check (DC 14).

### Actions
- **Beak.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 1 Piercing damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 10, 'speed_fly_ft': 50, 'stat_block': {'STR': 2, 'DEX': 14, 'CON': 8, 'INT': 4, 'WIS': 12, 'CHA': 6}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'trait_refs': [ref('trait', 'Mimicry')], 'action_refs': [ref('creature-action', 'Beak (Raven)')]}),
      packEntity(slug: 'animal', name: 'Saber-Toothed Tiger', description: r'''A prehistoric cat with massive saber-like fangs.

### Statistics
- **Large Beast**, Unaligned
- **AC** 12 · **HP** 52 (7d10+14)
- **Speed** walk 40 ft.
- **STR** 18 (+4) · **DEX** 14 (+2) · **CON** 15 (+2) · **INT** 3 (-4) · **WIS** 12 (+1) · **CHA** 8 (-1)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 15

### Traits
- **Keen Smell.** The creature has Advantage on Wisdom (Perception) checks that rely on smell.

### Actions
- **Bite.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (1d10 + 5) Piercing damage.
- **Claw.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 12 (2d6 + 5) Slashing damage.''', attributes: {'size_ref': lookup('size', 'Large'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 52, 'hp_dice': '7d10+14', 'speed_walk_ft': 40, 'stat_block': {'STR': 18, 'DEX': 14, 'CON': 15, 'INT': 3, 'WIS': 12, 'CHA': 8}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 15, 'trait_refs': [ref('trait', 'Keen Smell')], 'action_refs': [ref('creature-action', 'Bite (Saber-Toothed Tiger)'), ref('creature-action', 'Claw (Saber-Toothed Tiger)')]}),
      packEntity(slug: 'animal', name: 'Scorpion', description: r'''A small venomous arachnid with pincer claws and a stinger.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 11 · **HP** 1 (1d4-1)
- **Speed** walk 10 ft.
- **STR** 2 (-4) · **DEX** 11 (+0) · **CON** 8 (-1) · **INT** 1 (-5) · **WIS** 8 (-1) · **CHA** 2 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 9
- **Senses** Blindsight 10 ft.

### Actions
- **Sting.** *Melee Attack Roll:* +3, reach 5 ft. *Hit:* 1 Piercing damage. The target must make a DC 9 Constitution save, taking 4 (1d8) Poison damage on a fail or half on a success.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 11, 'initiative_modifier': 0, 'initiative_score': 10, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 10, 'stat_block': {'STR': 2, 'DEX': 11, 'CON': 8, 'INT': 1, 'WIS': 8, 'CHA': 2}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 9, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}], 'action_refs': [ref('creature-action', 'Sting (Scorpion)')]}),
      packEntity(slug: 'animal', name: 'Spider', description: r'''A small spider with a weak venomous bite.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 12 · **HP** 1 (1d4-1)
- **Speed** walk 20 ft., climb 20 ft.
- **STR** 2 (-4) · **DEX** 14 (+2) · **CON** 8 (-1) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 2 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 12
- **Senses** Darkvision 30 ft.

### Traits
- **Spider Climb.** The creature can climb difficult surfaces, including upside down on ceilings, without an ability check.
- **Web Walker.** The creature ignores movement restrictions caused by webbing.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 1 Piercing damage plus 2 (1d4) Poison damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 20, 'speed_climb_ft': 20, 'stat_block': {'STR': 2, 'DEX': 14, 'CON': 8, 'INT': 1, 'WIS': 10, 'CHA': 2}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 12, 'senses': [{'sense': 'Darkvision', 'range_ft': 30}], 'trait_refs': [ref('trait', 'Spider Climb'), ref('trait', 'Web Walker')], 'action_refs': [ref('creature-action', 'Bite (Spider)')]}),
      packEntity(slug: 'animal', name: 'Venomous Snake', description: r'''A small biting serpent with potent venom.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 12 · **HP** 5 (2d4)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 2 (-4) · **DEX** 15 (+2) · **CON** 11 (+0) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 1/8 (25 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Blindsight 10 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 3 (1d6) Poison damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 5, 'hp_dice': '2d4', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'stat_block': {'STR': 2, 'DEX': 15, 'CON': 11, 'INT': 1, 'WIS': 10, 'CHA': 3}, 'cr': '1/8', 'xp': 25, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}], 'action_refs': [ref('creature-action', 'Bite (Venomous Snake)')]}),
      packEntity(slug: 'animal', name: 'Weasel', description: r'''A small ferret-like predator.

### Statistics
- **Tiny Beast**, Unaligned
- **AC** 13 · **HP** 1 (1d4-1)
- **Speed** walk 30 ft., climb 30 ft.
- **STR** 3 (-4) · **DEX** 16 (+3) · **CON** 8 (-1) · **INT** 2 (-4) · **WIS** 12 (+1) · **CHA** 3 (-4)
- **CR** 0 (10 XP) · **Proficiency Bonus** +2 · **Passive Perception** 13
- **Senses** Darkvision 60 ft.

### Actions
- **Bite.** *Melee Attack Roll:* +5, reach 5 ft. *Hit:* 1 Piercing damage.''', attributes: {'size_ref': lookup('size', 'Tiny'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 1, 'hp_dice': '1d4-1', 'speed_walk_ft': 30, 'speed_climb_ft': 30, 'stat_block': {'STR': 3, 'DEX': 16, 'CON': 8, 'INT': 2, 'WIS': 12, 'CHA': 3}, 'cr': '0', 'xp': 10, 'proficiency_bonus': 2, 'passive_perception': 13, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'action_refs': [ref('creature-action', 'Bite (Weasel)')]}),
      packEntity(slug: 'animal', name: 'Swarm of Piranhas', description: r'''A frenzied school of piranhas that strips prey to bones in seconds.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 13 · **HP** 28 (8d8-8)
- **Speed** swim 40 ft.
- **STR** 13 (+1) · **DEX** 16 (+3) · **CON** 9 (-1) · **INT** 1 (-5) · **WIS** 7 (-2) · **CHA** 2 (-4)
- **CR** 1 (200 XP) · **Proficiency Bonus** +2 · **Passive Perception** 8
- **Senses** Darkvision 60 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Blood Frenzy.** The creature has Advantage on attack rolls against any creature that doesn't have all its HP.
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.
- **Water Breathing.** The creature can breathe only underwater.

### Actions
- **Bites.** *Melee Attack Roll:* +5, reach 0 ft. *Hit:* 14 (4d6) Piercing damage, or 7 (2d6) if the swarm has half its HP or fewer.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 13, 'initiative_modifier': 3, 'initiative_score': 13, 'hp_average': 28, 'hp_dice': '8d8-8', 'speed_walk_ft': 0, 'speed_swim_ft': 40, 'stat_block': {'STR': 13, 'DEX': 16, 'CON': 9, 'INT': 1, 'WIS': 7, 'CHA': 2}, 'cr': '1', 'xp': 200, 'proficiency_bonus': 2, 'passive_perception': 8, 'senses': [{'sense': 'Darkvision', 'range_ft': 60}], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Prone'), lookup('condition', 'Restrained'), lookup('condition', 'Stunned')], 'trait_refs': [ref('trait', 'Blood Frenzy'), ref('trait', 'Swarm'), ref('trait', 'Water Breathing (Animal)')], 'action_refs': [ref('creature-action', 'Bites (Swarm of Piranhas)')]}),
      packEntity(slug: 'animal', name: 'Swarm of Ravens', description: r'''A flock of mimicking ravens that descends in a deafening cloud.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 12 · **HP** 24 (7d8-7)
- **Speed** walk 10 ft., fly 50 ft.
- **STR** 6 (-2) · **DEX** 14 (+2) · **CON** 8 (-1) · **INT** 4 (-3) · **WIS** 12 (+1) · **CHA** 6 (-2)
- **CR** 1/4 (50 XP) · **Proficiency Bonus** +2 · **Passive Perception** 15
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.

### Actions
- **Beaks.** *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d6) Piercing damage, or 3 (1d6) if the swarm has half its HP or fewer.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 12, 'initiative_modifier': 2, 'initiative_score': 12, 'hp_average': 24, 'hp_dice': '7d8-7', 'speed_walk_ft': 10, 'speed_fly_ft': 50, 'stat_block': {'STR': 6, 'DEX': 14, 'CON': 8, 'INT': 4, 'WIS': 12, 'CHA': 6}, 'cr': '1/4', 'xp': 50, 'proficiency_bonus': 2, 'passive_perception': 15, 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Prone'), lookup('condition', 'Restrained'), lookup('condition', 'Stunned')], 'trait_refs': [ref('trait', 'Swarm')], 'action_refs': [ref('creature-action', 'Beaks (Swarm of Ravens)')]}),
      packEntity(slug: 'animal', name: 'Swarm of Venomous Snakes', description: r'''A writhing knot of venomous snakes that surges across the ground.

### Statistics
- **Medium Beast**, Unaligned
- **AC** 14 · **HP** 36 (8d8)
- **Speed** walk 30 ft., swim 30 ft.
- **STR** 8 (-1) · **DEX** 18 (+4) · **CON** 11 (+0) · **INT** 1 (-5) · **WIS** 10 (+0) · **CHA** 3 (-4)
- **CR** 2 (450 XP) · **Proficiency Bonus** +2 · **Passive Perception** 10
- **Senses** Blindsight 10 ft.
- **Damage Resistances** Bludgeoning, Piercing, Slashing
- **Condition Immunities** Charmed, Frightened, Grappled, Paralyzed, Petrified, Prone, Restrained, Stunned

### Traits
- **Swarm.** The swarm can occupy another creature's space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can't regain HP or gain Temporary HP.

### Actions
- **Bites.** *Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (4d6) Piercing damage plus 14 (4d6) Poison damage, or half each if the swarm has half its HP or fewer.''', attributes: {'size_ref': lookup('size', 'Medium'), 'creature_type_ref': lookup('creature-type', 'Beast'), 'alignment_ref': lookup('alignment', 'Unaligned'), 'ac': 14, 'initiative_modifier': 4, 'initiative_score': 14, 'hp_average': 36, 'hp_dice': '8d8', 'speed_walk_ft': 30, 'speed_swim_ft': 30, 'stat_block': {'STR': 8, 'DEX': 18, 'CON': 11, 'INT': 1, 'WIS': 10, 'CHA': 3}, 'cr': '2', 'xp': 450, 'proficiency_bonus': 2, 'passive_perception': 10, 'senses': [{'sense': 'Blindsight', 'range_ft': 10}], 'resistance_refs': [lookup('damage-type', 'Bludgeoning'), lookup('damage-type', 'Piercing'), lookup('damage-type', 'Slashing')], 'condition_immunity_refs': [lookup('condition', 'Charmed'), lookup('condition', 'Frightened'), lookup('condition', 'Grappled'), lookup('condition', 'Paralyzed'), lookup('condition', 'Petrified'), lookup('condition', 'Prone'), lookup('condition', 'Restrained'), lookup('condition', 'Stunned')], 'trait_refs': [ref('trait', 'Swarm')], 'action_refs': [ref('creature-action', 'Bites (Swarm of Venomous Snakes)')]}),
    ];
