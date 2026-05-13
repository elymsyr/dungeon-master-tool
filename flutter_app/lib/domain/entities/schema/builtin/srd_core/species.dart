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
          'subspecies_options': [
            {
              'name': 'Black',
              'description': 'Acid breath weapon and Acid resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Acid')],
            },
            {
              'name': 'Blue',
              'description': 'Lightning breath weapon and Lightning resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Lightning')],
            },
            {
              'name': 'Brass',
              'description': 'Fire breath weapon and Fire resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Fire')],
            },
            {
              'name': 'Bronze',
              'description': 'Lightning breath weapon and Lightning resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Lightning')],
            },
            {
              'name': 'Copper',
              'description': 'Acid breath weapon and Acid resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Acid')],
            },
            {
              'name': 'Gold',
              'description': 'Fire breath weapon and Fire resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Fire')],
            },
            {
              'name': 'Green',
              'description': 'Poison breath weapon and Poison resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Poison')],
            },
            {
              'name': 'Red',
              'description': 'Fire breath weapon and Fire resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Fire')],
            },
            {
              'name': 'Silver',
              'description': 'Cold breath weapon and Cold resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Cold')],
            },
            {
              'name': 'White',
              'description': 'Cold breath weapon and Cold resistance.',
              'granted_damage_resistances': [lookup('damage-type', 'Cold')],
            },
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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
          'trait_refs': [
            ref('trait', 'Fey Ancestry'),
            ref('trait', 'Trance'),
            ref('trait', 'Keen Senses (Elf)'),
            ref('trait', 'Elven Lineage'),
          ],
          'subspecies_options': [
            {
              'name': 'Drow',
              'description':
                  'Superior Darkvision (120 ft. — replaces base Darkvision). Innate spells: Dancing Lights (L1), Faerie Fire (L3, 1/day), Darkness (L5, 1/day).',
              'granted_modifiers': const <Map<String, dynamic>>[],
            },
            {
              'name': 'High Elf',
              'description':
                  'Innate spells: a Wizard cantrip (L1), Detect Magic (L3, 1/day), Misty Step (L5, 1/day).',
              'granted_modifiers': const <Map<String, dynamic>>[],
            },
            {
              'name': 'Wood Elf',
              'description':
                  'Speed 35 ft (+5 ft from base). Innate spells: Druidcraft (L1), Longstrider (L3, 1/day), Pass without Trace (L5, 1/day).',
              'granted_modifiers': [
                {'kind': 'speed_bonus', 'value': 5},
              ],
            },
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
          'granted_senses': [lookup('sense', 'Darkvision')],
          'trait_refs': [
            ref('trait', 'Gnomish Cunning'),
          ],
          'subspecies_options': [
            {
              'name': 'Forest Gnome',
              'description':
                  'Minor Illusion cantrip. Speak with Small Beasts (telepathic).',
              'granted_modifiers': const <Map<String, dynamic>>[],
            },
            {
              'name': 'Rock Gnome',
              'description':
                  "Artificer's Lore (double prof on magic-item History). Tinker (Mending + Prestidigitation, build clockwork toys).",
              'granted_modifiers': const <Map<String, dynamic>>[],
            },
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
          'subspecies_options': [
            {
              'name': 'Cloud Giant',
              'description':
                  "Cloud's Jaunt — Bonus Action teleport 30 ft to an unoccupied space you can see; uses = PB per Long Rest.",
              'granted_modifiers': const <Map<String, dynamic>>[],
              'granted_bonus_action_refs': [
                ref('creature-action', "Cloud's Jaunt"),
              ],
            },
            {
              'name': 'Fire Giant',
              'description':
                  "Fire's Burn — when you hit a target and deal damage, also deal 1d10 Fire damage.",
              'granted_action_refs': [
                ref('creature-action', "Fire's Burn"),
              ],
            },
            {
              'name': 'Frost Giant',
              'description':
                  "Frost's Chill — when you hit a target and deal damage, also deal 1d6 Cold damage and reduce its Speed by 10 ft.",
              'granted_action_refs': [
                ref('creature-action', "Frost's Chill"),
              ],
            },
            {
              'name': 'Hill Giant',
              'description':
                  "Hill's Tumble — when you hit with a melee attack you can knock Large or smaller creatures Prone; uses = PB per Long Rest.",
              'granted_modifiers': const <Map<String, dynamic>>[],
              'granted_reaction_refs': [
                ref('creature-action', "Hill's Tumble"),
              ],
            },
            {
              'name': 'Stone Giant',
              'description':
                  "Stone's Endurance — Reaction: roll d12 + Con mod, reduce damage taken by that amount; uses = PB per Long Rest.",
              'granted_modifiers': const <Map<String, dynamic>>[],
              'granted_reaction_refs': [
                ref('creature-action', "Stone's Endurance"),
              ],
            },
            {
              'name': 'Storm Giant',
              'description':
                  "Storm's Thunder — when you take damage from a creature within 60 ft, Reaction to deal 1d8 Thunder damage.",
              'granted_reaction_refs': [
                ref('creature-action', "Storm's Thunder"),
              ],
            },
          ],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
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
          'granted_senses': [lookup('sense', 'Darkvision')],
          'trait_refs': [
            ref('trait', 'Otherworldly Presence'),
            ref('trait', 'Fiendish Legacy'),
          ],
          'subspecies_options': [
            {
              'name': 'Abyssal',
              'description':
                  'Poison resistance. Innate spells: Poison Spray (L1), Ray of Sickness (L3, 1/day), Hold Person (L5, 1/day).',
              'granted_damage_resistances': [lookup('damage-type', 'Poison')],
            },
            {
              'name': 'Chthonic',
              'description':
                  'Necrotic resistance. Innate spells: Chill Touch (L1), False Life (L3, 1/day), Ray of Enfeeblement (L5, 1/day).',
              'granted_damage_resistances': [lookup('damage-type', 'Necrotic')],
            },
            {
              'name': 'Infernal',
              'description':
                  'Fire resistance. Innate spells: Fire Bolt (L1), Hellish Rebuke (L3, 1/day), Darkness (L5, 1/day).',
              'granted_damage_resistances': [lookup('damage-type', 'Fire')],
            },
          ],
        },
      ),
    ];
