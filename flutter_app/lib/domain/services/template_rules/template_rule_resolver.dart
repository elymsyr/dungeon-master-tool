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
///
/// Every other kind (`choose`, `set_pouch_max`, `refill_pouch`/`empty_pouch`,
/// `grant_pouch`) is recorded in [TemplateResolution.deferred] rather than
/// silently dropped, so the harness shows exactly what remains for later slices.
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
/// [grantRefs] and [grantProficiency] are interpreted; the rest are still
/// recorded as deferred.
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

  /// Rules not interpreted by this slice (kind or value-source not yet built).
  final List<ResolverSkip> deferred;

  const TemplateResolution({
    required this.statDeltas,
    required this.notes,
    required this.warnings,
    required this.grants,
    required this.proficiencyGrants,
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

  bool get isEmpty =>
      statDeltas.isEmpty &&
      notes.isEmpty &&
      warnings.isEmpty &&
      grants.isEmpty &&
      proficiencyGrants.isEmpty;
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
    required List<String> notes,
    required List<String> warnings,
    required Map<String, List<String>> grants,
    required Map<String, Map<String, String>> proficiencyGrants,
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
