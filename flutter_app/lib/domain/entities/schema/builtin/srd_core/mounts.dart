// SRD 5.2.1 Mounts (p. 100 Mounts and Other Animals table). Speed values
// from the corresponding monster/animal stat blocks (e.g. Mastiff is in
// Animals A-Z; Riding Horse + Warhorse + Draft Horse + Pony are too).

import '_helpers.dart';

const _slug = 'mount';

Map<String, dynamic> _m({
  required String name,
  required int carryLb,
  required int speedFt,
  required int costGp,
  bool trained = true,
}) {
  return packEntity(
    slug: _slug,
    name: name,
    attributes: {
      'carrying_capacity_lb': carryLb,
      'speed_ft': speedFt,
      'cost_gp': costGp,
      'is_trained': trained,
    },
  );
}

/// SRD 5.2.1 mounts and other animals, p. 100 table.
List<Map<String, dynamic>> srdMounts() => [
      _m(name: 'Camel', carryLb: 450, speedFt: 50, costGp: 50),
      _m(name: 'Elephant', carryLb: 1320, speedFt: 40, costGp: 200),
      _m(name: 'Draft Horse', carryLb: 540, speedFt: 40, costGp: 50),
      _m(name: 'Riding Horse', carryLb: 480, speedFt: 60, costGp: 75),
      _m(name: 'Mastiff', carryLb: 195, speedFt: 40, costGp: 25),
      _m(name: 'Mule', carryLb: 420, speedFt: 40, costGp: 8),
      _m(name: 'Pony', carryLb: 225, speedFt: 40, costGp: 30),
      _m(name: 'Warhorse', carryLb: 540, speedFt: 60, costGp: 400),
    ];
