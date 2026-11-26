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

/// The special senses in "Rules Glossary" (A9).
const srdSenses = {
  'Blindsight':
      'If you have Blindsight, you can see within a specific range without '
      'relying on physical sight. Within that range, you can see anything '
      'that isn’t behind Total Cover even if you have the Blinded condition '
      'or are in Darkness. Moreover, in that range, you can see something '
      'that has the Invisible condition.',
  'Darkvision':
      'If you have Darkvision, you can see in Dim Light within a specified '
      'range as if it were Bright Light and in Darkness within that range as '
      'if it were Dim Light. You discern colors in that Darkness only as '
      'shades of gray. See also “Playing the Game” (“Exploration”).',
  'Tremorsense':
      'A creature with Tremorsense can pinpoint the location of creatures and '
      'moving objects within a specific range, provided that the creature '
      'with Tremorsense and anything it is detecting are both in contact with '
      'the same surface (such as the ground, a wall, or a ceiling) or the '
      'same liquid.\n\n'
      'Tremorsense can’t detect creatures or objects in the air, and it '
      'doesn’t count as a form of sight.',
  'Truesight':
      'If you have Truesight, your vision is enhanced within a specified '
      'range. Within that range, your vision pierces through the '
      'following:\n\n'
      '**Darkness.** You can see in normal and magical Darkness.\n\n'
      '**Invisibility.** You see creatures and objects that have the '
      'Invisible condition.\n\n'
      '**Visual Illusions.** Visual illusions appear transparent to you, and '
      'you automatically succeed on saving throws against them.\n\n'
      '**Transformations.** You discern the true form of any creature or '
      'object you see that has been transformed by magic.\n\n'
      '**Ethereal Plane.** You see into the Ethereal Plane.',
};

/// The hazards in "Rules Glossary" (A9), with their tables.
const srdHazards = {
  'Burning':
      'A burning creature or object takes 1d4 Fire damage at the start of '
      'each of its turns. As an action, you can extinguish fire on yourself '
      'by giving yourself the Prone condition and rolling on the ground. The '
      'fire also goes out if it is doused, submerged, or suffocated.',
  'Dehydration':
      'A creature requires an amount of water per day based on its size, as '
      'shown in the Water Needs per Day table. A creature that drinks less '
      'than half the required water for a day gains 1 Exhaustion level at the '
      'day’s end. Exhaustion caused by dehydration can’t be removed until the '
      'creature drinks the full amount of water required for a day. See also '
      '“Exhaustion.”\n\n'
      '| Size | Water |\n'
      '|---|---|\n'
      '| Tiny | 1/4 gallon |\n'
      '| Small | 1 gallon |\n'
      '| Medium | 1 gallon |\n'
      '| Large | 4 gallons |\n'
      '| Huge | 16 gallons |\n'
      '| Gargantuan | 64 gallons |',
  'Falling':
      'A creature that falls takes 1d6 Bludgeoning damage at the end of the '
      'fall for every 10 feet it fell, to a maximum of 20d6. When the '
      'creature lands, it has the Prone condition unless it avoids taking any '
      'damage from the fall.\n\n'
      'A creature that falls into water or another liquid can use its '
      'Reaction to make a DC 15 Strength (Athletics) or Dexterity '
      '(Acrobatics) check to hit the surface head or feet first. On a '
      'successful check, any damage resulting from the fall is halved.',
  'Malnutrition':
      'A creature needs an amount of food per day based on its size, as shown '
      'in the Food Needs per Day table. A creature that eats but consumes '
      'less than half the required food for a day must succeed on a DC 10 '
      'Constitution saving throw or gain 1 Exhaustion level at the day’s end. '
      'A creature that eats nothing for 5 days automatically gains 1 '
      'Exhaustion level at the end of the fifth day as well as an additional '
      'level at the end of each subsequent day without food.\n\n'
      'Exhaustion caused by malnutrition can’t be removed until the creature '
      'eats the full amount of food required for a day. See also '
      '“Exhaustion.”\n\n'
      '| Size | Food |\n'
      '|---|---|\n'
      '| Tiny | 1/4 pound |\n'
      '| Small | 1 pound |\n'
      '| Medium | 1 pound |\n'
      '| Large | 4 pounds |\n'
      '| Huge | 16 pounds |\n'
      '| Gargantuan | 64 pounds |',
  'Suffocation':
      'A creature can hold its breath for a number of minutes equal to 1 plus '
      'its Constitution modifier (minimum of 30 seconds) before suffocation '
      'begins. When a creature runs out of breath or is choking, it gains 1 '
      'Exhaustion level at the end of each of its turns. When a creature can '
      'breathe again, it removes all levels of Exhaustion it gained from '
      'suffocating.',
};

