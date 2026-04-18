import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/network_providers.dart';
import '../../domain/exceptions/cloud_backup_exceptions.dart';
import '../services/media_bundler.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart';
import 'cloud_backup_provider.dart';
import 'cloud_remote_check_provider.dart';
import 'package_provider.dart';

// ── Sync result types ───────────────────────────────────────────────

enum SyncResult { synced, pending, tooLarge, quotaExceeded, networkError }

class SyncItemResult {
  final String id;
  final String name;
  final String type;
  final SyncResult result;
  final String? message;

  const SyncItemResult({
    required this.id,
    required this.name,
    required this.type,
    required this.result,
    this.message,
  });
}

// ── Cloud sync state ────────────────────────────────────────────────

enum CloudSyncStatus { idle, pending, syncing, synced, error }

class CloudSyncState {
  final CloudSyncStatus status;
  final List<SyncItemResult> results;
  final DateTime? lastSyncAt;

  const CloudSyncState({
    this.status = CloudSyncStatus.idle,
    this.results = const [],
    this.lastSyncAt,
  });

  CloudSyncState copyWith({
    CloudSyncStatus? status,
    List<SyncItemResult>? results,
    DateTime? lastSyncAt,
  }) =>
      CloudSyncState(
        status: status ?? this.status,
        results: results ?? this.results,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );

  /// Sync edilememiş item sayısı.
  int get failedCount =>
      results.where((r) => r.result != SyncResult.synced).length;

  /// Bekleyen item sayısı.
  int get pendingCount =>
      results.where((r) => r.result == SyncResult.pending).length;
}

// ── Cloud sync notifier ─────────────────────────────────────────────

