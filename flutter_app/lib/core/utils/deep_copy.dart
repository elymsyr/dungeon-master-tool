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
