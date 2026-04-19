/// Tier 0 stateful machine. Single turn's spent-flag budget. Resets to
/// [ActionEconomy.fresh] at the start of each combatant's turn.
class ActionEconomy {
  final bool actionUsed;
  final bool bonusUsed;
  final bool reactionUsed;

  const ActionEconomy._(
      this.actionUsed, this.bonusUsed, this.reactionUsed);

  const ActionEconomy.fresh()
      : actionUsed = false,
        bonusUsed = false,
        reactionUsed = false;

  ActionEconomy spendAction() =>
      ActionEconomy._(true, bonusUsed, reactionUsed);
  ActionEconomy spendBonus() =>
      ActionEconomy._(actionUsed, true, reactionUsed);
  ActionEconomy spendReaction() =>
      ActionEconomy._(actionUsed, bonusUsed, true);

  @override
  bool operator ==(Object other) =>
      other is ActionEconomy &&
      other.actionUsed == actionUsed &&
      other.bonusUsed == bonusUsed &&
      other.reactionUsed == reactionUsed;
  @override
  int get hashCode => Object.hash(actionUsed, bonusUsed, reactionUsed);
  @override
  String toString() =>
      'ActionEconomy(a:$actionUsed b:$bonusUsed r:$reactionUsed)';
}
