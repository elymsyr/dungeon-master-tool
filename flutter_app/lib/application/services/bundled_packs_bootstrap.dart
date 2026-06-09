import 'dart:convert';
import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../../data/database/app_database.dart';
import '../../domain/repositories/package_repository.dart';
import 'package_payload_importer.dart';

/// Debug-only auto-installer for the bundled Open5e content packs
/// (`assets/open5e_packs/`). Mirrors [SrdCorePackageBootstrap]: runs once per
/// app session per DB instance and (re)installs each pack into the local
/// package store whenever its on-disk content differs from the stored copy.
///
/// Why this exists: the bundled packs previously reached the DB *only* via the
/// admin "Install asset packs" toggle. A maintainer who never flipped it — or
/// who flipped it OFF — saw stale / missing content (e.g. official-background
/// starting equipment the importer now structures into `equipment_choice_groups`).
/// This makes the freshly-regenerated packs self-heal on every debug launch,
/// independent of the admin switch.
///
/// BB-1: the ~32MB packs are excluded from release bundles and only readable
/// off-disk under `kDebugMode` (see [_tryLoad]). The provider that drives this
/// guards on `kDebugMode`, so it is a deliberate no-op in release — where the
/// official R2 catalog is the real delivery channel.
///
/// Freshness gate: `pack_version` / `source_data_rev` are NOT bumped between
/// regenerations (both stay `1.0.0` / `staging-…`), so a version compare can't
/// detect a content change. Instead we hash the raw payload and store the digest
/// under `metadata.bundled_content_hash`; a pack is skipped only when its stored
/// hash still matches the on-disk file. Each row is stamped
/// `installed_from = 'assets'` so the admin uninstall path keeps recognising it.
class BundledPacksBootstrap {
  BundledPacksBootstrap(this._db, this._repo);

  final AppDatabase _db;
  final PackageRepository _repo;

  static const _manifestAsset = 'assets/open5e_packs/manifest.json';
  static const _assetDir = 'assets/open5e_packs';

  /// DB instances already reconciled in this process. Keyed by
  /// `identityHashCode` so an auth-driven DB swap re-reconciles into the new DB
  /// (same rationale as [SrdCorePackageBootstrap._installedFor]).
  static final Set<int> _installedFor = <int>{};

  /// Reconcile every bundled pack into the DB. Returns the number of packs
  /// (re)installed — 0 when everything was already current or unavailable.
  Future<int> ensureInstalled() async {
    final key = identityHashCode(_db);
    if (_installedFor.contains(key)) return 0;

    final manifestRaw = await _tryLoad(_manifestAsset);
    if (manifestRaw == null) {
      // Release build / packs not on disk — nothing to do. Mark done so we
      // don't re-probe rootBundle on every package read this session.
      _installedFor.add(key);
      return 0;
    }

    var installed = 0;
    try {
      final decoded = jsonDecode(manifestRaw);
      final packs = decoded is Map ? decoded['packs'] : null;
      if (packs is! List) {
        _installedFor.add(key);
        return 0;
      }
      final importer = PackagePayloadImporter(_repo);
      for (final p in packs.whereType<Map>()) {
        final asset = p['asset'] as String?;
        if (asset == null) continue;
        final payloadRaw = await _tryLoad('$_assetDir/$asset');
        if (payloadRaw == null) continue;
        final hash = sha1.convert(utf8.encode(payloadRaw)).toString();
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        final name = _packageName(payload);
        if (name == null || name.isEmpty) continue;

        // Cheap gate: skip when a non-empty row already carries this exact
        // content hash. Two indexed reads; no re-install on a warm start.
        final row = await _db.packagesDao.getByName(name);
        if (row != null) {
          final count = await _db.packagesDao.countEntities(row.id);
          if (count > 0 && _storedHash(row) == hash) continue;
        }

        await importer.install(
          payload,
          installedFrom: 'assets',
          extraMetadata: {'bundled_content_hash': hash},
        );
        installed++;
      }
    } catch (_) {
      // Best-effort: a malformed manifest/payload must not block startup.
      // Leave the gate unmarked so a later call can retry.
      return installed;
    }

    _installedFor.add(key);
    return installed;
  }

  /// Package row name the importer will use: prefer `metadata.title`, fall back
  /// to the machine slug — kept in lockstep with [PackagePayloadImporter].
  String? _packageName(Map<String, dynamic> payload) {
    final meta = payload['metadata'];
    final title = (meta is Map ? meta['title'] as String? : null)?.trim();
    if (title != null && title.isNotEmpty) return title;
    return payload['package_name'] as String?;
  }

  /// Reads `metadata.bundled_content_hash` out of a stored row's `stateJson`.
  /// Returns null (→ treated as a mismatch, forcing re-install) when absent or
  /// malformed.
  String? _storedHash(Package row) {
    final raw = row.stateJson;
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final meta = decoded['metadata'];
        if (meta is Map && meta['bundled_content_hash'] is String) {
          return meta['bundled_content_hash'] as String;
        }
      }
    } catch (_) {
      // Malformed stateJson — fall through to re-install.
    }
    return null;
  }

  /// rootBundle first, then the `kDebugMode`-only on-disk fallback — identical
  /// to [AssetsPackInstaller._tryLoad]; the packs are excluded from the bundle
  /// (BB-1) but live on disk during `flutter run`.
  Future<String?> _tryLoad(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      if (kDebugMode && !kIsWeb) {
        try {
          final f = File(asset);
          if (await f.exists()) return await f.readAsString();
        } catch (_) {
          // Not on disk / no filesystem access — fall through to null.
        }
      }
      return null;
    }
  }

  static void resetInstallGate() => _installedFor.clear();
}
