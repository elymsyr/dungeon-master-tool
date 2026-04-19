/// Sealed family of lifecycle events emitted by `EncounterService` after
/// each successful state change. Hooks observe these to surface UI
/// notifications (toasts, log lines), drive AI decisions, or feed an
/// activity journal. Events are pure data — receivers must not assume
/// they can mutate the encounter through them.
sealed class EncounterEvent {
  /// Id of the encounter this event belongs to.
  final String encounterId;

  /// Round number at the moment the event was emitted (1-based, matches
  /// `Encounter.round`).
  final int round;

  const EncounterEvent({required this.encounterId, required this.round});
}

/// Fired immediately after the active turn marker advances to a new
/// combatant. The combatant whose turn it now is referenced by id.
class StartOfTurnEvent extends EncounterEvent {
  final String combatantId;
  const StartOfTurnEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
  });
}

/// Fired for the combatant whose turn just ended (i.e. the active actor
/// before `advanceTurn` was called). Useful for end-of-turn save retries
/// and lingering effect ticks.
class EndOfTurnEvent extends EncounterEvent {
  final String combatantId;
  const EndOfTurnEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
  });
}

/// Fired once when the initiative order wraps back to the first index,
/// signalling a new round began. The [round] value already reflects the
/// post-wrap round number.
class RoundAdvancedEvent extends EncounterEvent {
  final int previousRound;
  const RoundAdvancedEvent({
    required super.encounterId,
    required super.round,
    required this.previousRound,
  });
}

/// Fired after damage was applied to a target. Carries the pre/post HP
/// snapshot so listeners don't need to diff snapshots themselves.
class DamageDealtEvent extends EncounterEvent {
  final String? attackerId;
  final String targetId;
  final String damageTypeId;
  final int amountAfterMitigation;
  final int previousCurrentHp;
  final int newCurrentHp;
  final bool dropsToZero;
  final bool instantDeath;

  const DamageDealtEvent({
    required super.encounterId,
    required super.round,
    required this.attackerId,
    required this.targetId,
    required this.damageTypeId,
    required this.amountAfterMitigation,
    required this.previousCurrentHp,
    required this.newCurrentHp,
    required this.dropsToZero,
    required this.instantDeath,
  });
}

/// Fired when a damage application drops the target's current HP to 0
/// (or triggers instant-death from massive damage). Distinct from
/// [DamageDealtEvent] so listeners can subscribe specifically to
/// drop transitions.
class CombatantDroppedEvent extends EncounterEvent {
  final String combatantId;
  final bool instantDeath;
  const CombatantDroppedEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
    required this.instantDeath,
  });
}

/// Fired when a damage-driven concentration check failed and the target
/// lost their concentration spell. The `spellId` is the spell that was
/// being concentrated on (may be null if the source didn't track it).
class ConcentrationBrokenEvent extends EncounterEvent {
  final String combatantId;
  final String? spellId;
  final int dc;
  const ConcentrationBrokenEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
    required this.spellId,
    required this.dc,
  });
}

/// Fired when a condition is added to a combatant. [durationRounds] is
/// null for open-ended conditions (cleared on save / by the source).
class ConditionAddedEvent extends EncounterEvent {
  final String combatantId;
  final String conditionId;
  final int? durationRounds;
  const ConditionAddedEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
    required this.conditionId,
    required this.durationRounds,
  });
}

/// Fired when a condition is explicitly removed (by save success, source
/// dispelling it, etc.) — distinct from expiration via the round tick.
class ConditionRemovedEvent extends EncounterEvent {
  final String combatantId;
  final String conditionId;
  const ConditionRemovedEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
    required this.conditionId,
  });
}

/// Fired during `tickConditions` for every condition whose duration
/// counter reached 0 this round.
class ConditionExpiredEvent extends EncounterEvent {
  final String combatantId;
  final String conditionId;
  const ConditionExpiredEvent({
    required super.encounterId,
    required super.round,
    required this.combatantId,
    required this.conditionId,
  });
}
