/// TemplateRuleResolver — the v3 template rule runtime (SHADOW).
///
/// Roadmap PR-T7 / PR-2.4. This is the eventual replacement for
/// `RuleCompiler` + `BoundRule` + `CharacterResolver`'s ~67 effect kinds (see
/// docs/new_system/the-template-system.md §4). It reads the `rules` attached to
/// a v3 template's [FieldSchema]s and folds them into a derived-stat overlay.
///
/// **Authority status — SHADOW ONLY.** Nothing in the live app calls this yet.
/// The old hardcoded engine (`character_resolver.dart`) stays authoritative
/// until the per-world authority flip in PR-T8/Phase 3.11. This resolver exists
/// so each rule kind can land as a small, independently-verifiable slice with a
/// dev harness (`tool/template_rule_resolver_harness.dart`) and, later, a debug
/// panel that compares old/new outputs on demand. Keeping it inert means a
/// half-built kind never affects a real character sheet.
///
/// **Implemented so far:**
///   * `modify_stat` with all three value sources — a constant (`fixed`, slice
///     1), a stored field read (`field`, slice 2, reading
///     `attachment.values[...]`), and a `formula` (slice 3) evaluated over the
///     PC card's [AspectContext] via `formula_evaluator.dart` (§4.3 grammar:
///     aspect identifiers, arithmetic, `floor/ceil/min/max`, `table(...)`).
///   * `note` (slice 4) — the §4.2 escape hatch: emits `rule['text']` (with
///     `{field_key}` interpolation from the attachment's stored values) into
///     [TemplateResolution.notes] when its trigger is active.
///   * `check_clauses` (slice 4) — evaluates a list of `{aspect, op, value}`
///     comparison clauses (inline, or read from the field's stored rows) against
///     the [AspectContext]; an unmet prerequisite pushes a policy-tagged string
///     into [TemplateResolution.warnings] (the §4.4-step-5 prereq-banner content).
///   * `grant_refs` (slice 5) — collects entity-id refs (traits, languages,
///     resistances, spells, actions) into a PC list-field named by `target`,
///     de-duplicated, in [TemplateResolution.grants].
///   * `grant_proficiency` (slice 5) — sets a proficiency `tier`
///     (`proficient`/`expertise`) on a skillTree field's rows, in
///     [TemplateResolution.proficiencyGrants].
///   * `choose` (slice 6) — emits a *pending choice* rather than folding a final
///     value: an `optionsFrom` (rows/refs) or inline option list, a `pick`
///     count, a `prompt` and optional `target`, surfaced in
///     [TemplateResolution.pendingChoices] (§4.4 step 4). The picker UI/choice
///     persistence and the re-fold of `perPick` effects from a stored selection
///     are a later slice; this slice only surfaces the unanswered choice.
///   * `set_pouch_max` (slice 7) — the first of the pouch kinds. Sets the
///     *maximum* of an `intPouch` (scalar) or `pouchMatrix` (per-row) target
///     field from a source: a level-keyed field read (a `levelTable`
///     `{level: max}` or `levelMatrix` `{level: {row: max}}`, selected at the
///     gate level like the §4.3 `table(...)` function) or a `formula` over the
///     [AspectContext]. Maxima **aggregate across multiclass** — multiple class
///     attachments targeting the same pouch sum their contributions (per-row for
///     a matrix). Emitted into [TemplateResolution.pouchMax], gated by the
///     folding triggers.
///   * `refill_pouch` / `empty_pouch` (slice 8) — the imperative `on_button`
///     pair (§4.2). Unlike every kind above these do **not** fold a derived
///     overlay; they mutate stored pouch *current* values in response to a
///     rest / level-up button press. They are therefore interpreted by a
///     separate entry point, [TemplateRuleResolver.applyButton], rather than by
///     `resolve(...)` — a button press walks the attachments' pouch fields,
///     fires the rules whose `params.button` matches, and computes each pouch's
///     new current from its max (refill: `all` → full, `half_max_round_up` →
///     `ceil(max/2)`, or a formula amount; empty: `all` → 0, or a formula
///     amount), per-row for a `pouchMatrix`. During a `resolve(...)` fold these
///     `on_button` rules are correctly inert (a fold is not the button runtime).
///
/// The last kind (`grant_pouch`) is still recorded in
/// [TemplateResolution.deferred] rather than silently dropped, so the harness
/// shows exactly what remains for later slices.
library;

import '../../entities/schema/field_schema.dart';
import '../../entities/schema/entity_category_schema.dart';
import 'aspect_context.dart';
import 'formula_evaluator.dart';

/// The closed set of 6 rule triggers (the-template-system.md §4.1).
///
/// Only [whenGranted], [levelUp] and [whenEquipped] participate in the
/// stat-fold; [prereqToGrant]/[prereqToEquip] carry clauses (a `check_clauses`
/// concern) and [onButton] is imperative (fired by rest/level-up buttons), so
/// neither folds a stat in this resolver.
abstract final class RuleTriggers {
  static const whenGranted = 'when_granted';
  static const levelUp = 'level_up';
  static const prereqToGrant = 'prereq_to_grant';
  static const whenEquipped = 'when_equipped';
  static const prereqToEquip = 'prereq_to_equip';
  static const onButton = 'on_button';

  /// Absent `trigger` ⇒ always-on, matching the v2 category default for
  /// non-equippable fields (the-template-system.md §4.1 / field_schema doc).
  static const fallback = whenGranted;

  static const all = <String>{
    whenGranted,
    levelUp,
    prereqToGrant,
    whenEquipped,
    prereqToEquip,
    onButton,
  };
}

/// The closed set of 8 rule kinds + the `note` escape hatch
/// (the-template-system.md §4.2). [modifyStat], [note], [checkClauses],
/// [grantRefs], [grantProficiency], [choose] and [setPouchMax] are interpreted
/// by the `resolve(...)` fold; the imperative [refillPouch]/[emptyPouch] pair is
/// interpreted by [TemplateRuleResolver.applyButton] (they mutate stored pouch
/// state on a button press rather than fold an overlay). Only [grantPouch]
/// remains recorded as deferred.
abstract final class RuleKinds {
  static const modifyStat = 'modify_stat';
  static const grantRefs = 'grant_refs';
  static const grantProficiency = 'grant_proficiency';
  static const choose = 'choose';
  static const setPouchMax = 'set_pouch_max';
  static const refillPouch = 'refill_pouch';
  static const emptyPouch = 'empty_pouch';
  static const grantPouch = 'grant_pouch';
  static const checkClauses = 'check_clauses';
  static const note = 'note';
}

/// One rule-bearing entity contributing to a character — a class, subclass,
/// species, background, feat, granted trait or equipped item — paired with the
/// schema that declares its fields' rules and the entity's stored field values.
///
/// The PC card itself is also an attachment (its own fields may carry rules).
class ResolverAttachment {
  /// Stable id of the contributing entity (used in skip/choice keys).
  final String entityId;

