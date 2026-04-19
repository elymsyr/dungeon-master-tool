import 'package:dungeon_master_tool/application/dnd5e/combat/multi_type_damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/typed_damage.dart';
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

void main() {
  const r = MultiTypeDamageResolver();

  group('MultiTypeDamageResolver — per-type mitigation', () {
    test('sums all types when none are resisted', () {
      final res = r.resolve(
        _t(),
        TypedDamage(
            byType: const {'srd:slashing': 7, 'srd:fire': 4}),
      );
      expect(res.totalPreSave, 11);
      expect(res.outcome.newCurrentHp, 19);
      expect(res.breakdown.length, 2);
    });

    test('resistance halves one type, leaves the other intact', () {
      final res = r.resolve(
        _t(res: const {'srd:fire'}),
        TypedDamage(
            byType: const {'srd:slashing': 7, 'srd:fire': 10}),
      );
      // slashing 7 + fire 5 = 12
      expect(res.totalPreSave, 12);
      final fire = res.breakdown.firstWhere((b) => b.typeId == 'srd:fire');
      expect(fire.resisted, true);
      expect(fire.amountAfterMitigation, 5);
      final slash =
          res.breakdown.firstWhere((b) => b.typeId == 'srd:slashing');
      expect(slash.resisted, false);
    });

    test('vulnerability doubles one type only', () {
      final res = r.resolve(
        _t(vul: const {'srd:fire'}),
        TypedDamage(
            byType: const {'srd:slashing': 7, 'srd:fire': 4}),
      );
      expect(res.totalPreSave, 7 + 8);
    });

    test('immunity zeroes that type', () {
      final res = r.resolve(
        _t(imm: const {'srd:fire'}),
        TypedDamage(
            byType: const {'srd:slashing': 7, 'srd:fire': 100}),
      );
      expect(res.totalPreSave, 7);
      final fire = res.breakdown.firstWhere((b) => b.typeId == 'srd:fire');
      expect(fire.immune, true);
      expect(fire.amountAfterMitigation, 0);
    });

    test('immunity wins even when resistance + vulnerability set', () {
      final res = r.resolve(
        _t(
          res: const {'srd:fire'},
          vul: const {'srd:fire'},
          imm: const {'srd:fire'},
        ),
        TypedDamage(byType: const {'srd:fire': 20}),
      );
      final fire = res.breakdown.single;
      expect(fire.immune, true);
      expect(fire.resisted, false);
      expect(fire.vulnerable, false);
      expect(res.totalPreSave, 0);
    });
  });

  group('MultiTypeDamageResolver — save half', () {
    test('save succeeded halves total after per-type mitigation', () {
      final res = r.resolve(
        _t(res: const {'srd:fire'}),
        TypedDamage(
          byType: const {'srd:fire': 20, 'srd:cold': 10},
          fromSavedThrow: true,
          savedSucceeded: true,
        ),
      );
      // fire resisted 20 → 10; cold 10. Sum 20, save half → 10.
      expect(res.totalPreSave, 20);
      expect(res.totalPostSave, 10);
      expect(res.outcome.newCurrentHp, 20);
    });

    test('failed save (fromSave=true, saved=false) keeps full total', () {
      final res = r.resolve(
        _t(),
        TypedDamage(
          byType: const {'srd:fire': 20},
          fromSavedThrow: true,
          savedSucceeded: false,
        ),
      );
      expect(res.totalPostSave, 20);
    });
  });

  group('MultiTypeDamageResolver — temp HP + HP clamp', () {
    test('temp HP absorbs the post-save total first', () {
      final res = r.resolve(
        _t(hp: 20, tempHp: 5),
        TypedDamage(byType: const {'srd:fire': 8}),
      );
      expect(res.outcome.absorbedByTempHp, 5);
      expect(res.outcome.newTempHp, 0);
      expect(res.outcome.newCurrentHp, 17);
    });

    test('drop-to-zero flagged', () {
      final res = r.resolve(
        _t(hp: 5),
        TypedDamage(byType: const {'srd:fire': 10}),
      );
      expect(res.outcome.dropsToZero, true);
      expect(res.outcome.newCurrentHp, 0);
    });
  });

  group('MultiTypeDamageResolver — PC death/massive damage', () {
    test('Massive Damage on PC', () {
      final res = r.resolve(
        _t(hp: 10, max: 20, pc: true),
        TypedDamage(byType: const {'srd:fire': 40}),
      );
      expect(res.outcome.instantDeath, true);
    });

    test('hit at 0 HP adds 1 failure (2 on crit)', () {
      final normal = r.resolve(
        _t(hp: 0, max: 20, pc: true),
        TypedDamage(byType: const {'srd:fire': 3}),
      );
      expect(normal.outcome.deathSaveFailuresToAdd, 1);
      final crit = r.resolve(
        _t(hp: 0, max: 20, pc: true),
        TypedDamage(byType: const {'srd:fire': 3}, isCritical: true),
      );
      expect(crit.outcome.deathSaveFailuresToAdd, 2);
    });
  });

  group('MultiTypeDamageResolver — concentration DC', () {
    test('DC is max(10, total/2) capped at 30', () {
      expect(
        r
            .resolve(_t(), TypedDamage(byType: const {'srd:fire': 10}))
            .outcome
            .concentrationSaveDc,
        10,
      );
      expect(
        r
            .resolve(_t(), TypedDamage(byType: const {'srd:fire': 30}))
            .outcome
            .concentrationSaveDc,
        15,
      );
      expect(
        r
            .resolve(_t(hp: 200, max: 200),
                TypedDamage(byType: const {'srd:fire': 80}))
            .outcome
            .concentrationSaveDc,
        30,
      );
    });
  });
}
