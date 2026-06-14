// SRD 5.2.1 Armor (p. 92 armor table). Don/doff times derive from sub-table
// header. Light = 1 min, Medium = 5 min don / 1 min doff, Heavy = 10 min don /
// 5 min doff. Shield don/doff is a Utilize action so it shows as 0 minutes.
//
// Each row also carries a complete, player-facing Markdown `description`
// (master-roadmap §4.1 item form: intro -> `### Properties` -> `### When
// Equipped`). The prose is provably additive: stripping every `description`
// back to '' reproduces the original card byte-for-byte, so no mechanical
// field is touched. The AC formula, Strength requirement, Stealth
// disadvantage and don/doff times are restated in plain language so a player
// can equip any piece correctly from the card text alone.

import '_helpers.dart';

const _slug = 'armor';

Map<String, dynamic> _a({
  required String name,
  required String description,
  required String category, // 'Light' | 'Medium' | 'Heavy' | 'Shield'
  required int baseAc,
  required bool addsDex,
  int? dexCap,
  int? strReq,
  required bool stealthDis,
  required int donMin,
  required int doffMin,
  required double costGp,
  required double weightLb,
}) {
  final attrs = <String, dynamic>{
    'category_ref': lookup('armor-category', category),
    'base_ac': baseAc,
    'adds_dex': addsDex,
    'stealth_disadvantage': stealthDis,
    'don_time_minutes': donMin,
    'doff_time_minutes': doffMin,
    'cost_gp': costGp,
    'weight_lb': weightLb,
  };
  if (dexCap != null) attrs['dex_cap'] = dexCap;
  if (strReq != null) attrs['strength_requirement'] = strReq;
  return packEntity(
      slug: _slug, name: name, description: description, attributes: attrs);
}