  /// The schema whose [FieldSchema]s carry the `rules` to fold.
  final EntityCategorySchema category;

  /// The entity's stored field values, keyed by [FieldSchema.fieldKey].
  /// Used by future value sources (`field`/`formula`); unused this slice.
  final Map<String, dynamic> values;

  /// True when this attachment is currently equipped (gates `when_equipped`).
  final bool isEquipped;

  const ResolverAttachment({
    required this.entityId,
    required this.category,
    this.values = const {},
    this.isEquipped = false,
  });
}

/// A rule that this slice does not yet interpret — surfaced (never silently
/// dropped) so the harness/debug panel shows precisely what later slices owe.
class ResolverSkip {
  final String entityId;
  final String fieldKey;
  final int ruleIndex;
  final String kind;
  final String reason;

  const ResolverSkip({
    required this.entityId,
    required this.fieldKey,
    required this.ruleIndex,
    required this.kind,
    required this.reason,
  });

  @override
  String toString() =>
      '$entityId/$fieldKey#$ruleIndex ($kind): $reason';
}

/// A `choose` rule that has surfaced an unanswered pick (the-template-system.md
/// §4.4 step 4). The picker UI consumes this — [pendingChoices] is the resolver
/// equivalent of "the PC owes a decision".
///
/// A made selection persists on the PC card as data under
/// `rule_choices[<choiceKey>] = [<picked>, …]` (§4.4 step 4). Re-folding the
/// rule's `perPick` effects from a stored selection is a later slice; this
/// record only carries what the picker needs to render the prompt.
class PendingChoice {
  /// The contributing entity that owns the `choose` rule (class/feat/species…).
  final String entityId;

  /// The field whose rule emitted this choice.
  final String fieldKey;

  /// The rule's stable id (`rule['ruleId']`), or `rule#<index>` when absent —
  /// the third segment of [choiceKey].
  final String ruleId;

  /// Player-facing prompt shown by the picker.
  final String prompt;

  /// The selectable option ids/labels (entity refs, ability keys, or inline
  /// strings), in declaration order.
  final List<String> options;

  /// How many of [options] the player must pick (≥ 1).
  final int pick;

  /// Optional PC list-field the made selection is written into (e.g.
  /// `subclass_refs`); informational for this slice (the write happens when the
  /// choice is resolved, a later slice).
  final String? target;

  const PendingChoice({
    required this.entityId,
    required this.fieldKey,
    required this.ruleId,
    required this.prompt,
    required this.options,
    required this.pick,
    this.target,
  });

  /// Persistence key under the PC card's `rule_choices` map (§4.4 step 4):
  /// `<entityId>:<fieldKey>:<ruleId>`.
  String get choiceKey => '$entityId:$fieldKey:$ruleId';

  @override
  String toString() =>
      '$choiceKey — "$prompt" (pick $pick of ${options.length}'
      '${target == null ? '' : ' → $target'})';
}

/// The resolver's output overlay — an `EffectiveCharacter`-equivalent in the
/// making (the-template-system.md §4.4 step 5). [statDeltas] comes from
/// `modify_stat`; [notes] from `note` rules; [warnings] from `check_clauses`.
class TemplateResolution {
  /// Summed additive deltas per aspect path (e.g. `{'ac': 2, 'speed': 10}`).
  final Map<String, num> statDeltas;

  /// Player-facing rule text emitted by `note` rules, in fold order.
  final List<String> notes;

  /// Prerequisite/validation warnings emitted by `check_clauses`, in fold order
  /// — the policy-tagged content of the §4.4-step-5 prereq banner.
  final List<String> warnings;

  /// Entity-id refs granted into a PC list-field by `grant_refs` (§4.2:
  /// traits/languages/resistances/spells/actions), keyed by the target list-field
  /// key and de-duplicated in fold order (e.g.
  /// `{'resistances': ['fire', 'cold']}`).
  final Map<String, List<String>> grants;

  /// Proficiency tiers set on a skillTree field's rows by `grant_proficiency`
  /// (§4.2), keyed by the target skillTree fieldKey then row name → tier
  /// (`proficient`/`expertise`); e.g. `{'skills': {'Stealth': 'expertise'}}`.
  /// `expertise` outranks `proficient` when a row is granted twice.
  final Map<String, Map<String, String>> proficiencyGrants;

  /// Unanswered `choose` rules (§4.4 step 4), in fold order — the picks the PC
  /// still owes. Each carries its options/prompt/pick for the picker UI.
  final List<PendingChoice> pendingChoices;

  /// Pouch *maxima* set by `set_pouch_max` (§4.2), keyed by the target pouch
  /// field key. The value is either a `num` (an `intPouch` scalar max) or a
  /// `Map<String, num>` (a `pouchMatrix` per-row max, keyed by row key). Maxima
  /// are summed across attachments (per-row for a matrix), so multiclass
  /// spell-slot / resource progressions aggregate, e.g.
  /// `{'spell_slots': {'1': 5, '2': 4}, 'ki_points': 5}`.
  final Map<String, dynamic> pouchMax;

  /// Rules not interpreted by this slice (kind or value-source not yet built).
  final List<ResolverSkip> deferred;

  const TemplateResolution({
    required this.statDeltas,
    required this.notes,
    required this.warnings,
    required this.grants,
    required this.proficiencyGrants,
    required this.pendingChoices,
    required this.pouchMax,
    required this.deferred,
  });

  /// The net delta accumulated for [aspect] (0 when untouched).
  num delta(String aspect) => statDeltas[aspect] ?? 0;

  /// The de-duplicated refs granted into [fieldKey] (empty when none).
  List<String> grantsFor(String fieldKey) => grants[fieldKey] ?? const [];

  /// The tier (`proficient`/`expertise`) granted to [rowName] in skillTree
  /// [fieldKey], or `null` when that row got no grant.
  String? proficiencyFor(String fieldKey, String rowName) =>
      proficiencyGrants[fieldKey]?[rowName];

  /// The unanswered `choose` emitted by [entityId]'s [fieldKey] rule, or `null`
  /// when that field surfaced no pending choice.
  PendingChoice? choiceFor(String entityId, String fieldKey) {
    for (final choice in pendingChoices) {
      if (choice.entityId == entityId && choice.fieldKey == fieldKey) {
        return choice;
      }
    }
    return null;
  }

  /// The aggregated maximum set on pouch [fieldKey] — a `num` (intPouch) or a
  /// `Map<String, num>` (pouchMatrix), or `null` when no `set_pouch_max` rule
  /// targeted it (e.g. its progression has no row at or below the gate level).
  dynamic pouchMaxFor(String fieldKey) => pouchMax[fieldKey];

