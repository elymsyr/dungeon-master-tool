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
  return packEntity(slug: _slug, name: name, attributes: attrs);
}

/// Hand-authored adventuring gear from SRD 5.2.1 pp. 94–99.
/// Note: trade goods, money, and arcane/druidic/holy focus *items* live
/// here; the focus *kinds* (Crystal, Orb, Wand, …) ship as Tier-0
/// `arcane-focus` / `druidic-focus` / `holy-symbol` rows. Each focus item
/// row points back at its kind via `focus_kind_ref`.
List<Map<String, dynamic>> srdAdventuringGear() => [
      _g(name: 'Acid', costCp: 25 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw a vial of Acid at a creature within 20 ft. as part of the Attack action. DC 8 + DEX mod + PB; on hit deals 2d6 Acid damage.'),
      _g(name: "Alchemist's Fire", costCp: 50 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              "Throw a flask of Alchemist's Fire at a creature within 20 ft. as part of the Attack action. DC 8 + DEX mod + PB; on hit deals 1d4 Fire damage and starts burning."),
      _g(name: 'Antitoxin', costCp: 50 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'As a Bonus Action drink the vial to gain Advantage on saves to avoid or end the Poisoned condition for 1 hour.'),
      _g(name: 'Backpack', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Holds up to 30 lb within 1 cubic foot. Can also serve as a saddlebag.'),
      _g(name: 'Ball Bearings', costCp: 1 * _cpPerGp, weightLb: 2,
          consumable: false,
          utilizeDc: 10, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Spill bearings to cover a level, 10-ft-square area within 5 ft. DC 10 DEX save to avoid going Prone; takes 10 minutes to recover.'),
      _g(name: 'Barrel', costCp: 2 * _cpPerGp, weightLb: 70,
          utilizeDescription:
              'Holds up to 40 gallons of liquid or up to 4 cubic feet of dry goods.'),
      _g(name: 'Basket', costCp: 4 * _cpPerSp, weightLb: 2,
          utilizeDescription:
              'Holds up to 40 lb within 2 cubic feet.'),
      _g(name: 'Bedroll', costCp: 1 * _cpPerGp, weightLb: 7,
          utilizeDescription:
              'Sleeps one Small or Medium creature. Auto-succeed on saves vs. extreme cold.'),
      _g(name: 'Bell', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              'Produces a sound that can be heard up to 60 ft away.'),
      _g(name: 'Blanket', costCp: 5 * _cpPerSp, weightLb: 3,
          utilizeDescription:
              'While wrapped in a blanket gain Advantage on saves vs. extreme cold.'),
      _g(name: 'Block and Tackle', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Hoist up to four times the weight you can normally lift.'),
      _g(name: 'Book', costCp: 25 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              '+5 bonus to Intelligence (Arcana, History, Nature, Religion) checks about its topic.'),
      _g(name: 'Bottle, Glass', costCp: 2 * _cpPerGp, weightLb: 2,
          utilizeDescription: 'Holds up to 1.5 pints.'),
      _g(name: 'Bucket', costCp: 5 * _cpPerCp(), weightLb: 2,
          utilizeDescription: 'Holds up to half a cubic foot of contents.'),
      _g(name: 'Caltrops', costCp: 1 * _cpPerGp, weightLb: 2,
          utilizeDc: 15, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Spread to cover a 5-ft-square area. DC 15 DEX save to avoid 1 Piercing damage and Speed reduced to 0 until start of next turn.'),
      _g(name: 'Candle', costCp: 1, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'For 1 hour sheds Bright Light in a 5-ft radius and Dim Light for an additional 5 ft.'),
      _g(name: 'Case, Crossbow Bolt', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Holds up to 20 Bolts.'),
      _g(name: 'Case, Map or Scroll', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription:
              'Holds up to 10 sheets of paper or 5 sheets of parchment.'),
      _g(name: 'Chain', costCp: 5 * _cpPerGp, weightLb: 10,
          utilizeDc: 13, utilizeAbility: 'Strength',
          utilizeDescription:
              'Wrap around an unwilling Grappled/Incapacitated/Restrained creature. DC 13 STR (Athletics) check to bind.'),
      _g(name: 'Chest', costCp: 5 * _cpPerGp, weightLb: 25,
          utilizeDescription: 'Holds up to 12 cubic feet of contents.'),
      _g(name: "Climber's Kit", costCp: 25 * _cpPerGp, weightLb: 12,
          utilizeDescription:
              "Anchor yourself; you can't fall more than 25 ft from the anchor and can't move more than 25 ft from there without undoing the anchor as a Bonus Action."),
      _g(name: 'Clothes, Fine', costCp: 15 * _cpPerGp, weightLb: 6,
          utilizeDescription:
              'Some events and locations admit only people wearing fine clothes.'),
      _g(name: "Clothes, Traveler's", costCp: 2 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Resilient garments designed for travel in various environments.'),
      _g(name: 'Component Pouch', costCp: 25 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Contains all the free Material components of your spells.'),
      _g(name: 'Costume', costCp: 5 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Advantage on ability checks to impersonate the person or type of person it represents.'),
      _g(name: 'Crowbar', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Advantage on Strength checks where the leverage can be applied.'),
      _g(name: "Burglar's Pack", costCp: 16 * _cpPerGp, weightLb: 42),
      _g(name: "Diplomat's Pack", costCp: 39 * _cpPerGp, weightLb: 39),
      _g(name: "Dungeoneer's Pack", costCp: 12 * _cpPerGp, weightLb: 55),
      _g(name: "Entertainer's Pack", costCp: 40 * _cpPerGp, weightLb: 58),
      _g(name: "Explorer's Pack", costCp: 10 * _cpPerGp, weightLb: 55),
      _g(name: 'Flask', costCp: 2, weightLb: 1,
          utilizeDescription: 'Holds up to 1 pint.'),
      _g(name: 'Grappling Hook', costCp: 2 * _cpPerGp, weightLb: 4,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Throw at a railing/ledge/catch within 50 ft. DC 13 DEX (Acrobatics) for the hook to catch.'),
      _g(name: "Healer's Kit", costCp: 5 * _cpPerGp, weightLb: 3,
          consumable: true,
          utilizeDescription:
              'Ten uses. Stabilize an Unconscious creature with 0 HP without needing a Wisdom (Medicine) check.'),
      _g(name: 'Holy Water', costCp: 25 * _cpPerGp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw at a creature within 20 ft as part of the Attack action. DC 8 + DEX + PB; on hit deals 2d8 Radiant damage if Fiend or Undead.'),
      _g(name: 'Hunting Trap', costCp: 5 * _cpPerGp, weightLb: 25,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Place sawtooth ring snap-trap. DC 13 DEX save to avoid 1d4 Piercing and Speed 0; STR (Athletics) DC 13 to escape.'),
      _g(name: 'Ink', costCp: 10 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              '1-ounce bottle; enough ink to write about 500 pages.'),
      _g(name: 'Ink Pen', costCp: 2, weightLb: 0,
          utilizeDescription: 'Used with Ink to write or draw.'),
      _g(name: 'Jug', costCp: 2, weightLb: 4,
          utilizeDescription: 'Holds up to 1 gallon.'),
      _g(name: 'Ladder', costCp: 1 * _cpPerSp, weightLb: 25,
          utilizeDescription: '10 ft tall; climb to move up or down.'),
      _g(name: 'Lamp', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 15-ft radius and Dim Light for an additional 30 ft.'),
      _g(name: 'Lantern, Bullseye', costCp: 10 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 60-ft Cone and Dim Light for an additional 60 ft.'),
      _g(name: 'Lantern, Hooded', costCp: 5 * _cpPerGp, weightLb: 2,
          utilizeDescription:
              'Burns Oil to cast Bright Light in a 30-ft radius and Dim Light for an additional 30 ft. Bonus Action to lower the hood.'),
      _g(name: 'Lock', costCp: 10 * _cpPerGp, weightLb: 1,
          utilizeDc: 15, utilizeAbility: 'Dexterity',
          utilizeDescription:
              "Comes with a key; without the key DC 15 DEX (Sleight of Hand) with Thieves' Tools to pick."),
      _g(name: 'Magnifying Glass', costCp: 100 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              'Advantage on ability checks to appraise or inspect a highly detailed item.'),
      _g(name: 'Manacles', costCp: 2 * _cpPerGp, weightLb: 6,
          utilizeDc: 13, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Bind an unwilling Small/Medium creature. DC 13 DEX (Sleight of Hand) check while bound.'),
      _g(name: 'Map', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription:
              '+5 bonus to Wisdom (Survival) checks to find your way in the place represented on it.'),
      _g(name: 'Mirror', costCp: 5 * _cpPerGp, weightLb: 0.5,
          utilizeDescription:
              'Useful for personal cosmetics, peeking around corners, or reflecting light as a signal.'),
      _g(name: 'Net', costCp: 1 * _cpPerGp, weightLb: 3,
          consumable: false,
          utilizeDescription:
              'Throw at a creature within 15 ft. DC 8 + DEX + PB; on hit Restrained until escapes (DC 10 STR Athletics action). Auto-success if Huge or larger.'),
      _g(name: 'Oil', costCp: 1 * _cpPerSp, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Throw a flask at a creature within 20 ft as part of the Attack action; if hit and creature later takes Fire damage, takes an extra 5 Fire from burning oil.'),
      _g(name: 'Paper', costCp: 2 * _cpPerSp, weightLb: 0,
          utilizeDescription: 'One sheet holds about 250 handwritten words.'),
      _g(name: 'Parchment', costCp: 1 * _cpPerSp, weightLb: 0,
          utilizeDescription: 'One sheet holds about 250 handwritten words.'),
      _g(name: 'Perfume', costCp: 5 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Apply for 1 hour: Advantage on Charisma (Persuasion) checks to influence an Indifferent Humanoid within 5 ft.'),
      _g(name: 'Poison, Basic', costCp: 100 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Coat one weapon or up to three pieces of ammunition; +1d4 Poison damage on Piercing/Slashing hit. Lasts 1 minute or until damage dealt.'),
      _g(name: 'Pole', costCp: 5 * _cpPerCp(), weightLb: 7,
          utilizeDescription:
              '10 ft long. Touch something up to 10 ft away.'),
      _g(name: 'Pot, Iron', costCp: 2 * _cpPerGp, weightLb: 10,
          utilizeDescription: 'Holds up to 1 gallon.'),
      _g(name: 'Potion of Healing', costCp: 50 * _cpPerGp, weightLb: 0.5,
          consumable: true,
          utilizeDescription:
              'Bonus Action to drink/administer; regain 2d4 + 2 Hit Points.'),
      _g(name: 'Pouch', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Holds up to 6 lb within one-fifth of a cubic foot.'),
      _g(name: "Priest's Pack", costCp: 33 * _cpPerGp, weightLb: 29),
      _g(name: 'Quiver', costCp: 1 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Holds up to 20 Arrows.'),
      _g(name: 'Ram, Portable', costCp: 4 * _cpPerGp, weightLb: 35,
          utilizeDescription:
              '+4 bonus to STR check to break down doors. Another character helping gives Advantage.'),
      _g(name: 'Rations', costCp: 5 * _cpPerSp, weightLb: 2,
          consumable: true,
          utilizeDescription: 'Travel-ready food (jerky, fruit, hardtack, nuts).'),
      _g(name: 'Robe', costCp: 1 * _cpPerGp, weightLb: 4,
          utilizeDescription:
              'Vocational or ceremonial significance. Some places admit only those wearing certain colors/symbols.'),
      _g(name: 'Rope', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDc: 10, utilizeAbility: 'Dexterity',
          utilizeDescription:
              'Tie a knot. DC 10 DEX (Sleight of Hand). DC 20 STR (Athletics) to burst.'),
      _g(name: 'Sack', costCp: 1, weightLb: 0.5,
          utilizeDescription: 'Holds up to 30 lb within 1 cubic foot.'),
      _g(name: "Scholar's Pack", costCp: 40 * _cpPerGp, weightLb: 22),
      _g(name: 'Shovel', costCp: 2 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              '1 hour to dig a hole 5 ft on each side in soil or similar material.'),
      _g(name: 'Signal Whistle', costCp: 5, weightLb: 0,
          utilizeDescription: 'Sound heard up to 600 ft away.'),
      _g(name: 'Spell Scroll (Cantrip)', costCp: 30 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              "Magic item bearing a cantrip. Read scroll to cast at scribe's level; scroll disintegrates."),
      _g(name: 'Spell Scroll (Level 1)', costCp: 50 * _cpPerGp, weightLb: 0,
          consumable: true,
          utilizeDescription:
              'Magic item bearing a level 1 spell. Save DC 13, attack +5; scroll disintegrates.'),
      _g(name: 'Spikes, Iron', costCp: 1 * _cpPerGp, weightLb: 5,
          utilizeDescription:
              'Bundle of ten. Hammer to jam doors shut or tie ropes/chains to.'),
      _g(name: 'Spyglass', costCp: 1000 * _cpPerGp, weightLb: 1,
          utilizeDescription: 'Magnifies viewed objects to twice their size.'),
      _g(name: 'String', costCp: 1 * _cpPerSp, weightLb: 0,
          utilizeDescription: '10 ft long; tie a knot as a Utilize action.'),
      _g(name: 'Tent', costCp: 2 * _cpPerGp, weightLb: 20,
          utilizeDescription: 'Sleeps up to two Small or Medium creatures.'),
      _g(name: 'Tinderbox', costCp: 5 * _cpPerSp, weightLb: 1,
          utilizeDescription:
              'Light a Candle/Lamp/Lantern/Torch—or anything with exposed fuel—as a Bonus Action.'),
      _g(name: 'Torch', costCp: 1, weightLb: 1,
          consumable: true,
          utilizeDescription:
              'Burns 1 hour; Bright Light 20 ft, Dim Light 20 ft. Attack action: hit deals 1 Fire damage.'),
      _g(name: 'Vial', costCp: 1 * _cpPerGp, weightLb: 0,
          utilizeDescription: 'Holds up to 4 ounces.'),
      _g(name: 'Waterskin', costCp: 2 * _cpPerSp, weightLb: 5,
          utilizeDescription: 'Holds up to 4 pints.'),

      // ── Tack and Harness (SRD p. 100) ─────────────────────────────
      _g(name: 'Saddle, Exotic', costCp: 60 * _cpPerGp, weightLb: 40,
          utilizeDescription:
              'Required to ride awakened or magical mounts (e.g. Pegasus, Griffon).'),
      _g(name: 'Saddle, Military', costCp: 20 * _cpPerGp, weightLb: 30,
          utilizeDescription:
              "Advantage on saves vs. being knocked off the mount in combat."),
      _g(name: 'Saddle, Riding', costCp: 10 * _cpPerGp, weightLb: 25,
          utilizeDescription:
              'Standard saddle for ordinary mounts.'),
      _g(name: 'Feed', costCp: 5, weightLb: 10,
          consumable: true,
          utilizeDescription: 'One day of feed for one mount.'),
      _g(name: 'Stabling', costCp: 5 * _cpPerSp, weightLb: 0,
          consumable: true,
          utilizeDescription: 'One day of stabling for one mount.'),

      // ── Arcane Foci ───────────────────────────────────────────────
      _g(name: 'Crystal', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Crystal'),
      _g(name: 'Orb', costCp: 20 * _cpPerGp, weightLb: 3,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Orb'),
      _g(name: 'Rod', costCp: 10 * _cpPerGp, weightLb: 2,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Rod'),
      _g(name: 'Staff (Arcane Focus)', costCp: 5 * _cpPerGp, weightLb: 4,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Staff'),
      _g(name: 'Wand (Arcane Focus)', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'arcane-focus', focusKindName: 'Wand'),

      // ── Druidic Foci ──────────────────────────────────────────────
      _g(name: 'Sprig of Mistletoe', costCp: 1 * _cpPerGp, weightLb: 0,
          isFocus: true,
          focusKindSlug: 'druidic-focus',
          focusKindName: 'Sprig of Mistletoe'),
      _g(name: 'Wooden Staff (Druidic Focus)',
          costCp: 5 * _cpPerGp, weightLb: 4,
          isFocus: true,
          focusKindSlug: 'druidic-focus',
          focusKindName: 'Wooden Staff'),
      _g(name: 'Yew Wand', costCp: 10 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'druidic-focus', focusKindName: 'Yew Wand'),

      // ── Holy Symbols ──────────────────────────────────────────────
      _g(name: 'Amulet (Holy Symbol)', costCp: 5 * _cpPerGp, weightLb: 1,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Amulet'),
      _g(name: 'Emblem (Holy Symbol)', costCp: 5 * _cpPerGp, weightLb: 0,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Emblem'),
      _g(name: 'Reliquary', costCp: 5 * _cpPerGp, weightLb: 2,
          isFocus: true,
          focusKindSlug: 'holy-symbol', focusKindName: 'Reliquary'),
    ];

int _cpPerCp() => 1; // syntactic helper for "X CP" rows.