/// The areas of effect in "Rules Glossary" (A9).
const srdAreaShapes = {
  'Cone':
      'A Cone is an area of effect that extends in straight lines from a '
      'point of origin in a direction its creator chooses. A Cone’s width at '
      'any point along its length is equal to that point’s distance from the '
      'point of origin. For example, a Cone is 15 feet wide at a point along '
      'its length that is 15 feet from the point of origin. The effect that '
      'creates a Cone specifies its maximum length.\n\n'
      'A Cone’s point of origin isn’t included in the area of effect unless '
      'its creator decides otherwise.',
  'Cube':
      'A Cube is an area of effect that extends in straight lines from a '
      'point of origin located anywhere on a face of the Cube. The effect '
      'that creates a Cube specifies its size, which is the length of each '
      'side.\n\n'
      'A Cube’s point of origin isn’t included in the area of effect unless '
      'its creator decides otherwise.',
  'Cylinder':
      'A Cylinder is an area of effect that extends in straight lines from a '
      'point of origin located at the center of the circular top or bottom of '
      'the Cylinder. The effect that creates a Cylinder specifies the radius '
      'of the Cylinder’s base and the Cylinder’s height.\n\n'
      'A Cylinder’s point of origin is included in the area of effect.',
  'Line':
      'A Line is an area of effect that extends from a point of origin in a '
      'straight path along its length and covers an area defined by its '
      'width. The effect that creates a Line specifies its length and '
      'width.\n\n'
      'A Line’s point of origin isn’t included in the area of effect unless '
      'its creator decides otherwise.',
  'Sphere':
      'A Sphere is an area of effect that extends in straight lines from a '
      'point of origin outward in all directions. The effect that creates a '
      'Sphere specifies the distance it extends as the radius of the '
      'Sphere.\n\n'
      'A Sphere’s point of origin is included in the Sphere’s area of effect.',
  'Emanation':
      'An Emanation is an area of effect that extends in straight lines from '
      'a creature or an object in all directions. The effect that creates an '
      'Emanation specifies the distance it extends.\n\n'
      'An Emanation moves with the creature or object that is its origin '
      'unless it is an instantaneous or a stationary effect.\n\n'
      'An Emanation’s origin (creature or object) isn’t included in the area '
      'of effect unless its creator decides otherwise.',
};

/// The attitudes in "Rules Glossary" (A9).
const srdAttitudes = {
  'Friendly':
      'A Friendly creature views you favorably. You have Advantage on an '
      'ability check to influence a Friendly creature. See also “Influence.”',
  'Indifferent':
      'An Indifferent creature has no desire to help or hinder you. '
      'Indifferent is the default attitude of a monster. See also “Influence.”',
  'Hostile':
      'A Hostile creature views you unfavorably. You have Disadvantage on an '
      'ability check to influence a Hostile creature. See also “Influence.”',
};

/// "Light" in "Exploration" (A9); the glossary only points there.
const srdIllumination = {
  'Bright':
      'Bright Light lets most creatures see normally. Even gloomy days '
      'provide Bright Light, as do torches, lanterns, fires, and other '
      'sources of illumination within a specific radius.',
  'Dim':
      'Dim Light, also called shadows, creates a Lightly Obscured area. An '
      'area of Dim Light is usually a boundary between Bright Light and '
      'surrounding Darkness. The soft light of twilight and dawn also counts '
      'as Dim Light. A full moon might bathe the land in Dim Light.',
  'Darkness':
      'Darkness creates a Heavily Obscured area. Characters face Darkness '
      'outdoors at night (even most moonlit nights), within the confines of '
      'an unlit dungeon, or in an area of magical Darkness.',
};

