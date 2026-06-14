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
/// **Implemented so far:** the `modify_stat` rule kind with all three value
/// sources — a constant (`fixed`, slice 1), a stored field read (`field`, slice
/// 2, reading `attachment.values[...]`), and a `formula` (slice 3) evaluated
/// over the PC card's [AspectContext] via `formula_evaluator.dart` (§4.3
/// grammar: aspect identifiers, arithmetic, `floor/ceil/min/max`, `table(...)`).
/// Every other kind (`grant_refs`, `grant_proficiency`, `choose`,
/// `set_pouch_max`, `refill_pouch`/`empty_pouch`, `grant_pouch`,
/// `check_clauses`, `note`) is recorded in [TemplateResolution.deferred] rather
/// than silently dropped, so the harness shows exactly what remains for later
/// slices.
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
/// (the-template-system.md §4.2). Only [modifyStat] is interpreted this slice.
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

/// The resolver's output overlay — an `EffectiveCharacter`-equivalent in the
/// making (the-template-system.md §4.4 step 5). This slice fills [statDeltas];
/// [notes]/[warnings] are populated by later kinds (`note`, `check_clauses`).
class TemplateResolution {
  /// Summed additive deltas per aspect path (e.g. `{'ac': 2, 'speed': 10}`).
  final Map<String, num> statDeltas;

  /// Player-facing rule text from `note` rules (later slice).
  final List<String> notes;

  /// Prerequisite/validation warnings from `check_clauses` (later slice).
  final List<String> warnings;

  /// Rules not interpreted by this slice (kind or value-source not yet built).
  final List<ResolverSkip> deferred;

  const TemplateResolution({
    required this.statDeltas,
    required this.notes,
    required this.warnings,
    required this.deferred,
  });

  /// The net delta accumulated for [aspect] (0 when untouched).
  num delta(String aspect) => statDeltas[aspect] ?? 0;

  bool get isEmpty =>
      statDeltas.isEmpty && notes.isEmpty && warnings.isEmpty;
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
            deferred: deferred,
          );
        }
      }
    }

    return TemplateResolution(
      statDeltas: statDeltas,
      notes: notes,
      warnings: warnings,
      deferred: deferred,
    );
  }

  void _foldRule({
    required ResolverAttachment attachment,
    required FieldSchema field,
    required Map<String, dynamic> rule,
    required int ruleIndex,
    required int gateLevel,
    required AspectContext aspects,
    required Map<String, num> statDeltas,
    required List<ResolverSkip> deferred,
  }) {
    final kind = (rule['kind'] as String?)?.trim() ?? '';
    final trigger = (rule['trigger'] as String?)?.trim().isNotEmpty == true
        ? (rule['trigger'] as String).trim()
        : RuleTriggers.fallback;

    ResolverSkip skip(String reason) => ResolverSkip(
          entityId: attachment.entityId,
          fieldKey: field.fieldKey,
          ruleIndex: ruleIndex,
          kind: kind.isEmpty ? '(missing)' : kind,
          reason: reason,
        );

    // Only `modify_stat` is interpreted this slice; everything else is owed.
    if (kind != RuleKinds.modifyStat) {
      deferred.add(skip('kind not implemented in this slice'));
      return;
    }

    // Trigger gate: only the folding triggers contribute a stat delta.
    if (!_triggerActive(trigger, attachment, rule, gateLevel)) {
      // Inactive folding trigger ⇒ correctly contributes nothing (not a skip).
      // Non-folding triggers (prereq_*, on_button) are recorded as deferred so
      // a modify_stat authored under them is visibly unhandled here.
      if (!_isFoldingTrigger(trigger)) {
        deferred.add(skip('trigger "$trigger" is not a stat-fold trigger'));
      }
      return;
    }

    final target = (rule['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      deferred.add(skip('modify_stat missing "target" aspect path'));
      return;
    }

    final resolved = _resolveValueSource(rule['value'], attachment, field, aspects);
    if (resolved.value == null) {
      deferred.add(skip(resolved.reason ?? 'value source could not be resolved'));
      return;
    }

    statDeltas[target] = (statDeltas[target] ?? 0) + resolved.value!;
  }

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
}
