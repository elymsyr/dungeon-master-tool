import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart' as drift_db;
import '../../data/database/database_provider.dart';
import '../../data/repositories/world_repository_impl.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../services/pending_write_buffer.dart';
import 'auth_provider.dart';
import 'character_provider.dart';
import 'cloud_backup_provider.dart';
import 'online_worlds_provider.dart';
import 'role_provider.dart';
import 'sync_engine_provider.dart';
import 'world_membership_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

/// View model for the Settings → Trash UI. Wraps a Drift trash row with the
/// fields the UI consumes (display name + type). Replaces the old
/// `campaign_local_ds.TrashItem` shape (deleted in PR-D2).
class TrashItem {
  final String id;
  final String originalName;
  final String type;
  final DateTime deletedAt;
  /// Drift `kind` column — `'world'` | `'package'`. Used by restore handlers.
  final String kind;
  /// Raw payload for restore.
  final Map<String, dynamic> payload;

  const TrashItem({
    required this.id,
    required this.originalName,
    required this.type,
    required this.deletedAt,
    required this.kind,
    required this.payload,
  });
}

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => WorldRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// Mevcut kampanya listesi.
final campaignListProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(campaignRepositoryProvider).getAvailable();
});

/// True while an active-campaign open/swap is in flight (after the
/// optimistic state flip, before `_data` is populated). UI surfaces a
/// skeleton/spinner while this is `true` and the underlying providers
/// fall back to defaults (empty entity map, default schema).
final activeCampaignLoadingProvider = StateProvider<bool>((_) => false);

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

/// Kampanya listesi + template bilgileri. v12: worlds tablosundan oku, schema
/// adını world_settings.settings_json içindeki `_world_schema.name`'den çıkar.
/// N+1 var ama dünya sayısı küçük (typ < 20).
final campaignInfoListProvider = FutureProvider<List<CampaignInfo>>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final worlds = await db.worldsDao.getAll();
  final infos = <CampaignInfo>[];
  for (final w in worlds) {
    final settingsRow = await db.worldSettingsDao.get(w.id);
    String templateName = '';
    if (settingsRow != null && settingsRow.settingsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(settingsRow.settingsJson);
        if (decoded is Map) {
          final schema = decoded['_world_schema'];
          if (schema is Map && schema['name'] is String) {
            templateName = schema['name'] as String;
          }
        }
      } catch (_) {}
    }
    infos.add(CampaignInfo(
      id: w.id,
      name: w.worldName,
      templateName: templateName,
    ));
  }
  return infos;
});

/// Resolves a worldId to its local campaign name, pulling the world from
/// cloud_backup on demand when the local copy is missing.
///
/// Used by the character-open paths (Char Tab + sidebar) so a character that
/// arrived via cross-device char sync but whose world has not yet been
/// downloaded triggers a one-shot world restore instead of failing with
/// "Character world not found locally."
///
/// Returns the resolved campaign name on success, or `null` when the world
/// is neither local nor available in cloud_backup (or pull failed). The
/// caller is responsible for surfacing the failure message; this helper
/// stays silent so it can be used as a best-effort step.
Future<String?> ensureWorldLocalById(WidgetRef ref, String worldId) async {
  final infos = await ref.read(campaignInfoListProvider.future);
  final match = infos.where((i) => i.id == worldId).firstOrNull;
  if (match != null) return match.name;
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.read(authProvider) == null) return null;
  try {
    final repo = ref.read(cloudBackupRepositoryProvider);
    final meta = await repo.fetchByItem(worldId, 'world');
    if (meta == null) return null;
    final ok = await ref
        .read(cloudBackupOperationProvider.notifier)
        .restoreBackup(meta);
    if (!ok) return null;
    ref.invalidate(campaignInfoListProvider);
    final fresh = await ref.read(campaignInfoListProvider.future);
    final found = fresh.where((i) => i.id == worldId).firstOrNull;
    return found?.name;
  } catch (e, st) {
    debugPrint('ensureWorldLocalById error: $e\n$st');
    return null;
  }
}

