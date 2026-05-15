import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/character_repository.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../../domain/services/character_resolver.dart';
import '../services/builtin_srd_entities.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'character_claim_provider.dart';
import 'entity_provider.dart';
import 'online_worlds_provider.dart';
import 'world_mirror_provider.dart';

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

final characterRepositoryProvider =
    Provider<CharacterRepository>((_) => CharacterRepository());

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
  }

  final CharacterRepository _repo;
  final Ref _ref;

  /// World mirror push: char online bir world'e bağlıysa `world_characters`
  /// tablosuna upsert. 039 model'de personal sync kaldırıldı — `world_characters`
  /// RLS `owner_id = auth.uid OR is_world_member` ile cross-device sync'i tek
  /// kanaldan sağlar.
  void _mirrorPush(Character c) {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    final worldId = c.worldId ?? _worldIdFromName(c.worldName);
    if (worldId == null) return;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return;
    // ignore: discarded_futures
    mirror.pushCharacter(
      worldId: worldId,
      character: c,
      referencedEntityIds: const <String>{},
    );
  }

  void _mirrorDelete(String characterId, {String? worldName, String? worldId}) {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    final wid = worldId ?? _worldIdFromName(worldName ?? '');
    if (wid == null) return;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(wid)) return;
    // ignore: discarded_futures
    mirror.deleteCharacter(characterId: characterId);
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

  /// Legacy worldName → worldId resolver. Yeni karakterlerde worldId zaten
  /// set; bu sadece migrate edilmemiş eski local files için fallback.
  String? _worldIdFromName(String worldName) {
    if (worldName.isEmpty) return null;
    final list =
        _ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    return list.where((c) => c.name == worldName).firstOrNull?.id;
  }

  /// Campaign listesi yüklendiğinde legacy `worldName`-only karakterleri
  /// `worldId`'ye migrate eder. Idempotent — `worldId` zaten varsa atlar.
  Future<void> _backfillWorldIds(List<dynamic> infos) async {
    final list = state.valueOrNull;
    if (list == null || list.isEmpty) return;
    final nameToId = <String, String>{};
    for (final info in infos) {
      final name = (info as dynamic).name as String;
      final id = (info as dynamic).id as String;
      nameToId[name] = id;
    }
    final out = [...list];
    var changed = false;
    for (var i = 0; i < out.length; i++) {
      final c = out[i];
      if (c.worldId != null) continue;
      if (c.worldName.isEmpty) continue;
      final id = nameToId[c.worldName];
      if (id == null) continue;
      final patched = c.copyWith(worldId: id);
      try {
        await _repo.save(patched);
      } catch (e) {
        debugPrint('backfill worldId save error: $e');
        continue;
      }
      out[i] = patched;
      changed = true;
    }
    if (changed) state = AsyncValue.data(out);
  }

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _repo.loadAll());
      final auth = _ref.read(authProvider);
      if (auth != null) {
        await _backfillWorldlessOwnership(auth.uid);
      }
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
      _mirrorPush(c);
    }
  }

  Future<void> refresh() => _load();

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
    required String worldName,
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
    final effectiveOwnerId = ownerId ?? _resolveOwnerIdForWorld(worldName);
    // worldId paralel: caller verirse onu kullan, yoksa worldName'den lookup
    // et. campaignInfoListProvider yüklü değilse null kalır (PR3'te tek
    // canonical link olacak; şimdilik worldName + worldId paralel taşınır).
    final resolvedWorldId = worldId ?? _worldIdFromName(worldName);
    final character = Character(
      id: _uuid.v4(),
      templateId: template.schemaId,
      templateName: template.name,
      entity: entity,
      worldName: worldName,
      worldId: resolvedWorldId,
      ownerId: effectiveOwnerId,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(character);
    state = AsyncValue.data([character, ...state.valueOrNull ?? const []]);
    _mirrorPush(character);
    return character;
  }

  /// Resolves the owner_id for a freshly created character.
  ///
  /// - No auth (pure offline) → null.
  /// - Worldless (char tab create): creator becomes owner (auth.uid). Char
  ///   tab visibility is own-only, so the creator must hold ownership to
  ///   keep seeing their character there.
  /// - Online world + player → auth.uid (RLS `Chars: player inserts own`
  ///   WITH CHECK requires it).
  /// - Online world + DM → auth.uid. Creator gets ownership; DM can later
  ///   "Release" to make the char claimable by a player.
  /// - Offline world (local-only campaign) → auth.uid when authenticated,
  ///   else null. The creator still sees the char in their tab.
  String? _resolveOwnerIdForWorld(String worldName) {
    final auth = _ref.read(authProvider);
    if (auth == null) return null;
    return auth.uid;
  }

  /// Bir world'de template güncellenince o world'e bağlı karakterlerin
  /// `entity.fields`'i yeni Player kategorisine göre haritalanır: yeni
  /// alanlara default, kaldırılan alanlar düşürülür.
  Future<void> applyTemplateUpdate({
    required String worldName,
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
      if (c.worldName != worldName) continue;
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
    _mirrorPush(bumped);
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
  /// UUID'sine çevirir (slug+name eşleşmesiyle), worldName'i temizler ve
  /// karakteri kaydeder. Böylece world purge sonrası orphan karakterlerin
  /// Species/Class/Trait/Action refleri builtin SRD üzerinden çözülür.
  ///
  /// [worldEntitiesRaw]: campaign data'sının `entities` alt-map'i. Null veya
  /// boş geçilebilir — entity remap atlanır ama `worldName` her durumda
  /// temizlenir. Bu davranış kritik: aynı isimli yeni bir world yaratıldığında
  /// eski karakterler `worldName == 'X'` ile asılı kalırsa hub filtresi
  /// (`c.worldName == activeWorld`) onları yeni world'e yapıştırır.
  Future<void> orphanForWorld(
    String worldName, [
    Map<String, dynamic>? worldEntitiesRaw,
  ]) async {
    if (worldName.isEmpty) return;
    final list = state.valueOrNull ?? const <Character>[];
    final affected = list.where((c) => c.worldName == worldName).toList();
    if (affected.isEmpty) return;

    final remap = <String, String>{};
    if (worldEntitiesRaw != null && worldEntitiesRaw.isNotEmpty) {
      final builtin = _ref.read(builtinSrdEntitiesProvider);
      worldEntitiesRaw.forEach((worldId, raw) {
        if (raw is! Map) return;
        final slug = (raw['type'] as String?)?.trim();
        final name = (raw['name'] as String?)?.trim();
        if (slug == null || slug.isEmpty) return;
        if (name == null || name.isEmpty) return;
        final stableId = srdStableEntityId(slug, name);
        if (builtin.containsKey(stableId)) {
          remap[worldId] = stableId;
        }
      });
    }

    for (final c in affected) {
      final rewritten = remap.isEmpty
          ? c.entity.fields
          : _rewriteRefs(c.entity.fields, remap) as Map<String, dynamic>;
      final patched = c.copyWith(
        worldName: '',
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

  /// Char Tab "Delete/Leave world" action point. 039 model server-side router:
  ///   - world-bound (worldId != null || worldName != ''): `remove_from_world`
  ///     RPC. Server-side branch:
  ///       * owner varsa → world_id NULL (karakter orphan'a düşer, local'de kalır)
  ///       * owner yoksa → row DELETE (CHECK violation olurdu)
  ///   - orphan: `delete_character` RPC → hard delete (cloud + local).
  /// Offline (svc == null) durumda local-only patch.
  Future<void> delete(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final existing = list.where((c) => c.id == id).firstOrNull;
    if (existing == null) return;
    final svc = _ref.read(characterClaimServiceProvider);
    final isWorldBound =
        existing.worldId != null || existing.worldName.isNotEmpty;

    if (svc != null) {
      try {
        if (isWorldBound) {
          final result = await svc.removeFromWorld(id);
          if (!result.deleted) {
            // Server (owner, NULL) yaptı — local'i orphan'a patch et.
            // Cloud CDC UPDATE echo'su aynı state'i tekrar yazacak.
            final patched = existing.copyWith(
              worldId: null,
              worldName: '',
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
          // result.deleted = true → server row'u sildi; local cleanup'a düş.
        } else {
          await svc.deleteCharacter(id);
        }
      } catch (e) {
        debugPrint('delete RPC error: $e');
        // Local cleanup'a düş — kullanıcının cihazında en azından silinsin.
      }
    }

    final displayName = existing.entity.name;
    await _repo.delete(id, displayName: displayName);
    state = AsyncValue.data(list.where((c) => c.id != id).toList());
    _mirrorDelete(id, worldName: existing.worldName);
  }

  /// Local Character'in `worldName`'ini boşaltır. world_characters DB
  /// satırının yok olduğu durumlarda (CDC DELETE event veya kendi initiate
  /// ettiğimiz remove-from-world) çağrılır — local char dosyası kalır,
  /// sadece world bağı kopar. `update()` yolundan geçtiği için personal
  /// sync push'u tetiklenir; owner'ın diğer cihazlarına da yansır.
  Future<void> detachFromWorld(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null || c.worldName.isEmpty) return;
    await update(c.copyWith(worldName: ''));
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
  if (list == null) return null;
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
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
  if (pc.worldName.isEmpty) {
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