/// The actions in "Rules Glossary" (A9); Free Action has no SRD entry.
const srdActions = {
  'Action':
      'On your turn, you can take one action. Choose which action to take '
      'from those below or from the special actions provided by your '
      'features. See also “Playing the Game” (“Actions”). These actions are '
      'defined elsewhere in this glossary:\n\n'
      '- Attack\n'
      '- Dash\n'
      '- Disengage\n'
      '- Dodge\n'
      '- Help\n'
      '- Hide\n'
      '- Influence\n'
      '- Magic\n'
      '- Ready\n'
      '- Search\n'
      '- Study\n'
      '- Utilize',
  'Bonus Action':
      'A Bonus Action is a special action that you can take on the same turn '
      'that you take an action. You can’t take more than one Bonus Action on '
      'a turn, and you have a Bonus Action to take only if a rule explicitly '
      'says so. See also “Playing the Game” (“Actions”).',
  'Reaction':
      'A Reaction is a special action taken in response to a trigger defined '
      'in the Reaction’s description. You can take a Reaction on another '
      'creature’s turn, and if you take it on your turn, you can do so even '
      'if you also take an action, a Bonus Action, or both. Once you take a '
      'Reaction, you can’t take another one until the start of your next '
      'turn. The Opportunity Attack is a Reaction available to all creatures. '
      'See also “Opportunity Attacks” and “Playing the Game” (“Actions”).',
  'Magic Action':
      'When you take the Magic action, you cast a spell that has a casting '
      'time of an action or use a feature or magic item that requires a Magic '
      'action to be activated.\n\n'
      'If you cast a spell that has a casting time of 1 minute or longer, you '
      'must take the Magic action on each turn of that casting, and you must '
      'maintain Concentration while you do so. If your Concentration is '
      'broken, the spell fails, but you don’t expend a spell slot. See also '
      '“Concentration.”',
  'Attack Action':
      'When you take the Attack action, you can make one attack roll with a '
      'weapon or an Unarmed Strike.\n\n'
      '**Equipping and Unequipping Weapons.** You can either equip or unequip '
      'one weapon when you make an attack as part of this action. You do so '
      'either before or after the attack. If you equip a weapon before an '
      'attack, you don’t need to use it for that attack. Equipping a weapon '
      'includes drawing it from a sheath or picking it up. Unequipping a '
      'weapon includes sheathing, stowing, or dropping it.\n\n'
      '**Moving between Attacks.** If you move on your turn and have a '
      'feature, such as Extra Attack, that gives you more than one attack as '
      'part of the Attack action, you can use some or all of that movement to '
      'move between those attacks.',
  'Dash':
      'When you take the Dash action, you gain extra movement for the current '
      'turn. The increase equals your Speed after applying any modifiers. '
      'With a Speed of 30 feet, for example, you can move up to 60 feet on '
      'your turn if you Dash. If your Speed of 30 feet is reduced to 15 feet, '
      'you can move up to 30 feet this turn if you Dash.\n\n'
      'If you have a special speed, such as a Fly Speed or Swim Speed, you '
      'can use that speed instead of your Speed when you take this action. '
      'You choose which speed to use each time you take it. See also “Speed.”',
  'Dodge':
      'If you take the Dodge action, you gain the following benefits: until '
      'the start of your next turn, any attack roll made against you has '
      'Disadvantage if you can see the attacker, and you make Dexterity '
      'saving throws with Advantage.\n\n'
      'You lose these benefits if you have the Incapacitated condition or if '
      'your Speed is 0.',
  'Disengage':
      'If you take the Disengage action, your movement doesn’t provoke '
      'Opportunity Attacks for the rest of the current turn.',
  'Help':
      'When you take the Help action, you do one of the following.\n\n'
      '**Assist an Ability Check.** Choose one of your skill or tool '
      'proficiencies and one ally who is near enough for you to assist '
      'verbally or physically when they make an ability check. That ally has '
      'Advantage on the next ability check they make with the chosen skill or '
      'tool. This benefit expires if the ally doesn’t use it before the start '
      'of your next turn. The GM has final say on whether your assistance is '
      'possible.\n\n'
      '**Assist an Attack Roll.** You momentarily distract an enemy within 5 '
      'feet of you, giving Advantage to the next attack roll by one of your '
      'allies against that enemy. This benefit expires at the start of your '
      'next turn.',
  'Hide':
      'With the Hide action, you try to hide yourself. To do so, you must '
      'succeed on a DC 15 Dexterity (Stealth) check while you’re Heavily '
      'Obscured or behind Three-Quarters Cover or Total Cover, and you must '
      'be out of any enemy’s line of sight; if you can see a creature, you '
      'can discern whether it can see you.\n\n'
      'On a successful check, you have the Invisible condition while hidden. '
      'Make note of your check’s total, which is the DC for a creature to '
      'find you with a Wisdom (Perception) check.\n\n'
      'You stop being hidden immediately after any of the following occurs: '
      'you make a sound louder than a whisper, an enemy finds you, you make '
      'an attack roll, or you cast a spell with a Verbal component.',
  'Ready':
      'You take the Ready action to wait for a particular circumstance before '
      'you act. To do so, you take this action on your turn, which lets you '
      'act by taking a Reaction before the start of your next turn.\n\n'
      'First, you decide what perceivable circumstance will trigger your '
      'Reaction. Then, you choose the action you will take in response to '
      'that trigger, or you choose to move up to your Speed in response to '
      'it. Examples include “If the cultist steps on the trapdoor, I’ll pull '
      'the lever that opens it,” and “If the zombie steps next to me, I move '
      'away.”\n\n'
      'When the trigger occurs, you can either take your Reaction right after '
      'the trigger finishes or ignore the trigger.\n\n'
      'When you Ready a spell, you cast it as normal (expending any resources '
      'used to cast it) but hold its energy, which you release with your '
      'Reaction when the trigger occurs. To be readied, a spell must have a '
      'casting time of an action, and holding on to the spell’s magic '
      'requires Concentration, which you can maintain up to the start of your '
      'next turn. If your Concentration is broken, the spell dissipates '
      'without taking effect.',
  'Search':
      'When you take the Search action, you make a Wisdom check to discern '
      'something that isn’t obvious. The Search table suggests which skills '
      'are applicable when you take this action, depending on what you’re '
      'trying to detect.\n\n'
      '| Skill | Thing to Detect |\n'
      '|---|---|\n'
      '| Insight | Creature’s state of mind |\n'
      '| Medicine | Creature’s ailment or cause of death |\n'
      '| Perception | Concealed creature or object |\n'
      '| Survival | Tracks or food |',
  'Influence':
      'With the Influence action, you urge a monster to do something. '
      'Describe or roleplay how you’re communicating with the monster. Are '
      'you trying to deceive, intimidate, amuse, or gently persuade? The GM '
      'then determines whether the monster feels willing, unwilling, or '
      'hesitant due to your interaction; this determination establishes '
      'whether an ability check is necessary, as explained below.\n\n'
      '**Willing.** If your urging aligns with the monster’s desires, no '
      'ability check is necessary; the monster fulfills your request in a way '
      'it prefers.\n\n'
      '**Unwilling.** If your urging is repugnant to the monster or counter '
      'to its alignment, no ability check is necessary; it doesn’t comply.\n\n'
      '**Hesitant.** If you urge the monster to do something that it is '
      'hesitant to do, you must make an ability check, which is affected by '
      'the monster’s attitude: Indifferent, Friendly, or Hostile, each of '
      'which is defined in this glossary. The Influence Checks table suggests '
      'which ability check to make based on how you’re interacting with the '
      'monster. The GM chooses the check, which has a default DC equal to 15 '
      'or the monster’s Intelligence score, whichever is higher. On a '
      'successful check, the monster does as urged. On a failed check, you '
      'must wait 24 hours (or a duration set by the GM) before urging it in '
      'the same way again.\n\n'
      '| Ability Check | Interaction |\n'
      '|---|---|\n'
      '| Charisma (Deception) | Deceiving a monster that understands you |\n'
      '| Charisma (Intimidation) | Intimidating a monster |\n'
      '| Charisma (Performance) | Amusing a monster |\n'
      '| Charisma (Persuasion) | Persuading a monster that understands you |\n'
      '| Wisdom (Animal Handling) | Gently coaxing a Beast or Monstrosity |',
  'Study':
      'When you take the Study action, you make an Intelligence check to '
      'study your memory, a book, a clue, or another source of knowledge and '
      'call to mind an important piece of information about it.\n\n'
      'The Areas of Knowledge table suggests which skills are applicable to '
      'various areas of knowledge.\n\n'
      '| Skill | Areas |\n'
      '|---|---|\n'
      '| Arcana | Spells, magic items, eldritch symbols, magical traditions, '
      'planes of existence, and certain creatures (Aberrations, Constructs, '
      'Elementals, Fey, and Monstrosities) |\n'
      '| History | Historic events and people, ancient civilizations, wars, '
      'and certain creatures (Giants and Humanoids) |\n'
      '| Investigation | Traps, ciphers, riddles, and gadgetry |\n'
      '| Nature | Terrain, flora, weather, and certain creatures (Beasts, '
      'Dragons, Oozes, and Plants) |\n'
      '| Religion | Deities, religious hierarchies and rites, holy symbols, '
      'cults, and certain creatures (Celestials, Fiends, and Undead) |',
  'Utilize':
      'You normally interact with an object while doing something else, such '
      'as when you draw a sword as part of the Attack action. When an object '
      'requires an action for its use, you take the Utilize action.',
};

