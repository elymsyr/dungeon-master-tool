import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/exceptions/cloud_backup_exceptions.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'cloud_backup_provider.dart';

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

    final key = '$type:$itemId';
    _dirtyItems[key] = (name: itemName, type: type, id: itemId);

    state = state.copyWith(status: CloudSyncStatus.pending);
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDelay, _performSync);
    _maxDelayTimer ??= Timer(_maxSyncDelay, _performSync);
  }

  /// Manuel tetik.
  Future<void> syncNow() async {
    _syncTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    await _performSync();
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
        final data = await _loadItemData(item.id, item.type);
        if (data == null) continue;

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
    _ref.invalidate(cloudBackupTemplatesProvider);
    _ref.invalidate(cloudBackupPackagesProvider);
    _ref.invalidate(cloudStorageUsedProvider);
  }

  /// Item verisini tip'e göre yükle.
  Future<Map<String, dynamic>?> _loadItemData(
      String itemId, String type) async {
    try {
      switch (type) {
        case 'world':
          // itemId = campaignName (for worlds the name is the lookup key)
          return await _ref.read(campaignRepositoryProvider).load(itemId);
        // Template ve package loading ileride eklenecek.
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Cloud sync: failed to load $type:$itemId — $e');
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
