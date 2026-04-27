// SRD 5.2.1 Armor (p. 92 armor table). Don/doff times derive from sub-table
// header. Light = 1 min, Medium = 5 min don / 1 min doff, Heavy = 10 min don /
// 5 min doff. Shield don/doff is a Utilize action so it shows as 0 minutes.

import '_helpers.dart';

const _slug = 'armor';

Map<String, dynamic> _a({
  required String name,
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
    'category_ref': category,
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
  return packEntity(slug: _slug, name: name, attributes: attrs);
}

/// Hand-authored armor rows from SRD 5.2.1 p. 92.
List<Map<String, dynamic>> srdArmor() => [
      // Light Armor — 1 min don / 1 min doff.
      _a(name: 'Padded Armor', category: 'Light', baseAc: 11, addsDex: true,
          stealthDis: true,
          donMin: 1, doffMin: 1, costGp: 5, weightLb: 8),
      _a(name: 'Leather Armor', category: 'Light', baseAc: 11, addsDex: true,
          stealthDis: false,
          donMin: 1, doffMin: 1, costGp: 10, weightLb: 10),
      _a(name: 'Studded Leather Armor', category: 'Light',
          baseAc: 12, addsDex: true, stealthDis: false,
          donMin: 1, doffMin: 1, costGp: 45, weightLb: 13),

      // Medium Armor — 5 min don / 1 min doff. Dex cap +2.
      _a(name: 'Hide Armor', category: 'Medium', baseAc: 12, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 10, weightLb: 12),
      _a(name: 'Chain Shirt', category: 'Medium', baseAc: 13, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 50, weightLb: 20),
      _a(name: 'Scale Mail', category: 'Medium', baseAc: 14, addsDex: true,
          dexCap: 2, stealthDis: true,
          donMin: 5, doffMin: 1, costGp: 50, weightLb: 45),
      _a(name: 'Breastplate', category: 'Medium', baseAc: 14, addsDex: true,
          dexCap: 2, stealthDis: false,
          donMin: 5, doffMin: 1, costGp: 400, weightLb: 20),
      _a(name: 'Half Plate Armor', category: 'Medium',
          baseAc: 15, addsDex: true, dexCap: 2, stealthDis: true,
          donMin: 5, doffMin: 1, costGp: 750, weightLb: 40),

      // Heavy Armor — 10 min don / 5 min doff. No Dex.
      _a(name: 'Ring Mail', category: 'Heavy', baseAc: 14, addsDex: false,
          stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 30, weightLb: 40),
      _a(name: 'Chain Mail', category: 'Heavy', baseAc: 16, addsDex: false,
          strReq: 13, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 75, weightLb: 55),
      _a(name: 'Splint Armor', category: 'Heavy',
          baseAc: 17, addsDex: false, strReq: 15, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 200, weightLb: 60),
      _a(name: 'Plate Armor', category: 'Heavy',
          baseAc: 18, addsDex: false, strReq: 15, stealthDis: true,
          donMin: 10, doffMin: 5, costGp: 1500, weightLb: 65),

      // Shield — Utilize action; encoded as 0 minutes.
      _a(name: 'Shield', category: 'Shield', baseAc: 2, addsDex: false,
          stealthDis: false,
          donMin: 0, doffMin: 0, costGp: 10, weightLb: 6),
    ];