/// The speeds in "Rules Glossary" (A9); Walk is its "Speed" entry.
const srdSpeeds = {
  'Walk':
      'A creature has a Speed, which is the distance in feet the creature can '
      'cover when it moves on its turn. See also “Climbing,” “Crawling,” '
      '“Flying,” “Jumping,” “Swimming” and “Playing the Game” (“Combat”).\n\n'
      '**Special Speeds.** Some creatures have special speeds, such as a '
      'Burrow Speed, Climb Speed, Fly Speed, or Swim Speed, each of which is '
      'defined in this glossary. If you have more than one speed, choose '
      'which one to use when you move; you can switch between the speeds '
      'during your move. Whenever you switch, subtract the distance already '
      'moved from the new speed. The result determines how much farther you '
      'can move. If the result is 0 or less, you can’t use the new speed '
      'during the current move. For example, if you have a Speed of 30 and a '
      'Fly Speed of 40, you could fly 10 feet, walk 10 feet, and leap into '
      'the air to fly 20 feet more.\n\n'
      '**Changes to Your Speeds.** If an effect increases or decreases your '
      'Speed for a time, any special speed you have increases or decreases by '
      'an equal amount for the same duration. For example, if your Speed is '
      'reduced to 0 and you have a Climb Speed, your Climb Speed is also '
      'reduced to 0. Similarly, if your Speed is halved and you have a Fly '
      'Speed, your Fly Speed is also halved.',
  'Burrow':
      'A creature that has a Burrow Speed can use that speed to move through '
      'sand, earth, mud, or ice. The creature can’t burrow through solid rock '
      'unless the creature has a trait that allows it to do so. See also '
      '“Speed.”',
  'Climb':
      'A Climb Speed can be used in place of Speed to traverse a vertical '
      'surface without expending the extra movement normally associated with '
      'climbing. See also “Climbing” and “Speed.”',
  'Fly':
      'A Fly Speed can be used to travel through the air. While you have a '
      'Fly Speed, you can stay aloft until you land, fall, or die. See also '
      '“Flying” and “Speed.”',
  'Swim':
      'A Swim Speed can be used to swim without expending the extra movement '
      'normally associated with swimming. See also “Swimming” and “Speed.”',
};

