import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/world_mirror_provider.dart';
import 'media_bundler.dart';
import 'world_mirror_service.dart';
import '../../data/network/network_providers.dart';

/// Yeni dünya senkron mantığı (manuel Refresh + Sync).
///
/// Tek kaynak: `worlds` tablosu. Cloud_backups kavramı kaldırıldı. Kural:
///
/// * Dünya cloud'da yalnızca "Make Online" yapıldıysa durur.
/// * Refresh / Sync bidirectional reconcile:
///   - Cloud'da var, lokalde yok → indir.
///   - Lokalde var, cloud'da var, cloud daha güncel → cloud → lokal.
///   - Lokalde var, cloud'da var, lokal daha güncel → lokal → cloud
///     (`publishWorld` ile state_json overwrite).
///   - Lokalde var, cloud'da yok → dokunma (offline kalır).
class WorldReconciler {
  WorldReconciler(this._ref);

  final Ref _ref;

  Future<ReconcileResult> reconcile() async {
    if (!SupabaseConfig.isConfigured) {
      return ReconcileResult.empty('Cloud yapılandırılmamış');
    }
    if (_ref.read(authProvider) == null) {
      return ReconcileResult.empty('Oturum açılmamış');
    }
    final client = Supabase.instance.client;

    final List<Map<String, dynamic>> cloudRows;
    try {
      final raw = await client
          .from('worlds')
          .select(
              'id, world_name, updated_at, template_id, template_hash, state_json');
      cloudRows = (raw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('reconcile cloud worlds list error: $e');
      return ReconcileResult.empty('Cloud listesi alınamadı: $e');
    }

    final localById = <String, _LocalWorld>{};
    try {
      final repo = _ref.read(campaignRepositoryProvider);
      final names = await repo.getAvailable();
      for (final name in names) {
        try {
          final data = await repo.load(name);
          final id = (data['world_id'] as String?) ?? name;
          final raw = data['last_modified'] ?? data['updated_at'];
          final updated = raw is String ? DateTime.tryParse(raw) : null;
          localById[id] = _LocalWorld(name: name, data: data, updatedAt: updated);
        } catch (e) {
          debugPrint('reconcile local load "$name" error: $e');
        }
      }
    } catch (e) {
      debugPrint('reconcile local list error: $e');
    }

    var pulled = 0;
    var pushed = 0;
    final mirror = _ref.read(worldMirrorServiceProvider);

    for (final row in cloudRows) {
      final worldId = row['id'] as String;
      final worldName = (row['world_name'] as String?) ?? worldId;
      final cloudUpdatedRaw = row['updated_at'] as String?;
      final cloudUpdated = cloudUpdatedRaw != null
          ? DateTime.tryParse(cloudUpdatedRaw)
          : null;
      final stateJsonStr = row['state_json'] as String?;
      final templateId = row['template_id'] as String?;
      final templateHash = row['template_hash'] as String?;

      final local = localById.remove(worldId);
      if (local == null) {
        // Cloud-only → indir.
        final ok = await _pullToLocal(
          worldId: worldId,
          worldName: worldName,
          stateJsonStr: stateJsonStr,
        );
        if (ok) pulled++;
        _ref.read(onlineWorldIdsProvider.notifier).add(worldId);
        continue;
      }

      // Her iki tarafta var → en güncel kazanır.
      final cloudWins = cloudUpdated != null &&
          (local.updatedAt == null || cloudUpdated.isAfter(local.updatedAt!));
      final localWins = local.updatedAt != null &&
          (cloudUpdated == null || local.updatedAt!.isAfter(cloudUpdated));

      if (cloudWins) {
        final ok = await _pullToLocal(
          worldId: worldId,
          worldName: local.name,
          stateJsonStr: stateJsonStr,
        );
        if (ok) pulled++;
      } else if (localWins && mirror != null) {
        final ok = await _pushToCloud(
          mirror: mirror,
          worldId: worldId,
          worldName: local.name,
          templateId: templateId,
          templateHash: templateHash,
          data: local.data,
        );
        if (ok) pushed++;
      }
      _ref.read(onlineWorldIdsProvider.notifier).add(worldId);
    }

    return ReconcileResult(
      pulled: pulled,
      pushed: pushed,
      message: 'Pulled $pulled, pushed $pushed',
    );
  }

  Future<bool> _pullToLocal({
    required String worldId,
    required String worldName,
    required String? stateJsonStr,
  }) async {
    if (stateJsonStr == null || stateJsonStr.isEmpty) return false;
    try {
      final decoded = jsonDecode(stateJsonStr);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      data['world_id'] = worldId;
      await _ref.read(campaignRepositoryProvider).save(worldName, data);
      _ref.invalidate(campaignListProvider);
      _ref.invalidate(campaignInfoListProvider);
      return true;
    } catch (e) {
      debugPrint('reconcile pull "$worldName" error: $e');
      return false;
    }
  }

  Future<bool> _pushToCloud({
    required WorldMirrorService mirror,
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required Map<String, dynamic> data,
  }) async {
    try {
      Map<String, dynamic> bundled = data;
      final assetSvc = _ref.read(assetServiceProvider);
      if (assetSvc != null) {
        try {
          final res = await MediaBundler(assetSvc).bundleWorldMedia(
            worldName: worldName,
            worldId: worldId,
            data: data,
          );
          bundled = res.data;
        } catch (e) {
          debugPrint('reconcile push media bundle error: $e');
        }
      }
      await mirror.pushWorldState(
        worldId: worldId,
        worldName: worldName,
        templateId: templateId,
        templateHash: templateHash,
        stateJson: jsonEncode(bundled),
      );
      return true;
    } catch (e) {
      debugPrint('reconcile push "$worldName" error: $e');
      return false;
    }
  }
}

class _LocalWorld {
  _LocalWorld({required this.name, required this.data, required this.updatedAt});
  final String name;
  final Map<String, dynamic> data;
  final DateTime? updatedAt;
}

class ReconcileResult {
  ReconcileResult({required this.pulled, required this.pushed, required this.message});
  ReconcileResult.empty(this.message) : pulled = 0, pushed = 0;

  final int pulled;
  final int pushed;
  final String message;
}

final worldReconcilerProvider =
    Provider<WorldReconciler>((ref) => WorldReconciler(ref));
