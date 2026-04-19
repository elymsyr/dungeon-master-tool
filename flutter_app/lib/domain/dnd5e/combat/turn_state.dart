import 'action_economy.dart';

/// Tier 0 stateful machine: full turn snapshot.
/// [speedFt] is the base walking speed; [movementUsedFt] accrues as the
/// combatant moves. Dash doubles budget by [extraMovementFt].
class TurnState {
  final ActionEconomy economy;
  final int speedFt;
  final int movementUsedFt;
  final int extraMovementFt;

  const TurnState._(this.economy, this.speedFt, this.movementUsedFt,
      this.extraMovementFt);

  factory TurnState({
    required int speedFt,
    ActionEconomy economy = const ActionEconomy.fresh(),
    int movementUsedFt = 0,
    int extraMovementFt = 0,
  }) {
    if (speedFt < 0) throw ArgumentError('TurnState.speedFt must be >= 0');
    if (movementUsedFt < 0) {
      throw ArgumentError('TurnState.movementUsedFt must be >= 0');
    }
    if (extraMovementFt < 0) {
      throw ArgumentError('TurnState.extraMovementFt must be >= 0');
    }
    return TurnState._(economy, speedFt, movementUsedFt, extraMovementFt);
  }

  int get movementBudgetFt => speedFt + extraMovementFt;
  int get movementRemainingFt =>
      (movementBudgetFt - movementUsedFt).clamp(0, movementBudgetFt);

  TurnState move(int ft) {
    if (ft < 0) throw ArgumentError('move(ft): ft must be >= 0');
    if (ft > movementRemainingFt) {
      throw StateError('Movement $ft ft exceeds remaining $movementRemainingFt');
    }
    return TurnState._(economy, speedFt, movementUsedFt + ft, extraMovementFt);
  }

  TurnState withEconomy(ActionEconomy e) =>
      TurnState._(e, speedFt, movementUsedFt, extraMovementFt);

  TurnState dash() =>
      TurnState._(economy, speedFt, movementUsedFt, extraMovementFt + speedFt);

  TurnState reset(int newSpeedFt) =>
      TurnState._(const ActionEconomy.fresh(), newSpeedFt, 0, 0);

  @override
  bool operator ==(Object other) =>
      other is TurnState &&
      other.economy == economy &&
      other.speedFt == speedFt &&
      other.movementUsedFt == movementUsedFt &&
      other.extraMovementFt == extraMovementFt;
  @override
  int get hashCode =>
      Object.hash(economy, speedFt, movementUsedFt, extraMovementFt);
}
