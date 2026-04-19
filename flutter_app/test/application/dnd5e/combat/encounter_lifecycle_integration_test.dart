import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_roll.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_event.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_hook.dart';
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
  required EncounterHook hook,
}) {
  final source = CombatantEffectSource(conditionEffects: _noEffects);
  return EncounterService(
    repository: repo,
    hook: hook,
    attackPipeline: AttackPipeline(
      effectSource: source,
      resolver: AttackResolver(D20Roller(_QueueRng(const []))),
    ),
    damagePipeline: DamagePipeline(
      effectSource: source,
      applyPipeline: ApplyDamagePipeline(
        damageResolver: const DamageResolver(),
        concentrationResolver:
            ConcentrationCheckResolver(SaveResolver(D20Roller(_QueueRng(const [])))),
      ),
    ),
    savePipeline: SavePipeline(
      effectSource: source,
      resolver: SaveResolver(D20Roller(_QueueRng(const []))),
    ),
    defensesFor: (c) => TargetDefenses(
      currentHp: c.currentHp,
      maxHp: c.maxHp,
    ),
  );
}

DamagePipelineInput Function(Combatant, Combatant, TargetDefenses) _hit(
  int amount, {
  Concentration? concentration,
  bool autoFailSave = false,
}) =>
    (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: amount, typeId: 'srd:slashing'),
          concentration: concentration,
          autoFailSave: autoFailSave,
        );

