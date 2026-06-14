// SRD 5.2.1 Mounts (p. 100 Mounts and Other Animals table). Speed values
// from the corresponding monster/animal stat blocks (e.g. Mastiff is in
// Animals A-Z; Riding Horse + Warhorse + Draft Horse + Pony are too).

import '_helpers.dart';

const _slug = 'mount';

Map<String, dynamic> _m({
  required String name,
  required String description,
  required int carryLb,
  required int speedFt,
  required int costGp,
  bool trained = true,
}) {
  return packEntity(
    slug: _slug,
    name: name,
    description: description,
    attributes: {
      'carrying_capacity_lb': carryLb,
      'speed_ft': speedFt,
      'cost_gp': costGp,
      'is_trained': trained,
    },
  );
}

String _mount(String name, String flavor, int carry, int speed, int costGp,
        {bool trained = true}) =>
    '''
**$name.**

$flavor

**As a mount:**
- **Speed:** $speed ft — how far it moves on its turn while you ride it.
- **Carrying capacity:** $carry lb — the most it can carry (gear plus rider) before being slowed. Double this to find the most it can drag, lift, or push.
- ${trained ? 'Comes **trained to bear a rider**, so it stays calm in normal travel and lets you ride, mount, and dismount as part of your move.' : '**Not trained for battle** — it may bolt or balk if combat breaks out near it.'}

**Cost:** $costGp gp
''';

/// SRD 5.2.1 mounts and other animals, p. 100 table.
List<Map<String, dynamic>> srdMounts() => [
      _m(
          name: 'Camel',
          description: _mount('Camel',
              'A hardy desert mount that endures long, dry journeys far better than a horse.',
              450, 50, 50),
          carryLb: 450, speedFt: 50, costGp: 50),
      _m(
          name: 'Elephant',
          description: _mount('Elephant',
              'A massive beast of burden able to haul enormous loads and carry several riders.',
              1320, 40, 200),
          carryLb: 1320, speedFt: 40, costGp: 200),
      _m(
          name: 'Draft Horse',
          description: _mount('Draft Horse',
              'A strong, even-tempered work horse bred to pull carts, plows, and wagons.',
              540, 40, 50),
          carryLb: 540, speedFt: 40, costGp: 50),
      _m(
          name: 'Riding Horse',
          description: _mount('Riding Horse',
              'A swift, sure-footed horse bred for travel and everyday riding.',
              480, 60, 75),
          carryLb: 480, speedFt: 60, costGp: 75),
      _m(
          name: 'Mastiff',
          description: _mount('Mastiff',
              'A large, loyal hound big enough for a Small creature to ride and useful as a guard or tracker.',
              195, 40, 25),
          carryLb: 195, speedFt: 40, costGp: 25),
      _m(
          name: 'Mule',
          description: _mount('Mule',
              'A stubborn but tireless pack animal, ideal for hauling supplies over rough trails.',
              420, 40, 8),
          carryLb: 420, speedFt: 40, costGp: 8),
      _m(
          name: 'Pony',
          description: _mount('Pony',
              'A small, gentle mount well suited to Small riders such as halflings and gnomes.',
              225, 40, 30),
          carryLb: 225, speedFt: 40, costGp: 30),
      _m(
          name: 'Warhorse',
          description: _mount('Warhorse',
              'A powerful steed trained for the battlefield — it stays steady amid the chaos of combat.',
              540, 60, 400),
          carryLb: 540, speedFt: 60, costGp: 400),
    ];
