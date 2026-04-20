import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/dnd5e/package/conflict_resolution.dart';
import '../../domain/dnd5e/package/dnd5e_package_codec.dart';
import '../../domain/dnd5e/package/import_report.dart';
import '../dnd5e/package/bundled_srd_packages.dart';
import '../dnd5e/package/dnd5e_package_importer.dart';
import 'custom_effect_registry_provider.dart';

/// Resolves the installed-package row (if any) for the given bundled SRD
/// envelope. Null when not yet installed — UI shows "Install & Enable"
/// rather than a simple checkbox.
final installedPackageForBundleProvider =
    FutureProvider.family<InstalledPackage?, BundledSrdPackage>(
        (ref, bundle) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.installedPackages)
        ..where((t) => t.sourcePackageId.equals(bundle.sourcePackageId)))
      .getSingleOrNull();
});

/// Set of enabled installed-package ids for a campaign. Keyed by campaign id.
/// Stream so the world-create + settings dialogs both re-render on toggle.
final enabledPackageIdsForCampaignProvider =
    StreamProvider.family<Set<String>, String>((ref, campaignId) {
  final dao = ref.watch(appDatabaseProvider).dnd5eContentDao;
  return dao
      .watchEnabledPackageIdsForCampaign(campaignId)
      .map((ids) => ids.toSet());
});

/// Controller for installing bundled SRD envelopes + toggling them per
/// campaign. Kept off the `CampaignRepository` so world-create stays
/// decoupled from the D&D 5e importer.
class CampaignPackagesController {
  final Ref _ref;

  CampaignPackagesController(this._ref);

  /// Installs [bundle] if it's missing; returns the `installed_packages.id`.
  /// Idempotent — if already installed, just returns the existing id.
  Future<String> ensureInstalled(BundledSrdPackage bundle) async {
    final db = _ref.read(appDatabaseProvider);
    final existing = await (db.select(db.installedPackages)
          ..where((t) => t.sourcePackageId.equals(bundle.sourcePackageId)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final raw = await rootBundle.loadString(bundle.assetPath);
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    final expectedHash = json['contentHash'] as String?;
    final pkg = const Dnd5ePackageCodec().decode(json);

    final registry = _ref.read(customEffectRegistryProvider);
    final importer = Dnd5ePackageImporter(db, registry);
    final result = await importer.import(
      pkg,
      onConflict: ConflictResolution.overwrite,
      expectedContentHash: expectedHash,
    );
    switch (result) {
      case PackageImportError(:final message):
        throw StateError('Failed to install ${bundle.name}: $message');
      case PackageImportSuccess():
        final row = await (db.select(db.installedPackages)
              ..where((t) => t.sourcePackageId.equals(bundle.sourcePackageId)))
            .getSingleOrNull();
        if (row == null) {
          throw StateError(
              'Install of ${bundle.name} succeeded but no row visible');
        }
        return row.id;
    }
  }

  /// Enables [installedPackageId] in [campaignId]. Idempotent.
  Future<void> enable(String campaignId, String installedPackageId) =>
      _ref
          .read(appDatabaseProvider)
          .dnd5eContentDao
          .enablePackageInCampaign(campaignId, installedPackageId);

  /// Disables [installedPackageId] in [campaignId]. Content stays installed,
  /// just hidden in this world.
  Future<void> disable(String campaignId, String installedPackageId) => _ref
      .read(appDatabaseProvider)
      .dnd5eContentDao
      .disablePackageInCampaign(campaignId, installedPackageId);

  /// Convenience: install if missing, then enable in [campaignId].
  Future<String> ensureAndEnable(
      String campaignId, BundledSrdPackage bundle) async {
    final installedPackageId = await ensureInstalled(bundle);
    await enable(campaignId, installedPackageId);
    return installedPackageId;
  }

  /// Silently rewrites any lingering `installed_packages` row whose
  /// `sourcePackageId` is in [retiredBundledSourcePackageIds] (e.g.
  /// `srd-rules-1`, `srd-heroes-1` from the pre-merge split) onto the
  /// current Core `sourcePackageId`. Preserves all content rows — the
  /// primary-key `installedPackageId` is unchanged, only the outward-facing
  /// bundle id is renormalized so `installedPackageForBundleProvider(core)`
  /// finds them. Idempotent: no-op once no retired rows remain.
  Future<int> migrateRetiredBundles() async {
    final db = _ref.read(appDatabaseProvider);
    final rewritten = await (db.update(db.installedPackages)
          ..where((t) => t.sourcePackageId.isIn(retiredBundledSourcePackageIds)))
        .write(const InstalledPackagesCompanion(
      sourcePackageId: Value('srd-core-1'),
    ));
    if (rewritten > 0) {
      _ref.invalidate(installedPackageForBundleProvider);
    }
    return rewritten;
  }
}

final campaignPackagesControllerProvider =
    Provider<CampaignPackagesController>(
        (ref) => CampaignPackagesController(ref));