/// The Cover table's rows, in "Combat" (A9).
const srdCover = {
  'Half Cover':
      '| Benefit to Target | Offered By … |\n'
      '|---|---|\n'
      '| +2 bonus to AC and Dexterity saving throws | Another creature or an '
      'object that covers at least half of the target |',
  'Three-Quarters Cover':
      '| Benefit to Target | Offered By … |\n'
      '|---|---|\n'
      '| +5 bonus to AC and Dexterity saving throws | An object that covers '
      'at least three-quarters of the target |',
  'Total Cover':
      '| Benefit to Target | Offered By … |\n'
      '|---|---|\n'
      '| Can’t be targeted directly | An object that covers the whole target |',
};

/// The Travel Pace table's rows and each pace's effect (A9).
const srdTravelPaces = {
  'Fast':
      '| Minute | Hour | Day |\n'
      '|---|---|---|\n'
      '| 400 feet | 4 miles | 30 miles |\n\n'
      'Traveling at a Fast pace imposes Disadvantage on a traveler’s Wisdom '
      '(Perception or Survival) and Dexterity (Stealth) checks.',
  'Normal':
      '| Minute | Hour | Day |\n'
      '|---|---|---|\n'
      '| 300 feet | 3 miles | 24 miles |\n\n'
      'Traveling at a Normal pace imposes Disadvantage on Dexterity (Stealth) '
      'checks.',
  'Slow':
      '| Minute | Hour | Day |\n'
      '|---|---|---|\n'
      '| 200 feet | 2 miles | 18 miles |\n\n'
      'Traveling at a Slow pace grants Advantage on Wisdom (Perception or '
      'Survival) checks.',
};

/// "The Nine Alignments" and "Unaligned Creatures" (A9).
const srdAlignments = {
  'Lawful Good':
      'Lawful Good creatures endeavor to do the right thing as expected by '
      'society. Someone who fights injustice and protects the innocent '
      'without hesitation is probably Lawful Good.',
  'Neutral Good':
      'Neutral Good creatures do the best they can, working within rules but '
      'not feeling bound by them. A kindly person who helps others according '
      'to their needs is probably Neutral Good.',
  'Chaotic Good':
      'Chaotic Good creatures act as their conscience directs with little '
      'regard for what others expect. A rebel who waylays a cruel baron’s tax '
      'collectors and uses the stolen money to help the poor is probably '
      'Chaotic Good.',
  'Lawful Neutral':
      'Lawful Neutral individuals act in accordance with law, tradition, or '
      'personal codes. Someone who follows a disciplined rule of life—and '
      'isn’t swayed either by the demands of those in need or by the '
      'temptations of evil—is probably Lawful Neutral.',
  'Neutral':
      'Neutral is the alignment of those who prefer to avoid moral questions '
      'and don’t take sides, doing what seems best at the time. Someone who’s '
      'bored by moral debate is probably Neutral.',
  'Chaotic Neutral':
      'Chaotic Neutral creatures follow their whims, valuing their personal '
      'freedom above all else. A scoundrel who wanders the land living by '
      'their wits is probably Chaotic Neutral.',
  'Lawful Evil':
      'Lawful Evil creatures methodically take what they want within the '
      'limits of a code of tradition, loyalty, or order. An aristocrat '
      'exploiting citizens while scheming for power is probably Lawful Evil.',
  'Neutral Evil':
      'Neutral Evil is the alignment of those who are untroubled by the harm '
      'they cause as they pursue their desires. A criminal who robs and '
      'murders as they please is probably Neutral Evil.',
  'Chaotic Evil':
      'Chaotic Evil creatures act with arbitrary violence, spurred by their '
      'hatred or bloodlust. A villain pursuing schemes of vengeance and havoc '
      'is probably Chaotic Evil.',
  'Unaligned':
      'Most creatures that lack the capacity for rational thought don’t have '
      'alignments; they are unaligned. Sharks are savage predators, for '
      'example, but they aren’t evil; they are unaligned.',
};

