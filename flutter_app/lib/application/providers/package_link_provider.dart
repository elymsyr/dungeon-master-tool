import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/package_link.dart';
import '../services/package_link_service.dart';
import '../services/world_package_installer.dart';
import 'builtin_package_provider.dart' show srdReferenceEntitiesProvider;
import 'entity_provider.dart' show entityFromRaw;
import 'package_provider.dart' show packageRepositoryProvider;

final packageLinkServiceProvider = Provider<PackageLinkService>((ref) {
  return PackageLinkService(
    ref.watch(appDatabaseProvider),
    ref.watch(packageRepositoryProvider),
  );
});

/// Single entry point for installing / re-syncing / removing a package in a
/// world, link-closure aware. See [WorldPackageInstaller].
final worldPackageInstallerProvider = Provider<WorldPackageInstaller>((ref) {
  return WorldPackageInstaller(
    ref.watch(appDatabaseProvider),
    ref.watch(packageRepositoryProvider),
  );
});

/// Bumped after every link mutation so the family providers below re-run.
/// Riverpod families keyed by package name can't be invalidated wholesale, and
/// a link edit changes the closure of every package upstream of the target —
/// so a single revision counter is both simpler and more correct than trying
/// to invalidate the affected keys.
final packageLinkRevisionProvider = StateProvider<int>((ref) => 0);

/// Declared links of one package, split into resolved + dangling.
final packageLinkStatusProvider =
    FutureProvider.family<PackageLinkStatus, String>((ref, packageName) async {
  ref.watch(packageLinkRevisionProvider);
  return ref.watch(packageLinkServiceProvider).statusOf(packageName);
});

/// Transitive link closure in dependency order, as package names. The package
/// itself is the LAST element (see [PackageLinkService.closure]).
final packageLinkClosureProvider =
    FutureProvider.family<List<String>, String>((ref, packageName) async {
  ref.watch(packageLinkRevisionProvider);
  final rows = await ref.watch(packageLinkServiceProvider).closure(packageName);
  return [for (final p in rows) p.name];
});

/// Closure over several roots at once — what the character wizard needs when
/// the player ticks a set of content packages.
///
/// The family key is [packageSetKey], NOT a `List<String>`: Riverpod caches
/// families by `==` on the key, and a fresh list instance every rebuild would
/// mint a fresh provider each time (and never settle).
final packageLinkClosureOfAllProvider =
    FutureProvider.family<List<String>, String>((ref, key) async {
  ref.watch(packageLinkRevisionProvider);
  final names = key.isEmpty ? const <String>[] : key.split(_keySep);
  if (names.isEmpty) return const [];
  final rows =
      await ref.watch(packageLinkServiceProvider).closureOfAll(names);
  return [for (final p in rows) p.name];
});

/// NUL separator — package names are human titles ("Adventurer's Guide"), so
/// any printable separator could split a name in half.
const String _keySep = '\u0000';

/// Stable family key for [packageLinkClosureOfAllProvider]. Caller order is
/// preserved (it decides id-collision precedence downstream), so two different
/// orderings are two cache entries — acceptable, the picker order is stable.
String packageSetKey(List<String> packageNames) =>
    packageNames.join(_keySep);

/// Read-only entities overlaid into [packageName]'s editing view: the built-in
/// SRD reference set PLUS every package it links (transitively).
///
/// Generalises what used to be an SRD-only overlay. Consumed by
/// `EntityNotifier(referenceOverlayFor: …)`, which injects these on top of the
/// package's own rows and skips them on every write path — so a linked
/// package's content is *visible* without ever being copied in. Editing one
/// forks a homebrew copy, exactly as with SRD rows.
///
/// Entities are keyed by their pack-side id and marked `linked: true`, so a
/// cross-package reference stored in a card is the target's `package_entities`
/// id — which `WorldPackageInstaller` then remaps to world ids on import.
final packageReferenceOverlayProvider =
    FutureProvider.family<Map<String, Entity>, String>(
        (ref, packageName) async {
  ref.watch(packageLinkRevisionProvider);
  final srd = await ref.watch(srdReferenceEntitiesProvider.future);
  final closure =
      await ref.watch(packageLinkServiceProvider).closure(packageName);

  // Closure ends with the package itself — its own rows come from the editor
  // state, not the overlay.
  final linked = closure.where((p) => p.name != packageName).toList();
  if (linked.isEmpty) return srd;

  final db = ref.watch(appDatabaseProvider);
  final out = <String, Entity>{...srd};
  // Dependency order: a package later in the closure wins an id collision,
  // matching how the editor layers its own rows on top of everything.
  for (final pkg in linked) {
    for (final row in await db.packagesDao.getEntities(pkg.id)) {
      out[row.id] = _entityFromPackageRow(row);
    }
  }
  return out;
});

Entity _entityFromPackageRow(PackageEntity row) {
  return entityFromRaw(row.id, {
    'name': row.name,
    'type': row.categorySlug,
    'source': row.source,
    'description': row.description,
    'image_path': row.imagePath,
    'images': _decodeList(row.imagesJson),
    'tags': _decodeList(row.tagsJson),
    'dm_notes': row.dmNotes,
    'pdfs': _decodeList(row.pdfsJson),
    'location_id': row.locationId,
    'attributes': _decodeMap(row.fieldsJson),
    'package_id': row.packageId,
    'package_entity_id': row.id,
    'linked': true,
  }).copyWith(linked: true);
}

List<dynamic> _decodeList(String json) {
  if (json.isEmpty || json == '[]') return const [];
  try {
    final v = jsonDecode(json);
    if (v is List) return v;
  } catch (_) {}
  return const [];
}

Map<String, dynamic> _decodeMap(String json) {
  if (json.isEmpty || json == '{}') return const {};
  try {
    final v = jsonDecode(json);
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  return const {};
}

/// Link a package into another. Returns false when the link already exists,
/// either side is missing, or it would create a cycle.
Future<bool> addPackageLink(
  WidgetRef ref,
  String packageName,
  String targetName,
) async {
  final ok = await ref
      .read(packageLinkServiceProvider)
      .addLink(packageName, targetName);
  if (ok) _bump(ref);
  return ok;
}

Future<bool> removePackageLink(
  WidgetRef ref,
  String packageName,
  PackageLink link,
) async {
  final ok =
      await ref.read(packageLinkServiceProvider).removeLink(packageName, link);
  if (ok) _bump(ref);
  return ok;
}

void _bump(WidgetRef ref) {
  ref.read(packageLinkRevisionProvider.notifier).update((n) => n + 1);
}
