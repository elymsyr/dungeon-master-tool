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
  /// `_performSave` sonrası mirror push'ları zaten zincir içinden çalışır
  /// (campaign_provider.save → mirror push). Kullanıcı Save butonundan
  /// `pushAfter: false` ile çağırır, close-guard `pushAfter: true` ile.
  Future<void> saveNow({bool pushAfter = false}) async {
    await _performSave(pushAfter: pushAfter);
  }

  Future<void> _performSave({required bool pushAfter}) async {
    if (_disposed || !mounted) return;
    state = SaveStatus.saving;
    try {
      if (_ref.read(activeCampaignProvider) != null) {
        await _ref
            .read(activeCampaignProvider.notifier)
            .save(pushMirror: pushAfter);
      }
      if (_ref.read(activePackageProvider) != null) {
        await _ref
            .read(activePackageProvider.notifier)
            .save(pushMirror: pushAfter);
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
