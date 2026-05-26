import '../../domain/entities/entity.dart';
import '../../domain/services/count_formula.dart';

/// Pure resolver for class resource pools (Rage uses, Bardic Inspiration,
/// Channel Divinity, Ki / Focus Points, Wild Shape, Lay on Hands, etc.).
/// Walks every feat in [entities] whose `auto_granted_by` points at the
/// active class or subclass, picks each `resource_pool_grant` effect,
/// and resolves a max value at [level] from either:
///
///   1. `scales_with.table` — uses the entry with the highest `lvl ≤ level`
///   2. `payload.count_formula` — evaluated via [evalCountFormula] when
///      `abilities` / `classLevels` are supplied (e.g. `paladin_level_x5`,
///      `monk_level`, `cha_mod_min_1`). Skipped when context is empty so
///      planner-only callers fall through to the literal `count`.
///   3. `payload.count` literal — final fallback.
///
/// Returns a map of `pool_ref.name` → max count. Empty when no class is
/// supplied or no feats apply at this level.
Map<String, int> resolveResourcePoolsAt({
  required Entity? classEntity,
  required Entity? subclassEntity,
  required int level,
  required Map<String, Entity> entities,
  Map<String, int> abilities = const {},
  Map<String, int> classLevels = const {},
}) {
  if (level < 1) return const {};
  final classNames = <String>{};
  if (classEntity != null) classNames.add(classEntity.name);
  if (subclassEntity != null) classNames.add(subclassEntity.name);
  if (classNames.isEmpty) return const {};
  if (entities.isEmpty) return const {};

  final out = <String, int>{};
  for (final e in entities.values) {
    if (e.categorySlug != 'feat') continue;
    if (!_isAutoGranted(e, classNames, level, entities)) continue;

    final effects = e.fields['effects'];
    if (effects is! List) continue;
    for (final eff in effects) {
      if (eff is! Map) continue;
      if (eff['kind'] != 'resource_pool_grant') continue;
      final payload = eff['payload'];
      if (payload is! Map) continue;
      final poolRef = payload['pool_ref'];
      if (poolRef is! Map) continue;
      final poolName = poolRef['name']?.toString();
      if (poolName == null || poolName.isEmpty) continue;

      final value = _resolveValue(
        eff,
        payload,
        level,
        abilities: abilities,
        classLevels: classLevels,
        entities: entities,
      );
      if (value == null) continue;
      // If multiple effects grant the same pool (e.g. base + subclass
      // upgrade), keep the larger value so the player isn't downgraded.
      final cur = out[poolName] ?? 0;
      if (value > cur) out[poolName] = value;
    }
  }
  return out;
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

int? _resolveValue(
  Map eff,
  Map payload,
  int level, {
  required Map<String, int> abilities,
  required Map<String, int> classLevels,
  required Map<String, Entity> entities,
}) {
  final scales = eff['scales_with'];
  if (scales is Map) {
    final table = scales['table'];
    if (table is List) {
      int? best;
      int? bestLvl;
      for (final row in table) {
        if (row is! Map) continue;
        final lvlRaw = row['lvl'];
        final vRaw = row['v'];
        final lvl = lvlRaw is int ? lvlRaw : int.tryParse('$lvlRaw');
        final v = vRaw is int ? vRaw : int.tryParse('$vRaw');
        if (lvl == null || v == null) continue;
        if (lvl > level) continue;
        if (bestLvl == null || lvl > bestLvl) {
          bestLvl = lvl;
          best = v;
        }
      }
      if (best != null) return best;
    }
  }
  if (abilities.isNotEmpty || classLevels.isNotEmpty) {
    final formulaMax = evalCountFormula(
      payload['count_formula']?.toString(),
      abilities: abilities,
      classLevels: classLevels,
      entitiesById: entities,
    );
    if (formulaMax != null) return formulaMax;
  }
  final countRaw = payload['count'];
  if (countRaw is int) return countRaw;
  if (countRaw is String) {
    final parsed = int.tryParse(countRaw);
    if (parsed != null) return parsed;
  }
  return null;
}
