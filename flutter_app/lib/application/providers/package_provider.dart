import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/deep_copy.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/package_repository_impl.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/package_repository.dart';
import '../services/entity_media_cleanup_service.dart';
import '../services/marketplace_cleanup_service.dart';
import '../services/pending_write_buffer.dart';
import '../services/srd_core_package_bootstrap.dart';
import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart' show campaignRevisionProvider;
import 'cloud_backup_provider.dart';
import 'personal_online_provider.dart';
import 'sync_engine_provider.dart';
import 'world_mirror_provider.dart';

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// Built-in SRD content pack auto-install gate. Runs once per app session;
/// materialises the hand-authored SRD 5.2.1 pack as a real Packages row so
/// the Packages tab can list it like any user package.
final srdCorePackageBootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await SrdCorePackageBootstrap(db).ensureInstalled();
});

/// Otomatik SRD pack live-link auto-apply kaldırıldı (manuel save/sync
/// modeli). Provider mevcut callsite'ları break etmesin diye no-op olarak
/// duruyor; kullanıcı paketleri açıkça apply etmek isterse hub'da ayrı bir
/// aksiyon eklenecek (out of scope).
final activeCampaignSyncProvider = FutureProvider<int>((ref) async {
  return 0;
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
  // Kapak değiştirildiyse eski cloud resmini silmek için eski ref'i
  // overwrite'tan ÖNCE yakala.
  String? oldCover;
  final prevMeta = data['metadata'];
  if (prevMeta is Map) oldCover = prevMeta['cover_image_path'] as String?;
  data['metadata'] = newMetadata;
  await repo.save(packageName, data);
  ref.invalidate(packageMetadataProvider(packageName));
  ref.invalidate(packageListProvider);

  // Kapak değiştiyse eski cloud resmini best-effort sil.
  if (ref.read(authProvider) != null) {
    final cleanup = ref.read(entityMediaCleanupServiceProvider);
    if (cleanup != null) {
      // ignore: discarded_futures
      cleanup
          .cleanupReplacedRef(
            oldRef: oldCover,
            newRef: newMetadata['cover_image_path'] as String?,
          )
          .catchError(
            (Object e) => debugPrint('package cover cleanup error: $e'),
          );
    }
  }
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
      // ignore: discarded_futures
      _pullIfCloudNewer();
      return true;
    } catch (e, st) {
      debugPrint('Package load error: $e\n$st');
      return false;
    }
  }

  /// On open: if cloud_backup of this package is newer than the row we just
  /// loaded from disk, download + replace in place. Best-effort.
  Future<void> _pullIfCloudNewer() async {
    if (!SupabaseConfig.isConfigured) return;
    if (_ref.read(authProvider) == null) return;
    if (!_ref.read(isBetaActiveProvider)) return;
    final data = _data;
    final name = state;
    if (data == null || name == null) return;
    final packageId = (data['package_id'] as String?) ??
        (data['world_id'] as String?) ??
        name;
    final localUpdatedRaw = data['last_modified'] ?? data['updated_at'];
    final localUpdated = localUpdatedRaw is String
        ? DateTime.tryParse(localUpdatedRaw)
        : null;
    try {
      final repo = _ref.read(cloudBackupRepositoryProvider);
      final meta = await repo.fetchByItem(packageId, 'package');
      if (meta == null) return;
      if (localUpdated != null && !meta.createdAt.isAfter(localUpdated)) return;
      final fresh = await repo.downloadBackup(meta.id);
      await _replaceWithData(fresh);
    } catch (e) {
      debugPrint('Package cloud-pull error: $e');
    }
  }

  Future<void> _replaceWithData(Map<String, dynamic> newData) async {
    final name = state;
    if (name == null) return;
    if (_data == null) {
      _data = Map<String, dynamic>.from(newData);
    } else {
      _data!
        ..clear()
        ..addAll(newData);
    }
    await _repo.save(name, _data!);
    // Bump revision so widgets re-read campaign-bound providers.
    final notifier = _ref.read(campaignRevisionProvider.notifier);
    notifier.state = notifier.state + 1;
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

  /// F6: `pushMirror` param retired — entity edits push row-level via
  /// outbox (see [saveEntity]/[deleteEntity]). This bulk save remains
  /// for cloud restore / trash safety nets.
  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  /// F5 row-level: single-entity write inside the active personal package.
  /// Debounced via PendingWriteBuffer ([kind] caller'a göre). Built-in
  /// pack repository guard'ından geçer. Online'sa per-entity outbox row
  /// enqueue eder (same coalesced semantics).
  Future<void> saveEntity(String entityId, Map<String, dynamic> row,
      {WriteKind kind = WriteKind.shortText}) async {
    final name = state;
    if (name == null) return;
    final onlineNames = _ref.read(personalOnlinePackageNamesProvider);
    final shouldEnqueue =
        _ref.read(authProvider) != null && onlineNames.contains(name);
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'pkg_entity:$name:$entityId',
          kind: kind,
          action: () async {
            await _repo.saveEntity(name, entityId, row);
            if (shouldEnqueue) {
              await _ref
                  .read(syncEngineProvider)
                  .enqueuePersonalPackageEntityUpsert(
                    packageName: name,
                    entityId: entityId,
                    entityMap: row,
                  );
            }
          },
        );
  }

  Future<void> deleteEntity(String entityId) async {
    final name = state;
    if (name == null) return;
    final onlineNames = _ref.read(personalOnlinePackageNamesProvider);
    final shouldEnqueue =
        _ref.read(authProvider) != null && onlineNames.contains(name);
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'pkg_entity:$name:$entityId',
          kind: WriteKind.immediate,
          action: () async {
            await _repo.deleteEntity(name, entityId);
            if (shouldEnqueue) {
              await _ref
                  .read(syncEngineProvider)
                  .enqueuePersonalPackageEntityDelete(
                    packageName: name,
                    entityId: entityId,
                  );
            }
          },
        );
  }

  /// F5: schema/metadata patch (rarely fires — template update, marketplace
  /// fields, etc.). Cloud still gets the legacy full `state_json` blob via
  /// [_mirrorPushPersonal] because schema isn't row-level.
  Future<void> saveStatePatch(Map<String, dynamic> patch,
      {WriteKind kind = WriteKind.shortText}) async {
    final name = state;
    if (name == null) return;
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'pkg_state:$name',
          kind: kind,
          action: () async {
            await _repo.saveStatePatch(name, patch);
            _mirrorPushPersonal();
          },
        );
  }

  /// Aktif paket "Make Online" yapıldıysa `personal_packages`'a push eder.
  /// Offline'sa no-op (RLS gürültüsü olmaz).
  void _mirrorPushPersonal() {
    final name = state;
    final data = _data;
    if (name == null || data == null) return;
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    final onlineNames = _ref.read(personalOnlinePackageNamesProvider);
    if (!onlineNames.contains(name)) return;
    // Fire-and-forget — push errors are logged inside the service. The
    // outbox path is the source of retries; this direct push is just an
    // auto-mirror hook on save.
    // ignore: discarded_futures
    mirror.pushPersonalPackage(packageName: name, state: data).catchError(
          (Object e) => debugPrint('_mirrorPushPersonal swallow: $e'),
        );
  }

  /// "Make Online" — aktif paketi `personal_packages`'a publish eder ve
  /// online listesine ekler. Bundan sonra her `save()` otomatik sync olur.
  Future<void> makeOnline() async {
    final name = state;
    final data = _data;
    if (name == null || data == null) {
      throw StateError('No package open.');
    }
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) {
      throw StateError('Sign in and configure Supabase to enable sync.');
    }
    await mirror.pushPersonalPackage(packageName: name, state: data);
    _ref
        .read(personalOnlinePackageNamesProvider.notifier)
        .add(name);
  }

  /// "Make Offline" — bulut kopyayı kaldırır. Local paket dosyası kalır.
  Future<void> makeOffline() async {
    final name = state;
    if (name == null) return;
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    await mirror.unpublishPersonalPackage(name);
    _ref
        .read(personalOnlinePackageNamesProvider.notifier)
        .remove(name);
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
    _mirrorPushPersonal();
    _bumpRevision();
  }

  void _bumpRevision() {
    final notifier = _ref.read(campaignRevisionProvider.notifier);
    notifier.state = notifier.state + 1;
  }

  Future<void> delete(String packageName) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    final onlineNames = _ref.read(personalOnlinePackageNamesProvider);
    final wasOnline = onlineNames.contains(packageName);
    // Resolve the cloud_backup item_id before the row is wiped — convention
    // matches manual_backup_provider: prefer `package_id`, then `world_id`,
    // fallback to package name.
    String backupItemId = packageName;
    try {
      final preDeleteData = state == packageName && _data != null
          ? _data
          : await _repo.load(packageName);
      if (preDeleteData != null) {
        backupItemId = (preDeleteData['package_id'] as String?) ??
            (preDeleteData['world_id'] as String?) ??
            packageName;
      }
    } catch (e) {
      debugPrint('package delete pre-load error: $e');
    }
    await _repo.delete(packageName);
    if (state == packageName) {
      _data = null;
      state = null;
    }
    if (wasOnline && mirror != null) {
      // Fire-and-forget — caller already removed the local row.
      // ignore: discarded_futures
      mirror.unpublishPersonalPackage(packageName).catchError(
            (Object e) =>
                debugPrint('package delete unpublish swallow: $e'),
          );
      _ref
          .read(personalOnlinePackageNamesProvider.notifier)
          .remove(packageName);
    }
    // Cloud-backup snapshot delete — best-effort via outbox so an offline
    // delete still drains on reconnect. Engine itself enforces the beta
    // gate before contacting Supabase.
    if (_ref.read(authProvider) != null) {
      try {
        await _ref.read(syncEngineProvider).enqueueCloudBackupDelete(
              itemId: backupItemId,
              type: 'package',
            );
      } catch (e) {
        debugPrint('package delete cloud_backup enqueue error: $e');
      }
    }

    // Best-effort: pakete bağlı cloud medyayı (kapak + entity resimleri)
    // temizler. Local cache korunur — trash'ten restore'da resim local kalır.
    if (_ref.read(authProvider) != null) {
      final cleanup = _ref.read(entityMediaCleanupServiceProvider);
      if (cleanup != null) {
        // ignore: discarded_futures
        cleanup.cleanupPackage(packageName: packageName).catchError(
              (Object e) => debugPrint('package media cleanup error: $e'),
            );
      }
      // Best-effort: bu paketten publish edilmiş marketplace listing'lerini sil.
      final mkt = _ref.read(marketplaceCleanupServiceProvider);
      if (mkt != null) {
        // ignore: discarded_futures
        mkt
            .cleanupItem(itemType: 'package', localId: packageName)
            .catchError(
              (Object e) =>
                  debugPrint('package marketplace cleanup error: $e'),
            );
      }
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
    _mirrorPushPersonal();
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
