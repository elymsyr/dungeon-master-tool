// SRD 5.2.1 Adventuring Gear (table p. 95 + descriptions pp. 94–99).
// Schema: cost_cp (integer), weight_lb, utilize_check_dc, utilize_ability_ref,
// utilize_description, consumable, is_focus, focus_kind_ref. Cost stored in
// copper to keep small denominations exact (1 GP = 100 CP, 1 SP = 10 CP).

import '_helpers.dart';

const _slug = 'adventuring-gear';

const _cpPerSp = 10;
const _cpPerGp = 100;

Map<String, dynamic> _g({
  required String name,
  required String description,
  required int costCp,
  required double weightLb,
  bool consumable = false,
  bool isFocus = false,
  String? focusKindSlug, // 'arcane-focus' | 'druidic-focus' | 'holy-symbol'
  String? focusKindName, // e.g. 'Crystal', 'Sprig of Mistletoe', 'Amulet'
  int? utilizeDc,
  String? utilizeAbility, // 'Strength' / 'Dexterity' / etc.
  String? utilizeDescription,
}) {
  final attrs = <String, dynamic>{
    'cost_cp': costCp,
    'weight_lb': weightLb,
    'consumable': consumable,
    'is_focus': isFocus,
  };
  if (focusKindSlug != null && focusKindName != null) {
    attrs['focus_kind_ref'] = lookup(focusKindSlug, focusKindName);
  }
  if (utilizeDc != null) attrs['utilize_check_dc'] = utilizeDc;
  if (utilizeAbility != null) {
    attrs['utilize_ability_ref'] = lookup('ability', utilizeAbility);
  }
  if (utilizeDescription != null) {
    attrs['utilize_description'] = utilizeDescription;
  }
  return packEntity(
      slug: _slug, name: name, description: description, attributes: attrs);
}

