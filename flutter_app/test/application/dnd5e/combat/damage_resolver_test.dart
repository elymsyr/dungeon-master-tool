import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:flutter_test/flutter_test.dart';

TargetDefenses _t({
  int hp = 30,
  int max = 30,
  int tempHp = 0,
  Set<String> res = const {},
  Set<String> vul = const {},
  Set<String> imm = const {},
  bool pc = false,
}) =>
    TargetDefenses(
      currentHp: hp,
      maxHp: max,
      tempHp: tempHp,
      resistances: res,
      vulnerabilities: vul,
      damageImmunities: imm,
      isPlayer: pc,
    );

DamageInstance _d({
  int amount = 10,
  String type = 'srd:fire',
  bool crit = false,
  bool save = false,
  bool saved = false,
}) =>
    DamageInstance(
      amount: amount,
      typeId: type,
      isCritical: crit,
      fromSavedThrow: save,
      savedSucceeded: saved,
    );

void main() {
  const r = DamageResolver();

  group('DamageResolver — base pipeline', () {
    test('clean hit deducts full amount', () {
      final o = r.resolve(_t(hp: 30), _d(amount: 10));
      expect(o.amountAfterMitigation, 10);
      expect(o.newCurrentHp, 20);
      expect(o.newTempHp, 0);
      expect(o.absorbedByTempHp, 0);
    });

    test('resistance halves (floor)', () {
      final o = r.resolve(_t(res: const {'srd:fire'}), _d(amount: 11));
      expect(o.amountAfterMitigation, 5);
    });

    test('vulnerability doubles', () {
      final o = r.resolve(_t(vul: const {'srd:fire'}), _d(amount: 7));
      expect(o.amountAfterMitigation, 14);
    });

    test('immunity zeroes', () {
      final o = r.resolve(_t(imm: const {'srd:fire'}), _d(amount: 100));
      expect(o.amountAfterMitigation, 0);
      expect(o.newCurrentHp, 30);
    });

    test('immunity wins over resistance + vulnerability both set', () {
      final o = r.resolve(
        _t(
          res: const {'srd:fire'},
          vul: const {'srd:fire'},
          imm: const {'srd:fire'},
        ),
        _d(amount: 12),
      );
      expect(o.amountAfterMitigation, 0);
    });

    test('resistance and vulnerability combined: halve then double', () {
      final o = r.resolve(
        _t(
          res: const {'srd:fire'},
          vul: const {'srd:fire'},
        ),
        _d(amount: 10),
      );
      // halve → 5, then double → 10
      expect(o.amountAfterMitigation, 10);
    });

    test('save-for-half halves after resistance', () {
      final o = r.resolve(
        _t(res: const {'srd:fire'}),
        _d(amount: 20, save: true, saved: true),
      );
      // resist 20 → 10, save half → 5
      expect(o.amountAfterMitigation, 5);
    });

    test('failed save (fromSavedThrow=true, savedSucceeded=false) is full', () {
      final o = r.resolve(_t(), _d(amount: 20, save: true, saved: false));
      expect(o.amountAfterMitigation, 20);
    });
  });

  group('DamageResolver — temp HP', () {
    test('temp HP absorbs first', () {
      final o = r.resolve(_t(hp: 30, tempHp: 5), _d(amount: 8));
      expect(o.absorbedByTempHp, 5);
      expect(o.newTempHp, 0);
      expect(o.newCurrentHp, 27); // 30 - (8 - 5) = 27
    });

    test('temp HP > damage fully absorbs', () {
      final o = r.resolve(_t(hp: 30, tempHp: 10), _d(amount: 4));
      expect(o.absorbedByTempHp, 4);
      expect(o.newTempHp, 6);
      expect(o.newCurrentHp, 30);
    });

    test('immunity + temp HP: no temp HP consumed', () {
      final o = r.resolve(
          _t(hp: 30, tempHp: 5, imm: const {'srd:fire'}), _d(amount: 20));
      expect(o.absorbedByTempHp, 0);
      expect(o.newTempHp, 5);
      expect(o.newCurrentHp, 30);
    });
  });

  group('DamageResolver — concentration', () {
    test('concentration DC is max(10, half damage) capped at 30', () {
      expect(
          r.resolve(_t(), _d(amount: 8)).concentrationSaveDc, 10); // 4 < 10
      expect(
          r.resolve(_t(), _d(amount: 30)).concentrationSaveDc, 15); // 30/2
      expect(r.resolve(_t(hp: 200, max: 200), _d(amount: 80))
          .concentrationSaveDc, 30); // capped
    });

    test('zero damage does not trigger a concentration check', () {
      final o = r.resolve(_t(imm: const {'srd:fire'}), _d(amount: 10));
      expect(o.concentrationCheckTriggered, false);
    });

    test('any nonzero mitigated damage triggers check', () {
      final o = r.resolve(_t(), _d(amount: 1));
      expect(o.concentrationCheckTriggered, true);
    });
  });

  group('DamageResolver — dropping to zero', () {
    test('dropsToZero true only when crossing from >0 to 0', () {
      final drop = r.resolve(_t(hp: 5), _d(amount: 10));
      expect(drop.dropsToZero, true);
      expect(drop.newCurrentHp, 0);

      final already = r.resolve(_t(hp: 0, pc: true), _d(amount: 3));
      expect(already.dropsToZero, false);
    });

    test('exactly reducing to 0 counts as dropsToZero', () {
      final o = r.resolve(_t(hp: 5), _d(amount: 5));
      expect(o.dropsToZero, true);
      expect(o.newCurrentHp, 0);
    });
  });

  group('DamageResolver — PC Massive Damage & death saves', () {
    test('Massive Damage triggers instantDeath on PC', () {
      final o = r.resolve(_t(hp: 10, max: 20, pc: true), _d(amount: 40));
      // overkill = 40 - 10 = 30, >= maxHp 20 → instant death
      expect(o.instantDeath, true);
      expect(o.newCurrentHp, 0);
    });

    test('NPC never suffers Massive Damage (no instantDeath flag)', () {
      final o = r.resolve(_t(hp: 10, max: 20, pc: false), _d(amount: 40));
      expect(o.instantDeath, false);
    });

    test('drop-to-zero hit on PC does NOT add a death-save failure', () {
      final o = r.resolve(_t(hp: 10, max: 20, pc: true), _d(amount: 10));
      expect(o.dropsToZero, true);
      expect(o.deathSaveFailuresToAdd, 0);
    });

    test('hit while already at 0 adds 1 failure, crit adds 2', () {
      final normal =
          r.resolve(_t(hp: 0, max: 20, pc: true), _d(amount: 3));
      expect(normal.deathSaveFailuresToAdd, 1);

      final crit = r.resolve(
        _t(hp: 0, max: 20, pc: true),
        _d(amount: 3, crit: true),
      );
      expect(crit.deathSaveFailuresToAdd, 2);
    });

    test('zero-damage hit at 0 HP adds nothing', () {
      final o = r.resolve(
        _t(hp: 0, max: 20, pc: true, imm: const {'srd:fire'}),
        _d(amount: 5),
      );
      expect(o.deathSaveFailuresToAdd, 0);
    });
  });
}
