// SRD 5.2.1 Monster traits (catalogue from monster stat blocks pp. 258–364).
// Common traits shared across multiple monsters live here as a single shared
// row so monster entries can reference them by name.

import '_helpers.dart';

Map<String, dynamic> _t({
  required String name,
  required String kind,
  required String description,
  String source = 'SRD 5.2.1',
}) {
  return packEntity(
    slug: 'trait',
    name: name,
    description: description,
    attributes: {
      'source': source,
      'trait_kind': kind,
      'description': description,
    },
  );
}

List<Map<String, dynamic>> srdTraits() => [
      _t(name: 'Amphibious', kind: 'Movement', description: 'The creature can breathe air and water.'),
      _t(name: 'Legendary Resistance (3/Day)', kind: 'Defensive', description: 'If the creature fails a saving throw, it can choose to succeed instead. Three uses per day.'),
      _t(name: 'Magic Resistance', kind: 'Defensive', description: 'The creature has Advantage on saving throws against spells and other magical effects.'),
      _t(name: 'Pack Tactics', kind: 'Passive', description: 'The creature has Advantage on attack rolls against a creature if at least one of the creature\'s allies is within 5 feet of the target and the ally doesn\'t have the Incapacitated condition.'),
      _t(name: 'Keen Smell', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on smell.'),
      _t(name: 'Keen Sight', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on sight.'),
      _t(name: 'Keen Hearing', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on hearing.'),
      _t(name: 'Sunlight Sensitivity', kind: 'Defensive', description: 'While in sunlight, the creature has Disadvantage on attack rolls and on Wisdom (Perception) checks that rely on sight.'),
      _t(name: 'Spider Climb', kind: 'Movement', description: 'The creature can climb difficult surfaces, including upside down on ceilings, without an ability check.'),
      _t(name: 'Web Sense', kind: 'Sense', description: 'While in contact with a web, the creature knows the exact location of any other creature in contact with the same web.'),
      _t(name: 'Web Walker', kind: 'Movement', description: 'The creature ignores movement restrictions caused by webbing.'),
      _t(name: 'Aggressive', kind: 'Movement', description: 'As a Bonus Action, the creature can move up to its Speed toward a hostile creature it can see.'),
      _t(name: 'Brute', kind: 'Passive', description: 'A melee weapon attack from the creature deals one extra die of damage when it hits (included in the attack).'),
      _t(name: 'Reckless', kind: 'Passive', description: 'At the start of its turn, the creature can gain Advantage on all melee weapon attack rolls during that turn, but attack rolls against it have Advantage until the start of its next turn.'),
      _t(name: 'Flyby', kind: 'Movement', description: 'The creature doesn\'t provoke Opportunity Attacks when it flies out of an enemy\'s reach.'),
      _t(name: 'Standing Leap', kind: 'Movement', description: 'The creature\'s long jump is up to 30 feet and its high jump is up to 15 feet, with or without a running start.'),
      _t(name: 'Undead Fortitude', kind: 'Defensive', description: 'When the creature is reduced to 0 HP by damage that isn\'t Radiant or from a critical hit, it makes a Constitution saving throw (DC 5 + the damage taken). On a success, it drops to 1 HP instead.'),
      _t(name: 'Aboleth Telepathy', kind: 'Other', description: 'The aboleth can telepathically speak to any creature within 1 mile of itself. The contacted creature understands only if it shares a language with the aboleth.'),
      _t(name: 'Eldritch Restoration', kind: 'Defensive', description: 'If destroyed, the aboleth gains a new body in 5d10 days, restoring it to life. The new body appears within 1d100 miles of the aboleth\'s old body.'),
      _t(name: 'Mucous Cloud', kind: 'Passive', description: 'While underwater, the aboleth is surrounded by transformative mucus. A creature that touches the aboleth or hits it with a melee attack while within 5 feet of it must succeed on a DC 14 Constitution save or be diseased for 1d4 hours.'),
      _t(name: 'Probing Telepathy', kind: 'Other', description: 'If a creature communicates telepathically with the aboleth, the aboleth learns the creature\'s greatest desires.'),
    ];
