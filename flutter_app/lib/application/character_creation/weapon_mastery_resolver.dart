import '../../domain/entities/entity.dart';
import 'auto_granted_feats.dart';

/// Resolver for the `weapon_mastery_count` grant field on auto-granted
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
  var best = 0;
  for (final feat in autoGrantedFeatsAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: level,
    entities: entities,
  )) {
    final raw = feat.fields['weapon_mastery_count'];
    final v = raw is int ? raw : int.tryParse('$raw');
    if (v != null && v > best) best = v;
  }
  return best;
}
