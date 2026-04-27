// SRD 5.2.1 Magic Items A–Z (pp. 209–253). The full SRD ships ~150 items;
// this file covers the canonical, most-played selection — enough to populate
// a session of dungeon delving without being exhaustive. The remainder is
// deferred per plan.

import '_helpers.dart';

Map<String, dynamic> _mi({
  required String name,
  required String category,
  required String rarity,
  required bool requiresAttunement,
  required String activation,
  required String effects,
  String? attunementPrereq,
  bool isCursed = false,
  String? baseItemSlug,
  String? baseItemName,
  int? maxCharges,
  String? chargeRegain,
  int? costGp,
  double? weightLb,
  bool isSentient = false,
}) {
  final attrs = <String, dynamic>{
    'magic_category_ref': lookup('magic-item-category', category),
    'rarity_ref': rarity,
    'requires_attunement': requiresAttunement,
    'is_cursed': isCursed,
    'activation': activation,
    'effects': effects,
    'is_sentient': isSentient,
  };
  if (attunementPrereq != null) attrs['attunement_prereq'] = attunementPrereq;
  if (baseItemSlug != null && baseItemName != null) {
    attrs['base_item_ref'] = ref(baseItemSlug, baseItemName);
  }
  if (maxCharges != null) attrs['charges_max'] = maxCharges;
  if (chargeRegain != null) attrs['charge_regain'] = chargeRegain;
  if (costGp != null) attrs['cost_gp'] = costGp;
  if (weightLb != null) attrs['weight_lb'] = weightLb;
  return packEntity(
    slug: 'magic-item',
    name: name,
    description: effects,
    attributes: attrs,
  );
}

