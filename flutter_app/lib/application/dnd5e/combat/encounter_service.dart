import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/combat/encounter.dart';
import '../../../domain/dnd5e/core/hit_points.dart';
import 'attack_pipeline.dart';
import 'condition_tick_service.dart';
import 'damage_pipeline.dart';
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

/// Top-level composer for one encounter's lifecycle. Owns no rules — every
/// call delegates to a pipeline / service injected at construction. The
/// service's job is plumbing: load → run pipeline → write back via mutator
/// → save through the repository.
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
  /// [TargetDefenses]→[Combatant.copyWith], and persists via repository.
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
    final result = damagePipeline.run(buildInput(atk, tgt, defensesFor(tgt)));
    final updatedTarget = _writeHp(tgt, result.outcome.damage.newCurrentHp);
    final next = mutator.replaceCombatant(e, updatedTarget);
    await repository.save(next);
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
  /// 0-HP combatants by default), persists, and returns the new state.
  Future<Encounter> advanceTurn(String encounterId) async {
    final e = await _load(encounterId);
    final next = rotation.advance(e);
    await repository.save(next);
    return next;
  }

  /// Decrements every combatant's per-round condition durations, removes
  /// expired entries, and persists. Use at end-of-round.
  Future<EncounterTickOutcome> tickConditions(String encounterId) async {
    final e = await _load(encounterId);
    final results = conditionTick.tickAll(e.combatants);
    final next = mutator.replaceAll(
      e,
      [for (final r in results) r.combatant],
    );
    await repository.save(next);
    return EncounterTickOutcome(
      encounter: next,
      expiredByCombatant: {
        for (final r in results)
          if (r.expiredConditionIds.isNotEmpty)
            r.combatant.id: r.expiredConditionIds,
      },
    );
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
}
