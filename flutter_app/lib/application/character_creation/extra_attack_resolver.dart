import '../../domain/entities/entity.dart';

/// Pure resolver for the `extra_attack_count` /
/// `extra_attack_count_by_level` grant fields on auto-granted class/subclass
/// feats. Each feat declares the *total* attacks per Attack action (2 at L5,
/// 3 at L11 Fighter, 4 at L20 Fighter) either as a flat int or as a
/// `{lvl: count}` table; the runtime takes the **maximum** across all
/// matching grants — matching the precedence rule already implemented by
/// `CharacterResolver`.
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
    if (!_isAutoGranted(e, classNames, level, entities)) continue;

    final table = e.fields['extra_attack_count_by_level'];
    final scaled = _valueForLevel(table, level);
    final raw = e.fields['extra_attack_count'];
    final v = scaled ?? (raw is int ? raw : int.tryParse('$raw'));
    if (v == null) continue;
    if (v > best) best = v;
  }
  return best;
}

/// `{lvl: count}` table lookup — the value of the highest level ≤ [level].
int? _valueForLevel(Object? table, int level) {
  if (table is! Map) return null;
  int? best;
  var bestLvl = -1;
  for (final e in table.entries) {
    final lvl = e.key is int ? e.key as int : int.tryParse('${e.key}');
    final v = e.value is int ? e.value as int : int.tryParse('${e.value}');
    if (lvl == null || v == null) continue;
    if (lvl <= level && lvl > bestLvl) {
      bestLvl = lvl;
      best = v;
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