void main() {
  group('EncounterService lifecycle integration', () {
    test('Step 1: damage→drop chain emits [DamageDealt, CombatantDropped]',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 5)]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(8),
      );
      expect(hook.events.map((e) => e.runtimeType),
          [DamageDealtEvent, CombatantDroppedEvent]);
      expect((hook.events[0] as DamageDealtEvent).newCurrentHp, 0);
      expect((hook.events[1] as CombatantDroppedEvent).combatantId, 'b');
    });

    test(
        'Step 2: damage→break-concentration→advance emits Damage, '
        'ConcentrationBroken, EndOfTurn, StartOfTurn in order', () async {
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
        buildInput: _hit(6,
            concentration: concentrating.concentration, autoFailSave: true),
      );
      await svc.advanceTurn('e1');
      expect(hook.events.map((e) => e.runtimeType), [
        DamageDealtEvent,
        ConcentrationBrokenEvent,
        EndOfTurnEvent,
        StartOfTurnEvent,
      ]);
      expect((hook.events[1] as ConcentrationBrokenEvent).spellId, 'srd:bless');
      expect((hook.events[2] as EndOfTurnEvent).combatantId, 'a');
      expect((hook.events[3] as StartOfTurnEvent).combatantId, 'b');
    });

    test('Step 3: two-round wrap emits [End, Start, End, RoundAdvanced, Start]',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.advanceTurn('e1');
      await svc.advanceTurn('e1');
      expect(hook.events.map((e) => e.runtimeType), [
        EndOfTurnEvent,
        StartOfTurnEvent,
        EndOfTurnEvent,
        RoundAdvancedEvent,
        StartOfTurnEvent,
      ]);
      final round = hook.of<RoundAdvancedEvent>().single;
      expect(round.previousRound, 1);
      expect(round.round, 2);
      // Final start-of-turn lands on 'a' — order wraps to head.
      expect((hook.events.last as StartOfTurnEvent).combatantId, 'a');
    });

    test('Step 4: condition tick decrements then expires across two ticks',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: 2,
      );
      await svc.tickConditions('e1');
      // First tick: still alive, no expiry event.
      expect(hook.of<ConditionExpiredEvent>(), isEmpty);
      await svc.tickConditions('e1');
      // Second tick: counter hits 0 → expired.
      final expired = hook.of<ConditionExpiredEvent>().single;
      expect(expired.conditionId, 'srd:bless');
      // Sequence overall: Added, Expired (no other event types in between).
      expect(hook.events.map((e) => e.runtimeType),
          [ConditionAddedEvent, ConditionExpiredEvent]);
    });

    test(
        'Step 5: round wrap does NOT auto-tick — explicit tickConditions '
        'still required for expiry', () async {
      final repo = InMemoryEncounterRepository();
      // Position so that one advanceTurn wraps the round.
      final e = Encounter(
        id: 'e1',
        name: 'Test',
        combatants: [_mc('a'), _mc('b')],
        order: InitiativeOrder(combatantIds: const ['a', 'b']).advance(),
      );
      await repo.save(e);
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:slow',
        durationRounds: 1,
      );
      await svc.advanceTurn('e1');
      // No expiry on round-advance alone.
      expect(hook.of<ConditionExpiredEvent>(), isEmpty);
      await svc.tickConditions('e1');
      expect(hook.of<ConditionExpiredEvent>().single.conditionId, 'srd:slow');
    });

    test('Step 6: sequential damage to two targets emits two DamageDealtEvents',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b'), _mc('c')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(3),
      );
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'c',
        buildInput: _hit(2),
      );
      final dmgs = hook.of<DamageDealtEvent>();
      expect(dmgs.map((e) => e.targetId), ['b', 'c']);
      expect(dmgs.map((e) => e.amountAfterMitigation), [3, 2]);
      expect(hook.of<CombatantDroppedEvent>(), isEmpty);
    });

    test('Step 7: apply→remove→re-apply emits [Added, Removed, Added]',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: 10,
      );
      await svc.removeCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
      );
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: 5,
      );
      expect(hook.events.map((e) => e.runtimeType), [
        ConditionAddedEvent,
        ConditionRemovedEvent,
        ConditionAddedEvent,
      ]);
      expect(
          hook.of<ConditionAddedEvent>().map((e) => e.durationRounds), [10, 5]);
    });

    test(
        'Step 8: drop guard — first hit emits Dropped, second hit at 0 HP '
        'emits Damage only (no second Dropped)', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 3)]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(5),
      );
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(2),
      );
      expect(hook.of<DamageDealtEvent>(), hasLength(2));
      expect(hook.of<CombatantDroppedEvent>(), hasLength(1));
      expect(hook.events.map((e) => e.runtimeType), [
        DamageDealtEvent,
        CombatantDroppedEvent,
        DamageDealtEvent,
      ]);
    });

    test('Step 9: composite hook fan-out — both recorders see identical stream',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 4)]));
      final r1 = RecordingEncounterHook();
      final r2 = RecordingEncounterHook();
      final svc = _service(
        repo: repo,
        hook: CompositeEncounterHook([r1, r2]),
      );
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(6),
      );
      await svc.advanceTurn('e1');
      expect(r1.events.length, r2.events.length);
      expect(r1.events.map((e) => e.runtimeType).toList(),
          r2.events.map((e) => e.runtimeType).toList());
      // Damage, Dropped, End('a'), RoundAdvanced (rotation skips dropped 'b'
      // and wraps), Start('a').
      expect(r1.events.length, 5);
      expect(r1.events.map((e) => e.runtimeType), [
        DamageDealtEvent,
        CombatantDroppedEvent,
        EndOfTurnEvent,
        RoundAdvancedEvent,
        StartOfTurnEvent,
      ]);
    });

    test(
        'Step 10: of<T>() filters across mixed sequence — counts per type '
        'match emission order', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b', hp: 3), _mc('c')]));
      final hook = RecordingEncounterHook();
      final svc = _service(repo: repo, hook: hook);
      await svc.applyCondition(
        encounterId: 'e1',
        combatantId: 'c',
        conditionId: 'srd:bless',
        durationRounds: 1,
      );
      await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: _hit(3),
      );
      await svc.advanceTurn('e1');
      await svc.tickConditions('e1');
      expect(hook.of<ConditionAddedEvent>(), hasLength(1));
      expect(hook.of<DamageDealtEvent>(), hasLength(1));
      expect(hook.of<CombatantDroppedEvent>(), hasLength(1));
      expect(hook.of<EndOfTurnEvent>(), hasLength(1));
      expect(hook.of<StartOfTurnEvent>(), hasLength(1));
      expect(hook.of<ConditionExpiredEvent>(), hasLength(1));
      // Total event count equals sum of subtype counts (no event missed).
      expect(hook.events, hasLength(6));
      // Last event is the expiry from the explicit tick.
      expect(hook.events.last, isA<ConditionExpiredEvent>());
    });
  });
}
