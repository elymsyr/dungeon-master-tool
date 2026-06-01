import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/first_party_catalog_service.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../services/assets_pack_installer.dart';
import '../services/package_payload_importer.dart';
import 'package_provider.dart';

/// Long-lived catalog service (native HttpClient inside).
final firstPartyCatalogServiceProvider =
    Provider<FirstPartyCatalogService>((ref) => FirstPartyCatalogService());

/// Admin-only bundled-assets installer (Part 1 — dashboard toggle).
final assetsPackInstallerProvider = Provider<AssetsPackInstaller>(
    (ref) => AssetsPackInstaller(ref.read(packageRepositoryProvider)));

/// Official package catalog: R2 manifest → bundled fallback. The service
/// degrades to the bundled catalog when offline, so this never surfaces an
/// offline error — the cards render (and install from bundled assets) offline.
final firstPartyCatalogProvider = FutureProvider<List<CatalogEntry>>((ref) {
  return ref.read(firstPartyCatalogServiceProvider).fetchManifest();
});

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

  Future<bool> install(CatalogEntry entry) async {
    if (statusFor(entry.slug).phase == CatalogInstallPhase.installing) {
      return false;
    }
    _set(entry.slug,
        const CatalogInstallStatus(phase: CatalogInstallPhase.installing));
    try {
      final payload =
          await _ref.read(firstPartyCatalogServiceProvider).fetchPayload(entry);
      final importer =
          PackagePayloadImporter(_ref.read(packageRepositoryProvider));
      await importer.install(
        payload,
        installedFrom: 'official',
        extraMetadata: {'catalog_version': entry.version},
      );
      _ref.invalidate(packageListProvider);
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
