/// Recursively deep-copies a JSON-like value (Map / List / primitives)
/// without going through a JSON string round-trip.
///
/// This is significantly faster than `jsonDecode(jsonEncode(x))` because
/// it avoids UTF-8 encoding, string allocation, and re-parsing.
///
/// Also handles Freezed / json_serializable objects that have a `toJson()`
/// method — they are serialized to a plain Map first, then deep-copied.
dynamic deepCopyJson(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key as String: deepCopyJson(e.value),
    };
  }
  if (value is List) {
    return [for (final e in value) deepCopyJson(e)];
  }
  // Primitives (String, int, double, bool, null) are immutable — return as-is.
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  // Freezed / json_serializable objects — serialize to plain map first.
  try {
    // ignore: avoid_dynamic_calls
    final json = (value as dynamic).toJson();
    return deepCopyJson(json);
  } catch (_) {
    return value;
  }
}

/// [deepCopyJson] for plain JSON trees, replacing every string value and map
/// key found in [ids] with its mapped value. Used to give a copied item fresh
/// ids while keeping its internal references pointing at the copy.
///
/// Mentions embedded in text (`@[Name](entity:<id>)`) are rewritten too —
/// the id there is part of a longer string, not a value of its own.
dynamic remapIdsJson(dynamic value, Map<String, String> ids) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries)
        ids[e.key] ?? e.key as String: remapIdsJson(e.value, ids),
    };
  }
  if (value is List) {
    return [for (final e in value) remapIdsJson(e, ids)];
  }
  if (value is String) {
    final mapped = ids[value];
    if (mapped != null) return mapped;
    if (!value.contains('](entity:')) return value;
    return value.replaceAllMapped(_mentionTarget, (m) {
      final to = ids[m[1]];
      return to == null ? m[0]! : '](entity:$to)';
    });
  }
  return value;
}

final RegExp _mentionTarget = RegExp(r'\]\(entity:([^)\s]+)\)');
