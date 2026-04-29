// SRD 5.2.1 Species (pp. 83–86): Dragonborn, Dwarf, Elf, Gnome, Goliath,
// Halfling, Human, Orc, Tiefling. All Humanoid. Speed 30 ft. except Goliath
// (35 ft.) and Wood Elf lineage. Lineage / ancestry tables preserved verbatim
// in the `traits` markdown body so the card retains the SRD's nested choice
// presentation.

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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
        },
      ),
    ];
