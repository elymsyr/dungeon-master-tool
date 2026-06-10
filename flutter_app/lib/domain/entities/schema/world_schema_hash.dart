import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'world_schema.dart';

/// Computes a deterministic content hash of a [WorldSchema] over the fields
/// that affect gameplay/runtime behavior:
///   - categories (entity field definitions, groups)
///   - encounterConfig (combat config)
///   - encounterLayouts
///   - metadata
///
/// Volatile / cosmetic fields are intentionally excluded so that renaming
/// a template or bumping its version string does NOT invalidate every
/// dependent campaign:
///   - schemaId, name, description, version, baseSystem, formatVersion
///   - createdAt, updatedAt
///   - originalHash (would be a circular dependency: changing the field
///     that stores the hash would change the hash itself)
///
/// Template v3 adds two gameplay-affecting surfaces that ARE folded in:
/// the per-field `typeConfig`/`rules` (carried inside `categories`) and the
/// top-level `seedRows` (folded only when present — see the body).
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
  // Template v3 (PR-1.2): the per-field `typeConfig` + `rules` keys are
  // FieldSchema members, so they ride inside `categories` and fold into the
  // hash automatically once populated — no work needed here. `seedRows` is a
  // new top-level key; fold it in ONLY when present so pre-v3 schemas (which
  // omit it entirely via `includeIfNull: false`) hash byte-identically and
  // never trigger a spurious drift prompt on existing campaigns. The
  // structural marker `formatVersion` is intentionally excluded (same reason
  // `version` is — flipping it must not invalidate every dependent campaign).
  final seedRows = json['seedRows'];
  if (seedRows != null && !(seedRows is Map && seedRows.isEmpty)) {
    relevant['seedRows'] = seedRows;
  }
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
