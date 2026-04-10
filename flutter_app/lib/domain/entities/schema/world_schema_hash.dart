import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'world_schema.dart';

/// Computes a deterministic content hash of a [WorldSchema] over the fields
/// that affect gameplay/runtime behavior:
///   - categories (entity field definitions, rules, groups)
///   - encounterConfig (combat config)
///   - encounterLayouts
///   - metadata
///
/// Volatile / cosmetic fields are intentionally excluded so that renaming
/// a template or bumping its version string does NOT invalidate every
/// dependent campaign:
///   - schemaId, name, description, version, baseSystem
///   - createdAt, updatedAt
///   - originalHash (would be a circular dependency: changing the field
///     that stores the hash would change the hash itself)
///
/// This is the "current" hash — recomputed on every read. The companion
/// concept is `WorldSchema.originalHash`, which is the value of THIS
/// function at the moment the template was first created and is then
/// frozen on the schema forever.
///
/// Used by the lazy template-sync flow: each campaign stores both the
/// originalHash of the template it derives from AND the currentHash at
/// last sync; on campaign open we look up the template by originalHash,
/// recompute its currentHash, and prompt the user when they diverge.
String computeWorldSchemaContentHash(WorldSchema schema) {
  final json = schema.toJson();
  final relevant = <String, dynamic>{
    'categories': json['categories'],
    'encounterConfig': json['encounterConfig'],
    'encounterLayouts': json['encounterLayouts'],
    'metadata': json['metadata'],
  };
  final canonical = jsonEncode(_canonicalize(relevant));
  final digest = sha256.convert(utf8.encode(canonical));
  return digest.toString();
}

/// Recursively canonicalizes a JSON-like value so that semantically equal
/// structures encode to byte-identical strings:
///   - Map keys are sorted alphabetically
///   - Lists keep their order (order is meaningful for categories/fields)
///   - Primitives pass through unchanged
Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {
      for (final k in sortedKeys) k: _canonicalize(value[k]),
    };
  }
  if (value is List) {
    return [for (final e in value) _canonicalize(e)];
  }
  return value;
}