/// Hand-authored adventuring gear from SRD 5.2.1 pp. 94–99.
/// Note: trade goods, money, and arcane/druidic/holy focus *items* live
/// here; the focus *kinds* (Crystal, Orb, Wand, …) ship as Tier-0
/// `arcane-focus` / `druidic-focus` / `holy-symbol` rows. Each focus item
/// row points back at its kind via `focus_kind_ref`.
List<Map<String, dynamic>> srdAdventuringGear() => [
      _g(
          description: r'''
**Acid.**

**How to use it:**
- Throw a vial of Acid at a creature within 20 ft. as part of the Attack action.
- DC 8 + Dexterity modifier + proficiency bonus; on hit deals 2d6 Acid damage.

**Cost:** 25 gp  ·  **Weight:** 1 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Acid', costCp: 25 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw a vial of Acid at a creature within 20 ft. as part of the Attack action. DC 8 + DEX mod + PB; on hit deals 2d6 Acid damage.'),
      _g(
          description: r'''
**Alchemist's Fire.**

**How to use it:**
- Throw a flask of Alchemist's Fire at a creature within 20 ft. as part of the Attack action.
- DC 8 + Dexterity modifier + proficiency bonus; on hit deals 1d4 Fire damage and starts burning.

**Cost:** 50 gp  ·  **Weight:** 1 lb  ·  **Consumable** (used up when you use it)
''',
          name: "Alchemist's Fire", costCp: 50 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              "Throw a flask of Alchemist's Fire at a creature within 20 ft. as part of the Attack action. DC 8 + DEX mod + PB; on hit deals 1d4 Fire damage and starts burning."),
      _g(
          description: r'''
**Antitoxin.**

**How to use it:**
- As a Bonus Action drink the vial to gain Advantage on saves to avoid or end the Poisoned condition for 1 hour.

**Cost:** 50 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Antitoxin', costCp: 50 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'As a Bonus Action drink the vial to gain Advantage on saves to avoid or end the Poisoned condition for 1 hour.'),
      _g(
          description: r'''
**Backpack.**

**How to use it:**
- Holds up to 30 lb within 1 cubic foot.
- Can also serve as a saddlebag.

**Cost:** 2 gp  ·  **Weight:** 5 lb
''',
          name: 'Backpack', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Holds up to 30 lb within 1 cubic foot. Can also serve as a saddlebag.'),
      _g(
          description: r'''
**Ball Bearings.**

**How to use it:**
- Spill bearings to cover a level, 10-ft-square area within 5 ft.
- DC 10 Dexterity save to avoid going Prone; takes 10 minutes to recover.

**Check to use:** when using this item calls for a roll, make a **DC 10 Dexterity** check.

**Cost:** 1 gp  ·  **Weight:** 2 lb
''',
          name: 'Ball Bearings', costCp: 1 * _cpPerGp, weightLb: 2,
          consumable: false,
          utilizeDc: 10, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Spill bearings to cover a level, 10-ft-square area within 5 ft. DC 10 DEX save to avoid going Prone; takes 10 minutes to recover.'),
      _g(
          description: r'''
**Barrel.**

**How to use it:**
- Holds up to 40 gallons of liquid or up to 4 cubic feet of dry goods.

**Cost:** 2 gp  ·  **Weight:** 70 lb
''',
          name: 'Barrel', costCp: 2 * _cpPerGp, weightLb: 70,
          utilizeDescription:
              'Holds up to 40 gallons of liquid or up to 4 cubic feet of dry goods.'),
      _g(
          description: r'''
**Basket.**

**How to use it:**
- Holds up to 40 lb within 2 cubic feet.

**Cost:** 4 sp  ·  **Weight:** 2 lb
''',
          name: 'Basket', costCp: 4 * _cpPerSp, weightLb: 2,
          utilizeDescription:
              'Holds up to 40 lb within 2 cubic feet.'),
      _g(
          description: r'''
**Bedroll.**

**How to use it:**
- Sleeps one Small or Medium creature.
- Auto-succeed on saves vs. extreme cold.

**Cost:** 1 gp  ·  **Weight:** 7 lb
''',
          name: 'Bedroll', costCp: 1 * _cpPerGp, weightLb: 7,
          utilizeDescription:
              'Sleeps one Small or Medium creature. Auto-succeed on saves vs. extreme cold.'),
      _g(
          description: r'''
**Bell.**

**How to use it:**
- Produces a sound that can be heard up to 60 ft away.

**Cost:** 1 gp  ·  **Weight:** —
''',
          name: 'Bell', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              'Produces a sound that can be heard up to 60 ft away.'),
      _g(
          description: r'''
**Blanket.**

**How to use it:**
- While wrapped in a blanket gain Advantage on saves vs. extreme cold.

**Cost:** 5 sp  ·  **Weight:** 3 lb
''',
          name: 'Blanket', costCp: 5 * _cpPerSp, weightLb: 3,
          utilizeDescription:
              'While wrapped in a blanket gain Advantage on saves vs. extreme cold.'),
      _g(
          description: r'''
**Block and Tackle.**

**How to use it:**
- Hoist up to four times the weight you can normally lift.

**Cost:** 1 gp  ·  **Weight:** 5 lb
''',
          name: 'Block and Tackle', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Hoist up to four times the weight you can normally lift.'),
      _g(
          description: r'''
**Book.**

**How to use it:**
- +5 bonus to Intelligence (Arcana, History, Nature, Religion) checks about its topic.

**Cost:** 25 gp  ·  **Weight:** 5 lb
''',
          name: 'Book', costCp: 25 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              '+5 bonus to Intelligence (Arcana, History, Nature, Religion) checks about its topic.'),
      _g(
          description: r'''
**Bottle, Glass.**

**How to use it:**
- Holds up to 1.5 pints.

**Cost:** 2 gp  ·  **Weight:** 2 lb
''',
          name: 'Bottle, Glass', costCp: 2 * _cpPerGp, weightLb: 2,
          utilizeDescription: 'Holds up to 1.5 pints.'),
      _g(
          description: r'''
**Bucket.**

**How to use it:**
- Holds up to half a cubic foot of contents.

**Cost:** 5 cp  ·  **Weight:** 2 lb
''',
          name: 'Bucket', costCp: 5 * _cpPerCp(), weightLb: 2,
          utilizeDescription: 'Holds up to half a cubic foot of contents.'),
      _g(
          description: r'''
**Caltrops.**

**How to use it:**
- Spread to cover a 5-ft-square area.
- DC 15 Dexterity save to avoid 1 Piercing damage and Speed reduced to 0 until start of next turn.

**Check to use:** when using this item calls for a roll, make a **DC 15 Dexterity** check.

**Cost:** 1 gp  ·  **Weight:** 2 lb
''',
          name: 'Caltrops', costCp: 1 * _cpPerGp, weightLb: 2,
          utilizeDc: 15, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Spread to cover a 5-ft-square area. DC 15 DEX save to avoid 1 Piercing damage and Speed reduced to 0 until start of next turn.'),
      _g(
          description: r'''
**Candle.**

**How to use it:**
- For 1 hour sheds Bright Light in a 5-ft radius and Dim Light for an additional 5 ft.

**Cost:** 1 cp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Candle', costCp: 1, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'For 1 hour sheds Bright Light in a 5-ft radius and Dim Light for an additional 5 ft.'),
      _g(
          description: r'''
**Case, Crossbow Bolt.**

**How to use it:**
- Holds up to 20 Bolts.

**Cost:** 1 gp  ·  **Weight:** 1 lb
''',
          name: 'Case, Crossbow Bolt', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Holds up to 20 Bolts.'),
      _g(
          description: r'''
**Case, Map or Scroll.**

**How to use it:**
- Holds up to 10 sheets of paper or 5 sheets of parchment.

**Cost:** 1 gp  ·  **Weight:** 1 lb
''',
          name: 'Case, Map or Scroll', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription:
              'Holds up to 10 sheets of paper or 5 sheets of parchment.'),
      _g(
          description: r'''
**Chain.**

**How to use it:**
- Wrap around an unwilling Grappled/Incapacitated/Restrained creature.
- DC 13 STR (Athletics) check to bind.

**Check to use:** when using this item calls for a roll, make a **DC 13 Strength** check.

**Cost:** 5 gp  ·  **Weight:** 10 lb
''',
          name: 'Chain', costCp: 5 * _cpPerGp, weightLb: 10,
          utilizeDc: 13, utilizeAbility: 'Strength',
          utilizeDescription:
              'Wrap around an unwilling Grappled/Incapacitated/Restrained creature. DC 13 STR (Athletics) check to bind.'),
      _g(
          description: r'''
**Chest.**

**How to use it:**
- Holds up to 12 cubic feet of contents.

**Cost:** 5 gp  ·  **Weight:** 25 lb
''',
          name: 'Chest', costCp: 5 * _cpPerGp, weightLb: 25,
          utilizeDescription: 'Holds up to 12 cubic feet of contents.'),
      _g(
          description: r'''
**Climber's Kit.**

**How to use it:**
- Anchor yourself; you can't fall more than 25 ft from the anchor and can't move more than 25 ft from there without undoing the anchor as a Bonus Action.

**Cost:** 25 gp  ·  **Weight:** 12 lb
''',
          name: "Climber's Kit", costCp: 25 * _cpPerGp, weightLb: 12,
          utilizeDescription:
              "Anchor yourself; you can't fall more than 25 ft from the anchor and can't move more than 25 ft from there without undoing the anchor as a Bonus Action."),
      _g(
          description: r'''
**Clothes, Fine.**

**How to use it:**
- Some events and locations admit only people wearing fine clothes.

**Cost:** 15 gp  ·  **Weight:** 6 lb
''',
          name: 'Clothes, Fine', costCp: 15 * _cpPerGp, weightLb: 6,
          utilizeDescription:
              'Some events and locations admit only people wearing fine clothes.'),
      _g(
          description: r'''
**Clothes, Traveler's.**

**How to use it:**
- Resilient garments designed for travel in various environments.

**Cost:** 2 gp  ·  **Weight:** 4 lb
''',
          name: "Clothes, Traveler's", costCp: 2 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Resilient garments designed for travel in various environments.'),
      _g(
          description: r'''
**Component Pouch.**

**How to use it:**
- Contains all the free Material components of your spells.

**Cost:** 25 gp  ·  **Weight:** 2 lb
''',
          name: 'Component Pouch', costCp: 25 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Contains all the free Material components of your spells.'),
      _g(
          description: r'''
**Costume.**

**How to use it:**
- Advantage on ability checks to impersonate the person or type of person it represents.

**Cost:** 5 gp  ·  **Weight:** 4 lb
''',
          name: 'Costume', costCp: 5 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Advantage on ability checks to impersonate the person or type of person it represents.'),
      _g(
          description: r'''
**Crowbar.**

**How to use it:**
- Advantage on Strength checks where the leverage can be applied.

**Cost:** 2 gp  ·  **Weight:** 5 lb
''',
          name: 'Crowbar', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Advantage on Strength checks where the leverage can be applied.'),
      _g(
          description: r'''
**Burglar's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 16 gp  ·  **Weight:** 42 lb
''',
          name: "Burglar's Pack", costCp: 16 * _cpPerGp, weightLb: 42),
      _g(
          description: r'''
**Diplomat's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 39 gp  ·  **Weight:** 39 lb
''',
          name: "Diplomat's Pack", costCp: 39 * _cpPerGp, weightLb: 39),
      _g(
          description: r'''
**Dungeoneer's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 12 gp  ·  **Weight:** 55 lb
''',
          name: "Dungeoneer's Pack", costCp: 12 * _cpPerGp, weightLb: 55),
      _g(
          description: r'''
**Entertainer's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 40 gp  ·  **Weight:** 58 lb
''',
          name: "Entertainer's Pack", costCp: 40 * _cpPerGp, weightLb: 58),
      _g(
          description: r'''
**Explorer's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 10 gp  ·  **Weight:** 55 lb
''',
          name: "Explorer's Pack", costCp: 10 * _cpPerGp, weightLb: 55),
      _g(
          description: r'''
**Flask.**

**How to use it:**
- Holds up to 1 pint.

**Cost:** 2 cp  ·  **Weight:** 1 lb
''',
          name: 'Flask', costCp: 2, weightLb: 1,
          utilizeDescription: 'Holds up to 1 pint.'),
      _g(
          description: r'''
**Grappling Hook.**

**How to use it:**
- Throw at a railing/ledge/catch within 50 ft.
- DC 13 DEX (Acrobatics) for the hook to catch.

**Check to use:** when using this item calls for a roll, make a **DC 13 Dexterity** check.

**Cost:** 2 gp  ·  **Weight:** 4 lb
''',
          name: 'Grappling Hook', costCp: 2 * _cpPerGp, weightLb: 4,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Throw at a railing/ledge/catch within 50 ft. DC 13 DEX (Acrobatics) for the hook to catch.'),
      _g(
          description: r'''
**Healer's Kit.**

**How to use it:**
- Ten uses.
- Stabilize an Unconscious creature with 0 HP without needing a Wisdom (Medicine) check.

**Cost:** 5 gp  ·  **Weight:** 3 lb  ·  **Consumable** (used up when you use it)
''',
          name: "Healer's Kit", costCp: 5 * _cpPerGp, weightLb: 3,
          consumable: true,
          utilizeDescription:
              'Ten uses. Stabilize an Unconscious creature with 0 HP without needing a Wisdom (Medicine) check.'),
      _g(
          description: r'''
**Holy Water.**

**How to use it:**
- Throw at a creature within 20 ft as part of the Attack action.
- DC 8 + DEX + proficiency bonus; on hit deals 2d8 Radiant damage if Fiend or Undead.

**Cost:** 25 gp  ·  **Weight:** 1 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Holy Water', costCp: 25 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw at a creature within 20 ft as part of the Attack action. DC 8 + DEX + PB; on hit deals 2d8 Radiant damage if Fiend or Undead.'),
      _g(
          description: r'''
**Hunting Trap.**

**How to use it:**
- Place sawtooth ring snap-trap.
- DC 13 Dexterity save to avoid 1d4 Piercing and Speed 0;
- STR (Athletics) DC 13 to escape.

**Check to use:** when using this item calls for a roll, make a **DC 13 Dexterity** check.

**Cost:** 5 gp  ·  **Weight:** 25 lb
''',
          name: 'Hunting Trap', costCp: 5 * _cpPerGp, weightLb: 25,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Place sawtooth ring snap-trap. DC 13 DEX save to avoid 1d4 Piercing and Speed 0; STR (Athletics) DC 13 to escape.'),
      _g(
          description: r'''
**Ink.**

**How to use it:**
- 1-ounce bottle; enough ink to write about 500 pages.

**Cost:** 10 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Ink', costCp: 10 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              '1-ounce bottle; enough ink to write about 500 pages.'),
      _g(
          description: r'''
**Ink Pen.**

**How to use it:**
- Used with Ink to write or draw.

**Cost:** 2 cp  ·  **Weight:** —
''',
          name: 'Ink Pen', costCp: 2, weightLb: 0,
          utilizeDescription: 'Used with Ink to write or draw.'),
      _g(
          description: r'''
**Jug.**

**How to use it:**
- Holds up to 1 gallon.

**Cost:** 2 cp  ·  **Weight:** 4 lb
''',
          name: 'Jug', costCp: 2, weightLb: 4,
          utilizeDescription: 'Holds up to 1 gallon.'),
      _g(
          description: r'''
**Ladder.**

**How to use it:**
- 10 ft tall; climb to move up or down.

**Cost:** 1 sp  ·  **Weight:** 25 lb
''',
          name: 'Ladder', costCp: 1 * _cpPerSp, weightLb: 25,
          utilizeDescription: '10 ft tall; climb to move up or down.'),
      _g(
          description: r'''
**Lamp.**

**How to use it:**
- Burns Oil to cast Bright Light in a 15-ft radius and Dim Light for an additional 30 ft.

**Cost:** 5 sp  ·  **Weight:** 1 lb
''',
          name: 'Lamp', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 15-ft radius and Dim Light for an additional 30 ft.'),
      _g(
          description: r'''
**Lantern, Bullseye.**

**How to use it:**
- Burns Oil to cast Bright Light in a 60-ft Cone and Dim Light for an additional 60 ft.

**Cost:** 10 gp  ·  **Weight:** 2 lb
''',
          name: 'Lantern, Bullseye', costCp: 10 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 60-ft Cone and Dim Light for an additional 60 ft.'),
      _g(
          description: r'''
**Lantern, Hooded.**

**How to use it:**
- Burns Oil to cast Bright Light in a 30-ft radius and Dim Light for an additional 30 ft.
- Bonus Action to lower the hood.

**Cost:** 5 gp  ·  **Weight:** 2 lb
''',
          name: 'Lantern, Hooded', costCp: 5 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 30-ft radius and Dim Light for an additional 30 ft. Bonus Action to lower the hood.'),
      _g(
          description: r'''
**Lock.**

**How to use it:**
- Comes with a key; without the key DC 15 DEX (Sleight of Hand) with Thieves' Tools to pick.

**Check to use:** when using this item calls for a roll, make a **DC 15 Dexterity** check.

**Cost:** 10 gp  ·  **Weight:** 1 lb
''',
          name: 'Lock', costCp: 10 * _cpPerGp, weightLb: 1,
          utilizeDc: 15, utilizeAbility: 'Dexterity',
          utilizeDescription:
              "Comes with a key; without the key DC 15 DEX (Sleight of Hand) with Thieves' Tools to pick."),
      _g(
          description: r'''
**Magnifying Glass.**

**How to use it:**
- Advantage on ability checks to appraise or inspect a highly detailed item.

**Cost:** 100 gp  ·  **Weight:** —
''',
          name: 'Magnifying Glass', costCp: 100 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              'Advantage on ability checks to appraise or inspect a highly detailed item.'),
      _g(
          description: r'''
**Manacles.**

**How to use it:**
- Bind an unwilling Small/Medium creature.
- DC 13 DEX (Sleight of Hand) check while bound.

**Check to use:** when using this item calls for a roll, make a **DC 13 Dexterity** check.

**Cost:** 2 gp  ·  **Weight:** 6 lb
''',
          name: 'Manacles', costCp: 2 * _cpPerGp, weightLb: 6,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Bind an unwilling Small/Medium creature. DC 13 DEX (Sleight of Hand) check while bound.'),
      _g(
          description: r'''
**Map.**

**How to use it:**
- +5 bonus to Wisdom (Survival) checks to find your way in the place represented on it.

**Cost:** 1 gp  ·  **Weight:** —
''',
          name: 'Map', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              '+5 bonus to Wisdom (Survival) checks to find your way in the place represented on it.'),
      _g(
          description: r'''
**Mirror.**

**How to use it:**
- Useful for personal cosmetics, peeking around corners, or reflecting light as a signal.

**Cost:** 5 gp  ·  **Weight:** 0.5 lb
''',
          name: 'Mirror', costCp: 5 * _cpPerGp, weightLb: 0.5,
          utilizeDescription:
              'Useful for personal cosmetics, peeking around corners, or reflecting light as a signal.'),
      _g(
          description: r'''
**Net.**

**How to use it:**
- Throw at a creature within 15 ft.
- DC 8 + DEX + proficiency bonus; on hit Restrained until escapes (DC 10 STR Athletics action).
- Auto-success if Huge or larger.

**Cost:** 1 gp  ·  **Weight:** 3 lb
''',
          name: 'Net', costCp: 1 * _cpPerGp, weightLb: 3,
          consumable: false,
          utilizeDescription:
              'Throw at a creature within 15 ft. DC 8 + DEX + PB; on hit Restrained until escapes (DC 10 STR Athletics action). Auto-success if Huge or larger.'),
      _g(
          description: r'''
**Oil.**

**How to use it:**
- Throw a flask at a creature within 20 ft as part of the Attack action; if hit and creature later takes Fire damage, takes an extra 5 Fire from burning oil.

**Cost:** 1 sp  ·  **Weight:** 1 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Oil', costCp: 1 * _cpPerSp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw a flask at a creature within 20 ft as part of the Attack action; if hit and creature later takes Fire damage, takes an extra 5 Fire from burning oil.'),
      _g(
          description: r'''
**Paper.**

**How to use it:**
- One sheet holds about 250 handwritten words.

**Cost:** 2 sp  ·  **Weight:** —
''',
          name: 'Paper', costCp: 2 * _cpPerSp, weightLb: 0,
          utilizeDescription: 'One sheet holds about 250 handwritten words.'),
      _g(
          description: r'''
**Parchment.**

**How to use it:**
- One sheet holds about 250 handwritten words.

**Cost:** 1 sp  ·  **Weight:** —
''',
          name: 'Parchment', costCp: 1 * _cpPerSp, weightLb: 0,
          utilizeDescription: 'One sheet holds about 250 handwritten words.'),
      _g(
          description: r'''
**Perfume.**

**How to use it:**
- Apply for 1 hour: Advantage on Charisma (Persuasion) checks to influence an Indifferent Humanoid within 5 ft.

**Cost:** 5 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Perfume', costCp: 5 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Apply for 1 hour: Advantage on Charisma (Persuasion) checks to influence an Indifferent Humanoid within 5 ft.'),
      _g(
          description: r'''
**Poison, Basic.**

**How to use it:**
- Coat one weapon or up to three pieces of ammunition; +1d4 Poison damage on Piercing/Slashing hit.
- Lasts 1 minute or until damage dealt.

**Cost:** 100 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Poison, Basic', costCp: 100 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Coat one weapon or up to three pieces of ammunition; +1d4 Poison damage on Piercing/Slashing hit. Lasts 1 minute or until damage dealt.'),
      _g(
          description: r'''
**Pole.**

**How to use it:**
- 10 ft long.
- Touch something up to 10 ft away.

**Cost:** 5 cp  ·  **Weight:** 7 lb
''',
          name: 'Pole', costCp: 5 * _cpPerCp(), weightLb: 7,
          utilizeDescription:
              '10 ft long. Touch something up to 10 ft away.'),
      _g(
          description: r'''
**Pot, Iron.**

**How to use it:**
- Holds up to 1 gallon.

**Cost:** 2 gp  ·  **Weight:** 10 lb
''',
          name: 'Pot, Iron', costCp: 2 * _cpPerGp, weightLb: 10,
          utilizeDescription: 'Holds up to 1 gallon.'),
      _g(
          description: r'''
**Potion of Healing.**

**How to use it:**
- Bonus Action to drink/administer; regain 2d4 + 2 Hit Points.

**Cost:** 50 gp  ·  **Weight:** 0.5 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Potion of Healing', costCp: 50 * _cpPerGp, weightLb: 0.5,
          consumable: true,
          utilizeDescription:
              'Bonus Action to drink/administer; regain 2d4 + 2 Hit Points.'),
      _g(
          description: r'''
**Pouch.**

**How to use it:**
- Holds up to 6 lb within one-fifth of a cubic foot.

**Cost:** 5 sp  ·  **Weight:** 1 lb
''',
          name: 'Pouch', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Holds up to 6 lb within one-fifth of a cubic foot.'),
      _g(
          description: r'''
**Priest's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 33 gp  ·  **Weight:** 29 lb
''',
          name: "Priest's Pack", costCp: 33 * _cpPerGp, weightLb: 29),
      _g(
          description: r'''
**Quiver.**

**How to use it:**
- Holds up to 20 Arrows.

**Cost:** 1 gp  ·  **Weight:** 1 lb
''',
          name: 'Quiver', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Holds up to 20 Arrows.'),
      _g(
          description: r'''
**Ram, Portable.**

**How to use it:**
- +4 bonus to Strength check to break down doors.
- Another character helping gives Advantage.

**Cost:** 4 gp  ·  **Weight:** 35 lb
''',
          name: 'Ram, Portable', costCp: 4 * _cpPerGp, weightLb: 35,
          utilizeDescription:
              '+4 bonus to STR check to break down doors. Another character helping gives Advantage.'),
      _g(
          description: r'''
**Rations.**

**How to use it:**
- Travel-ready food (jerky, fruit, hardtack, nuts).

**Cost:** 5 sp  ·  **Weight:** 2 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Rations', costCp: 5 * _cpPerSp, weightLb: 2,
          consumable: true,
          utilizeDescription: 'Travel-ready food (jerky, fruit, hardtack, nuts).'),
      _g(
          description: r'''
**Robe.**

**How to use it:**
- Vocational or ceremonial significance.
- Some places admit only those wearing certain colors/symbols.

**Cost:** 1 gp  ·  **Weight:** 4 lb
''',
          name: 'Robe', costCp: 1 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Vocational or ceremonial significance. Some places admit only those wearing certain colors/symbols.'),
      _g(
          description: r'''
**Rope.**

**How to use it:**
- Tie a knot.
- DC 10 DEX (Sleight of Hand).
- DC 20 STR (Athletics) to burst.

**Check to use:** when using this item calls for a roll, make a **DC 10 Dexterity** check.

**Cost:** 1 gp  ·  **Weight:** 5 lb
''',
          name: 'Rope', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDc: 10, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Tie a knot. DC 10 DEX (Sleight of Hand). DC 20 STR (Athletics) to burst.'),
      _g(
          description: r'''
**Sack.**

**How to use it:**
- Holds up to 30 lb within 1 cubic foot.

**Cost:** 1 cp  ·  **Weight:** 0.5 lb
''',
          name: 'Sack', costCp: 1, weightLb: 0.5,
          utilizeDescription: 'Holds up to 30 lb within 1 cubic foot.'),
      _g(
          description: r'''
**Scholar's Pack.**

A ready-made bundle of adventuring equipment, sold together for convenience so you don't have to buy each piece separately. The pack's individual contents are listed in the SRD equipment pack tables.

**Cost:** 40 gp  ·  **Weight:** 22 lb
''',
          name: "Scholar's Pack", costCp: 40 * _cpPerGp, weightLb: 22),
      _g(
          description: r'''
**Shovel.**

**How to use it:**
- 1 hour to dig a hole 5 ft on each side in soil or similar material.

**Cost:** 2 gp  ·  **Weight:** 5 lb
''',
          name: 'Shovel', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              '1 hour to dig a hole 5 ft on each side in soil or similar material.'),
      _g(
          description: r'''
**Signal Whistle.**

**How to use it:**
- Sound heard up to 600 ft away.

**Cost:** 5 cp  ·  **Weight:** —
''',
          name: 'Signal Whistle', costCp: 5, weightLb: 0,
          utilizeDescription: 'Sound heard up to 600 ft away.'),
      _g(
          description: r'''
**Spell Scroll (Cantrip).**

**How to use it:**
- Magic item bearing a cantrip.
- Read scroll to cast at scribe's level; scroll disintegrates.

**Cost:** 30 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Spell Scroll (Cantrip)', costCp: 30 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              "Magic item bearing a cantrip. Read scroll to cast at scribe's level; scroll disintegrates."),
      _g(
          description: r'''
**Spell Scroll (Level 1).**

**How to use it:**
- Magic item bearing a level 1 spell.
- Save DC 13, attack +5; scroll disintegrates.

**Cost:** 50 gp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Spell Scroll (Level 1)', costCp: 50 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Magic item bearing a level 1 spell. Save DC 13, attack +5; scroll disintegrates.'),
      _g(
          description: r'''
**Spikes, Iron.**

**How to use it:**
- Bundle of ten.
- Hammer to jam doors shut or tie ropes/chains to.

**Cost:** 1 gp  ·  **Weight:** 5 lb
''',
          name: 'Spikes, Iron', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Bundle of ten. Hammer to jam doors shut or tie ropes/chains to.'),
      _g(
          description: r'''
**Spyglass.**

**How to use it:**
- Magnifies viewed objects to twice their size.

**Cost:** 1000 gp  ·  **Weight:** 1 lb
''',
          name: 'Spyglass', costCp: 1000 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Magnifies viewed objects to twice their size.'),
      _g(
          description: r'''
**String.**

**How to use it:**
- 10 ft long; tie a knot as a Utilize action.

**Cost:** 1 sp  ·  **Weight:** —
''',
          name: 'String', costCp: 1 * _cpPerSp, weightLb: 0,
          utilizeDescription: '10 ft long; tie a knot as a Utilize action.'),
      _g(
          description: r'''
**Tent.**

**How to use it:**
- Sleeps up to two Small or Medium creatures.

**Cost:** 2 gp  ·  **Weight:** 20 lb
''',
          name: 'Tent', costCp: 2 * _cpPerGp, weightLb: 20,
          utilizeDescription: 'Sleeps up to two Small or Medium creatures.'),
      _g(
          description: r'''
**Tinderbox.**

**How to use it:**
- Light a Candle/Lamp/Lantern/Torch—or anything with exposed fuel—as a Bonus Action.

**Cost:** 5 sp  ·  **Weight:** 1 lb
''',
          name: 'Tinderbox', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Light a Candle/Lamp/Lantern/Torch—or anything with exposed fuel—as a Bonus Action.'),
      _g(
          description: r'''
**Torch.**

**How to use it:**
- Burns 1 hour;
- Bright Light 20 ft, Dim Light 20 ft.
- Attack action: hit deals 1 Fire damage.

**Cost:** 1 cp  ·  **Weight:** 1 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Torch', costCp: 1, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Burns 1 hour; Bright Light 20 ft, Dim Light 20 ft. Attack action: hit deals 1 Fire damage.'),
      _g(
          description: r'''
**Vial.**

**How to use it:**
- Holds up to 4 ounces.

**Cost:** 1 gp  ·  **Weight:** —
''',
          name: 'Vial', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription: 'Holds up to 4 ounces.'),
      _g(
          description: r'''
**Waterskin.**

**How to use it:**
- Holds up to 4 pints.

**Cost:** 2 sp  ·  **Weight:** 5 lb
''',
          name: 'Waterskin', costCp: 2 * _cpPerSp, weightLb: 5,
          utilizeDescription: 'Holds up to 4 pints.'),

      // ── Tack and Harness (SRD p. 100) ─────────────────────────────
      _g(
          description: r'''
**Saddle, Exotic.**

**How to use it:**
- Required to ride awakened or magical mounts (e.g.
- Pegasus, Griffon).

**Cost:** 60 gp  ·  **Weight:** 40 lb
''',
          name: 'Saddle, Exotic', costCp: 60 * _cpPerGp, weightLb: 40,
          utilizeDescription:
              'Required to ride awakened or magical mounts (e.g. Pegasus, Griffon).'),
      _g(
          description: r'''
**Saddle, Military.**

**How to use it:**
- Advantage on saves vs. being knocked off the mount in combat.

**Cost:** 20 gp  ·  **Weight:** 30 lb
''',
          name: 'Saddle, Military', costCp: 20 * _cpPerGp, weightLb: 30,
          utilizeDescription:
              "Advantage on saves vs. being knocked off the mount in combat."),
      _g(
          description: r'''
**Saddle, Riding.**

**How to use it:**
- Standard saddle for ordinary mounts.

**Cost:** 10 gp  ·  **Weight:** 25 lb
''',
          name: 'Saddle, Riding', costCp: 10 * _cpPerGp, weightLb: 25,
          utilizeDescription:
              'Standard saddle for ordinary mounts.'),
      _g(
          description: r'''
**Feed.**

**How to use it:**
- One day of feed for one mount.

**Cost:** 5 cp  ·  **Weight:** 10 lb  ·  **Consumable** (used up when you use it)
''',
          name: 'Feed', costCp: 5, weightLb: 10,
          consumable: true,
          utilizeDescription: 'One day of feed for one mount.'),
      _g(
          description: r'''
**Stabling.**

**How to use it:**
- One day of stabling for one mount.

**Cost:** 5 sp  ·  **Weight:** —  ·  **Consumable** (used up when you use it)
''',
          name: 'Stabling', costCp: 5 * _cpPerSp, weightLb: 0,
          consumable: true,
          utilizeDescription: 'One day of stabling for one mount.'),

      // ── Arcane Foci ───────────────────────────────────────────────
      _g(
          description: r'''
**Crystal.**

An **arcane spellcasting focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 10 gp  ·  **Weight:** 1 lb
''',
          name: 'Crystal', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Crystal'),
      _g(
          description: r'''
**Orb.**

An **arcane spellcasting focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 20 gp  ·  **Weight:** 3 lb
''',
          name: 'Orb', costCp: 20 * _cpPerGp, weightLb: 3,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Orb'),
      _g(
          description: r'''
**Rod.**

An **arcane spellcasting focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 10 gp  ·  **Weight:** 2 lb
''',
          name: 'Rod', costCp: 10 * _cpPerGp, weightLb: 2,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Rod'),
      _g(
          description: r'''
**Staff (Arcane Focus).**

An **arcane spellcasting focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 5 gp  ·  **Weight:** 4 lb
''',
          name: 'Staff (Arcane Focus)', costCp: 5 * _cpPerGp, weightLb: 4,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Staff'),
      _g(
          description: r'''
**Wand (Arcane Focus).**

An **arcane spellcasting focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 10 gp  ·  **Weight:** 1 lb
''',
          name: 'Wand (Arcane Focus)', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Wand'),

      // ── Druidic Foci ──────────────────────────────────────────────
      _g(
          description: r'''
**Sprig of Mistletoe.**

A **druidic focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 1 gp  ·  **Weight:** —
''',
          name: 'Sprig of Mistletoe', costCp: 1 * _cpPerGp, weightLb: 0,
          isFocus: true,
          focusKindSlug: 'druidic-focus',
          focusKindName: 'Sprig of Mistletoe'),
      _g(
          description: r'''
**Wooden Staff (Druidic Focus).**

A **druidic focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 5 gp  ·  **Weight:** 4 lb
''',
          name: 'Wooden Staff (Druidic Focus)',
          costCp: 5 * _cpPerGp, weightLb: 4,
          isFocus: true,
          focusKindSlug: 'druidic-focus',
          focusKindName: 'Wooden Staff'),
      _g(
          description: r'''
**Yew Wand.**

A **druidic focus**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 10 gp  ·  **Weight:** 1 lb
''',
          name: 'Yew Wand', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'druidic-focus', focusKindName: 'Yew Wand'),

      // ── Holy Symbols ──────────────────────────────────────────────
      _g(
          description: r'''
**Amulet (Holy Symbol).**

A **holy symbol**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 5 gp  ·  **Weight:** 1 lb
''',
          name: 'Amulet (Holy Symbol)', costCp: 5 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Amulet'),
      _g(
          description: r'''
**Emblem (Holy Symbol).**

A **holy symbol**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 5 gp  ·  **Weight:** —
''',
          name: 'Emblem (Holy Symbol)', costCp: 5 * _cpPerGp, weightLb: 0,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Emblem'),
      _g(
          description: r'''
**Reliquary.**

A **holy symbol**. While you hold it, you can use it in place of the material components for your spells — except for any component that has a cost listed, or one that's consumed by the spell.

**Cost:** 5 gp  ·  **Weight:** 2 lb
''',
          name: 'Reliquary', costCp: 5 * _cpPerGp, weightLb: 2,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Reliquary'),

      // ── Gap closure: missed common SRD 5.2.1 adventuring gear ─────
      _g(
          description: r'''
**Chalk.**

A stick of chalk for marking surfaces — leaving trail signs, sketching rough maps, or labeling your gear.

**Cost:** 1 cp  ·  **Weight:** —
''',
          name: 'Chalk', costCp: 1, weightLb: 0),
      _g(
          description: r'''
**Fishing Tackle.**

A wooden rod, line, hooks, and lures for catching fish to supplement your rations.

**Cost:** 1 gp  ·  **Weight:** 4 lb
''',
          name: 'Fishing Tackle', costCp: 1 * _cpPerGp, weightLb: 4),
      _g(
          description: r'''
**Hammer.**

A one-handed hammer for driving pitons, tent stakes, and iron spikes.

**Cost:** 1 gp  ·  **Weight:** 3 lb
''',
          name: 'Hammer', costCp: 1 * _cpPerGp, weightLb: 3),
      _g(
          description: r'''
**Hourglass.**

A sand timer that measures the passage of roughly one hour.

**Cost:** 25 gp  ·  **Weight:** 1 lb
''',
          name: 'Hourglass', costCp: 25 * _cpPerGp, weightLb: 1),
      _g(
          description: r'''
**Mess Kit.**

A tin box holding a cup and simple cutlery so you can prepare and eat meals on the trail.

**Cost:** 2 sp  ·  **Weight:** 1 lb
''',
          name: 'Mess Kit', costCp: 2 * _cpPerSp, weightLb: 1),
      _g(
          description: r'''
**Pick, Miner's.**

A heavy pick for breaking apart rock and digging out ore.

**Cost:** 2 gp  ·  **Weight:** 10 lb
''',
          name: 'Pick, Miner\'s', costCp: 2 * _cpPerGp, weightLb: 10),
      _g(
          description: r'''
**Piton.**

An iron spike you hammer into rock or wood to anchor a rope.

**Cost:** 5 cp  ·  **Weight:** 0.25 lb
''',
          name: 'Piton', costCp: 5, weightLb: 0.25),
      _g(
          description: r'''
**Scale, Merchant's.**

A balance with a set of weights for measuring the weight of goods, coins, or trade items.

**Cost:** 5 gp  ·  **Weight:** 3 lb
''',
          name: 'Scale, Merchant\'s', costCp: 5 * _cpPerGp, weightLb: 3),
      _g(
          description: r'''
**Sealing Wax.**

Wax for sealing letters and documents, usually stamped with a signet.

**Cost:** 5 sp  ·  **Weight:** —
''',
          name: 'Sealing Wax', costCp: 5 * _cpPerSp, weightLb: 0),
      _g(
          description: r'''
**Signet Ring.**

An engraved ring used to press your personal seal into wax.

**Cost:** 5 gp  ·  **Weight:** —
''',
          name: 'Signet Ring', costCp: 5 * _cpPerGp, weightLb: 0),
      _g(
          description: r'''
**Soap.**

A bar of soap for washing yourself and your equipment.

**Cost:** 2 cp  ·  **Weight:** —
''',
          name: 'Soap', costCp: 2 * _cpPerCp(), weightLb: 0),
      _g(
          description: r'''
**Spellbook.**

A leather-bound tome of 100 blank pages in which a wizard records the spells they know.

**Cost:** 50 gp  ·  **Weight:** 3 lb
''',
          name: 'Spellbook', costCp: 50 * _cpPerGp, weightLb: 3),
      _g(
          description: r'''
**Whetstone.**

A sharpening stone for honing the edge of a blade or tool.

**Cost:** 1 cp  ·  **Weight:** 1 lb
''',
          name: 'Whetstone', costCp: 1 * _cpPerCp(), weightLb: 1),
    ];

int _cpPerCp() => 1; // syntactic helper for "X CP" rows.
