import 'package:flutter/foundation.dart';

import 'dart:convert';

import '../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/datasources/local/campaign_local_ds.dart' show CampaignLocalDataSource, TrashItem;
import '../../data/repositories/campaign_repository_impl.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../../data/network/network_providers.dart';
import '../services/campaign_import_service.dart';
import '../services/media_bundler.dart';
import '../services/world_mirror_service.dart';
import 'online_worlds_provider.dart';
import 'world_mirror_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

final campaignLocalDsProvider = Provider((_) => CampaignLocalDataSource());

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => CampaignRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.read(campaignLocalDsProvider),
  ),
);

/// Legacy (Python v0.8.4) world klasörlerini [AppPaths.worldsDir] altına
/// kopyalayan servis. UI bunu çağırır; mevcut load pipeline sonrasında
/// otomatik olarak MsgPack → SQLite migration'u devralır.
final campaignImportServiceProvider = Provider<CampaignImportService>(
  (ref) => CampaignImportService(
    ref.watch(campaignRepositoryProvider),
    ref.watch(campaignLocalDsProvider),
  ),
);

/// Mevcut kampanya listesi.
final campaignListProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(campaignRepositoryProvider).getAvailable();
});

/// Monotonic revision counter for the active campaign/package data.
///
/// Bumped when `_data` is mutated in-place and downstream providers need
/// to re-read without forcing a full `activeCampaignProvider` rebuild
/// (which used to be done by null-toggling `state`, triggering a cascade
/// reparse of WorldSchema and EntityNotifier on every bump). Watchers
/// that care about data-content changes should watch this provider in
/// addition to `activeCampaignProvider`.
final campaignRevisionProvider = StateProvider<int>((_) => 0);

/// Kampanya isim + template bilgisi.
class CampaignInfo {
  final String id;
  final String name;
  final String templateName;
  const CampaignInfo({
    required this.id,
    required this.name,
    required this.templateName,
  });
}

/// Kampanya listesi + template bilgileri.
final campaignInfoListProvider = FutureProvider<List<CampaignInfo>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.campaignDao.getCampaignInfoList();
  return rows
      .map((r) => CampaignInfo(
            id: r.id,
            name: r.worldName,
            templateName: r.templateName,
          ))
      .toList();
});

