import 'rule_trigger.dart';

/// How a rule's source entity is attached to the character. Determines which
/// implicit-rule derivations run, the trigger defaults, the gate level, and
/// the source label (`feat:Alert`, `species:Dwarf`, ...).
enum RuleAttachment {
  classHeld,
  subclass,
  species,
  subspecies,
  background,
  feat,
  autoFeat,
  trait,
  equippedItem,
  attunedItem,
}

/// One compiled, character-bound rule: a single effect row (or prerequisite
/// clause set) with its trigger, gate, and provenance resolved.
///
/// Produced by `RuleCompiler.compile` from two sources:
///   - EXPLICIT rules — rows authored in `rule_effects` / `effects` /
///     `granted_modifiers` / `features[].effects`;
///   - IMPLICIT (derived) rules — compiled from the typed fields on the card
///     (`granted_skill_refs` → proficiency_grant, `speed_fly_ft` →
///     alternate_speed, `prereq_*` → prerequisite, ...). `derived` is true
///     and `derivedFromField` names the field so editors can render the full
///     effective rule set read-only ("compiled from granted_skill_refs").
///
/// Emission order per entity mirrors the legacy resolver pass bodies
/// EXACTLY — list order is load-bearing: `grantSources`/`skills`/`warnings`
/// orders are user-visible and the PR-R2 parity assert compares full JSON.
class BoundRule {
  final String sourceEntityId;

  /// Source tag in the resolver's historical `kind:Name` shape
  /// (`feat:Alert`, `subspecies:Dwarf/Hill Dwarf`) — flows into
  /// `applyEffect`/`noteSource` unchanged so `grantSources` stays
  /// byte-identical.
  final String sourceLabel;

  final RuleTrigger trigger;

  /// when_level_up gate level (0 = ungated). Compiler only emits rows whose
  /// gate already passes for the character's current levels (legacy-parity
  /// behavior); the value is kept for display/planner use.
  final int atLevel;

  /// Class whose level gates this rule (null = total character level).
  final String? gateClassId;

  /// The effect row, ready for `applyEffect`: `{kind, target_kind?,
  /// target_ref?, value?, payload?, predicates?, scales_with?, ...}`.
  /// Internal compiler-only kinds (handled by the resolver's apply wrapper,
  /// never authored): `trait_grant`, `alternate_speed`, `level_gated_spells`,
  /// `background_asi_apply`, `feat_asi_apply`, `proficiency_grant_raw`,
  /// `prerequisite`.
  final Map<String, dynamic> effect;

  /// Prerequisite clause list (prereq_evaluator vocabulary). Non-empty only
  /// when [trigger] is a prereq trigger; such rules never reach applyEffect.
  final List<Map<String, dynamic>> clauses;

  /// True when the legacy grant path called `noteSource` where the plain
  /// `applyEffect` case does not (species spell/cantrip grants). The apply
  /// wrapper honors this to keep `grantSources` byte-identical. Never
  /// persisted.
  final bool noteSourceOverride;

  /// True = compiled from a typed field (read-only in editors).
  final bool derived;

  /// Field key this rule was derived from (`granted_skill_refs`), null for
  /// explicit rows.
  final String? derivedFromField;

  const BoundRule({
    required this.sourceEntityId,
    required this.sourceLabel,
    required this.trigger,
    required this.effect,
    this.atLevel = 0,
    this.gateClassId,
    this.clauses = const [],
    this.noteSourceOverride = false,
    this.derived = false,
    this.derivedFromField,
  });
}
