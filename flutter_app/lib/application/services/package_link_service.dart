import 'dart:convert';

import '../../data/database/app_database.dart';
import '../../domain/entities/package_link.dart';
import '../../domain/repositories/package_repository.dart';

/// Reads and writes the package→package link graph.
///
/// Links live in `packages.state_json['links']` (see [PackageLink] for why
/// there is no table). Every traversal here loads the whole `packages` row set
/// once and walks it in memory: the catalog is a few dozen rows and their
/// `state_json` is small metadata (entities live in `package_entities`), so a
/// single `getAll()` beats N per-node queries.
///
/// Three consumers depend on the closure:
///   * the package editor overlay (`packageReferenceOverlayProvider`),
///   * world install (`WorldPackageInstaller`),
///   * character-creation sources (`package_source_entities.dart`).
class PackageLinkService {
  final AppDatabase _db;
  final PackageRepository _repo;

  PackageLinkService(this._db, this._repo);

  /// Parses the `links` list out of a package's `state_json`. Accepts both the
  /// top-level `links` key (what [writeLinks] emits) and `metadata.links`
  /// (what a built pack payload declares) so imported packs keep their links.
  /// Malformed entries are dropped.
  static List<PackageLink> parseLinks(String stateJson) {
    if (stateJson.isEmpty || stateJson == '{}') return const [];
    Map<String, dynamic> state;
    try {
      final decoded = jsonDecode(stateJson);
      if (decoded is! Map) return const [];
      state = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const [];
    }
    return linksFromState(state);
  }

  /// Same as [parseLinks] but over an already-decoded package state map (the
  /// shape `PackageRepository.load` returns). Shared with the payload importer.
  static List<PackageLink> linksFromState(Map<String, dynamic> state) {
    var raw = state['links'];
    if (raw is! List) {
      final meta = state['metadata'];
      raw = meta is Map ? meta['links'] : null;
    }
    if (raw is! List) return const [];
    final out = <PackageLink>[];
    for (final item in raw) {
      final link = PackageLink.fromJson(item);
      if (link == null) continue;
      if (out.contains(link)) continue;
      out.add(link);
    }
    return out;
  }

  /// Every package row, indexed by id and by name — the single read backing
  /// all traversals below.
  Future<_PackageIndex> _index() async {
    final rows = await _db.packagesDao.getAll();
    return _PackageIndex(rows);
  }

  /// Declared links of [packageName], resolved or not.
  Future<List<PackageLink>> linksOf(String packageName) async {
    final index = await _index();
    final pkg = index.byName[packageName];
    if (pkg == null) return const [];
    return parseLinks(pkg.stateJson);
  }

  /// Declared links split into resolved targets and dangling refs.
  Future<PackageLinkStatus> statusOf(String packageName) async {
    final index = await _index();
    final pkg = index.byName[packageName];
    if (pkg == null) {
      return const PackageLinkStatus(resolved: [], dangling: []);
    }
    final resolved = <Package>[];
    final dangling = <PackageLink>[];
    for (final link in parseLinks(pkg.stateJson)) {
      final target = index.resolve(link);
      if (target == null) {
        dangling.add(link);
      } else if (!resolved.any((p) => p.id == target.id)) {
        resolved.add(target);
      }
    }
    return PackageLinkStatus(resolved: resolved, dangling: dangling);
  }

  /// Transitive link closure of [packageName] in **dependency order**: every
  /// package appears after the packages it links, with [packageName] itself
  /// last. Cycles are broken by a visited set (a package already emitted is
  /// never emitted twice), dangling links are skipped silently.
  ///
  /// Returns an empty list when [packageName] is not installed locally.
  Future<List<Package>> closure(String packageName) async {
    final index = await _index();
    final root = index.byName[packageName];
    if (root == null) return const [];
    return _closureFrom(index, [root]);
  }

  /// Closure over several roots at once, de-duplicated. Used by the character
  /// wizard, which layers a whole set of picked packages.
  Future<List<Package>> closureOfAll(Iterable<String> packageNames) async {
    final index = await _index();
    final roots = <Package>[];
    for (final name in packageNames) {
      final pkg = index.byName[name];
      if (pkg != null && !roots.any((p) => p.id == pkg.id)) roots.add(pkg);
    }
    if (roots.isEmpty) return const [];
    return _closureFrom(index, roots);
  }

