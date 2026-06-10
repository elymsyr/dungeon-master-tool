/// Trigger taxonomy of the unified rules engine (PR-R2).
///
/// Every rule — explicit (`rule_effects` / `effects` rows) or implicit
/// (compiled from typed fields by `RuleCompiler`) — carries exactly one
/// trigger that says WHEN it participates in resolution:
///
/// | trigger          | fold semantics (stateless resolver)                  |
/// |------------------|------------------------------------------------------|
/// | always_on        | applies every resolve while the source is attached    |
/// | when_granted     | IDENTICAL fold to always_on — the resolver re-derives |
/// |                  | from scratch each read, so there is no event timeline.|
/// |                  | The distinction drives pending-choice generation and  |
/// |                  | editor display only. Do NOT invent stateful semantics.|
/// | when_level_up    | applies when the gate level ≥ `atLevel` (gate = the   |
/// |                  | owning class's level, or total character level)       |
/// | when_equipped    | applies while the owning inventory row is equipped    |
/// | when_attuned     | applies while the owning inventory row is attuned     |
/// |                  | (inert until the attunement runtime ships — PR-R4)    |
/// | prereq_to_grant  | never folds stats: clauses checked, failure → typed   |
/// | prereq_to_equip  | UnmetPrerequisite warning (WARN-KEEP policy). Pickers |
/// | prereq_to_attune | filter on the same clauses via prereq_evaluator.      |
///
/// Wire format: an optional `trigger` key on the effect-row map (absent =
/// context default via [RuleTrigger.defaultFor]), `trigger_args:
/// {at_level: int, gate: 'class'|'character'}` for when_level_up, and
/// `clauses: [...]` (prereq_evaluator vocabulary) on prereq rows.
library;

enum RuleTrigger {
  alwaysOn('always_on'),
  whenGranted('when_granted'),
  whenLevelUp('when_level_up'),
  whenEquipped('when_equipped'),
  whenAttuned('when_attuned'),
  prereqToGrant('prereq_to_grant'),
  prereqToEquip('prereq_to_equip'),
  prereqToAttune('prereq_to_attune');

  /// Stable wire string stored in effect rows.
  final String wire;
  const RuleTrigger(this.wire);

  bool get isPrereq =>
      this == prereqToGrant || this == prereqToEquip || this == prereqToAttune;

  static RuleTrigger? fromWire(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    for (final t in RuleTrigger.values) {
      if (t.wire == raw) return t;
    }
    return null;
  }

  /// Backward-compatible default when a row carries no `trigger` key — this
  /// is what keeps every existing pack/SRD row resolving unchanged:
  ///   - `rule_effects` on weapon / armor / magic-item → [whenEquipped]
  ///   - `rule_effects` on class / subclass / species / subspecies /
  ///     background / trait, and feat `effects` / `granted_modifiers`
  ///     → [alwaysOn]
  ///   - class/subclass `features[].effects` rows → [whenLevelUp] at the
  ///     row's level (the compiler sets `atLevel`; not derivable from the
  ///     category alone, so callers pass `inFeatureRow`).
  static RuleTrigger defaultFor(String categorySlug, {bool inFeatureRow = false}) {
    if (inFeatureRow) return whenLevelUp;
    switch (categorySlug) {
      case 'weapon':
      case 'armor':
      case 'magic-item':
        return whenEquipped;
      default:
        return alwaysOn;
    }
  }
}
