import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/combat/encounter.dart';
import '../../../domain/dnd5e/core/hit_points.dart';
import 'attack_pipeline.dart';
import 'condition_tick_service.dart';
import 'damage_pipeline.dart';
import 'encounter_event.dart';
import 'encounter_hook.dart';
import 'encounter_mutator.dart';
import 'encounter_repository.dart';
import 'save_pipeline.dart';
import 'target_defenses.dart';
import 'turn_rotation_service.dart';

/// Outcome envelope for [EncounterService.runAttack]: pipeline result plus
/// the encounter snapshot after any state change. The current attack-only
/// path doesn't write back to the encounter (no HP loss yet — that lives in
/// damage application), so [encounter] is unchanged.
class EncounterAttackOutcome {
  final Encounter encounter;
  final AttackPipelineResult result;

  const EncounterAttackOutcome({
    required this.encounter,
    required this.result,
  });
}

class EncounterDamageOutcome {
  final Encounter encounter;
  final DamagePipelineResult result;

  const EncounterDamageOutcome({
    required this.encounter,
    required this.result,
  });
}

class EncounterSaveOutcome {
  final Encounter encounter;
  final SavePipelineResult result;

  const EncounterSaveOutcome({
    required this.encounter,
    required this.result,
  });
}

/// Tick result for one round-end pass: the new encounter (with all
/// combatants' durations decremented + expired conditions removed) plus the
/// flat list of expired ids per combatant.
class EncounterTickOutcome {
  final Encounter encounter;
  final Map<String, Set<String>> expiredByCombatant;

  EncounterTickOutcome({
    required this.encounter,
    required Map<String, Set<String>> expiredByCombatant,
  }) : expiredByCombatant = Map.unmodifiable({
          for (final e in expiredByCombatant.entries)
            e.key: Set.unmodifiable(e.value),
        });
}

/// Outcome for [EncounterService.applyCondition] / [removeCondition]: the
/// post-mutation encounter and a `changed` flag indicating whether the
/// combatant's condition set actually moved (so callers can suppress the
/// hook event on a no-op).
class EncounterConditionMutationOutcome {
  final Encounter encounter;
  final bool changed;

  const EncounterConditionMutationOutcome({
    required this.encounter,
    required this.changed,
  });
}

/// Top-level composer for one encounter's lifecycle. Owns no rules — every
/// call delegates to a pipeline / service injected at construction. The
/// service's job is plumbing: load → run pipeline → write back via mutator
/// → save through the repository → notify the [hook].
///
/// Stateless across calls; the repository holds the current encounter
/// snapshot. Callers pass the encounter id; the service loads, mutates, and
/// saves in one operation.
class EncounterService {
  final EncounterRepository repository;
  final AttackPipeline attackPipeline;
  final DamagePipeline damagePipeline;
  final SavePipeline savePipeline;
  final TurnRotationService rotation;
  final ConditionTickService conditionTick;
  final EncounterMutator mutator;
  final EncounterHook hook;
  final TargetDefenses Function(Combatant) defensesFor;

  const EncounterService({
    required this.repository,
    required this.attackPipeline,
    required this.damagePipeline,
    required this.savePipeline,
    required this.defensesFor,
    this.rotation = const TurnRotationService(),
    this.conditionTick = const ConditionTickService(),
    this.mutator = const EncounterMutator(),
    this.hook = const CompositeEncounterHook.empty(),
  });

  Future<Encounter> _load(String encounterId) async {
    final e = await repository.findById(encounterId);
    if (e == null) {
      throw StateError('EncounterService: no encounter "$encounterId"');
    }
    return e;
  }

  Combatant _require(Encounter e, String combatantId) {
    final c = e.byId(combatantId);
    if (c == null) {
      throw StateError(
          'EncounterService: no combatant "$combatantId" in encounter "${e.id}"');
    }
    return c;
  }

  /// Resolves an attack roll between two combatants in the same encounter.
  /// Does NOT apply damage — call [applyDamage] in a follow-up step. No
  /// encounter state changes here.
  Future<EncounterAttackOutcome> runAttack({
    required String encounterId,
    required String attackerId,
    required String targetId,
    required AttackPipelineInput Function(Combatant attacker, Combatant target)
        buildInput,
  }) async {
    final e = await _load(encounterId);
    final atk = _require(e, attackerId);
    final tgt = _require(e, targetId);
    final result = attackPipeline.run(buildInput(atk, tgt));
    return EncounterAttackOutcome(encounter: e, result: result);
  }

