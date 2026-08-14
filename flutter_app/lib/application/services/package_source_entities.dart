import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../providers/package_link_provider.dart';
import '../providers/package_provider.dart';
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
  // Reconcile the bundled Open5e packs before reading — guarantees the wizard /
  // editor see freshly-regenerated pack content (e.g. background equipment)
  // even when nothing watched [packageListProvider] first. No-op in release.
  await ref.watch(bundledPacksBootstrapProvider.future);
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

/// Package names a committed character was built against. Persisted on the PC
/// entity's `source_packages` field by the wizard so the editor/card can
/// re-resolve refs that live outside the bundled SRD pack.
List<String> sourcePackagesOf(Character character) {
  final raw = character.entity.fields['source_packages'];
  if (raw is List) {
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

/// Transitive link closure of [packageNames] as names, or the input unchanged
/// while the closure is still loading. A package the user picked pulls in the
/// packages it links, so a class/species borrowed from a linked pack
/// dereferences the same way it does inside the package editor.
/// `Ref.watch` / `WidgetRef.watch` share this shape, so the helpers below work
/// from providers and widgets alike (same trick as `world_packages_provider`).
typedef PackageWatch = T Function<T>(ProviderListenable<T> p);

List<String> expandedPackageNames(
    PackageWatch watch, List<String> packageNames) {
  if (packageNames.isEmpty) return packageNames;
  final closure =
      watch(packageLinkClosureOfAllProvider(packageSetKey(packageNames)))
          .valueOrNull;
  // Empty means nothing resolved locally — keep the caller's list rather than
  // silently dropping every source.
  return (closure == null || closure.isEmpty) ? packageNames : closure;
}

/// Layers a character's installed [packageNames] on top of [base] (packages
/// win id collisions). [readPackage] returns the loaded entity map for a
/// package name, or null while its future is still in flight — callers must
/// `watch` so they re-run when those settle. Shared by every card-side path
/// (resolver, stat chips, editor) so official-package refs dereference
/// everywhere the wizard already resolved them. Returns [base] unchanged when
/// the character has no source packages or none have loaded yet.
///
/// [watch] is the caller's `ref.watch`, used to expand [packageNames] over
/// their link closure before layering.
Map<String, Entity> layerCharacterPackages(
  PackageWatch watch,
  Map<String, Entity> base,
  List<String> packageNames,
  Map<String, Entity>? Function(String name) readPackage,
) {
  if (packageNames.isEmpty) return base;
  final maps = <Map<String, Entity>>[];
  for (final name in expandedPackageNames(watch, packageNames)) {
    final m = readPackage(name);
    if (m != null && m.isNotEmpty) maps.add(m);
  }
  if (maps.isEmpty) return base;
  // Reversed for the same reason as [layerPackagesOverBuiltin]: a
  // `CombinedMapView` resolves a key — and is iterated by
  // `findEntityIdByName` — in list order, so *first* wins. Dependency order
  // puts the picked package last, and it is the one that should win.
  return UnmodifiableMapView<String, Entity>(
    CombinedMapView<String, Entity>([...maps.reversed, base]),
  );
}

/// Merges the built-in SRD map with every package in [packageNames] *and the
/// packages those link*, packages layering on top (later names win id
/// collisions). Package maps still loading contribute nothing yet — the caller
/// re-runs when their futures settle (both call sites watch
/// [packageEntitiesProvider] reactively).
Map<String, Entity> mergeBuiltinWithPackages(
  Ref ref,
  Map<String, Entity> builtin,
  List<String> packageNames,
) {
  if (packageNames.isEmpty) return builtin;
  final maps = <Map<String, Entity>>[];
  // Closure is dependency-ordered (links first), so a picked package still
  // wins an id collision against the packages it borrows from.
  for (final name in expandedPackageNames(ref.watch, packageNames)) {
    final map = ref.watch(packageEntitiesProvider(name)).valueOrNull;
    if (map != null) maps.add(map);
  }
  return layerPackagesOverBuiltin(builtin, maps);
}

/// Built-in map with [packages] layered on top, in list order.
///
/// **A package wins a *name* collision, not just an id collision** (audit
/// **L1**). Ids never actually collide across packs — they are uuidv5 of
/// `(pack, slug, name)` — so the merge order that matters is the one
/// `findEntityIdByName` sees: it indexes `byId.values` with *first writer
/// wins*, i.e. insertion order. Building the map as `{...builtin, ...packs}`
/// therefore handed every one of the 1,643 section-A collisions (409 monsters,
/// 314 spells, 12 A5E backgrounds, …) to the built-in card, while the two
/// sibling paths gave them to the package: [layerCharacterPackages] puts the
/// package maps first in its `CombinedMapView`, and `wizardEntitiesProvider`'s
/// world branch drops the built-in row outright when the campaign supplies the
/// same `(slug, name)`. The same worldless character resolved a soft ref one
/// way in the wizard and the other way on the sheet.
///
/// L1's measurement is why this is a fix and not a preference: **nothing in
/// section A is a duplicate worth deleting** — A5E restats, separate ToB
/// editions, and two additive singletons (§2.5) — so a user who ticks A5E's
/// Adventurer's Guide is asking for A5E's "Fireball", and the shadowing has to
/// point at the pack they picked.
Map<String, Entity> layerPackagesOverBuiltin(
  Map<String, Entity> builtin,
  List<Map<String, Entity>> packages,
) {
  final merged = <String, Entity>{};
  // Reversed + putIfAbsent: the closure is dependency-ordered (links first,
  // the package the user actually picked last), and *last wins* — for the id
  // collision this always documented, and now for the name collision too.
  for (final map in packages.reversed) {
    for (final entry in map.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }
  }
  if (merged.isEmpty) return builtin;
  for (final entry in builtin.entries) {
    merged.putIfAbsent(entry.key, () => entry.value);
  }
  return Map<String, Entity>.unmodifiable(merged);
}
