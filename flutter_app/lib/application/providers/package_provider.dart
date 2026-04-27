import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/deep_copy.dart';
import '../../data/database/app_database.dart' show InstalledPackagesCompanion;
import '../../data/database/database_provider.dart';
import '../../data/datasources/local/package_local_ds.dart';
import '../../data/repositories/package_repository_impl.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/package_repository.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../services/package_import_service.dart';
import '../services/package_sync_service.dart';
import '../services/srd_core_package_bootstrap.dart';
import 'campaign_provider.dart'
    show activeCampaignProvider, campaignRevisionProvider;

final packageLocalDsProvider = Provider((_) => PackageLocalDataSource());

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.read(packageLocalDsProvider),
  ),
);

/// Built-in SRD content pack auto-install gate. Runs once per app session;
/// materialises the hand-authored SRD 5.2.1 pack as a real Packages row so
/// the Packages tab can list it like any user package.
final srdCorePackageBootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await SrdCorePackageBootstrap(db).ensureInstalled();
});

/// Live-link sync for the active campaign. After SRD pack refresh, walks
/// `installed_packages` rows for the campaign and applies each pack's
/// current state to linked entities (add/update/remove). Runs once per
/// (campaign, app session) — campaign switches re-trigger.
final activeCampaignSyncProvider = FutureProvider<int>((ref) async {
  await ref.watch(srdCorePackageBootstrapProvider.future);
  final campaign = ref.watch(activeCampaignProvider);
  if (campaign == null) return 0;
  final db = ref.read(appDatabaseProvider);
  final notifier = ref.read(activeCampaignProvider.notifier);
  final campaignId = notifier.data?['world_id'] as String?;
  if (campaignId == null) return 0;

  // Migrate orphans: campaigns created before installed_packages existed
  // may have entities with packageId set but no matching install row.
  // Detect those and create install rows so sync can repair them (e.g.
  // rewrite spell.class_refs from pack-side UUIDs to campaign-side).
  final installedNow =
      await db.installedPackageDao.listForCampaign(campaignId);
  final installedIds = installedNow.map((r) => r.packageId).toSet();
  final orphanRows = await (db.select(db.entities)
        ..where((t) =>
            t.campaignId.equals(campaignId) & t.packageId.isNotNull()))
      .get();
  final orphanPackageIds = <String>{};
  for (final row in orphanRows) {
    final pid = row.packageId;
    if (pid != null && !installedIds.contains(pid)) {
      orphanPackageIds.add(pid);
    }
  }
  for (final pid in orphanPackageIds) {
    final pkg = await db.packageDao.getById(pid);
    await db.installedPackageDao.upsert(InstalledPackagesCompanion.insert(
      campaignId: campaignId,
      packageId: pid,
      packageName: Value(pkg?.name ?? ''),
    ));
  }

  final installed =
      await db.installedPackageDao.listForCampaign(campaignId);
  if (installed.isEmpty) return 0;

  // Build Tier-0 (slug,name) → uuid index from the destination campaign so
  // pack-side `_lookup` placeholders resolve to this campaign's IDs.
  final build = generateBuiltinDnd5eV2Schema();
  final tier0Slugs = build.seedRows.keys.toSet();
  final tier0Rows = await (db.select(db.entities)
        ..where((t) =>
            t.campaignId.equals(campaignId) &
            t.categorySlug.isIn(tier0Slugs)))
      .get();
  final tier0Index = <String, Map<String, String>>{};
  for (final row in tier0Rows) {
    tier0Index
        .putIfAbsent(row.categorySlug, () => <String, String>{})[row.name] =
        row.id;
  }
  Map<String, dynamic> resolveAttrs(Map<String, dynamic> attrs) {
    return PackageImportService.resolveLookupPlaceholder(attrs, tier0Index)
        as Map<String, dynamic>;
  }

  final sync = PackageSyncService(db);
  var total = 0;
  for (final pkg in installed) {
    final result = await sync.sync(
      campaignId: campaignId,
      packageId: pkg.packageId,
      resolveAttrs: resolveAttrs,
    );
    total += result.total;
  }
  if (total > 0) {
    // Reload campaign so the entity provider picks up the synced rows.
    await notifier.reload();
  }
  return total;
});