  /// The per-row maximum for row [rowKey] of pouchMatrix [fieldKey], or `null`
  /// when that field/row got no max (or [fieldKey] is a scalar intPouch).
  num? pouchRowMax(String fieldKey, String rowKey) {
    final max = pouchMax[fieldKey];
    if (max is Map) {
      final v = max[rowKey];
      return v is num ? v : null;
    }
    return null;
  }

  bool get isEmpty =>
      statDeltas.isEmpty &&
      notes.isEmpty &&
      warnings.isEmpty &&
      grants.isEmpty &&
      proficiencyGrants.isEmpty &&
      pendingChoices.isEmpty &&
      pouchMax.isEmpty;
}

/// Stateless fold over a v3 template's rule attachments.
///
/// Deterministic order (the-template-system.md §4.4 step 3): attachment order
/// as supplied → field [orderIndex] → rule index. The fold is a pure
/// re-derive (same invariant as the old engine): no event log, no mutation of
/// the inputs.
class TemplateRuleResolver {
  const TemplateRuleResolver();

  /// Fold [attachments] into a derived-stat overlay.
  ///
  /// [gateLevel] is the character level used to gate `level_up` rules
  /// (`row.level <= gateLevel`); defaults to a high value so an ungated harness
  /// run applies every level rule. [aspects] is the PC card's aspect map
  /// (§4.3) — read by the `formula` value source (slice 3); the already-built
  /// `fixed`/`field` sources don't need it, but it is threaded now so the fold
  /// signature is stable. Pure — returns a fresh [TemplateResolution].
  TemplateResolution resolve(
    List<ResolverAttachment> attachments, {
    int gateLevel = 1 << 20,
    AspectContext aspects = AspectContext.empty,
  }) {
    final statDeltas = <String, num>{};
    final notes = <String>[];
    final warnings = <String>[];
    final grants = <String, List<String>>{};
    final proficiencyGrants = <String, Map<String, String>>{};
    final pendingChoices = <PendingChoice>[];
    final pouchMax = <String, dynamic>{};
    final deferred = <ResolverSkip>[];

    for (final attachment in attachments) {
      final fields = [...attachment.category.fields]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (final field in fields) {
        final rules = field.rules ?? const <Map<String, dynamic>>[];
        for (var i = 0; i < rules.length; i++) {
          _foldRule(
            attachment: attachment,
            field: field,
            rule: rules[i],
            ruleIndex: i,
            gateLevel: gateLevel,
            aspects: aspects,
            statDeltas: statDeltas,
            notes: notes,
            warnings: warnings,
            grants: grants,
            proficiencyGrants: proficiencyGrants,
            pendingChoices: pendingChoices,
            pouchMax: pouchMax,
            deferred: deferred,
          );
        }
      }
    }

    return TemplateResolution(
      statDeltas: statDeltas,
      notes: notes,
      warnings: warnings,
      grants: grants,
      proficiencyGrants: proficiencyGrants,
      pendingChoices: pendingChoices,
      pouchMax: pouchMax,
      deferred: deferred,
    );
  }

  /// Apply a `button` press (the-template-system.md §4.2 / §6 item 6) — one of
  /// `long_rest` / `short_rest` / `level_up` — to the pouch fields across
  /// [attachments], firing the `refill_pouch` / `empty_pouch` rules that name
  /// that button and returning each touched pouch's **new current** value.
  ///
  /// These are the imperative `on_button` kinds: unlike the fold in
  /// [resolve], they mutate stored pouch state rather than derive an overlay,
  /// so they live behind this separate entry point. The fold and the button
  /// runtime never overlap — `resolve(...)` leaves these rules inert.
  ///
  /// A rule fires when it is a `refill_pouch`/`empty_pouch` kind, its trigger is
  /// `on_button` (the §4.1 imperative trigger), and its `params.button` (or
  /// top-level `button`) equals [button]. The pouch it acts on is its
  /// `params.target` (or top-level `target`), defaulting to the **field's own
  /// key** — refill/empty rules are declared *on the target pouch field*
  /// (§2.3), so the common case needs no `target`.
  ///
  /// The new current is computed from the pouch's max and prior current:
  ///   * **refill** — `amount: all` (or absent) restores to full (`current =
  ///     max`); `half_max_round_up` adds `ceil(max/2)` (capped at max); a
  ///     formula/number adds that many (capped at max). `current = min(prior +
  ///     amount, max)`.
  ///   * **empty** — `amount: all` (or absent) drains to 0; a formula/number
  ///     spends that many. `current = max(prior - amount, 0)`.
  ///
  /// A `pouchMatrix` (a per-row `Map<String, num>` max/current) is processed
  /// **per row**; an `intPouch` (a scalar) as a single value. Maxima come from
  /// [pouchMax] (the [resolve] overlay — typically the same run's output);
  /// prior currents from [currentValues], keyed by pouch field key (a scalar
  /// `num`, or a per-row `Map<String, num>` — the caller normalizes the stored
  /// `intPouch` `current` / `pouchMatrix` `remaining` into this shape). Multiple
  /// rules touching the same pouch chain in fold order (each sees the prior
  /// result). [aspects] feeds formula amounts.
  ///
  /// Returns only the pouches a fired rule touched → their new current (a `num`
  /// or `Map<String, num>`). Pure — mutates no input.
  Map<String, dynamic> applyButton(
    List<ResolverAttachment> attachments, {
    required String button,
    Map<String, dynamic> pouchMax = const {},
    Map<String, dynamic> currentValues = const {},
    AspectContext aspects = AspectContext.empty,
  }) {
    final updated = <String, dynamic>{};

    for (final attachment in attachments) {
      final fields = [...attachment.category.fields]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (final field in fields) {
        final rules = field.rules ?? const <Map<String, dynamic>>[];
        for (final rule in rules) {
          final kind = (rule['kind'] as String?)?.trim() ?? '';
          if (kind != RuleKinds.refillPouch && kind != RuleKinds.emptyPouch) {
            continue;
          }
          final trigger = (rule['trigger'] as String?)?.trim() ?? '';
          // Refill/empty are inherently imperative; only an on_button rule fires
          // on a button press (a misauthored trigger simply does nothing here).
          if (trigger != RuleTriggers.onButton) continue;
          final ruleButton = _ruleParamString(rule, 'button');
          if (ruleButton != button) continue;

          final target =
              _ruleParamString(rule, 'target') ?? field.fieldKey;
          // Prior current: the running result first (so chained rules on the
          // same pouch see each other), else the caller-supplied current.
          final prior = updated.containsKey(target)
              ? updated[target]
              : currentValues[target];
          final next = _applyPouchButton(
            isRefill: kind == RuleKinds.refillPouch,
            rule: rule,
            prior: prior,
            max: pouchMax[target],
            aspects: aspects,
          );
          if (next != null) updated[target] = next;
        }
      }
    }

    return updated;
  }

