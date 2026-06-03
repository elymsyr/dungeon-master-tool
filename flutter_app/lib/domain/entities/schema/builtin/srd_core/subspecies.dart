// SRD 5.2.1 / 5.1-legacy Subspecies (lineages / ancestries) as first-class
// `subspecies` entities — the analogue of subclass→class. Each carries a
// `parent_species_ref` (hard same-pack ref) and the same grant fields a species
// uses, so CharacterResolver folds them identically.
//
// `legacy_subspecies_key` preserves the original `subspecies_options` row name
// so characters saved before the field→entity migration (which stored the
// option name in `subspecies_id`) still resolve to the right entity.

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
          description:
              '${c.$2} breath weapon and ${c.$2} resistance.',
          grants: {
            'granted_damage_resistances': [lookup('damage-type', c.$2)],
          },
        ),

      // --- Dwarf (SRD 5.1 legacy ancestries) ---
      _sub(
        parent: 'Dwarf',
        name: 'Hill Dwarf',
        description:
            'Hill Dwarf — keen Insight from highland wisdom plus Dwarven Toughness (+1 HP per level). (SRD 5.1 legacy ancestry)',
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
        description:
            'Mountain Dwarf — extra hardiness from harsh peaks. (SRD 5.1 legacy ancestry: +2 max HP)',
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
        description:
            'Superior Darkvision (120 ft. — replaces base Darkvision). Innate spells: Dancing Lights (L1), Faerie Fire (L3, 1/day), Darkness (L5, 1/day).',
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
        description:
            'Innate spells: a Wizard cantrip (L1), Detect Magic (L3, 1/day), Misty Step (L5, 1/day).',
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
        description:
            'Speed 35 ft (+5 ft from base). Innate spells: Druidcraft (L1), Longstrider (L3, 1/day), Pass without Trace (L5, 1/day).',
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
        description:
            'Minor Illusion cantrip. Speak with Small Beasts (telepathic).',
        grants: {
          'granted_cantrip_refs': [ref('spell', 'Minor Illusion')],
        },
      ),
      _sub(
        parent: 'Gnome',
        name: 'Rock Gnome',
        description:
            "Artificer's Lore (double prof on magic-item History). Tinker (Mending + Prestidigitation, build clockwork toys).",
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
        description:
            "Cloud's Jaunt — Bonus Action teleport 30 ft to an unoccupied space you can see; uses = PB per Long Rest.",
        grants: {
          'granted_bonus_action_refs': [ref('creature-action', "Cloud's Jaunt")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Fire Giant',
        description:
            "Fire's Burn — when you hit a target and deal damage, also deal 1d10 Fire damage.",
        grants: {
          'granted_action_refs': [ref('creature-action', "Fire's Burn")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Frost Giant',
        description:
            "Frost's Chill — when you hit a target and deal damage, also deal 1d6 Cold damage and reduce its Speed by 10 ft.",
        grants: {
          'granted_action_refs': [ref('creature-action', "Frost's Chill")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Hill Giant',
        description:
            "Hill's Tumble — when you hit with a melee attack you can knock Large or smaller creatures Prone; uses = PB per Long Rest.",
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Hill's Tumble")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Stone Giant',
        description:
            "Stone's Endurance — Reaction: roll d12 + Con mod, reduce damage taken by that amount; uses = PB per Long Rest.",
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Stone's Endurance")],
        },
      ),
      _sub(
        parent: 'Goliath',
        name: 'Storm Giant',
        description:
            "Storm's Thunder — when you take damage from a creature within 60 ft, Reaction to deal 1d8 Thunder damage.",
        grants: {
          'granted_reaction_refs': [ref('creature-action', "Storm's Thunder")],
        },
      ),

      // --- Halfling (SRD 5.1 legacy ancestries) ---
      _sub(
        parent: 'Halfling',
        name: 'Lightfoot Halfling',
        description:
            'Lightfoot — natural sneaks who slip past notice. (SRD 5.1 legacy ancestry: Stealth proficiency)',
        grants: {
          'granted_skill_proficiencies': [lookup('skill', 'Stealth')],
        },
      ),
      _sub(
        parent: 'Halfling',
        name: 'Stout Halfling',
        description:
            'Stout — dwarven kinship grants poison damage resistance. (SRD 5.1 legacy ancestry)',
        grants: {
          'granted_damage_resistances': [lookup('damage-type', 'Poison')],
        },
      ),

      // --- Human (SRD 5.1 legacy ancestry) ---
      _sub(
        parent: 'Human',
        name: 'Standard Human',
        description:
            'Standard Human — +1 to every ability score. (SRD 5.1 legacy ancestry; replaces the Versatile / Skilled package thematically.)',
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
        description:
            'Half-Orc — human-orc heritage, intimidating presence. (SRD 5.1 legacy ancestry: Intimidation proficiency)',
        grants: {
          'granted_skill_proficiencies': [lookup('skill', 'Intimidation')],
        },
      ),

      // --- Tiefling fiendish legacies ---
      _sub(
        parent: 'Tiefling',
        name: 'Abyssal Tiefling',
        legacyKey: 'Abyssal',
        description:
            'Poison resistance. Innate spells: Poison Spray (L1), Ray of Sickness (L3, 1/day), Hold Person (L5, 1/day).',
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
        description:
            'Necrotic resistance. Innate spells: Chill Touch (L1), False Life (L3, 1/day), Ray of Enfeeblement (L5, 1/day).',
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
        description:
            'Fire resistance. Innate spells: Fire Bolt (L1), Hellish Rebuke (L3, 1/day), Darkness (L5, 1/day).',
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
