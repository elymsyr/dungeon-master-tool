import '../../domain/entities/entity.dart';

/// Pure resolver for the `extra_attack_count` effect granted by auto-granted
/// class/subclass feats. Mirrors [resolveResourcePoolsAt] but for the flat
/// `value` shape used by Extra Attack: each feat declares a single integer
/// (2 at L5, 3 at L11 Fighter, 4 at L20 Fighter) and the runtime takes the
/// **maximum** across all matching grants — matching the precedence rule
/// already implemented by `CharacterResolver`.
///
/// Returns 0 when no class is supplied, [level] is below 1, or no matching
/// feat is found at or below [level].
int resolveExtraAttackCountAt({
  required Entity? classEntity,
  required Entity? subclassEntity,
  required int level,
  required Map<String, Entity> entities,
}) {
  if (level < 1) return 0;
  final classNames = <String>{};
  if (classEntity != null) classNames.add(classEntity.name);
  if (subclassEntity != null) classNames.add(subclassEntity.name);
  if (classNames.isEmpty) return 0;
  if (entities.isEmpty) return 0;

  var best = 0;
  for (final e in entities.values) {
    if (e.categorySlug != 'feat') continue;
    if (!_isAutoGranted(e, classNames, level)) continue;

    final effects = e.fields['effects'];
    if (effects is! List) continue;
    for (final eff in effects) {
      if (eff is! Map) continue;
      final kind = eff['kind'];
      if (kind != 'extra_attack_count' && kind != 'extra_attack_bump') continue;
      final raw = eff['value'];
      final v = raw is int ? raw : int.tryParse('$raw');
      if (v == null) continue;
      if (v > best) best = v;
    }
  }
  return best;
}

bool _isAutoGranted(Entity feat, Set<String> sources, int level) {
  final auto = feat.fields['auto_granted_by'];
  if (auto is! List) return false;
  for (final row in auto) {
    if (row is! Map) continue;
    final sourceRef = row['source_ref'];
    String? srcName;
    if (sourceRef is Map) srcName = sourceRef['name']?.toString();
    final atLvlRaw = row['at_level'];
    final atLvl = atLvlRaw is int ? atLvlRaw : int.tryParse('$atLvlRaw');
    if (srcName == null || atLvl == null) continue;
    if (!sources.contains(srcName)) continue;
    if (atLvl > level) continue;
    return true;
  }
  return false;
}