/// Hand-authored armor rows from SRD 5.2.1 p. 92.
List<Map<String, dynamic>> srdArmor() => [
      // Light Armor — 1 min don / 1 min doff.
      _a(
          name: 'Padded Armor',
          description: r'''
Padded armor is made of quilted layers of cloth and batting — cheap, light protection that grows stifling on a long march.

### Properties
- **Category:** Light Armor
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 1 minute to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **11 + your full Dexterity modifier** (no maximum) while you wear this armor.

**Cost:** 5 gp  ·  **Weight:** 8 lb
''',
          category: 'Light', baseAc: 11, addsDex: true,
          stealthDis: true,
          donMin: 1, doffMin: 1, costGp: 5, weightLb: 8),
      _a(
          name: 'Leather Armor',
          description: r'''
Leather armor is fashioned from stiffened, boiled leather over softer hide, guarding the vital areas while leaving you nimble.

### Properties
- **Category:** Light Armor
- **Don / Doff:** 1 minute to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **11 + your full Dexterity modifier** (no maximum) while you wear this armor.

**Cost:** 10 gp  ·  **Weight:** 10 lb
''',
          category: 'Light', baseAc: 11, addsDex: true,
          stealthDis: false,
          donMin: 1, doffMin: 1, costGp: 10, weightLb: 10),
      _a(
          name: 'Studded Leather Armor',
          description: r'''
Studded leather is reinforced with close-set rivets or spikes, adding protection without sacrificing the freedom of light armor.

### Properties
- **Category:** Light Armor
- **Don / Doff:** 1 minute to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **12 + your full Dexterity modifier** (no maximum) while you wear this armor.

**Cost:** 45 gp  ·  **Weight:** 13 lb
''',
          category: 'Light',
          baseAc: 12, addsDex: true, stealthDis: false,
          donMin: 1, doffMin: 1, costGp: 45, weightLb: 13),

      // Medium Armor — 5 min don / 1 min doff. Dex cap +2.
      _a(
          name: 'Hide Armor',
          description: r'''
Hide armor is crude protection of thick furs and pelts, favored by those who lack access to worked metal.

### Properties
- **Category:** Medium Armor
- **Don / Doff:** 5 minutes to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **12 + your Dexterity modifier (maximum +2)** while you wear this armor.

**Cost:** 10 gp  ·  **Weight:** 12 lb
''',
          category: 'Medium', baseAc: 12, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 10, weightLb: 12),
      _a(
          name: 'Chain Shirt',
          description: r'''
A chain shirt of interlocking metal rings is worn between layers of clothing or leather, offering solid protection while staying easy to conceal.

### Properties
- **Category:** Medium Armor
- **Don / Doff:** 5 minutes to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **13 + your Dexterity modifier (maximum +2)** while you wear this armor.

**Cost:** 50 gp  ·  **Weight:** 20 lb
''',
          category: 'Medium', baseAc: 13, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 50, weightLb: 20),
      _a(
          name: 'Scale Mail',
          description: r'''
Scale mail is a coat and leggings of overlapping metal scales — sturdy, but it rattles and clatters with every movement.

### Properties
- **Category:** Medium Armor
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 5 minutes to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **14 + your Dexterity modifier (maximum +2)** while you wear this armor.

**Cost:** 50 gp  ·  **Weight:** 45 lb
''',
          category: 'Medium', baseAc: 14, addsDex: true,
          dexCap: 2, stealthDis: true,
          donMin: 5, doffMin: 1, costGp: 50, weightLb: 45),
      _a(
          name: 'Breastplate',
          description: r'''
A breastplate is a fitted metal chestpiece worn over supple leather, guarding the vitals while leaving the limbs free and quiet.

### Properties
- **Category:** Medium Armor
- **Don / Doff:** 5 minutes to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **14 + your Dexterity modifier (maximum +2)** while you wear this armor.

**Cost:** 400 gp  ·  **Weight:** 20 lb
''',
          category: 'Medium', baseAc: 14, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 400, weightLb: 20),
      _a(
          name: 'Half Plate Armor',
          description: r'''
Half plate consists of shaped metal plates covering most of the body, stopping short of the full leg protection of plate armor.

### Properties
- **Category:** Medium Armor
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 5 minutes to put on, 1 minute to take off.

### When Equipped
- Your Armor Class becomes **15 + your Dexterity modifier (maximum +2)** while you wear this armor.

**Cost:** 750 gp  ·  **Weight:** 40 lb
''',
          category: 'Medium',
          baseAc: 15, addsDex: true, dexCap: 2, stealthDis: true,
          donMin: 5, doffMin: 1, costGp: 750, weightLb: 40),

      // Heavy Armor — 10 min don / 5 min doff. No Dex.
      _a(
          name: 'Ring Mail',
          description: r'''
Ring mail is leather armor studded with heavy rings sewn into it — a cheaper, clumsier cousin of true chain, usually worn by those who can't afford better.

### Properties
- **Category:** Heavy Armor
- **Dexterity:** Your Dexterity modifier does **not** apply to your Armor Class in this armor.
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 10 minutes to put on, 5 minutes to take off.

### When Equipped
- Your Armor Class becomes a flat **14** while you wear this armor.

**Cost:** 30 gp  ·  **Weight:** 40 lb
''',
          category: 'Heavy', baseAc: 14, addsDex: false,
          stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 30, weightLb: 40),
      _a(
          name: 'Chain Mail',
          description: r'''
Chain mail is a full suit of interlocking metal rings worn over a layer of padding, trading agility for heavy, dependable protection.

### Properties
- **Category:** Heavy Armor
- **Dexterity:** Your Dexterity modifier does **not** apply to your Armor Class in this armor.
- **Strength:** Requires Strength 13. If your Strength is lower, your speed is reduced by 10 feet while you wear it.
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 10 minutes to put on, 5 minutes to take off.

### When Equipped
- Your Armor Class becomes a flat **16** while you wear this armor.

**Cost:** 75 gp  ·  **Weight:** 55 lb
''',
          category: 'Heavy', baseAc: 16, addsDex: false,
          strReq: 13, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 75, weightLb: 55),
      _a(
          name: 'Splint Armor',
          description: r'''
Splint armor is made of narrow vertical strips of metal riveted to a leather backing and worn over cloth padding, covering the joints with supple chain.

### Properties
- **Category:** Heavy Armor
- **Dexterity:** Your Dexterity modifier does **not** apply to your Armor Class in this armor.
- **Strength:** Requires Strength 15. If your Strength is lower, your speed is reduced by 10 feet while you wear it.
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 10 minutes to put on, 5 minutes to take off.

### When Equipped
- Your Armor Class becomes a flat **17** while you wear this armor.

**Cost:** 200 gp  ·  **Weight:** 60 lb
''',
          category: 'Heavy',
          baseAc: 17, addsDex: false, strReq: 15, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 200, weightLb: 60),
      _a(
          name: 'Plate Armor',
          description: r'''
Plate armor is a full suit of shaped, interlocking metal that encases the entire body — the finest protection money can buy, complete with padded gauntlets, greaves, and a visored helm.

### Properties
- **Category:** Heavy Armor
- **Dexterity:** Your Dexterity modifier does **not** apply to your Armor Class in this armor.
- **Strength:** Requires Strength 15. If your Strength is lower, your speed is reduced by 10 feet while you wear it.
- **Stealth:** You have Disadvantage on Dexterity (Stealth) checks while you wear this armor.
- **Don / Doff:** 10 minutes to put on, 5 minutes to take off.

### When Equipped
- Your Armor Class becomes a flat **18** while you wear this armor.

**Cost:** 1,500 gp  ·  **Weight:** 65 lb
''',
          category: 'Heavy',
          baseAc: 18, addsDex: false, strReq: 15, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 1500, weightLb: 65),

      // Shield — Utilize action; encoded as 0 minutes.
      _a(
          name: 'Shield',
          description: r'''
A shield is a board of wood or metal carried in one hand, raised to turn aside blows. You can benefit from only one shield at a time.

### Properties
- **Category:** Shield
- **Hands:** Wielding a shield occupies one hand, leaving you only one free for weapons or other gear.
- **Don / Doff:** Donned or doffed with a Utilize action — no minutes required.

### When Equipped
- While you wield this shield, you gain a **+2 bonus to Armor Class**, added on top of the protection from your armor.

**Cost:** 10 gp  ·  **Weight:** 6 lb
''',
          category: 'Shield', baseAc: 2, addsDex: false,
          stealthDis: false,
          donMin: 0, doffMin: 0, costGp: 10, weightLb: 6),
    ];