/// Auto cloud sync — local save'den sonra 30s debounce, 120s max delay.
/// Tüm dirty item'ları (world, template, package) toplar ve upload eder.
class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  final Ref _ref;
  Timer? _syncTimer;
  Timer? _maxDelayTimer;
  bool _disposed = false;

  static const _syncDelay = Duration(seconds: 30);
  static const _maxSyncDelay = Duration(seconds: 120);

  /// Dirty items: key = "$type:$id", value = (name, type, id)
  final Map<String, ({String name, String type, String id})> _dirtyItems = {};

  CloudSyncNotifier(this._ref) : super(const CloudSyncState());

  /// Local save sonrası çağrılır. Item'ı dirty olarak işaretle.
  void markDirty(String itemId, String itemName, String type) {
    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) return;
    // Beta-only gate: kullanıcı beta programında değilse cloud sync no-op.
    if (!_ref.read(betaProvider).isActive) return;

    final key = '$type:$itemId';
    _dirtyItems[key] = (name: itemName, type: type, id: itemId);

    state = state.copyWith(status: CloudSyncStatus.pending);
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDelay, _performSync);
    _maxDelayTimer ??= Timer(_maxSyncDelay, _performSync);
  }

  /// Manuel tetik. Pending dirty items varsa hemen upload eder.
  Future<void> syncNow() async {
    _syncTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    await _performSync();
  }

  /// Force-upload the currently active world or package, regardless of
  /// dirty state. Resolves the active item via providers, adds it to
  /// `_dirtyItems`, then runs the sync. Called by the user-facing
  /// "Backup to Cloud" action — which should work even when nothing has
  /// been marked dirty (e.g. when auto cloud save is disabled).
  ///
  /// Returns `true` when an active item was resolved and the sync ran;
  /// `false` when there is no active item to back up (caller should
  /// surface an "open something first" message).
  Future<bool> backupActiveItem() async {
    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) {
      return false;
    }
    if (!_ref.read(betaProvider).isActive) {
      // Caller (save_sync_indicator) false cevabini "beta gereklidir"
      // mesajiyla yorumlar.
      return false;
    }

    final campaignName = _ref.read(activeCampaignProvider);
    if (campaignName != null) {
      final data = _ref.read(activeCampaignProvider.notifier).data;
      if (data != null) {
        final worldId = data['world_id'] as String? ?? campaignName;
        _dirtyItems['world:$worldId'] =
            (name: campaignName, type: 'world', id: worldId);
        await syncNow();
        return true;
      }
    }

    final packageName = _ref.read(activePackageProvider);
    if (packageName != null) {
      final data = _ref.read(activePackageProvider.notifier).data;
      if (data != null) {
        final packageId = (data['package_id'] as String?) ??
            (data['world_id'] as String?) ??
            packageName;
        _dirtyItems['package:$packageId'] =
            (name: packageName, type: 'package', id: packageId);
        await syncNow();
        return true;
      }
    }

    return false;
  }

  Future<void> _performSync() async {
    if (_disposed || !mounted) return;
    _syncTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;

    if (_dirtyItems.isEmpty) {
      state = state.copyWith(status: CloudSyncStatus.idle);
      return;
    }

    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) {
      state = state.copyWith(status: CloudSyncStatus.idle);
      return;
    }

    state = state.copyWith(status: CloudSyncStatus.syncing);

    final items = Map.of(_dirtyItems);
    _dirtyItems.clear();

    final results = <SyncItemResult>[];
    final repo = _ref.read(cloudBackupRepositoryProvider);

    for (final entry in items.entries) {
      final item = entry.value;
      try {
        final raw = await _loadItemData(item.name, item.type);
        if (raw == null) continue;

        // World backups must bundle the media gallery + entity portraits so
        // another device can restore a self-contained world. No-op for
        // template/package types.
        final data = item.type == 'world'
            ? await _bundleWorldMedia(item.name, item.id, raw)
            : raw;

        await repo.uploadBackup(item.name, item.id, item.type, data);

        results.add(SyncItemResult(
          id: item.id,
          name: item.name,
          type: item.type,
          result: SyncResult.synced,
        ));
      } on CloudBackupSizeLimitException catch (e) {
        results.add(SyncItemResult(
          id: item.id,
          name: item.name,
          type: item.type,
          result: SyncResult.tooLarge,
          message: e.toString(),
        ));
      } on CloudBackupQuotaExceededException catch (e) {
        results.add(SyncItemResult(
          id: item.id,
          name: item.name,
          type: item.type,
          result: SyncResult.quotaExceeded,
          message: e.toString(),
        ));
      } catch (e) {
        results.add(SyncItemResult(
          id: item.id,
          name: item.name,
          type: item.type,
          result: SyncResult.networkError,
          message: e.toString(),
        ));
        // Network error — re-add to dirty so it retries next cycle.
        _dirtyItems[entry.key] = item;
      }
    }

    if (_disposed || !mounted) return;

    // Merge with previous results (keep non-synced items from earlier runs).
    final merged = <String, SyncItemResult>{};
    for (final r in state.results) {
      if (r.result != SyncResult.synced && r.result != SyncResult.pending) {
        merged['${r.type}:${r.id}'] = r;
      }
    }
    for (final r in results) {
      merged['${r.type}:${r.id}'] = r;
    }

    final hasErrors = merged.values.any((r) => r.result != SyncResult.synced);

    state = CloudSyncState(
      status: hasErrors ? CloudSyncStatus.error : CloudSyncStatus.synced,
      results: merged.values.toList(),
      lastSyncAt: DateTime.now(),
    );

    // Invalidate backup list providers.
    _ref.invalidate(cloudBackupListProvider);
    _ref.invalidate(cloudBackupWorldsProvider);
    _ref.invalidate(cloudBackupPackagesProvider);
    _ref.invalidate(cloudBackupCharactersProvider);
    _ref.invalidate(cloudStorageUsedProvider);

    // We just wrote to remote, so we're definitively caught up — clear any
    // multi-device "pull changes" hint that may have been showing.
    if (!hasErrors) {
      _ref.read(cloudRemoteHasNewerProvider.notifier).markCaughtUp();
    }
  }

  /// World upload öncesi medya bundling. AssetService yoksa (offline
  /// / yapılandırılmamış) girdiyi olduğu gibi döndürür.
  Future<Map<String, dynamic>> _bundleWorldMedia(
    String worldName,
    String worldId,
    Map<String, dynamic> data,
  ) async {
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
          'cloud_sync media_bundler partial: ${result.failures.length} file(s) '
          'failed — ${result.failures.take(3).join(', ')}',
        );
      }
      return result.data;
    } catch (e, st) {
      debugPrint('cloud_sync media_bundler error: $e\n$st');
      return data;
    }
  }

  /// Item verisini tipe göre yükle. [itemName] kampanya/paket adı (dosya/DB
  /// lookup key'i); markDirty'den gelen itemId bir UUID olduğu için
  /// burada kullanılmaz — aksi takdirde `campaignRepository.load()` her
  /// seferinde file-not-found atardı ve hiçbir world cloud'a yüklenemezdi.
  Future<Map<String, dynamic>?> _loadItemData(
      String itemName, String type) async {
    try {
      switch (type) {
        case 'world':
          return await _ref.read(campaignRepositoryProvider).load(itemName);
        case 'package':
          return await _ref.read(packageRepositoryProvider).load(itemName);
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Cloud sync: failed to load $type:$itemName — $e');
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _maxDelayTimer?.cancel();
    super.dispose();
  }
}

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncNotifier, CloudSyncState>(
  (ref) => CloudSyncNotifier(ref),
);
