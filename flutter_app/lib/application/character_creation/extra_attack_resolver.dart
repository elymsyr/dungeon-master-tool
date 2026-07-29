import '../../domain/entities/entity.dart';
import 'auto_granted_feats.dart';

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
  var best = 0;
  for (final feat in autoGrantedFeatsAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: level,
    entities: entities,
  )) {
    final scaled =
        _valueForLevel(feat.fields['extra_attack_count_by_level'], level);
    final raw = feat.fields['extra_attack_count'];
    final v = scaled ?? (raw is int ? raw : int.tryParse('$raw'));
    if (v != null && v > best) best = v;
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

