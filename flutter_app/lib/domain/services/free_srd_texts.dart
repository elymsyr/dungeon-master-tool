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

/// The Rules Glossary's conditions (A8, R4): what the dropped flags said,
/// and the rest of the rule.
const srdConditions = {
  'Blinded':
      'While you have the Blinded condition, you experience the following '
      'effects.\n\n'
      '**Can’t See.** You can’t see and automatically fail any ability check '
      'that requires sight.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage, and '
      'your attack rolls have Disadvantage.',
  'Charmed':
      'While you have the Charmed condition, you experience the following '
      'effects.\n\n'
      '**Can’t Harm the Charmer.** You can’t attack the charmer or target the '
      'charmer with damaging abilities or magical effects.\n\n'
      '**Social Advantage.** The charmer has Advantage on any ability check '
      'to interact with you socially.',
  'Deafened':
      'While you have the Deafened condition, you experience the following '
      'effect.\n\n'
      '**Can’t Hear.** You can’t hear and automatically fail any ability '
      'check that requires hearing.',
  'Exhaustion':
      'While you have the Exhaustion condition, you experience the following '
      'effects.\n\n'
      '**Exhaustion Levels.** This condition is cumulative. Each time you '
      'receive it, you gain 1 Exhaustion level. You die if your Exhaustion '
      'level is 6.\n\n'
      '**D20 Tests Affected.** When you make a D20 Test, the roll is reduced '
      'by 2 times your Exhaustion level.\n\n'
      '**Speed Reduced.** Your Speed is reduced by a number of feet equal to '
      '5 times your Exhaustion level.\n\n'
      '**Removing Exhaustion Levels.** Finishing a Long Rest removes 1 of '
      'your Exhaustion levels. When your Exhaustion level reaches 0, the '
      'condition ends.',
  'Frightened':
      'While you have the Frightened condition, you experience the following '
      'effects.\n\n'
      '**Ability Checks and Attacks Affected.** You have Disadvantage on '
      'ability checks and attack rolls while the source of fear is within '
      'line of sight.\n\n'
      '**Can’t Approach.** You can’t willingly move closer to the source of '
      'fear.',
  'Grappled':
      'While you have the Grappled condition, you experience the following '
      'effects.\n\n'
      '**Speed 0.** Your Speed is 0 and can’t increase.\n\n'
      '**Attacks Affected.** You have Disadvantage on attack rolls against '
      'any target other than the grappler.\n\n'
      '**Movable.** The grappler can drag or carry you when it moves, but '
      'every foot of movement costs it 1 extra foot unless you are Tiny or '
      'two or more sizes smaller than it.',
  'Incapacitated':
      'While you have the Incapacitated condition, you experience the '
      'following effects.\n\n'
      '**Inactive.** You can’t take any action, Bonus Action, or Reaction.'
      '\n\n'
      '**No Concentration.** Your Concentration is broken.\n\n'
      '**Speechless.** You can’t speak.\n\n'
      '**Surprised.** If you’re Incapacitated when you roll Initiative, you '
      'have Disadvantage on the roll.',
  'Invisible':
      'While you have the Invisible condition, you experience the following '
      'effects.\n\n'
      '**Surprise.** If you’re Invisible when you roll Initiative, you have '
      'Advantage on the roll.\n\n'
      '**Concealed.** You aren’t affected by any effect that requires its '
      'target to be seen unless the effect’s creator can somehow see you. Any '
      'equipment you are wearing or carrying is also concealed.\n\n'
      '**Attacks Affected.** Attack rolls against you have Disadvantage, and '
      'your attack rolls have Advantage. If a creature can somehow see you, '
      'you don’t gain this benefit against that creature.',
  'Paralyzed':
      'While you have the Paralyzed condition, you experience the following '
      'effects.\n\n'
      '**Incapacitated.** You have the Incapacitated condition.\n\n'
      '**Speed 0.** Your Speed is 0 and can’t increase.\n\n'
      '**Saving Throws Affected.** You automatically fail Strength and '
      'Dexterity saving throws.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage.\n\n'
      '**Automatic Critical Hits.** Any attack roll that hits you is a '
      'Critical Hit if the attacker is within 5 feet of you.',
  'Petrified':
      'While you have the Petrified condition, you experience the following '
      'effects.\n\n'
      '**Turned to Inanimate Substance.** You are transformed, along with any '
      'nonmagical objects you are wearing and carrying, into a solid '
      'inanimate substance (usually stone). Your weight increases by a factor '
      'of ten, and you cease aging.\n\n'
      '**Incapacitated.** You have the Incapacitated condition.\n\n'
      '**Speed 0.** Your Speed is 0 and can’t increase.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage.\n\n'
      '**Saving Throws Affected.** You automatically fail Strength and '
      'Dexterity saving throws.\n\n'
      '**Resist Damage.** You have Resistance to all damage.\n\n'
      '**Poison Immunity.** You have Immunity to the Poisoned condition.',
  'Poisoned':
      'While you have the Poisoned condition, you experience the following '
      'effect.\n\n'
      '**Ability Checks and Attacks Affected.** You have Disadvantage on '
      'attack rolls and ability checks.',
  'Prone':
      'While you have the Prone condition, you experience the following '
      'effects.\n\n'
      '**Restricted Movement.** Your only movement options are to crawl or to '
      'spend an amount of movement equal to half your Speed (round down) to '
      'right yourself and thereby end the condition. If your Speed is 0, you '
      'can’t right yourself.\n\n'
      '**Attacks Affected.** You have Disadvantage on attack rolls. An attack '
      'roll against you has Advantage if the attacker is within 5 feet of '
      'you. Otherwise, that attack roll has Disadvantage.',
  'Restrained':
      'While you have the Restrained condition, you experience the following '
      'effects.\n\n'
      '**Speed 0.** Your Speed is 0 and can’t increase.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage, and '
      'your attack rolls have Disadvantage.\n\n'
      '**Saving Throws Affected.** You have Disadvantage on Dexterity saving '
      'throws.',
  'Stunned':
      'While you have the Stunned condition, you experience the following '
      'effects.\n\n'
      '**Incapacitated.** You have the Incapacitated condition.\n\n'
      '**Saving Throws Affected.** You automatically fail Strength and '
      'Dexterity saving throws.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage.',
  'Unconscious':
      'While you have the Unconscious condition, you experience the following '
      'effects.\n\n'
      '**Inert.** You have the Incapacitated and Prone conditions, and you '
      'drop whatever you’re holding. When this condition ends, you remain '
      'Prone.\n\n'
      '**Speed 0.** Your Speed is 0 and can’t increase.\n\n'
      '**Attacks Affected.** Attack rolls against you have Advantage.\n\n'
      '**Saving Throws Affected.** You automatically fail Strength and '
      'Dexterity saving throws.\n\n'
      '**Automatic Critical Hits.** Any attack roll that hits you is a '
      'Critical Hit if the attacker is within 5 feet of you.\n\n'
      '**Unaware.** You’re unaware of your surroundings.',
};

