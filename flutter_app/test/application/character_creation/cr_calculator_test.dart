import 'package:dungeon_master_tool/application/character_creation/cr_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defensiveCrFromAcHp', () {
    test('CR 0 bracket (HP <= 6, AC 13)', () {
      expect(defensiveCrFromAcHp(13, 4), '0');
    });
    test('CR 1/4 bracket (HP 36-49, AC 13)', () {
      expect(defensiveCrFromAcHp(13, 40), '1/4');
    });
    test('AC +2 from expected → shifts up one CR step', () {
      // HP 40 → CR 1/4 bracket (expected AC 13). AC 15 → +2 → CR 1/2.
      expect(defensiveCrFromAcHp(15, 40), '1/2');
    });
    test('AC -2 from expected → shifts down one CR step', () {
      // HP 40 → CR 1/4. AC 11 → -2 → CR 1/8.
      expect(defensiveCrFromAcHp(11, 40), '1/8');
    });
    test('high HP clamps to top of ladder', () {
      expect(defensiveCrFromAcHp(19, 900), '30');
    });
  });

  group('offensiveCrFromAtkDpr', () {
    test('CR 0 bracket (DPR <= 1, atk 3)', () {
      expect(offensiveCrFromAtkDpr(3, 1), '0');
    });
    test('CR 1 bracket (DPR 9-14, atk 3)', () {
      expect(offensiveCrFromAtkDpr(3, 14), '1');
    });
    test('attack bonus +2 from expected → shifts up', () {
      // DPR 14 → CR 1 bracket (expected atk 3). atk 5 → +2 → CR 2.
      expect(offensiveCrFromAtkDpr(5, 14), '2');
    });
    test('attack bonus -2 → shifts down', () {
      // DPR 14 → CR 1. atk 1 → -2 → CR 1/2.
      expect(offensiveCrFromAtkDpr(1, 14), '1/2');
    });
  });

  group('combinedCr', () {
    test('averages CR 1/4 + CR 1/2 → CR ~1/4 (0.375 rounded to 0.25)', () {
      // 0.25 + 0.5 = 0.75, /2 = 0.375. Nearest ladder is 1/4 (0.25)
      // since |0.375-0.25|=0.125 < |0.375-0.5|=0.125 → tie, picks first
      // (lower) — acceptable rounding behavior.
      expect(combinedCr('1/4', '1/2'), '1/4');
    });
    test('averages CR 2 + CR 4 → CR 3', () {
      expect(combinedCr('2', '4'), '3');
    });
    test('averages CR 0 + CR 0 → CR 0', () {
      expect(combinedCr('0', '0'), '0');
    });
  });

  group('xpForCr', () {
    test('canonical entries', () {
      expect(xpForCr('0'), 10);
      expect(xpForCr('1/8'), 25);
      expect(xpForCr('1/4'), 50);
      expect(xpForCr('1/2'), 100);
      expect(xpForCr('1'), 200);
      expect(xpForCr('20'), 25000);
      expect(xpForCr('30'), 155000);
    });
    test('unknown CR → 0', () {
      expect(xpForCr('bogus'), 0);
    });
  });
}
