import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';
import 'online_worlds_provider.dart';
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
  // Active-world online (PR-SYNC-1): tighten the debounce so a remote
  // player sees a DM edit within a couple of seconds.
  static const _saveDelayOnline = Duration(milliseconds: 800);
  static const _maxSaveDelayOnline = Duration(seconds: 3);

  // Offline / hub-only: leave the original 5s/30s window — local-only writes
  // shouldn't chew through SSD I/O.
  static const _saveDelayOffline = Duration(seconds: 5);
  static const _maxSaveDelayOffline = Duration(seconds: 30);
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
      final online = _isActiveWorldOnline();
      final delay = online ? _saveDelayOnline : _saveDelayOffline;
      final maxDelay = online ? _maxSaveDelayOnline : _maxSaveDelayOffline;
      _saveTimer?.cancel();
      _saveTimer = Timer(delay, _performSave);
      _maxDelayTimer ??= Timer(maxDelay, _performSave);
    }
  }

  bool _isActiveWorldOnline() {
    final data = _ref.read(activeCampaignProvider.notifier).data;
    final worldId = data?['world_id'] as String?;
    if (worldId == null) return false;
    return _ref.read(onlineWorldIdsProvider).contains(worldId);
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
      // PR-SYNC-6: cloud_sync_provider retired. Per-mutation outbox enqueues
      // already drive the real-time mirror + cloud_backup paths; no fan-out
      // hook needed here.
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