/// The weapon properties (A8): "Properties" in "Equipment". The pack's
/// Improvised is no SRD property and has none.
const srdWeaponProperties = {
  'Ammunition':
      'You can use a weapon that has the Ammunition property to make a ranged '
      'attack only if you have ammunition to fire from it. The type of '
      'ammunition required is specified with the weapon’s range. Each attack '
      'expends one piece of ammunition. Drawing the ammunition is part of the '
      'attack (you need a free hand to load a one-handed weapon). After a '
      'fight, you can spend 1 minute to recover half the ammunition (round '
      'down) you used in the fight; the rest is lost.',
  'Finesse':
      'When making an attack with a Finesse weapon, use your choice of your '
      'Strength or Dexterity modifier for the attack and damage rolls. You '
      'must use the same modifier for both rolls.',
  'Heavy':
      'You have Disadvantage on attack rolls with a Heavy weapon if it’s a '
      'Melee weapon and your Strength score isn’t at least 13 or if it’s a '
      'Ranged weapon and your Dexterity score isn’t at least 13.',
  'Light':
      'When you take the Attack action on your turn and attack with a Light '
      'weapon, you can make one extra attack as a Bonus Action later on the '
      'same turn. That extra attack must be made with a different Light '
      'weapon, and you don’t add your ability modifier to the extra attack’s '
      'damage unless that modifier is negative. For example, you can attack '
      'with a Shortsword in one hand and a Dagger in the other using the '
      'Attack action and a Bonus Action, but you don’t add your Strength or '
      'Dexterity modifier to the damage roll of the Bonus Action unless that '
      'modifier is negative.',
  'Loading':
      'You can fire only one piece of ammunition from a Loading weapon when '
      'you use an action, a Bonus Action, or a Reaction to fire it, regardless '
      'of the number of attacks you can normally make.',
  'Range':
      'A Range weapon has a range in parentheses after the Ammunition or '
      'Thrown property. The range lists two numbers. The first is the '
      'weapon’s normal range in feet, and the second is the weapon’s long '
      'range. When attacking a target beyond normal range, you have '
      'Disadvantage on the attack roll. You can’t attack a target beyond the '
      'long range.',
  'Reach':
      'A Reach weapon adds 5 feet to your reach when you attack with it, as '
      'well as when determining your reach for Opportunity Attacks with it.',
  'Thrown':
      'If a weapon has the Thrown property, you can throw the weapon to make '
      'a ranged attack, and you can draw that weapon as part of the attack. '
      'If the weapon is a Melee weapon, use the same ability modifier for the '
      'attack and damage rolls that you use for a melee attack with that '
      'weapon.',
  'Two-Handed': 'A Two-Handed weapon requires two hands when you attack with '
      'it.',
  'Versatile':
      'A Versatile weapon can be used with one or two hands. A damage value '
      'in parentheses appears with the property. The weapon deals that damage '
      'when used with two hands to make a melee attack.',
};

