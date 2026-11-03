/// Texts the free SRD package takes word for word from the SRD 5.2.1 PDF
/// (docs/free-template/SRD-FREE-ALANLAR.md §8, K12): what the pack's data
/// does not hold. Keyed by the pack card's name.
library;

/// A species' Size line (A4): the height is in no field.
const srdSpeciesSizes = {
  'Dragonborn': 'Medium (about 5–7 feet tall)',
  'Dwarf': 'Medium (about 4–5 feet tall)',
  'Elf': 'Medium (about 5–6 feet tall)',
  'Gnome': 'Small (about 3–4 feet tall)',
  'Goliath': 'Medium (about 7–8 feet tall)',
  'Halfling': 'Small (about 2–3 feet tall)',
  'Human':
      'Medium (about 4–7 feet tall) or Small (about 2–4 feet tall), chosen '
      'when you select this species',
  'Orc': 'Medium (about 6–7 feet tall)',
  'Tiefling':
      'Medium (about 4–7 feet tall) or Small (about 3–4 feet tall), chosen '
      'when you select this species',
};

/// The species whose traits the SRD opens otherwise than "As a …, you have
/// these special traits."
const srdSpeciesTraitsIntros = {
  'Tiefling': 'As a Tiefling, you have the following special traits.',
};

/// The Level 1 cells of the Elven Lineages and Fiendish Legacies tables
/// (A4); the Level 3 and 5 cells are the spells themselves.
const srdLineageLevel1 = {
  'Drow':
      'The range of your Darkvision increases to 120 feet. You also know the '
      'Dancing Lights cantrip.',
  'High Elf':
      'You know the Prestidigitation cantrip. Whenever you finish a Long '
      'Rest, you can replace that cantrip with a different cantrip from the '
      'Wizard spell list.',
  'Wood Elf':
      'Your Speed increases to 35 feet. You also know the Druidcraft cantrip.',
  'Abyssal Tiefling':
      'You have Resistance to Poison damage. You also know the Poison Spray '
      'cantrip.',
  'Chthonic Tiefling':
      'You have Resistance to Necrotic damage. You also know the Chill Touch '
      'cantrip.',
  'Infernal Tiefling':
      'You have Resistance to Fire damage. You also know the Fire Bolt '
      'cantrip.',
};

/// The Core Traits lines (A5) the data cannot write in the SRD's words: a
/// primary ability of one or the other, a choice from a kind of tool.
const srdClassLines = {
  'Fighter': {'primary_ability': 'Strength or Dexterity'},
  'Bard': {
    'skill_proficiencies': 'Choose any 3 skills (see “Playing the Game”)',
    'tool_proficiencies': 'Choose 3 Musical Instruments (see “Equipment”)',
  },
  'Monk': {
    'tool_proficiencies':
        'Choose one type of Artisan’s Tools or Musical Instrument (see '
        '“Equipment”)',
  },
};

/// The first "As a Multiclass Character" line of each class's "Becoming
/// a …" box (A5); the box's other lines are the same in every class.
const srdClassMulticlass = {
  'Barbarian':
      'Gain the following traits from the Core Barbarian Traits table: Hit '
      'Point Die, proficiency with Martial weapons, and training with '
      'Shields.',
  'Bard':
      'Gain the following traits from the Core Bard Traits table: Hit Point '
      'Die, proficiency in one skill of your choice, proficiency with one '
      'Musical Instrument of your choice, and training with Light armor.',
  'Cleric':
      'Gain the following traits from the Core Cleric Traits table: Hit '
      'Point Die and training with Light and Medium armor and Shields.',
  'Druid':
      'Gain the following traits from the Core Druid Traits table: Hit '
      'Point Die and training with Light armor and Shields.',
  'Fighter':
      'Gain the following traits from the Core Fighter Traits table: Hit '
      'Point Die, proficiency with Martial weapons, and training with Light '
      'and Medium armor and Shields.',
  'Monk': 'Gain the Hit Point Die trait from the Core Monk Traits table.',
  'Paladin':
      'Gain the following traits from the Core Paladin Traits table: Hit '
      'Point Die, proficiency with Martial weapons, and training with Light '
      'and Medium armor and Shields.',
  'Ranger':
      'Gain the following traits from the Core Ranger Traits table: Hit '
      'Point Die, proficiency with Martial weapons, proficiency in one skill '
      'of your choice from the Ranger’s skill list, and training with Light '
      'and Medium armor and Shields.',
  'Rogue':
      'Gain the following traits from the Core Rogue Traits table: Hit '
      'Point Die, proficiency in one skill of your choice from the Rogue’s '
      'skill list, proficiency with Thieves’ Tools, and training with Light '
      'armor.',
  'Sorcerer': 'Gain the Hit Point Die from the Core Sorcerer Traits table.',
  'Warlock':
      'Gain the following traits from the Core Warlock Traits table: Hit '
      'Point Die and training with Light armor.',
  'Wizard': 'Gain the Hit Point Die from the Core Wizard Traits table.',
};

