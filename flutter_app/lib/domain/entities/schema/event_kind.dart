/// Rule engine V3 event taxonomy.
/// Event-driven kurallar bu enum üzerinden trigger'lanır.
/// Serialization: enum name string (örn. "onLongRest").
enum EventKind {
  // ── Lifecycle ──────────────────────────────────────────────────────────────
  onCreate,
  onLevelUp,
  onClassAdded,
  onSubclassUnlocked,

  // ── Rest / Time ────────────────────────────────────────────────────────────
  onShortRest,
  onLongRest,
  onDawn,
  onDusk,

  // ── Combat: Rounds / Turns ─────────────────────────────────────────────────
  onInitiativeRoll,
  onRoundStart,
  onRoundEnd,
  onTurnStart,
  onTurnEnd,

  // ── Combat: Attacks / Damage ───────────────────────────────────────────────
  onAttackMade,
  onAttackHit,
  onAttackMiss,
  onCriticalHit,
  onDamageDealt,
  onDamageTaken,
  onHpZero,
  onDeath,
  onStabilize,

  // ── Conditions / Concentration ─────────────────────────────────────────────
  onConditionApplied,
  onConditionRemoved,
  onConcentrationBroken,

  // ── Spells ─────────────────────────────────────────────────────────────────
  onSpellCast,
  onSpellSlotConsumed,
  onCantripCast,

  // ── Movement ───────────────────────────────────────────────────────────────
  onMove,
  onOpportunityAttackProvoked,

  // ── Equipment ──────────────────────────────────────────────────────────────
  onEquip,
  onUnequip,
  onAttune,
  onUnattune,

  // ── Extension ──────────────────────────────────────────────────────────────
  custom,
}

/// D20 test tipi — D20Trigger ve D20TestService için.
enum D20TestType {
  abilityCheck,
  savingThrow,
  attackRoll,
  initiative,
}

/// Damage direction — DamageTrigger için.
enum DamageDirection {
  taken,   // bu entity alıyor
  dealt,   // bu entity veriyor
}

/// Turn phase — TurnTrigger ve TurnPhasePredicate için.
enum TurnPhase {
  start,
  end,
  beforeAttack,
  afterAttack,
  beforeSave,
  afterSave,
}

/// Action tipi — TurnState / GrantActionEffect / ActionAvailablePredicate için.
enum ActionType {
  action,
  bonusAction,
  reaction,
  free,
  legendary,
  lair,
}

/// ResourceState alan seçici — ResourcePredicate ve ResourceExpr için.
enum ResourceField {
  current,
  max,
  expended,
}

/// Advantage/disadvantage scope — GrantAdvantage/Disadvantage için.
enum AdvantageScope {
  attackRoll,
  savingThrow,
  abilityCheck,
  d20Test,
}

/// Damage modifier operator — DamageRollEffect için.
enum DamageModOp {
  add,
  multiply,
  halve,
  negate,
  minimumDieOf,
  rerollBelow,
}

/// Resource refresh kuralı — ResourceState için.
enum RefreshRule {
  never,
  shortRest,
  longRest,
  dawn,
  turn,
  custom,
}

/// Rule scope — engine içinde rule'u sınıflamak için.
enum RuleScope {
  reactive,
  event,
  d20Test,
  damage,
  turnPhase,
}
