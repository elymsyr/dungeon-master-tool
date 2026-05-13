// SRD §1 / DMG 2014 p.273-275 Challenge Rating calculator. Pure helpers —
// no Flutter / Riverpod dependency so the math is unit-testable in
// isolation. Two halves:
//
//  - **Defensive CR**: derived from average HP and effective AC. AC
//    +/- 2 from the bracket's expected AC shifts the bracket up/down
//    by 1 step.
//  - **Offensive CR**: derived from average damage-per-round (across
//    a 3-round encounter) and the attack bonus / save DC the monster
//    leans on. Attack bonus +/- 2 from expected shifts the bracket
//    one step.
//
// Final CR is the average of the two halves, rounded to the nearest
// canonical CR notch.
//
// Numbers come from the SRD's monster-building tables. The brackets
// are wide on purpose — the math is a guide, not gospel; combat math
// is meaningfully shaped by traits/actions outside this scope.

/// Canonical CR ladder used by the SRD monster tables. Each entry is
/// rendered as the string the entity stores (`'1/8'`, `'1'`, `'30'`).
const _crLadder = <String>[
  '0',
  '1/8',
  '1/4',
  '1/2',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
  '15',
  '16',
  '17',
  '18',
  '19',
  '20',
  '21',
  '22',
  '23',
  '24',
  '25',
  '26',
  '27',
  '28',
  '29',
  '30',
];

double _crToDouble(String cr) {
  switch (cr) {
    case '1/8':
      return 0.125;
    case '1/4':
      return 0.25;
    case '1/2':
      return 0.5;
    default:
      return double.tryParse(cr) ?? 0;
  }
}

int _crIndex(String cr) {
  final idx = _crLadder.indexOf(cr);
  return idx < 0 ? 0 : idx;
}

String _crAtIndex(int i) {
  if (i < 0) return _crLadder.first;
  if (i >= _crLadder.length) return _crLadder.last;
  return _crLadder[i];
}

// SRD Defensive CR table — (maxHp, expectedAc, defensiveCr).
// HP bracket upper bound; AC reference for ±2 adjustment.
const _defensiveTable = <(int hp, int ac, String cr)>[
  (6, 13, '0'),
  (35, 13, '1/8'),
  (49, 13, '1/4'),
  (70, 13, '1/2'),
  (85, 13, '1'),
  (100, 13, '2'),
  (115, 13, '3'),
  (130, 14, '4'),
  (145, 15, '5'),
  (160, 15, '6'),
  (175, 15, '7'),
  (190, 16, '8'),
  (205, 16, '9'),
  (220, 17, '10'),
  (235, 17, '11'),
  (250, 17, '12'),
  (265, 18, '13'),
  (280, 18, '14'),
  (295, 18, '15'),
  (310, 18, '16'),
  (325, 19, '17'),
  (340, 19, '18'),
  (355, 19, '19'),
  (400, 19, '20'),
  (445, 19, '21'),
  (490, 19, '22'),
  (535, 19, '23'),
  (580, 19, '24'),
  (625, 19, '25'),
  (670, 19, '26'),
  (715, 19, '27'),
  (760, 19, '28'),
  (805, 19, '29'),
  (850, 19, '30'),
];

// SRD Offensive CR table — (maxDpr, expectedAtkBonus, offensiveCr).
const _offensiveTable = <(int dpr, int atk, String cr)>[
  (1, 3, '0'),
  (3, 3, '1/8'),
  (5, 3, '1/4'),
  (8, 3, '1/2'),
  (14, 3, '1'),
  (20, 3, '2'),
  (26, 4, '3'),
  (32, 5, '4'),
  (38, 6, '5'),
  (44, 6, '6'),
  (50, 6, '7'),
  (56, 7, '8'),
  (62, 7, '9'),
  (68, 7, '10'),
  (74, 8, '11'),
  (80, 8, '12'),
  (86, 8, '13'),
  (92, 8, '14'),
  (98, 8, '15'),
  (104, 9, '16'),
  (110, 10, '17'),
  (116, 10, '18'),
  (122, 11, '19'),
  (140, 11, '20'),
  (158, 11, '21'),
  (176, 11, '22'),
  (194, 11, '23'),
  (212, 13, '24'),
  (230, 13, '25'),
  (248, 13, '26'),
  (266, 13, '27'),
  (284, 13, '28'),
  (302, 13, '29'),
  (320, 13, '30'),
];