/// Paket listesi — hub ekranında gösterim için.
/// SRD content pack startup'ta install edilir, sonra listing fetch edilir.
final packageListProvider = FutureProvider<List<PackageInfo>>((ref) async {
  await ref.watch(srdCorePackageBootstrapProvider.future);
  return ref.watch(packageRepositoryProvider).getPackageInfoList();
});

/// Per-package metadata lookup — cover / description / tags için.
final packageMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, packageName) async {
  try {
    final data = await ref.read(packageRepositoryProvider).load(packageName);
    final meta = data['metadata'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Package metadata writer — sadece metadata'yı değiştirir.
Future<void> updatePackageMetadata(
  WidgetRef ref,
  String packageName,
  Map<String, dynamic> newMetadata,
) async {
  final repo = ref.read(packageRepositoryProvider);
  final data = await repo.load(packageName);
  data['metadata'] = newMetadata;
  await repo.save(packageName, data);
  ref.invalidate(packageMetadataProvider(packageName));
  ref.invalidate(packageListProvider);
}

/// Aktif paket adı. null = henüz seçilmedi.
class ActivePackageNotifier extends StateNotifier<String?> {
  final PackageRepository _repo;
  final Ref _ref;

  ActivePackageNotifier(this._repo, this._ref) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  Future<bool> load(String name) async {
    try {
      _data = await _repo.load(name);
      state = name;
      return true;
    } catch (e, st) {
      debugPrint('Package load error: $e\n$st');
      return false;
    }
  }

  Future<bool> create(String packageName, {WorldSchema? template}) async {
    try {
      await _repo.create(packageName, template: template);
      return load(packageName);
    } catch (e, st) {
      debugPrint('Package create error: $e\n$st');
      return false;
    }
  }

  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  /// Replaces the in-memory package data with [newData] and persists
  /// it. Mirrors [ActiveCampaignNotifier.replaceWithData]; used by the
  /// cloud "restore into the open item" flow to overwrite the running
  /// package session with fresh downloaded content.
  Future<void> replaceWithData(Map<String, dynamic> newData) async {
    if (state == null) return;
    final name = state!;
    if (_data == null) {
      _data = Map<String, dynamic>.from(newData);
    } else {
      _data!
        ..clear()
        ..addAll(newData);
    }
    await _repo.save(name, _data!);
    _bumpRevision();
  }

  void _bumpRevision() {
    final notifier = _ref.read(campaignRevisionProvider.notifier);
    notifier.state = notifier.state + 1;
  }

  Future<void> delete(String packageName) async {
    await _repo.delete(packageName);
    if (state == packageName) {
      _data = null;
      state = null;
    }
  }

  /// Applies a template update to the active package (mirrors campaign logic).
  Future<void> applyTemplateUpdate(WorldSchema newTemplate) async {
    if (state == null || _data == null) return;
    final currentHash = computeWorldSchemaContentHash(newTemplate);
    _data!['world_schema'] = deepCopyJson(newTemplate.toJson());
    _data!['template_id'] = newTemplate.schemaId;
    _data!['template_hash'] = currentHash;
    if (newTemplate.originalHash != null) {
      _data!['template_original_hash'] = newTemplate.originalHash;
    }
    _data!.remove('template_dismissed_hash');
    _data!.remove('template_updates_muted');
    await _repo.save(state!, _data!);
    _bumpRevision();
  }

  /// Dismisses a specific template version for the active package.
  Future<void> dismissTemplateUpdate(String templateHash) async {
    if (state == null || _data == null) return;
    _data!['template_dismissed_hash'] = templateHash;
    await _repo.save(state!, _data!);
  }

  /// Permanently mutes template update prompts for the active package.
  Future<void> muteTemplateUpdates() async {
    if (state == null || _data == null) return;
    _data!['template_updates_muted'] = true;
    await _repo.save(state!, _data!);
  }
}

final activePackageProvider =
    StateNotifierProvider<ActivePackageNotifier, String?>((ref) {
  return ActivePackageNotifier(ref.watch(packageRepositoryProvider), ref);
});