/// Each category's rules in "Magic Item Categories" (A9).
const srdMagicItemCategories = {
  'Armor':
      'An item in the Armor category is typically a magical version of armor '
      'from “Equipment.” Unless an armor’s description notes otherwise, the '
      'armor must be worn for its magic to function.\n\n'
      'Some suits of magic armor specify the type of armor they are, such as '
      'Chain Mail or Plate Armor. If no type is specified, choose the type or '
      'determine it randomly.',
  'Potions':
      'An item in the Potion category might be a magical brew that must be '
      'imbibed or an oil that must be applied to a creature or an object. A '
      'typical potion consists of 1 ounce of liquid in a vial.\n\n'
      '**Using a Potion.** Potions are consumable items. Drinking a potion or '
      'administering it to another creature requires a Bonus Action. Applying '
      'an oil might take longer as specified in its description. Once used, a '
      'potion takes effect immediately, and it is used up.\n\n'
      '**Mixing Potions.** A character might drink one potion while still '
      'under the effects of another or pour several potions into a single '
      'container. The strange ingredients used in creating potions can result '
      'in unpredictable interactions.\n\n'
      'When a character mixes two potions together, roll on the Potion '
      'Miscibility table. If more than two are combined, roll again for each '
      'subsequent potion, combining the results. Unless the effects are '
      'immediately obvious, reveal them only when they become evident.\n\n'
      '| 1d100 | Result |\n'
      '|---|---|\n'
      '| 01 | Both potions lose their effects, and the mixture creates a '
      'magical explosion in a 5-foot-radius Sphere centered on itself. Each '
      'creature in that area takes 4d10 Force damage. |\n'
      '| 02–08 | Both potions lose their effects, and the mixture becomes an '
      'ingested poison of your choice (see “Poison” in “Gameplay Toolbox”). '
      '|\n'
      '| 09–15 | Both potions lose their effects. |\n'
      '| 16–25 | One potion loses its effect. |\n'
      '| 26–35 | Both potions work, but with their numerical effects and '
      'durations halved. If a potion has no numerical effect and no duration, '
      'it instead loses its effect. |\n'
      '| 36–90 | Both potions work normally. |\n'
      '| 91–99 | Both potions work, but the numerical effects and duration of '
      'one potion are doubled. If neither potion has anything to double in '
      'this way, they work normally. |\n'
      '| 00 | Only one potion works, but its effects are permanent. Choose '
      'the simplest effect to make permanent or the one that seems the most '
      'fun. For example, a Potion of Healing might increase the drinker’s Hit '
      'Point maximum by 2d4 + 2, or a Potion of Invisibility might give the '
      'drinker the Invisible condition indefinitely. At your discretion, a '
      'Dispel Magic spell or similar magic might end this lasting effect. |',
  'Rings':
      'For its magic to function, an item in the Ring category must be worn '
      'on a finger or a similar digit unless its description notes otherwise.',
  'Rods':
      'An item in the Rod category is a scepter usually made of metal, wood, '
      'or bone. A typical rod weighs 2 to 5 pounds.\n\n'
      'Unless its description notes otherwise, a rod can be used as an Arcane '
      'Focus.',
  'Scrolls':
      'An item in the Scroll category is a roll of paper or parchment, '
      'sometimes attached to wooden rods and typically kept safe in a tube of '
      'ivory, jade, leather, metal, or wood. The most prevalent scroll is the '
      'Spell Scroll, a spell stored in written form.\n\n'
      '**Using a Scroll.** Scrolls are consumable items. Unleashing the magic '
      'in a scroll requires the user to read the scroll. When its magic has '
      'been invoked, the scroll can’t be used again. Its words fade, or it '
      'crumbles into dust.\n\n'
      'Any creature that can understand a written language can read a scroll '
      'and attempt to activate it unless its description notes otherwise.',
  'Staffs':
      'Items in the Staff category vary widely in appearance: some are of '
      'nearly equal diameter throughout and smooth, others are gnarled and '
      'twisted, some are made of wood, and others are composed of polished '
      'metal or crystal. A staff weighs between 2 and 7 pounds and serves '
      'well as a walking stick or cane.\n\n'
      'Unless its description notes otherwise, a staff can be used as a '
      'nonmagical Quarterstaff and an Arcane Focus.',
  'Wands':
      'An item in the Wand category is typically 12 to 15 inches long and '
      'crafted of metal, bone, or wood. It is tipped with metal, crystal, '
      'stone, or some other material.\n\n'
      'Unless its description notes otherwise, a wand can be used as an '
      'Arcane Focus.',
  'Weapons':
      'A magic weapon is typically a magical version of a weapon from '
      '“Equipment.” Some magic weapons specify the type of weapon they are in '
      'their descriptions, such as a Longsword or Longbow. If no weapon type '
      'is specified, you may choose the type or determine it randomly.\n\n'
      '**Ammunition.** If a magic weapon has the Ammunition property, '
      'ammunition fired from it is considered magical for the purpose of any '
      'rule that cares whether a weapon is magical or not.',
  'Wondrous Items':
      'Wondrous Items include wearable items such as boots, belts, capes, '
      'amulets, brooches, and circlets. Bags, carpets, figurines, horns, '
      'musical instruments, and more also fall into this category.',
};

/// "Lifestyle Expenses" (A9); the cost is the card's own field.
const srdLifestyles = {
  'Wretched':
      'You survive via chance and charity. You’re often exposed to natural '
      'dangers as a result of sleeping outside.',
  'Squalid':
      'You spend the bare minimum for your necessities. You might be exposed '
      'to unhealthy conditions and opportunistic criminals.',
  'Poor': 'You spend frugally for your necessities.',
  'Modest': 'You support yourself at an average level.',
  'Comfortable':
      'You spend modestly for your necessities and enjoy a few luxuries.',
  'Wealthy':
      'You’re accustomed to the finer things in life and might have servants.',
  'Aristocratic':
      'You pay for the best and might have a staff that supports your '
      'lifestyle. Others notice your wealth and might encourage you to share '
      'it, either legally or otherwise.',
};

