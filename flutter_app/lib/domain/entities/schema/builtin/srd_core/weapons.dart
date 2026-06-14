// SRD 5.2.1 Weapons (p. 91 weapons table; properties/masteries on Tier-0
// already; ammunition rows authored in ammunition.dart).
//
// Each row carries every fieldKey from the `weapon` Tier-1 schema in
// content.dart:533-566. References to Tier-0 lookups use `lookup(slug, name)`
// placeholders and are resolved at import time.
//
// Each row also carries a complete, player-facing Markdown `description`
// (master-roadmap §4.1 item form: intro -> `### Properties` -> `### When
// Equipped`). The prose is provably additive: stripping every `description`
// arg back out (and reverting the `_w` signature + packEntity call) reproduces
// the original card byte-for-byte, so no mechanical field is touched. Damage,
// range, each weapon Property and Mastery, and the attack ability are restated
// in plain language so a player can use any weapon correctly from the card
// text alone. (Wave 2 description half; the `when_equipped`/`prereq_to_equip`
// template rules for armor/weapons are authored separately in the template
// JSON.)

import '_helpers.dart';

const _slug = 'weapon';

Map<String, dynamic> _w({
  required String name,
  required String description,
  required String category, // 'Simple' | 'Martial'
  required bool melee,
  required String dice,
  required String dmgType,
  required List<String> properties,
  required String mastery,
  required double costGp,
  required double weightLb,
  int? normalRangeFt,
  int? longRangeFt,
  String? versatileDice,
  String? ammoType, // ammunition row name (e.g. "Arrows")
}) {
  final attrs = <String, dynamic>{
    'category_ref': lookup('weapon-category', '$category ${melee ? "Melee" : "Ranged"}'),
    'is_melee': melee,
    'damage_dice': dice,
    'damage_type_ref': lookup('damage-type', dmgType),
    'property_refs':
        properties.map((p) => lookup('weapon-property', p)).toList(),
    'mastery_ref': lookup('weapon-mastery', mastery),
    'cost_gp': costGp,
    'weight_lb': weightLb,
  };
  if (normalRangeFt != null) attrs['normal_range_ft'] = normalRangeFt;
  if (longRangeFt != null) attrs['long_range_ft'] = longRangeFt;
  if (versatileDice != null) attrs['versatile_damage_dice'] = versatileDice;
  if (ammoType != null) {
    attrs['ammunition_type_ref'] = ref('ammunition', ammoType);
  }
  return packEntity(
      slug: _slug, name: name, description: description, attributes: attrs);
}

