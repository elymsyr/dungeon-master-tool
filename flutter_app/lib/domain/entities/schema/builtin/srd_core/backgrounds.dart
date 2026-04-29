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
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Magic Initiate'),
          'granted_skill_refs': [
            lookup('skill', 'Insight'),
            lookup('skill', 'Religion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
          ],
          'starting_gold_gp': 8,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Calligrapher\'s Supplies, Book, Holy Symbol, Parchment, Robe, 8 GP',
                  items: [
                    eqItem('tool', 'Calligrapher\'s Supplies'),
                    eqItem('adventuring-gear', 'Book'),
                    eqItem('adventuring-gear', 'Amulet (Holy Symbol)'),
                    eqItem('adventuring-gear', 'Parchment', qty: 10),
                    eqItem('adventuring-gear', 'Robe'),
                  ],
                  goldGp: 8,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
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
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Alert'),
          'granted_skill_refs': [
            lookup('skill', 'Sleight of Hand'),
            lookup('skill', 'Stealth'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Thieves\' Tools'),
          ],
          'starting_gold_gp': 16,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: '2 Daggers, Thieves\' Tools, Crowbar, 2 Pouches, Traveler\'s Clothes, 16 GP',
                  items: [
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('tool', 'Thieves\' Tools'),
                    eqItem('adventuring-gear', 'Crowbar'),
                    eqItem('adventuring-gear', 'Pouch', qty: 2),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 16,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
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
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Magic Initiate'),
          'granted_skill_refs': [
            lookup('skill', 'Arcana'),
            lookup('skill', 'History'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
          ],
          'starting_gold_gp': 8,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Quarterstaff, Calligrapher\'s Supplies, Book, Parchment, Robe, 8 GP',
                  items: [
                    eqItem('weapon', 'Quarterstaff'),
                    eqItem('tool', 'Calligrapher\'s Supplies'),
                    eqItem('adventuring-gear', 'Book'),
                    eqItem('adventuring-gear', 'Parchment', qty: 8),
                    eqItem('adventuring-gear', 'Robe'),
                  ],
                  goldGp: 8,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
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
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Savage Attacker'),
          'granted_skill_refs': [
            lookup('skill', 'Athletics'),
            lookup('skill', 'Intimidation'),
          ],
          'starting_gold_gp': 14,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Spear, Shortbow, 20 Arrows, Gaming Set, Healer\'s Kit, Quiver, Traveler\'s Clothes, 14 GP',
                  items: [
                    eqItem('weapon', 'Spear'),
                    eqItem('weapon', 'Shortbow'),
                    eqItem('ammunition', 'Arrows', qty: 20),
                    eqItem('adventuring-gear', 'Healer\'s Kit'),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 14,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
    ];
