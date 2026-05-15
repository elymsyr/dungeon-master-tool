import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../providers/auth_provider.dart';
import '../providers/beta_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../providers/cloud_backup_provider.dart';
import '../providers/package_provider.dart';
import '../../domain/entities/package_info.dart';

/// App-start cloud catch-up. For each cloud_backup row of type
/// `world` / `package` / `character`, pulls the row when the cloud copy is
/// newer than the local copy (or the local copy is missing). Best-effort;
/// silently skipped when offline, not signed in, or not in the beta program.
class CloudCatchupService {
  final Ref _ref;
  CloudCatchupService(this._ref);

  Future<void> runAll() async {
    if (!SupabaseConfig.isConfigured) return;
    if (_ref.read(authProvider) == null) return;
    if (!_ref.read(isBetaActiveProvider)) return;
    await Future.wait([
      _pullWorlds(),
      _pullPackages(),
      _pullCharacters(),
    ]);
  }

  Future<void> _pullWorlds() async {
    try {
      final repo = _ref.read(cloudBackupRepositoryProvider);
      final metas = await repo.listBackupsByType('world');
      final campaignRepo = _ref.read(campaignRepositoryProvider);
      final localNames =
          await _ref.read(campaignListProvider.future).catchError((_) => <String>[]);
      final localUpdates = <String, DateTime?>{};
      for (final name in localNames) {
        try {
          final data = await campaignRepo.load(name);
          final raw = data['last_modified'] ?? data['updated_at'];
          localUpdates[name] = raw is String ? DateTime.tryParse(raw) : null;
        } catch (_) {/* ignore */}
      }
      var pulled = false;
      for (final meta in metas) {
        final name = meta.itemName;
        final localAt = localUpdates[name];
        if (localAt != null && !meta.createdAt.isAfter(localAt)) continue;
        try {
          final fresh = await repo.downloadBackup(meta.id);
          await campaignRepo.save(name, fresh);
          pulled = true;
        } catch (e) {
          if (isStorageNotFound(e)) {
            try {
              await repo.deleteOrphanedMeta(meta.id);
            } catch (_) {/* ignore */}
            continue;
          }
          debugPrint('Cloud catch-up pull world "$name" error: $e');
        }
      }
      if (pulled) _ref.invalidate(campaignListProvider);
    } catch (e) {
      if (isOfflineError(e)) return;
      debugPrint('Cloud catch-up listBackupsByType(world) error: $e');
    }
  }

  Future<void> _pullPackages() async {
    try {
      final repo = _ref.read(cloudBackupRepositoryProvider);
      final metas = await repo.listBackupsByType('package');
      final packageRepo = _ref.read(packageRepositoryProvider);
      final infos = await _ref
          .read(packageListProvider.future)
          .catchError((_) => const <PackageInfo>[]);
      final localUpdates = <String, DateTime?>{};
      for (final info in infos) {
        try {
          final data = await packageRepo.load(info.name);
          final raw = data['last_modified'] ?? data['updated_at'];
          localUpdates[info.name] =
              raw is String ? DateTime.tryParse(raw) : null;
        } catch (_) {/* ignore */}
      }
      var pulled = false;
      for (final meta in metas) {
        final name = meta.itemName;
        final localAt = localUpdates[name];
        if (localAt != null && !meta.createdAt.isAfter(localAt)) continue;
        try {
          final fresh = await repo.downloadBackup(meta.id);
          await packageRepo.save(name, fresh);
          pulled = true;
        } catch (e) {
          if (isStorageNotFound(e)) {
            try {
              await repo.deleteOrphanedMeta(meta.id);
            } catch (_) {/* ignore */}
            continue;
          }
          debugPrint('Cloud catch-up pull package "$name" error: $e');
        }
      }
      if (pulled) _ref.invalidate(packageListProvider);
    } catch (e) {
      if (isOfflineError(e)) return;
      debugPrint('Cloud catch-up listBackupsByType(package) error: $e');
    }
  }

  Future<void> _pullCharacters() async {
    try {
      await _ref
          .read(characterListProvider.notifier)
          .pullNewerFromCloud();
    } catch (e) {
      if (isOfflineError(e)) return;
      debugPrint('Cloud catch-up chars error: $e');
    }
  }
}

final cloudCatchupServiceProvider = Provider<CloudCatchupService>(
  (ref) => CloudCatchupService(ref),
);
