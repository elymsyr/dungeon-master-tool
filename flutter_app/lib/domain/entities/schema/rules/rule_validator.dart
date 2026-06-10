import 'rule_definition.dart';

/// One non-blocking authoring issue on an effect row. Surfaced as a warning in
/// the editor; never blocks save or mutates data.
class RuleIssue {
  final String message;
  const RuleIssue(this.message);
}

/// Validate a single feat-effect row against the [catalog].
/// [hostFields] (when supplied) enables the `$field` dynamic-value check —
/// a `value: {"$field": key}` whose key is absent on the host card is
/// flagged (the resolver SKIPS such rows at compile time).
///
/// Deliberately high-confidence only — it flags shapes that are almost
/// certainly authoring mistakes (no/unknown kind, a target-kind the rule does
/// not accept, an unknown predicate, a missing required param). It does NOT
/// flag capability mismatches (e.g. predicates on a rule whose catalog entry
/// has `supportsPredicates: false`), because those flags are conservative
/// declarations rather than hard constraints — the resolver still honors the
/// data, so warning would be noise on valid SRD content.
List<RuleIssue> validateEffectRow(
    Map<String, dynamic> row, RuleCatalog catalog,
    {Map<String, dynamic>? hostFields}) {
  final issues = <RuleIssue>[];

  final kind = row['kind'];
  if (kind is! String || kind.isEmpty) {
    return [const RuleIssue('No rule selected')];
  }
  final rule = catalog[kind];
  if (rule == null) {
    return [RuleIssue('Unknown rule "$kind"')];
  }

  // Target kind must be one the rule accepts (only when it declares a list).
  final tk = row['target_kind'];
  if (rule.allowedTargetKinds.isNotEmpty &&
      tk is String &&
      tk.isNotEmpty &&
      !rule.allowedTargetKinds.contains(tk)) {
    issues.add(RuleIssue('Target kind "$tk" is not valid for ${rule.label}'));
  }

  // Required params present.
  for (final p in rule.params) {
    if (!p.required) continue;
    if (!_paramPresent(p, row)) {
      issues.add(RuleIssue('Missing required "${p.label}"'));
    }
  }

  // Predicate rows must carry a known predicate kind.
  final preds = row['predicates'];
  if (preds is List) {
    for (final raw in preds) {
      if (raw is! Map) continue;
      final pk = raw['kind'];
      if (pk is! String || pk.isEmpty) {
        issues.add(const RuleIssue('A predicate has no kind'));
      } else if (catalog.predicateKinds.isNotEmpty &&
          !catalog.predicateKinds.contains(pk)) {
        issues.add(RuleIssue('Unknown predicate "$pk"'));
      }
    }
  }

  // Trigger key (PR-R2 wire addition) — must be a known wire string, and one
  // the rule declares when it constrains the list. `trigger_args.at_level`
  // must be an int when present. `clauses` belong to prereq rules only.
  const triggerWires = {
    'always_on', 'when_granted', 'when_level_up', 'when_equipped',
    'when_attuned', 'prereq_to_grant', 'prereq_to_equip', 'prereq_to_attune', //
  };
  const prereqWires = {
    'prereq_to_grant',
    'prereq_to_equip',
    'prereq_to_attune',
  };
  final trigger = row['trigger'];
  if (trigger != null) {
    if (trigger is! String || !triggerWires.contains(trigger)) {
      issues.add(RuleIssue('Unknown trigger "$trigger"'));
    } else if (rule.allowedTriggers.isNotEmpty &&
        !rule.allowedTriggers.contains(trigger)) {
      issues.add(RuleIssue('Trigger "$trigger" is not valid for ${rule.label}'));
    } else if (prereqWires.contains(trigger) && kind != 'prerequisite') {
      issues.add(const RuleIssue(
          'Prereq triggers belong on a "Prerequisite" rule'));
    }
  }
  final triggerArgs = row['trigger_args'];
  if (triggerArgs is Map &&
      triggerArgs['at_level'] != null &&
      triggerArgs['at_level'] is! int) {
    issues.add(const RuleIssue('trigger_args.at_level must be a number'));
  }
  if (row['clauses'] is List &&
      (row['clauses'] as List).isNotEmpty &&
      kind != 'prerequisite') {
    issues.add(const RuleIssue('Clauses belong on a "Prerequisite" rule'));
  }

  // `$field` dynamic value refs must name a field present on the host card.
  void checkFieldRef(Object? v, String where) {
    if (v is! Map || !v.containsKey(r'$field')) return;
    final key = v[r'$field'];
    if (key is! String || key.isEmpty) {
      issues.add(RuleIssue('$where has an empty \$field reference'));
    } else if (hostFields != null && !hostFields.containsKey(key)) {
      issues.add(RuleIssue('$where references missing field "$key"'));
    }
  }

  checkFieldRef(row['value'], 'Value');
  final payloadMap = row['payload'];
  if (payloadMap is Map) {
    payloadMap.forEach((k, v) => checkFieldRef(v, 'Payload "$k"'));
  }

  return issues;
}

bool _paramPresent(RuleParamSpec p, Map<String, dynamic> row) {
  switch (p.location) {
    case RuleParamLocation.topLevel:
      return row[p.key] != null;
    case RuleParamLocation.payload:
      final payload = row['payload'];
      return payload is Map && payload[p.key] != null;
    case RuleParamLocation.targetRef:
      return row['target_ref'] != null;
  }
}
