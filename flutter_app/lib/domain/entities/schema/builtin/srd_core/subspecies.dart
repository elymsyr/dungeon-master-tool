// SRD 5.2.1 / 5.1-legacy Subspecies (lineages / ancestries) as first-class
// `subspecies` entities — the analogue of subclass→class. Each carries a
// `parent_species_ref` (hard same-pack ref) and the same grant fields a species
// uses, so CharacterResolver folds them identically.
//
// `legacy_subspecies_key` preserves the original `subspecies_options` row name
// so characters saved before the field→entity migration (which stored the
// option name in `subspecies_id`) still resolve to the right entity.
//
// Each row also carries a complete, player-facing Markdown `description`
// (master-roadmap §4.1 species/subspecies form: intro -> `### Traits` ->
// `### Choices`). The intro names the parent species as a human-readable
// back-link (the machine link is `parent_species_ref`), and the Traits prose
// is inlined verbatim from the sibling `creature_actions.dart` rows the
// `granted_*_action_refs` point at (the Goliath giant ancestries) plus the
// spell/sense/resistance grants the row already carries, so a player can
// understand a lineage from the card text alone (master-roadmap §4
// description-first). The enrichment is provably ADDITIVE: only each
// `description` value changed — every attribute (`parent_species_ref`,
// `legacy_subspecies_key`, `granted_modifiers`, `granted_damage_resistances`,
// `granted_skill_proficiencies`, `granted_cantrip_refs`,
// `granted_spells_at_level`, `granted_action_refs`, `granted_bonus_action_refs`,
// `granted_reaction_refs`) is byte-identical to the pre-enrichment row, so no
// mechanical field is touched and no template rule is authored (RULE RESET
// intact; Wave 3 description slice).

import '_helpers.dart';

/// Build one subspecies entity scoped to [parent], merging [grants] (the same
/// `granted_*` / `trait_refs` / modifier shape used by species) into attributes.
Map<String, dynamic> _sub({
  required String parent,
  required String name,
  String? legacyKey,
  required String description,
  Map<String, dynamic> grants = const {},
}) {
  return packEntity(
    slug: 'subspecies',
    name: name,
    description: description,
    tags: [parent],
    attributes: {
      'parent_species_ref': ref('species', parent),
      'legacy_subspecies_key': legacyKey ?? name,
      ...grants,
    },
  );
}

