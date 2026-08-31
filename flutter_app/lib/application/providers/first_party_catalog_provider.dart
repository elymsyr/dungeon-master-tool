import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_paths.dart';
import '../../data/services/first_party_catalog_service.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../services/assets_pack_installer.dart';
import '../services/bundled_worlds_installer.dart';
import '../services/cover_image_bundler.dart';
import '../services/package_payload_importer.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'package_provider.dart';

/// Long-lived catalog service (native HttpClient inside).
final firstPartyCatalogServiceProvider =
    Provider<FirstPartyCatalogService>((ref) => FirstPartyCatalogService());

/// Admin-only bundled-assets installer (Part 1 — dashboard toggle).
final assetsPackInstallerProvider = Provider<AssetsPackInstaller>(
    (ref) => AssetsPackInstaller(ref.read(packageRepositoryProvider)));

/// Whether the bundled Open5e packs ship in this build (BB-1). False in normal
/// production builds (packs excluded from pubspec to drop ~32MB) — the admin
/// installer toggle is hidden when this is false. Cached so the rootBundle
/// probe runs once.
final assetsPacksAvailableProvider = FutureProvider<bool>(
    (ref) => ref.read(assetsPackInstallerProvider).isAvailable());

/// Admin-only bundled worlds installer — reads from `assets/worlds/` and
/// converts world-blueprint format to world entities via CampaignRepository.
final bundledWorldsInstallerProvider = Provider<BundledWorldsInstaller>(
    (ref) => BundledWorldsInstaller(
          ref.read(campaignRepositoryProvider),
          ref.read(characterRepositoryProvider),
        ));

/// Whether bundled worlds are present in this build.
final bundledWorldsAvailableProvider = FutureProvider<bool>(
    (ref) => ref.read(bundledWorldsInstallerProvider).isAvailable());

/// Official package catalog: R2 manifest → bundled fallback. The service
/// degrades to the bundled catalog when offline, so this never surfaces an
/// offline error — the cards render (and install from bundled assets) offline.
final firstPartyCatalogProvider = FutureProvider<List<CatalogEntry>>((ref) {
  return ref.read(firstPartyCatalogServiceProvider).fetchManifest();
});

/// True when [catalogVersion] is a strictly newer `major.minor.patch` than the
/// version stamped into an installed pack's `metadata.catalog_version` (audit
/// D2). Fail-soft: an absent or non-semver version on either side reports "no
/// update" rather than nagging — `emit.packVersion` is semver by contract, so
/// anything else is data we don't understand.
bool isCatalogUpdateAvailable(String? installedVersion, String catalogVersion) {
  final a = _semver(catalogVersion);
  final b = _semver(installedVersion);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int>? _semver(String? v) {
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(v?.trim() ?? '');
  return m == null
      ? null
      : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// Per-slug install status for the official catalog cards.
enum CatalogInstallPhase { idle, installing, done, error }

class CatalogInstallStatus {
  const CatalogInstallStatus({
    this.phase = CatalogInstallPhase.idle,
    this.message,
  });

  final CatalogInstallPhase phase;
  final String? message;
}

/// Installs an official catalog package into the local package store: fetch the
/// payload (R2 → bundled), attach the live built-in schema, stamp
/// `metadata.installed_from = 'official'` + `catalog_version`, save, and refresh
/// the package list. Mirrors `SoundpackDownloadNotifier`.
class FirstPartyInstallNotifier
    extends StateNotifier<Map<String, CatalogInstallStatus>> {
  FirstPartyInstallNotifier(this._ref) : super(const {});

  final Ref _ref;

  CatalogInstallStatus statusFor(String slug) =>
      state[slug] ?? const CatalogInstallStatus();

  /// Installs [entry] together with everything it declares in
  /// [CatalogEntry.requires], dependencies first. A required slug missing from
  /// the manifest is skipped — the link simply dangles, matching the soft-ref
  /// rule that a missing target is a warning, never a failure.
  Future<bool> install(CatalogEntry entry) async {
    if (statusFor(entry.slug).phase == CatalogInstallPhase.installing) {
      return false;
    }
    if (entry.requires.isNotEmpty) {
      final catalog =
          await _ref.read(firstPartyCatalogProvider.future);
      final bySlug = {for (final e in catalog) e.slug: e};
      final order = <CatalogEntry>[];
      final emitted = <String>{};
      final visiting = <String>{};

      // Post-order DFS, cycle-safe — mirrors PackageLinkService.closure.
      void walk(CatalogEntry node) {
        if (emitted.contains(node.slug)) return;
        if (!visiting.add(node.slug)) return;
        for (final slug in node.requires) {
          final dep = bySlug[slug];
          if (dep != null && dep.slug != node.slug) walk(dep);
        }
        visiting.remove(node.slug);
        if (emitted.add(node.slug)) order.add(node);
      }

      walk(entry);
      for (final dep in order) {
        if (dep.slug == entry.slug) continue;
        if (statusFor(dep.slug).phase == CatalogInstallPhase.done) continue;
        final ok = await _installOne(dep);
        if (!ok) return false; // a missing dependency fails the whole install
      }
    }
    return _installOne(entry);
  }

  Future<bool> _installOne(CatalogEntry entry) async {
    _set(entry.slug,
        const CatalogInstallStatus(phase: CatalogInstallPhase.installing));
    try {
      final service = _ref.read(firstPartyCatalogServiceProvider);
      final payload = await service.fetchPayload(entry);
      final importer =
          PackagePayloadImporter(_ref.read(packageRepositoryProvider));

      // Also install the card banner: download from R2 and materialise it as
      // the local package cover so the Packages tab shows the same art.
      final extra = <String, dynamic>{'catalog_version': entry.version};
      final bannerBytes = await service.fetchBanner(entry.slug);
      if (bannerBytes != null) {
        final coverPath = await CoverImageBundler.restore(
          metadata: {
            'cover_image_data': base64Encode(bannerBytes),
            'cover_image_ext': '.jpg',
          },
          destDir: AppPaths.packagesDir,
          itemId: entry.slug,
        );
        if (coverPath != null) extra['cover_image_path'] = coverPath;
      }

      await importer.install(
        payload,
        installedFrom: 'official',
        extraMetadata: extra,
      );
      _ref.invalidate(packageListProvider);
      // Re-read metadata so a reinstall flips the stored `catalog_version` the
      // update check reads (D2) — the family is invalidated whole because the
      // row is keyed by title, which only the importer resolves.
      _ref.invalidate(packageMetadataProvider);
      _set(entry.slug,
          const CatalogInstallStatus(phase: CatalogInstallPhase.done));
      return true;
    } catch (e) {
      _set(
        entry.slug,
        CatalogInstallStatus(
            phase: CatalogInstallPhase.error, message: e.toString()),
      );
      return false;
    }
  }

  void _set(String slug, CatalogInstallStatus status) {
    state = {...state, slug: status};
  }
}

final firstPartyInstallProvider = StateNotifierProvider<
    FirstPartyInstallNotifier, Map<String, CatalogInstallStatus>>(
  (ref) => FirstPartyInstallNotifier(ref),
);
