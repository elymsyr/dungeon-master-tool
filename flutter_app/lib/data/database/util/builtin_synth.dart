import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../application/services/package_import_service.dart';
import '../../../application/services/srd_core_package_bootstrap.dart'
    show srdCorePackageName;
import '../app_database.dart';

const _uuid = Uuid();

/// In-memory marker on entitiesMap entries that came from the synthesiser.
/// `_saveToDb` reads this flag to skip persisting pristine built-in rows.
const String synthFlagKey = '_synth';

/// Deterministic per-world id for a built-in package entity. F1 decouple:
/// the same `(worldId, packageEntityId)` pair always resolves to the same
/// synthesised id, so character refs stay stable across loads without us
/// ever materialising a `world_entities` row for the built-in pack.
String synthBuiltinEntityId(String worldId, String packageEntityId) =>
    _uuid.v5(worldId, packageEntityId);

class BuiltinSynthResult {
  /// Synthesised `entities` map entries keyed by synth id. Empty when the
  /// built-in pack isn't installed in this world or every pack entity has
  /// already been forked into a homebrew row.
  final Map<String, dynamic> entries;

  /// The built-in package id, or null when the world has no built-in install.
  final String? builtinPackageId;

  const BuiltinSynthResult({
    required this.entries,
    required this.builtinPackageId,
  });
}

/// Synthesises built-in entity entries for [worldId] without touching
/// `world_entities`. Refs inside each pack entity's `fields_json` are
/// remapped from pack-internal ids to the per-world synth ids so the
/// shape matches what `EntityNotifier` already expects.
///
/// [existingPackageEntityIds] are the pack-entity ids already covered by
/// a real `world_entities` row (homebrew fork or legacy import). The
/// synthesiser skips these so a fork wins over the pristine pack entry.
Future<BuiltinSynthResult> synthesizeWorldBuiltins(
  AppDatabase db,
  String worldId, {
  required Set<String> existingPackageEntityIds,
}) async {
  final installed = await db.installedPackagesDao.getByWorld(worldId);
  String? builtinPkgId;
  for (final row in installed) {
    final pkg = await db.packagesDao.getById(row.packageId);
    if (pkg == null) continue;
    if (pkg.name == srdCorePackageName) {
      builtinPkgId = pkg.id;
      break;
    }
  }
  if (builtinPkgId == null) {
    return const BuiltinSynthResult(entries: {}, builtinPackageId: null);
  }

  final packRows = await db.packagesDao.getEntities(builtinPkgId);
  if (packRows.isEmpty) {
    return BuiltinSynthResult(entries: const {}, builtinPackageId: builtinPkgId);
  }

  // Tier-0 lookup map: slug → name → synth id. Drives `_lookup` resolution
  // in Tier-1 attrs (mirrors what `srd_core_bootstrap._seedTier0` builds
  // at world-create time, just deterministic instead of v4 random).
  final tier0Index = <String, Map<String, String>>{};
  for (final r in packRows) {
    tier0Index
        .putIfAbsent(r.categorySlug, () => <String, String>{})[r.name] =
        synthBuiltinEntityId(worldId, r.id);
  }

  // Pack id → synth id remap for cross-entity refs inside Tier-1 attrs.
  final packToSynth = <String, String>{
    for (final r in packRows) r.id: synthBuiltinEntityId(worldId, r.id),
  };

  final out = <String, dynamic>{};
  for (final r in packRows) {
    if (existingPackageEntityIds.contains(r.id)) continue;
    final synthId = packToSynth[r.id]!;
    final rawFields = _decodeMap(r.fieldsJson);
    final resolved = PackageImportService.resolveLookupPlaceholder(
      rawFields,
      tier0Index,
    );
    final remapped = _remapStringRefs(resolved, packToSynth);
    out[synthId] = <String, dynamic>{
      'name': r.name,
      'type': r.categorySlug,
      'source': r.source,
      'description': r.description,
      'image_path': r.imagePath,
      'images': _decodeList(r.imagesJson),
      'tags': _decodeList(r.tagsJson),
      'dm_notes': r.dmNotes,
      'pdfs': _decodeList(r.pdfsJson),
      'location_id': r.locationId,
      'attributes': remapped is Map<String, dynamic>
          ? remapped
          : <String, dynamic>{},
      'package_id': builtinPkgId,
      'package_entity_id': r.id,
      'linked': true,
      // `_synth: true` lets the repo save path skip writing pristine
      // built-in entries back into `world_entities`. Edits via
      // EntityNotifier produce a fresh map (no `_synth`) which then
      // persists as a per-world fork row at the same synth id.
      synthFlagKey: true,
    };
  }

  return BuiltinSynthResult(entries: out, builtinPackageId: builtinPkgId);
}

