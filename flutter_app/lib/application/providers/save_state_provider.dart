import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'cloud_sync_provider.dart';
import 'package_provider.dart';
import 'ui_state_provider.dart';

enum SaveStatus { saved, dirty, saving }

/// Centralized save state — all modules call [markDirty] after updating
/// in-memory campaign data. A 2-second debounce timer batches disk writes,
/// but a max delay of 10 seconds guarantees a save during continuous mutations
/// (e.g. rapid combat HP changes).
class SaveStateNotifier extends StateNotifier<SaveStatus> {
  final Ref _ref;
  Timer? _saveTimer;
  Timer? _maxDelayTimer;
  static const _saveDelay = Duration(seconds: 5);
  static const _maxSaveDelay = Duration(seconds: 30);
  bool _disposed = false;

  SaveStateNotifier(this._ref) : super(SaveStatus.saved);

  /// Last successful save timestamp — read imperatively for UI display.
  DateTime? lastSavedAt;

  /// Called by any module when in-memory campaign data has changed.
  void markDirty() {
    if (_disposed || !mounted) return;
    state = SaveStatus.dirty;
    final autoSave = _ref.read(uiStateProvider).autoLocalSave;
    if (autoSave) {
      _saveTimer?.cancel();
      _saveTimer = Timer(_saveDelay, _performSave);
      _maxDelayTimer ??= Timer(_maxSaveDelay, _performSave);
    }
  }

  /// Force an immediate save (e.g., before app close or tab switch).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    await _performSave();
  }

  Future<void> _performSave() async {
    if (_disposed || !mounted) return;
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    state = SaveStatus.saving;
    try {
      if (_ref.read(activeCampaignProvider) != null) {
        await _ref.read(activeCampaignProvider.notifier).save();
      }
      if (_disposed) return;
      lastSavedAt = DateTime.now();

      // Auto cloud sync. Always-on for signed-in beta users — cloudSync
      // markDirty itself gates on supabase + auth + beta. Worlds that are
      // currently online (`onlineWorldIdsProvider` contains worldId) skip
      // the cloud_backup path because campaign_provider's `_mirrorAfterSave`
      // already pushes the real-time world_state mirror.
      if (SupabaseConfig.isConfigured && _ref.read(authProvider) != null) {
        final notifier = _ref.read(cloudSyncProvider.notifier);
        final campaignName = _ref.read(activeCampaignProvider);
        if (campaignName != null) {
          final data = _ref.read(activeCampaignProvider.notifier).data;
          final worldId = (data?['world_id'] as String?) ?? campaignName;
          notifier.markDirty(worldId, campaignName, 'world');
        }
        final packageName = _ref.read(activePackageProvider);
        if (packageName != null) {
          final data = _ref.read(activePackageProvider.notifier).data;
          final packageId = (data?['package_id'] as String?) ??
              (data?['world_id'] as String?) ??
              packageName;
          notifier.markDirty(packageId, packageName, 'package');
        }
      }
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (!_disposed && mounted) {
        state = SaveStatus.saved;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    super.dispose();
  }
}

final saveStateProvider =
    StateNotifierProvider<SaveStateNotifier, SaveStatus>((ref) {
  return SaveStateNotifier(ref);
});