  /// Compute one pouch's new current for a refill/empty button rule. Dispatches
  /// to a per-row computation for a `pouchMatrix` (when [max] or [prior] is a
  /// `Map`) or a scalar computation for an `intPouch`. Returns `null` only when
  /// nothing could be computed (an unresolvable amount and no max/prior to act
  /// on) — the caller then leaves the pouch untouched rather than corrupt it.
  dynamic _applyPouchButton({
    required bool isRefill,
    required Map<String, dynamic> rule,
    required dynamic prior,
    required dynamic max,
    required AspectContext aspects,
  }) {
    if (max is Map || prior is Map) {
      final rowKeys = <String>{
        if (max is Map) ...max.keys.map((k) => '$k'),
        if (prior is Map) ...prior.keys.map((k) => '$k'),
      };
      final out = <String, num>{};
      for (final key in rowKeys) {
        final rowMax = max is Map ? _coerceNum(max[key]) : null;
        final rowPrior = prior is Map ? (_coerceNum(prior[key]) ?? 0) : 0;
        final v = _computePouchCurrent(
          isRefill: isRefill,
          rule: rule,
          prior: rowPrior,
          max: rowMax,
          aspects: aspects,
        );
        if (v != null) out[key] = v;
      }
      return out.isEmpty ? null : out;
    }

    return _computePouchCurrent(
      isRefill: isRefill,
      rule: rule,
      prior: _coerceNum(prior) ?? 0,
      max: _coerceNum(max),
      aspects: aspects,
    );
  }

  /// The scalar refill/empty computation. [prior] is the current value, [max]
  /// the pouch maximum (possibly `null` when no `set_pouch_max` fed it).
  ///
  /// Refill: `amount: all`/absent → full (`max`, or `prior` when no max known);
  /// `half_max_round_up` → `min(prior + ceil(max/2), max)`; a formula/number →
  /// `min(prior + amount, max)`. Empty: `all`/absent → `0`; a formula/number →
  /// `max(prior - amount, 0)`. Returns `null` when an amount can't be resolved
  /// (e.g. a `half_max_round_up`/formula with no max) so the pouch is left as-is.
  num? _computePouchCurrent({
    required bool isRefill,
    required Map<String, dynamic> rule,
    required num prior,
    required num? max,
    required AspectContext aspects,
  }) {
    final raw = _pouchAmountRaw(rule);
    final spec = raw is String ? raw.trim().toLowerCase() : null;
    final isAll = raw == null || spec == 'all';

    if (isRefill) {
      if (isAll) return max ?? prior;
      final amount = _pouchAmountValue(raw, spec, max, aspects);
      if (amount == null) return null;
      final next = prior + amount;
      if (max == null) return next < 0 ? 0 : next;
      return next > max ? max : (next < 0 ? 0 : next);
    } else {
      if (isAll) return 0;
      final amount = _pouchAmountValue(raw, spec, max, aspects);
      if (amount == null) return null;
      final next = prior - amount;
      return next < 0 ? 0 : next;
    }
  }

  /// Raw `amount` of a refill/empty rule (top-level, else under `params`).
  dynamic _pouchAmountRaw(Map<String, dynamic> rule) {
    final top = rule['amount'];
    if (top != null) return top;
    final params = rule['params'];
    if (params is Map) return params['amount'];
    return null;
  }

  /// Resolve a non-`all` refill/empty amount to a number:
  ///   * `half_max_round_up` → `ceil(max/2)` (needs a max; `null` without one);
  ///   * a number → itself;
  ///   * a string → a §4.3 formula over [aspects] (a bare numeric string parses
  ///     too); a malformed/erroring formula → `null` (the pouch is left as-is).
  num? _pouchAmountValue(
    dynamic raw,
    String? spec,
    num? max,
    AspectContext aspects,
  ) {
    if (spec == 'half_max_round_up') {
      if (max == null) return null;
      return (max / 2).ceil();
    }
    if (raw is num) return raw;
    if (raw is String) {
      final expr = raw.trim();
      if (expr.isEmpty) return null;
      try {
        return const FormulaEvaluator().evaluate(expr, aspects);
      } on FormulaException {
        return null;
      }
    }
    return null;
  }

