import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/aoe_damage_orchestrator.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/aoe_target.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/area_of_effect.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/grid_cell.dart';
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

AoEDamageOrchestrator _orchestrator(List<int> rolls) {
  final roller = D20Roller(_QueueRng(rolls));
  final saver = SaveResolver(roller);
  return AoEDamageOrchestrator(
    saveResolver: saver,
    damagePipeline: ApplyDamagePipeline(
      damageResolver: const DamageResolver(),
      concentrationResolver: ConcentrationCheckResolver(saver),
    ),
  );
}

TargetDefenses _pc({int hp = 30, Set<String> resistances = const {}}) =>
    TargetDefenses(
      currentHp: hp,
      maxHp: hp,
      resistances: resistances,
      isPlayer: true,
    );

AoETarget _target(
  String id,
  GridCell pos, {
  int hp = 30,
  Set<String> resistances = const {},
  int spellSaveMod = 0,
  Concentration? conc,
}) =>
    AoETarget(
      id: id,
      position: pos,
      defenses: _pc(hp: hp, resistances: resistances),
      spellSaveAbilityMod: spellSaveMod,
      concentration: conc,
    );

Concentration _bless() =>
    Concentration(spellId: 'srd:bless', castAtLevel: SpellLevel(1));

void main() {
  // Sphere of radius 10ft (=2 cells) centered at origin (0,0). Cells inside:
  // those with col²+row² <= 4 in 5ft units (the AoE uses ceil(ft/5)).
  final area = SphereAoE(10.0);
  const origin = GridCell(0, 0);
  const dir = GridDirection.east;

  group('coverage filter', () {
    test('targets outside sphere are skipped', () {
      // Target at (10, 10) cells = far outside 10ft sphere.
      final out = _orchestrator([19]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [_target('outside', const GridCell(10, 10))],
        damageAmount: 20,
        damageTypeId: 'srd:fire',
      );
      expect(out, isEmpty);
    });

    test('only in-sphere targets resolve', () {
      final out = _orchestrator([]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [
          _target('in', const GridCell(0, 0)),
          _target('out', const GridCell(20, 20)),
        ],
        damageAmount: 10,
        damageTypeId: 'srd:fire',
      );
      expect(out.keys, ['in']);
      expect(out['in']!.damage.damage.newCurrentHp, 20);
      expect(out['in']!.spellSave, isNull);
    });
  });

  group('save-for-half', () {
    test('save success halves damage; save fail full damage', () {
      // Two targets: roll-15 (success vs DC 13), roll-1 (fail).
      final out = _orchestrator([14, 0]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [
          _target('saver', const GridCell(0, 0)),
          _target('failer', const GridCell(1, 0)),
        ],
        damageAmount: 20,
        damageTypeId: 'srd:fire',
        saveAbility: Ability.dexterity,
        saveDc: 13,
      );
      expect(out['saver']!.spellSave!.succeeded, isTrue);
      expect(out['saver']!.damage.damage.amountAfterMitigation, 10);
      expect(out['saver']!.damage.damage.newCurrentHp, 20);
      expect(out['failer']!.spellSave!.succeeded, isFalse);
      expect(out['failer']!.damage.damage.amountAfterMitigation, 20);
      expect(out['failer']!.damage.damage.newCurrentHp, 10);
    });

    test('saveDc null → no spell save rolled, full damage applied', () {
      final out = _orchestrator([]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [_target('t', const GridCell(0, 0))],
        damageAmount: 12,
        damageTypeId: 'srd:fire',
      );
      expect(out['t']!.spellSave, isNull);
      expect(out['t']!.damage.damage.amountAfterMitigation, 12);
    });

    test('saveDc + saveAbility must be set together', () {
      expect(
        () => _orchestrator([]).apply(
          area: area,
          origin: origin,
          direction: dir,
          targets: const [],
          damageAmount: 10,
          damageTypeId: 'srd:fire',
          saveDc: 13,
        ),
        throwsArgumentError,
      );
    });

    test('resistance applies after save halving', () {
      // Save success (roll 19) → 20/2=10; fire-resistant → 10/2=5.
      final out = _orchestrator([18]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [
          _target('t', const GridCell(0, 0), resistances: {'srd:fire'}),
        ],
        damageAmount: 20,
        damageTypeId: 'srd:fire',
        saveAbility: Ability.dexterity,
        saveDc: 10,
      );
      expect(out['t']!.spellSave!.succeeded, isTrue);
      expect(out['t']!.damage.damage.amountAfterMitigation, 5);
    });
  });

  group('concentration in AoE', () {
    test('damaged concentrator rolls concentration save after spell save', () {
      // Spell save fail (roll 1) → full 24 dmg → DC 12 conc save → roll 19+0=19 pass.
      final out = _orchestrator([0, 18]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [
          _target('caster', const GridCell(0, 0), conc: _bless()),
        ],
        damageAmount: 24,
        damageTypeId: 'srd:fire',
        saveAbility: Ability.dexterity,
        saveDc: 13,
      );
      expect(out['caster']!.spellSave!.succeeded, isFalse);
      expect(out['caster']!.damage.damage.amountAfterMitigation, 24);
      expect(out['caster']!.damage.concentration!.dc, 12);
      expect(out['caster']!.damage.concentration!.maintained, isTrue);
    });

    test('non-concentrator skips concentration save', () {
      final out = _orchestrator([0]).apply(
        area: area,
        origin: origin,
        direction: dir,
        targets: [_target('mook', const GridCell(0, 0))],
        damageAmount: 24,
        damageTypeId: 'srd:fire',
        saveAbility: Ability.dexterity,
        saveDc: 13,
      );
      expect(out['mook']!.damage.concentration, isNull);
    });
  });

  group('input validation', () {
    test('negative damage rejected', () {
      expect(
        () => _orchestrator([]).apply(
          area: area,
          origin: origin,
          direction: dir,
          targets: const [],
          damageAmount: -1,
          damageTypeId: 'srd:fire',
        ),
        throwsArgumentError,
      );
    });
  });
}
