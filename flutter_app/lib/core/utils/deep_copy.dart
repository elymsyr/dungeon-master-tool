/// Recursively deep-copies a JSON-like value (Map / List / primitives)
/// without going through a JSON string round-trip.
///
/// This is significantly faster than `jsonDecode(jsonEncode(x))` because
/// it avoids UTF-8 encoding, string allocation, and re-parsing.
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
  return value;
}
