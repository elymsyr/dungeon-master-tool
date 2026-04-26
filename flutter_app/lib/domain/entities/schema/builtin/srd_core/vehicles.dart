// SRD 5.2.1 Vehicles. Land vehicles (Tack/Harness + Drawn Vehicles table
// p. 100): Carriage, Cart, Chariot, Sled, Wagon. Waterborne (Airborne &
// Waterborne Vehicles table p. 101): Airship, Galley, Keelboat, Longship,
// Rowboat, Sailing Ship, Warship.

import '_helpers.dart';

const _slug = 'vehicle';

Map<String, dynamic> _v({
  required String name,
  required String kind, // 'Land' | 'Waterborne' | 'Airborne'
  double? speedMph,
  int? crew,
  int? passengers,
  double? cargoTons,
  int? ac,
  int? hp,
  int? damageThreshold,
  int? costGp,
}) {
  final attrs = <String, dynamic>{'vehicle_kind': kind};
  if (speedMph != null) attrs['speed_mph'] = speedMph;
  if (crew != null) attrs['crew'] = crew;
  if (passengers != null) attrs['passengers'] = passengers;
  if (cargoTons != null) attrs['cargo_tons'] = cargoTons;
  if (ac != null) attrs['ac'] = ac;
  if (hp != null) attrs['hp'] = hp;
  if (damageThreshold != null) attrs['damage_threshold'] = damageThreshold;
  if (costGp != null) attrs['cost_gp'] = costGp;
  return packEntity(slug: _slug, name: name, attributes: attrs);
}

/// SRD 5.2.1 vehicles. Land speeds left blank (the SRD defers to the pulling
/// animal's speed); only ships carry mph.
List<Map<String, dynamic>> srdVehicles() => [
      // Land — Tack/Harness + Drawn Vehicles table p. 100.
      _v(name: 'Carriage', kind: 'Land', costGp: 100),
      _v(name: 'Cart', kind: 'Land', costGp: 15),
      _v(name: 'Chariot', kind: 'Land', costGp: 250),
      _v(name: 'Sled', kind: 'Land', costGp: 20),
      _v(name: 'Wagon', kind: 'Land', costGp: 35),

      // Waterborne — Airborne and Waterborne Vehicles table p. 101.
      _v(name: 'Galley', kind: 'Waterborne', speedMph: 4, crew: 80,
          cargoTons: 150, ac: 15, hp: 500,
          damageThreshold: 20, costGp: 30000),
      _v(name: 'Keelboat', kind: 'Waterborne', speedMph: 1, crew: 1,
          passengers: 6, cargoTons: 0.5, ac: 15, hp: 100,
          damageThreshold: 10, costGp: 3000),
      _v(name: 'Longship', kind: 'Waterborne', speedMph: 3, crew: 40,
          passengers: 150, cargoTons: 10, ac: 15, hp: 300,
          damageThreshold: 15, costGp: 10000),
      _v(name: 'Rowboat', kind: 'Waterborne', speedMph: 1.5, crew: 1,
          passengers: 3, ac: 11, hp: 50, costGp: 50),
      _v(name: 'Sailing Ship', kind: 'Waterborne', speedMph: 2, crew: 20,
          passengers: 20, cargoTons: 100, ac: 15, hp: 300,
          damageThreshold: 15, costGp: 10000),
      _v(name: 'Warship', kind: 'Waterborne', speedMph: 2.5, crew: 60,
          passengers: 60, cargoTons: 200, ac: 15, hp: 500,
          damageThreshold: 20, costGp: 25000),

      // Airborne — Airborne and Waterborne Vehicles table p. 101.
      _v(name: 'Airship', kind: 'Airborne', speedMph: 8, crew: 10,
          passengers: 20, cargoTons: 1, ac: 13, hp: 300, costGp: 40000),
    ];
