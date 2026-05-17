import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';
import 'package_provider.dart';

enum SaveStatus { saved, dirty, saving }

/// Manuel save modeli — auto-save kaldırıldı. `saveNow()` Save butonu ve
/// close-guard akışları tarafından çağrılır. `markDirty()` artık tip
/// uyumluluğu için no-op olarak duruyor (eski callsite'ları kırmasın diye).
class SaveStateNotifier extends StateNotifier<SaveStatus> {
  final Ref _ref;
  bool _disposed = false;

  SaveStateNotifier(this._ref) : super(SaveStatus.saved);

  /// Last successful save timestamp — read imperatively for UI display.
  DateTime? lastSavedAt;

  /// No-op — auto-save kaldırıldı. Kalan caller'lar temizlenirken zararsız.
  void markDirty() {}

  /// Save current active campaign/package to disk. `pushAfter` true ise
  /// F6: cloud sync is row-level via the outbox — bulk close-time push
  /// retired. `saveNow` now only persists in-memory data to disk.
  Future<void> saveNow() async {
    await _performSave();
  }

  Future<void> _performSave() async {
    if (_disposed || !mounted) return;
    state = SaveStatus.saving;
    try {
      if (_ref.read(activeCampaignProvider) != null) {
        await _ref.read(activeCampaignProvider.notifier).save();
      }
      if (_ref.read(activePackageProvider) != null) {
        await _ref.read(activePackageProvider.notifier).save();
      }
      if (_disposed) return;
      lastSavedAt = DateTime.now();
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
    super.dispose();
  }
}

final saveStateProvider =
    StateNotifierProvider<SaveStateNotifier, SaveStatus>((ref) {
  return SaveStateNotifier(ref);
});
