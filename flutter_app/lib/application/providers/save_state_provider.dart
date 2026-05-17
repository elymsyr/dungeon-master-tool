import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pending_write_buffer.dart';
import 'campaign_provider.dart';
import 'package_provider.dart';

enum SaveStatus { saved, dirty, saving }

/// Manuel save modeli — auto-save kaldırıldı. `saveNow()` Save butonu ve
/// close-guard akışları tarafından çağrılır. `markDirty()` artık tip
/// uyumluluğu için no-op olarak duruyor (eski callsite'ları kırmasın diye).
class SaveStateNotifier extends StateNotifier<SaveStatus> {
  final Ref _ref;
  bool _disposed = false;

  SaveStateNotifier(this._ref) : super(SaveStatus.saved) {
    // PendingWriteBuffer tick'lerine bağlan — buffer'da pending iş varsa
    // dirty, fire/flush sonrası saved. saveNow() / manual flush yine
    // _performSave path'inden gider.
    final buffer = _ref.read(pendingWriteBufferProvider);
    buffer.tick.addListener(_onBufferTick);
  }

  void _onBufferTick() {
    if (_disposed || !mounted) return;
    if (state == SaveStatus.saving) return;
    final hasPending = _ref.read(pendingWriteBufferProvider).hasPending;
    final next = hasPending ? SaveStatus.dirty : SaveStatus.saved;
    if (state != next) {
      state = next;
      if (!hasPending) {
        lastSavedAt = DateTime.now();
      }
    }
  }

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
      // Önce pending debounce'ları drain et — buffer'da bekleyen row
      // yazımları close anında kaybolmasın.
      await _ref.read(pendingWriteBufferProvider).flush();
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
    try {
      _ref.read(pendingWriteBufferProvider).tick.removeListener(_onBufferTick);
    } catch (_) {}
    super.dispose();
  }
}

final saveStateProvider =
    StateNotifierProvider<SaveStateNotifier, SaveStatus>((ref) {
  return SaveStateNotifier(ref);
});
