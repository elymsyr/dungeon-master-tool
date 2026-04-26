import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/character_repository.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

const _uuid = Uuid();
const playerCategorySlug = 'player';

final characterRepositoryProvider =
    Provider<CharacterRepository>((_) => CharacterRepository());

/// Hub-level karakter listesi. Senkron kalsın diye StateNotifier.
class CharacterListNotifier extends StateNotifier<AsyncValue<List<Character>>> {
  CharacterListNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final CharacterRepository _repo;

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
  }) async {
    final playerCategory =
        template.categories.firstWhere((c) => c.slug == playerCategorySlug);
    final now = DateTime.now().toUtc().toIso8601String();
    final entity = Entity(
      id: _uuid.v4(),
      name: name,
      categorySlug: playerCategorySlug,
      fields: _defaultFieldsFor(playerCategory),
    );
    final character = Character(
      id: _uuid.v4(),
      templateId: template.schemaId,
      templateName: template.name,
      entity: entity,
      worldName: worldName,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(character);
    state = AsyncValue.data([character, ...state.valueOrNull ?? const []]);
    return character;
  }

  /// Bir world'de template güncellenince o world'e bağlı karakterlerin
  /// `entity.fields`'i yeni Player kategorisine göre haritalanır: yeni
  /// alanlara default, kaldırılan alanlar düşürülür.
  Future<void> applyTemplateUpdate({
    required String worldName,
    required WorldSchema newTemplate,
  }) async {
    final playerCat = newTemplate.categories
        .where((c) => c.slug == playerCategorySlug)
        .firstOrNull;
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
  return CharacterListNotifier(ref.watch(characterRepositoryProvider));
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
      _ => null,
    };
  }
  return out;
}