  /// Post-order DFS. `emitted` doubles as the cycle guard: a node is pushed
  /// only after its links are walked, and `visiting` stops A→B→A from
  /// recursing forever.
  List<Package> _closureFrom(_PackageIndex index, List<Package> roots) {
    final out = <Package>[];
    final emitted = <String>{};
    final visiting = <String>{};

    void walk(Package pkg) {
      if (emitted.contains(pkg.id)) return;
      if (!visiting.add(pkg.id)) return; // cycle — already on the stack
      for (final link in parseLinks(pkg.stateJson)) {
        final target = index.resolve(link);
        if (target == null) continue; // dangling — skipped, never fatal
        if (target.id == pkg.id) continue; // self-link
        walk(target);
      }
      visiting.remove(pkg.id);
      if (emitted.add(pkg.id)) out.add(pkg);
    }

    for (final root in roots) {
      walk(root);
    }
    return out;
  }

  /// Packages that declare a link TO [packageName]. Drives the delete warning
  /// ("3 packages link this one").
  Future<List<Package>> reverseLinks(String packageName) async {
    final index = await _index();
    final target = index.byName[packageName];
    if (target == null) return const [];
    final out = <Package>[];
    for (final pkg in index.all) {
      if (pkg.id == target.id) continue;
      for (final link in parseLinks(pkg.stateJson)) {
        if (index.resolve(link)?.id == target.id) {
          out.add(pkg);
          break;
        }
      }
    }
    return out;
  }

  /// True when linking [targetName] into [packageName] would create a cycle —
  /// i.e. [packageName] is already reachable from [targetName].
  Future<bool> wouldCycle(String packageName, String targetName) async {
    if (packageName == targetName) return true;
    final index = await _index();
    final source = index.byName[packageName];
    final target = index.byName[targetName];
    if (source == null || target == null) return false;
    return _closureFrom(index, [target]).any((p) => p.id == source.id);
  }

  /// Adds a link from [packageName] to [targetName]. No-op when the link
  /// already exists, when either side is missing, or when it would cycle.
  /// Returns true only when a link was actually written.
  Future<bool> addLink(String packageName, String targetName) async {
    final index = await _index();
    final source = index.byName[packageName];
    final target = index.byName[targetName];
    if (source == null || target == null) return false;
    if (source.id == target.id) return false;
    if (await wouldCycle(packageName, targetName)) return false;

    // Growable copy — parseLinks may hand back a `const []`.
    final links = [...parseLinks(source.stateJson)];
    if (links.any((l) => index.resolve(l)?.id == target.id)) return false;
    links.add(PackageLink(packageId: target.id, name: target.name));
    await writeLinks(packageName, links);
    return true;
  }

  /// Removes every link from [packageName] resolving to [targetName] (or, for
  /// a dangling link, matching it by id/name). Returns true when something
  /// changed.
  Future<bool> removeLink(String packageName, PackageLink link) async {
    final index = await _index();
    final source = index.byName[packageName];
    if (source == null) return false;
    final links = parseLinks(source.stateJson);
    final kept = links.where((l) {
      if (l == link) return false;
      // Also drop a link that resolves to the same package under a stale
      // name/id pair, so removal is not defeated by a renamed target.
      final a = index.resolve(l);
      final b = index.resolve(link);
      return !(a != null && b != null && a.id == b.id);
    }).toList();
    if (kept.length == links.length) return false;
    await writeLinks(packageName, kept);
    return true;
  }

  /// Persists [links] onto [packageName] through `saveStatePatch`, which
  /// merges the single `links` key instead of rewriting the package.
  ///
  /// No-op for the built-in SRD pack — `PackageRepositoryImpl.saveStatePatch`
  /// already refuses it (the pack is regenerated from code every boot), so SRD
  /// is the root of the graph and never links anything.
  Future<void> writeLinks(String packageName, List<PackageLink> links) {
    return _repo.saveStatePatch(packageName, {
      'links': [for (final l in links) l.toJson()],
    });
  }
}

/// Result of resolving one package's declared links.
class PackageLinkStatus {
  /// Links whose target is installed locally.
  final List<Package> resolved;

  /// Links whose target could not be found — shown as "not installed".
  final List<PackageLink> dangling;

  const PackageLinkStatus({required this.resolved, required this.dangling});

  bool get isEmpty => resolved.isEmpty && dangling.isEmpty;
  int get total => resolved.length + dangling.length;
}

/// In-memory id/name index over the local package catalog.
class _PackageIndex {
  final List<Package> all;
  final Map<String, Package> byId;
  final Map<String, Package> byName;

  _PackageIndex(this.all)
      : byId = {for (final p in all) p.id: p},
        byName = {for (final p in all) p.name: p};

  /// Soft-ref resolution: id first, human name as the fallback for packages
  /// that were re-created with a fresh local id (copy, marketplace download).
  Package? resolve(PackageLink link) {
    final byIdHit = link.packageId.isEmpty ? null : byId[link.packageId];
    if (byIdHit != null) return byIdHit;
    return link.name.isEmpty ? null : byName[link.name];
  }
}