List<Map<String, dynamic>> srdMagicItems() => [
      _mi(
        name: 'Bag of Holding',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'Utilize',
        weightLb: 15,
        effects:
            'This bag has an interior space considerably larger than its outside dimensions, roughly 2 feet in diameter at the mouth and 4 feet deep. The bag can hold up to 500 pounds, not exceeding a volume of 64 cubic feet. The bag weighs 15 pounds, regardless of its contents. Retrieving an item from the bag requires a Utilize action.\n\n'
                'If the bag is overloaded, pierced, or torn, it ruptures and is destroyed; its contents are scattered in the Astral Plane. If the bag is turned inside out, its contents spill forth, unharmed; the bag must be put right before it can be used again. Placing a bag of holding inside an extradimensional space (Bag of Holding, Portable Hole, Handy Haversack) immediately destroys both items and opens a gate to the Astral Plane.',
      ),
      _mi(
        name: 'Cloak of Protection',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
      ),
      _mi(
        name: 'Boots of Elvenkind',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'None',
        effects:
            'While you wear these boots, your steps make no sound, regardless of the surface you are moving across. You also have Advantage on Dexterity (Stealth) checks that rely on moving silently.',
      ),
      _mi(
        name: 'Potion of Healing',
        category: 'Potions',
        rarity: 'Common',
        requiresAttunement: false,
        activation: 'Consumable',
        weightLb: 0.5,
        costGp: 50,
        effects:
            'You regain 2d4 + 2 HP when you drink this potion. The potion\'s red liquid glimmers when agitated.',
      ),
      _mi(
        name: 'Potion of Greater Healing',
        category: 'Potions',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'Consumable',
        weightLb: 0.5,
        effects: 'You regain 4d4 + 4 HP when you drink this potion.',
      ),
      _mi(
        name: 'Wand of Magic Missiles',
        category: 'Wands',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'Magic Action',
        maxCharges: 7,
        chargeRegain: '1d6+1 daily at dawn',
        effects:
            'This wand has 7 charges. While holding it, you can use a Magic action to expend 1 or more of its charges to cast Magic Missile from it. For 1 charge, cast the level 1 version. You can increase the slot level by one for each additional charge expended.\n\n'
                'The wand regains 1d6 + 1 expended charges daily at dawn. If you expend the wand\'s last charge, roll a d20. On a 1, the wand crumbles into ashes and is destroyed.',
      ),
      _mi(
        name: 'Ring of Protection',
        category: 'Rings',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'You gain a +1 bonus to AC and saving throws while wearing this ring.',
      ),
      _mi(
        name: 'Ring of Spell Storing',
        category: 'Rings',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'Magic Action',
        effects:
            'This ring stores spells cast into it, holding them until the attuned wearer uses them. The ring can store up to 5 levels worth of spells at a time. When found, it contains 1d6 − 1 levels of stored spells chosen by the GM.\n\n'
                'Any creature can cast a spell of level 1–5 into the ring by touching it. The spell has no effect; it is stored. If the ring can\'t hold the spell, it is expended without effect. The wearer can cast a stored spell using its spell save DC, slot level, and spell attack bonus. Casting it from the ring requires no Material components, removes it from the ring, and frees up its capacity.',
      ),
      _mi(
        name: 'Staff of Healing',
        category: 'Staffs',
        rarity: 'Rare',
        requiresAttunement: true,
        attunementPrereq: 'Bard, Cleric, or Druid',
        activation: 'Magic Action',
        maxCharges: 10,
        chargeRegain: '1d6+4 daily at dawn',
        effects:
            'This staff has 10 charges. While holding it, you can use a Magic action to expend 1 or more of its charges to cast one of the following spells from it, using your spell save DC and spellcasting ability:\n\n'
                '• Cure Wounds (1 charge per spell level, up to level 4)\n'
                '• Lesser Restoration (2 charges)\n'
                '• Mass Cure Wounds (5 charges)\n\n'
                'The staff regains 1d6 + 4 expended charges daily at dawn. If you expend the last charge, roll a d20. On a 1, the staff vanishes in a flash of light, lost forever.',
      ),
      _mi(
        name: 'Sword of Sharpness',
        category: 'Weapons',
        rarity: 'Very Rare',
        requiresAttunement: true,
        activation: 'None',
        baseItemSlug: 'weapon',
        baseItemName: 'Longsword',
        effects:
            'When you attack an object with this magic Slashing weapon and hit, maximize your weapon damage dice against the target.\n\n'
                'When you attack a creature with this weapon and roll a 20 on the attack roll, that target takes an extra 4d6 Slashing damage. Then roll another d20. If you roll a 20, you lop off one of the target\'s limbs, with the effect of such loss determined by the GM. If the creature has no limb to sever, you lop off a portion of its body instead.\n\n'
                'In addition, you can speak the sword\'s command word to cause the blade to shed Bright Light in a 10-foot radius and Dim Light for an additional 10 feet. Speaking the command word again or sheathing the sword puts out the light.',
      ),
      _mi(
        name: 'Plate Armor of Etherealness',
        category: 'Armor',
        rarity: 'Legendary',
        requiresAttunement: true,
        activation: 'Magic Action',
        baseItemSlug: 'armor',
        baseItemName: 'Plate Armor',
        effects:
            'While wearing this armor, you can speak its command word as a Magic action to gain the effect of the Etherealness spell, which lasts for 10 minutes or until you use the action to speak the command word again. This property can\'t be used again until the next dawn.',
      ),
      _mi(
        name: 'Vorpal Sword',
        category: 'Weapons',
        rarity: 'Legendary',
        requiresAttunement: true,
        activation: 'None',
        baseItemSlug: 'weapon',
        baseItemName: 'Greatsword',
        effects:
            'You gain a +3 bonus to attack and damage rolls made with this magic weapon. In addition, the weapon ignores Resistance to Slashing damage.\n\n'
                'When you attack a creature that has at least one head with this weapon and roll a 20 on the attack roll, you cut off one of the creature\'s heads. The creature dies if it can\'t survive without the lost head. A creature is immune to this effect if it has Legendary Actions, lacks or doesn\'t need a head, or the GM decides that the creature is too big for its head to be cut off. Otherwise you can decapitate it with this attack.',
      ),

      // ─── Apparel ─────────────────────────────────────────────────────────
      _mi(
        name: 'Cloak of Elvenkind',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: true,
        activation: 'Magic Action',
        effects:
            'While you wear this cloak with its hood up, Wisdom (Perception) checks made to see you have Disadvantage, and you have Advantage on Dexterity (Stealth) checks made to hide, as the cloak\'s color shifts to camouflage you. Pulling the hood up or down requires a Magic action.',
      ),
      _mi(
        name: 'Bracers of Defense',
        category: 'Wondrous Items',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and aren\'t using a Shield.',
      ),
      _mi(
        name: 'Gauntlets of Ogre Power',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'Your Strength score is 19 while you wear these gauntlets. They have no effect on you if your Strength is 19 or higher without them.',
      ),
      _mi(
        name: 'Goggles of Night',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'None',
        effects:
            'While wearing these dark lenses, you have Darkvision out to a range of 60 feet. If you already have Darkvision, the goggles increase its range by 60 feet.',
      ),
      _mi(
        name: 'Headband of Intellect',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'Your Intelligence score is 19 while you wear this headband. It has no effect on you if your Intelligence is 19 or higher without it.',
      ),
      _mi(
        name: 'Boots of Speed',
        category: 'Wondrous Items',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'Bonus Action',
        effects:
            'While you wear these boots, you can take a Bonus Action to click the boots\' heels together. While the heels are clicked together, your Speed is doubled, and any creature that makes an Opportunity Attack against you has Disadvantage on the attack roll. The effect ends when you click the heels together again as a Bonus Action or after 10 minutes have passed. Once the boots have been used for a total of 10 minutes, they can\'t be used again until the next dawn.',
      ),
      _mi(
        name: 'Winged Boots',
        category: 'Wondrous Items',
        rarity: 'Uncommon',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'While you wear these boots, you have a Fly Speed equal to your Walk Speed. You can use the boots to fly for up to 4 hours, all at once or in several shorter flights. Each use of the boots in flight uses a minimum of 1 minute. If you are flying when the boots\' last minute of flight is used, you descend at a rate of 30 feet per round until you land.\n\nThe boots regain 2 hours of flying capability for every 12 hours they aren\'t in use.',
      ),
      _mi(
        name: 'Belt of Giant Strength (Hill)',
        category: 'Wondrous Items',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'While wearing this belt, your Strength score is 21. The item has no effect on you if your Strength is already 21 or higher without it.',
      ),
      _mi(
        name: 'Amulet of Health',
        category: 'Wondrous Items',
        rarity: 'Rare',
        requiresAttunement: true,
        activation: 'None',
        effects:
            'Your Constitution score is 19 while you wear this amulet. It has no effect on you if your Constitution is 19 or higher without it.',
      ),

      // ─── +N weapons & armor ─────────────────────────────────────────────
      _mi(
        name: 'Weapon, +1',
        category: 'Weapons',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'None',
        effects:
            'You have a +1 bonus to attack rolls and damage rolls made with this magic weapon. The bonus applies to any weapon of the chosen base type (e.g. all longswords). The Item Rarity table determines the bonus: +1 (Uncommon), +2 (Rare), +3 (Very Rare).',
      ),
      _mi(
        name: 'Armor, +1',
        category: 'Armor',
        rarity: 'Rare',
        requiresAttunement: false,
        activation: 'None',
        effects:
            'You have a +1 bonus to AC while wearing this armor. The bonus increases by rarity: +1 (Rare), +2 (Very Rare), +3 (Legendary). Choose any base armor.',
      ),
      _mi(
        name: 'Shield, +1',
        category: 'Armor',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'None',
        effects:
            'While holding this Shield, you have a bonus to AC in addition to the Shield\'s normal bonus. The Item Rarity table determines the bonus: +1 (Uncommon), +2 (Rare), +3 (Very Rare).',
      ),

      // ─── Common potions / scrolls ───────────────────────────────────────
      _mi(
        name: 'Potion of Climbing',
        category: 'Potions',
        rarity: 'Common',
        requiresAttunement: false,
        activation: 'Consumable',
        weightLb: 0.5,
        costGp: 50,
        effects:
            'When you drink this potion, you gain a Climb Speed equal to your Walk Speed for 1 hour. During this time, you have Advantage on Strength (Athletics) checks made to climb. The potion is separated into brown, silver, and gray layers resembling bands of stone. Shaking the bottle fails to mix the colors.',
      ),
      _mi(
        name: 'Potion of Fire Breath',
        category: 'Potions',
        rarity: 'Uncommon',
        requiresAttunement: false,
        activation: 'Consumable',
        weightLb: 0.5,
        effects:
            'After you drink this potion, you can take a Bonus Action to exhale fire at a creature within 30 feet of yourself. The creature must succeed on a DC 13 Dexterity save or take 4d6 Fire damage. The effect ends after you exhale fire three times or when 1 hour has passed.\n\nThe potion\'s orange liquid flickers, and smoke wafts from its opening.',
      ),
      _mi(
        name: 'Spell Scroll',
        category: 'Scrolls',
        rarity: 'Common',
        requiresAttunement: false,
        activation: 'Magic Action',
        effects:
            'A Spell Scroll bears the words of a single spell, written in a mystical cipher. If the spell is on your spell list, you can cast it from the scroll without having to provide any Material components. Otherwise the scroll is unintelligible.\n\nIf the spell is of a level higher than you can normally cast, you must make an ability check using your spellcasting ability to determine whether you cast it successfully (DC = 10 + spell\'s level). On a failed check, the spell disappears with no other effect.\n\nOnce the spell is cast, the words on the scroll fade and the scroll itself crumbles to dust. The level of the spell on the scroll determines its rarity, save DC, attack bonus, and gold value (Cantrip = Common, Level 1 = Common, Level 2-3 = Uncommon, Level 4-5 = Rare, Level 6-7 = Very Rare, Level 8-9 = Legendary).',
      ),

      // ─── More potions ───────────────────────────────────────────────────
      _mi(name: 'Potion of Animal Friendship', category: 'Potions', rarity: 'Uncommon', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you can cast the Animal Friendship spell (save DC 13) for 1 hour at will. Agitating this muddy liquid brings little bits into view: a fish scale, a hummingbird tongue, a cat claw, or a squirrel hair.'),
      _mi(name: 'Potion of Diminution', category: 'Potions', rarity: 'Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you gain the "reduce" effect of the Enlarge/Reduce spell for 10 minutes (no Concentration required). The potion\'s red liquid contains a tiny bit of pickled doppelganger ear.'),
      _mi(name: 'Potion of Flying', category: 'Potions', rarity: 'Very Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you gain a Fly Speed equal to your Walk Speed for 1 hour and can hover. If you are in the air when the potion wears off, you fall unless you have some other means of staying aloft. The potion\'s clear liquid floats at the top of its container and has cloudy white impurities drifting in it.'),
      _mi(name: 'Potion of Gaseous Form', category: 'Potions', rarity: 'Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you gain the effect of the Gaseous Form spell for 1 hour (no Concentration required) or until you end the effect as a Bonus Action.'),
      _mi(name: 'Potion of Giant Strength (Hill)', category: 'Potions', rarity: 'Uncommon', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, your Strength score becomes 21 for 1 hour. The potion has no effect on you if your Strength is already 21 or higher. The transparent liquid contains floating bits of fingernails, hair, and brown spots.'),
      _mi(name: 'Potion of Heroism', category: 'Potions', rarity: 'Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'For 1 hour after drinking it, you gain 10 Temporary Hit Points that last for 1 hour. For the same duration, you are under the effect of the Bless spell (no Concentration required). This blue potion bubbles and steams as if boiling.'),
      _mi(name: 'Potion of Invisibility', category: 'Potions', rarity: 'Very Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'The potion\'s container looks empty but feels as though it holds liquid. When you drink it, you have the Invisible condition for 1 hour. Anything you wear or carry is also Invisible as long as it is on your person. The effect ends early if you attack or cast a spell.'),
      _mi(name: 'Potion of Mind Reading', category: 'Potions', rarity: 'Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you gain the effect of the Detect Thoughts spell (save DC 13). The potion\'s dense, purple liquid has an ovoid cloud of pink floating in it.'),
      _mi(name: 'Potion of Poison', category: 'Potions', rarity: 'Uncommon', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, isCursed: true, effects: 'This concoction looks, smells, and tastes like a Potion of Healing or other beneficial potion. However, it is actually poison masked by illusion magic. An Identify spell reveals its true nature. If you drink it, you take 3d6 Poison damage and must succeed on a DC 13 Con save or have the Poisoned condition. At the end of each of your turns, you can repeat the save, taking 3d6 Poison damage on a fail or ending the effect on a success.'),
      _mi(name: 'Potion of Speed', category: 'Potions', rarity: 'Very Rare', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'When you drink this potion, you gain the effect of the Haste spell for 1 minute (no Concentration required). The potion\'s yellow fluid is streaked with black and swirls on its own.'),
      _mi(name: 'Potion of Water Breathing', category: 'Potions', rarity: 'Uncommon', requiresAttunement: false, activation: 'Consumable', weightLb: 0.5, effects: 'You can breathe underwater for 1 hour after drinking this potion. Its cloudy green fluid smells of the sea and has a jellyfish-like bubble floating in it.'),
      _mi(name: 'Oil of Slipperiness', category: 'Potions', rarity: 'Uncommon', requiresAttunement: false, activation: 'Utilize', weightLb: 0.5, effects: 'This sticky black unguent is thick and heavy in the container, but it flows quickly when poured. The oil can cover a Medium or smaller creature, along with the equipment it\'s wearing and carrying (one additional vial is required for each size category above Medium). Applying the oil takes 10 minutes. The affected creature then gains the effect of a Freedom of Movement spell for 8 hours.'),
      _mi(name: 'Oil of Sharpness', category: 'Potions', rarity: 'Very Rare', requiresAttunement: false, activation: 'Utilize', weightLb: 0.5, effects: 'This clear, gelatinous oil sparkles with tiny, ultrathin silver shards. The oil can coat one Slashing or Piercing weapon or up to 5 pieces of Slashing or Piercing ammunition. Applying the oil takes 1 minute. For 1 hour, the coated item is magical and has a +3 bonus to attack and damage rolls.'),

      // ─── Apparel & accessories ──────────────────────────────────────────
      _mi(name: 'Cloak of Resistance', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'You have Resistance to one damage type chosen at the time the cloak is created (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder).'),
      _mi(name: 'Cloak of the Bat', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'Magic Action', effects: 'While wearing this cloak, you have Advantage on Dex (Stealth) checks. In an area of Dim Light or Darkness, you can grip the edges of the cloak with both hands and use it to fly at a Speed of 40 feet. If you ever fail to grip the cloak\'s edges, or you are no longer in Dim Light or Darkness, you lose this Fly Speed. While wearing the cloak in an area of Dim Light or Darkness, you can take a Magic action to cast Polymorph on yourself, transforming into a Bat. While in this form you retain your Intelligence, Wisdom, and Charisma scores.'),
      _mi(name: 'Cloak of Displacement', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'While you wear this cloak, it projects an illusion that makes you appear to be standing in a place near your actual location. The illusion makes attack rolls against you have Disadvantage. If you take damage, the property ceases to function until the start of your next turn. This property is suppressed while you have the Incapacitated condition, are Restrained, or otherwise can\'t move.'),
      _mi(name: 'Hat of Disguise', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'Magic Action', effects: 'While wearing this hat, you can take a Magic action to cast the Disguise Self spell from it at will. The spell ends if the hat is removed.'),
      _mi(name: 'Helm of Telepathy', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'Magic Action', effects: 'While wearing this helm, you can take a Magic action to cast the Detect Thoughts spell (save DC 13) from it. As long as you maintain Concentration on the spell, you can use the helm to send a telepathic message to anyone you focus your thoughts on. A target who can understand a language can reply telepathically. Once you cast the spell from the helm, it can\'t be cast again from it until the next dawn.'),
      _mi(name: 'Periapt of Wound Closure', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While you wear this pendant, you stabilize whenever you have the Unconscious condition and are at 0 HP. In addition, whenever you roll a Hit Die to regain HP, double the number of HP it restores.'),
      _mi(name: 'Bag of Beans', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Utilize', effects: 'Inside this heavy cloth bag are 3d4 dry beans. You can take a Magic action to remove a bean and throw it up to 10 feet. After 1 minute, the bean produces a magical effect determined by rolling on a table provided in the SRD (effects range from a useful Treant to a calamitous earthquake). If you dump the bag\'s contents on the ground, the beans burst forth in a 30-foot-radius eruption.'),
      _mi(name: 'Bag of Tricks (Gray)', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'This ordinary-looking bag, made from gray cloth, appears empty. Reaching inside, however, retrieves a small fuzzy object. You can take a Magic action to pull the object from the bag and throw it up to 20 feet. When the object lands, it transforms into a creature determined by rolling a d8 (Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, Giant Elk). The creature is friendly to you and your companions, and acts on your turn. The creature exists for 1 hour, until it drops to 0 HP, or until you dismiss it. The bag has 3 charges, regaining 1d3 expended charges daily at dawn.'),
      _mi(name: 'Brooch of Shielding', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While wearing this brooch, you have Resistance to Force damage and Immunity to damage from the Magic Missile spell.'),
      _mi(name: 'Decanter of Endless Water', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'This stoppered flask sloshes when shaken, as if it contains water. The flask weighs 2 pounds. You can take a Magic action to remove the stopper and speak one of three command words: "Stream" produces 1 gallon of water per turn for as long as you speak the word; "Fountain" produces 5 gallons of water in a 5-foot-long stream; "Geyser" produces 30 gallons in a 30-foot-long, 1-foot-wide stream that knocks down creatures of Large size or smaller (DC 13 Strength save or be pushed 5 feet and knocked Prone).'),
      _mi(name: 'Driftglobe', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'This small sphere of thick glass weighs 1 pound. While within 60 feet of it, you can speak its command word to cast the Daylight spell from it. The spell ends when you use a Bonus Action to repeat the command word or when the driftglobe is covered. You can also speak another command word to cause the driftglobe to rise into the air and float no more than 5 feet off the ground. The globe hovers in this way until you or another creature grasps it.'),
      _mi(name: 'Eyes of Charming', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'Magic Action', maxCharges: 3, chargeRegain: 'all daily at dawn', effects: 'These crystal lenses fit over the eyes. They have 3 charges. While wearing them, you can take a Magic action to expend 1 charge to cast the Charm Person spell (save DC 13) on a Humanoid within 30 feet of you. The lenses regain all expended charges daily at dawn.'),
      _mi(name: 'Eyes of the Eagle', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'These crystal lenses fit over the eyes. While wearing them, you have Advantage on Wisdom (Perception) checks that rely on sight. In conditions of clear visibility, you can make out details of even extremely distant creatures and objects as small as 2 feet across.'),
      _mi(name: 'Figurine of Wondrous Power (Bronze Griffon)', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'This bronze statuette of a griffon can become a real griffon for 6 hours, with statistics matching that creature. The figurine reverts to a statue when it drops to 0 HP or when its owner uses an action to speak the command word again. Once used, can\'t be used again until 5 days have passed.'),
      _mi(name: 'Gem of Brightness', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', maxCharges: 50, effects: 'This prism has 50 charges. While you are holding it, you can take a Magic action to speak one of three command words to cause one of the following effects. The gem can\'t be recharged. *Light:* Speaking the first command word causes the gem to shed Bright Light in a 30-foot radius and Dim Light for an additional 30 feet. *Bright Beam:* Speaking the second command word expends 1 charge and causes the gem to fire a brilliant beam of light at one creature within 60 feet of you. The creature must succeed on a DC 15 Con save or have the Blinded condition for 1 minute. *Blinding Cone:* Speaking the third command word expends 5 charges and causes the gem to flare with blinding light in a 30-foot Cone originating from it. Each creature in the Cone must make the same saving throw.'),
      _mi(name: 'Horn of Blasting', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'You can take a Magic action to blow this horn, which emits a thunderous blast in a 30-foot Cone. Each creature in the Cone must make a DC 15 Con save: 5d6 Thunder damage and Deafened 1 minute on a fail, half damage on a success. A creature made of inorganic material such as stone, crystal, or metal has Disadvantage on this save. A nonmagical object that isn\'t worn or carried also takes the damage if in the Cone. Once the horn has been used, it can\'t be used again until the next dawn. If you blow the horn 4 or more times before the next dawn, there is a 20% chance that it explodes, dealing 10d6 Force damage to you.'),
      _mi(name: 'Immovable Rod', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', weightLb: 2, effects: 'This flat iron rod has a button on one end. You can take a Magic action to press the button, which causes the rod to become magically fixed in place. Until you or another creature takes a Magic action to push the button again, the rod doesn\'t move, even if it is defying gravity. The rod can hold up to 8,000 pounds of weight. More weight causes the rod to deactivate and fall.'),
      _mi(name: 'Lantern of Revealing', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'While lit, this hooded lantern burns for 6 hours on 1 pint of oil, shedding Bright Light in a 30-foot radius and Dim Light for an additional 30 feet. Invisible creatures and objects are visible as long as they are in the lantern\'s Bright Light. You can take a Bonus Action to lower the hood, reducing the light to Dim Light in a 5-foot radius.'),
      _mi(name: 'Necklace of Adaptation', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While wearing this necklace, you can breathe normally in any environment, and you have Advantage on saving throws made against harmful gases and vapors (such as Cloudkill and Stinking Cloud effects, inhaled poisons, and the breath weapons of some dragons).'),
      _mi(name: 'Necklace of Fireballs', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'This necklace has 1d6 + 3 beads hanging from it. You can take a Magic action to detach a bead and throw it up to 60 feet away. When it reaches the end of its trajectory, the bead detonates as a level 3 Fireball spell (save DC 15). You can hurl multiple beads, or even the whole necklace, as one action. When you do so, increase the level of the Fireball by 1 for each bead beyond the first.'),
      _mi(name: 'Pearl of Power', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, attunementPrereq: 'A spellcaster', activation: 'Bonus Action', effects: 'While this pearl is on your person, you can take a Bonus Action to speak the pearl\'s command word and regain one expended spell slot of up to level 3. Once you have used the pearl, it can\'t be used again until the next dawn.'),
      _mi(name: 'Quiver of Ehlonna', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Utilize', effects: 'Each of the three compartments of this quiver connects to an extradimensional space that allows the quiver to hold numerous items while never weighing more than 2 pounds. The shortest compartment can hold up to sixty arrows, javelins, or similar objects. The midsize compartment holds up to eighteen objects of similar size, such as bows. The longest compartment holds up to six long objects, such as bows, quarterstaves, or spears.'),
      _mi(name: 'Robe of Eyes', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'This robe is adorned with eyelike patterns. While you wear the robe, you gain the following benefits: you can see in all directions and have Advantage on Wisdom (Perception) checks that rely on sight; you have Darkvision out to a range of 120 feet; you can see Invisible creatures and objects, as well as into the Ethereal Plane, out to 120 feet. The robe\'s eyes can\'t be closed or averted. Although you can close or avert your own eyes, you are never considered to do so while wearing this robe.'),
      _mi(name: 'Robe of Stars', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'Magic Action', effects: 'This black or dark blue robe is embroidered with small white or silver stars. You gain a +1 bonus to saving throws while you wear it. Six stars on the front are particularly large. While wearing the robe, you can take a Magic action to pull off one of the stars and use it to cast Magic Missile as a level 5 spell. Daily at dusk, 1d6 stars regenerate. While wearing the robe, you can use a Magic action to enter the Astral Plane along with everything you wear and carry; the robe and any items it contains accompany you. You can stay there for up to 12 hours per day.'),
      _mi(name: 'Robe of the Archmagi', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'Sorcerer, Warlock, or Wizard', activation: 'None', effects: 'This elegant garment is made from exquisite cloth of white, gray, or black and adorned with silvery runes. The robe\'s color corresponds to the alignment for which the item was created: white for good, gray for neutral, and black for evil. You can\'t attune to a robe of the archmagi that doesn\'t correspond to your alignment. Wearing the robe gives you: AC 15 + your Dex modifier (no armor required); Advantage on saving throws against spells and other magical effects; +2 bonus to spell save DC and spell attack rolls.'),
      _mi(name: 'Robe of Useful Items', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'This robe has cloth patches of various items on it. The robe has two of each of the following: Dagger, Bullseye Lantern (with full oil), Steel Mirror, 10-foot pole, Hempen Rope (50 feet, coiled), and Sack. The GM might allow other patches to be created. The wearer can detach a patch as an action; the patch becomes the actual item it depicts.'),
      _mi(name: 'Slippers of Spider Climbing', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While you wear these light shoes, you can move up, down, and across vertical surfaces and upside down along ceilings, while leaving your hands free. You have a Climb Speed equal to your Walk Speed. However, the slippers don\'t allow you to move this way on a slippery surface, such as one covered by ice or oil.'),
      _mi(name: 'Stone of Good Luck (Luckstone)', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While this polished agate is on your person, you gain a +1 bonus to ability checks and saving throws.'),
      _mi(name: 'Wand of Fireballs', category: 'Wands', rarity: 'Rare', requiresAttunement: true, attunementPrereq: 'A spellcaster', activation: 'Magic Action', maxCharges: 7, chargeRegain: '1d6+1 daily at dawn', effects: 'This wand has 7 charges. While holding it, you can take a Magic action to expend 1 or more of its charges to cast the Fireball spell (save DC 15) from it. For 1 charge, you cast the level 3 version. You can increase the spell\'s level by 1 for each additional charge expended. The wand regains 1d6 + 1 expended charges daily at dawn. If you expend the wand\'s last charge, roll a d20. On a 1, the wand crumbles into ashes and is destroyed.'),
      _mi(name: 'Wand of Lightning Bolts', category: 'Wands', rarity: 'Rare', requiresAttunement: true, attunementPrereq: 'A spellcaster', activation: 'Magic Action', maxCharges: 7, chargeRegain: '1d6+1 daily at dawn', effects: 'This wand has 7 charges. While holding it, you can take a Magic action to expend 1 or more of its charges to cast the Lightning Bolt spell (save DC 15) from it. For 1 charge, you cast the level 3 version. You can increase the spell\'s level by 1 for each additional charge expended.'),
      _mi(name: 'Wand of the War Mage, +1', category: 'Wands', rarity: 'Uncommon', requiresAttunement: true, attunementPrereq: 'A spellcaster', activation: 'None', effects: 'While holding this wand, you gain a bonus to spell attack rolls determined by the wand\'s rarity (+1 Uncommon, +2 Rare, +3 Very Rare). In addition, you ignore Half Cover when making a spell attack.'),
      _mi(name: 'Wand of Web', category: 'Wands', rarity: 'Uncommon', requiresAttunement: true, attunementPrereq: 'A spellcaster', activation: 'Magic Action', maxCharges: 7, chargeRegain: '1d6+1 daily at dawn', effects: 'This wand has 7 charges. While holding it, you can take a Magic action to expend 1 of its charges to cast the Web spell (save DC 15) from it.'),
      _mi(name: 'Staff of Fire', category: 'Staffs', rarity: 'Very Rare', requiresAttunement: true, attunementPrereq: 'Druid, Sorcerer, Warlock, or Wizard', activation: 'Magic Action', maxCharges: 10, chargeRegain: '1d6+4 daily at dawn', effects: 'You have Resistance to Fire damage while you hold this staff. The staff has 10 charges. While holding it, you can take a Magic action to expend 1 or more of its charges to cast Burning Hands (1 charge), Fireball (3 charges), or Wall of Fire (4 charges). The staff regains 1d6 + 4 expended charges daily at dawn.'),
      _mi(name: 'Staff of Frost', category: 'Staffs', rarity: 'Very Rare', requiresAttunement: true, attunementPrereq: 'Druid, Sorcerer, Warlock, or Wizard', activation: 'Magic Action', maxCharges: 10, chargeRegain: '1d6+4 daily at dawn', effects: 'You have Resistance to Cold damage while you hold this staff. The staff has 10 charges. While holding it, you can take a Magic action to expend 1 or more charges to cast Cone of Cold (5 charges), Fog Cloud (1 charge), Ice Storm (4 charges), or Wall of Ice (4 charges).'),
      _mi(name: 'Staff of the Magi', category: 'Staffs', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'Sorcerer, Warlock, or Wizard', activation: 'Magic Action', maxCharges: 50, chargeRegain: '4d6+2 daily at dawn', effects: 'This iron-shod, hardwood staff is decorated with carvings depicting many forms of magic. While holding the staff, you have Advantage on saving throws against spells. You can also take a Reaction to absorb a spell of level 8 or lower that targets only you and not an area, and gain spell slots from it. The staff has 50 charges, used to cast various potent spells (Fireball, Ice Storm, Lightning Bolt, Wall of Fire, Web, Detect Magic, Enlarge/Reduce, Light, Mage Hand, Flaming Sphere, Invisibility, Knock, Passwall, Plane Shift, Telekinesis, Pyrotechnics).'),
      _mi(name: 'Ring of Three Wishes', category: 'Rings', rarity: 'Legendary', requiresAttunement: true, activation: 'Magic Action', maxCharges: 3, effects: 'While wearing this ring, you can take a Magic action to expend 1 of its 3 charges to cast the Wish spell from it. The ring becomes nonmagical when you use the last charge.'),
      _mi(name: 'Ring of Free Action', category: 'Rings', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'While you wear this ring, Difficult Terrain doesn\'t cost you extra movement. In addition, magic can neither reduce your Speed nor cause you to be Paralyzed or Restrained.'),
      _mi(name: 'Ring of Invisibility', category: 'Rings', rarity: 'Legendary', requiresAttunement: true, activation: 'Magic Action', effects: 'While wearing this ring, you can take a Magic action to have the Invisible condition. You remain Invisible until the ring is removed, until you attack or cast a spell, or until you take a Bonus Action to become visible again.'),
      _mi(name: 'Ring of Mind Shielding', category: 'Rings', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While wearing this ring, you are immune to magic that allows other creatures to read your thoughts, determine whether you are lying, know your alignment, or know your creature type. Creatures can communicate telepathically with you only if you allow it. You can take a Magic action to imprint your soul into the ring before you die. If you have any unfinished business in life, your soul inhabits the ring and remains until your business is concluded.'),
      _mi(name: 'Ring of Regeneration', category: 'Rings', rarity: 'Very Rare', requiresAttunement: true, activation: 'None', effects: 'While wearing this ring, you regain 1d6 HP every 10 minutes, provided that you have at least 1 HP. If you lose a body part, the ring causes the missing part to regrow and return to full functionality after 1d6 + 1 days if you have at least 1 HP the whole time.'),
      _mi(name: 'Ring of Resistance', category: 'Rings', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'You have Resistance to one damage type while wearing this ring. The damage type is determined by the gem in the ring (Pearl=Acid, Tourmaline=Cold, Garnet=Fire, Citrine=Force, Sapphire=Lightning, Jet=Necrotic, Amethyst=Poison, Jade=Psychic, Topaz=Radiant, Spinel=Thunder).'),

      // ─── Weapons & armor ────────────────────────────────────────────────
      _mi(name: 'Dragon Slayer', category: 'Weapons', rarity: 'Rare', requiresAttunement: false, activation: 'None', baseItemSlug: 'weapon', baseItemName: 'Longsword', effects: 'You gain a +1 bonus to attack rolls and damage rolls made with this magic weapon. When you hit a Dragon with this weapon, the Dragon takes an extra 3d6 damage of the weapon\'s type. For the purpose of this weapon, "Dragon" refers to any creature with the Dragon creature type.'),
      _mi(name: 'Flame Tongue', category: 'Weapons', rarity: 'Rare', requiresAttunement: true, activation: 'Bonus Action', baseItemSlug: 'weapon', baseItemName: 'Longsword', effects: 'You can take a Bonus Action to speak this magic sword\'s command word, causing flames to erupt from the blade. These flames shed Bright Light in a 40-foot radius and Dim Light for an additional 40 feet. While the sword is ablaze, it deals an extra 2d6 Fire damage to any target it hits. The flames last until you use a Bonus Action to speak the command word again or until you drop or sheathe the sword.'),
      _mi(name: 'Frost Brand', category: 'Weapons', rarity: 'Very Rare', requiresAttunement: true, activation: 'None', baseItemSlug: 'weapon', baseItemName: 'Longsword', effects: 'When you hit with an attack using this magic sword, the target takes an extra 1d6 Cold damage. In addition, while you hold the sword, you have Resistance to Fire damage. In freezing temperatures, the sword sheds Bright Light in a 10-foot radius and Dim Light for an additional 10 feet. When you draw this weapon, you can extinguish all nonmagical flames within 30 feet.'),
      _mi(name: 'Holy Avenger', category: 'Weapons', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'Paladin', activation: 'None', baseItemSlug: 'weapon', baseItemName: 'Longsword', effects: 'You gain a +3 bonus to attack rolls and damage rolls made with this magic weapon. When you hit a Fiend or an Undead with it, that creature takes an extra 2d10 Radiant damage. While you hold the drawn sword, it creates an aura in a 10-foot radius around you. You and all Celestials, Fey, and Humanoids in the aura have Advantage on saving throws against spells and other magical effects. If the sword has 17 or more levels, the aura\'s radius increases to 30 feet.'),
      _mi(name: 'Adamantine Armor', category: 'Armor', rarity: 'Uncommon', requiresAttunement: false, activation: 'None', baseItemSlug: 'armor', baseItemName: 'Plate Armor', effects: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While wearing it, any Critical Hit against you becomes a normal hit.'),
      _mi(name: 'Mithral Armor', category: 'Armor', rarity: 'Uncommon', requiresAttunement: false, activation: 'None', baseItemSlug: 'armor', baseItemName: 'Half Plate Armor', effects: 'Mithral is a light, flexible metal. A mithral chain shirt or breastplate can be worn under normal clothes. If the armor normally imposes Disadvantage on Dex (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.'),
      _mi(name: 'Armor of Resistance', category: 'Armor', rarity: 'Rare', requiresAttunement: true, activation: 'None', baseItemSlug: 'armor', baseItemName: 'Chain Mail', effects: 'You have Resistance to one type of damage while you wear this armor. The damage type is determined by the GM or the armor\'s creator (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder).'),
      _mi(name: 'Glamoured Studded Leather', category: 'Armor', rarity: 'Rare', requiresAttunement: false, activation: 'Bonus Action', baseItemSlug: 'armor', baseItemName: 'Studded Leather Armor', effects: 'While wearing this armor, you gain a +1 bonus to AC. You can also speak the armor\'s command word as a Bonus Action to cause it to assume the appearance of a normal set of clothing or some other kind of armor. You decide what it looks like, including color, style, and accessories, but the armor retains its normal bulk and weight. The illusory appearance lasts until you use this property again or remove the armor.'),

      // ─── Artifacts & legendary wonders ──────────────────────────────────
      _mi(name: 'Apparatus of the Crab', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: false, activation: 'Magic Action', effects: 'This iron barrel has a hatch at one end. When the hatch is open, up to two Medium creatures can fit inside. Ten levers are arranged in two rows: levers move the apparatus across the floor or through water in the directions assigned to each. The apparatus is a Large object with AC 20, HP 200, and Immunity to Poison and Psychic damage.'),
      _mi(name: 'Cube of Force', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'Magic Action', maxCharges: 36, chargeRegain: '1d20 daily at dawn', effects: 'This cube is about an inch across. Each face has a distinct marking. The cube has 36 charges and regains 1d20 expended charges daily at dawn. As a Magic action, you can press one face of the cube and expend charges to create an invisible barrier of force in the shape of a 15-foot Cube around you. The barrier blocks creatures, objects, and spells in various combinations depending on the face pressed (1-6 charges).'),
      _mi(name: 'Crystal Ball', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'Magic Action', effects: 'The typical crystal ball is about 6 inches in diameter. While touching it, you can cast Scrying (DC 17) with it. Variants exist: Crystal Ball of Mind Reading (cast Detect Thoughts on creatures observed), Crystal Ball of Telepathy (Sending), Crystal Ball of True Seeing (cast on yourself).'),
      _mi(name: 'Deck of Many Things', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: false, activation: 'Magic Action', effects: 'A deck of small ivory or vellum cards. Drawing a card invokes its magic. Outcomes range from boons (gain XP, gain magic items, raise an ally) to disasters (lose all wealth, banish to another plane, become enemies of a powerful being). Once drawn, you must keep the result; some cards trigger immediately, others can be saved for later.'),
      _mi(name: 'Eye of Vecna', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, isCursed: true, activation: 'Magic Action', effects: 'In place of your right eye is a withered, dead-looking orb that grants Truesight up to 30 feet, casts Clairvoyance (1/day, no Concentration), Crown of Madness (1/day), Disintegrate (1/day), Dominate Monster (1/day, save DC 18), Eyebite (1/day). The Eye is sentient and tries to corrupt its bearer.'),
      _mi(name: 'Hand of Vecna', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, isCursed: true, activation: 'Magic Action', effects: 'In place of your left hand is a withered, mummified appendage. While attached, it grants +4 STR, immunity to Poison damage, and access to Finger of Death (1/day, save DC 18), Sleep (1/day), Slow (1/day, save DC 18), and Teleport (1/day).'),
      _mi(name: 'Tome of Clear Thought', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book contains memory and logic exercises that take 48 hours to complete. After completing the exercises, your Intelligence score and Intelligence maximum each increase by 2, to a maximum of 24. The book then loses its magic but retains its mundane value.'),
      _mi(name: 'Tome of Leadership and Influence', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book contains tales of charisma and influence. After 48 hours of study over no more than 6 days, your Charisma score and Charisma maximum each increase by 2, to a maximum of 24. The book then loses its magic.'),
      _mi(name: 'Tome of Understanding', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book contains exercises in intuition and insight. After 48 hours of study over no more than 6 days, your Wisdom score and Wisdom maximum each increase by 2, to a maximum of 24. The book then loses its magic.'),
      _mi(name: 'Manual of Bodily Health', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book describes physical exercises. After 48 hours of training over no more than 6 days, your Constitution score and maximum each increase by 2, to a maximum of 24. The book then loses its magic.'),
      _mi(name: 'Manual of Gainful Exercise', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book describes weight-training and combat conditioning. After 48 hours of training over no more than 6 days, your Strength score and maximum each increase by 2, to a maximum of 24. The book then loses its magic.'),
      _mi(name: 'Manual of Quickness of Action', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'This book describes coordination and balance training. After 48 hours of training over no more than 6 days, your Dexterity score and maximum each increase by 2, to a maximum of 24. The book then loses its magic.'),
      _mi(name: 'Mantle of Spell Resistance', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'You have Advantage on saving throws against spells while wearing this cloak.'),
      _mi(name: 'Iron Bands of Bilarro', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'This rusty iron sphere fits in the palm of your hand. As a Magic action while holding it, you can target a Huge or smaller creature within 60 feet, requiring a ranged attack roll (+5 to hit). On a hit, iron bands wrap the target, giving it the Restrained condition until you take a Bonus Action to release it or 24 hours pass.'),
      _mi(name: 'Mirror of Life Trapping', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Special', effects: 'When this mirror is hung and a creature comes within 30 feet that can see itself in the mirror, the mirror traps the creature in an extradimensional cell unless it succeeds on a DC 15 Charisma save. The mirror has 15 such cells.'),
      _mi(name: 'Sphere of Annihilation', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: false, activation: 'Magic Action', effects: 'A 2-foot-diameter ball of absolute, magical darkness. Any matter that touches the sphere — but not extradimensional space — is instantly erased. The sphere is stationary; you can attempt a DC 25 Intelligence (Arcana) check to control its movement up to 60 feet on your turn.'),
      _mi(name: 'Talisman of Pure Good', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'a creature of good alignment', activation: 'Reaction', effects: 'A creature of evil alignment that touches the talisman takes 6d6 Radiant damage. While wearing it, you gain a +2 bonus to all saving throws. The talisman has 7 charges; you can expend a charge as a Reaction when you fail a saving throw to succeed instead.'),
      _mi(name: 'Talisman of Ultimate Evil', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'a creature of evil alignment', activation: 'Reaction', effects: 'A creature of good alignment that touches the talisman takes 8d6 Necrotic damage. While wearing it, you gain a +2 bonus to all saving throws. The talisman has 6 charges; spend a charge as a Reaction to succeed on a failed save.'),
      _mi(name: 'Wings of Flying', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'Bonus Action', effects: 'While wearing this cloak, you can take a Bonus Action to cause it to transform into a pair of bat wings or bird wings on your back. The wings last for 1 hour or until you take a Bonus Action to make them disappear. The wings give you a Fly Speed of 60 feet.'),
      _mi(name: 'Boots of Levitation', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'Magic Action', effects: 'While wearing these boots, you can take a Magic action to cast Levitate on yourself at will.'),
      _mi(name: 'Bracers of Archery', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: true, activation: 'None', effects: 'While wearing these bracers, you have proficiency with the Longbow and Shortbow, and you gain a +2 bonus to damage rolls on ranged attacks made with such weapons.'),
      _mi(name: 'Cape of the Mountebank', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Bonus Action', effects: 'This cape smells faintly of brimstone. While wearing it, you can take a Bonus Action to cast Dimension Door from the cape. This property can\'t be used again until the next dawn. When you disappear, you leave behind a cloud of smoke, and you appear in a similar cloud of smoke at your destination.'),
      _mi(name: 'Demon Armor', category: 'Armor', rarity: 'Very Rare', requiresAttunement: true, isCursed: true, activation: 'None', baseItemSlug: 'armor', baseItemName: 'Plate Armor', effects: 'While wearing this armor, you gain a +1 bonus to AC, and you can understand and speak Abyssal. In addition, the armor\'s gauntlets turn unarmed strikes with your hands into magical attacks; on a hit, you deal 1d8 Slashing damage.'),
      _mi(name: 'Dimensional Shackles', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'You can take a Magic action to place these shackles on an Incapacitated creature. The shackles adjust to fit Small to Large creatures. They can\'t be teleported or otherwise removed by extradimensional means while attached. While wearing them, the creature can\'t use any method of extradimensional movement.'),
      _mi(name: 'Folding Boat', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'A wooden box about 12 inches long. Speak the command word, and the box unfolds into a 10-foot rowboat (or 24-foot ship with another command word). Speaking a third command word folds it back to a box.'),
      _mi(name: 'Belt of Giant Strength (Stone)', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'None', effects: 'While wearing this belt, your Strength score changes to 23. The item has no effect on you if your Strength without the belt is equal to or greater than 23.'),
      _mi(name: 'Belt of Giant Strength (Frost/Fire)', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'None', effects: 'While wearing this belt, your Strength score changes to 25. The item has no effect on you if your Strength without the belt is equal to or greater than 25.'),
      _mi(name: 'Belt of Giant Strength (Cloud)', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, activation: 'None', effects: 'While wearing this belt, your Strength score changes to 27. The item has no effect on you if your Strength without the belt is equal to or greater than 27.'),
      _mi(name: 'Belt of Giant Strength (Storm)', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, activation: 'None', effects: 'While wearing this belt, your Strength score changes to 29. The item has no effect on you if your Strength without the belt is equal to or greater than 29.'),
      _mi(name: 'Helm of Brilliance', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'Magic Action', effects: 'This dazzling helm is set with 1d10 diamonds, 2d10 rubies, 3d10 fire opals, and 4d10 opals. While wearing it, you gain Daylight (1/day, no Concentration), Fireball (DC 18, expends a fire opal), Prismatic Spray (1/day, expends a diamond), Wall of Fire (DC 18, no Concentration, expends a ruby).'),
      _mi(name: 'Helm of Teleportation', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'Magic Action', maxCharges: 3, chargeRegain: '1d3 daily at dawn', effects: 'This helm has 3 charges. While wearing it, you can expend 1 charge as a Magic action to cast Teleport from it. The helm regains 1d3 expended charges daily at dawn.'),
      _mi(name: 'Robe of Scintillating Colors', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: true, activation: 'Magic Action', maxCharges: 3, chargeRegain: '1d3 daily at dawn', effects: 'This robe has 3 charges, and it regains 1d3 expended charges daily at dawn. While you wear it, you can take a Magic action and expend 1 charge to cause the garment to display a swirling pattern of dazzling colors until the end of your next turn. During this time, the robe sheds Bright Light in a 30-foot radius and Dim Light for an additional 30 feet. Creatures that can see you have Disadvantage on attack rolls against you. In addition, any creature in the Bright Light that can see you when the robe\'s power is activated must succeed on a DC 15 Wisdom save or have the Stunned condition until the effect ends.'),
      _mi(name: 'Robe of the Magi', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, attunementPrereq: 'Bard, Cleric, Druid, Sorcerer, Warlock, or Wizard', activation: 'None', effects: 'This elegant garment grants the following benefits while you wear it: Advantage on saving throws against spells and other magical effects, +2 bonus to AC and to saving throws, +2 bonus to spell save DCs and spell attack rolls.'),
      _mi(name: 'Mirror of Mental Prowess', category: 'Wondrous Items', rarity: 'Legendary', requiresAttunement: true, activation: 'Magic Action', effects: 'A 4-foot-tall mirror. While touching it, you can take a Magic action to cast Detect Thoughts on yourself, gain the benefit of a Scrying spell once per day, or step through the mirror to a location you have seen, exiting through any other Mirror of Mental Prowess.'),
      _mi(name: 'Carpet of Flying', category: 'Wondrous Items', rarity: 'Very Rare', requiresAttunement: false, activation: 'Magic Action', effects: 'You can speak the carpet\'s command word as a Magic action to make the carpet hover and fly. The carpet\'s Fly Speed depends on its size: 3×5 ft (Fly 80, capacity 200 lb), 4×6 ft (Fly 60, 400 lb), 5×7 ft (Fly 40, 600 lb), 6×9 ft (Fly 30, 800 lb).'),
      _mi(name: 'Mantle of the Champion', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, activation: 'None', effects: 'While wearing this cloak, you have Advantage on Strength saving throws and Charisma (Performance) checks.'),
      _mi(name: 'Necklace of Prayer Beads', category: 'Wondrous Items', rarity: 'Rare', requiresAttunement: true, attunementPrereq: 'Cleric, Druid, or Paladin', activation: 'Bonus Action', effects: 'This necklace has 1d4 + 2 magic beads. Each bead is one of the following kinds: Bead of Blessing (Bless, no Concentration, 1/day), Bead of Curing (Cure Wounds, level 2, 2/day), Bead of Favor (Greater Restoration, 1/day), Bead of Karma (Wisdom +4 for 10 min, 1/day), Bead of Smiting (Branding Smite, level 5, 1/day), Bead of Summons (summon a celestial CR 4 or lower, 1/week), Bead of Wind Walking (Wind Walk, 1/day).'),
      _mi(name: 'Restorative Ointment', category: 'Wondrous Items', rarity: 'Uncommon', requiresAttunement: false, activation: 'Magic Action', effects: 'A jar holds 1d4 + 1 doses. As a Magic action, you can apply a dose: it heals 2d8 + 2 HP and ends the Diseased and Poisoned conditions on the target. Or you can spread a dose on a weapon or piece of ammunition: the next attack with that weapon deals an extra 2d8 Radiant damage if it hits.'),
    ];