/// A background's Tool Proficiency line where the data holds a choice
/// (A5).
const srdBackgroundTools = {
  'Soldier': 'Choose one kind of Gaming Set (see “Equipment”)',
};

/// The line under each subclass's name (A5, S1).
const srdSubclassIntros = {
  'Path of the Berserker': 'Channel Rage into Violent Fury',
  'College of Lore': 'Plumb the Depths of Magical Knowledge',
  'Life Domain': 'Soothe the Hurts of the World',
  'Circle of the Land': 'Celebrate Connection to the Natural World',
  'Champion': 'Pursue Physical Excellence in Combat',
  'Warrior of the Open Hand': 'Master Unarmed Combat Techniques',
  'Oath of Devotion': 'Uphold the Ideals of Justice and Order',
  'Hunter': 'Protect Nature and People from Destruction',
  'Thief': 'Hunt for Treasure as a Classic Adventurer',
  'Draconic Sorcery': 'Breathe the Magic of Dragons',
  'Fiend Patron': 'Make a Deal with the Lower Planes',
  'Evoker': 'Create Explosive Elemental Effects',
};

/// A tool's Craft line (A7, S5): the pack holds no craftable items. The
/// tools without one craft nothing.
const srdToolCrafts = {
  "Alchemist's Supplies":
      'Acid, Alchemist’s Fire, Component Pouch, Oil, Paper, Perfume',
  "Brewer's Supplies": 'Antitoxin',
  "Calligrapher's Supplies": 'Ink, Spell Scroll',
  "Carpenter's Tools":
      'Club, Greatclub, Quarterstaff, Barrel, Chest, Ladder, Pole, Portable '
      'Ram, Torch',
  "Cartographer's Tools": 'Map',
  "Cobbler's Tools": 'Climber’s Kit',
  "Cook's Utensils": 'Rations',
  "Glassblower's Tools": 'Glass Bottle, Magnifying Glass, Spyglass, Vial',
  "Jeweler's Tools": 'Arcane Focus, Holy Symbol',
  "Leatherworker's Tools":
      'Sling, Whip, Hide Armor, Leather Armor, Studded Leather Armor, '
      'Backpack, Crossbow Bolt Case, Map or Scroll Case, Parchment, Pouch, '
      'Quiver, Waterskin',
  "Mason's Tools": 'Block and Tackle',
  "Painter's Supplies": 'Druidic Focus, Holy Symbol',
  "Potter's Tools": 'Jug, Lamp',
  "Smith's Tools":
      'Any Melee weapon (except Club, Greatclub, Quarterstaff, and Whip), '
      'Medium armor (except Hide), Heavy armor, Ball Bearings, Bucket, '
      'Caltrops, Chain, Crowbar, Firearm Bullets, Grappling Hook, Iron Pot, '
      'Iron Spikes, Sling Bullets',
  "Tinker's Tools":
      'Musket, Pistol, Bell, Bullseye Lantern, Flask, Hooded Lantern, '
      'Hunting Trap, Lock, Manacles, Mirror, Shovel, Signal Whistle, '
      'Tinderbox',
  "Weaver's Tools":
      'Padded Armor, Basket, Bedroll, Blanket, Fine Clothes, Net, Robe, '
      'Rope, Sack, String, Tent, Traveler’s Clothes',
  "Woodcarver's Tools":
      'Club, Greatclub, Quarterstaff, Ranged weapons (except Pistol, Musket, '
      'and Sling), Arcane Focus, Arrows, Bolts, Druidic Focus, Ink Pen, '
      'Needles',
  'Disguise Kit': 'Costume',
  "Poisoner's Kit": 'Basic Poison',
  'Herbalism Kit': 'Antitoxin, Candle, Healer’s Kit, Potion of Healing',
};

/// How long an armor category takes to don or doff (A7): the Armor
/// table's category headings.
const srdArmorDonDoff = {
  'Light': '1 Minute to Don or Doff',
  'Medium': '5 Minutes to Don and 1 Minute to Doff',
  'Heavy': '10 Minutes to Don and 5 Minutes to Doff',
  'Shield': 'Utilize Action to Don or Doff',
};