  /// Applies damage to a combatant, writes the new HP back through
  /// [TargetDefenses]→[Combatant.copyWith], persists via repository, and
  /// emits [DamageDealtEvent] (always), [CombatantDroppedEvent] (if HP
  /// transitioned to 0 / instant-death), and [ConcentrationBrokenEvent]
  /// (if the damage broke the target's concentration).
  Future<EncounterDamageOutcome> applyDamage({
    required String encounterId,
    required String attackerId,
    required String targetId,
    required DamagePipelineInput Function(
            Combatant attacker, Combatant target, TargetDefenses defenses)
        buildInput,
  }) async {
    final e = await _load(encounterId);
    final atk = _require(e, attackerId);
    final tgt = _require(e, targetId);
    final previousHp = tgt.currentHp;
    final previousConcentration = tgt.concentration;
    final result = damagePipeline.run(buildInput(atk, tgt, defensesFor(tgt)));
    final updatedTarget = _writeHp(tgt, result.outcome.damage.newCurrentHp);
    final next = mutator.replaceCombatant(e, updatedTarget);
    await repository.save(next);

    final dmg = result.outcome.damage;
    hook.on(DamageDealtEvent(
      encounterId: next.id,
      round: next.round,
      attackerId: attackerId,
      targetId: targetId,
      damageTypeId: result.modifiedDamage.typeId,
      amountAfterMitigation: dmg.amountAfterMitigation,
      previousCurrentHp: previousHp,
      newCurrentHp: dmg.newCurrentHp,
      dropsToZero: dmg.dropsToZero,
      instantDeath: dmg.instantDeath,
    ));
    if ((dmg.dropsToZero || dmg.instantDeath) && previousHp > 0) {
      hook.on(CombatantDroppedEvent(
        encounterId: next.id,
        round: next.round,
        combatantId: targetId,
        instantDeath: dmg.instantDeath,
      ));
    }
    final conc = result.outcome.concentration;
    if (conc != null && conc.broken) {
      hook.on(ConcentrationBrokenEvent(
        encounterId: next.id,
        round: next.round,
        combatantId: targetId,
        spellId: previousConcentration?.spellId,
        dc: conc.dc,
      ));
    }

    return EncounterDamageOutcome(encounter: next, result: result);
  }

  /// Runs a saving throw for a combatant. No state change.
  Future<EncounterSaveOutcome> requestSave({
    required String encounterId,
    required String saverId,
    required SavePipelineInput Function(Combatant saver) buildInput,
  }) async {
    final e = await _load(encounterId);
    final s = _require(e, saverId);
    final result = savePipeline.run(buildInput(s));
    return EncounterSaveOutcome(encounter: e, result: result);
  }

  /// Advances the active turn marker per [TurnRotationService] (skipping
  /// 0-HP combatants by default), persists, and emits [EndOfTurnEvent] for
  /// the prior actor, [RoundAdvancedEvent] when the order wraps, and
  /// [StartOfTurnEvent] for the new actor.
  Future<Encounter> advanceTurn(String encounterId) async {
    final e = await _load(encounterId);
    final priorActor = e.order.currentId;
    final priorRound = e.round;
    final next = rotation.advance(e);
    await repository.save(next);

    hook.on(EndOfTurnEvent(
      encounterId: next.id,
      round: priorRound,
      combatantId: priorActor,
    ));
    if (next.round != priorRound) {
      hook.on(RoundAdvancedEvent(
        encounterId: next.id,
        round: next.round,
        previousRound: priorRound,
      ));
    }
    hook.on(StartOfTurnEvent(
      encounterId: next.id,
      round: next.round,
      combatantId: next.order.currentId,
    ));
    return next;
  }

