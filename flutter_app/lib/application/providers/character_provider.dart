import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/error_format.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/pending_release_repository.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../../domain/services/character_resolver.dart';
import '../services/builtin_srd_entities.dart';
import '../services/character_migration_service.dart';
import 'auth_provider.dart';
import 'beta_provider.dart';
import 'campaign_provider.dart';
import 'character_claim_provider.dart';
import 'cloud_backup_provider.dart';
import 'entity_provider.dart';
import 'online_worlds_provider.dart';
import 'role_provider.dart';
import 'sync_engine_provider.dart';
import 'world_characters_provider.dart';

const _uuid = Uuid();

/// Category slugs treated as a "Player" category for character creation
/// purposes. `player-character` is the 2024 builtin v2 schema slug;
/// `player` is the legacy default schema slug. Wizard + character editor
/// accept either.
const kPlayerCategorySlugs = ['player-character', 'player'];

/// Legacy single-slug constant — kept so older call-sites keep working.
/// Prefer [kPlayerCategorySlugs] + [findPlayerCategory] for new code.
const playerCategorySlug = 'player-character';

/// Resolve a Player-like category from a template, or null if absent.
EntityCategorySchema? findPlayerCategory(WorldSchema template) {
  for (final slug in kPlayerCategorySlugs) {
    final cat = template.categories.where((c) => c.slug == slug).firstOrNull;
    if (cat != null) return cat;
  }
  return null;
}

final characterRepositoryProvider = Provider<CharacterRepository>(
    (ref) => CharacterRepository(ref.watch(appDatabaseProvider)));

/// One-shot JSON → Drift migration service (PR-SYNC-0). Backfills the
/// `characters` Drift table from `AppPaths.charactersDir/*.json` on the
/// first cold start after the v9 schema upgrade. Idempotent via a
/// per-user SharedPreferences flag.
final characterMigrationServiceProvider =
    Provider<CharacterMigrationService>((ref) =>
        CharacterMigrationService(ref.watch(appDatabaseProvider)));

/// Offline char tab "Release" akışı için sidecar queue. Online olununca
/// `CharacterListNotifier.drainPendingReleases` çağrılır.
final pendingReleasesProvider =
    Provider<PendingReleaseRepository>((_) => PendingReleaseRepository());

