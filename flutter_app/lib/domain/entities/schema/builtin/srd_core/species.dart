// SRD 5.2.1 Species (pp. 83–86): Dragonborn, Dwarf, Elf, Gnome, Goliath,
// Halfling, Human, Orc, Tiefling — plus Half-Elf, an SRD 5.1 legacy species
// (dropped in 5.2.1) kept here as its own row because a subspecies can only
// ADD to its parent, and hanging it off Elf would wrongly grant Trance,
// Keen Senses and Elven Lineage. All Humanoid. Speed 30 ft. except Goliath
// (35 ft.). Lineages / ancestries (Drow, High Elf, Hill Dwarf, the Dragonborn
// colors, …) ship as first-class `subspecies` entities in subspecies.dart,
// each pointing back here via `parent_species_ref`.

import '_helpers.dart';

List<Map<String, dynamic>> srdSpecies() => [
      packEntity(
        slug: 'species',
        name: 'Dragonborn',
        description:
            'Descendants of dragons, bearing scales, breath weapon, and damage resistance keyed to a chosen ancestry.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Draconic Ancestry'),
            ref('trait', 'Damage Resistance (Dragonborn)'),
          ],
          'granted_action_refs': [
            ref('creature-action', 'Breath Weapon (Dragonborn)'),
          ],
          'granted_bonus_action_refs': [
            ref('creature-action', 'Draconic Flight'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Dwarf',
        description:
            'Stout, hardy folk with poison resistance, tremorsense on stone, and heightened toughness.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
          'trait_refs': [
            ref('trait', 'Dwarven Resilience'),
            ref('trait', 'Dwarven Toughness'),
            ref('trait', 'Stonecunning'),
            ref('trait', 'Forge Wise'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Elf',
        description:
            'Fey-touched folk with Trance, charm resistance, keen senses, and a chosen Drow / High Elf / Wood Elf lineage.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Fey Ancestry'),
            ref('trait', 'Trance'),
            ref('trait', 'Keen Senses (Elf)'),
            ref('trait', 'Elven Lineage'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Gnome',
        description:
            'Small inventive folk with mental save advantage and a Forest / Rock lineage of innate magic.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Small'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Gnomish Cunning'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Goliath',
        description:
            'Giant-blooded Medium folk with a chosen Cloud / Fire / Frost / Hill / Stone / Storm Giant ancestry boon, plus optional Large Form starting at level 5.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 35,
          'trait_refs': [
            ref('trait', 'Powerful Build'),
            ref('trait', 'Large Form'),
            ref('trait', 'Giant Ancestry'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Half-Elf',
        source: 'SRD 5.1',
        description:
            'Human-elf heritage: Fey Ancestry and Darkvision from the elven side, '
            'human adaptability as two free skill proficiencies. '
            '(SRD 5.1 legacy species — dropped from SRD 5.2.1, kept here for 2014-era characters.)',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'age': '180 years',
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'granted_languages': [
            lookup('language', 'Common'),
            lookup('language', 'Elvish'),
          ],
          'trait_refs': [
            ref('trait', 'Fey Ancestry'),
            ref('trait', 'Skill Versatility'),
          ],
          'mechanical_notes':
              'Ability scores come from your background, as for every other species '
              '(the 2024 rules moved the ASI off the species card). SRD 5.1 gave '
              'Half-Elf Charisma +2 and +1 to two other scores — deliberately not '
              'applied here, it would stack on top of the background ASI. '
              'Skill Versatility: choose the two skill proficiencies yourself. '
              'Languages: Common and Elvish (granted) plus one more of your choice.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Halfling',
        description:
            'Small, lucky folk who can hide behind larger creatures and reroll natural 1s.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Small'),
          'speed_ft': 30,
          'trait_refs': [
            ref('trait', 'Halfling Lucky'),
            ref('trait', 'Naturally Stealthy'),
            ref('trait', 'Brave'),
            ref('trait', 'Halfling Nimbleness'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Human',
        description:
            'Adaptable folk with bonus Heroic Inspiration on Long Rests, a free skill, and an Origin feat.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'trait_refs': [
            ref('trait', 'Resourceful'),
            ref('trait', 'Skilled (Human)'),
            ref('trait', 'Versatile (Human)'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Orc',
        description:
            'Adrenaline-driven warriors with bonus-action Dash, temporary HP, and Relentless Endurance.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Powerful Build'),
          ],
          'granted_bonus_action_refs': [
            ref('creature-action', 'Adrenaline Rush'),
          ],
          'granted_reaction_refs': [
            ref('creature-action', 'Relentless Endurance'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Tiefling',
        description:
            'Fiend-blooded folk with a chosen Abyssal / Chthonic / Infernal legacy granting damage resistance and innate spells.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [
            {'sense_ref': lookup('sense', 'Darkvision'), 'range_ft': 60},
          ],
          'trait_refs': [
            ref('trait', 'Otherworldly Presence'),
            ref('trait', 'Fiendish Legacy'),
          ],
        },
      ),
    ];