/// Per-campaign metadata lookup — cover / description / tags için.
/// Campaign blob'undan `metadata` alanını okur. List UI bu provider'ı
/// watch ederek cover/desc/tags gösterimi için kullanır.
final campaignMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      campaignName,
    ) async {
      try {
        final data = await ref
            .read(campaignRepositoryProvider)
            .load(campaignName);
        final meta = data['metadata'];
        return meta is Map
            ? Map<String, dynamic>.from(meta)
            : <String, dynamic>{};
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

  /// Optimistic state flip: synchronously points the active campaign at
  /// [name] and clears `_data`, so route + dependent providers can update
  /// in the same frame as the tap. The heavy file IO + flush runs in
  /// [completeLoad], which the caller awaits separately.
  ///
  /// Downstream providers (`worldSchemaProvider`, `entityProvider`) treat
  /// `_data == null` as a transient state — schema falls back to default,
  /// entities to an empty map — until `completeLoad` lands and bumps
  /// `campaignRevisionProvider` to trigger a reparse.
  void beginLoad(String name) {
    _data = null;
    _ref.read(activeCampaignLoadingProvider.notifier).state = true;
    state = name;
  }

  /// Async tail of [beginLoad]. Flushes pending writes for the prior
  /// world, loads the new world's data, then bumps the revision counter.
  Future<bool> completeLoad() async {
    final name = state;
    if (name == null) {
      _ref.read(activeCampaignLoadingProvider.notifier).state = false;
      return false;
    }
    try {
      // Önceki world'ün pending row yazımlarını drain et — yeni world
      // yüklenmeden eski edit'ler kayba uğramasın.
      await _ref.read(pendingWriteBufferProvider).flush();
      _data = await _repo.load(name);
      // `state` already equals `name` from beginLoad — bump revision so
      // schema + entity providers re-read `_data` (state didn't change so
      // they wouldn't otherwise see the new content).
      _ref.read(campaignRevisionProvider.notifier).state++;
      _ref.read(activeCampaignLoadingProvider.notifier).state = false;
      // Online dünya açılışında roster + invite cache'lerini temizle —
      // kapalıyken kaçırılan join'ler ya da offline iken null cache'lenmiş
      // invite kodu reopen ile kurtarılsın.
      final worldId = _data?['world_id'] as String?;
      if (worldId != null) {
        _ref.invalidate(worldMembersProvider(worldId));
        _ref.invalidate(worldActiveInviteCodeProvider(worldId));
      }
      return true;
    } catch (e, st) {
      _ref.read(activeCampaignLoadingProvider.notifier).state = false;
      debugPrint('Campaign load error: $e\n$st');
      return false;
    }
  }

  Future<bool> load(String name) async {
    beginLoad(name);
    return completeLoad();
  }

  Future<bool> create(String worldName, {WorldSchema? template}) async {
    try {
      // Defense-in-depth: an earlier `delete()` may have failed to orphan
      // chars (entity load error swallowed). Without scrubbing here, those
      // stale rows with `worldName == X` get adopted by the new world.
      try {
        await _ref
            .read(characterListProvider.notifier)
            .orphanForWorld(worldName);
      } catch (e, st) {
        debugPrint('orphan-before-create error: $e\n$st');
      }
      await _repo.create(worldName, template: template);
      return load(worldName);
    } catch (e, st) {
      debugPrint('Campaign create error: $e\n$st');
      return false;
    }
  }

  /// F6: `pushMirror` param retired — cloud sync is row-level via the
  /// outbox (entities F4, settings F3, map_data/sessions F3). This bulk
  /// save remains for trash restore / cloud restore safety nets where
  /// the diff is unknown.
  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  /// F2: row-level single-entity write. Skips legacy bulk `save`. Caller
  /// (EntityNotifier) is responsible for keeping the in-memory
  /// `_data['entities'][id]` map in sync; this method only touches the
  /// Drift row + bumps `worlds.updated_at`.
  Future<void> saveEntity(String entityId, Map<String, dynamic> row) async {
    final name = state;
    if (name == null) return;
    await _repo.saveEntity(name, entityId, row);
  }

  /// F2: row-level delete counterpart for [saveEntity].
  Future<void> deleteEntity(String entityId) async {
    final name = state;
    if (name == null) return;
    await _repo.deleteEntity(name, entityId);
  }

  /// F3: read-merge-write a subset of `world_settings.settings_json`.
  /// Repo decodes the existing JSON, applies [patch] keys on top, and
  /// re-encodes — touching only the one `world_settings` row. Caller
  /// (combat / mind_map / map) keeps the in-memory mirror in sync.
  ///
  /// F6 follow-up: when the world is online, also enqueue a
  /// `world_settings` outbox upsert with the full merged blob so the
  /// other-device CDC applier sees the change. Old bulk `_bundleAndPush`
  /// used to handle this; row-level world_settings push replaces it.
  Future<void> saveSettingsPatch(Map<String, dynamic> patch) async {
    final name = state;
    if (name == null) return;
    await _repo.saveSettingsPatch(name, patch);
    final data = _data;
    if (data == null) return;
    final worldId = data['world_id'] as String?;
    if (worldId == null) return;
    if (!_ref.read(onlineWorldIdsProvider).contains(worldId)) return;
    if (_ref.read(authProvider) == null) return;
    // Client-side DM gate. `_repo.saveSettingsPatch` above already wrote
    // Drift, so for a non-DM this degrades to local-only persistence — the
    // cloud outbox enqueue is skipped. Pre-empts the RLS 42501 rejection
    // spam on `world_settings` for PLAYER-role members.
    //
    // `worldRoleProvider` is worldId-keyed, depends only on authProvider (no
    // campaign dependency → no circular provider graph), and swallows errors
    // internally → WorldRole.none on failure. `.future` is awaited so the
    // gate is reliable on the first settings write after world-open, before
    // any roster has bootstrapped.
    final role = await _ref.read(worldRoleProvider(worldId).future);
    if (role != WorldRole.dm) return;
    // Build the full settings_json mirror (everything except typed top
    // keys and `entities`) so the cloud row contains the post-merge state.
    final settings = <String, dynamic>{};
    for (final entry in data.entries) {
      if (_settingsTopKeyBlocklist.contains(entry.key)) continue;
      settings[entry.key] = entry.value;
    }
    // ignore: discarded_futures
    _ref.read(syncEngineProvider).enqueueWorldSettings(
          worldId: worldId,
          settings: settings,
        );
  }

  /// Same as [saveSettingsPatch] minus the cloud enqueue. Motion-class
  /// field'lar (viewport pan/zoom, scroll position, ephemeral UI state)
  /// için — local Drift yazılır, outbox'a girmez. Cihaz dünyayı yeniden
  /// açtığında default viewport ile başlar; bilinçli karar — DM'in pan'ı
  /// oyuncuya yansımasın, başka cihazda ekran sıçramasın.
  Future<void> saveSettingsPatchLocalOnly(Map<String, dynamic> patch) async {
    final name = state;
    if (name == null) return;
    await _repo.saveSettingsPatch(name, patch);
    // bilerek enqueueWorldSettings çağrılmıyor — local-only motion class
  }

  /// Keys that live in their own typed table or aren't part of the
  /// `world_settings.settings_json` mirror.
  static const _settingsTopKeyBlocklist = {
    'world_id',
    'world_name',
    'created_at',
    'entities',
    'sessions',
    'world_schema',
    'template_id',
    'template_hash',
    'template_original_hash',
  };

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
    // Karakter bağını kopar (önce orphan): bkz. eski yorum bloğu.
    Map<String, dynamic>? data;
    try {
      if (state == campaignName && _data != null) {
        data = _data;
      } else {
        data = await _repo.load(campaignName);
      }
    } catch (e, st) {
      debugPrint('orphan-before-delete load error: $e\n$st');
    }
    final entitiesRaw = data?['entities'];
    final entitiesMap = entitiesRaw is Map<String, dynamic>
        ? entitiesRaw
        : (entitiesRaw is Map ? Map<String, dynamic>.from(entitiesRaw) : null);
    try {
      await _ref
          .read(characterListProvider.notifier)
          .orphanForWorld(campaignName, entitiesMap);
    } catch (e, st) {
      debugPrint('orphan-before-delete error: $e\n$st');
    }
    // Yeni sıra: cloud önce, sonra lokal. Cloud silinmezse rethrow et —
    // UI lokal silmeyi iptal eder, refresh ile dünyanın geri gelmesini
    // önler.
    await _cloudDeleteWorld(
      worldId: data?['world_id'] as String?,
      campaignName: campaignName,
    );
    await _repo.delete(campaignName);
    if (state == campaignName) {
      _data = null;
      state = null;
    }
  }

  /// Hard delete — bypasses trash. Used when the user leaves an online
  /// world (or gets kicked): the local mirror is wiped immediately, the
  /// world disappears from the hub, and there is no `.trash/` entry to
  /// restore from later.
  ///
  /// Before wiping, walks every local character bound to this world and
  /// rewrites their SRD-derived entity refs (species/class/trait/action/…)
  /// from this world's UUIDs to the bundled builtin-SRD stable UUIDs. The
  /// world's SRD copies share (slug, name) with the builtin pack, so the
  /// stable v5 id derived from that pair re-anchors the character's refs
  /// to a map that survives the purge. Custom DM-authored entities have
  /// no builtin counterpart and are left as unresolvable orphans.
  Future<void> purge(String campaignName) async {
    Map<String, dynamic>? data;
    try {
      if (state == campaignName && _data != null) {
        data = _data;
      } else {
        data = await _repo.load(campaignName);
      }
    } catch (e, st) {
      debugPrint('orphan-before-purge load error: $e\n$st');
    }
    final entitiesRaw = data?['entities'];
    final entitiesMap = entitiesRaw is Map<String, dynamic>
        ? entitiesRaw
        : (entitiesRaw is Map ? Map<String, dynamic>.from(entitiesRaw) : null);
    try {
      await _ref
          .read(characterListProvider.notifier)
          .orphanForWorld(campaignName, entitiesMap);
    } catch (e, st) {
      debugPrint('orphan-before-purge error: $e\n$st');
    }
    await _repo.purge(campaignName);
    if (state == campaignName) {
      _data = null;
      state = null;
    }
    await _cloudDeleteWorld(worldId: data?['world_id'] as String?, campaignName: campaignName);
  }

  /// Removes the world's footprint from Supabase: drops the `worlds` row
  /// (cascade clears every mirror table) when the world was online, and
  /// enqueues a `cloud_backup_world` delete so the manual snapshot (if
  /// any) is removed too. Best-effort — failures don't block the local
  /// delete that already happened.
  Future<void> _cloudDeleteWorld({
    required String? worldId,
    required String campaignName,
  }) async {
    if (_ref.read(authProvider) == null) return;
    final wid = worldId ?? campaignName;
    final wasOnline = _ref.read(onlineWorldIdsProvider).contains(wid);
    // Cloud row var mı diye kontrol et — wasOnline set'i stale olabilir
    // (publish edildi ama set güncellenmedi). Cloud'da satır varsa
    // silmeyi zorla dene; yoksa skip.
    final hasCloudRow = wasOnline || await _cloudHasWorld(wid);
    if (!hasCloudRow) return;
    // Başarısız olursa rethrow — caller lokal silmeyi iptal eder.
    await _ref.read(worldMembershipServiceProvider).unpublishWorld(wid);
    _ref.read(onlineWorldIdsProvider.notifier).remove(wid);
  }

  Future<bool> _cloudHasWorld(String worldId) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final row = await Supabase.instance.client
          .from('worlds')
          .select('id')
          .eq('id', worldId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('cloud-has-world check error: $e');
      return false;
    }
  }
}