/// Per-campaign metadata lookup — cover / description / tags için.
/// Campaign blob'undan `metadata` alanını okur. List UI bu provider'ı
/// watch ederek cover/desc/tags gösterimi için kullanır.
final campaignMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, campaignName) async {
  try {
    final data = await ref.read(campaignRepositoryProvider).load(campaignName);
    final meta = data['metadata'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Campaign metadata writer — sadece metadata'yı değiştirir, diğer verilere
/// dokunmaz. Ayarlar dialog'undan çağrılır.
Future<void> updateCampaignMetadata(
  WidgetRef ref,
  String campaignName,
  Map<String, dynamic> newMetadata,
) async {
  final repo = ref.read(campaignRepositoryProvider);
  final data = await repo.load(campaignName);
  data['metadata'] = newMetadata;
  await repo.save(campaignName, data);
  ref.invalidate(campaignMetadataProvider(campaignName));
  ref.invalidate(campaignInfoListProvider);
}

/// Aktif kampanya adı. null = henüz seçilmedi.
class ActiveCampaignNotifier extends StateNotifier<String?> {
  final CampaignRepository _repo;
  final Ref _ref;

  ActiveCampaignNotifier(this._repo, this._ref) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  /// Dışarıdan veri ile önceden yükle (paket ProviderScope override için).
  void preload(String name, Map<String, dynamic> data) {
    _data = data;
    state = name;
  }

  Future<bool> load(String name) async {
    try {
      _data = await _repo.load(name);
      state = name;
      return true;
    } catch (e, st) {
      debugPrint('Campaign load error: $e\n$st');
      return false;
    }
  }

  Future<bool> create(String worldName, {WorldSchema? template}) async {
    try {
      await _repo.create(worldName, template: template);
      return load(worldName);
    } catch (e, st) {
      debugPrint('Campaign create error: $e\n$st');
      return false;
    }
  }

  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
      _mirrorAfterSave();
    }
  }

  /// World online ise lokal save sonrası Supabase mirror'a push eder.
  /// Best-effort: mirror null veya RLS reddederse sessizce geç.
  void _mirrorAfterSave() {
    final mirror = _ref.read(worldMirrorServiceProvider);
    final data = _data;
    if (mirror == null || data == null) return;
    final worldId = data['world_id'] as String?;
    if (worldId == null) return;
    // Offline world → mirror push'u atla (RLS gürültüsünü engeller).
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return;
    final worldName = state ?? '';
    final schemaMap = data['world_schema'];
    final templateId = schemaMap is Map ? schemaMap['schemaId'] as String? : null;
    final templateHash = data['template_hash'] as String?;
    // Media'yı R2'ye yükleyip `dmt-asset://` ref'lerine rewrite et;
    // sonra entity + state push. Bundle SHA-dedupe sayesinde repeat
    // save'ler ucuz. AssetService yoksa (worker URL define yok) raw data.
    // ignore: discarded_futures
    _bundleAndPush(
      mirror: mirror,
      worldId: worldId,
      worldName: worldName,
      templateId: templateId,
      templateHash: templateHash,
      data: data,
    );
  }

  Future<void> _bundleAndPush({
    required WorldMirrorService mirror,
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required Map<String, dynamic> data,
  }) async {
    // Player rolündeki user world_entities/worlds tablolarına yazamaz (RLS).
    // Async lookup — circular dep'i önlemek için doğrudan Supabase.
    if (SupabaseConfig.isConfigured) {
      final auth = Supabase.instance.client.auth.currentUser;
      if (auth == null) return;
      try {
        final row = await Supabase.instance.client
            .from('world_members')
            .select('role')
            .eq('world_id', worldId)
            .eq('user_id', auth.id)
            .maybeSingle();
        if (row == null || row['role'] != 'dm') return;
      } catch (_) {
        return;
      }
    }
    final assetSvc = _ref.read(assetServiceProvider);
    Map<String, dynamic> bundled = data;
    if (assetSvc != null) {
      try {
        final res = await MediaBundler(assetSvc).bundleWorldMedia(
          worldName: worldName,
          worldId: worldId,
          data: data,
        );
        bundled = res.data;
      } catch (e, st) {
        debugPrint('online mirror media bundle error: $e\n$st');
      }
    }
    final entitiesRaw = bundled['entities'];
    final entitiesBlob = entitiesRaw is Map<String, dynamic>
        ? entitiesRaw
        : const <String, dynamic>{};
    await mirror.pushEntities(worldId: worldId, entitiesBlob: entitiesBlob);
    await mirror.pushWorldState(
      worldId: worldId,
      worldName: worldName,
      templateId: templateId,
      templateHash: templateHash,
      stateJson: jsonEncode(bundled),
    );
  }

  /// Re-reads the active campaign from disk, replaces [_data] in place
  /// (so any cached references — e.g. the wrapped notifier inside
  /// PackageScreen's ProviderScope — observe the new values), and
  /// bumps [campaignRevisionProvider] so downstream providers
  /// (worldSchemaProvider, entityProvider, …) re-read from the fresh
  /// data without a full notifier recreation cascade. Used by the
  /// cloud "restore into the currently open item" flow.
  Future<void> reload() async {
    if (state == null) return;
    final name = state!;
    final fresh = await _repo.load(name);
    if (_data == null) {
      _data = fresh;
    } else {
      _data!
        ..clear()
        ..addAll(fresh);
    }
    _bumpRevision();
  }

  /// Replaces the in-memory data map with [newData] and persists it.
  /// Like [reload], but uses a caller-supplied payload instead of
  /// reading from disk. Used by cloud restore where we already have
  /// the downloaded backup envelope.
  Future<void> replaceWithData(Map<String, dynamic> newData) async {
    if (state == null) return;
    final name = state!;
    if (_data == null) {
      _data = Map<String, dynamic>.from(newData);
    } else {
      _data!
        ..clear()
        ..addAll(newData);
    }
    await _repo.save(name, _data!);
    _bumpRevision();
  }

  void _bumpRevision() {
    final notifier = _ref.read(campaignRevisionProvider.notifier);
    notifier.state = notifier.state + 1;
  }

  /// Replaces the active campaign's worldSchema with [newTemplate], updates
  /// the recorded template hash, and persists. Used by the lazy template-sync
  /// "Update" action from the prompt dialog. The caller is responsible for
  /// invalidating any provider caches that read the world schema.
  ///
  /// Hash bookkeeping:
  ///   - `template_hash` always becomes [newTemplate]'s freshly computed
  ///     current hash (the "synced at this version" marker).
  ///   - `template_original_hash` is set/backfilled to the new template's
  ///     `originalHash`. For campaigns that already had a matching
  ///     lineage hash this is a no-op; for legacy campaigns matched via
  ///     the schemaId fallback this writes the lineage identifier so
  ///     future drift checks can use the preferred lookup path.
  ///
  /// Note: we mutate `_data` in place but `state` (the campaign name) stays
  /// the same — Riverpod's StateNotifier only fires listeners on `state`
  /// changes, so widgets watching `activeCampaignProvider` would not
  /// rebuild on their own. We force a notification by toggling state via
  /// the same name, which makes any `ref.watch(activeCampaignProvider)`
  /// downstream (e.g., `worldSchemaProvider`) re-execute.
  Future<void> applyTemplateUpdate(WorldSchema newTemplate) async {
    if (state == null || _data == null) return;
    final currentHash = computeWorldSchemaContentHash(newTemplate);
    final prevHash = _data!['template_hash'];
    final prevTemplateId = _data!['template_id'];
    // Hash gate: skip the expensive deepCopyJson(toJson()) when the schema
    // is already at this exact version. Bookkeeping (dismiss/mute clear) +
    // save still run so the caller's intent — "user accepted this template" —
    // is honoured even on a no-op content match.
    if (prevHash != currentHash || prevTemplateId != newTemplate.schemaId) {
      _data!['world_schema'] = deepCopyJson(newTemplate.toJson());
      _data!['template_id'] = newTemplate.schemaId;
      _data!['template_hash'] = currentHash;
    }
    if (newTemplate.originalHash != null) {
      _data!['template_original_hash'] = newTemplate.originalHash;
    }
    // Clear any previous dismiss/mute so the next drift check doesn't skip.
    _data!.remove('template_dismissed_hash');
    _data!.remove('template_updates_muted');
    await _repo.save(state!, _data!);
    _bumpRevision();
  }

  /// Persists the user's "ignore this template version" choice. The
  /// dismissed hash is stored in `state_json` (not a typed column) so no
  /// DB migration is needed. If the template is edited again (new hash),
  /// the mismatch with the dismissed hash causes the prompt to reappear.
  Future<void> dismissTemplateUpdate(String templateHash) async {
    if (state == null || _data == null) return;
    _data!['template_dismissed_hash'] = templateHash;
    await _repo.save(state!, _data!);
  }

  /// Permanently suppresses template-update prompts for this campaign.
  /// Stores `template_updates_muted: true` in the campaign's state_json.
  Future<void> muteTemplateUpdates() async {
    if (state == null || _data == null) return;
    _data!['template_updates_muted'] = true;
    await _repo.save(state!, _data!);
  }

  Future<void> delete(String campaignName) async {
    await _repo.delete(campaignName);
    if (state == campaignName) {
      _data = null;
      state = null;
    }
  }
}

final activeCampaignProvider =
    StateNotifierProvider<ActiveCampaignNotifier, String?>((ref) {
  return ActiveCampaignNotifier(ref.watch(campaignRepositoryProvider), ref);
});

/// Trash'teki silinen kampanyalar.
final trashListProvider = FutureProvider<List<TrashItem>>((ref) {
  return ref.read(campaignLocalDsProvider).listTrash();
});
