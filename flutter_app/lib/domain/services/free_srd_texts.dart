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
