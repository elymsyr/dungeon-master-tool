import 'package:flutter/foundation.dart';

import '../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/datasources/local/campaign_local_ds.dart' show CampaignLocalDataSource, TrashItem;
import '../../data/repositories/campaign_repository_impl.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../services/campaign_import_service.dart';
import '../services/template_sync_service.dart';

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
      // Lazy template-sync drift check — surfaces a prompt for the UI to
      // show when the source template has been edited since this campaign
      // was last synced. Failures here MUST NOT block the load.
      try {
        final result = await _ref
            .read(templateSyncServiceProvider)
            .checkDrift(campaignName: name, campaignData: _data!);
        if (result.healedHash != null) {
          // Non-semantic hash drift — store the fresh hash so the next
          // open matches cleanly, no prompt shown.
          _data!['template_hash'] = result.healedHash!;
          await _repo.save(name, _data!);
        }
        _ref.read(pendingTemplateUpdateProvider.notifier).state = result.prompt;
      } catch (e, st) {
        debugPrint('Template sync drift check failed: $e\n$st');
      }
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
    }
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
    _data!['world_schema'] = deepCopyJson(newTemplate.toJson());
    _data!['template_id'] = newTemplate.schemaId;
    _data!['template_hash'] = currentHash;
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
