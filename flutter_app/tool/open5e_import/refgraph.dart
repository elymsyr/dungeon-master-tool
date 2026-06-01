// Per-package entity id minting + inter-entity `_ref` resolution.
//
// Cloned from `buildSrdCorePack` (srd_core_pack.dart): Pass 1 mints a
// deterministic UUIDv5 from `<namespace>` + `"slug:name"` so ids stay stable
// across rebuilds (installed-campaign `package_entity_id` foreign keys keep
// resolving). Pass 2 rewrites every `{_ref, name}` placeholder to the matching
// UUID. `{_lookup, name}` placeholders are left intact — the app resolves those
// at install time against the world's Tier-0 rows.
//
// Each package gets its OWN namespace UUID so ids never collide across
// packages and a package can be rebuilt byte-stable.
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PackBuilder {
  /// Per-package namespace (a UUIDv5 derived from the document slug).
  final String namespace;

  /// id -> wire-format package entity (`packEntity` output).
  final Map<String, dynamic> entities = {};

  /// slug -> (name -> id), for `_ref` resolution.
  final Map<String, Map<String, String>> _refIndex = {};

  PackBuilder(String packageName)
      : namespace = _uuid.v5(Namespace.url.value, 'open5e-pack:$packageName');

  String stableId(String slug, String name) =>
      _uuid.v5(namespace, '$slug:$name');

  /// Add an entity (its `name`/`type` already set by `packEntity`). Returns the
  /// minted id. Re-adding the same (slug, name) is idempotent.
  String add(Map<String, dynamic> row) {
    final slug = row['type'] as String;
    final name = row['name'] as String;
    final id = stableId(slug, name);
    entities[id] = row;
    (_refIndex[slug] ??= <String, String>{})[name] = id;
    return id;
  }

  /// True if a (slug, name) is already registered.
  bool has(String slug, String name) => _refIndex[slug]?.containsKey(name) ?? false;

  /// Pass 2: rewrite `_ref` placeholders to ids. Returns the list of
  /// `slug:name` refs that could not be resolved (empty = healthy pack).
  List<String> resolveRefs() {
    final unresolved = <String>[];
    for (final id in entities.keys.toList()) {
      final row = entities[id] as Map<String, dynamic>;
      final attrs = row['attributes'];
      if (attrs is Map) {
        row['attributes'] = _resolve(
            Map<String, dynamic>.from(attrs), unresolved);
      }
    }
    return unresolved;
  }

  dynamic _resolve(dynamic value, List<String> unresolved) {
    if (value is Map) {
      final ref = value['_ref'];
      final name = value['name'];
      if (ref is String && name is String) {
        final id = _refIndex[ref]?[name];
        if (id == null) {
          unresolved.add('$ref:$name');
          return '';
        }
        return id;
      }
      return value.map((k, v) => MapEntry(k, _resolve(v, unresolved)));
    }
    if (value is List) {
      return value.map((e) => _resolve(e, unresolved)).toList();
    }
    return value;
  }
}
