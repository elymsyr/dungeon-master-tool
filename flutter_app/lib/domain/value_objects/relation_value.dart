/// Pure parser for `relation`-type field values stored in `entity.fields`.
///
/// A relation value can be:
///   * a `String` UUID (single resolved relation),
///   * a `Map` `{id, equipped?}` (equipment-style list item),
///   * a `List` of any of the above (relation-list field).
///
/// Legacy `{_lookup}` / `{_ref}` placeholder maps carry no resolvable UUID
/// without the world entity map, so they yield no id here — they are stale
/// import-time leftovers and safe to drop on plain-text / share surfaces.
library;

/// Extracts every entity-UUID referenced by a relation field [value].
List<String> extractRelationIds(dynamic value) {
  if (value == null) return const [];
  if (value is String) return value.isEmpty ? const [] : [value];
  if (value is Map) {
    final id = _idFromMap(value);
    return id == null ? const [] : [id];
  }
  if (value is List) {
    final out = <String>[];
    for (final e in value) {
      out.addAll(extractRelationIds(e));
    }
    return out;
  }
  return const [];
}

/// Extracts the first entity-UUID from a single-relation field [value].
String? extractRelationId(dynamic value) {
  final ids = extractRelationIds(value);
  return ids.isEmpty ? null : ids.first;
}

String? _idFromMap(Map<dynamic, dynamic> m) {
  final id = m['id'];
  return (id is String && id.isNotEmpty) ? id : null;
}
