/// Declarative description of a single game-mechanic "Rule".
///
/// A [RuleDefinition] is the named, introspectable counterpart of one effect
/// `kind` understood by `CharacterResolver`. The resolver remains the closed
/// executable interpreter; this catalog is the *declared* surface that drives:
///   - the effect-editor dropdowns (kind + target-kind options),
///   - per-kind param authoring (Phase 1),
///   - validation (Phase 3),
///   - a debug cross-check so the declared and executable surfaces never drift.
///
/// Plain Dart by design — the catalog is code-declared and never serialized
/// into a persisted `WorldSchema`, so it needs no Freezed/JSON support and
/// never touches `computeWorldSchemaContentHash`.
library;

/// Value type of a single rule parameter — tells the generic editor which
/// input primitive to render and the validator which shape to expect.
enum RuleParamType {
  int_,
  string_,
  bool_,
  relation, // single entity reference (uses [RuleParamSpec.relationAllowedTypes])
  enumChoice, // fixed string options (uses [RuleParamSpec.enumOptions])
  abilityList, // list of ability abbreviations (STR/DEX/...)
  dice, // dice notation string ("2d6", "1d8+2")
}

/// Where a param value is stored within the effect-row map.
enum RuleParamLocation {
  /// Top-level row key, e.g. `row['value']` or `row[key]`.
  topLevel,

  /// Nested under `row['payload'][key]`.
  payload,

  /// The `row['target_ref']` reference (paired with `row['target_kind']`).
  targetRef,
}

/// Whether the resolver applies this rule at resolve time, or merely records
/// it for the combat tracker to read at runtime.
enum RuleResolverStatus {
  /// `CharacterResolver.applyEffect` has a real case for it.
  applied,

  /// Recognized but no resolve-time effect — surfaced for the combat tracker.
  deferred,
}

/// Functional grouping used to organize the catalog for the editor / browser.
enum RuleCategory {
  grant,
  bonus,
  defense,
  combat,
  sense,
  movement,
  resource,
  spellcasting,
  meta,
}

/// One authorable parameter of a [RuleDefinition].
class RuleParamSpec {
  final String key;
  final String label;
  final RuleParamType type;
  final RuleParamLocation location;

  /// For [RuleParamType.relation] — allowed target category slugs.
  final List<String> relationAllowedTypes;

  /// For [RuleParamType.enumChoice] — selectable string options.
  final List<String> enumOptions;

  final bool required;

  const RuleParamSpec({
    required this.key,
    required this.label,
    required this.type,
    this.location = RuleParamLocation.topLevel,
    this.relationAllowedTypes = const [],
    this.enumOptions = const [],
    this.required = false,
  });
}

/// Declarative definition of one mechanic rule (one effect `kind`).
class RuleDefinition {
  /// Stable id — equals the effect `kind` string in the wire format.
  final String id;
  final String label;
  final String description;
  final RuleCategory category;

  /// Authorable params beyond `kind`/`target_kind`/`target_ref`.
  final List<RuleParamSpec> params;

  /// Target-kind tokens this rule accepts (drives the Target Kind dropdown).
  /// Empty ⇒ the editor falls back to the universal target-kind list, so no
  /// token authored in existing data ever becomes unselectable.
  final List<String> allowedTargetKinds;

  final bool supportsPredicates;
  final bool supportsScaling;
  final bool supportsActivation;
  final bool supportsPayload;
  final RuleResolverStatus resolverStatus;

  const RuleDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    this.params = const [],
    this.allowedTargetKinds = const [],
    this.supportsPredicates = false,
    this.supportsScaling = false,
    this.supportsActivation = false,
    this.supportsPayload = false,
    this.resolverStatus = RuleResolverStatus.applied,
  });
}

/// A template-scoped collection of [RuleDefinition]s plus the closed predicate
/// enumeration and the universal target-kind fallback list.
class RuleCatalog {
  /// Keyed by [RuleDefinition.id] (== effect kind).
  final Map<String, RuleDefinition> rules;

  /// Closed predicate-kind enum (the `{kind, args}` predicate rows).
  final List<String> predicateKinds;

  /// Universal target-kind fallback — used when a rule declares none, so the
  /// Target Kind dropdown never hides a token present in existing data.
  final List<String> targetKindFallback;

  const RuleCatalog({
    required this.rules,
    this.predicateKinds = const [],
    this.targetKindFallback = const [],
  });

  RuleDefinition? operator [](String kind) => rules[kind];

  bool contains(String kind) => rules.containsKey(kind);

  Iterable<String> get kinds => rules.keys;

  /// Display label for a kind; falls back to the raw kind when undeclared.
  String labelFor(String kind) => rules[kind]?.label ?? kind;

  /// Target-kind options for [kind]: the rule's declared list when non-empty,
  /// otherwise the universal fallback.
  List<String> targetKindsFor(String? kind) {
    final r = kind == null ? null : rules[kind];
    final declared = r?.allowedTargetKinds ?? const <String>[];
    return declared.isNotEmpty ? declared : targetKindFallback;
  }
}
