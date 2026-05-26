// SRD 5.2.1 Backgrounds (Free Rules 2024 §1.4): all 16 standard backgrounds —
// Acolyte, Artisan, Charlatan, Criminal, Entertainer, Farmer, Guard, Guide,
// Hermit, Merchant, Noble, Sage, Sailor, Scribe, Soldier, Wayfarer. Each
// grants two skill proficiencies, one tool/instrument proficiency, an origin
// feat, and 3-32 GP plus a typed starting-kit option. Equipment option B is
// a flat 50 GP per background. `granted_skill_refs` + `granted_tool_refs`
// feed the resolver; `equipment_choice_groups` feeds the wizard's equipment
// step.

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
          // SRD 5.2.1 p. 83: Soldier picks one Gaming Set variant. The wizard
          // surfaces this as a variant picker rather than a fixed grant.
          'granted_tool_variant_group': 'gaming_set',
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
      packEntity(
        slug: 'background',
        name: 'Artisan',
        description:
            'You began your career as the apprentice of an artisan, learning a trade and the value of careful craft.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Intelligence'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Crafter'),
          'granted_skill_refs': [
            lookup('skill', 'Investigation'),
            lookup('skill', 'Persuasion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Smith\'s Tools'),
          ],
          'starting_gold_gp': 32,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Smith\'s Tools, 2 Pouches, Traveler\'s Clothes, 32 GP',
                  items: [
                    eqItem('tool', 'Smith\'s Tools'),
                    eqItem('adventuring-gear', 'Pouch', qty: 2),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 32,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Charlatan',
        description:
            'You learned to charm marks and bend the truth — a smile and a forged document can open doors that locks can\'t.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Skilled'),
          'granted_skill_refs': [
            lookup('skill', 'Deception'),
            lookup('skill', 'Sleight of Hand'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Forgery Kit'),
          ],
          'starting_gold_gp': 15,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Forgery Kit, Costume, Fine Clothes, Pouch, 15 GP',
                  items: [
                    eqItem('tool', 'Forgery Kit'),
                    eqItem('adventuring-gear', 'Costume'),
                    eqItem('adventuring-gear', 'Clothes, Fine'),
                    eqItem('adventuring-gear', 'Pouch'),
                  ],
                  goldGp: 15,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Entertainer',
        description:
            'You play the crowd — dancer, juggler, singer, or storyteller — turning attention into coin.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Musician'),
          'granted_skill_refs': [
            lookup('skill', 'Acrobatics'),
            lookup('skill', 'Performance'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Flute'),
          ],
          'starting_gold_gp': 11,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Flute, Costume, Mirror, 2 Pouches, Traveler\'s Clothes, 11 GP',
                  items: [
                    eqItem('tool', 'Flute'),
                    eqItem('adventuring-gear', 'Costume'),
                    eqItem('adventuring-gear', 'Mirror'),
                    eqItem('adventuring-gear', 'Pouch', qty: 2),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 11,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Farmer',
        description:
            'You grew up tilling the land, with weather-worn hands and a deep understanding of seasons, soil, and beasts.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Wisdom'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Tough'),
          'granted_skill_refs': [
            lookup('skill', 'Animal Handling'),
            lookup('skill', 'Nature'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Carpenter\'s Tools'),
          ],
          'starting_gold_gp': 30,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Carpenter\'s Tools, Shovel, Iron Pot, Healer\'s Kit, Traveler\'s Clothes, 30 GP',
                  items: [
                    eqItem('tool', 'Carpenter\'s Tools'),
                    eqItem('adventuring-gear', 'Shovel'),
                    eqItem('adventuring-gear', 'Pot, Iron'),
                    eqItem('adventuring-gear', 'Healer\'s Kit'),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 30,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Guard',
        description:
            'You patrolled gates and walls, watching for trouble and ready to call the alarm at the first sign of it.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Alert'),
          'granted_skill_refs': [
            lookup('skill', 'Athletics'),
            lookup('skill', 'Perception'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Gaming Set'),
          ],
          'starting_gold_gp': 12,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Spear, Light Crossbow, 20 Bolts, Gaming Set, Hooded Lantern, Manacles, Quiver, Traveler\'s Clothes, 12 GP',
                  items: [
                    eqItem('weapon', 'Spear'),
                    eqItem('weapon', 'Crossbow, Light'),
                    eqItem('ammunition', 'Bolts', qty: 20),
                    eqItem('tool', 'Gaming Set'),
                    eqItem('adventuring-gear', 'Lantern, Hooded'),
                    eqItem('adventuring-gear', 'Manacles'),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 12,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Guide',
        description:
            'You spent your youth in wilderness places — trail, hunt, and map are second nature to you.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Constitution'),
            lookup('ability', 'Wisdom'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Magic Initiate'),
          'granted_skill_refs': [
            lookup('skill', 'Stealth'),
            lookup('skill', 'Survival'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Cartographer\'s Tools'),
          ],
          'starting_gold_gp': 3,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Shortbow, 20 Arrows, Cartographer\'s Tools, Bedroll, Quiver, Traveler\'s Clothes, 3 GP',
                  items: [
                    eqItem('weapon', 'Shortbow'),
                    eqItem('ammunition', 'Arrows', qty: 20),
                    eqItem('tool', 'Cartographer\'s Tools'),
                    eqItem('adventuring-gear', 'Bedroll'),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 3,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Hermit',
        description:
            'You withdrew from the world for years of contemplation, returning with insight and a knack for natural remedies.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Constitution'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Healer'),
          'granted_skill_refs': [
            lookup('skill', 'Medicine'),
            lookup('skill', 'Religion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Herbalism Kit'),
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
                  label: 'Quarterstaff, Herbalism Kit, Bedroll, Lamp, 3 Oil, 5 Parchment, Robe, 8 GP',
                  items: [
                    eqItem('weapon', 'Quarterstaff'),
                    eqItem('tool', 'Herbalism Kit'),
                    eqItem('adventuring-gear', 'Bedroll'),
                    eqItem('adventuring-gear', 'Lamp'),
                    eqItem('adventuring-gear', 'Oil', qty: 3),
                    eqItem('adventuring-gear', 'Parchment', qty: 5),
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
        name: 'Merchant',
        description:
            'You apprenticed to a trader, learning how to bargain, value cargo, and travel safely between markets.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Constitution'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Lucky'),
          'granted_skill_refs': [
            lookup('skill', 'Animal Handling'),
            lookup('skill', 'Persuasion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Navigator\'s Tools'),
          ],
          'starting_gold_gp': 22,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Navigator\'s Tools, 2 Pouches, Traveler\'s Clothes, 22 GP',
                  items: [
                    eqItem('tool', 'Navigator\'s Tools'),
                    eqItem('adventuring-gear', 'Pouch', qty: 2),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 22,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Noble',
        description:
            'You were raised in privilege among the upper echelons of society, taught the manners and politics of court.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Skilled'),
          'granted_skill_refs': [
            lookup('skill', 'History'),
            lookup('skill', 'Persuasion'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Gaming Set'),
          ],
          'starting_gold_gp': 29,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Gaming Set, Fine Clothes, Perfume, Signet Ring, 29 GP',
                  items: [
                    eqItem('tool', 'Gaming Set'),
                    eqItem('adventuring-gear', 'Clothes, Fine'),
                    eqItem('adventuring-gear', 'Perfume'),
                    eqItem('adventuring-gear', 'Signet Ring'),
                  ],
                  goldGp: 29,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Sailor',
        description:
            'You sailed on a seagoing ship for years, learning rigging, rope, and the ways of port-town life.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Wisdom'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Tavern Brawler'),
          'granted_skill_refs': [
            lookup('skill', 'Acrobatics'),
            lookup('skill', 'Perception'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Navigator\'s Tools'),
          ],
          'starting_gold_gp': 20,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Dagger, Navigator\'s Tools, Rope, Traveler\'s Clothes, 20 GP',
                  items: [
                    eqItem('weapon', 'Dagger'),
                    eqItem('tool', 'Navigator\'s Tools'),
                    eqItem('adventuring-gear', 'Rope'),
                    eqItem('adventuring-gear', 'Clothes, Traveler\'s'),
                  ],
                  goldGp: 20,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Scribe',
        description:
            'You worked as a scribe, copying manuscripts and learning to spot the smallest discrepancies in a document.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Skilled'),
          'granted_skill_refs': [
            lookup('skill', 'Investigation'),
            lookup('skill', 'Perception'),
          ],
          'granted_tool_refs': [
            ref('tool', 'Calligrapher\'s Supplies'),
          ],
          'starting_gold_gp': 24,
          'gold_alternative_gp': 50,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Calligrapher\'s Supplies, Fine Clothes, Lamp, 3 Oil, 12 Parchment, 24 GP',
                  items: [
                    eqItem('tool', 'Calligrapher\'s Supplies'),
                    eqItem('adventuring-gear', 'Clothes, Fine'),
                    eqItem('adventuring-gear', 'Lamp'),
                    eqItem('adventuring-gear', 'Oil', qty: 3),
                    eqItem('adventuring-gear', 'Parchment', qty: 12),
                  ],
                  goldGp: 24,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
        },
      ),
      packEntity(
        slug: 'background',
        name: 'Wayfarer',
        description:
            'You grew up on the road — orphan, traveler, or rootless wanderer — making your own way by wits and luck.',
        attributes: {
          'ability_score_options': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'asi_distribution_options': const ['+2/+1', '+1/+1/+1'],
          'origin_feat_ref': ref('feat', 'Lucky'),
          'granted_skill_refs': [
            lookup('skill', 'Insight'),
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
                  label: '2 Daggers, Thieves\' Tools, Gaming Set, Bedroll, 2 Pouches, Traveler\'s Clothes, 16 GP',
                  items: [
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('tool', 'Thieves\' Tools'),
                    eqItem('tool', 'Gaming Set'),
                    eqItem('adventuring-gear', 'Bedroll'),
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
    ];