/// Hub-level karakter listesi. Senkron kalsın diye StateNotifier.
class CharacterListNotifier extends StateNotifier<AsyncValue<List<Character>>> {
  CharacterListNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    _load();
    // Auth transition (offline → signed in): pre-existing worldless chars
    // had `ownerId == null` and would otherwise become invisible under the
    // own-only char tab filter. Adopt them on first auth.
    _ref.listen(authProvider, (prev, next) {
      if (prev == null && next != null) {
        // ignore: discarded_futures
        _backfillWorldlessOwnership(next.uid);
        // Sign-in → server'a ulaşabiliyoruz; offline'da biriken release'leri
        // boşalt. drainPendingReleases idempotent.
        // ignore: discarded_futures
        drainPendingReleases();
        // ignore: discarded_futures
        pullNewerFromCloud();
      }
    });
    // Legacy `worldName` → `worldId` migration: campaign listesi yüklendiğinde
    // henüz worldId set olmayan karakterleri resolve eder. PR4 cleanup: artık
    // worldId canonical.
    _ref.listen(campaignInfoListProvider, (_, next) {
      final infos = next.valueOrNull;
      if (infos == null || infos.isEmpty) return;
      // ignore: discarded_futures
      _backfillWorldIds(infos);
    });
    // Online world set changed: pending release queue (user explicitly
    // released a char while offline) drained on first transition. Auto-push
    // of edited chars kaldırıldı — kullanıcı manuel Sync butonu ile push'lar.
    _ref.listen(onlineWorldIdsProvider, (prev, next) {
      final prevSet = prev ?? const <String>{};
      final added = next.difference(prevSet);
      if (added.isEmpty) return;
      if (prevSet.isEmpty) {
        // ignore: discarded_futures
        drainPendingReleases();
      }
    });
  }

  final CharacterRepository _repo;
  final Ref _ref;

  /// Unified sync entry point. Routes a char to the right backend:
  ///   - World is online → `world_characters` mirror (real-time, RLS-gated).
  ///   - Beta + (worldless or world offline) → `cloud_backup` snapshot
  ///     (last-write-wins by item_id+type).
  ///   - Non-beta + (worldless or world offline) → local only, no push.
  void _syncPush(Character c) {
    _mirrorPush(c);
    _cloudBackupPush(c);
  }

  void _syncDelete(String characterId, {String? worldId}) {
    _mirrorDelete(characterId, worldId: worldId);
    _cloudBackupDelete(characterId);
  }

  /// world_characters mirror push — runs whenever the char's world is in
  /// `onlineWorldIdsProvider`, regardless of beta. RLS enforces ownership.
  /// Routed through the [SyncEngine] outbox so retries survive app restarts.
  void _mirrorPush(Character c) {
    final worldId = c.worldId;
    if (worldId == null) return;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return;
    if (_ref.read(authProvider) == null) return;
    // Optimistic apply into the world view — WorldCharactersView reads from
    // `worldCharactersProvider`, which is independent of the hub char list
    // and only gets populated by CDC echoes. Without this, a freshly
    // created char doesn't appear in its world until the outbox drains and
    // realtime echoes back (seconds-to-minutes if the network is slow).
    _ref.read(worldCharactersProvider(worldId).notifier).applyMirror(
          WorldCharacterRow(
            id: c.id,
            worldId: worldId,
            ownerId: c.ownerId,
            templateId: c.templateId,
            templateName: c.templateName,
            payloadJson: jsonEncode(c.toJson()),
            updatedAt: DateTime.tryParse(c.updatedAt)?.toUtc() ??
                DateTime.now().toUtc(),
          ),
        );
    // ignore: discarded_futures
    _ref.read(syncEngineProvider).enqueueWorldCharacterUpsert(
          worldId: worldId,
          character: c,
        );
  }

  void _mirrorDelete(String characterId, {String? worldId}) {
    final wid = worldId;
    if (wid == null) return;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(wid)) return;
    if (_ref.read(authProvider) == null) return;
    _ref.read(worldCharactersProvider(wid).notifier).removeMirror(characterId);
    // ignore: discarded_futures
    _ref.read(syncEngineProvider).enqueueWorldCharacterDelete(
          characterId: characterId,
          worldId: wid,
        );
  }

  /// Beta-gated cloud_backup auto-sync — uploads a per-char snapshot when the
  /// char is NOT covered by the world_characters mirror (worldless or world
  /// offline). Routed through the [SyncEngine] outbox so retries survive app
  /// restarts; engine itself enforces the beta gate before uploading.
  void _cloudBackupPush(Character c) {
    if (!_ref.read(isBetaActiveProvider)) return;
    if (_ref.read(authProvider) == null) return;
    final wid = c.worldId;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    // Mirror handles online-world chars; cloud_backup is for the rest.
    if (wid != null && onlineIds.contains(wid)) return;
    // World-bound but offline → user opted out of cloud entirely for this
    // world; no auto-backup of its characters.
    if (wid != null) return;
    // ignore: discarded_futures
    _ref.read(syncEngineProvider).enqueueCloudBackupUpsert(
          itemId: c.id,
          itemName: c.entity.name.isEmpty ? c.id : c.entity.name,
          type: 'character',
          data: {'character': c.toJson()},
        );
  }

  /// Cloud-newer pull for the character list. Compares each cloud_backup
  /// 'character' meta's `createdAt` to the local char's `updatedAt`; if cloud
  /// is newer or the char is cloud-only, downloads + `applyMirror`'s the row.
  /// Best-effort; auth/network errors are swallowed.
  Future<void> pullNewerFromCloud() async {
    if (!_ref.read(isBetaActiveProvider)) return;
    if (_ref.read(authProvider) == null) return;
    final repo = _ref.read(cloudBackupRepositoryProvider);
    try {
      final metas = await repo.listBackupsByType('character');
      final localById = <String, Character>{
        for (final c in state.valueOrNull ?? const <Character>[]) c.id: c,
      };
      for (final meta in metas) {
        final local = localById[meta.itemId];
        if (local != null) {
          final localAt = DateTime.tryParse(local.updatedAt);
          if (localAt != null && !meta.createdAt.isAfter(localAt)) continue;
        }
        try {
          final data = await repo.downloadBackup(meta.id);
          final raw = data['character'];
          if (raw is! Map<String, dynamic>) continue;
          final c = Character.fromJson(raw);
          await applyMirror(c);
        } catch (e) {
          if (isStorageNotFound(e)) {
            // Orphan meta — storage file is gone; drop the table row so the
            // next catch-up doesn't retry it forever.
            try {
              await repo.deleteOrphanedMeta(meta.id);
            } catch (_) {/* ignore */}
            continue;
          }
          debugPrint('pull char from cloud error: $e');
        }
      }
    } catch (e) {
      debugPrint('listBackupsByType char error: $e');
    }
  }

  /// Targeted freshness pull for a single character on editor open. Routes
  /// by storage class:
  ///   - World-bound → `world_characters` row (DB source of truth for
  ///     online worlds; matches the mirror push side).
  ///   - Worldless → `cloud_backups` snapshot.
  /// Skips silently when local is at least as new as remote.
  Future<void> pullCharFromCloudIfNewer(String characterId) async {
    if (_ref.read(authProvider) == null) return;
    final list = state.valueOrNull ?? const <Character>[];
    final local = list.where((c) => c.id == characterId).firstOrNull;
    final wid = local?.worldId;
    if (wid != null) {
      await _pullCharFromMirror(characterId, local: local);
      return;
    }
    if (!_ref.read(isBetaActiveProvider)) return;
    final repo = _ref.read(cloudBackupRepositoryProvider);
    try {
      final meta = await repo.fetchByItem(characterId, 'character');
      if (meta == null) return;
      if (local != null) {
        final localAt = DateTime.tryParse(local.updatedAt);
        if (localAt != null && !meta.createdAt.isAfter(localAt)) return;
      }
      final data = await repo.downloadBackup(meta.id);
      final raw = data['character'];
      if (raw is! Map<String, dynamic>) return;
      final c = Character.fromJson(raw);
      await applyMirror(c);
    } catch (e) {
      if (isStorageNotFound(e)) {
        debugPrint('pullCharFromCloudIfNewer: storage missing for $characterId');
        return;
      }
      debugPrint('pullCharFromCloudIfNewer error: $e');
    }
  }

  Future<void> _pullCharFromMirror(
    String characterId, {
    required Character? local,
  }) async {
    final svc = _ref.read(characterClaimServiceProvider);
    if (svc == null) return;
    try {
      final row = await svc.fetchWorldCharacter(characterId);
      if (row == null) return;
      if (local != null) {
        final localAt = DateTime.tryParse(local.updatedAt);
        if (localAt != null && !row.updatedAt.isAfter(localAt)) return;
      }
      final decoded = jsonDecode(row.payloadJson);
      if (decoded is! Map<String, dynamic>) return;
      final fresh = Character.fromJson(decoded).copyWith(
        worldId: row.worldId,
        ownerId: row.ownerId,
        templateId: row.templateId,
        templateName: row.templateName,
        updatedAt: row.updatedAt.toUtc().toIso8601String(),
      );
      await applyMirror(fresh);
      _ref.read(worldCharactersProvider(row.worldId).notifier).applyMirror(row);
    } catch (e) {
      debugPrint('_pullCharFromMirror error: $e');
    }
  }

  /// Awaitable enqueue for editor-close. Mirror-route chars (online world)
  /// get their push via `_mirrorPush` already; for the cloud_backup branch
  /// we just make sure the outbox row exists before the screen unmounts.
  /// The actual upload is async on the [SyncEngine]; awaiting `forceTick()`
  /// would block the editor close on the network so we don't.
  Future<void> flushCloudBackup(String characterId) async {
    if (!_ref.read(isBetaActiveProvider)) return;
    if (_ref.read(authProvider) == null) return;
    final list = state.valueOrNull;
    if (list == null) return;
    final c = list.where((x) => x.id == characterId).firstOrNull;
    if (c == null) return;
    final wid = c.worldId;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (wid != null && onlineIds.contains(wid)) return;
    // World-bound but offline → no cloud_backup auto-flush either.
    if (wid != null) return;
    await _ref.read(syncEngineProvider).enqueueCloudBackupUpsert(
          itemId: c.id,
          itemName: c.entity.name.isEmpty ? c.id : c.entity.name,
          type: 'character',
          data: {'character': c.toJson()},
        );
  }

  void _cloudBackupDelete(String characterId) {
    if (!_ref.read(isBetaActiveProvider)) return;
    if (_ref.read(authProvider) == null) return;
    // ignore: discarded_futures
    _ref.read(syncEngineProvider).enqueueCloudBackupDelete(
          itemId: characterId,
          type: 'character',
        );
  }

  /// DEPRECATED no-op — 039 model `world_characters` RLS cross-device sync
  /// sağlar. Sığ shim'ler PR5'te tamamen kaldırılacak; şimdilik mevcut UI
  /// call site'larını bozmaz.
  @Deprecated('No-op; world_characters RLS handles sync')
  Future<void> makeOnline(String id) async {}

  @Deprecated('No-op; world_characters RLS handles sync')
  Future<void> makeOffline(String id) async {}

  @Deprecated('No-op; world_characters RLS handles sync')
  Future<void> ensureOnline(String id) async {}

  @Deprecated('Always true; auto-online implicit')
  bool isAutoOnline(String id) => true;

  /// Disk'ten yüklenen Character JSON'larından strip edilen legacy
  /// `world_name` field'larını id'leri ile saklar. Campaign listesi
  /// yüklendiğinde `_backfillWorldIds` bu haritadan resolve eder.
  Map<String, String> _legacyWorldNames = const {};

  /// Campaign listesi yüklendiğinde legacy `worldName`-only karakterleri
  /// `worldId`'ye migrate eder. Idempotent — eşleşen entry pop edilir.
  Future<void> _backfillWorldIds(List<dynamic> infos) async {
    if (_legacyWorldNames.isEmpty) return;
    final list = state.valueOrNull;
    if (list == null || list.isEmpty) return;
    final nameToId = <String, String>{};
    for (final info in infos) {
      final name = (info as dynamic).name as String;
      final id = (info as dynamic).id as String;
      nameToId[name] = id;
    }
    final out = [...list];
    final remainingLegacy = Map<String, String>.from(_legacyWorldNames);
    var changed = false;
    for (var i = 0; i < out.length; i++) {
      final c = out[i];
      if (c.worldId != null) {
        remainingLegacy.remove(c.id);
        continue;
      }
      final legacyName = remainingLegacy[c.id];
      if (legacyName == null) continue;
      final id = nameToId[legacyName];
      if (id == null) continue;
      final patched = c.copyWith(worldId: id);
      try {
        await _repo.save(patched);
      } catch (e) {
        debugPrint('backfill worldId save error: $e');
        continue;
      }
      out[i] = patched;
      remainingLegacy.remove(c.id);
      changed = true;
      _syncPush(patched);
    }
    _legacyWorldNames = remainingLegacy;
    if (changed) state = AsyncValue.data(out);
  }

  Future<void> _load() async {
    try {
      // PR-SYNC-0: run the one-shot JSON → Drift backfill before the first
      // load. Idempotent via per-user SharedPreferences flag, so steady-state
      // cold starts skip straight through.
      try {
        final svc = _ref.read(characterMigrationServiceProvider);
        await svc.migrateFromJsonIfNeeded();
        // PR-SYNC-6: delete legacy JSON snapshots after the migration
        // committed (idempotent via separate flag).
        await svc.cleanupLegacyJsonIfNeeded();
      } catch (e) {
        debugPrint('character JSON→Drift migration failed: $e');
      }
      final loaded = await _repo.loadAllWithLegacy();
      _legacyWorldNames = loaded.legacyWorldNames;
      state = AsyncValue.data(loaded.chars);
      final auth = _ref.read(authProvider);
      if (auth != null) {
        await _backfillWorldlessOwnership(auth.uid);
      }
      // Cold-start push sweep kaldırıldı (manuel save+sync modeli).
      // Cloud catch-up pull yine çalışır — `cloudCatchupServiceProvider`
      // app startup'ta runAll() ile tetikler; bu satır da redundant ama
      // ucuz no-op olduğu için bırakıldı.
      // ignore: discarded_futures
      pullNewerFromCloud();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Adopt pre-existing chars on local disk that have no `ownerId`. Local
  /// char files were created by this user on this device, so under the
  /// "creator owns" policy we claim them all on first sign-in — worldless
  /// and world-bound alike. Without this, world-bound chars created
  /// pre-auth (or under the old DM-null policy) would render with an
  /// empty owner on the card.
  ///
  /// Adopted rows are also mirror-pushed so the user's other devices
  /// receive them — without this, signing in on a new device produced an
  /// empty char tab even though the first device just claimed the rows.
  Future<void> _backfillWorldlessOwnership(String uid) async {
    final list = state.valueOrNull;
    if (list == null || list.isEmpty) return;
    final out = [...list];
    final adopted = <Character>[];
    for (var i = 0; i < out.length; i++) {
      final c = out[i];
      if (c.ownerId != null) continue;
      final patched = c.copyWith(ownerId: uid);
      try {
        await _repo.save(patched);
      } catch (e) {
        debugPrint('backfill ownership save error: $e');
        continue;
      }
      out[i] = patched;
      adopted.add(patched);
    }
    if (adopted.isEmpty) return;
    state = AsyncValue.data(out);
    for (final c in adopted) {
      _syncPush(c);
    }
  }

  Future<void> refresh() => _load();

  /// Offline'da char tab "Release" akışında ownerId-null-only patch
  /// uygulayanları server'a aktarır. `release_character` RPC zaten
  /// idempotent — duplicate çağrı no-op. Hata olursa entry queue'da kalır,
  /// sonraki online transition'ında tekrar denenir.
  Future<void> drainPendingReleases() async {
    final svc = _ref.read(characterClaimServiceProvider);
    if (svc == null) return;
    final repo = _ref.read(pendingReleasesProvider);
    final ids = await repo.load();
    for (final id in ids) {
      try {
        await svc.release(id);
        await repo.remove(id);
      } catch (e) {
        debugPrint('drain release error for $id: $e');
      }
    }
  }

  /// Granular insert/update from realtime mirror. Persists to disk and
  /// patches the in-memory list in place — avoids the
  /// `invalidate(characterListProvider)` storm which would `loadAll()` from
  /// disk on every CDC event.
  Future<void> applyMirror(Character c) async {
    try {
      await _repo.save(c);
    } catch (e) {
      debugPrint('applyMirror save error: $e');
      return;
    }
    final list = [...(state.valueOrNull ?? const <Character>[])];
    final idx = list.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      list[idx] = c;
    } else {
      list.insert(0, c);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncValue.data(list);
  }

  /// Granular delete from realtime mirror — disk + state in one shot, no
  /// full-list reload.
  Future<void> removeMirror(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final existing = list.where((c) => c.id == id).firstOrNull;
    if (existing == null) return;
    try {
      await _repo.delete(id, displayName: existing.entity.name);
    } catch (e) {
      debugPrint('removeMirror delete error: $e');
    }
    state = AsyncValue.data(list.where((c) => c.id != id).toList());
  }

  Future<Character> create({
    required String name,
    required WorldSchema template,
    String? worldId,
    String description = '',
    List<String> tags = const [],
    String portraitPath = '',
    Map<String, dynamic> seedFields = const {},
    String? ownerId,
  }) async {
    final playerCategory = findPlayerCategory(template);
    if (playerCategory == null) {
      throw StateError(
          'Template "${template.name}" has no Player category.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final fields = _defaultFieldsFor(playerCategory);
    for (final entry in seedFields.entries) {
      fields[entry.key] = entry.value;
    }
    final entity = Entity(
      id: _uuid.v4(),
      name: name,
      categorySlug: playerCategory.slug,
      description: description,
      imagePath: portraitPath,
      tags: tags,
      fields: fields,
    );
    // Auth-always invariant (039+): yaratan kişi owner olur. Offline'da bile
    // hesap açıktır, ownerId her zaman dolu. Caller yine de explicit ownerId
    // geçebilir (örn. DM seed unclaimed → null, RLS DM branch ile geçer).
    final effectiveOwnerId = ownerId ?? _resolveOwnerId();
    final character = Character(
      id: _uuid.v4(),
      templateId: template.schemaId,
      templateName: template.name,
      entity: entity,
      worldId: worldId,
      ownerId: effectiveOwnerId,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(character);
    state = AsyncValue.data([character, ...state.valueOrNull ?? const []]);
    _syncPush(character);
    return character;
  }

  /// Resolves the owner_id for a freshly created character.
  ///
  /// - No auth (pure offline) → null.
  /// - Authenticated → auth.uid. Creator becomes owner irrespective of
  ///   world binding; DM-seeded unclaimed chars pass `ownerId: null`
  ///   explicitly.
  String? _resolveOwnerId() {
    final auth = _ref.read(authProvider);
    if (auth == null) return null;
    return auth.uid;
  }

  /// Bir world'de template güncellenince o world'e bağlı karakterlerin
  /// `entity.fields`'i yeni Player kategorisine göre haritalanır: yeni
  /// alanlara default, kaldırılan alanlar düşürülür.
  Future<void> applyTemplateUpdate({
    required String worldId,
    required WorldSchema newTemplate,
  }) async {
    final playerCat = findPlayerCategory(newTemplate);
    if (playerCat == null) return;
    final list = [...(state.valueOrNull ?? const <Character>[])];
    final defaults = _defaultFieldsFor(playerCat);
    final allowedKeys = playerCat.fields.map((f) => f.fieldKey).toSet();
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      if (c.worldId != worldId) continue;
      final merged = <String, dynamic>{};
      for (final key in allowedKeys) {
        merged[key] = c.entity.fields.containsKey(key)
            ? c.entity.fields[key]
            : defaults[key];
      }
      final bumped = c.copyWith(
        entity: c.entity.copyWith(fields: merged),
        templateId: newTemplate.schemaId,
        templateName: newTemplate.name,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _repo.save(bumped);
      list[i] = bumped;
      changed = true;
    }
    if (changed) state = AsyncValue.data(list);
  }

  Future<void> update(Character character) async {
    final bumped = character.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _repo.save(bumped);
    final list = [...(state.valueOrNull ?? const <Character>[])];
    final idx = list.indexWhere((c) => c.id == bumped.id);
    if (idx >= 0) {
      list[idx] = bumped;
    } else {
      list.insert(0, bumped);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncValue.data(list);
    _syncPush(bumped);
  }

  /// Partial metadata update — name/description/tags/cover/rename combined.
  /// Tüm metadata entity alanlarına yazılır (entity_card ile ortak kaynak).
  Future<void> updateMetadata({
    required String id,
    String? name,
    String? description,
    List<String>? tags,
    String? coverImagePath,
  }) async {
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    final patched = c.copyWith(
      entity: c.entity.copyWith(
        name: name ?? c.entity.name,
        description: description ?? c.entity.description,
        tags: tags ?? c.entity.tags,
        imagePath: coverImagePath ?? c.entity.imagePath,
      ),
    );
    await update(patched);
  }

  /// Player a world'den ayrıldığında (leave / kick / DM-delete) çağrılır:
  /// world'ün entity blob'unu okur, her char ref'ini builtin SRD'nin stable
  /// UUID'sine çevirir (slug+name eşleşmesiyle), worldId'yi temizler ve
  /// karakteri kaydeder. Böylece world purge sonrası orphan karakterlerin
  /// Species/Class/Trait/Action refleri builtin SRD üzerinden çözülür.
  ///
  /// [worldEntitiesRaw]: campaign data'sının `entities` alt-map'i. Null veya
  /// boş geçilebilir — entity remap atlanır ama `worldId` her durumda
  /// temizlenir.
  Future<void> orphanForWorld(
    String worldId, [
    Map<String, dynamic>? worldEntitiesRaw,
  ]) async {
    if (worldId.isEmpty) return;
    final list = state.valueOrNull ?? const <Character>[];
    final affected = list.where((c) => c.worldId == worldId).toList();
    if (affected.isEmpty) return;

    final remap = <String, String>{};
    if (worldEntitiesRaw != null && worldEntitiesRaw.isNotEmpty) {
      final builtin = _ref.read(builtinSrdEntitiesProvider);
      worldEntitiesRaw.forEach((entityId, raw) {
        if (raw is! Map) return;
        final slug = (raw['type'] as String?)?.trim();
        final name = (raw['name'] as String?)?.trim();
        if (slug == null || slug.isEmpty) return;
        if (name == null || name.isEmpty) return;
        final stableId = srdStableEntityId(slug, name);
        if (builtin.containsKey(stableId)) {
          remap[entityId] = stableId;
        }
      });
    }

    for (final c in affected) {
      final rewritten = remap.isEmpty
          ? c.entity.fields
          : _rewriteRefs(c.entity.fields, remap) as Map<String, dynamic>;
      final patched = c.copyWith(
        worldId: null,
        entity: c.entity.copyWith(fields: rewritten),
      );
      await update(patched);
    }
  }

  static dynamic _rewriteRefs(dynamic value, Map<String, String> remap) {
    if (remap.isEmpty) return value;
    if (value is String) return remap[value] ?? value;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _rewriteRefs(v, remap);
      });
      return out;
    }
    if (value is List) {
      return value.map((e) => _rewriteRefs(e, remap)).toList();
    }
    return value;
  }

  /// Char Tab "Delete/Release" action point. Spec: owner-delete-from-char-tab
  /// drops OWNER, not world. World tarafı `_dmDelete` ile koparılır.
  ///
  /// Online router:
  ///   - world-bound: `release_character` RPC. Server-side branch:
  ///       * (me, W) → (NULL, W) UPDATE — char tab'dan kaybolur, world'de kalır
  ///       * (me, NULL) → DELETE — CHECK violation olurdu, RPC siler
  ///     `deleted: false` → local'i ownerId=null patch et, dosya kalır.
  ///     `deleted: true` (race) → local trash'e düşür.
  ///   - orphan (worldsuz): `delete_character` RPC → hard delete + trash.
  ///
  /// Offline router:
  ///   - world-bound: local-only `ownerId = null` patch; row dosyada kalır.
  ///     Pending release queue'ya eklenir (Step 6) — online olunca drain edilir.
  ///   - worldsuz: doğrudan local trash'e düşür.
  Future<void> delete(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final existing = list.where((c) => c.id == id).firstOrNull;
    if (existing == null) return;
    final svc = _ref.read(characterClaimServiceProvider);
    final isWorldBound = existing.worldId != null;

    if (svc != null) {
      try {
        if (isWorldBound) {
          final result = await svc.release(id);
          if (!result.deleted) {
            // Server (NULL, W) yaptı — local'i ownerId=null patch et,
            // worldId / worldName aynen kalır. Char tab own-only filter'ı
            // sayesinde karakter kaybolur; world view'da görünür kalır.
            final patched = existing.copyWith(
              ownerId: null,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            );
            await _repo.save(patched);
            final out = [...list];
            final idx = out.indexWhere((c) => c.id == id);
            if (idx >= 0) {
              out[idx] = patched;
            }
            out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            state = AsyncValue.data(out);
            return;
          }
          // result.deleted = true → server (me, NULL) idi, row silindi.
          // Local cleanup'a düş.
        } else {
          await svc.deleteCharacter(id);
        }
      } catch (e) {
        debugPrint('delete RPC error: $e');
        // Local cleanup'a düş — kullanıcının cihazında en azından silinsin.
      }
    } else if (isWorldBound) {
      // Offline + world-bound: server'a ulaşamıyoruz, ownerId'yi local
      // olarak temizle ve queue'ya at. Karakter dosyası kalır; world görür
      // edebilen başka bir cihaz CDC ile (NULL, W)'i öğrenecek.
      final patched = existing.copyWith(
        ownerId: null,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _repo.save(patched);
      final out = [...list];
      final idx = out.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        out[idx] = patched;
      }
      out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = AsyncValue.data(out);
      try {
        await _ref.read(pendingReleasesProvider).add(id);
      } catch (e) {
        debugPrint('pending release queue add error: $e');
      }
      return;
    }

    final displayName = existing.entity.name;
    await _repo.delete(id, displayName: displayName);
    state = AsyncValue.data(list.where((c) => c.id != id).toList());
    _syncDelete(id, worldId: existing.worldId);
  }

  /// Local Character'in `worldId`'sini boşaltır. world_characters DB
  /// satırının yok olduğu durumlarda (CDC DELETE event veya kendi initiate
  /// ettiğimiz remove-from-world) çağrılır — local char dosyası kalır,
  /// sadece world bağı kopar. `update()` yolundan geçtiği için cross-device
  /// sync push'u tetiklenir; owner'ın diğer cihazlarına da yansır.
  Future<void> detachFromWorld(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null || c.worldId == null) return;
    await update(c.copyWith(worldId: null));
  }

  /// Trash'ten karakteri geri yükle. UI tarafı settings_tab'tan çağırır.
  Future<void> restoreFromTrash(String trashDirName) async {
    final restored = await _repo.restoreFromTrash(trashDirName);
    if (restored == null) return;
    final list = [...(state.valueOrNull ?? const <Character>[])];
    final idx = list.indexWhere((c) => c.id == restored.id);
    if (idx >= 0) {
      list[idx] = restored;
    } else {
      list.insert(0, restored);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncValue.data(list);
  }
}

final characterListProvider = StateNotifierProvider<CharacterListNotifier,
    AsyncValue<List<Character>>>((ref) {
  return CharacterListNotifier(ref.watch(characterRepositoryProvider), ref);
});

/// H3: characters tab "Recents-first" listesi. Sort `updatedAt` DESC
/// üzerinde çalışır ve Riverpod identity-cache'i sayesinde
/// `characterListProvider` değişmediği sürece aynı `List` instance'ı
/// döner — `CharactersTab` her hub-rebuild'inde `[...all]..sort` yapmaz.
final sortedCharactersProvider = Provider<List<Character>>((ref) {
  final list =
      ref.watch(characterListProvider).valueOrNull ?? const <Character>[];
  final out = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return List<Character>.unmodifiable(out);
});

/// DEPRECATED — 039 model `world_characters` RLS ile owner-set chars'ı
/// cross-device otomatik sync eder. Bu provider eski Make Online/Offline
/// toggle'ı UI'da gizlemek için kullanılıyordu; her durumda `true` döner →
/// toggle gizlenir. PR5'te provider tamamen kaldırılacak.
@Deprecated('Personal sync retired in 039+; world_characters RLS handles cross-device sync')
final autoOnlineForCharacterProvider =
    Provider.family<bool, String>((ref, id) => true);

/// Tek bir karakteri ID ile döndürür — editor ekran için.
final characterByIdProvider = Provider.family<Character?, String>((ref, id) {
  final list = ref.watch(characterListProvider).valueOrNull;
  if (list != null) {
    for (final c in list) {
      if (c.id == id) return c;
    }
  }
  // Fallback: world view rows (other players' chars, or own chars on a
  // device where the JSON→Drift backfill hasn't seeded the hub list yet).
  // Decode the `world_characters.payload_json` into a Character on demand.
  final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
  if (worldId == null) return null;
  final rows = ref.watch(worldCharactersProvider(worldId)).valueOrNull;
  if (rows == null) return null;
  final row = rows.where((r) => r.id == id).firstOrNull;
  if (row == null) return null;
  try {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, dynamic>) return null;
    return Character.fromJson(decoded).copyWith(
      worldId: row.worldId,
      ownerId: row.ownerId,
      templateId: row.templateId,
      templateName: row.templateName,
      updatedAt: row.updatedAt.toUtc().toIso8601String(),
    );
  } catch (e) {
    debugPrint('characterByIdProvider fallback decode error: $e');
    return null;
  }
});

/// Read-time resolved view of a character: applies feat effects, class
/// features by level, equipment choice resolutions, etc. Recomputes when
/// either the character entity or the campaign-wide entity map changes.
///
/// Returns null when the character is missing.
final effectiveCharacterProvider =
    Provider.family<EffectiveCharacter?, String>((ref, id) {
  final pc = ref.watch(characterByIdProvider(id));
  if (pc == null) return null;
  // Worldless characters resolve against the bundled SRD map. World-bound
  // characters merge the campaign on top so authored overrides win, with
  // builtin filling in any Tier-0 lookup the campaign hasn't seeded.
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  final Map<String, Entity> entities;
  if (pc.worldId == null) {
    entities = builtin;
  } else {
    final campaign = ref.watch(entityProvider);
    entities = campaign.isEmpty ? builtin : {...builtin, ...campaign};
  }
  return CharacterResolver.resolve(pc, entities);
});

/// Player kategorisi field'ları için default değer üretir.
/// `entity_provider.dart`'daki mantığın küçük bir kopyası — karakterler
/// kampanya dışında yaşadığı için aynı provider'a erişemiyoruz.
Map<String, dynamic> _defaultFieldsFor(EntityCategorySchema cat) {
  final out = <String, dynamic>{};
  for (final f in cat.fields) {
    if (f.defaultValue != null) {
      out[f.fieldKey] = f.defaultValue;
      continue;
    }
    if (f.isList) {
      out[f.fieldKey] = <dynamic>[];
      continue;
    }
    out[f.fieldKey] = switch (f.fieldType) {
      FieldType.text || FieldType.textarea || FieldType.markdown => '',
      FieldType.integer => 0,
      FieldType.float_ => 0.0,
      FieldType.boolean_ => false,
      FieldType.enum_ => '',
      FieldType.relation => '',
      FieldType.tagList => <String>[],
      FieldType.statBlock =>
          {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
      FieldType.combatStats => {
          'hp': '',
          'max_hp': '',
          'ac': '',
          'speed': '',
          'cr': '',
          'xp': '',
          'initiative': '',
        },
      FieldType.dice => '',
      FieldType.proficiencyTable => const {'rows': <dynamic>[]},
      FieldType.classFeatures => const <Map<String, dynamic>>[],
      FieldType.spellEffectList => const <Map<String, dynamic>>[],
      FieldType.rangedSenseList => const <Map<String, dynamic>>[],
      FieldType.grantedModifiers => const <Map<String, dynamic>>[],
      FieldType.equipmentChoiceGroups => const <Map<String, dynamic>>[],
      FieldType.featEffectList => const <Map<String, dynamic>>[],
      _ => null,
    };
  }
  return out;
}
