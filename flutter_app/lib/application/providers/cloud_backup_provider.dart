import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../core/config/supabase_config.dart';
import '../services/cover_image_bundler.dart';
import '../../core/utils/error_format.dart';
import '../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../data/network/network_providers.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/cloud_backup_meta.dart';
import '../../domain/exceptions/cloud_backup_exceptions.dart';
import '../../domain/repositories/cloud_backup_repository.dart';
import '../services/media_bundler.dart';
import '../services/media_manifest_restorer.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'cloud_remote_check_provider.dart';
import 'package_provider.dart';
import 'save_state_provider.dart';

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

final cloudBackupPackagesProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref.read(cloudBackupRepositoryProvider).listBackupsByType('package');
});

final cloudBackupCharactersProvider =
    FutureProvider<List<CloudBackupMeta>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return [];
  return ref
      .read(cloudBackupRepositoryProvider)
      .listBackupsByType('character');
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
      final raw =
          await _ref.read(campaignRepositoryProvider).load(campaignName);
      final campaignId = raw['world_id'] as String? ?? '';

      final data = await _bundleWorldMediaIfPossible(
        worldName: campaignName,
        worldId: campaignId,
        data: raw,
      );
      await _bundleMetadataCover(data);

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
      state = CloudBackupOperationState.error(formatError(e));
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
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    } on CloudBackupQuotaExceededException catch (e) {
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    }
  }

  /// Belirli bir kampanyayi ismiyle cloud'a yedekle.
  Future<bool> uploadCampaign(String campaignName, {String? notes}) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final raw =
          await _ref.read(campaignRepositoryProvider).load(campaignName);
      final campaignId = raw['world_id'] as String? ?? '';

      final data = await _bundleWorldMediaIfPossible(
        worldName: campaignName,
        worldId: campaignId,
        data: raw,
      );
      await _bundleMetadataCover(data);

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
      state = CloudBackupOperationState.error(formatError(e));
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
          // Restore metadata cover image to local path.
          await _restoreMetadataCover(
              data, AppPaths.worldsDir, meta.itemId);
          await _ref.read(campaignRepositoryProvider).save(finalName, data);
          await _restoreWorldMediaIfPossible(
            worldName: finalName,
            data: data,
          );
          _ref.invalidate(campaignListProvider);
          _ref.invalidate(campaignInfoListProvider);

        case 'package':
          await _restoreMetadataCover(
              data, AppPaths.packagesDir, meta.itemId);
          await _ref.read(packageRepositoryProvider).save(name, data);
          _ref.invalidate(packageListProvider);

        case 'character':
          final charJson = Map<String, dynamic>.from(
            data['character'] as Map<String, dynamic>? ?? data,
          );
          var character = Character.fromJson(charJson);
          // Restore bundled cover image if present.
          final coverB64 = data['cover_image_data'] as String?;
          final coverExt = (data['cover_image_ext'] as String?) ?? '.png';
          if (coverB64 != null && coverB64.isNotEmpty) {
            try {
              final dir = Directory(AppPaths.charactersDir);
              await dir.create(recursive: true);
              final file = File(p.join(dir.path, '${character.id}_cover$coverExt'));
              await file.writeAsBytes(base64Decode(coverB64));
              character = character.copyWith(
                entity: character.entity.copyWith(imagePath: file.path),
              );
            } catch (e) {
              debugPrint('Character cover restore skip: $e');
            }
          }
          await _ref
              .read(characterRepositoryProvider)
              .save(character);
          await _ref.read(characterListProvider.notifier).refresh();
      }

      // Successful restore — we're caught up with what's on remote.
      _ref.read(cloudRemoteHasNewerProvider.notifier).markCaughtUp();

      state = const CloudBackupOperationState.success();
      return true;
    } catch (e, st) {
      debugPrint('Cloud backup restore error: $e\n$st');
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    }
  }

  /// Karakteri cloud'a yedekle.
  Future<bool> uploadCharacter(Character character, {String? notes}) async {
    state = const CloudBackupOperationState.busy(CloudBackupOpType.uploading);
    try {
      final envelope = <String, dynamic>{
        'character': character.toJson(),
      };
      // Bundle portrait (entity.imagePath) as base64.
      final portraitPath = character.entity.imagePath;
      if (portraitPath.isNotEmpty) {
        try {
          final file = File(portraitPath);
          if (await file.exists()) {
            envelope['cover_image_data'] = base64Encode(await file.readAsBytes());
            envelope['cover_image_ext'] = p.extension(portraitPath);
          }
        } catch (e) {
          debugPrint('Character cover bundle skip: $e');
        }
      }
      final meta =
          await _ref.read(cloudBackupRepositoryProvider).uploadBackup(
                character.entity.name,
                character.id,
                'character',
                envelope,
                notes: notes,
              );
      _invalidateLists();
      state = CloudBackupOperationState.success(meta: meta);
      return true;
    } on CloudBackupSizeLimitException catch (e) {
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    } on CloudBackupQuotaExceededException catch (e) {
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    } catch (e, st) {
      debugPrint('Cloud backup upload error: $e\n$st');
      state = CloudBackupOperationState.error(formatError(e));
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
      await _bundleMetadataCover(data);

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
      state = CloudBackupOperationState.error(formatError(e));
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
      state = CloudBackupOperationState.error(formatError(e));
      return false;
    }
  }

  /// `data['metadata']['cover_image_path']` içindeki yerel dosyayı base64
  /// olarak aynı metadata map'ine gömer. Worlds / Packages için.
  /// WorldSchema template için uploadTemplate ayrı handle ediyor.
  Future<void> _bundleMetadataCover(Map<String, dynamic> data) async {
    final meta = data['metadata'];
    if (meta is! Map) return;
    final mutable = Map<String, dynamic>.from(meta);
    await CoverImageBundler.bundle(mutable);
    data['metadata'] = mutable;
  }

  /// Restore counterpart — base64'i decode edip [destDir]'e yazar.
  Future<void> _restoreMetadataCover(
      Map<String, dynamic> data, String destDir, String itemId) async {
    final meta = data['metadata'];
    if (meta is! Map) return;
    final mutable = Map<String, dynamic>.from(meta);
    await CoverImageBundler.restore(
      metadata: mutable,
      destDir: destDir,
      itemId: itemId,
    );
    data['metadata'] = mutable;
  }

  /// Walk [data] for local-path media and upload every file to R2 before
  /// the world JSON is serialised into the backup envelope. Mutates nothing
  /// — returns a new `data` map with rewritten entity refs and a
  /// `media_manifest` block. No-ops (returns [data] untouched) when
  /// AssetService is offline.
  Future<Map<String, dynamic>> _bundleWorldMediaIfPossible({
    required String worldName,
    required String worldId,
    required Map<String, dynamic> data,
  }) async {
    final svc = _ref.read(assetServiceProvider);
    if (svc == null) return data;
    try {
      final result = await MediaBundler(svc).bundleWorldMedia(
        worldName: worldName,
        worldId: worldId,
        data: data,
      );
      if (result.failures.isNotEmpty) {
        debugPrint(
          'media_bundler partial: ${result.failures.length} file(s) failed '
          'to upload — ${result.failures.take(3).join(', ')}',
        );
      }
      return result.data;
    } catch (e, st) {
      // Media upload failure must not block the world backup itself.
      debugPrint('media_bundler error: $e\n$st');
      return data;
    }
  }

  /// After a world backup is written to disk, mirror every manifest entry
  /// into `{worldsDir}/{worldName}/media/` so local render + gallery work
  /// without waiting for per-entity downloads.
  Future<void> _restoreWorldMediaIfPossible({
    required String worldName,
    required Map<String, dynamic> data,
  }) async {
    final svc = _ref.read(assetServiceProvider);
    if (svc == null) return;
    final manifest = data['media_manifest'] as List?;
    if (manifest == null || manifest.isEmpty) return;
    try {
      final result = await MediaManifestRestorer(svc).restore(
        worldName: worldName,
        manifest: manifest,
      );
      if (result.failures.isNotEmpty) {
        debugPrint(
          'media_restore partial: ${result.failures.length} file(s) failed '
          '— ${result.failures.take(3).join(', ')}',
        );
      }
    } catch (e, st) {
      debugPrint('media_restore error: $e\n$st');
    }
  }

  void reset() => state = const CloudBackupOperationState.idle();

  void _invalidateLists() {
    _ref.invalidate(cloudBackupListProvider);
    _ref.invalidate(cloudBackupWorldsProvider);
    _ref.invalidate(cloudBackupPackagesProvider);
    _ref.invalidate(cloudBackupCharactersProvider);
    _ref.invalidate(cloudStorageUsedProvider);
    // Own upload/delete — by definition we're caught up with remote, so
    // clear the multi-device "someone else pushed" hint immediately. Without
    // this, the Settings tab shows a dot right after the user's own push
    // because next refresh() sees remote_latest > last_seen.
    _ref.read(cloudRemoteHasNewerProvider.notifier).markCaughtUp();
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
