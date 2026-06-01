import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/repositories/package_repository.dart';
import 'package_payload_importer.dart';

/// Installs / removes the bundled Open5e content packs (`assets/open5e_packs/`)
/// into the local package store. Admin-only utility (gated by the dashboard
/// toggle) so a maintainer can install the shipped content in-app, inspect it
/// and compare against a freshly-published version. Each installed package is
/// stamped `metadata.installed_from = 'assets'` and tagged "(assets)" in the
/// package list.
class AssetsPackInstaller {
  AssetsPackInstaller(this._repo);
  final PackageRepository _repo;

  static const _manifestAsset = 'assets/open5e_packs/manifest.json';
  static const _assetDir = 'assets/open5e_packs';

  /// Whether the bundled Open5e packs are present in THIS build (BB-1). The
  /// 32MB packs are excluded from the default pubspec asset set, so normal
  /// production builds return false here and the admin UI hides the installer.
  /// A maintainer who needs the in-app installer uncomments the
  /// `assets/open5e_packs/` line in pubspec.yaml and rebuilds — that build then
  /// bundles the packs and this returns true.
  Future<bool> isAvailable() async => (await _tryLoad(_manifestAsset)) != null;

  /// Install every bundled pack. Idempotent — `save()` upserts by name.
  /// Returns the number of packs installed.
  Future<int> installAll() async {
    final raw = await _tryLoad(_manifestAsset);
    if (raw == null) return 0;
    final json = jsonDecode(raw);
    final packs = (json is Map ? json['packs'] : null);
    if (packs is! List) return 0;
    final importer = PackagePayloadImporter(_repo);
    var n = 0;
    for (final p in packs.whereType<Map>()) {
      final asset = p['asset'] as String?;
      if (asset == null) continue;
      final payloadRaw = await _tryLoad('$_assetDir/$asset');
      if (payloadRaw == null) continue;
      final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      await importer.install(payload, installedFrom: 'assets');
      n++;
    }
    return n;
  }

  /// Remove every package previously installed from bundled assets (those
  /// stamped `metadata.installed_from == 'assets'`). Returns the count removed.
  Future<int> uninstallAll() async {
    final names = await _repo.getAvailable();
    var n = 0;
    for (final name in names) {
      try {
        final data = await _repo.load(name);
        final meta = data['metadata'];
        if (meta is Map && meta['installed_from'] == 'assets') {
          await _repo.delete(name);
          n++;
        }
      } catch (_) {
        // best-effort — skip packages that fail to load.
      }
    }
    return n;
  }

  Future<String?> _tryLoad(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      // BB-1 debug fallback: the 32MB packs are excluded from the bundle, so
      // rootBundle misses them. A `flutter run` (debug) on desktop has cwd =
      // project root, so read them straight off disk — this is what makes the
      // admin installer + its checkbox appear under `flutter run --debug`
      // without re-bloating release builds (release has no on-disk packs).
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
}