  void _foldRule({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required int gateLevel,
    required AspectContext aspects,
    required Map<String, num> statDeltas,
    required List<String> notes,
    required List<String> warnings,
    required Map<String, List<String>> grants,
    required Map<String, Map<String, String>> proficiencyGrants,
    required List<PendingChoice> pendingChoices,
    required Map<String, dynamic> pouchMax,
    required List<ResolverSkip> deferred,
  }) {
    final kind = (rule['kind'] as String?)?.trim() ?? '';
    final trigger = (rule['trigger'] as String?)?.trim().isNotEmpty == true
        ? (rule['trigger'] as String).trim()
        : RuleTriggers.fallback;

    if (kind.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind, 'rule missing "kind"'));
      return;
    }

    // Dispatch on rule kind. Interpreted kinds handle their own trigger gate;
    // any other kind is owed (recorded in `deferred`, never silently dropped).
    switch (kind) {
      case RuleKinds.modifyStat:
        _foldModifyStat(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          aspects: aspects,
          statDeltas: statDeltas,
          deferred: deferred,
        );
      case RuleKinds.note:
        _foldNote(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          notes: notes,
          deferred: deferred,
        );
      case RuleKinds.checkClauses:
        _foldCheckClauses(
          attachment: attachment,
          field: field,
          rule: rule,
          trigger: trigger,
          aspects: aspects,
          warnings: warnings,
        );
      case RuleKinds.grantRefs:
        _foldGrantRefs(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          grants: grants,
          deferred: deferred,
        );
      case RuleKinds.grantProficiency:
        _foldGrantProficiency(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          proficiencyGrants: proficiencyGrants,
          deferred: deferred,
        );
      case RuleKinds.choose:
        _foldChoose(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          pendingChoices: pendingChoices,
          deferred: deferred,
        );
      case RuleKinds.setPouchMax:
        _foldSetPouchMax(
          attachment: attachment,
          field: field,
          rule: rule,
          ruleIndex: ruleIndex,
          kind: kind,
          trigger: trigger,
          gateLevel: gateLevel,
          aspects: aspects,
          pouchMax: pouchMax,
          deferred: deferred,
        );
      case RuleKinds.refillPouch:
      case RuleKinds.emptyPouch:
        // Imperative on_button kinds — they mutate stored pouch *current* values
        // on a rest / level-up button press, NOT a derived overlay. They are
        // applied by [applyButton], so during a fold they are correctly inert
        // (this is not a silent drop: the fold simply isn't their runtime).
        break;
      default:
        deferred.add(
          _skip(attachment, field, ruleIndex, kind, 'kind not implemented in this slice'),
        );
    }
  }

  /// `modify_stat` (§4.2): sum a value source into [statDeltas] under a target
  /// aspect path, gated by a folding trigger.
  void _foldModifyStat({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required AspectContext aspects,
    required Map<String, num> statDeltas,
    required List<ResolverSkip> deferred,
  }) {
    // Trigger gate: only the folding triggers contribute a stat delta.
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      // Inactive folding trigger ⇒ correctly contributes nothing (not a skip).
      // Non-folding triggers (prereq_*, on_button) are recorded as deferred so
      // a modify_stat authored under them is visibly unhandled here.
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(_skip(attachment, field, ruleIndex, kind,
            'trigger "$trigger" is not a stat-fold trigger'));
      }
      return;
    }

    final target = (rule['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'modify_stat missing "target" aspect path'));
      return;
    }

    final resolved =
        _resolveValueSource(rule['value'], attachment, field, aspects);
    if (resolved.value == null) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          resolved.reason ?? 'value source could not be resolved'));
      return;
    }

    statDeltas[target] = (statDeltas[target] ?? 0) + resolved.value!;
  }

  /// `note` (§4.2): the escape hatch. Emit the rule's text — with `{field_key}`
  /// placeholders interpolated from the attachment's stored values — into
  /// [notes] when the note is active. A note is always surfaced (it is just
  /// informational text), except `when_equipped` (only when equipped) and
  /// `level_up` (only once the gate level is reached).
  void _foldNote({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required List<String> notes,
    required List<ResolverSkip> deferred,
  }) {
    if (!_noteActive(trigger, attachment, rule, gateLevel)) return;

    final raw = (rule['text'] as String?) ?? (rule['note'] as String?);
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      deferred.add(
        _skip(attachment, field, ruleIndex, kind, 'note rule missing "text"'),
      );
      return;
    }

    notes.add(_interpolate(text, attachment));
  }

  /// `check_clauses` (§4.2 / §4.4 step 5): evaluate a list of comparison clauses
  /// against the aspect context; an unmet clause pushes a policy-tagged warning.
  ///
  /// Clauses are read inline from `rule['clauses']` (or `rule['params']
  /// ['clauses']`), falling back to the field's own stored rows
  /// (`attachment.values[field.fieldKey]`, the `prereq-clauses` recordList).
  /// Each clause is `{aspect|field, op, value}`. `policy` ∈ `warn` (default) /
  /// `block` — both surface here; the block/warn split governs how a *picker*
  /// vs the *sheet* reacts, a later call-site concern.
  void _foldCheckClauses({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required String trigger,
    required AspectContext aspects,
    required List<String> warnings,
  }) {
    if (!_checkActive(trigger, attachment)) return;

    final clauses = _gatherClauses(rule, attachment, field);
    // No clauses ⇒ no prerequisites ⇒ trivially satisfied (not a skip).
    if (clauses.isEmpty) return;

    final policy = _clausePolicy(rule);

    for (final clause in clauses) {
      final result = _evalClause(clause, aspects);
      if (result.reason != null) {
        // A malformed clause is a template-authoring error — surface it loudly
        // so it is never silently treated as "passing".
        warnings.add('${attachment.entityId} [clause error]: ${result.reason}');
        continue;
      }
      if (result.passed == false) {
        final aspectName =
            (clause['aspect'] ?? clause['field']).toString().trim();
        final op = (clause['op'] as String?)?.trim().isNotEmpty == true
            ? (clause['op'] as String).trim()
            : '>=';
        final need = clause['value'];
        final have = aspects.value(aspectName);
        warnings.add('${attachment.entityId} [$policy]: requires '
            '$aspectName $op $need (have $have)');
      }
    }
  }

  /// `grant_refs` (§4.2): collect entity-id refs into a PC list-field named by
  /// `target`, de-duplicated in fold order. Refs come from inline `rule['refs']`
  /// (or `params.refs`), else the rule's **own** stored field value
  /// (`attachment.values[field.fieldKey]`). Gated by the folding triggers — a
  /// `level_up` grant only lands once the gate level is reached; an unequipped
  /// item's `when_equipped` grant contributes nothing (not a skip). A grant
  /// authored under a non-folding trigger, a missing `target`, or no resolvable
  /// refs is surfaced as deferred, never silently dropped.
  void _foldGrantRefs({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required Map<String, List<String>> grants,
    required List<ResolverSkip> deferred,
  }) {
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(_skip(attachment, field, ruleIndex, kind,
            'trigger "$trigger" is not a grant trigger'));
      }
      return;
    }

    final target = (rule['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'grant_refs missing "target" list-field key'));
      return;
    }

    final refs = _gatherStrings(
      rule,
      attachment,
      field,
      inlineKey: 'refs',
      mapKeys: const ['id', 'ref', 'entity_id', 'slug'],
    );
    if (refs.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'grant_refs found no refs (inline "refs" or stored field '
          '"${field.fieldKey}")'));
      return;
    }

    final bucket = grants.putIfAbsent(target, () => <String>[]);
    for (final ref in refs) {
      if (!bucket.contains(ref)) bucket.add(ref);
    }
  }

  /// `grant_proficiency` (§4.2): set a proficiency tier on a skillTree field's
  /// rows. `target` is the skillTree fieldKey; `tier` ∈ `proficient`/`expertise`
  /// (default `proficient`); the affected rows come from inline `rule['rows']`
  /// (or `params.rows`), else the rule's own stored field value. Recorded into
  /// [proficiencyGrants] as `{target: {rowName: tier}}`; `expertise` outranks
  /// `proficient` when a row is granted twice. Same trigger gating as
  /// `grant_refs`; a non-folding trigger / missing target / no rows defers.
  void _foldGrantProficiency({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required Map<String, Map<String, String>> proficiencyGrants,
    required List<ResolverSkip> deferred,
  }) {
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(_skip(attachment, field, ruleIndex, kind,
            'trigger "$trigger" is not a grant trigger'));
      }
      return;
    }

    final target = (rule['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'grant_proficiency missing "target" skillTree field key'));
      return;
    }

    final rows = _gatherStrings(
      rule,
      attachment,
      field,
      inlineKey: 'rows',
      mapKeys: const ['name', 'row', 'skill', 'ability'],
    );
    if (rows.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'grant_proficiency found no rows (inline "rows" or stored field '
          '"${field.fieldKey}")'));
      return;
    }

    final tier = _proficiencyTier(rule);
    final bucket =
        proficiencyGrants.putIfAbsent(target, () => <String, String>{});
    for (final row in rows) {
      bucket[row] = _higherTier(bucket[row], tier);
    }
  }

  /// `choose` (§4.2 / §4.4 step 4): surface an unanswered pick rather than fold a
  /// final value. Options come from inline `params['options']` (or top-level
  /// `options`), else — per `optionsFrom` (`rows`/`refs`) — the rule's own stored
  /// field value (`attachment.values[field.fieldKey]`: a recordList's rows or a
  /// ref list). `pick` (default 1), `prompt` and an optional `target` PC
  /// list-field round out the [PendingChoice]. Gated by the folding triggers — a
  /// `level_up` choice only surfaces once its gate level is reached; an
  /// unequipped item's `when_equipped` choice surfaces nothing (not a skip). A
  /// choice authored under a non-folding trigger, or one with no resolvable
  /// options, is surfaced as deferred, never silently dropped.
  ///
  /// This slice only *emits* the pending choice; recording a selection and
  /// re-folding the rule's `perPick` effects from it is a later slice.
  void _foldChoose({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required List<PendingChoice> pendingChoices,
    required List<ResolverSkip> deferred,
  }) {
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(_skip(attachment, field, ruleIndex, kind,
            'trigger "$trigger" is not a choose trigger'));
      }
      return;
    }

    final options = _gatherStrings(
      rule,
      attachment,
      field,
      inlineKey: 'options',
      mapKeys: const [
        'id',
        'ref',
        'value',
        'ability',
        'name',
        'option',
        'entity_id',
        'slug',
        'choiceId',
      ],
    );
    if (options.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'choose found no options (inline "options", "optionsFrom", or stored '
          'field "${field.fieldKey}")'));
      return;
    }

    final pick = _choosePick(rule);
    final prompt = _ruleParamString(rule, 'prompt') ??
        (pick > 1 ? 'Choose $pick options' : 'Choose an option');
    final target = _ruleParamString(rule, 'target');
    final ruleId = _ruleParamString(rule, 'ruleId') ?? 'rule#$ruleIndex';

    pendingChoices.add(PendingChoice(
      entityId: attachment.entityId,
      fieldKey: field.fieldKey,
      ruleId: ruleId,
      prompt: prompt,
      options: options,
      pick: pick,
      target: target,
    ));
  }

  /// `set_pouch_max` (§4.2): set the *maximum* of a pouch target field from a
  /// level-keyed progression or a formula, aggregating across attachments.
  ///
  /// `target` names the PC pouch field (an `intPouch` or `pouchMatrix`). The
  /// source is read via [_resolvePouchSource]:
  ///   * a level-keyed field — a `levelTable` (`{level: max}`) or `levelMatrix`
  ///     (`{level: {row: max}}`) — selected at [gateLevel] like the §4.3
  ///     `table(...)` step function (the highest level row ≤ gate). A matrix row
  ///     yields a per-row `Map<String, num>`; a table yields a scalar `num`.
  ///   * a `formula` over the [AspectContext] (a scalar `num`).
  ///
  /// Contributions accumulate into [pouchMax] *by sum* — multiple class cards
  /// targeting the same pouch combine (per-row for a matrix), so a multiclass
  /// caster's slots aggregate. Gated by the folding triggers (`set_pouch_max`
  /// lives on a `when_granted` class field in the built-in; the gate level —
  /// not the trigger — selects the progression row). A progression with no row
  /// at or below the gate contributes nothing (not a skip — the class simply has
  /// no slots yet). A non-folding trigger, a missing `target`, an unresolvable
  /// source, or a shape clash (scalar vs matrix on the same target) is surfaced
  /// as deferred, never silently dropped.
  void _foldSetPouchMax({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required String kind,
    required String trigger,
    required int gateLevel,
    required AspectContext aspects,
    required Map<String, dynamic> pouchMax,
    required List<ResolverSkip> deferred,
  }) {
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(_skip(attachment, field, ruleIndex, kind,
            'trigger "$trigger" is not a set_pouch_max trigger'));
      }
      return;
    }

    final target = (rule['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      deferred.add(_skip(attachment, field, ruleIndex, kind,
          'set_pouch_max missing "target" pouch field key'));
      return;
    }

    final resolved =
        _resolvePouchSource(rule, attachment, field, gateLevel, aspects);
    if (resolved.reason != null) {
      deferred.add(_skip(attachment, field, ruleIndex, kind, resolved.reason!));
      return;
    }
    // A legitimately empty contribution (progression below the gate level): the
    // class has no slots yet — nothing to add, and not an error.
    if (resolved.value == null) return;

    final clash =
        _accumulatePouchMax(pouchMax, target, resolved.value as Object);
    if (clash != null) {
      deferred.add(_skip(attachment, field, ruleIndex, kind, clash));
    }
  }

  /// Resolve a `set_pouch_max` source to either a scalar `num` (intPouch max) or
  /// a `Map<String, num>` (pouchMatrix per-row max). The source is, in order:
  ///   * `rule['source']` / `rule['params']['source']` — `{kind: 'formula',
  ///     expr}` (a scalar over [aspects]) or `{kind: 'field', field}` (a stored
  ///     level-keyed map), else
  ///   * the rule's own stored field value (`attachment.values[field.fieldKey]`
  ///     — the slot-progression `levelMatrix`/`levelTable` data).
  ///
  /// A returned `(value: null, reason: null)` means a valid-but-empty
  /// contribution (no progression row ≤ [gateLevel]); a non-null `reason` is a
  /// hard deferral.
  ({Object? value, String? reason}) _resolvePouchSource(
    Map<String, dynamic> rule,
    ResolverAttachment attachment,
    FieldSchema field,
    int gateLevel,
    AspectContext aspects,
  ) {
    dynamic source = rule['source'];
    if (source is! Map) {
      final params = rule['params'];
      if (params is Map && params['source'] is Map) source = params['source'];
    }

    // Explicit formula source → a scalar max.
    if (source is Map && (source['kind'] as String?)?.trim() == 'formula') {
      final expr = (source['expr'] as String?)?.trim();
      if (expr == null || expr.isEmpty) {
        return (value: null, reason: 'set_pouch_max formula source missing "expr"');
      }
      try {
        return (value: const FormulaEvaluator().evaluate(expr, aspects),
            reason: null);
      } on FormulaException catch (e) {
        return (value: null, reason: 'formula "$expr" failed: ${e.message}');
      }
    }

    // Field source (explicit key) or the rule's own field — a level-keyed map.
    dynamic raw;
    if (source is Map && (source['kind'] as String?)?.trim() == 'field') {
      final key = (source['field'] as String?)?.trim();
      raw = attachment.values[(key != null && key.isNotEmpty)
          ? key
          : field.fieldKey];
    } else {
      raw = attachment.values[field.fieldKey];
    }

    if (raw is num) return (value: raw, reason: null);
    if (raw is! Map) {
      return (
        value: null,
        reason: 'set_pouch_max source for "${field.fieldKey}" is not a '
            'level-keyed map, number, or formula '
            '(${raw == null ? 'absent' : raw.runtimeType})',
      );
    }

    return _selectAtLevel(raw, gateLevel);
  }

  /// Select the value of a level-keyed map at [gateLevel] — the entry whose
  /// integer key is the highest value ≤ [gateLevel] (the §4.3 `table(...)` step
  /// semantics; D&D slot tables are cumulative, so the single matching row is
  /// the full count, not a sum across levels).
  ///
  /// A `levelMatrix` (values are maps) yields a `Map<String, num>` row; a
  /// `levelTable` (values are numbers) yields a scalar `num`. No key ≤ gate ⇒
  /// `(value: null, reason: null)` (empty, not an error).
  ({Object? value, String? reason}) _selectAtLevel(
    Map<dynamic, dynamic> data,
    int gateLevel,
  ) {
    int? bestLevel;
    dynamic bestValue;
    for (final entry in data.entries) {
      final lvl = _coerceNum(entry.key)?.toInt();
      if (lvl == null || lvl > gateLevel) continue;
      if (bestLevel == null || lvl > bestLevel) {
        bestLevel = lvl;
        bestValue = entry.value;
      }
    }
    if (bestLevel == null) return (value: null, reason: null);

    if (bestValue is Map) {
      final row = <String, num>{};
      bestValue.forEach((k, v) {
        final n = _coerceNum(v);
        if (n != null) row['$k'] = n;
      });
      if (row.isEmpty) return (value: null, reason: null);
      return (value: row, reason: null);
    }

    final n = _coerceNum(bestValue);
    if (n != null) return (value: n, reason: null);
    return (
      value: null,
      reason: 'set_pouch_max level $bestLevel value is not numeric '
          '(${bestValue.runtimeType})',
    );
  }

  /// Add [contribution] (a `num` scalar or a `Map<String, num>` row) into
  /// [pouchMax] under [target], summing with any existing contribution
  /// (per-row for a matrix). Returns `null` on success, or a deferral reason
  /// when the shapes clash (a scalar contribution onto a matrix target, or vice
  /// versa).
  String? _accumulatePouchMax(
    Map<String, dynamic> pouchMax,
    String target,
    Object contribution,
  ) {
    final existing = pouchMax[target];
    if (existing == null) {
      pouchMax[target] = contribution is Map
          ? Map<String, num>.from(contribution)
          : contribution;
      return null;
    }
    if (existing is num && contribution is num) {
      pouchMax[target] = existing + contribution;
      return null;
    }
    if (existing is Map && contribution is Map) {
      final merged = Map<String, num>.from(existing);
      contribution.forEach((k, v) {
        if (v is num) merged['$k'] = (merged['$k'] ?? 0) + v;
      });
      pouchMax[target] = merged;
      return null;
    }
    return 'set_pouch_max shape clash on target "$target" '
        '(${existing is Map ? 'matrix' : 'scalar'} already set, '
        'got ${contribution is Map ? 'matrix' : 'scalar'})';
  }

  /// A `choose` rule's `pick` count (top-level or under `params`), clamped to ≥ 1
  /// (default 1).
  int _choosePick(Map<String, dynamic> rule) {
    dynamic raw = rule['pick'];
    if (raw is! num) {
      final params = rule['params'];
      if (params is Map) raw = params['pick'];
    }
    final n = raw is num ? raw.toInt() : 1;
    return n < 1 ? 1 : n;
  }

  /// Read a string param from a rule, top-level first then under `params`;
  /// returns `null` when absent/blank in both.
  String? _ruleParamString(Map<String, dynamic> rule, String key) {
    final top = (rule[key] as String?)?.trim();
    if (top != null && top.isNotEmpty) return top;
    final params = rule['params'];
    if (params is Map) {
      final p = (params[key] as String?)?.trim();
      if (p != null && p.isNotEmpty) return p;
    }
    return null;
  }

  /// Collect a list of strings for a collection rule (`grant_refs` /
  /// `grant_proficiency`): inline `rule[inlineKey]` (or `rule['params']
  /// [inlineKey]`), else the rule's own stored field value
  /// (`attachment.values[field.fieldKey]`). A bare scalar source is tolerated as
  /// a single-element list. Each entry is a bare string or a map carrying the id
  /// under one of [mapKeys]; blank/empty entries are skipped.
  List<String> _gatherStrings(
    Map<String, dynamic> rule,
    ResolverAttachment attachment,
    FieldSchema field, {
    required String inlineKey,
    required List<String> mapKeys,
  }) {
    dynamic source = rule[inlineKey];
    if (source is! List) {
      final params = rule['params'];
      if (params is Map && params[inlineKey] is List) {
        source = params[inlineKey];
      }
    }
    source ??= attachment.values[field.fieldKey];
    final list =
        source is List ? source : (source == null ? const [] : [source]);

    final out = <String>[];
    for (final entry in list) {
      final value = _stringFrom(entry, mapKeys);
      if (value != null && value.isNotEmpty) out.add(value);
    }
    return out;
  }

  static String? _stringFrom(dynamic entry, List<String> mapKeys) {
    if (entry is String) return entry.trim();
    if (entry is num) return entry.toString();
    if (entry is Map) {
      for (final k in mapKeys) {
        final v = entry[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
    }
    return null;
  }

  /// `grant_proficiency` tier: `expertise` or `proficient` (default), read from
  /// `rule['tier']` (or under `params`).
  String _proficiencyTier(Map<String, dynamic> rule) {
    String? raw = (rule['tier'] as String?)?.trim();
    if (raw == null || raw.isEmpty) {
      final params = rule['params'];
      if (params is Map) raw = (params['tier'] as String?)?.trim();
    }
    return raw?.toLowerCase() == 'expertise' ? 'expertise' : 'proficient';
  }

  /// Combine two proficiency tiers — `expertise` always wins over `proficient`.
  String _higherTier(String? existing, String incoming) =>
      (existing == 'expertise' || incoming == 'expertise')
          ? 'expertise'
          : 'proficient';

  /// True for the three triggers that fold a stat, with their gating applied.
  bool _triggerActive(
    String trigger,
    ResolverAttachment attachment,
    Map<String, dynamic> rule,
    int gateLevel,
  ) {
    switch (trigger) {
      case RuleTriggers.whenGranted:
        return true;
      case RuleTriggers.whenEquipped:
        return attachment.isEquipped;
      case RuleTriggers.levelUp:
        return gateLevel >= _ruleAtLevel(rule);
      default:
        return false;
    }
  }

  /// A note surfaces unless gated by equip state (`when_equipped`) or level
  /// (`level_up`); all other triggers (incl. the `prereq_*`/`on_button`
  /// imperatives) still show their text, since a note is purely informational.
  bool _noteActive(
    String trigger,
    ResolverAttachment attachment,
    Map<String, dynamic> rule,
    int gateLevel,
  ) {
    switch (trigger) {
      case RuleTriggers.whenEquipped:
        return attachment.isEquipped;
      case RuleTriggers.levelUp:
        return gateLevel >= _ruleAtLevel(rule);
      default:
        return true;
    }
  }

  /// Prereq clauses are checked whenever the entity is present, except the
  /// equip-scoped triggers (`when_equipped`/`prereq_to_equip`), which only
  /// matter once the item is actually equipped.
  bool _checkActive(String trigger, ResolverAttachment attachment) {
    switch (trigger) {
      case RuleTriggers.whenEquipped:
      case RuleTriggers.prereqToEquip:
        return attachment.isEquipped;
      default:
        return true;
    }
  }

  bool _isFoldingTrigger(String trigger) =>
      trigger == RuleTriggers.whenGranted ||
      trigger == RuleTriggers.whenEquipped ||
      trigger == RuleTriggers.levelUp;

  /// `level_up` gate level: `trigger_args.at_level` (default 1 ⇒ always on for
  /// a character that exists).
  int _ruleAtLevel(Map<String, dynamic> rule) {
    final args = rule['trigger_args'];
    if (args is Map) {
      final raw = args['at_level'];
      if (raw is num) return raw.toInt();
    }
    return 1;
  }

  /// Resolve a value source (the-template-system.md §4.2) to a number, or a
  /// `(value: null, reason: …)` so the caller can record precisely why it was
  /// deferred.
  ///
  /// Implemented sources:
  ///   * a bare number (`"value": 2`) — shorthand for `fixed`;
  ///   * `{"kind": "fixed", "value": N}` — a constant (slice 1);
  ///   * `{"kind": "field", "field": "<key>"}` — the stored value of one of the
  ///     attachment's fields, coerced to a number (slice 2). An absent/blank
  ///     `field` defaults to the rule's **own** field key, so a rule on an
  ///     ability-score-improvement field can add that field's own value.
  ///   * `{"kind": "formula", "expr": "..."}` — the §4.3 expression evaluated
  ///     over [aspects] via `formula_evaluator.dart` (slice 3). A blank `expr`
  ///     or a malformed formula returns a precise deferral reason, never a
  ///     silent stat change.
  ({num? value, String? reason}) _resolveValueSource(
    dynamic source,
    ResolverAttachment attachment,
    FieldSchema field,
    AspectContext aspects,
  ) {
    if (source is num) return (value: source, reason: null);
    if (source is! Map) {
      return (value: null, reason: 'value source is not a number or object');
    }

    final kind = (source['kind'] as String?)?.trim();

    if (kind == null || kind == 'fixed') {
      final v = source['value'];
      if (v is num) return (value: v, reason: null);
      return (value: null, reason: 'fixed value source missing numeric "value"');
    }

    if (kind == 'field') {
      final raw = (source['field'] as String?)?.trim();
      final lookupKey = (raw != null && raw.isNotEmpty) ? raw : field.fieldKey;
      final stored = attachment.values[lookupKey];
      final n = _coerceNum(stored);
      if (n != null) return (value: n, reason: null);
      return (
        value: null,
        reason: 'field value source "$lookupKey" is not numeric '
            '(${stored == null ? 'absent' : stored.runtimeType})',
      );
    }

    if (kind == 'formula') {
      final expr = (source['expr'] as String?)?.trim();
      if (expr == null || expr.isEmpty) {
        return (value: null, reason: 'formula value source missing "expr"');
      }
      try {
        final v = const FormulaEvaluator().evaluate(expr, aspects);
        return (value: v, reason: null);
      } on FormulaException catch (e) {
        return (value: null, reason: 'formula "$expr" failed: ${e.message}');
      }
    }

    return (value: null, reason: 'unknown value source kind "$kind"');
  }

  static num? _coerceNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  /// Build a [ResolverSkip] for a rule this slice could not (fully) interpret.
  ResolverSkip _skip(
    ResolverAttachment attachment,
    FieldSchema field,
    int ruleIndex,
    String kind,
    String reason,
  ) =>
      ResolverSkip(
        entityId: attachment.entityId,
        fieldKey: field.fieldKey,
        ruleIndex: ruleIndex,
        kind: kind.isEmpty ? '(missing)' : kind,
        reason: reason,
      );

  /// Replace `{field_key}` placeholders in a `note` template with the
  /// attachment's stored value for that key; an unknown key is left verbatim.
  static final RegExp _placeholder = RegExp(r'\{([A-Za-z0-9_]+)\}');

  String _interpolate(String text, ResolverAttachment attachment) {
    return text.replaceAllMapped(_placeholder, (m) {
      final key = m.group(1)!;
      final value = attachment.values[key];
      return value == null ? m.group(0)! : '$value';
    });
  }

  /// `check_clauses` policy: `block` or `warn` (default), read from the rule
  /// (`policy` at the top level or under `params`).
  String _clausePolicy(Map<String, dynamic> rule) {
    String? raw = (rule['policy'] as String?)?.trim();
    if (raw == null || raw.isEmpty) {
      final params = rule['params'];
      if (params is Map) raw = (params['policy'] as String?)?.trim();
    }
    return raw?.toLowerCase() == 'block' ? 'block' : 'warn';
  }

  /// Collect comparison clauses for a `check_clauses` rule: inline
  /// `rule['clauses']`, else `rule['params']['clauses']`, else the field's own
  /// stored rows (`attachment.values[field.fieldKey]` — the `prereq-clauses`
  /// recordList data). Returns only the map-shaped entries.
  List<Map<dynamic, dynamic>> _gatherClauses(
    Map<String, dynamic> rule,
    ResolverAttachment attachment,
    FieldSchema field,
  ) {
    dynamic source = rule['clauses'];
    if (source is! List) {
      final params = rule['params'];
      if (params is Map && params['clauses'] is List) {
        source = params['clauses'];
      }
    }
    source ??= attachment.values[field.fieldKey];
    if (source is! List) return const [];
    return source.whereType<Map>().toList();
  }

  /// Evaluate one `{aspect|field, op, value}` clause against [aspects].
  /// Returns `(passed: bool)` for a well-formed clause, or `(reason: …)` when
  /// the clause is malformed (missing aspect/value, or an unknown operator).
  ({bool? passed, String? reason}) _evalClause(
    Map<dynamic, dynamic> clause,
    AspectContext aspects,
  ) {
    final aspectName =
        (clause['aspect'] ?? clause['field'])?.toString().trim();
    if (aspectName == null || aspectName.isEmpty) {
      return (passed: null, reason: 'clause missing "aspect"');
    }

    final rhs = _coerceNum(clause['value']);
    if (rhs == null) {
      return (
        passed: null,
        reason: 'clause "$aspectName" missing numeric "value"',
      );
    }

    final op = (clause['op'] as String?)?.trim().isNotEmpty == true
        ? (clause['op'] as String).trim()
        : '>=';
    final lhs = aspects.value(aspectName);

    final bool? passed = switch (op) {
      '>=' => lhs >= rhs,
      '<=' => lhs <= rhs,
      '>' => lhs > rhs,
      '<' => lhs < rhs,
      '==' || '=' => lhs == rhs,
      '!=' => lhs != rhs,
      _ => null,
    };
    if (passed == null) {
      return (passed: null, reason: 'clause "$aspectName" has unknown op "$op"');
    }
    return (passed: passed, reason: null);
  }
}