List<Map<String, dynamic>> srdSubspecies() => [
      // --- Dragonborn ancestries (damage resistance keyed to color) ---
      for (final c in const [
        ('Black', 'Acid'),
        ('Blue', 'Lightning'),
        ('Brass', 'Fire'),
        ('Bronze', 'Lightning'),
        ('Copper', 'Acid'),
        ('Gold', 'Fire'),
        ('Green', 'Poison'),
        ('Red', 'Fire'),
        ('Silver', 'Cold'),
        ('White', 'Cold'),
      ])
        _sub(
          parent: 'Dragonborn',
          name: '${c.$1} Dragonborn',
          legacyKey: c.$1,
          description: '''
Part of the **Dragonborn** species. A ${c.$1} Dragonborn draws its heritage from ${c.$1} dragons, which sets the damage type of both your Breath Weapon and your Damage Resistance to ${c.$2}.

### Traits
- **Draconic Ancestry (${c.$1}).** Your draconic heritage is tied to ${c.$1} dragons.
- **Breath Weapon.** When you use your Dragonborn Breath Weapon, it deals ${c.$2} damage.
- **Damage Resistance.** You have Resistance to ${c.$2} damage.

### Choices
- This ancestry is chosen once at character creation and cannot be changed. It permanently sets your Breath Weapon and Damage Resistance to ${c.$2}.
''',
          grants: {
            'granted_damage_resistances': [lookup('damage-type', c.$2)],
          },
        ),

      // --- Dwarf (SRD 5.1 legacy ancestries) ---
      _sub(
        parent: 'Dwarf',
        name: 'Hill Dwarf',
        description: r'''
Part of the **Dwarf** species. Hill Dwarves carry the keen Insight of highland folk and a legendary toughness that thickens their hardiness with every level. *(SRD 5.1 legacy ancestry.)*

### Traits
- **Dwarven Toughness.** Your HP maximum increases by 1, and it increases by 1 again whenever you gain a level.
- **Skill Proficiency.** You gain proficiency in the Insight skill.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_modifiers': [
            {'kind': 'hp_bonus_per_level', 'value': 1},
          ],
          'granted_skill_proficiencies': [lookup('skill', 'Insight')],
        },
      ),
      _sub(
        parent: 'Dwarf',
        name: 'Mountain Dwarf',
        description: r'''
Part of the **Dwarf** species. Mountain Dwarves are raised among harsh peaks, and that hard upbringing leaves them tougher than most. *(SRD 5.1 legacy ancestry.)*

### Traits
- **Mountain Hardiness.** Your HP maximum increases by 2.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_modifiers': [
            {'kind': 'hp_bonus_flat', 'value': 2},
          ],
        },
      ),

      // --- Elf lineages ---
      _sub(
        parent: 'Elf',
        name: 'Drow',
        description: r'''
Part of the **Elf** species. Drow are elves of the Underdark, gifted with sight that pierces the deepest gloom and innate shadow magic.

### Traits
- **Superior Darkvision.** Your Darkvision has a range of 120 feet, replacing the base Elf Darkvision of 60 feet.
- **Drow Magic.** You know the *Dancing Lights* cantrip. At character level 3 you can cast *Faerie Fire* once per Long Rest, and at level 5 you can cast *Darkness* once per Long Rest. You can also cast these spells using any spell slots you have, and Charisma is your spellcasting ability for them.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_modifiers': [
            {
              'kind': 'sense_grant',
              'target_kind': 'sense',
              'target_ref': lookup('sense', 'Darkvision'),
              'payload': {'range_ft': 120},
            },
          ],
          'granted_cantrip_refs': [ref('spell', 'Dancing Lights')],
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'Faerie Fire'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Darkness'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),
      _sub(
        parent: 'Elf',
        name: 'High Elf',
        description: r'''
Part of the **Elf** species. High Elves are scholars of arcane tradition, weaving wizardly magic into their elven heritage.

### Traits
- **Cantrip.** You know one cantrip of your choice from the Wizard spell list. Intelligence is your spellcasting ability for it.
- **High Elf Magic.** At character level 3 you can cast *Detect Magic* once per Long Rest, and at level 5 you can cast *Misty Step* once per Long Rest. You can also cast these spells using any spell slots you have.

### Choices
- **Wizard Cantrip.** Choose one cantrip from the Wizard spell list to learn.
''',
        grants: {
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'Detect Magic'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Misty Step'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),
      _sub(
        parent: 'Elf',
        name: 'Wood Elf',
        description: r'''
Part of the **Elf** species. Wood Elves are swift, wary folk of the deep forest, moving faster and more quietly than other elves.

### Traits
- **Fleet of Foot.** Your Speed increases by 5 feet (to 35 feet).
- **Wood Elf Magic.** You know the *Druidcraft* cantrip. At character level 3 you can cast *Longstrider* once per Long Rest, and at level 5 you can cast *Pass without Trace* once per Long Rest. You can also cast these spells using any spell slots you have, and Wisdom is your spellcasting ability for them.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_modifiers': [
            {'kind': 'speed_bonus', 'value': 5},
          ],
          'granted_cantrip_refs': [ref('spell', 'Druidcraft')],
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'Longstrider'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Pass without Trace'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),

      // --- Gnome lineages ---
      _sub(
        parent: 'Gnome',
        name: 'Forest Gnome',
        description: r'''
Part of the **Gnome** species. Forest Gnomes have a natural knack for illusion and an instinctive bond with small woodland creatures.

### Traits
- **Natural Illusionist.** You know the *Minor Illusion* cantrip. Intelligence is your spellcasting ability for it.
- **Speak with Small Beasts.** Through sounds and gestures, you can communicate simple ideas with Small or smaller Beasts.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_cantrip_refs': [ref('spell', 'Minor Illusion')],
        },
      ),
      _sub(
        parent: 'Gnome',
        name: 'Rock Gnome',
        description: r'''
Part of the **Gnome** species. Rock Gnomes are born tinkerers, channeling gnomish cunning into clockwork gadgets and a deep knowledge of how magic items are made.

### Traits
- **Artificer's Lore.** Whenever you make an Intelligence (History) check related to magic items, alchemical objects, or technological devices, you add twice your Proficiency Bonus.
- **Tinker.** You know the *Mending* and *Prestidigitation* cantrips, and you can use them to build tiny clockwork devices such as toys, fire starters, or music boxes. Intelligence is your spellcasting ability for them.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_cantrip_refs': [
            ref('spell', 'Mending'),
            ref('spell', 'Prestidigitation'),
          ],
        },
      ),

      // --- Goliath giant ancestries ---
      _sub(
        parent: 'Goliath',
        name: 'Cloud Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with cloud giant ancestry can briefly step through space, vanishing and reappearing nearby.

### Traits
- **Cloud's Jaunt (Bonus Action).** As a Bonus Action, you magically teleport up to 30 feet to an unoccupied space you can see. You can use this a number of times equal to your Proficiency Bonus, regaining all uses on a Long Rest.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_bonus_action_refs': [ref('creature-action', "Cloud's Jaunt")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Fire Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with fire giant ancestry channel an inner flame into their blows.

### Traits
- **Fire's Burn.** When you hit a target with an attack roll and deal damage to it, you can also deal 1d10 Fire damage to that target.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_action_refs': [ref('creature-action', "Fire's Burn")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Frost Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with frost giant ancestry leave a numbing cold in the wake of their strikes.

### Traits
- **Frost's Chill.** When you hit a target with an attack roll and deal damage to it, you can also deal 1d6 Cold damage to that target and reduce its Speed by 10 feet until the start of your next turn.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_action_refs': [ref('creature-action', "Frost's Chill")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Hill Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with hill giant ancestry can topple foes with the sheer weight of their blows.

### Traits
- **Hill's Tumble (Reaction).** When you hit a Large or smaller creature with a melee attack, you can knock the target Prone. You can use this a number of times equal to your Proficiency Bonus, regaining all uses on a Long Rest.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Hill's Tumble")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Stone Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with stone giant ancestry shrug off blows with the resilience of living rock.

### Traits
- **Stone's Endurance (Reaction).** When you take damage, you can roll 1d12 and add your Constitution modifier, reducing the damage by that total. You can use this a number of times equal to your Proficiency Bonus, regaining all uses on a Long Rest.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Stone's Endurance")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Storm Giant',
        description: r'''
Part of the **Goliath** species. Goliaths with storm giant ancestry answer harm with a crack of thunder.

### Traits
- **Storm's Thunder (Reaction).** When you take damage from a creature within 60 feet of you, you can deal 1d8 Thunder damage to that creature. You can use this a number of times equal to your Proficiency Bonus, regaining all uses on a Long Rest.

### Choices
- This ancestry grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Storm's Thunder")],
        },
      ),

      // --- Halfling (SRD 5.1 legacy ancestries) ---
      _sub(
        parent: 'Halfling',
        name: 'Lightfoot Halfling',
        description: r'''
Part of the **Halfling** species. Lightfoot Halflings are quiet and unassuming, able to slip out of sight with ease. *(SRD 5.1 legacy ancestry.)*

### Traits
- **Skill Proficiency.** You gain proficiency in the Stealth skill.

### Choices
- This lineage grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_skill_proficiencies': [lookup('skill', 'Stealth')],
        },
      ),
      _sub(
        parent: 'Halfling',
        name: 'Stout Halfling',
        description: r'''
Part of the **Halfling** species. Stout Halflings claim dwarven blood, lending them a hardy constitution against poison. *(SRD 5.1 legacy ancestry.)*

### Traits
- **Poison Resilience.** You have Resistance to Poison damage.

### Choices
- This lineage grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
        },
      ),

      // --- Human (SRD 5.1 legacy ancestry) ---
      _sub(
        parent: 'Human',
        name: 'Standard Human',
        description: r'''
Part of the **Human** species. The Standard Human gains a measure of every talent, with a small bonus to all of their abilities. *(SRD 5.1 legacy ancestry; replaces the modern Versatile / Skilled package thematically.)*

### Traits
- **Ability Score Increase.** Each of your six ability scores — Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma — increases by 1.

### Choices
- This lineage grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_modifiers': [
            {'kind': 'ability_score_bonus', 'ability': 'STR', 'value': 1},
            {'kind': 'ability_score_bonus', 'ability': 'DEX', 'value': 1},
            {'kind': 'ability_score_bonus', 'ability': 'CON', 'value': 1},
            {'kind': 'ability_score_bonus', 'ability': 'INT', 'value': 1},
            {'kind': 'ability_score_bonus', 'ability': 'WIS', 'value': 1},
            {'kind': 'ability_score_bonus', 'ability': 'CHA', 'value': 1},
          ],
        },
      ),

      // --- Orc (SRD 5.1 legacy ancestry) ---
      _sub(
        parent: 'Orc',
        name: 'Half-Orc',
        description: r'''
Part of the **Orc** species. Half-Orcs blend human and orc heritage, carrying a forceful, intimidating presence. *(SRD 5.1 legacy ancestry.)*

### Traits
- **Skill Proficiency.** You gain proficiency in the Intimidation skill.

### Choices
- This lineage grants its benefit automatically — there are no further choices to make.
''',
        grants: {
          'granted_skill_proficiencies': [lookup('skill', 'Intimidation')],
        },
      ),

      // --- Tiefling fiendish legacies ---
      _sub(
        parent: 'Tiefling',
        name: 'Abyssal Tiefling',
        legacyKey: 'Abyssal',
        description: r'''
Part of the **Tiefling** species. Tieflings of the Abyssal legacy carry the corrupting taint of the Abyss, resisting poison and wielding sickening magic.

### Traits
- **Poison Resilience.** You have Resistance to Poison damage.
- **Abyssal Magic.** You know the *Poison Spray* cantrip. At character level 3 you can cast *Ray of Sickness* once per Long Rest, and at level 5 you can cast *Hold Person* once per Long Rest. You can also cast these spells using any spell slots you have, and Charisma is your spellcasting ability for them.

### Choices
- This legacy grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
          'granted_cantrip_refs': [ref('spell', 'Poison Spray')],
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'Ray of Sickness'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Hold Person'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),
      _sub(
        parent: 'Tiefling',
        name: 'Chthonic Tiefling',
        legacyKey: 'Chthonic',
        description: r'''
Part of the **Tiefling** species. Tieflings of the Chthonic legacy are touched by the gray wastes of death, resisting necrotic energy and drawing on life-draining magic.

### Traits
- **Necrotic Resilience.** You have Resistance to Necrotic damage.
- **Chthonic Magic.** You know the *Chill Touch* cantrip. At character level 3 you can cast *False Life* once per Long Rest, and at level 5 you can cast *Ray of Enfeeblement* once per Long Rest. You can also cast these spells using any spell slots you have, and Charisma is your spellcasting ability for them.

### Choices
- This legacy grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_damage_resistances': [lookup('damage-type', 'Necrotic')],
          'granted_cantrip_refs': [ref('spell', 'Chill Touch')],
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'False Life'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Ray of Enfeeblement'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),
      _sub(
        parent: 'Tiefling',
        name: 'Infernal Tiefling',
        legacyKey: 'Infernal',
        description: r'''
Part of the **Tiefling** species. Tieflings of the Infernal legacy descend from the Nine Hells, resisting fire and wielding searing flame.

### Traits
- **Fire Resilience.** You have Resistance to Fire damage.
- **Infernal Magic.** You know the *Fire Bolt* cantrip. At character level 3 you can cast *Hellish Rebuke* once per Long Rest, and at level 5 you can cast *Darkness* once per Long Rest. You can also cast these spells using any spell slots you have, and Charisma is your spellcasting ability for them.

### Choices
- This legacy grants its benefits automatically — there are no further choices to make.
''',
        grants: {
          'granted_damage_resistances': [lookup('damage-type', 'Fire')],
          'granted_cantrip_refs': [ref('spell', 'Fire Bolt')],
          'granted_spells_at_level': [
            {'spell_ref': ref('spell', 'Hellish Rebuke'), 'at_level': 3, 'uses_per_long_rest': 1},
            {'spell_ref': ref('spell', 'Darkness'), 'at_level': 5, 'uses_per_long_rest': 1},
          ],
        },
      ),
    ];
