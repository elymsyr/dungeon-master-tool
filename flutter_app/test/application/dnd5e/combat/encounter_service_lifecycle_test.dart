import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_roll.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_event.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_repository.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_service.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/recording_encounter_hook.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/encounter.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/initiative.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> q;
  int i = 0;
  _QueueRng(this.q);
  @override
  int nextInt(int max) => q[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(10),
      con: AbilityScore(10),
      int_: AbilityScore(10),
      wis: AbilityScore(10),
      cha: AbilityScore(10),
    );

MonsterCombatant _mc(
  String id, {
  int hp = 10,
  int maxHp = 10,
  Concentration? concentration,
}) =>
    MonsterCombatant(
      definition: Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: StatBlock(
          sizeId: 'srd:small',
          typeId: 'srd:humanoid',
          armorClass: 13,
          hitPoints: maxHp,
          abilities: _abs(),
          cr: ChallengeRating.parse('1/4'),
        ),
      ),
      id: id,
      instanceMaxHp: maxHp,
      instanceCurrentHp: hp,
      initiativeRoll: 10,
      concentration: concentration,
      turnState: TurnState(speedFt: 30),
    );

Encounter _enc(List<MonsterCombatant> cs, {int round = 1}) => Encounter(
      id: 'e1',
      name: 'Test',
      combatants: cs,
      order: InitiativeOrder(combatantIds: [for (final c in cs) c.id]),
      round: round,
    );

List<EffectDescriptor> _noEffects(String _) => const [];

EncounterService _service({
  required EncounterRepository repo,
  required RecordingEncounterHook hook,
  List<int> attackRolls = const [],
  List<int> saveRolls = const [],
  List<int> concRolls = const [],
}) {
  final source = CombatantEffectSource(conditionEffects: _noEffects);
  return EncounterService(
    repository: repo,
    hook: hook,
    attackPipeline: AttackPipeline(
      effectSource: source,
      resolver: AttackResolver(D20Roller(_QueueRng(attackRolls))),
    ),
    damagePipeline: DamagePipeline(
      effectSource: source,
      applyPipeline: ApplyDamagePipeline(
        damageResolver: const DamageResolver(),
        concentrationResolver:
            ConcentrationCheckResolver(SaveResolver(D20Roller(_QueueRng(concRolls)))),
      ),
    ),
    savePipeline: SavePipeline(
      effectSource: source,
      resolver: SaveResolver(D20Roller(_QueueRng(saveRolls))),
    ),
    defensesFor: (c) => TargetDefenses(
      currentHp: c.currentHp,
      maxHp: c.maxHp,
    ),
  );
}

