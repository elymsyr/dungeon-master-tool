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
    'rarity_ref': lookup('rarity', rarity),
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
    ];
