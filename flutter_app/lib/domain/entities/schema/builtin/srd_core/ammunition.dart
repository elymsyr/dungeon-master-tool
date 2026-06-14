// SRD 5.2.1 Ammunition (table p. 96). Each row reflects one bundle (the
// canonical pack size SRD lists). cost_gp converted from SRD list price.
// Schema: ammunition has storage_container, cost_gp, weight_lb, bundle_count.

import '_helpers.dart';

const _slug = 'ammunition';

Map<String, dynamic> _ammo({
  required String name,
  required String description,
  required String storage,
  required double costGp,
  required double weightLb,
  required int bundleCount,
}) {
  return packEntity(
    slug: _slug,
    name: name,
    description: description,
    attributes: {
      'storage_container': storage,
      'cost_gp': costGp,
      'weight_lb': weightLb,
      'bundle_count': bundleCount,
    },
  );
}

/// Hand-authored ammunition rows from SRD 5.2.1 p. 96 ammunition table.
/// Names match the wording weapons reference (Bolts / Arrows / etc.) so
/// `_ref('ammunition', 'Bolts')` resolves.
List<Map<String, dynamic>> srdAmmunition() => [
      _ammo(
          name: 'Arrows',
          description: r'''
**Arrows.**

Ammunition for a Bow. You buy and carry Arrows as a bundle, kept ready in a Quiver.

**How it works:**
- A bundle holds **20 Arrows**, stored in a **Quiver**.
- Each time you attack with a weapon that uses Arrows (such as a Shortbow or Longbow), you spend **one** Arrow from the bundle.
- After a fight, spend 1 minute searching the area to **recover up to half** the Arrows you fired.

**Bundle:** 20  ·  **Stored in:** Quiver  ·  **Cost:** 1 gp  ·  **Weight:** 1 lb
''',
          storage: 'Quiver',
          costGp: 1, weightLb: 1, bundleCount: 20),
      _ammo(
          name: 'Bolts',
          description: r'''
**Bolts.**

Ammunition for a Crossbow. Bolts are bought and carried as a bundle, kept ready in a Case.

**How it works:**
- A bundle holds **20 Bolts**, stored in a **Case**.
- Each time you attack with a Crossbow, you spend **one** Bolt from the bundle.
- After a fight, spend 1 minute searching the area to **recover up to half** the Bolts you fired.

**Bundle:** 20  ·  **Stored in:** Case  ·  **Cost:** 1 gp  ·  **Weight:** 1.5 lb
''',
          storage: 'Case',
          costGp: 1, weightLb: 1.5, bundleCount: 20),
      _ammo(
          name: 'Bullets, Firearm',
          description: r'''
**Bullets, Firearm.**

Ammunition for a Firearm. Bullets are bought and carried as a bundle in a Pouch.

**How it works:**
- A bundle holds **20 Firearm Bullets**, stored in a **Pouch**.
- Each time you attack with a Firearm, you spend **one** Bullet from the bundle.
- Firearm Bullets are destroyed on use and **cannot be recovered** after a fight.

**Bundle:** 20  ·  **Stored in:** Pouch  ·  **Cost:** 3 gp  ·  **Weight:** 2 lb
''',
          storage: 'Pouch',
          costGp: 3, weightLb: 2, bundleCount: 20),
      _ammo(
          name: 'Bullets, Sling',
          description: r'''
**Bullets, Sling.**

Ammunition for a Sling — simple lead or stone shot. Bought and carried as a bundle in a Pouch.

**How it works:**
- A bundle holds **20 Sling Bullets**, stored in a **Pouch**.
- Each time you attack with a Sling, you spend **one** Bullet from the bundle.
- After a fight, spend 1 minute searching the area to **recover up to half** the Bullets you fired.

**Bundle:** 20  ·  **Stored in:** Pouch  ·  **Cost:** 4 cp  ·  **Weight:** 1.5 lb
''',
          storage: 'Pouch',
          costGp: 0.04, weightLb: 1.5, bundleCount: 20),
      _ammo(
          name: 'Needles',
          description: r'''
**Needles.**

Ammunition for a Blowgun. Needles are bought and carried as a bundle in a Pouch.

**How it works:**
- A bundle holds **50 Needles**, stored in a **Pouch**.
- Each time you attack with a Blowgun, you spend **one** Needle from the bundle.
- After a fight, spend 1 minute searching the area to **recover up to half** the Needles you fired.

**Bundle:** 50  ·  **Stored in:** Pouch  ·  **Cost:** 1 gp  ·  **Weight:** 1 lb
''',
          storage: 'Pouch',
          costGp: 1, weightLb: 1, bundleCount: 50),
    ];
