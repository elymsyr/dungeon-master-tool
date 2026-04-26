// SRD 5.2.1 Backgrounds (p. 83): Acolyte, Criminal, Sage, Soldier. Only four
// backgrounds shipped with 5.2.1 — much smaller list than the 2014 5e SRD.
// Equipment option B is a flat 50 GP per background. `default_inventory_refs`
// covers option A (typed list of gear/weapon/armor/tool/pack/ammunition refs).

import '_helpers.dart';

List<Map<String, dynamic>> srdBackgrounds() => [
      packEntity(
        slug: 'background',
        name: 'Acolyte',
        description:
            'You spent your formative years tending an altar, mediating between the mortal and the divine.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'origin_feat_ref': ref('feat', 'Magic Initiate'),
          'granted_skill_refs': [
            lookup('skill', 'Insight'),
            lookup('skill', 'Religion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
          ],
          'default_inventory_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
            ref('adventuring-gear', 'Book'),
            ref('adventuring-gear', 'Amulet (Holy Symbol)'),
            ref('adventuring-gear', 'Parchment'),
            ref('adventuring-gear', 'Robe'),
          ],
          'starting_gold_gp': 8,
          'gold_alternative_gp': 50,
          'starting_equipment':
              'Choose A or B:\n\n'
                  '- **(A)** Calligrapher\'s Supplies, Book (prayers), Holy Symbol, Parchment (10 sheets), Robe, 8 GP\n'
                  '- **(B)** 50 GP\n\n'
                  'The Magic Initiate feat granted by this background uses the Cleric spell list.',
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Criminal',
        description:
            'You learned to operate outside the law — picking pockets, breaking into homes, or fencing stolen goods.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
          ],
          'origin_feat_ref': ref('feat', 'Alert'),
          'granted_skill_refs': [
            lookup('skill', 'Sleight of Hand'),
            lookup('skill', 'Stealth'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Thieves\' Tools'),
          ],
          'default_inventory_refs': [
            ref('weapon', 'Dagger'),
            ref('weapon', 'Dagger'),
            ref('tool', 'Thieves\' Tools'),
            ref('adventuring-gear', 'Crowbar'),
            ref('adventuring-gear', 'Pouch'),
            ref('adventuring-gear', 'Pouch'),
            ref('adventuring-gear', 'Clothes, Traveler\'s'),
          ],
          'starting_gold_gp': 16,
          'gold_alternative_gp': 50,
          'starting_equipment':
              'Choose A or B:\n\n'
                  '- **(A)** 2 Daggers, Thieves\' Tools, Crowbar, 2 Pouches, Traveler\'s Clothes, 16 GP\n'
                  '- **(B)** 50 GP',
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Sage',
        description:
            'You spent years devoted to the study of the multiverse and have an academic\'s breadth of knowledge.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
          ],
          'origin_feat_ref': ref('feat', 'Magic Initiate'),
          'granted_skill_refs': [
            lookup('skill', 'Arcana'),
            lookup('skill', 'History'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
          ],
          'default_inventory_refs': [
            ref('weapon', 'Quarterstaff'),
            ref('tool', 'Calligrapher\'s Supplies'),
            ref('adventuring-gear', 'Book'),
            ref('adventuring-gear', 'Parchment'),
            ref('adventuring-gear', 'Robe'),
          ],
          'starting_gold_gp': 8,
          'gold_alternative_gp': 50,
          'starting_equipment':
              'Choose A or B:\n\n'
                  '- **(A)** Quarterstaff, Calligrapher\'s Supplies, Book (history), Parchment (8 sheets), Robe, 8 GP\n'
                  '- **(B)** 50 GP\n\n'
                  'The Magic Initiate feat granted by this background uses the Wizard spell list.',
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Soldier',
        description:
            'You trained as a soldier, learning warfare in service to a banner, mercenary company, or warlord.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
          ],
          'origin_feat_ref': ref('feat', 'Savage Attacker'),
          'granted_skill_refs': [
            lookup('skill', 'Athletics'),
            lookup('skill', 'Intimidation'),
          ],
          // Tool: one chosen Gaming Set kind. The pack-level `tool` slug only
          // ships the generic "Gaming Set" tool; the variant is a player choice.
          'default_inventory_refs': [
            ref('weapon', 'Spear'),
            ref('weapon', 'Shortbow'),
            ref('ammunition', 'Arrows'),
            ref('adventuring-gear', 'Healer\'s Kit'),
            ref('adventuring-gear', 'Quiver'),
            ref('adventuring-gear', 'Clothes, Traveler\'s'),
          ],
          'starting_gold_gp': 14,
          'gold_alternative_gp': 50,
          'starting_equipment':
              'Choose A or B:\n\n'
                  '- **(A)** Spear, Shortbow, 20 Arrows, Gaming Set (one chosen kind), Healer\'s Kit, Quiver, Traveler\'s Clothes, 14 GP\n'
                  '- **(B)** 50 GP\n\n'
                  '**Tool Proficiency.** Choose one kind of Gaming Set (Dice, Dragonchess, Playing Cards, or Three-Dragon Ante).',
        },
      ),
    ];
