import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> queue;
  int i = 0;
  _QueueRng(this.queue);
  @override
  int nextInt(int max) => queue[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

ApplyDamagePipeline _pipeline(List<int> rolls) => ApplyDamagePipeline(
      damageResolver: const DamageResolver(),
      concentrationResolver:
          ConcentrationCheckResolver(SaveResolver(D20Roller(_QueueRng(rolls)))),
    );

TargetDefenses _pc({
  int currentHp = 30,
  int maxHp = 30,
  int tempHp = 0,
  Set<String> resistances = const {},
  Set<String> vulnerabilities = const {},
  Set<String> damageImmunities = const {},
}) =>
    TargetDefenses(
      currentHp: currentHp,
      maxHp: maxHp,
      tempHp: tempHp,
      resistances: resistances,
      vulnerabilities: vulnerabilities,
      damageImmunities: damageImmunities,
      isPlayer: true,
    );

Concentration _bless() => Concentration(
      spellId: 'srd:bless',
      castAtLevel: SpellLevel(1),
    );

DamageInstance _fire(int amount, {bool isCritical = false}) => DamageInstance(
      amount: amount,
      typeId: 'srd:fire',
      isCritical: isCritical,
    );

void main() {
  group('concentration gating', () {
    test('no concentration → no save rolled', () {
      final out = _pipeline([]).apply(
        target: _pc(),
        damage: _fire(10),
      );
      expect(out.concentration, isNull);
      expect(out.concentrationBroken, isFalse);
      expect(out.damage.newCurrentHp, 20);
    });

    test('has concentration but damage immune → no save', () {
      final out = _pipeline([]).apply(
        target: _pc(damageImmunities: {'srd:fire'}),
        damage: _fire(20),
        concentration: _bless(),
        conMod: 0,
      );
      expect(out.damage.amountAfterMitigation, 0);
      expect(out.damage.concentrationCheckTriggered, isFalse);
      expect(out.concentration, isNull);
    });

    test('instant death → no concentration save rolled', () {
      // 200 damage to 30/30 PC = overkill 170 >= maxHp 30 = instant death.
      final out = _pipeline([]).apply(
        target: _pc(),
        damage: _fire(200),
        concentration: _bless(),
        conMod: 0,
      );
      expect(out.damage.instantDeath, isTrue);
      expect(out.concentration, isNull);
    });
  });

  group('save pipeline', () {
    test('pass keeps concentration', () {
      // 10 dmg → DC 10. roll 15 + mod 3 = 18 ≥ 10.
      final out = _pipeline([14]).apply(
        target: _pc(),
        damage: _fire(10),
        concentration: _bless(),
        conMod: 3,
      );
      expect(out.damage.newCurrentHp, 20);
      expect(out.concentration, isNotNull);
      expect(out.concentration!.maintained, isTrue);
      expect(out.concentration!.dc, 10);
    });

    test('fail breaks concentration', () {
      // 24 dmg → DC 12. roll 2 + mod 0 = 2 < 12.
      final out = _pipeline([1]).apply(
        target: _pc(),
        damage: _fire(24),
        concentration: _bless(),
        conMod: 0,
      );
      expect(out.concentrationBroken, isTrue);
      expect(out.concentration!.dc, 12);
    });

    test('resistance halves damage before DC', () {
      // 24 dmg, resist fire → amt=12 → DC 10 (max(10, 6)).
      final out = _pipeline([19]).apply(
        target: _pc(resistances: {'srd:fire'}),
        damage: _fire(24),
        concentration: _bless(),
        conMod: 0,
      );
      expect(out.damage.amountAfterMitigation, 12);
      expect(out.concentration!.dc, 10);
    });

    test('save advantage picks higher d20', () {
      // 10 dmg → DC 10. advantage [4, 18] → 18 + mod 0 ≥ 10.
      final out = _pipeline([3, 17]).apply(
        target: _pc(),
        damage: _fire(10),
        concentration: _bless(),
        conMod: 0,
        saveAdvantage: AdvantageState.advantage,
      );
      expect(out.concentration!.maintained, isTrue);
      expect(out.concentration!.save.d20Chosen, 18);
    });

    test('autoFail breaks regardless of high mod', () {
      final out = _pipeline([]).apply(
        target: _pc(),
        damage: _fire(5),
        concentration: _bless(),
        conMod: 99,
        autoFailSave: true,
      );
      expect(out.concentrationBroken, isTrue);
    });

    test('proficiency bonus added to save', () {
      // 28 dmg → DC 14. roll 7 + mod 2 + prof 5 = 14 ≥ 14.
      final out = _pipeline([6]).apply(
        target: _pc(),
        damage: _fire(28),
        concentration: _bless(),
        conMod: 2,
        saveProfBonus: 5,
      );
      expect(out.concentration!.maintained, isTrue);
    });
  });
}
