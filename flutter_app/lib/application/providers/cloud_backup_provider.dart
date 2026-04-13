import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../../domain/entities/cloud_backup_meta.dart';
import '../../domain/exceptions/cloud_backup_exceptions.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/repositories/cloud_backup_repository.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart';
import 'package_provider.dart';
import 'save_state_provider.dart';
import 'template_provider.dart';

// ── Repository ──────────────────────────────────────────────────────

final cloudBackupRepositoryProvider = Provider<CloudBackupRepository>((ref) {
  return CloudBackupRepositoryImpl(
    CloudBackupRemoteDataSource(),
    quota: () => ref.read(betaProvider).quotaBytes,
  );
});

// ── Backup lists ────────────────────────────────────────────────────

/// Kullanicinin tum cloud backup listesi. Auth yoksa bos liste doner.
final cloudBackupListProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref.read(cloudBackupRepositoryProvider).listBackups();
});

/// Tip bazli cloud backup listeleri.
final cloudBackupWorldsProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref.read(cloudBackupRepositoryProvider).listBackupsByType('world');
});

final cloudBackupTemplatesProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref.read(cloudBackupRepositoryProvider).listBackupsByType('template');
});

final cloudBackupPackagesProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref.read(cloudBackupRepositoryProvider).listBackupsByType('package');
});

/// Kullanicinin toplam cloud storage kullanimi (bytes).
final cloudStorageUsedProvider = FutureProvider<int>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return 0;
  return ref.read(cloudBackupRepositoryProvider).getTotalStorageUsed();
});

// ── Operation state machine ─────────────────────────────────────────

enum CloudBackupOpType { idle, uploading, downloading, deleting }

class CloudBackupOperationState {
  final CloudBackupOpType type;
  final String? errorMessage;
  final CloudBackupMeta? result;

  const CloudBackupOperationState._({
    this.type = CloudBackupOpType.idle,
    this.errorMessage,
    this.result,
  });

  const CloudBackupOperationState.idle() : this._();

  const CloudBackupOperationState.busy(CloudBackupOpType type)
      : this._(type: type);

  const CloudBackupOperationState.success({CloudBackupMeta? meta})
      : this._(type: CloudBackupOpType.idle, result: meta);

  const CloudBackupOperationState.error(String message)
      : this._(type: CloudBackupOpType.idle, errorMessage: message);

  bool get isBusy => type != CloudBackupOpType.idle;
}

