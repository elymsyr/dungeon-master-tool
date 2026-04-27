// SRD 5.2.1 Tools (pp. 93–94). Categories on Tier-0:
//   "Artisan's Tools", "Other Tools", "Gaming Set", "Musical Instrument".
// Tools' `craftable_items` references resolve at *campaign* time against
// the seeded gear catalogue — encoded as `_ref('adventuring-gear', name)`.

import '_helpers.dart';

const _slug = 'tool';

Map<String, dynamic> _t({
  required String name,
  required String category,
  required String ability,
  required double costGp,
  required double weightLb,
  int? utilizeDc,
  String? utilizeDescription,
  List<String> craftableGear = const [],
  String? variantOf,
}) {
  final attrs = <String, dynamic>{
    'category_ref': category,
    'ability_ref': lookup('ability', ability),
    'cost_gp': costGp,
    'weight_lb': weightLb,
  };
  if (utilizeDc != null) attrs['utilize_check_dc'] = utilizeDc;
  if (utilizeDescription != null) {
    attrs['utilize_description'] = utilizeDescription;
  }
  if (craftableGear.isNotEmpty) {
    attrs['craftable_items'] =
        craftableGear.map((g) => ref('adventuring-gear', g)).toList();
  }
  if (variantOf != null) attrs['variant_of_ref'] = ref('tool', variantOf);
  return packEntity(slug: _slug, name: name, attributes: attrs);
}

