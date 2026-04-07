import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';

enum SaveStatus { saved, dirty, saving }

/// Centralized save state — all modules call [markDirty] after updating
/// in-memory campaign data. A 2-second debounce timer batches disk writes.
class SaveStateNotifier extends StateNotifier<SaveStatus> {
  final Ref _ref;
  Timer? _saveTimer;
  static const _saveDelay = Duration(seconds: 2);

  SaveStateNotifier(this._ref) : super(SaveStatus.saved);

  /// Called by any module when in-memory campaign data has changed.
  void markDirty() {
    if (!mounted) return;
    state = SaveStatus.dirty;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _performSave);
  }

  /// Force an immediate save (e.g., before app close or tab switch).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    await _performSave();
  }

  Future<void> _performSave() async {
    if (!mounted) return;
    state = SaveStatus.saving;
    try {
      await _ref.read(activeCampaignProvider.notifier).save();
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
    super.dispose();
  }
}

final saveStateProvider =
    StateNotifierProvider<SaveStateNotifier, SaveStatus>((ref) {
  return SaveStateNotifier(ref);
});