/// Defensive CR from average HP + effective AC. Returns the ladder
/// string (e.g. `'1/4'`). Higher AC than the bracket's expected value
/// shifts the bracket up by one step per 2 points; lower AC shifts
/// down. Result is clamped to the canonical ladder.
String defensiveCrFromAcHp(int ac, int hp) {
  // Find smallest bracket whose hp ceiling >= input.
  var bracketIdx = _defensiveTable.length - 1;
  for (var i = 0; i < _defensiveTable.length; i++) {
    if (hp <= _defensiveTable[i].$1) {
      bracketIdx = i;
      break;
    }
  }
  final bracket = _defensiveTable[bracketIdx];
  final acDelta = ac - bracket.$2;
  // ±2 AC moves bracket ±1 step (Dart truncates toward 0; offset matches).
  final shift = (acDelta / 2).truncate();
  final ladderIdx = _crIndex(bracket.$3) + shift;
  return _crAtIndex(ladderIdx);
}

/// Offensive CR from average damage-per-round + attack bonus. DPR is
/// expected to already be averaged across a typical 3-round span. The
/// attack bonus adjustment mirrors defensive AC — ±2 from the bracket's
/// expected attack bonus shifts the bracket by one step.
String offensiveCrFromAtkDpr(int attackBonus, int dpr) {
  var bracketIdx = _offensiveTable.length - 1;
  for (var i = 0; i < _offensiveTable.length; i++) {
    if (dpr <= _offensiveTable[i].$1) {
      bracketIdx = i;
      break;
    }
  }
  final bracket = _offensiveTable[bracketIdx];
  final atkDelta = attackBonus - bracket.$2;
  final shift = (atkDelta / 2).truncate();
  final ladderIdx = _crIndex(bracket.$3) + shift;
  return _crAtIndex(ladderIdx);
}

/// Combined CR = average of [defensive] + [offensive], rounded to
/// the nearest canonical ladder notch. The average operates in
/// numeric CR space (1/8 = 0.125, 1/2 = 0.5, etc.) so fractional
/// CR brackets aren't skipped.
String combinedCr(String defensive, String offensive) {
  final dv = _crToDouble(defensive);
  final ov = _crToDouble(offensive);
  final avg = (dv + ov) / 2;
  return _nearestCr(avg);
}

/// SRD XP table for the canonical CR ladder.
const _crToXp = <String, int>{
  '0': 10,
  '1/8': 25,
  '1/4': 50,
  '1/2': 100,
  '1': 200,
  '2': 450,
  '3': 700,
  '4': 1100,
  '5': 1800,
  '6': 2300,
  '7': 2900,
  '8': 3900,
  '9': 5000,
  '10': 5900,
  '11': 7200,
  '12': 8400,
  '13': 10000,
  '14': 11500,
  '15': 13000,
  '16': 15000,
  '17': 18000,
  '18': 20000,
  '19': 22000,
  '20': 25000,
  '21': 33000,
  '22': 41000,
  '23': 50000,
  '24': 62000,
  '25': 75000,
  '26': 90000,
  '27': 105000,
  '28': 120000,
  '29': 135000,
  '30': 155000,
};

/// XP yield for the canonical CR string. Returns 0 for unknown input.
int xpForCr(String cr) => _crToXp[cr] ?? 0;

String _nearestCr(double v) {
  String best = _crLadder.first;
  double bestDist = double.infinity;
  for (final cr in _crLadder) {
    final d = (v - _crToDouble(cr)).abs();
    if (d < bestDist) {
      bestDist = d;
      best = cr;
    }
  }
  return best;
}