/// "Tiers of Play" (A9): the cards keep their names; the SRD heading leads.
const srdTiersOfPlay = {
  'Local Heroes':
      '**Tier 1 (Levels 1–4)**\n\n'
      'In tier 1, characters are apprentice adventurers, though they are '
      'already set apart from the broader populace by virtue of their '
      'extraordinary abilities. They learn their starting class features and '
      'choose a subclass. The threats they face usually pose a danger to '
      'local farmsteads or villages.',
  'Heroes of the Realm':
      '**Tier 2 (Levels 5–10)**\n\n'
      'In tier 2, characters are full-fledged adventurers. Spellcasters gain '
      'iconic spells such as Fireball, Lightning Bolt, and Raise Dead. Most '
      'weapon-focused classes gain the ability to make multiple attacks in a '
      'round. The characters now face dangers that threaten cities and '
      'kingdoms.',
  'Masters of the Realm':
      '**Tier 3 (Levels 11–16)**\n\n'
      'In tier 3, characters have reached a level of power that makes them '
      'special among adventurers. At level 11, many spellcasters learn '
      'reality-altering spells. Other characters gain features that allow '
      'them to make more attacks or to do more impressive things with those '
      'attacks. These adventurers often confront threats to whole regions.',
  'Masters of the World':
      '**Tier 4 (Levels 17–20)**\n\n'
      'At tier 4, characters achieve the pinnacle of their class features, '
      'becoming heroic archetypes. The fate of the world or even the order of '
      'the multiverse might hang in the balance during their adventures.',
};

/// The Ability Descriptions table's "Score Measures …" column (A9).
const srdAbilityMeasures = {
  'Strength': 'Physical might',
  'Dexterity': 'Agility, reflexes, and balance',
  'Constitution': 'Health and stamina',
  'Intelligence': 'Reasoning and memory',
  'Wisdom': 'Perceptiveness and mental fortitude',
  'Charisma': 'Confidence, poise, and charm',
};

/// The Skills table's "Example Uses" column (A9).
const srdSkillUses = {
  'Acrobatics':
      'Stay on your feet in a tricky situation, or perform an acrobatic stunt.',
  'Animal Handling':
      'Calm or train an animal, or get an animal to behave in a certain way.',
  'Arcana':
      'Recall lore about spells, magic items, and the planes of existence.',
  'Athletics':
      'Jump farther than normal, stay afloat in rough water, or break '
      'something.',
  'Deception': 'Tell a convincing lie, or wear a disguise convincingly.',
  'History':
      'Recall lore about historical events, people, nations, and cultures.',
  'Insight': 'Discern a person’s mood and intentions.',
  'Intimidation': 'Awe or threaten someone into doing what you want.',
  'Investigation':
      'Find obscure information in books, or deduce how something works.',
  'Medicine':
      'Diagnose an illness, or determine what killed the recently slain.',
  'Nature': 'Recall lore about terrain, plants, animals, and weather.',
  'Perception':
      'Using a combination of senses, notice something that’s easy to miss.',
  'Performance': 'Act, tell a story, perform music, or dance.',
  'Persuasion': 'Honestly and graciously convince someone of something.',
  'Religion': 'Recall lore about gods, religious rituals, and holy symbols.',
  'Sleight of Hand':
      'Pick a pocket, conceal a handheld object, or perform legerdemain.',
  'Stealth': 'Escape notice by moving quietly and hiding behind things.',
  'Survival': 'Follow tracks, forage, find a trail, or avoid natural hazards.',
};

/// The Schools of Magic table's "Typical Effects" column (A9).
const srdSchoolEffects = {
  'Abjuration': 'Prevents or reverses harmful effects',
  'Conjuration': 'Transports creatures or objects',
  'Divination': 'Reveals information',
  'Enchantment': 'Influences minds',
  'Evocation': 'Channels energy to create effects that are often destructive',
  'Illusion': 'Deceives the mind or senses',
  'Necromancy': 'Manipulates life and death',
  'Transmutation': 'Transforms creatures or objects',
};

