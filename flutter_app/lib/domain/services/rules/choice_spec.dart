/// Constrained-choice descriptor (rules engine PR-R5; roadmap 1.4).
///
/// First-class "pick N of set, with per-option amounts" data so constraints
/// like "+2/+1 or +1/+1/+1" and "choose 2 skills from ..." round-trip as
/// data instead of degrading to the full option set. One model unifies:
///   - background ASI distributions (`asi_distribution_options` +
///     `ability_score_options`),
///   - class/subclass skill & tool picks (`skill_proficiency_choice_count` +
///     `_options`, `tool_proficiency_count` + `_options`),
///   - background bonus languages (`granted_language_count`),
///   - feat-internal `choice_group` effect rows (legacy wire kept as an
///     alias of the `choice_spec` kind).
///
/// Consumers: pending-choice seeding (which picker badges to queue), wizard
/// distribution UI, and the resolver's stored-pick validation (WARN-KEEP —
/// violations surface as warnings, mechanics still apply).
library;

class ChoiceSpec {
  /// Stable id within the source entity (`choice_group` `group_id`, or a
  /// field-derived tag like `background_asi`).
  final String specId;

  final String label;

  /// What is being picked: 'skill' | 'tool' | 'language' | 'ability' |
  /// 'ability_distribution' | 'enum' | ... Maps onto `PendingChoiceKind`s.
  final String pickKind;

  /// Number of picks (non-distribution kinds).
  final int pick;

  /// Allowed options — refs ({_lookup/_ref,name} maps or id strings) or
  /// plain strings for enum picks. Empty = unconstrained.
  final List<Object> options;

  /// For `ability_distribution`: the allowed bump distributions, descending
  /// (`[[2,1],[1,1,1]]`). Empty for other kinds.
  final List<List<int>> distributions;

  const ChoiceSpec({
    required this.specId,
    required this.label,
    required this.pickKind,
    this.pick = 1,
    this.options = const [],
    this.distributions = const [],
  });

  /// Parse `asi_distribution_options` wire values (`'+2/+1'`, `'+1/+1/+1'`)
  /// into sorted-descending int distributions. Unparseable entries skipped.
  static List<List<int>> parseDistributions(Object? raw) {
    if (raw is! List) return const [];
    final out = <List<int>>[];
    for (final v in raw) {
      if (v is! String) continue;
      final parts = v
          .split('/')
          .map((s) => int.tryParse(s.replaceAll('+', '').trim()))
          .toList();
      if (parts.isEmpty || parts.any((p) => p == null || p <= 0)) continue;
      out.add((parts.cast<int>())..sort((a, b) => b.compareTo(a)));
    }
    return out;
  }

  /// Whether a stored bump map (`{STR: 2, CON: 1}`) matches one of the
  /// allowed distributions (order-insensitive). True when no distributions
  /// are declared (unconstrained — official packs ship none).
  bool matchesDistribution(Map<String, int> picks) {
    if (distributions.isEmpty) return true;
    final got = picks.values.where((v) => v > 0).toList()
      ..sort((a, b) => b.compareTo(a));
    for (final d in distributions) {
      if (d.length != got.length) continue;
      var ok = true;
      for (var i = 0; i < d.length; i++) {
        if (d[i] != got[i]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// Parse a `choice_spec` / legacy `choice_group` effect row. Returns null
  /// for other kinds or rows without a payload/group id.
  static ChoiceSpec? fromEffectRow(Map<dynamic, dynamic> row) {
    final kind = row['kind'];
    if (kind != 'choice_spec' && kind != 'choice_group') return null;
    final payload = row['payload'];
    if (payload is! Map) return null;
    final groupId = payload['group_id']?.toString() ?? '';
    if (groupId.isEmpty) return null;
    return ChoiceSpec(
      specId: groupId,
      label: payload['label']?.toString() ?? groupId,
      pickKind: payload['pick_kind']?.toString() ?? 'enum',
      pick: payload['pick'] is int
          ? payload['pick'] as int
          : (payload['pick'] is num ? (payload['pick'] as num).toInt() : 1),
      options: payload['options'] is List
          ? List<Object>.from(payload['options'] as List)
          : const [],
      distributions: parseDistributions(payload['distributions']),
    );
  }
}
