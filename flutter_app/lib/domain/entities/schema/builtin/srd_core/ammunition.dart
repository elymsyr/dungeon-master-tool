// SRD 5.2.1 Ammunition (table p. 96). Each row reflects one bundle (the
// canonical pack size SRD lists). cost_gp converted from SRD list price.
// Schema: ammunition has storage_container, cost_gp, weight_lb, bundle_count.

import '_helpers.dart';

const _slug = 'ammunition';

Map<String, dynamic> _ammo({
  required String name,
  required String storage,
  required double costGp,
  required double weightLb,
  required int bundleCount,
}) {
  return packEntity(
    slug: _slug,
    name: name,
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
      _ammo(name: 'Arrows', storage: 'Quiver',
          costGp: 1, weightLb: 1, bundleCount: 20),
      _ammo(name: 'Bolts', storage: 'Case',
          costGp: 1, weightLb: 1.5, bundleCount: 20),
      _ammo(name: 'Bullets, Firearm', storage: 'Pouch',
          costGp: 3, weightLb: 2, bundleCount: 20),
      _ammo(name: 'Bullets, Sling', storage: 'Pouch',
          costGp: 0.04, weightLb: 1.5, bundleCount: 20),
      _ammo(name: 'Needles', storage: 'Pouch',
          costGp: 1, weightLb: 1, bundleCount: 50),
    ];