class CloudBackupOperationNotifier
    extends StateNotifier<CloudBackupOperationState> {
  final Ref _ref;

  CloudBackupOperationNotifier(this._ref)
      : super(const CloudBackupOperationState.idle());

  /// Aktif kampanyayi cloud'a yedekle.
  Future<bool> uploadCurrentCampaign({String? notes}) async {
    final campaignName = _ref.read(activeCampaignProvider);
    if (campaignName == null) return false;

    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      await _ref.read(saveStateProvider.notifier).saveNow();
      final data =
          await _ref.read(campaignRepositoryProvider).load(campaignName);
      final campaignId = data['world_id'] as String? ?? '';

      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                campaignName,
                campaignId,
                'world',
                data,
                notes: notes,
              );

      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Belirli bir item'i cloud'a yedekle.
  Future<bool> uploadItem({
    required String itemName,
    required String itemId,
    required String type,
    required Map<String, dynamic> data,
    String? notes,
  }) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                itemName,
                itemId,
                type,
                data,
                notes: notes,
              );

      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } on CloudBackupSizeLimitException catch (e) {
      state = CloudBackupOperationState.error(e.toString());
      return false;
    } on CloudBackupQuotaExceededException catch (e) {
      state = CloudBackupOperationState.error(e.toString());
      return false;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Belirli bir kampanyayi ismiyle cloud'a yedekle.
  Future<bool> uploadCampaign(String campaignName, {String? notes}) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final data =
          await _ref.read(campaignRepositoryProvider).load(campaignName);
      final campaignId = data['world_id'] as String? ?? '';

      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                campaignName,
                campaignId,
                'world',
                data,
                notes: notes,
              );

      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Cloud backup'i indirip yerel'e kaydet.
  Future<bool> restoreBackup(CloudBackupMeta meta,
      {String? restoreName}) async {
    state =
        const CloudBackupOperationState.busy(CloudBackupOpType.downloading);
    try {
      final data = await _ref
          .read(cloudBackupRepositoryProvider)
          .downloadBackup(meta.id);

      final name = restoreName ?? meta.itemName;

      switch (meta.type) {
        case 'world':
          final existing =
              await _ref.read(campaignRepositoryProvider).getAvailable();
          final finalName = existing.contains(name) && restoreName == null
              ? _findUniqueName(name, existing)
              : name;
          await _ref.read(campaignRepositoryProvider).save(finalName, data);
          _ref.invalidate(campaignListProvider);
          _ref.invalidate(campaignInfoListProvider);

        case 'template':
          final schema = WorldSchema.fromJson(
              data['world_schema'] as Map<String, dynamic>? ?? data);
          await _ref.read(templateLocalDsProvider).save(schema);
          _ref.invalidate(allTemplatesProvider);
          _ref.invalidate(customTemplatesProvider);
          _ref.invalidate(builtinTemplateProvider);

        case 'package':
          await _ref.read(packageRepositoryProvider).save(name, data);
          _ref.invalidate(packageListProvider);
      }

      state = const CloudBackupOperationState.success();
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup restore error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Template'i cloud'a yedekle.
  Future<bool> uploadTemplate(WorldSchema schema, {String? notes}) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final data = schema.toJson();
      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                schema.name,
                schema.schemaId,
                'template',
                {'world_schema': data},
                notes: notes,
              );

      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Package'i cloud'a yedekle.
  Future<bool> uploadPackage(String packageName, {String? notes}) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final data =
          await _ref.read(packageRepositoryProvider).load(packageName);
      final packageId = data['package_id'] as String? ??
          data['world_id'] as String? ?? packageName;

      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                packageName,
                packageId,
                'package',
                data,
                notes: notes,
              );

      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  /// Item ID + type kombinasyonuna gore cloud backup'i sil.
  /// Local silme sonrasi otomatik temizlik icin kullanilir.
  /// Auth yoksa veya Supabase yoksa no-op.
  Future<void> deleteBackupByItem(String itemId, String type) async {
    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) {
      return;
    }
    try {
      await _ref
          .read(cloudBackupRepositoryProvider)
          .deleteBackupByItem(itemId, type);
      _invalidateLists();
    } catch (e, st) {
      // Silinme hatasi kritik degil — local silme zaten basarili olmus olabilir.
      debugPrint('Cloud backup cleanup error ($type:$itemId): $e\n$st');
    }
  }

  /// Cloud backup'i sil.
  Future<bool> deleteBackup(String backupId) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.deleting);
    try {
      await _ref.read(cloudBackupRepositoryProvider).deleteBackup(backupId);
      _invalidateLists();
      state = const CloudBackupOperationState.success();
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup delete error: $e\n$st');
      state = CloudBackupOperationState.error(e.toString());
      return false;
    }
  }

  void reset() => state = const CloudBackupOperationState.idle();

  void _invalidateLists() {
    _ref.invalidate(cloudBackupListProvider);
    _ref.invalidate(cloudBackupWorldsProvider);
    _ref.invalidate(cloudBackupTemplatesProvider);
    _ref.invalidate(cloudBackupPackagesProvider);
    _ref.invalidate(cloudStorageUsedProvider);
  }

  String _findUniqueName(String base, List<String> existing) {
    var counter = 1;
    var candidate = '$base (cloud $counter)';
    while (existing.contains(candidate)) {
      counter++;
      candidate = '$base (cloud $counter)';
    }
    return candidate;
  }
}

final cloudBackupOperationProvider = StateNotifierProvider<
    CloudBackupOperationNotifier, CloudBackupOperationState>(
  (ref) => CloudBackupOperationNotifier(ref),
);
