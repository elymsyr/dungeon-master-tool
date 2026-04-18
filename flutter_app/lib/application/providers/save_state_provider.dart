import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'cloud_sync_provider.dart';
import 'template_provider.dart';
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
  static const _saveDelay = Duration(seconds: 2);
  static const _maxSaveDelay = Duration(seconds: 10);
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
      // Aktif item: campaign öncelikli; yoksa template.
      if (_ref.read(activeCampaignProvider) != null) {
        await _ref.read(activeCampaignProvider.notifier).save();
      } else if (_ref.read(activeTemplateProvider) != null) {
        await _ref.read(activeTemplateProvider.notifier).save();
      }
      if (_disposed) return;
      lastSavedAt = DateTime.now();

      // Cloud sync trigger — SADECE kullanıcı autoCloudSave ayarını
      // açmışsa dirty olarak işaretle. Default kapalı olduğu için
      // cloud backup yalnızca kullanıcı elle "Backup to Cloud" butonuna
      // basınca yapılır.
      if (SupabaseConfig.isConfigured &&
          _ref.read(authProvider) != null &&
          _ref.read(uiStateProvider).autoCloudSave) {
        final campaignName = _ref.read(activeCampaignProvider);
        final data = _ref.read(activeCampaignProvider.notifier).data;
        if (campaignName != null && data != null) {
          final worldId = data['world_id'] as String? ?? campaignName;
          _ref.read(cloudSyncProvider.notifier).markDirty(
                worldId,
                campaignName,
                'world',
              );
        }
        final templateId = _ref.read(activeTemplateProvider);
        if (templateId != null) {
          final schema = _ref.read(activeTemplateProvider.notifier).schema;
          if (schema != null) {
            _ref.read(cloudSyncProvider.notifier).markDirty(
                  schema.schemaId,
                  schema.name,
                  'template',
                );
          }
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
