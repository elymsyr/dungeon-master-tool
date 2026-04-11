import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';

enum SaveStatus { saved, dirty, saving }

/// Centralized save state — all modules call [markDirty] after updating
/// in-memory campaign data. A 2-second debounce timer batches disk writes,
/// but a max delay of 10 seconds guarantees a save during continuous mutations
/// (e.g. rapid combat HP changes).
class SaveStateNotifier extends StateNotifier<SaveStatus> {
  final Ref _ref;
  Timer? _saveTimer;
  Timer? _maxDelayTimer;
  static const _saveDelay = Duration(seconds: 2);
  static const _maxSaveDelay = Duration(seconds: 10);

  SaveStateNotifier(this._ref) : super(SaveStatus.saved);

  /// Last successful save timestamp — read imperatively for UI display.
  DateTime? lastSavedAt;

  /// Called by any module when in-memory campaign data has changed.
  void markDirty() {
    if (!mounted) return;
    state = SaveStatus.dirty;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _performSave);
    // Max delay guard: ilk dirty'den itibaren 10s sonra mutlaka save edilir.
    _maxDelayTimer ??= Timer(_maxSaveDelay, _performSave);
  }

  /// Force an immediate save (e.g., before app close or tab switch).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    await _performSave();
  }

  Future<void> _performSave() async {
    if (!mounted) return;
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    _maxDelayTimer = null;
    state = SaveStatus.saving;
    try {
      await _ref.read(activeCampaignProvider.notifier).save();
      lastSavedAt = DateTime.now();
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) {
        state = SaveStatus.saved;
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _maxDelayTimer?.cancel();
    super.dispose();
  }
}

final saveStateProvider =
    StateNotifierProvider<SaveStateNotifier, SaveStatus>((ref) {
  return SaveStateNotifier(ref);
});