/// SRD 5.2.1 tools — Artisan's Tools (15), Other Tools (5), Gaming Set
/// variants (3), Musical Instruments (9).
List<Map<String, dynamic>> srdTools() => [
      // ── Artisan's Tools ───────────────────────────────────────────
      _t(name: "Alchemist's Supplies", category: "Artisan's Tools",
          ability: 'Intelligence', costGp: 50, weightLb: 8,
          utilizeDc: 15,
          utilizeDescription:
              'Identify a substance (DC 15), or start a fire (DC 15)'),
      _t(name: "Brewer's Supplies", category: "Artisan's Tools",
          ability: 'Intelligence', costGp: 20, weightLb: 9,
          utilizeDc: 15,
          utilizeDescription:
              'Detect poisoned drink (DC 15), or identify alcohol (DC 10)'),
      _t(name: "Calligrapher's Supplies", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 10, weightLb: 5,
          utilizeDc: 15,
          utilizeDescription:
              'Write text with impressive flourishes that guard against forgery (DC 15)'),
      _t(name: "Carpenter's Tools", category: "Artisan's Tools",
          ability: 'Strength', costGp: 8, weightLb: 6,
          utilizeDc: 20,
          utilizeDescription:
              'Seal or pry open a door or container (DC 20)'),
      _t(name: "Cartographer's Tools", category: "Artisan's Tools",
          ability: 'Wisdom', costGp: 15, weightLb: 6,
          utilizeDc: 15,
          utilizeDescription: 'Draft a map of a small area (DC 15)'),
      _t(name: "Cobbler's Tools", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 5, weightLb: 5,
          utilizeDc: 10,
          utilizeDescription:
              "Modify footwear to give Advantage on the wearer's next Dexterity (Acrobatics) check (DC 10)"),
      _t(name: "Cook's Utensils", category: "Artisan's Tools",
          ability: 'Wisdom', costGp: 1, weightLb: 8,
          utilizeDc: 15,
          utilizeDescription:
              "Improve food's flavor (DC 10), or detect spoiled or poisoned food (DC 15)"),
      _t(name: "Glassblower's Tools", category: "Artisan's Tools",
          ability: 'Intelligence', costGp: 30, weightLb: 5,
          utilizeDc: 15,
          utilizeDescription:
              'Discern what a glass object held in the past 24 hours (DC 15)'),
      _t(name: "Jeweler's Tools", category: "Artisan's Tools",
          ability: 'Intelligence', costGp: 25, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription: "Discern a gem's value (DC 15)"),
      _t(name: "Leatherworker's Tools", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 5, weightLb: 5,
          utilizeDc: 10,
          utilizeDescription: 'Add a design to a leather item (DC 10)'),
      _t(name: "Mason's Tools", category: "Artisan's Tools",
          ability: 'Strength', costGp: 10, weightLb: 8,
          utilizeDc: 10,
          utilizeDescription: 'Chisel a symbol or hole in stone (DC 10)'),
      _t(name: "Painter's Supplies", category: "Artisan's Tools",
          ability: 'Wisdom', costGp: 10, weightLb: 5,
          utilizeDc: 10,
          utilizeDescription:
              "Paint a recognizable image of something you've seen (DC 10)"),
      _t(name: "Potter's Tools", category: "Artisan's Tools",
          ability: 'Intelligence', costGp: 10, weightLb: 3,
          utilizeDc: 15,
          utilizeDescription:
              'Discern what a ceramic object held in the past 24 hours (DC 15)'),
      _t(name: "Smith's Tools", category: "Artisan's Tools",
          ability: 'Strength', costGp: 20, weightLb: 8,
          utilizeDc: 20,
          utilizeDescription:
              'Pry open a door or container (DC 20)'),
      _t(name: "Tinker's Tools", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 50, weightLb: 10,
          utilizeDc: 20,
          utilizeDescription:
              'Assemble a Tiny item composed of scrap, which falls apart in 1 minute (DC 20)'),
      _t(name: "Weaver's Tools", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 1, weightLb: 5,
          utilizeDc: 10,
          utilizeDescription:
              'Mend a tear in clothing (DC 10), or sew a Tiny design (DC 10)'),
      _t(name: "Woodcarver's Tools", category: "Artisan's Tools",
          ability: 'Dexterity', costGp: 1, weightLb: 5,
          utilizeDc: 10,
          utilizeDescription: 'Carve a pattern in wood (DC 10)'),

      // ── Other Tools ───────────────────────────────────────────────
      _t(name: 'Disguise Kit', category: 'Other Tools',
          ability: 'Charisma', costGp: 25, weightLb: 3,
          utilizeDc: 10,
          utilizeDescription: 'Apply makeup (DC 10)'),
      _t(name: 'Forgery Kit', category: 'Other Tools',
          ability: 'Dexterity', costGp: 15, weightLb: 5,
          utilizeDc: 20,
          utilizeDescription:
              "Mimic the handwriting of someone else's (DC 15), or duplicate a wax seal (DC 20)"),
      _t(name: "Herbalism Kit", category: 'Other Tools',
          ability: 'Intelligence', costGp: 5, weightLb: 3,
          utilizeDc: 10,
          utilizeDescription: 'Identify a plant (DC 10)'),
      _t(name: "Navigator's Tools", category: 'Other Tools',
          ability: 'Wisdom', costGp: 25, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription:
              'Plot a course (DC 10), or determine position by stargazing (DC 15)'),
      _t(name: "Poisoner's Kit", category: 'Other Tools',
          ability: 'Intelligence', costGp: 50, weightLb: 2,
          utilizeDc: 10,
          utilizeDescription: 'Detect a poisoned object (DC 10)'),
      _t(name: "Thieves' Tools", category: 'Other Tools',
          ability: 'Dexterity', costGp: 25, weightLb: 1,
          utilizeDc: 15,
          utilizeDescription:
              'Pick a lock (DC 15), or disarm a trap (DC 15)'),

      // ── Gaming Set (variants of "Gaming Set" tool category) ───────
      // SRD 5.2.1 lists per-set price + describes the set; encode as a
      // single base "Gaming Set" plus typed variants for dice / cards /
      // three-dragon ante. variant_of_ref kept null on the base so the
      // schema's variant linkage is purely opt-in.
      _t(name: 'Gaming Set', category: 'Gaming Set',
          ability: 'Wisdom', costGp: 0, weightLb: 0,
          utilizeDc: 20,
          utilizeDescription:
              'Discern whether someone is cheating (DC 10), or win the game (DC 20)'),
      _t(name: 'Dice Set', category: 'Gaming Set',
          ability: 'Wisdom', costGp: 0.1, weightLb: 0,
          variantOf: 'Gaming Set'),
      _t(name: 'Dragonchess Set', category: 'Gaming Set',
          ability: 'Wisdom', costGp: 1, weightLb: 0.5,
          variantOf: 'Gaming Set'),
      _t(name: 'Playing Card Set', category: 'Gaming Set',
          ability: 'Wisdom', costGp: 0.5, weightLb: 0,
          variantOf: 'Gaming Set'),
      _t(name: 'Three-Dragon Ante Set', category: 'Gaming Set',
          ability: 'Wisdom', costGp: 1, weightLb: 0,
          variantOf: 'Gaming Set'),

      // ── Musical Instruments ───────────────────────────────────────
      _t(name: 'Bagpipes', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 30, weightLb: 6,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Drum', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 6, weightLb: 3,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Dulcimer', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 25, weightLb: 10,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Flute', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 2, weightLb: 1,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Horn', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 3, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Lute', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 35, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Lyre', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 30, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Pan Flute', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 12, weightLb: 2,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Shawm', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 2, weightLb: 1,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
      _t(name: 'Viol', category: 'Musical Instrument',
          ability: 'Charisma', costGp: 30, weightLb: 1,
          utilizeDc: 15,
          utilizeDescription: 'Play a known tune (DC 10), or improvise a song (DC 15)'),
    ];
