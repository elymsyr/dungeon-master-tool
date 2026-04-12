import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic SHA256 of an arbitrary JSON-encodable payload (the gzip'd
/// blob a marketplace listing carries). Equal inputs always produce equal
/// digests, regardless of map key insertion order, so re-publishing
/// unchanged content is detectable client-side and the publish RPC can be
/// short-circuited.
String computePayloadContentHash(Map<String, dynamic> payload) {
  final canonical = jsonEncode(canonicalizeJsonValue(payload));
  return sha256.convert(utf8.encode(canonical)).toString();
}

/// Recursively rewrites a JSON-like value so that semantically equal
/// structures encode to byte-identical strings:
///   - Map keys sorted alphabetically
///   - List order preserved (often meaningful — e.g. category ordering)
///   - Primitives untouched
Object? canonicalizeJsonValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: canonicalizeJsonValue(value[k])};
  }
  if (value is List) {
    return [for (final e in value) canonicalizeJsonValue(e)];
  }
  return value;
}