/// The Trinkets table in "Character Creation" (A9): row n is the card
/// for a d100 roll of n (00 is 100).
const srdTrinkets = [
  'A mummified goblin hand',
  'A crystal that faintly glows in moonlight',
  'A gold coin minted in an unknown land',
  'A diary written in a language you don’t know',
  'A brass ring that never tarnishes',
  'An old chess piece made from glass',
  'A pair of knucklebone dice, each with a skull symbol on the side that '
      'would normally show six pips',
  'A small idol depicting a nightmarish creature that gives you '
      'unsettling dreams when you sleep near it',
  'A lock of someone’s hair',
  'The deed for a parcel of land in a realm unknown to you',
  'A 1-ounce block made from an unknown material',
  'A small cloth doll skewered with needles',
  'A tooth from an unknown beast',
  'An enormous scale, perhaps from a dragon',
  'A bright-green feather',
  'An old divination card bearing your likeness',
  'A glass orb filled with moving smoke',
  'A 1-pound egg with a bright-red shell',
  'A pipe that blows bubbles',
  'A glass jar containing a bit of flesh floating in pickling fluid',
  'A gnome-crafted music box that plays a song you dimly remember from '
      'your childhood',
  'A wooden statuette of a smug halfling',
  'A brass orb etched with strange runes',
  'A multicolored stone disk',
  'A silver icon of a raven',
  'A bag containing forty-seven teeth, one of which is rotten',
  'A shard of obsidian that always feels warm to the touch',
  'A dragon’s talon strung on a leather necklace',
  'A pair of old socks',
  'A blank book whose pages refuse to hold ink, chalk, graphite, or any '
      'other marking',
  'A silver badge that is a five-pointed star',
  'A knife that belonged to a relative',
  'A glass vial filled with nail clippings',
  'A rectangular metal device with two tiny metal cups on one end that '
      'throws sparks when wet',
  'A white, sequined glove sized for a human',
  'A vest with one hundred tiny pockets',
  'A weightless stone',
  'A sketch of a goblin',
  'An empty glass vial that smells of perfume',
  'A gemstone that looks like a lump of coal when examined by anyone but you',
  'A scrap of cloth from an old banner',
  'A rank insignia from a lost legionnaire',
  'A silver bell without a clapper',
  'A mechanical canary inside a lamp',
  'A miniature chest carved to look like it has numerous feet on the bottom',
  'A dead sprite inside a clear glass bottle',
  'A metal can that has no opening but sounds as if it is filled with '
      'liquid, sand, spiders, or broken glass (your choice)',
  'A glass orb filled with water, in which swims a clockwork goldfish',
  'A silver spoon with an M engraved on the handle',
  'A whistle made from gold-colored wood',
  'A dead scarab beetle the size of your hand',
  'Two toy soldiers, one missing a head',
  'A small box filled with different-sized buttons',
  'A candle that can’t be lit',
  'A miniature cage with no door',
  'An old key',
  'An indecipherable treasure map',
  'A hilt from a broken sword',
  'A rabbit’s foot',
  'A glass eye',
  'A cameo of a hideous person',
  'A silver skull the size of a coin',
  'An alabaster mask',
  'A cone of sticky black incense that stinks',
  'A nightcap that gives you pleasant dreams when you wear it',
  'A single caltrop made from bone',
  'A gold monocle frame without the lens',
  'A 1-inch cube, each side a different color',
  'A crystal doorknob',
  'A packet filled with pink dust',
  'A fragment of a beautiful song, written as musical notes on two pieces '
      'of parchment',
  'A silver teardrop earring containing a real teardrop',
  'An eggshell painted with scenes of misery in disturbing detail',
  'A fan that, when unfolded, shows a sleepy cat',
  'A set of bone pipes',
  'A four-leaf clover pressed inside a book discussing manners and etiquette',
  'A sheet of parchment upon which is drawn a mechanical contraption',
  'An ornate scabbard that fits no blade you have found',
  'An invitation to a party where a murder happened',
  'A bronze pentacle with an etching of a rat’s head in its center',
  'A purple handkerchief embroidered with the name of an archmage',
  'Half a floor plan for a temple, a castle, or another structure',
  'A bit of folded cloth that, when unfolded, turns into a stylish cap',
  'A receipt of deposit at a bank in a far-off city',
  'A diary with seven missing pages',
  'An empty silver snuffbox bearing the inscription “dreams” on its lid',
  'An iron holy symbol devoted to an unknown god',
  'A book about a legendary hero’s rise and fall, with the last chapter '
      'missing',
  'A vial of dragon blood',
  'An ancient arrow of elven design',
  'A needle that never bends',
  'An ornate brooch of dwarven design',
  'An empty wine bottle bearing a pretty label that says, “The Wizard of '
      'Wines Winery, Red Dragon Crush, 331422-W”',
  'A mosaic tile with a multicolored, glazed surface',
  'A petrified mouse',
  'A black pirate flag adorned with a dragon’s skull and crossbones',
  'A tiny mechanical crab or spider that moves about when it’s not being '
      'observed',
  'A glass jar containing lard with a label that reads, “Griffon Grease”',
  'A wooden box with a ceramic bottom that holds a living worm with a '
      'head on each end of its body',
  'A metal urn containing the ashes of a hero',
];

/// The lookup cards whose Effects the converter writes, by category.
const srdLookupEffects = {
  'armor-category': srdArmorDonDoff,
  'condition': srdConditions,
  'weapon-property': srdWeaponProperties,
  'weapon-mastery': srdWeaponMasteries,
  'sense': srdSenses,
  'hazard': srdHazards,
  'area-shape': srdAreaShapes,
  'attitude': srdAttitudes,
  'illumination': srdIllumination,
  'action': srdActions,
  'speed-type': srdSpeeds,
  'cover': srdCover,
  'travel-pace': srdTravelPaces,
  'alignment': srdAlignments,
  'magic-item-category': srdMagicItemCategories,
  'lifestyle': srdLifestyles,
  'tier-of-play': srdTiersOfPlay,
};

/// The lookup cards whose Summary is an SRD table's column (A9), in place
/// of the core pack's own summaries.
const srdLookupSummaries = {
  'ability': srdAbilityMeasures,
  'skill': srdSkillUses,
  'spell-school': srdSchoolEffects,
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
