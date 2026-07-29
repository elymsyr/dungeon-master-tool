import '../../domain/entities/entity.dart';
import '../../domain/services/entity_ref.dart';

/// The feats a Class / Subclass hands out at or below [level].
///
/// A class card's `features` list is the single declaration of what arrives
/// when: each row carries a `level` and the `granted_feat_refs` for it. This
/// walks those rows so the chargen previews (extra attack, weapon mastery,
/// resource pools) read the mechanic from exactly the same place
/// `CharacterResolver` Pass 4b does — before the inversion each of those three
/// callers carried its own byte-identical copy of an `auto_granted_by` scan,
/// and any drift between them silently showed the player a wrong preview.
///
/// [level] is the character's level in that class. Subclass rows are gated by
/// the same number: a subclass is only ever taken inside its parent class, so
/// its L6 row lands at class level 6.
List<Entity> autoGrantedFeatsAt({
  required Entity? classEntity,
  required Entity? subclassEntity,
  required int level,
  required Map<String, Entity> entities,
}) {
  if (level < 1 || entities.isEmpty) return const [];
  final out = <Entity>[];
  final seen = <String>{};

  for (final card in [classEntity, subclassEntity]) {
    final rows = card?.fields['features'];
    if (rows is! List) continue;
    for (final row in rows) {
      if (row is! Map) continue;
      final rowLevel = row['level'];
      final at = rowLevel is int ? rowLevel : int.tryParse('$rowLevel');
      // A row with no level is a narrative header, not a level gate; treat it
      // as level 1 so its grants are not silently dropped.
      if ((at ?? 1) > level) continue;
      final refs = row['granted_feat_refs'];
      if (refs is! List) continue;
      for (final r in refs) {
        final id = resolveEntityRef(r, entities);
        if (id == null || !seen.add(id)) continue;
        final feat = entities[id];
        if (feat != null && feat.categorySlug == 'feat') out.add(feat);
      }
    }
  }
  return out;
}