/// The weapon mastery properties (A8): "Mastery Properties" in
/// "Equipment".
const srdWeaponMasteries = {
  'Cleave':
      'If you hit a creature with a melee attack roll using this weapon, you '
      'can make a melee attack roll with the weapon against a second creature '
      'within 5 feet of the first that is also within your reach. On a hit, '
      'the second creature takes the weapon’s damage, but don’t add your '
      'ability modifier to that damage unless that modifier is negative. You '
      'can make this extra attack only once per turn.',
  'Graze':
      'If your attack roll with this weapon misses a creature, you can deal '
      'damage to that creature equal to the ability modifier you used to make '
      'the attack roll. This damage is the same type dealt by the weapon, and '
      'the damage can be increased only by increasing the ability modifier.',
  'Nick':
      'When you make the extra attack of the Light property, you can make it '
      'as part of the Attack action instead of as a Bonus Action. You can '
      'make this extra attack only once per turn.',
  'Push':
      'If you hit a creature with this weapon, you can push the creature up '
      'to 10 feet straight away from yourself if it is Large or smaller.',
  'Sap':
      'If you hit a creature with this weapon, that creature has '
      'Disadvantage on its next attack roll before the start of your next '
      'turn.',
  'Slow':
      'If you hit a creature with this weapon and deal damage to it, you can '
      'reduce its Speed by 10 feet until the start of your next turn. If the '
      'creature is hit more than once by weapons that have this property, '
      'the Speed reduction doesn’t exceed 10 feet.',
  'Topple':
      'If you hit a creature with this weapon, you can force the creature to '
      'make a Constitution saving throw (DC 8 plus the ability modifier used '
      'to make the attack roll and your Proficiency Bonus). On a failed save, '
      'the creature has the Prone condition.',
  'Vex':
      'If you hit a creature with this weapon and deal damage to the '
      'creature, you have Advantage on your next attack roll against that '
      'creature before the end of your next turn.',
};

/// The lookup cards whose Effects the converter writes, by category.
const srdLookupEffects = {
  'armor-category': srdArmorDonDoff,
  'condition': srdConditions,
  'weapon-property': srdWeaponProperties,
  'weapon-mastery': srdWeaponMasteries,
};

/// "Starting at Higher Levels" in "Character Creation" (A8): the creation
/// guide's step in place of the Starter Bundle category.
const srdStartingAtHigherLevels =
    '**Starting at Higher Levels.** Your GM might start your group’s '
    'characters at a level higher than 1. It is particularly recommended to '
    'start at level 3 if your group is composed of seasoned D&D players.\n\n'
    'Creating a higher-level character uses the same character-creation '
    'steps outlined in this chapter and the rules for advancing beyond level '
    '1 provided in the “Level Advancement” section. You begin with the '
    'minimum amount of XP required to reach your starting level. For '
    'example, if the GM starts you at level 10, you have 64,000 XP.\n\n'
    'The GM decides whether your character starts with more than the '
    'standard equipment for a level 1 character, possibly even one or more '
    'magic items. The Starting Equipment at Higher Levels table is a guide '
    'for the GM.\n\n'
    '| Starting Level | Equipment and Money | Magic Items |\n'
    '|---|---|---|\n'
    '| 2–4 | Normal starting equipment | 1 Common |\n'
    '| 5–10 | 500 GP plus 1d10 × 25 GP plus normal starting equipment | '
    '1 Common, 1 Uncommon |\n'
    '| 11–16 | 5,000 gp plus 1d10 × 250 GP plus normal starting equipment | '
    '2 Common, 3 Uncommon, 1 Rare |\n'
    '| 17–20 | 20,000 GP plus 1d10 × 250 GP plus normal starting equipment | '
    '2 Common, 4 Uncommon, 3 Rare, 1 Very Rare |';
