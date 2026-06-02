/// Builds the compact, read-only content summary stored on a marketplace
/// listing at publish time (`marketplace_listings.content_summary`).
///
/// Both world and package payloads share the same shape:
///   `payload['entities']`     = `Map<id, {name, type:=categorySlug, ...}>`
///   `payload['world_schema']` = `{name, categories:[{slug, name, ...}], ...}`
/// so a single builder covers both item types.
///
/// Returned shape (or null when there is nothing to summarise — e.g. a
/// character payload that carries no `entities`/`world_schema`):
/// ```
/// {
///   "template": <world_schema.name | null>,
///   "categories": [
///     {"slug": "...", "name": "<schema name | slug>", "count": N,
///      "names": [...up to _maxNames...], "overflow": <extra beyond cap>}
///   ]
/// }
/// ```
library;

/// Max entity names retained per category — bounds the worst case (huge packs)
/// while keeping the closed list useful. Surplus is reported via `overflow`.
const int _maxNames = 500;

Map<String, dynamic>? buildListingContentSummary(Map<String, dynamic> payload) {
  final entitiesRaw = payload['entities'];
  if (entitiesRaw is! Map) return null;

  final schema = payload['world_schema'];
  final templateName =
      (schema is Map && schema['name'] is String) ? schema['name'] as String : null;

  // slug -> display name + original order, from the schema categories.
  final displayName = <String, String>{};
  final order = <String, int>{};
  if (schema is Map && schema['categories'] is List) {
    var i = 0;
    for (final c in schema['categories'] as List) {
      if (c is Map && c['slug'] is String) {
        final slug = c['slug'] as String;
        if (c['name'] is String && (c['name'] as String).isNotEmpty) {
          displayName[slug] = c['name'] as String;
        }
        order[slug] = i;
      }
      i++;
    }
  }

  // Group entity names by their categorySlug (stored as `type`).
  final names = <String, List<String>>{};
  final counts = <String, int>{};
  for (final e in entitiesRaw.values) {
    if (e is! Map) continue;
    final slug = (e['type'] as String?)?.isNotEmpty == true
        ? e['type'] as String
        : 'uncategorized';
    final name = (e['name'] as String?)?.trim();
    counts[slug] = (counts[slug] ?? 0) + 1;
    final bucket = names.putIfAbsent(slug, () => <String>[]);
    if (name != null && name.isNotEmpty && bucket.length < _maxNames) {
      bucket.add(name);
    }
  }

  if (counts.isEmpty) {
    return {'template': templateName, 'categories': const <dynamic>[]};
  }

  // Stable ordering: schema category order first, then any extra slugs
  // alphabetically.
  final slugs = counts.keys.toList()
    ..sort((a, b) {
      final oa = order[a];
      final ob = order[b];
      if (oa != null && ob != null) return oa.compareTo(ob);
      if (oa != null) return -1;
      if (ob != null) return 1;
      return a.compareTo(b);
    });

  final categories = <Map<String, dynamic>>[];
  for (final slug in slugs) {
    final count = counts[slug] ?? 0;
    final kept = names[slug] ?? const <String>[];
    categories.add({
      'slug': slug,
      'name': displayName[slug] ?? slug,
      'count': count,
      'names': kept,
      'overflow': count - kept.length,
    });
  }

  return {'template': templateName, 'categories': categories};
}