void main() {
  group('EncounterService lifecycle hooks', () {
    test('Step 4: applyDamage emits DamageDealtEvent with HP snapshot',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 10)]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: 4, typeId: 'srd:slashing'),
        ),
      );
      final dmg = hook.of<DamageDealtEvent>().single;
      expect(dmg.attackerId, 'a');
      expect(dmg.targetId, 'b');
      expect(dmg.previousCurrentHp, 10);
      expect(dmg.newCurrentHp, 6);
      expect(dmg.amountAfterMitigation, 4);
      expect(dmg.dropsToZero, isFalse);
      expect(dmg.damageTypeId, 'srd:slashing');
      expect(hook.of<CombatantDroppedEvent>(), isEmpty);
    });

    test('Step 5: lethal damage emits CombatantDroppedEvent', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 5)]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: 8, typeId: 'srd:slashing'),
        ),
      );
      final drop = hook.of<CombatantDroppedEvent>().single;
      expect(drop.combatantId, 'b');
      expect(drop.instantDeath, isFalse);
      // Damage event still emitted alongside the drop event.
      expect(hook.of<DamageDealtEvent>().single.dropsToZero, isTrue);
    });

    test('Step 5b: hit on already-0-HP target does NOT re-emit drop',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 0)]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: 1, typeId: 'srd:slashing'),
        ),
      );
      expect(hook.of<CombatantDroppedEvent>(), isEmpty);
    });

    test('Step 6: damage that breaks concentration emits ConcentrationBroken',
        () async {
      final repo = InMemoryEncounterRepository();
      final concentrating = _mc(
        'b',
        hp: 20,
        maxHp: 20,
        concentration: Concentration(
          spellId: 'srd:bless',
          castAtLevel: SpellLevel(1),
        ),
      );
      await repo.save(_enc([_mc('a'), concentrating]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: 6, typeId: 'srd:slashing'),
          concentration: tgt.concentration,
          autoFailSave: true,
        ),
      );
      final broken = hook.of<ConcentrationBrokenEvent>().single;
      expect(broken.combatantId, 'b');
      expect(broken.spellId, 'srd:bless');
      expect(broken.dc, 10);
    });

    test('Step 7: advanceTurn emits End→Start, no Round when not wrapping',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.advanceTurn('e1');
      final ends = hook.of<EndOfTurnEvent>();
      final starts = hook.of<StartOfTurnEvent>();
      expect(ends.single.combatantId, 'a');
      expect(starts.single.combatantId, 'b');
      expect(hook.of<RoundAdvancedEvent>(), isEmpty);
      // End-of-turn carries the prior round, start-of-turn carries the new one.
      expect(ends.single.round, 1);
      expect(starts.single.round, 1);
    });

    test('Step 7b: advanceTurn emits RoundAdvanced when order wraps',
        () async {
      final repo = InMemoryEncounterRepository();
      // Two combatants, second is current — next advance wraps to round 2.
      final e = Encounter(
        id: 'e1',
        name: 'Test',
        combatants: [_mc('a'), _mc('b')],
        order: InitiativeOrder(combatantIds: const ['a', 'b'])
            .advance(), // currentId='b'
      );
      await repo.save(e);
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      final next = await svc.advanceTurn('e1');
      expect(next.round, 2);
      final round = hook.of<RoundAdvancedEvent>().single;
      expect(round.previousRound, 1);
      expect(round.round, 2);
      expect(hook.of<EndOfTurnEvent>().single.combatantId, 'b');
      expect(hook.of<StartOfTurnEvent>().single.combatantId, 'a');
    });

    test('Step 8: tickConditions emits one ConditionExpired per expired pair',
        () async {
      final repo = InMemoryEncounterRepository();
      final a = _mc('a').copyWith(
        conditionIds: const {'srd:bless', 'srd:bane'},
        conditionDurationsRounds: const {'srd:bless': 1, 'srd:bane': 1},
      );
      final b = _mc('b').copyWith(
        conditionIds: const {'srd:slow'},
        conditionDurationsRounds: const {'srd:slow': 1},
      );
      await repo.save(_enc([a, b]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.tickConditions('e1');
      final expired = hook.of<ConditionExpiredEvent>();
      final pairs = expired
          .map((e) => '${e.combatantId}:${e.conditionId}')
          .toSet();
      expect(pairs, {'a:srd:bless', 'a:srd:bane', 'b:srd:slow'});
    });

    test('Step 9: applyCondition adds + emits ConditionAddedEvent',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      final out = await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: 10,
      );
      expect(out.changed, isTrue);
      final added = hook.of<ConditionAddedEvent>().single;
      expect(added.combatantId, 'a');
      expect(added.conditionId, 'srd:bless');
      expect(added.durationRounds, 10);
      // Persisted on combatant.
      final after = (await repo.findById('e1'))!.byId('a')!;
      expect(after.conditionIds, contains('srd:bless'));
      expect(after.conditionDurationsRounds['srd:bless'], 10);
    });

    test('Step 9b: re-applying same condition with same duration is a no-op',
        () async {
      final repo = InMemoryEncounterRepository();
      final a = _mc('a').copyWith(
        conditionIds: const {'srd:bless'},
        conditionDurationsRounds: const {'srd:bless': 5},
      );
      await repo.save(_enc([a]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      final out = await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: 5,
      );
      expect(out.changed, isFalse);
      expect(hook.of<ConditionAddedEvent>(), isEmpty);
    });

    test('Step 9c: applyCondition with null duration adds open-ended entry',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:rage',
      );
      final after = (await repo.findById('e1'))!.byId('a')!;
      expect(after.conditionIds, contains('srd:rage'));
      expect(after.conditionDurationsRounds.containsKey('srd:rage'), isFalse);
      expect(hook.of<ConditionAddedEvent>().single.durationRounds, isNull);
    });

    test('Step 10: removeCondition removes + emits ConditionRemovedEvent',
        () async {
      final repo = InMemoryEncounterRepository();
      final a = _mc('a').copyWith(
        conditionIds: const {'srd:bless'},
        conditionDurationsRounds: const {'srd:bless': 3},
      );
      await repo.save(_enc([a]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      final out = await svc.removeCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
      );
      expect(out.changed, isTrue);
      expect(hook.of<ConditionRemovedEvent>().single.conditionId, 'srd:bless');
      final after = (await repo.findById('e1'))!.byId('a')!;
      expect(after.conditionIds, isEmpty);
      expect(after.conditionDurationsRounds, isEmpty);
    });

    test('Step 10b: removing absent condition is a no-op', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      final out = await svc.removeCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
      );
      expect(out.changed, isFalse);
      expect(hook.of<ConditionRemovedEvent>(), isEmpty);
    });
  });
}