/// Builds a `slug → name → entityId` index of Tier-0 lookup rows for
/// [worldId], usable as `tier0NameToId` in
/// [PackageImportService.resolveLookupPlaceholder].
///
/// F1 decouple: built-in Tier-0 rows are not materialised in `world_entities`
/// — they live in `package_entities` and are synthesised at read time with
/// deterministic synth IDs ([synthBuiltinEntityId]). Pack-sync callers used
/// to query `world_entities` only and got an empty index on F1 worlds,
/// causing `_lookup` placeholders inside shared/imported homebrew packages
/// to resolve to `''` — manifested as "broken link entities" on joined
/// players.
///
/// Resolution priority for a given (slug, name):
///   1. Real `world_entities` row (legacy worlds + homebrew Tier-0 forks).
///   2. Synth id derived from the built-in SRD pack's `package_entities`.
Future<Map<String, Map<String, String>>> buildTier0LookupIndex(
  AppDatabase db,
  String worldId, {
  required Set<String> tier0Slugs,
}) async {
  final index = <String, Map<String, String>>{};

  // 1. Synth IDs for Tier-0 entries from the installed SRD pack.
  final installed = await db.installedPackagesDao.getByWorld(worldId);
  String? builtinPkgId;
  for (final row in installed) {
    final pkg = await db.packagesDao.getById(row.packageId);
    if (pkg == null) continue;
    if (pkg.name == srdCorePackageName) {
      builtinPkgId = pkg.id;
      break;
    }
  }
  if (builtinPkgId != null) {
    final packRows = await db.packagesDao.getEntities(builtinPkgId);
    for (final r in packRows) {
      if (!tier0Slugs.contains(r.categorySlug)) continue;
      index.putIfAbsent(r.categorySlug, () => <String, String>{})[r.name] =
          synthBuiltinEntityId(worldId, r.id);
    }
  }

  // 2. Real Tier-0 rows in `world_entities` (legacy worlds, or homebrew
  // forks that overrode a pack entry) win over the synth id so edits stick.
  final realRows = await (db.select(db.worldEntities)
        ..where((t) =>
            t.worldId.equals(worldId) & t.categorySlug.isIn(tier0Slugs)))
      .get();
  for (final r in realRows) {
    index.putIfAbsent(r.categorySlug, () => <String, String>{})[r.name] = r.id;
  }

  return index;
}

Map<String, dynamic> _decodeMap(String json) {
  if (json.isEmpty || json == '{}') return <String, dynamic>{};
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return <String, dynamic>{};
}

List<dynamic> _decodeList(String json) {
  if (json.isEmpty || json == '[]') return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded;
  } catch (_) {}
  return const [];
}

dynamic _remapStringRefs(dynamic value, Map<String, String> remap) {
  if (value is String) return remap[value] ?? value;
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k.toString()] = _remapStringRefs(v, remap);
    });
    return out;
  }
  if (value is List) {
    return value.map((e) => _remapStringRefs(e, remap)).toList();
  }
  return value;
}
