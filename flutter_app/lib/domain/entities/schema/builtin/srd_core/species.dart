// SRD 5.2.1 Species (pp. 83–86): Dragonborn, Dwarf, Elf, Gnome, Goliath,
// Halfling, Human, Orc, Tiefling. All Humanoid. Speed 30 ft. except Goliath
// (35 ft.). Lineages / ancestries (Drow, High Elf, Hill Dwarf, the Dragonborn
// colors, …) ship as first-class `subspecies` entities in subspecies.dart,
// each pointing back here via `parent_species_ref`.
//
// Each row also carries a complete, player-facing Markdown `description`
// (master-roadmap §4.1 species form: intro -> `### Traits` -> `### Actions`
// (when the species grants any) -> `### Choices`). The trait/action prose is
// inlined verbatim from the sibling `traits.dart` / `creature_actions.dart`
// rows the `trait_refs` / `granted_*_action_refs` point at, so a player can
// understand a species from the card text alone (master-roadmap §4
// description-first). The enrichment is provably ADDITIVE: only the
// `description` value changed — every attribute (`creature_type_ref`,
// `size_ref`, `speed_ft`, `granted_senses`, `granted_damage_resistances`,
// `trait_refs`, `granted_action_refs`, `granted_bonus_action_refs`,
// `granted_reaction_refs`) is byte-identical to the pre-enrichment row, so no
// mechanical field is touched and no template rule is authored (RULE RESET
// intact; Wave 3 description slice).

import '_helpers.dart';

