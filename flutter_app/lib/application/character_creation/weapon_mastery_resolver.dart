import '../../domain/entities/entity.dart';

/// Resolver for the `weapon_mastery_count_bonus` effect on auto-granted
/// class feats. Mirrors `resolveExtraAttackCountAt`: each feat declares an
/// integer cap and the runtime takes the **maximum** across grants at or
/// below [level]. SRD §1.7 spec varies by class (Fighter 3 at L1, others 2)
/// and bumps via separate feats (Fighter L4/L10/L16) — taking max matches
/// the precedence already used by `CharacterResolver` for stacking caps.
int resolveWeaponMasteryCountAt({
  required Entity? classEntity,
  required Entity? subclassEntity,
  required int level,
  required Map<String, Entity> entities,
}) {
  if (level < 1) return 0;
  final classNames = <String>{};
  if (classEntity != null) classNames.add(classEntity.name);
  if (subclassEntity != null) classNames.add(subclassEntity.name);
  if (classNames.isEmpty || entities.isEmpty) return 0;

  var best = 0;
  for (final e in entities.values) {
    if (e.categorySlug != 'feat') continue;
    if (!_isAutoGranted(e, classNames, level, entities)) continue;

    final effects = e.fields['effects'];
    if (effects is! List) continue;
    for (final eff in effects) {
      if (eff is! Map) continue;
      if (eff['kind'] != 'weapon_mastery_count_bonus') continue;
      final raw = eff['value'];
      final v = raw is int ? raw : int.tryParse('$raw');
      if (v == null) continue;
      if (v > best) best = v;
    }
  }
  return best;
}

bool _isAutoGranted(Entity feat, Set<String> sources, int level,
    Map<String, Entity> entities) {
  final auto = feat.fields['auto_granted_by'];
  if (auto is! List) return false;
  for (final row in auto) {
    if (row is! Map) continue;
    final sourceRef = row['source_ref'];
    String? srcName;
    if (sourceRef is Map) {
      srcName = sourceRef['name']?.toString();
    } else if (sourceRef is String) {
      srcName = entities[sourceRef]?.name;
    }
    final atLvlRaw = row['at_level'];
    final atLvl = atLvlRaw is int ? atLvlRaw : int.tryParse('$atLvlRaw');
    if (srcName == null || atLvl == null) continue;
    if (!sources.contains(srcName)) continue;
    if (atLvl > level) continue;
    return true;
  }
  return false;
}
