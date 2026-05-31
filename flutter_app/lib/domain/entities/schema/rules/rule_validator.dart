import 'rule_definition.dart';

/// One non-blocking authoring issue on an effect row. Surfaced as a warning in
/// the editor; never blocks save or mutates data.
class RuleIssue {
  final String message;
  const RuleIssue(this.message);
}

/// Validate a single feat-effect row against the [catalog].
///
/// Deliberately high-confidence only — it flags shapes that are almost
/// certainly authoring mistakes (no/unknown kind, a target-kind the rule does
/// not accept, an unknown predicate, a missing required param). It does NOT
/// flag capability mismatches (e.g. predicates on a rule whose catalog entry
/// has `supportsPredicates: false`), because those flags are conservative
/// declarations rather than hard constraints — the resolver still honors the
/// data, so warning would be noise on valid SRD content.
List<RuleIssue> validateEffectRow(
    Map<String, dynamic> row, RuleCatalog catalog) {
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