/// Hand-authored weapon rows from SRD 5.2.1 p. 91 weapons table.
List<Map<String, dynamic>> srdWeapons() => [
      // ── Simple Melee Weapons ──────────────────────────────────────
      _w(name: 'Club',
          description: r'''
A simple length of hard wood, the club is the most basic bludgeon — cheap, reliable, and found in nearly any hand.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d4 Bludgeoning
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 1 sp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: true, dice: '1d4',
          dmgType: 'Bludgeoning', properties: ['Light'], mastery: 'Slow',
          costGp: 0.1, weightLb: 2),
      _w(name: 'Dagger',
          description: r'''
A short, light blade balanced for both close work and throwing, the dagger is the most versatile of the simple weapons.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d4 Piercing
- **Range:** 20 ft normal / 60 ft long
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Nick.** When you make the extra attack of the Light property, you can make it as part of the Attack action instead of as a Bonus Action — but only once per turn.

### When Equipped
- You attack with this weapon using your **Strength or Dexterity** modifier (your choice) for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 2 gp  ·  **Weight:** 1 lb
''', category: 'Simple', melee: true, dice: '1d4',
          dmgType: 'Piercing',
          properties: ['Finesse', 'Light', 'Thrown'], mastery: 'Nick',
          costGp: 2, weightLb: 1, normalRangeFt: 20, longRangeFt: 60),
      _w(name: 'Greatclub',
          description: r'''
A massive, two-handed cudgel of solid wood that brings crushing force down on a single foe.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d8 Bludgeoning
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Push.** If you hit a creature with this weapon, you can push it up to 10 feet straight away from you if it is Large or smaller.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 2 sp  ·  **Weight:** 10 lb
''', category: 'Simple', melee: true, dice: '1d8',
          dmgType: 'Bludgeoning', properties: ['Two-Handed'], mastery: 'Push',
          costGp: 0.2, weightLb: 10),
      _w(name: 'Handaxe',
          description: r'''
A compact axe light enough to throw, favored by skirmishers who close and harry.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d6 Slashing
- **Range:** 20 ft normal / 60 ft long
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 gp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: true, dice: '1d6',
          dmgType: 'Slashing', properties: ['Light', 'Thrown'], mastery: 'Vex',
          costGp: 5, weightLb: 2, normalRangeFt: 20, longRangeFt: 60),
      _w(name: 'Javelin',
          description: r'''
A slender throwing spear designed to be hurled at range, though it serves in melee at need.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d6 Piercing
- **Range:** 30 ft normal / 120 ft long
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 sp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: true, dice: '1d6',
          dmgType: 'Piercing', properties: ['Thrown'], mastery: 'Slow',
          costGp: 0.5, weightLb: 2, normalRangeFt: 30, longRangeFt: 120),
      _w(name: 'Light Hammer',
          description: r'''
A small, balanced hammer light enough to fling or pair with a second weapon.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d4 Bludgeoning
- **Range:** 20 ft normal / 60 ft long
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Nick.** When you make the extra attack of the Light property, you can make it as part of the Attack action instead of as a Bonus Action — but only once per turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 2 gp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: true, dice: '1d4',
          dmgType: 'Bludgeoning',
          properties: ['Light', 'Thrown'], mastery: 'Nick',
          costGp: 2, weightLb: 2, normalRangeFt: 20, longRangeFt: 60),
      _w(name: 'Mace',
          description: r'''
A flanged metal head on a sturdy haft, the mace crushes armor and bone alike.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d6 Bludgeoning
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 gp  ·  **Weight:** 4 lb
''', category: 'Simple', melee: true, dice: '1d6',
          dmgType: 'Bludgeoning', properties: [], mastery: 'Sap',
          costGp: 5, weightLb: 4),
      _w(name: 'Quarterstaff',
          description: r'''
A stout wooden staff that can be gripped in one or both hands for sweeping, off-balancing strikes.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d6 Bludgeoning *(one-handed)* / 1d8 Bludgeoning *(two-handed)*
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Topple.** If you hit a creature with this weapon, you can force it to make a Constitution saving throw (DC 8 + the ability modifier used for the attack + your Proficiency Bonus). On a failure, the creature has the Prone condition.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 2 sp  ·  **Weight:** 4 lb
''', category: 'Simple', melee: true, dice: '1d6',
          dmgType: 'Bludgeoning', properties: ['Versatile'], mastery: 'Topple',
          costGp: 0.2, weightLb: 4, versatileDice: '1d8'),
      _w(name: 'Sickle',
          description: r'''
A short, curved farming blade pressed into service as a quick, light weapon.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d4 Slashing
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Nick.** When you make the extra attack of the Light property, you can make it as part of the Attack action instead of as a Bonus Action — but only once per turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 1 gp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: true, dice: '1d4',
          dmgType: 'Slashing', properties: ['Light'], mastery: 'Nick',
          costGp: 1, weightLb: 2),
      _w(name: 'Spear',
          description: r'''
A versatile shafted point that can be thrown, set against a charge, or gripped two-handed for extra power.

### Properties
- **Category:** Simple Melee Weapon
- **Damage:** 1d6 Piercing *(one-handed)* / 1d8 Piercing *(two-handed)*
- **Range:** 20 ft normal / 60 ft long
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 1 gp  ·  **Weight:** 3 lb
''', category: 'Simple', melee: true, dice: '1d6',
          dmgType: 'Piercing',
          properties: ['Thrown', 'Versatile'], mastery: 'Sap',
          costGp: 1, weightLb: 3,
          normalRangeFt: 20, longRangeFt: 60, versatileDice: '1d8'),

      // ── Simple Ranged Weapons ─────────────────────────────────────
      _w(name: 'Dart',
          description: r'''
A small, finned throwing point — light, cheap, and easy to carry by the handful.

### Properties
- **Category:** Simple Ranged Weapon
- **Damage:** 1d4 Piercing
- **Range:** 20 ft normal / 60 ft long
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 cp  ·  **Weight:** 0.25 lb
''', category: 'Simple', melee: false, dice: '1d4',
          dmgType: 'Piercing',
          properties: ['Finesse', 'Thrown'], mastery: 'Vex',
          costGp: 0.05, weightLb: 0.25,
          normalRangeFt: 20, longRangeFt: 60),
      _w(name: 'Light Crossbow',
          description: r'''
A compact crossbow that braces against the shoulder, trading rate of fire for accuracy.

### Properties
- **Category:** Simple Ranged Weapon
- **Damage:** 1d8 Piercing
- **Range:** 80 ft normal / 320 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bolts** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 25 gp  ·  **Weight:** 5 lb
''', category: 'Simple', melee: false,
          dice: '1d8', dmgType: 'Piercing',
          properties: ['Ammunition', 'Loading', 'Two-Handed'],
          mastery: 'Slow', costGp: 25, weightLb: 5,
          normalRangeFt: 80, longRangeFt: 320, ammoType: 'Bolts'),
      _w(name: 'Shortbow',
          description: r'''
A short, recurved bow that is quick to draw and easy to carry on the move.

### Properties
- **Category:** Simple Ranged Weapon
- **Damage:** 1d6 Piercing
- **Range:** 80 ft normal / 320 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Arrows** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 25 gp  ·  **Weight:** 2 lb
''', category: 'Simple', melee: false, dice: '1d6',
          dmgType: 'Piercing',
          properties: ['Ammunition', 'Two-Handed'], mastery: 'Vex',
          costGp: 25, weightLb: 2,
          normalRangeFt: 80, longRangeFt: 320, ammoType: 'Arrows'),
      _w(name: 'Sling',
          description: r'''
A simple leather strap that whips a bullet or stone to a surprising distance.

### Properties
- **Category:** Simple Ranged Weapon
- **Damage:** 1d4 Bludgeoning
- **Range:** 30 ft normal / 120 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bullets, Sling** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 1 sp  ·  **Weight:** —
''', category: 'Simple', melee: false, dice: '1d4',
          dmgType: 'Bludgeoning', properties: ['Ammunition'], mastery: 'Slow',
          costGp: 0.1, weightLb: 0,
          normalRangeFt: 30, longRangeFt: 120, ammoType: 'Bullets, Sling'),

      // ── Martial Melee Weapons ─────────────────────────────────────
      _w(name: 'Battleaxe',
          description: r'''
A broad-bladed war axe that can be swung in one hand or, gripped in two, with greater force.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Slashing *(one-handed)* / 1d10 Slashing *(two-handed)*
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Topple.** If you hit a creature with this weapon, you can force it to make a Constitution saving throw (DC 8 + the ability modifier used for the attack + your Proficiency Bonus). On a failure, the creature has the Prone condition.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 4 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Slashing', properties: ['Versatile'], mastery: 'Topple',
          costGp: 10, weightLb: 4, versatileDice: '1d10'),
      _w(name: 'Flail',
          description: r'''
A spiked or weighted head on a chain that wraps past shields and guards.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Bludgeoning
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 2 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Bludgeoning', properties: [], mastery: 'Sap',
          costGp: 10, weightLb: 2),
      _w(name: 'Glaive',
          description: r'''
A long polearm topped with a single sweeping blade, striking from a step beyond reach.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d10 Slashing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Reach.** This weapon adds 5 feet to your reach when you attack with it, and when determining your reach for Opportunity Attacks.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Graze.** If your attack roll with this weapon misses, the target still takes damage equal to the ability modifier you used for the attack. This damage is the weapon's damage type and increases only if that modifier increases.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 20 gp  ·  **Weight:** 6 lb
''', category: 'Martial', melee: true, dice: '1d10',
          dmgType: 'Slashing',
          properties: ['Heavy', 'Reach', 'Two-Handed'], mastery: 'Graze',
          costGp: 20, weightLb: 6),
      _w(name: 'Greataxe',
          description: r'''
A huge, two-handed axe built to cleave through armor and carry into a second foe.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d12 Slashing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Cleave.** If you hit a creature with a melee attack using this weapon, you can make a melee attack with it against a second creature within 5 feet of the first that is also within your reach. On a hit, the second creature takes the weapon's damage but you don't add your ability modifier unless it is negative. Usable once per turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 30 gp  ·  **Weight:** 7 lb
''', category: 'Martial', melee: true, dice: '1d12',
          dmgType: 'Slashing',
          properties: ['Heavy', 'Two-Handed'], mastery: 'Cleave',
          costGp: 30, weightLb: 7),
      _w(name: 'Greatsword',
          description: r'''
A massive two-handed blade whose every swing threatens everything within reach.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 2d6 Slashing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Graze.** If your attack roll with this weapon misses, the target still takes damage equal to the ability modifier you used for the attack. This damage is the weapon's damage type and increases only if that modifier increases.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 50 gp  ·  **Weight:** 6 lb
''', category: 'Martial', melee: true, dice: '2d6',
          dmgType: 'Slashing',
          properties: ['Heavy', 'Two-Handed'], mastery: 'Graze',
          costGp: 50, weightLb: 6),
      _w(name: 'Halberd',
          description: r'''
A polearm combining axe blade, spike, and hook, deadly against tight ranks.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d10 Slashing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Reach.** This weapon adds 5 feet to your reach when you attack with it, and when determining your reach for Opportunity Attacks.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Cleave.** If you hit a creature with a melee attack using this weapon, you can make a melee attack with it against a second creature within 5 feet of the first that is also within your reach. On a hit, the second creature takes the weapon's damage but you don't add your ability modifier unless it is negative. Usable once per turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 20 gp  ·  **Weight:** 6 lb
''', category: 'Martial', melee: true, dice: '1d10',
          dmgType: 'Slashing',
          properties: ['Heavy', 'Reach', 'Two-Handed'], mastery: 'Cleave',
          costGp: 20, weightLb: 6),
      _w(name: 'Lance',
          description: r'''
A long, heavy thrusting weapon built for charging from the back of a mount.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d10 Piercing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Reach.** This weapon adds 5 feet to your reach when you attack with it, and when determining your reach for Opportunity Attacks.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Topple.** If you hit a creature with this weapon, you can force it to make a Constitution saving throw (DC 8 + the ability modifier used for the attack + your Proficiency Bonus). On a failure, the creature has the Prone condition.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 6 lb
''', category: 'Martial', melee: true, dice: '1d10',
          dmgType: 'Piercing',
          properties: ['Heavy', 'Reach', 'Two-Handed'], mastery: 'Topple',
          costGp: 10, weightLb: 6),
      _w(name: 'Longsword',
          description: r'''
A classic knightly blade, balanced for one hand or two when the shield is set aside.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Slashing *(one-handed)* / 1d10 Slashing *(two-handed)*
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 15 gp  ·  **Weight:** 3 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Slashing', properties: ['Versatile'], mastery: 'Sap',
          costGp: 15, weightLb: 3, versatileDice: '1d10'),
      _w(name: 'Maul',
          description: r'''
An enormous two-handed war hammer that topples even braced defenders.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 2d6 Bludgeoning
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Topple.** If you hit a creature with this weapon, you can force it to make a Constitution saving throw (DC 8 + the ability modifier used for the attack + your Proficiency Bonus). On a failure, the creature has the Prone condition.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 10 lb
''', category: 'Martial', melee: true, dice: '2d6',
          dmgType: 'Bludgeoning',
          properties: ['Heavy', 'Two-Handed'], mastery: 'Topple',
          costGp: 10, weightLb: 10),
      _w(name: 'Morningstar',
          description: r'''
A spiked metal head on a haft, driving piercing points through armor.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Piercing
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 15 gp  ·  **Weight:** 4 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Piercing', properties: [], mastery: 'Sap',
          costGp: 15, weightLb: 4),
      _w(name: 'Pike',
          description: r'''
An extremely long thrusting spear that strikes from well outside an enemy's reach.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d10 Piercing
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Reach.** This weapon adds 5 feet to your reach when you attack with it, and when determining your reach for Opportunity Attacks.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Push.** If you hit a creature with this weapon, you can push it up to 10 feet straight away from you if it is Large or smaller.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 gp  ·  **Weight:** 18 lb
''', category: 'Martial', melee: true, dice: '1d10',
          dmgType: 'Piercing',
          properties: ['Heavy', 'Reach', 'Two-Handed'], mastery: 'Push',
          costGp: 5, weightLb: 18),
      _w(name: 'Rapier',
          description: r'''
A slender, rigid dueling blade rewarding precision and footwork over brute strength.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Piercing
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Strength or Dexterity** modifier (your choice) for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 25 gp  ·  **Weight:** 2 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Piercing', properties: ['Finesse'], mastery: 'Vex',
          costGp: 25, weightLb: 2),
      _w(name: 'Scimitar',
          description: r'''
A curved, light slashing sword quick enough for rapid, flowing strikes.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d6 Slashing
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Nick.** When you make the extra attack of the Light property, you can make it as part of the Attack action instead of as a Bonus Action — but only once per turn.

### When Equipped
- You attack with this weapon using your **Strength or Dexterity** modifier (your choice) for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 25 gp  ·  **Weight:** 3 lb
''', category: 'Martial', melee: true, dice: '1d6',
          dmgType: 'Slashing',
          properties: ['Finesse', 'Light'], mastery: 'Nick',
          costGp: 25, weightLb: 3),
      _w(name: 'Shortsword',
          description: r'''
A light, pointed blade made for fast thrusts and paired fighting.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d6 Piercing
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Strength or Dexterity** modifier (your choice) for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 2 lb
''', category: 'Martial', melee: true, dice: '1d6',
          dmgType: 'Piercing',
          properties: ['Finesse', 'Light'], mastery: 'Vex',
          costGp: 10, weightLb: 2),
      _w(name: 'Trident',
          description: r'''
A three-pronged spear that can be thrown or wielded two-handed for heavier blows.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Piercing *(one-handed)* / 1d10 Piercing *(two-handed)*
- **Range:** 20 ft normal / 60 ft long
- **Thrown.** You can throw this weapon to make a ranged attack, using the same ability modifier you use for a melee attack with it.
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Topple.** If you hit a creature with this weapon, you can force it to make a Constitution saving throw (DC 8 + the ability modifier used for the attack + your Proficiency Bonus). On a failure, the creature has the Prone condition.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 gp  ·  **Weight:** 4 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Piercing',
          properties: ['Thrown', 'Versatile'], mastery: 'Topple',
          costGp: 5, weightLb: 4,
          normalRangeFt: 20, longRangeFt: 60, versatileDice: '1d10'),
      _w(name: 'Warhammer',
          description: r'''
A solid-headed war hammer that can be swung one- or two-handed to drive foes back.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Bludgeoning *(one-handed)* / 1d10 Bludgeoning *(two-handed)*
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Push.** If you hit a creature with this weapon, you can push it up to 10 feet straight away from you if it is Large or smaller.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 15 gp  ·  **Weight:** 5 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Bludgeoning', properties: ['Versatile'], mastery: 'Push',
          costGp: 15, weightLb: 5, versatileDice: '1d10'),
      _w(name: 'War Pick',
          description: r'''
A heavy, beaked hammer designed to punch its point through plate.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d8 Piercing *(one-handed)* / 1d10 Piercing *(two-handed)*
- **Versatile.** You can wield this weapon in one or two hands. Used in two hands, it deals the larger damage die shown above.
- **Sap.** If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn.

### When Equipped
- You attack with this weapon using your **Strength** modifier for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 5 gp  ·  **Weight:** 2 lb
''', category: 'Martial', melee: true, dice: '1d8',
          dmgType: 'Piercing', properties: ['Versatile'], mastery: 'Sap',
          costGp: 5, weightLb: 2, versatileDice: '1d10'),
      _w(name: 'Whip',
          description: r'''
A long, flexible lash that strikes at range and snares off-balance foes.

### Properties
- **Category:** Martial Melee Weapon
- **Damage:** 1d4 Slashing
- **Finesse.** When you attack with this weapon, you choose **Strength or Dexterity** for the attack and damage rolls — use the same modifier for both.
- **Reach.** This weapon adds 5 feet to your reach when you attack with it, and when determining your reach for Opportunity Attacks.
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Strength or Dexterity** modifier (your choice) for both the attack roll and the damage roll.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 2 gp  ·  **Weight:** 3 lb
''', category: 'Martial', melee: true, dice: '1d4',
          dmgType: 'Slashing',
          properties: ['Finesse', 'Reach'], mastery: 'Slow',
          costGp: 2, weightLb: 3),

      // ── Martial Ranged Weapons ────────────────────────────────────
      _w(name: 'Blowgun',
          description: r'''
A hollow tube that propels a single needle with a sharp breath — quiet and easily concealed.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1 (no dice) Piercing
- **Range:** 25 ft normal / 100 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Needles** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 10 gp  ·  **Weight:** 1 lb
''', category: 'Martial', melee: false, dice: '1',
          dmgType: 'Piercing',
          properties: ['Ammunition', 'Loading'], mastery: 'Vex',
          costGp: 10, weightLb: 1,
          normalRangeFt: 25, longRangeFt: 100, ammoType: 'Needles'),
      _w(name: 'Hand Crossbow',
          description: r'''
A small, one-handed crossbow prized by duelists and rogues for its concealability.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1d6 Piercing
- **Range:** 30 ft normal / 120 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Light.** This weapon is small and easy to handle, so it qualifies for two-weapon fighting (a Bonus Action off-hand attack with another Light weapon).
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bolts** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 75 gp  ·  **Weight:** 3 lb
''', category: 'Martial', melee: false,
          dice: '1d6', dmgType: 'Piercing',
          properties: ['Ammunition', 'Light', 'Loading'], mastery: 'Vex',
          costGp: 75, weightLb: 3,
          normalRangeFt: 30, longRangeFt: 120, ammoType: 'Bolts'),
      _w(name: 'Heavy Crossbow',
          description: r'''
A powerful, two-handed crossbow that hits hard at long range but is slow to reload.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1d10 Piercing
- **Range:** 100 ft normal / 400 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Push.** If you hit a creature with this weapon, you can push it up to 10 feet straight away from you if it is Large or smaller.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bolts** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 50 gp  ·  **Weight:** 18 lb
''', category: 'Martial', melee: false,
          dice: '1d10', dmgType: 'Piercing',
          properties: ['Ammunition', 'Heavy', 'Loading', 'Two-Handed'],
          mastery: 'Push', costGp: 50, weightLb: 18,
          normalRangeFt: 100, longRangeFt: 400, ammoType: 'Bolts'),
      _w(name: 'Longbow',
          description: r'''
A tall war bow that reaches astonishing distances in trained hands.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1d8 Piercing
- **Range:** 150 ft normal / 600 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Heavy.** Small creatures have Disadvantage on attack rolls with this weapon because of its size and bulk.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Arrows** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 50 gp  ·  **Weight:** 2 lb
''', category: 'Martial', melee: false, dice: '1d8',
          dmgType: 'Piercing',
          properties: ['Ammunition', 'Heavy', 'Two-Handed'],
          mastery: 'Slow', costGp: 50, weightLb: 2,
          normalRangeFt: 150, longRangeFt: 600, ammoType: 'Arrows'),
      _w(name: 'Musket',
          description: r'''
A long-barreled firearm that fires a single heavy ball with devastating force.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1d12 Piercing
- **Range:** 40 ft normal / 120 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Two-Handed.** You need two free hands to attack with this weapon.
- **Slow.** If you hit a creature with this weapon and deal damage, you reduce its Speed by 10 feet until the start of your next turn. The reduction doesn't stack beyond 10 feet from multiple hits.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bullets, Firearm** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 500 gp  ·  **Weight:** 10 lb
''', category: 'Martial', melee: false, dice: '1d12',
          dmgType: 'Piercing',
          properties: ['Ammunition', 'Loading', 'Two-Handed'],
          mastery: 'Slow', costGp: 500, weightLb: 10,
          normalRangeFt: 40, longRangeFt: 120,
          ammoType: 'Bullets, Firearm'),
      _w(name: 'Pistol',
          description: r'''
A compact firearm that delivers a powerful shot at close range from one hand.

### Properties
- **Category:** Martial Ranged Weapon
- **Damage:** 1d10 Piercing
- **Range:** 30 ft normal / 90 ft long
- **Ammunition.** You can use this weapon to make a ranged attack only if you have ammunition to fire from it. Each attack you make expends one piece, and drawing the ammunition is part of the attack. After a battle you can spend 1 minute to recover half the ammunition you fired (rounded down).
- **Loading.** Because of the time it takes to load, you can fire only one piece of ammunition from it when you take the Attack action, no matter how many attacks you could normally make.
- **Vex.** If you hit a creature with this weapon and deal damage, you have Advantage on your next attack roll against that creature before the end of your next turn.

### When Equipped
- You attack with this weapon using your **Dexterity** modifier for both the attack roll and the damage roll.
- Requires **Bullets, Firearm** to fire; each attack expends one piece.
- The weapon's mastery property applies only while you have a feature (such as Weapon Mastery) that lets you use weapon masteries and you are proficient with this weapon.

**Cost:** 250 gp  ·  **Weight:** 3 lb
''', category: 'Martial', melee: false, dice: '1d10',
          dmgType: 'Piercing',
          properties: ['Ammunition', 'Loading'], mastery: 'Vex',
          costGp: 250, weightLb: 3,
          normalRangeFt: 30, longRangeFt: 90,
          ammoType: 'Bullets, Firearm'),
    ];
