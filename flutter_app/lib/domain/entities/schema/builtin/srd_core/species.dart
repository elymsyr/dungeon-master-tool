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
          'size_ref': 'Medium',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'traits':
              '**Draconic Ancestry.** Your lineage stems from a dragon progenitor. Choose the kind of dragon from the Draconic Ancestors table. Your choice affects your Breath Weapon and Damage Resistance traits as well as your appearance.\n\n'
                  '**Draconic Ancestors**\n\n'
                  '| Dragon | Damage Type |\n|---|---|\n'
                  '| Black | Acid |\n| Blue | Lightning |\n| Brass | Fire |\n| Bronze | Lightning |\n| Copper | Acid |\n'
                  '| Gold | Fire |\n| Green | Poison |\n| Red | Fire |\n| Silver | Cold |\n| White | Cold |\n\n'
                  '**Breath Weapon.** When you take the Attack action on your turn, you can replace one of your attacks with an exhalation of magical energy in either a 15-foot Cone or a 30-foot Line that is 5 feet wide (choose the shape each time). Each creature in that area must make a Dexterity saving throw (DC 8 plus your Constitution modifier and Proficiency Bonus). On a failed save, a creature takes 1d10 damage of the type determined by your Draconic Ancestry trait. On a successful save, a creature takes half as much damage. This damage increases by 1d10 when you reach character levels 5 (2d10), 11 (3d10), and 17 (4d10).\n\n'
                  'You can use this Breath Weapon a number of times equal to your Proficiency Bonus, and you regain all expended uses when you finish a Long Rest.\n\n'
                  '**Damage Resistance.** You have Resistance to the damage type determined by your Draconic Ancestry trait.\n\n'
                  '**Darkvision.** You have Darkvision with a range of 60 feet.\n\n'
                  '**Draconic Flight.** When you reach character level 5, you can channel draconic magic to give yourself temporary flight. As a Bonus Action, you sprout spectral wings on your back that last for 10 minutes or until you retract the wings (no action required) or have the Incapacitated condition. During that time, you have a Fly Speed equal to your Speed. Your wings appear to be made of the same energy as your Breath Weapon. Once you use this trait, you can\'t use it again until you finish a Long Rest.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Dwarf',
        description:
            'Stout, hardy folk with poison resistance, tremorsense on stone, and heightened toughness.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
          'traits':
              '**Darkvision.** You have Darkvision with a range of 120 feet.\n\n'
                  '**Dwarven Resilience.** You have Resistance to Poison damage. You also have Advantage on saving throws you make to avoid or end the Poisoned condition.\n\n'
                  '**Dwarven Toughness.** Your Hit Point maximum increases by 1, and it increases by 1 again whenever you gain a level.\n\n'
                  '**Stonecunning.** As a Bonus Action, you gain Tremorsense with a range of 60 feet for 10 minutes. You must be on a stone surface or touching a stone surface to use this Tremorsense. The stone can be natural or worked.\n\n'
                  'You can use this Bonus Action a number of times equal to your Proficiency Bonus, and you regain all expended uses when you finish a Long Rest.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Elf',
        description:
            'Fey-touched folk with Trance, charm resistance, keen senses, and a chosen Drow / High Elf / Wood Elf lineage.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'traits':
              '**Darkvision.** You have Darkvision with a range of 60 feet.\n\n'
                  '**Elven Lineage.** You are part of a lineage that grants you supernatural abilities. Choose a lineage from the Elven Lineages table. You gain the level 1 benefit of that lineage.\n\n'
                  'When you reach character levels 3 and 5, you learn a higher-level spell, as shown on the table. You always have that spell prepared. You can cast it once without a spell slot, and you regain the ability to cast it in that way when you finish a Long Rest. You can also cast the spell using any spell slots you have of the appropriate level.\n\n'
                  'Intelligence, Wisdom, or Charisma is your spellcasting ability for the spells you cast with this trait (choose the ability when you select the lineage).\n\n'
                  '**Elven Lineages**\n\n'
                  '| Lineage | Level 1 | Level 3 | Level 5 |\n|---|---|---|---|\n'
                  '| Drow | The range of your Darkvision increases to 120 feet. You also know the Dancing Lights cantrip. | Faerie Fire | Darkness |\n'
                  '| High Elf | You know the Prestidigitation cantrip. Whenever you finish a Long Rest, you can replace that cantrip with a different cantrip from the Wizard spell list. | Detect Magic | Misty Step |\n'
                  '| Wood Elf | Your Speed increases to 35 feet. You also know the Druidcraft cantrip. | Longstrider | Pass without Trace |\n\n'
                  '**Fey Ancestry.** You have Advantage on saving throws you make to avoid or end the Charmed condition.\n\n'
                  '**Keen Senses.** You have proficiency in the Insight, Perception, or Survival skill.\n\n'
                  '**Trance.** You don\'t need to sleep, and magic can\'t put you to sleep. You can finish a Long Rest in 4 hours if you spend those hours in a trancelike meditation, during which you retain consciousness.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Gnome',
        description:
            'Small inventive folk with mental save advantage and a Forest / Rock lineage of innate magic.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Small',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'traits':
              '**Darkvision.** You have Darkvision with a range of 60 feet.\n\n'
                  '**Gnomish Cunning.** You have Advantage on Intelligence, Wisdom, and Charisma saving throws.\n\n'
                  '**Gnomish Lineage.** You are part of a lineage that grants you supernatural abilities. Choose one of the following options; whichever one you choose, Intelligence, Wisdom, or Charisma is your spellcasting ability for the spells you cast with this trait (choose the ability when you select the lineage):\n\n'
                  '- **Forest Gnome.** You know the Minor Illusion cantrip. You also always have the Speak with Animals spell prepared. You can cast it without a spell slot a number of times equal to your Proficiency Bonus, and you regain all expended uses when you finish a Long Rest. You can also use any spell slots you have to cast the spell.\n'
                  '- **Rock Gnome.** You know the Mending and Prestidigitation cantrips. In addition, you can spend 10 minutes casting Prestidigitation to create a Tiny clockwork device (AC 5, 1 HP), such as a toy, fire starter, or music box. When you create the device, you determine its function by choosing one effect from Prestidigitation; the device produces that effect whenever you or another creature takes a Bonus Action to activate it with a touch. If the chosen effect has options within it, you choose one of those options for the device when you create it. You can have three such devices in existence at a time, and each falls apart 8 hours after its creation or when you dismantle it with a touch as a Utilize action.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Goliath',
        description:
            'Giant-blooded Medium folk with a chosen Cloud / Fire / Frost / Hill / Stone / Storm Giant ancestry boon, plus optional Large Form starting at level 5.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 35,
          'traits':
              '**Giant Ancestry.** You are descended from Giants. Choose one of the following benefits—a supernatural boon from your ancestry; you can use the chosen benefit a number of times equal to your Proficiency Bonus, and you regain all expended uses when you finish a Long Rest:\n\n'
                  '- **Cloud\'s Jaunt (Cloud Giant).** As a Bonus Action, you magically teleport up to 30 feet to an unoccupied space you can see.\n'
                  '- **Fire\'s Burn (Fire Giant).** When you hit a target with an attack roll and deal damage to it, you can also deal 1d10 Fire damage to that target.\n'
                  '- **Frost\'s Chill (Frost Giant).** When you hit a target with an attack roll and deal damage to it, you can also deal 1d6 Cold damage to that target and reduce its Speed by 10 feet until the start of your next turn.\n'
                  '- **Hill\'s Tumble (Hill Giant).** When you hit a Large or smaller creature with an attack roll and deal damage to it, you can give that target the Prone condition.\n'
                  '- **Stone\'s Endurance (Stone Giant).** When you take damage, you can take a Reaction to roll 1d12. Add your Constitution modifier to the number rolled and reduce the damage by that total.\n'
                  '- **Storm\'s Thunder (Storm Giant).** When you take damage from a creature within 60 feet of you, you can take a Reaction to deal 1d8 Thunder damage to that creature.\n\n'
                  '**Large Form.** Starting at character level 5, you can change your size to Large as a Bonus Action if you\'re in a big enough space. This transformation lasts for 10 minutes or until you end it (no action required). For that duration, you have Advantage on Strength checks, and your Speed increases by 10 feet. Once you use this trait, you can\'t use it again until you finish a Long Rest.\n\n'
                  '**Powerful Build.** You have Advantage on any ability check you make to end the Grappled condition. You also count as one size larger when determining your carrying capacity.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Halfling',
        description:
            'Small, lucky folk who can hide behind larger creatures and reroll natural 1s.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Small',
          'speed_ft': 30,
          'traits':
              '**Brave.** You have Advantage on saving throws you make to avoid or end the Frightened condition.\n\n'
                  '**Halfling Nimbleness.** You can move through the space of any creature that is a size larger than you, but you can\'t stop in the same space.\n\n'
                  '**Luck.** When you roll a 1 on the d20 of a D20 Test, you can reroll the die, and you must use the new roll.\n\n'
                  '**Naturally Stealthy.** You can take the Hide action even when you are obscured only by a creature that is at least one size larger than you.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Human',
        description:
            'Adaptable folk with bonus Heroic Inspiration on Long Rests, a free skill, and an Origin feat.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 30,
          'traits':
              '**Resourceful.** You gain Heroic Inspiration whenever you finish a Long Rest.\n\n'
                  '**Skillful.** You gain proficiency in one skill of your choice.\n\n'
                  '**Versatile.** You gain an Origin feat of your choice (see "Feats"). Skilled is recommended.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Orc',
        description:
            'Adrenaline-driven warriors with bonus-action Dash, temporary HP, and Relentless Endurance.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'traits':
              '**Adrenaline Rush.** You can take the Dash action as a Bonus Action. When you do so, you gain a number of Temporary Hit Points equal to your Proficiency Bonus.\n\n'
                  'You can use this trait a number of times equal to your Proficiency Bonus, and you regain all expended uses when you finish a Short or Long Rest.\n\n'
                  '**Darkvision.** You have Darkvision with a range of 120 feet.\n\n'
                  '**Relentless Endurance.** When you are reduced to 0 Hit Points but not killed outright, you can drop to 1 Hit Point instead. Once you use this trait, you can\'t do so again until you finish a Long Rest.',
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Tiefling',
        description:
            'Fiend-blooded folk with a chosen Abyssal / Chthonic / Infernal legacy granting damage resistance and innate spells.',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': 'Medium',
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'traits':
              '**Darkvision.** You have Darkvision with a range of 60 feet.\n\n'
                  '**Fiendish Legacy.** You are the recipient of a legacy that grants you supernatural abilities. Choose a legacy from the Fiendish Legacies table. You gain the level 1 benefit of the chosen legacy.\n\n'
                  'When you reach character levels 3 and 5, you learn a higher-level spell, as shown on the table. You always have that spell prepared. You can cast it once without a spell slot, and you regain the ability to cast it in that way when you finish a Long Rest. You can also cast the spell using any spell slots you have of the appropriate level.\n\n'
                  'Intelligence, Wisdom, or Charisma is your spellcasting ability for the spells you cast with this trait (choose the ability when you select the legacy).\n\n'
                  '**Otherworldly Presence.** You know the Thaumaturgy cantrip. When you cast it with this trait, the spell uses the same spellcasting ability you use for your Fiendish Legacy trait.\n\n'
                  '**Fiendish Legacies**\n\n'
                  '| Legacy | Level 1 | Level 3 | Level 5 |\n|---|---|---|---|\n'
                  '| Abyssal | You have Resistance to Poison damage. You also know the Poison Spray cantrip. | Ray of Sickness | Hold Person |\n'
                  '| Chthonic | You have Resistance to Necrotic damage. You also know the Chill Touch cantrip. | False Life | Ray of Enfeeblement |\n'
                  '| Infernal | You have Resistance to Fire damage. You also know the Fire Bolt cantrip. | Hellish Rebuke | Darkness |',
        },
      ),
    ];
