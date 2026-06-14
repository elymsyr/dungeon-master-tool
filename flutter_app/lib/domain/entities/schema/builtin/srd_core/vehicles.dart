// SRD 5.2.1 Vehicles. Land vehicles (Tack/Harness + Drawn Vehicles table
// p. 100): Carriage, Cart, Chariot, Sled, Wagon. Waterborne (Airborne &
// Waterborne Vehicles table p. 101): Airship, Galley, Keelboat, Longship,
// Rowboat, Sailing Ship, Warship.

import '_helpers.dart';

const _slug = 'vehicle';

Map<String, dynamic> _v({
  required String name,
  required String description,
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
  return packEntity(
      slug: _slug, name: name, description: description, attributes: attrs);
}

/// Builds the player-facing Markdown for a land vehicle (pulled by an animal,
/// so it carries no speed/AC/HP of its own — those come from the team).
String _land(String name, String flavor, int costGp) => '''
**$name.**

$flavor

**Using it:**
- A **land vehicle** has no speed of its own — it moves at the **speed of the animal team** pulling it (you'll also need the right Tack & Harness and a mount or draft animal).
- Use it to **haul cargo and passengers** over roads and open ground far more easily than on foot.

**Cost:** $costGp gp
''';

/// Builds the player-facing Markdown for a ship (waterborne or airborne),
/// which has its own speed and combat stats.
String _ship(
  String name,
  String flavor,
  String kind, {
  required double speedMph,
  required int crew,
  int? passengers,
  double? cargoTons,
  required int ac,
  required int hp,
  int? damageThreshold,
  required int costGp,
}) {
  final lines = <String>[
    '- **Type:** $kind vehicle.',
    '- **Speed:** $speedMph mph while crewed and under way.',
    '- **Crew needed:** $crew — the ship can only move and fight with enough hands aboard.',
    if (passengers != null) '- **Passengers:** up to $passengers.',
    if (cargoTons != null) '- **Cargo:** up to $cargoTons tons of goods.',
    '- **Armor Class:** $ac, **Hit Points:** $hp — attacks against the vessel use these.',
    if (damageThreshold != null)
      '- **Damage Threshold:** $damageThreshold — the ship ignores any single hit that deals less than this much damage.',
  ].join('\n');
  return '''
**$name.**

$flavor

**As a vessel:**
$lines

**Cost:** $costGp gp
''';
}

/// SRD 5.2.1 vehicles. Land speeds left blank (the SRD defers to the pulling
/// animal's speed); only ships carry mph.
List<Map<String, dynamic>> srdVehicles() => [
      // Land — Tack/Harness + Drawn Vehicles table p. 100.
      _v(
          name: 'Carriage',
          description: _land('Carriage',
              'An enclosed, four-wheeled passenger vehicle for comfortable road travel.',
              100),
          kind: 'Land', costGp: 100),
      _v(
          name: 'Cart',
          description: _land('Cart',
              'A small two-wheeled vehicle for hauling modest loads of goods.',
              15),
          kind: 'Land', costGp: 15),
      _v(
          name: 'Chariot',
          description: _land('Chariot',
              'A light, fast two-wheeled platform built for racing and battle.',
              250),
          kind: 'Land', costGp: 250),
      _v(
          name: 'Sled',
          description: _land('Sled',
              'A runnered vehicle for crossing snow and ice where wheels would bog down.',
              20),
          kind: 'Land', costGp: 20),
      _v(
          name: 'Wagon',
          description: _land('Wagon',
              'A large four-wheeled vehicle for hauling heavy cargo over long distances.',
              35),
          kind: 'Land', costGp: 35),

      // Waterborne — Airborne and Waterborne Vehicles table p. 101.
      _v(
          name: 'Galley',
          description: _ship('Galley',
              'A large oared warship, fast and heavily crewed for ramming and boarding.',
              'Waterborne',
              speedMph: 4, crew: 80, cargoTons: 150, ac: 15, hp: 500,
              damageThreshold: 20, costGp: 30000),
          kind: 'Waterborne', speedMph: 4, crew: 80,
          cargoTons: 150, ac: 15, hp: 500,
          damageThreshold: 20, costGp: 30000),
      _v(
          name: 'Keelboat',
          description: _ship('Keelboat',
              'A small, shallow-draft boat for rivers, lakes, and coastal waters.',
              'Waterborne',
              speedMph: 1, crew: 1, passengers: 6, cargoTons: 0.5, ac: 15,
              hp: 100, damageThreshold: 10, costGp: 3000),
          kind: 'Waterborne', speedMph: 1, crew: 1,
          passengers: 6, cargoTons: 0.5, ac: 15, hp: 100,
          damageThreshold: 10, costGp: 3000),
      _v(
          name: 'Longship',
          description: _ship('Longship',
              'A sleek, oared raiding ship that can carry a large war band along coasts and up rivers.',
              'Waterborne',
              speedMph: 3, crew: 40, passengers: 150, cargoTons: 10, ac: 15,
              hp: 300, damageThreshold: 15, costGp: 10000),
          kind: 'Waterborne', speedMph: 3, crew: 40,
          passengers: 150, cargoTons: 10, ac: 15, hp: 300,
          damageThreshold: 15, costGp: 10000),
      _v(
          name: 'Rowboat',
          description: _ship('Rowboat',
              'A tiny boat rowed by hand — perfect for ferrying a few people to shore or between ships.',
              'Waterborne',
              speedMph: 1.5, crew: 1, passengers: 3, ac: 11, hp: 50,
              costGp: 50),
          kind: 'Waterborne', speedMph: 1.5, crew: 1,
          passengers: 3, ac: 11, hp: 50, costGp: 50),
      _v(
          name: 'Sailing Ship',
          description: _ship('Sailing Ship',
              'A reliable seagoing merchant vessel driven by sail, suited to ocean voyages and cargo runs.',
              'Waterborne',
              speedMph: 2, crew: 20, passengers: 20, cargoTons: 100, ac: 15,
              hp: 300, damageThreshold: 15, costGp: 10000),
          kind: 'Waterborne', speedMph: 2, crew: 20,
          passengers: 20, cargoTons: 100, ac: 15, hp: 300,
          damageThreshold: 15, costGp: 10000),
      _v(
          name: 'Warship',
          description: _ship('Warship',
              'A heavy sailed combat vessel built to carry a large crew and trade broadsides at sea.',
              'Waterborne',
              speedMph: 2.5, crew: 60, passengers: 60, cargoTons: 200, ac: 15,
              hp: 500, damageThreshold: 20, costGp: 25000),
          kind: 'Waterborne', speedMph: 2.5, crew: 60,
          passengers: 60, cargoTons: 200, ac: 15, hp: 500,
          damageThreshold: 20, costGp: 25000),

      // Airborne — Airborne and Waterborne Vehicles table p. 101.
      _v(
          name: 'Airship',
          description: _ship('Airship',
              'A magical flying vessel that sails through the sky, ignoring terrain below.',
              'Airborne',
              speedMph: 8, crew: 10, passengers: 20, cargoTons: 1, ac: 13,
              hp: 300, costGp: 40000),
          kind: 'Airborne', speedMph: 8, crew: 10,
          passengers: 20, cargoTons: 1, ac: 13, hp: 300, costGp: 40000),
    ];