final activeCampaignProvider =
    StateNotifierProvider<ActiveCampaignNotifier, String?>((ref) {
      return ActiveCampaignNotifier(ref.watch(campaignRepositoryProvider), ref);
    });

/// Trash'teki silinen kampanyalar + paketler + karakterler. v12: Drift
/// `trash_items` tablosu — kind ∈ {'world','package','character'}.
final trashListProvider = FutureProvider<List<TrashItem>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = <drift_db.TrashItem>[
    ...await db.trashDao.getByKind('world'),
    ...await db.trashDao.getByKind('package'),
    ...await db.trashDao.getByKind('character'),
  ];
  rows.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  return rows.map((r) {
    Map<String, dynamic> payload = const {};
    try {
      final decoded = jsonDecode(r.payloadJson);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    String originalName;
    switch (r.kind) {
      case 'character':
        originalName = (payload['_original_name'] as String?) ??
            ((payload['entity'] as Map<String, dynamic>?)?['name']
                as String?) ??
            r.sourceId;
      case 'package':
        originalName = (payload['_original_name'] as String?) ??
            (payload['package_name'] as String?) ??
            r.sourceId;
      default:
        originalName = (payload['world_name'] as String?) ??
            (payload['name'] as String?) ??
            r.sourceId;
    }
    final type = switch (r.kind) {
      'world' => 'World',
      'package' => 'Package',
      'character' => 'Character',
      _ => r.kind,
    };
    return TrashItem(
      id: r.id,
      originalName: originalName,
      type: type,
      deletedAt: r.deletedAt,
      kind: r.kind,
      payload: payload,
    );
  }).toList();
});
