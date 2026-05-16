import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/network_providers.dart';
import '../services/media_bundler.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart';
import 'package_provider.dart';
import 'sync_engine_provider.dart';

/// PR-SYNC-6: explicit "Backup to Cloud" action. Replaces the
/// `cloudSyncProvider.backupActiveItem()` path retired with the old
/// debounce queue. Resolves the active world or package, bundles media
/// (worlds), enqueues a `cloud_backup_*` outbox row, and force-ticks the
/// engine so the upload starts immediately.
///
/// Returns `true` when something was enqueued (caller surfaces a
/// "Backing up..." snackbar); `false` when there's no active item or the
/// user lacks beta access.
final manualBackupRunnerProvider =
    Provider<ManualBackupRunner>((ref) => ManualBackupRunner(ref));

class ManualBackupRunner {
  ManualBackupRunner(this._ref);
  final Ref _ref;

  Future<bool> backupActiveItem() async {
    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) {
      return false;
    }
    if (!_ref.read(betaProvider).isActive) return false;

    final engine = _ref.read(syncEngineProvider);

    final campaignName = _ref.read(activeCampaignProvider);
    if (campaignName != null) {
      final data = _ref.read(activeCampaignProvider.notifier).data;
      if (data != null) {
        final worldId = (data['world_id'] as String?) ?? campaignName;
        final bundled = await _bundleWorldMedia(campaignName, worldId, data);
        await engine.enqueueCloudBackupUpsert(
          itemId: worldId,
          itemName: campaignName,
          type: 'world',
          data: bundled,
        );
        await engine.forceTick();
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
        await engine.enqueueCloudBackupUpsert(
          itemId: packageId,
          itemName: packageName,
          type: 'package',
          data: data,
        );
        await engine.forceTick();
        return true;
      }
    }

    return false;
  }

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
      return result.data;
    } catch (e, st) {
      debugPrint('manual_backup media_bundler error: $e\n$st');
      return data;
    }
  }
}
