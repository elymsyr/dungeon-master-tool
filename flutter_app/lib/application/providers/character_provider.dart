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
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../../domain/services/character_resolver.dart';
import '../services/builtin_srd_entities.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'entity_provider.dart';
import 'online_worlds_provider.dart';
import 'personal_online_provider.dart';
import 'role_provider.dart';
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
    // Bir world online'a alındığında o world'e bağlı self-owned karakterleri
    // otomatik personal sync'e dahil et — kullanıcının "Make Online"
    // tuşlamasına gerek kalmasın.
    _ref.listen<Set<String>>(onlineWorldIdsProvider, (prev, next) {
      final added = next.difference(prev ?? const <String>{});
      if (added.isEmpty) return;
      // ignore: discarded_futures
      _autoPublishForOnlineWorlds(added);
    });
    // Auth transition (offline → signed in): pre-existing worldless chars
    // had `ownerId == null` and would otherwise become invisible under the
    // own-only char tab filter. Adopt them on first auth.
    _ref.listen(authProvider, (prev, next) {
      if (prev == null && next != null) {
        // ignore: discarded_futures
        _backfillWorldlessOwnership(next.uid);
      }
    });
  }

  final CharacterRepository _repo;
  final Ref _ref;

  Future<void> _autoPublishForOnlineWorlds(Set<String> newWorldIds) async {
    final list = state.valueOrNull;
    if (list == null || list.isEmpty) return;
    for (final c in list) {
      final worldId = _worldIdFor(c.worldName);
      if (worldId == null) continue;
      if (!newWorldIds.contains(worldId)) continue;
      if (!_shouldAutoOnline(c)) continue;
      _mirrorPush(c);
    }
  }

  /// World name → world id (UUID) eşlemesi. campaignInfoListProvider'dan
  /// senkron okur; henüz yüklenmediyse null döner ve push skip edilir.
  String? _worldIdFor(String worldName) {
    if (worldName.isEmpty) return null;
    final list =
        _ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    return list
        .where((c) => c.name == worldName)
        .firstOrNull
        ?.id;
  }

  /// Char self-owned + online bir world'e bağlıysa otomatik olarak personal
  /// sync'e dahildir. Kullanıcının ayrıca "Make Online" tuşlamasına gerek
  /// yok; online-world membership implicit online demek.
  bool _shouldAutoOnline(Character c) {
    final auth = _ref.read(authProvider);
    if (auth == null) return false;
    if (c.ownerId == null || c.ownerId != auth.uid) return false;
    final worldId = _worldIdFor(c.worldName);
    if (worldId == null) return false;
    return _ref.read(onlineWorldIdsProvider).contains(worldId);
  }

  void _mirrorPush(Character c) {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    // World mirror — sadece char online bir world'e bağlıysa.
    final worldId = _worldIdFor(c.worldName);
    if (worldId != null) {
      final onlineIds = _ref.read(onlineWorldIdsProvider);
      if (onlineIds.contains(worldId)) {
        // ignore: discarded_futures
        mirror.pushCharacter(
          worldId: worldId,
          character: c,
          referencedEntityIds: const <String>{},
        );
      }
    }
    // Personal mirror — explicit "Make Online" set'i veya implicit
    // online-world membership. Online world'e bağlı self-owned karakter
    // kullanıcıya ek toggle gerektirmeden kendi cihazlarına sync olur.
    final personalIds = _ref.read(personalOnlineCharIdsProvider);
    final autoOnline = _shouldAutoOnline(c);
    final inPersonalSet = personalIds.contains(c.id);
    if (!inPersonalSet && !autoOnline) return;
    final auth = _ref.read(authProvider);
    if (auth == null || c.ownerId != auth.uid) {
      // Ownership flip (e.g. DM import drops it to null, world release
      // transfers it). Personal sync must mirror only self-owned chars
      // or we leak an ownerless payload to `personal_characters` and
      // every other device of this user.
      if (inPersonalSet) {
        _ref.read(personalOnlineCharIdsProvider.notifier).remove(c.id);
        // ignore: discarded_futures
        mirror.unpublishPersonalCharacter(c.id);
      }
      return;
    }
    // ignore: discarded_futures
    mirror.pushPersonalCharacter(c);
    if (autoOnline && !inPersonalSet) {
      _ref.read(personalOnlineCharIdsProvider.notifier).add(c.id);
    }
  }

  void _mirrorDelete(String characterId, {String? worldName}) {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    if (worldName != null) {
      final worldId = _worldIdFor(worldName);
      if (worldId != null) {
        final onlineIds = _ref.read(onlineWorldIdsProvider);
        if (onlineIds.contains(worldId)) {
          // ignore: discarded_futures
          mirror.deleteCharacter(characterId: characterId);
        }
      }
    }
    final personalIds = _ref.read(personalOnlineCharIdsProvider);
    if (personalIds.contains(characterId)) {
      // ignore: discarded_futures
      mirror.unpublishPersonalCharacter(characterId);
      _ref
          .read(personalOnlineCharIdsProvider.notifier)
          .remove(characterId);
    }
  }

  /// "Make Online" — bu karakteri Supabase `personal_characters`'a publish
  /// eder. Mevcut local state'i (örn. son düzenleme) push payload olarak
  /// kullanır; cross-device sync bundan sonra `update()` hook'u ile her
  /// yazımda devam eder.
  Future<void> makeOnline(String id) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) {
      throw StateError('Sign in and configure Supabase to enable sync.');
    }
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null) {
      throw StateError('Character not found.');
    }
    await mirror.pushPersonalCharacter(c);
    _ref.read(personalOnlineCharIdsProvider.notifier).add(id);
  }

  /// "Make Offline" — `personal_characters` satırını siler. Local karakter
  /// dosyası kalır; sadece cloud kopyası ve cross-device sync durdurulur.
  Future<void> makeOffline(String id) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    await mirror.unpublishPersonalCharacter(id);
    _ref.read(personalOnlineCharIdsProvider.notifier).remove(id);
  }

  /// Idempotent: char online-world implicit kuralından geçiyorsa veya
  /// personal set'te ise personal_characters'a push eder. Claim akışı
  /// gibi yerlerde "user toggle gerekmesin" demek için kullanılır.
  Future<void> ensureOnline(String id) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    final personalIds = _ref.read(personalOnlineCharIdsProvider);
    final autoOnline = _shouldAutoOnline(c);
    if (!personalIds.contains(id) && !autoOnline) return;
    await mirror.pushPersonalCharacter(c);
    if (!personalIds.contains(id)) {
      _ref.read(personalOnlineCharIdsProvider.notifier).add(id);
    }
  }

  /// Char online-world membership kuralından otomatik online sayılıyor mu?
  /// UI Make Online/Offline toggle'ını bu chars için gizleyebilmek için.
  bool isAutoOnline(String id) {
    final list = state.valueOrNull ?? const <Character>[];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null) return false;
    return _shouldAutoOnline(c);
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

  /// Adopt pre-existing worldless chars that have no `ownerId`. Under the
  /// own-only char tab filter they would otherwise vanish once the user
  /// signs in. World-bound orphan chars are left alone: they may belong
  /// to other players or live in the DM-owned pool of an online world.
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
      if (c.worldName.isNotEmpty) continue;
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
    // Online player rolünde owner_id zorunlu (RLS `Chars: player inserts
    // own` policy `owner_id = auth.uid()` ister). DM rolünde owner_id
    // null bırakılır (DM-owned implicit, DM policy zaten `is_world_dm`
    // ile geçer). Auth yoksa null kalır → offline akış değişmez.
    final effectiveOwnerId = ownerId ?? _resolveOwnerIdForWorld(worldName);
    final character = Character(
      id: _uuid.v4(),
      templateId: template.schemaId,
      templateName: template.name,
      entity: entity,
      worldName: worldName,
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
  /// - Online world + DM → null. DM-created world chars stay unowned so
  ///   any player can claim them.
  /// - Offline world (local-only campaign) → auth.uid when authenticated,
  ///   else null. The creator still sees the char in their tab.
  String? _resolveOwnerIdForWorld(String worldName) {
    final auth = _ref.read(authProvider);
    if (auth == null) return null;
    if (worldName.isEmpty) return auth.uid;
    final worldId = _worldIdFor(worldName);
    if (worldId == null) return auth.uid;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return auth.uid;
    final role = _ref.read(worldRoleProvider(worldId)).valueOrNull
        ?? _ref.read(currentWorldRoleProvider).valueOrNull;
    if (role == WorldRole.dm) return null;
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
  /// [worldEntitiesRaw]: campaign data'sının `entities` alt-map'i. Boşsa
  /// (`{}` veya null) no-op.
  Future<void> orphanForWorld(
    String worldName,
    Map<String, dynamic> worldEntitiesRaw,
  ) async {
    if (worldName.isEmpty) return;
    final list = state.valueOrNull ?? const <Character>[];
    final affected = list.where((c) => c.worldName == worldName).toList();
    if (affected.isEmpty) return;

    final builtin = _ref.read(builtinSrdEntitiesProvider);
    final remap = <String, String>{};
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

    for (final c in affected) {
      final rewritten =
          _rewriteRefs(c.entity.fields, remap) as Map<String, dynamic>;
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

  Future<void> delete(String id) async {
    final list = state.valueOrNull ?? const <Character>[];
    final existing = list.where((c) => c.id == id).firstOrNull;
    final displayName = existing?.entity.name;
    await _repo.delete(id, displayName: displayName);
    state = AsyncValue.data(list.where((c) => c.id != id).toList());
    _mirrorDelete(id, worldName: existing?.worldName);
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

/// Bir karakter, online bir world'e bağlı self-owned ise implicit auto-online
/// kabul edilir. UI bu provider'a bakıp Make Online/Offline tuşlarını
/// gizler — kullanıcıya manuel toggle ihtiyacı kalmaz.
final autoOnlineForCharacterProvider =
    Provider.family<bool, String>((ref, id) {
  final list = ref.watch(characterListProvider).valueOrNull;
  if (list == null) return false;
  final c = list.where((x) => x.id == id).firstOrNull;
  if (c == null) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;
  if (c.ownerId == null || c.ownerId != auth.uid) return false;
  if (c.worldName.isEmpty) return false;
  final infos =
      ref.watch(campaignInfoListProvider).valueOrNull ?? const [];
  final worldId =
      infos.where((i) => i.name == c.worldName).firstOrNull?.id;
  if (worldId == null) return false;
  return ref.watch(onlineWorldIdsProvider).contains(worldId);
});

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
