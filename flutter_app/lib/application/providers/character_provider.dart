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
import '../../domain/services/character_resolver.dart';
import '../services/builtin_srd_entities.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'character_claim_provider.dart';
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
  }

  final CharacterRepository _repo;
  final Ref _ref;

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
    // Personal mirror — char "Make Online" yapıldıysa kendi cihazlarına
    // sync. World mirror'dan bağımsız çalışır; ikisi birlikte de aktif
    // olabilir (örn. online world'de olup ayrıca personal sync isteyen
    // karakter — DM yapısında nadir, oyuncu için yaygın).
    final personalIds = _ref.read(personalOnlineCharIdsProvider);
    if (personalIds.contains(c.id)) {
      // ignore: discarded_futures
      mirror.pushPersonalCharacter(c);
    }
  }

  /// DM-created character'larda push sonrası claim havuzuna ekler — yeni
  /// karakter PlayerCharacterTab'da "Available for claim" listesinde
  /// görünür. Order matters: önce world_characters insert (mirror push),
  /// sonra character_claim_pool insert (FK depends on it).
  Future<void> _mirrorPushAndMaybeClaim(Character c) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) return;
    final worldId = _worldIdFor(c.worldName);
    if (worldId == null) return;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return;
    await mirror.pushCharacter(
      worldId: worldId,
      character: c,
      referencedEntityIds: const <String>{},
    );
    // DM-created → ownerId stays null (`_resolveOwnerIdForWorld` returns
    // null when role=dm). Auto-list in claim pool so players see it the
    // moment it's created, no DM follow-up click required.
    if (c.ownerId != null) return;
    final claim = _ref.read(characterClaimServiceProvider);
    if (claim == null) return;
    try {
      await claim.markAvailable(characterId: c.id, worldId: worldId);
    } catch (e) {
      // RLS may reject (e.g. user is not actually DM) — best effort.
      // ignore: avoid_print
      // ignore: discarded_futures
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

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _repo.loadAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

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
    // ignore: discarded_futures
    _mirrorPushAndMaybeClaim(character);
    return character;
  }

  /// Resolves the owner_id for a freshly created character.
  ///
  /// - Offline / non-member world → null (no online RLS to satisfy).
  /// - Player in online world → own auth.uid (required by RLS
  ///   `Chars: player inserts own` WITH CHECK).
  /// - DM in online world → null. Keeping DM-created characters "unowned"
  ///   is what lets them auto-flow into the claim pool — a player who
  ///   claims one then takes ownership via the `claim_character` RPC.
  String? _resolveOwnerIdForWorld(String worldName) {
    final auth = _ref.read(authProvider);
    if (auth == null) return null;
    final worldId = _worldIdFor(worldName);
    if (worldId == null) return null;
    final onlineIds = _ref.read(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return null;
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