List<Map<String, dynamic>> srdSpecies() => [
      packEntity(
        slug: 'species',
        name: 'Dragonborn',
        description: r'''
Descendants of dragons, dragonborn bear scaled hides, a draconic breath weapon, and damage resistance keyed to a chosen dragon ancestry.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Draconic Ancestry.** Choose a kind of dragon ancestry (Black, Blue, Brass, Bronze, Copper, Gold, Green, Red, Silver, or White). Your Breath Weapon and Damage Resistance are determined by that ancestry.
- **Damage Resistance.** You have Resistance to the damage type associated with your Draconic Ancestry.

### Actions
- **Breath Weapon (Action, recharges on a Short or Long Rest).** Exhale destructive energy as instinctive magic. Choose a 15-foot Cone or a 30-foot Line (5 ft. wide). Each creature in the area makes a Dexterity save (DC = 8 + Con mod + PB). On a failure they take damage that scales with your character level (see the SRD table); on a success, half damage. The damage type matches your ancestry (Acid, Cold, Fire, Lightning, or Poison).
- **Draconic Flight (Bonus Action, once per Long Rest).** Starting at character level 5, sprout spectral wings that last 10 minutes or until you retract them (no action required). While they last you have a Fly Speed equal to your Speed.

### Choices
- **Draconic Ancestry.** Pick one dragon type at character creation. It permanently sets the damage type of both your Breath Weapon and your Damage Resistance.
''',
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
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Dwarf',
        description: r'''
Stout, hardy folk who shrug off poison, read the bones of the earth through stone, and carry more grit than their frame suggests.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Poison Resistance.** You have Resistance to Poison damage.
- **Dwarven Resilience.** Advantage on saving throws against the Poisoned condition, and Resistance to Poison damage.
- **Dwarven Toughness.** Your HP maximum increases by 1, and it increases by 1 again whenever you gain a level.
- **Stonecunning.** As a Bonus Action you gain Tremorsense with a range of 60 feet for 10 minutes. You must be on a stone surface or touching one. Uses = Proficiency Bonus per Long Rest.
- **Forge Wise.** You have proficiency with two of the following Artisan's Tools of your choice: Jeweler's Tools, Mason's Tools, Smith's Tools, or Tinker's Tools.

### Choices
- **Forge Wise.** Pick two Artisan's Tools from the Forge Wise list to gain proficiency with.
''',
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
        description: r'''
Fey-touched folk with keen senses and a meditative Trance instead of sleep, shaped by a Drow, High Elf, or Wood Elf lineage.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Fey Ancestry.** You have Advantage on saving throws against being Charmed, and magic can't put you to sleep.
- **Trance.** You don't need to sleep, and magic can't put you to sleep. You can finish a Long Rest in 4 hours of meditation. After a Trance you gain proficiency with one weapon or tool of your choice for the next 24 hours.
- **Keen Senses.** You have proficiency in the Insight, Perception, or Survival skill (your choice).
- **Elven Lineage.** You are part of an Elven lineage (Drow, High Elf, or Wood Elf), granting additional traits and innate spells.

### Choices
- **Elven Lineage.** Choose Drow, High Elf, or Wood Elf (added as a subspecies). Each grants its own traits and innate spells.
- **Keen Senses.** Pick Insight, Perception, or Survival to gain proficiency in.
- **Trance.** After each Trance, choose one weapon or tool to be proficient with for the next 24 hours.
''',
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
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Gnome',
        description: r'''
Small, inventive folk with a stubborn mind for magic, sorted into a Forest or Rock lineage of innate tricks.

### Traits
- **Size & Speed.** Small Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Gnomish Cunning.** You have Advantage on Intelligence, Wisdom, and Charisma saving throws.

### Choices
- **Gnomish Lineage.** Choose a Forest Gnome or Rock Gnome lineage (added as a subspecies), which grants its own innate magic and traits.
''',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Small'),
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'trait_refs': [
            ref('trait', 'Gnomish Cunning'),
          ],
        },
      ),
      packEntity(
        slug: 'species',
        name: 'Goliath',
        description: r'''
Giant-blooded folk who stand a head taller than most, carrying an ancestral boon from one of six giant kinds and a brief Large Form at higher levels.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 35 ft. (faster than most species).
- **Powerful Build.** You count as one size larger when determining your carrying capacity and the weight you can push, drag, or lift. You have Advantage on any ability check you make to end the Grappled condition.
- **Large Form.** Starting at character level 5, you can change your size to Large as a Bonus Action if you are in a big enough space. For 10 minutes you have Advantage on Strength checks, and your Speed increases by 10 feet. Uses = Proficiency Bonus per Long Rest.
- **Giant Ancestry.** You are descended from giants. Choose one ancestry boon (Cloud, Fire, Frost, Hill, Stone, or Storm), which grants you an additional special action or resistance.

### Choices
- **Giant Ancestry.** Pick one boon at character creation — Cloud's Jaunt (teleport), Fire's Burn (extra Fire damage), Frost's Chill (extra Cold damage + slow), Hill's Tumble (knock Prone), Stone's Endurance (reduce damage), or Storm's Thunder (retaliatory Thunder damage). Most boons can be used a number of times equal to your Proficiency Bonus per Long Rest.
''',
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
        name: 'Halfling',
        description: r'''
Small, cheerful, and improbably lucky folk who slip out of trouble by hiding behind bigger allies and rerolling their worst dice.

### Traits
- **Size & Speed.** Small Humanoid, Speed 30 ft.
- **Halfling Lucky.** When you roll a 1 on the d20 of a d20 Test, you can reroll the die and must use the new roll.
- **Naturally Stealthy.** You can take the Hide action when you have only a creature that is at least one size larger than you as cover.
- **Brave.** You have Advantage on saving throws against being Frightened.
- **Halfling Nimbleness.** You can move through the space of any creature that is a size larger than you, though that space is Difficult Terrain for you.
''',
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
        description: r'''
The most adaptable folk of all — quick to learn new skills, pick up an Origin feat, and draw a second wind of inspiration after every rest.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Resourceful.** You gain Heroic Inspiration whenever you finish a Long Rest.
- **Skilled.** You gain proficiency in three skills of your choice.
- **Versatile.** You gain an Origin feat of your choice (see the Feats chapter).

### Choices
- **Skilled.** Choose any three skills to gain proficiency in.
- **Versatile.** Choose one Origin feat at character creation.
''',
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
        description: r'''
Adrenaline-driven warriors built to close distance fast, soak punishment, and refuse to fall.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Powerful Build.** You count as one size larger when determining your carrying capacity and the weight you can push, drag, or lift. You have Advantage on any ability check you make to end the Grappled condition.

### Actions
- **Adrenaline Rush (Bonus Action).** Take the Dash action and gain Temporary HP equal to your Proficiency Bonus. Uses = Proficiency Bonus per Short or Long Rest.
- **Relentless Endurance (Reaction, once per Long Rest).** When you are reduced to 0 HP but not killed outright, you can drop to 1 HP instead.
''',
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
        description: r'''
Fiend-blooded folk marked by a chosen Abyssal, Chthonic, or Infernal legacy that grants damage resistance and innate spells.

### Traits
- **Size & Speed.** Medium Humanoid, Speed 30 ft.
- **Darkvision.** You can see in Dim Light within 60 feet as if it were Bright Light, and in Darkness as if it were Dim Light (in shades of gray).
- **Otherworldly Presence.** You know the Thaumaturgy cantrip. When you cast it with this trait, the spell uses Charisma as the spellcasting ability.
- **Fiendish Legacy.** You have a Fiendish Legacy (Abyssal, Chthonic, or Infernal), granting you damage resistance and innate spells keyed to that legacy.

### Choices
- **Fiendish Legacy.** Choose Abyssal, Chthonic, or Infernal at character creation. Your legacy sets your damage resistance type and the innate spells you learn as you gain levels.
''',
        attributes: {
          'creature_type_ref': lookup('creature-type', 'Humanoid'),
          'size_ref': lookup('size', 'Medium'),
          'speed_ft': 30,
          'granted_senses': [lookup('sense', 'Darkvision')],
          'trait_refs': [
            ref('trait', 'Otherworldly Presence'),
            ref('trait', 'Fiendish Legacy'),
          ],
        },
      ),
    ];