  /// Decrements every combatant's per-round condition durations, removes
  /// expired entries, persists, and emits one [ConditionExpiredEvent] per
  /// expired (combatant, condition) pair.
  Future<EncounterTickOutcome> tickConditions(String encounterId) async {
    final e = await _load(encounterId);
    final results = conditionTick.tickAll(e.combatants);
    final next = mutator.replaceAll(
      e,
      [for (final r in results) r.combatant],
    );
    await repository.save(next);

    for (final r in results) {
      for (final cid in r.expiredConditionIds) {
        hook.on(ConditionExpiredEvent(
          encounterId: next.id,
          round: next.round,
          combatantId: r.combatant.id,
          conditionId: cid,
        ));
      }
    }

    return EncounterTickOutcome(
      encounter: next,
      expiredByCombatant: {
        for (final r in results)
          if (r.expiredConditionIds.isNotEmpty)
            r.combatant.id: r.expiredConditionIds,
      },
    );
  }

  /// Adds a condition to a combatant. Persists + emits [ConditionAddedEvent]
  /// on a real change. Re-applying an already-active condition with the
  /// same duration is a no-op (returns `changed: false`, no event).
  /// Re-applying with a different duration overwrites the existing entry
  /// and counts as a change.
  Future<EncounterConditionMutationOutcome> applyCondition({
    required String encounterId,
    required String combatantId,
    required String conditionId,
    int? durationRounds,
  }) async {
    final e = await _load(encounterId);
    final c = _require(e, combatantId);
    final hadCondition = c.conditionIds.contains(conditionId);
    final existingDuration = c.conditionDurationsRounds[conditionId];
    final unchanged = hadCondition && existingDuration == durationRounds;
    if (unchanged) {
      return EncounterConditionMutationOutcome(encounter: e, changed: false);
    }

    final newConditions = {...c.conditionIds, conditionId};
    final newDurations = {...c.conditionDurationsRounds};
    if (durationRounds == null) {
      newDurations.remove(conditionId);
    } else {
      newDurations[conditionId] = durationRounds;
    }
    final updated = _writeConditions(c, newConditions, newDurations);
    final next = mutator.replaceCombatant(e, updated);
    await repository.save(next);

    hook.on(ConditionAddedEvent(
      encounterId: next.id,
      round: next.round,
      combatantId: combatantId,
      conditionId: conditionId,
      durationRounds: durationRounds,
    ));
    return EncounterConditionMutationOutcome(encounter: next, changed: true);
  }

  /// Removes a condition from a combatant. Persists + emits
  /// [ConditionRemovedEvent] on a real removal. Removing a condition that
  /// isn't present is a no-op.
  Future<EncounterConditionMutationOutcome> removeCondition({
    required String encounterId,
    required String combatantId,
    required String conditionId,
  }) async {
    final e = await _load(encounterId);
    final c = _require(e, combatantId);
    if (!c.conditionIds.contains(conditionId)) {
      return EncounterConditionMutationOutcome(encounter: e, changed: false);
    }
    final newConditions = {...c.conditionIds}..remove(conditionId);
    final newDurations = {...c.conditionDurationsRounds}..remove(conditionId);
    final updated = _writeConditions(c, newConditions, newDurations);
    final next = mutator.replaceCombatant(e, updated);
    await repository.save(next);

    hook.on(ConditionRemovedEvent(
      encounterId: next.id,
      round: next.round,
      combatantId: combatantId,
      conditionId: conditionId,
    ));
    return EncounterConditionMutationOutcome(encounter: next, changed: true);
  }

  Combatant _writeHp(Combatant c, int newHp) {
    return switch (c) {
      MonsterCombatant mc => mc.copyWith(instanceCurrentHp: newHp),
      // PC HP lives on Character.hp — rebuild HitPoints with the new current
      // (preserving max + temp) and write back through Character.copyWith.
      PlayerCombatant pc => pc.copyWith(
          character: pc.character.copyWith(
            hp: HitPoints(
              current: newHp,
              max: pc.character.hp.max,
              temp: pc.character.hp.temp,
            ),
          ),
        ),
    };
  }

  Combatant _writeConditions(
    Combatant c,
    Set<String> conditionIds,
    Map<String, int> durations,
  ) {
    return switch (c) {
      MonsterCombatant mc => mc.copyWith(
          conditionIds: conditionIds,
          conditionDurationsRounds: durations,
        ),
      PlayerCombatant pc => pc.copyWith(
          conditionIds: conditionIds,
          conditionDurationsRounds: durations,
        ),
    };
  }
}
