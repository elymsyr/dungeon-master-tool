import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../domain/entities/entity.dart';
import 'builtin_srd_entities.dart';
import 'package_import_service.dart';

/// Tier-0 categories whose rows the built-in SRD map mints with stable
/// UUIDs. Package entities reference these via `_lookup` placeholders, so we
/// resolve against the builtin ids to keep refs pointing at the same rows the
/// rest of the wizard/editor already use.
Map<String, Map<String, String>> _tier0IndexFromBuiltin(
    Map<String, Entity> builtin) {
  final index = <String, Map<String, String>>{};
  for (final e in builtin.values) {
    final slug = e.categorySlug;
    final byName = index.putIfAbsent(slug, () => <String, String>{});
    byName[e.name] = e.id;
  }
  return index;
}

/// Materializes a single installed content package's entities into the same
/// `Map<String, Entity>` shape the wizard/editor consume. Reads straight from
/// `PackageEntities` (no full-blob `load()`), resolves `_lookup` placeholders
/// against the built-in Tier-0 ids, and caches per package name.
///
/// Used as an extra entity source during character creation when the user
/// picks standalone packages instead of a world, and by the editor to
/// re-resolve such characters (their `source_packages` field).
final packageEntitiesProvider =
    FutureProvider.family<Map<String, Entity>, String>((ref, packageName) async {
  ref.keepAlive();
  final db = ref.watch(appDatabaseProvider);
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  final pkg = await db.packagesDao.getByName(packageName);
  if (pkg == null) return const <String, Entity>{};
  final rows = await db.packagesDao.getEntities(pkg.id);
  final tier0 = _tier0IndexFromBuiltin(builtin);
  final out = <String, Entity>{};
  for (final row in rows) {
    final attrs = jsonDecode(row.fieldsJson);
    final resolved = PackageImportService.resolveLookupPlaceholder(
      attrs is Map ? Map<String, dynamic>.from(attrs) : <String, dynamic>{},
      tier0,
    ) as Map<String, dynamic>;
    out[row.id] = Entity(
      id: row.id,
      name: row.name,
      categorySlug: row.categorySlug,
      source: row.source,
      description: row.description,
      imagePath: row.imagePath,
      images: _decodeStringList(row.imagesJson),
      tags: _decodeStringList(row.tagsJson),
      dmNotes: row.dmNotes,
      pdfs: _decodeStringList(row.pdfsJson),
      locationId: row.locationId,
      fields: resolved,
    );
  }
  return Map<String, Entity>.unmodifiable(out);
});

List<String> _decodeStringList(String json) {
  final v = jsonDecode(json);
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

/// Merges the built-in SRD map with every package in [packageNames], packages
/// layering on top (later names win id collisions). Package maps still
/// loading contribute nothing yet — the caller re-runs when their futures
/// settle (both call sites watch [packageEntitiesProvider] reactively).
Map<String, Entity> mergeBuiltinWithPackages(
  Ref ref,
  Map<String, Entity> builtin,
  List<String> packageNames,
) {
  if (packageNames.isEmpty) return builtin;
  final merged = <String, Entity>{...builtin};
  for (final name in packageNames) {
    final map = ref.watch(packageEntitiesProvider(name)).valueOrNull;
    if (map == null) continue;
    merged.addAll(map);
  }
  return Map<String, Entity>.unmodifiable(merged);
}
