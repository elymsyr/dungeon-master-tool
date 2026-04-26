import 'package:flutter/foundation.dart';

import '../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../services/event_bus.dart';
import '../services/undo_redo_mixin.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'event_bus_provider.dart';
import 'save_state_provider.dart';

const _uuid = Uuid();

/// Module-level memo for [worldSchemaProvider] — keyed on the identity
/// of the source `world_schema` map inside the active campaign's
/// `_data`. Reparsing WorldSchema on every downstream rebuild is
/// expensive (deep Freezed tree), and until the source map is actually
/// replaced the parse result is stable, so identity equality is safe.
WorldSchema? _cachedWorldSchema;
Object? _cachedWorldSchemaSource;

/// WorldSchema provider — aktif kampanyadan schema okur, yoksa default üretir.
///
/// Rebuilds when either the active campaign changes or the revision
/// counter is bumped (in-place data replace / template update). The
/// parse result is memoized by source-map identity, so a rebuild with
/// an unchanged underlying map returns the cached WorldSchema instance
/// — preserving Riverpod equality and preventing cascade rebuilds.
final worldSchemaProvider = Provider<WorldSchema>((ref) {
  ref.watch(activeCampaignProvider);
  ref.watch(campaignRevisionProvider);
  final campaign = ref.read(activeCampaignProvider.notifier);
  final data = campaign.data;

  final rawSource = data?['world_schema'];
  if (rawSource != null && identical(rawSource, _cachedWorldSchemaSource)) {
    return _cachedWorldSchema!;
  }

  if (rawSource is Map) {
    try {
      final schema = WorldSchema.fromJson(
        Map<String, dynamic>.from(rawSource),
      );
      _cachedWorldSchemaSource = rawSource;
      _cachedWorldSchema = schema;
      return schema;
    } catch (e) {
      debugPrint('WorldSchema parse error: $e');
    }
  }

  // Fallback: default schema üret ve kampanyaya kaydet
  final schema = generateDefaultDnd5eSchema();
  if (data != null) {
    final serialized = deepCopyJson(schema.toJson());
    data['world_schema'] = serialized;
    _cachedWorldSchemaSource = serialized;
    _cachedWorldSchema = schema;
  } else {
    _cachedWorldSchemaSource = null;
    _cachedWorldSchema = schema;
  }
  return schema;
});

/// Aktif kampanyadaki entity'lerin reactive state'i.
class EntityNotifier extends StateNotifier<Map<String, Entity>>
    with UndoRedoMixin<Map<String, Entity>> {
  final ActiveCampaignNotifier _campaign;
  final Ref _ref;
  final VoidCallback _onDirty;
  final AppEventBus _eventBus;

  @override
  int get maxUndoDepth => 30;

  /// Aktif kampanyaya link edilmiş (kopya değil) karakterlerin id'leri.
  /// `_loadFromCampaign` içinde doldurulur; `_syncToCampaign` bunları
  /// disk'e `entities`'e yazmaz — karakterler hub'da kalır, world sadece
  /// referansı (`linked_character_ids`) tutar.
  final Set<String> _linkedCharacterIds = {};

  EntityNotifier(
      this._campaign, this._ref, this._onDirty, this._eventBus)
      : super({}) {
    _loadFromCampaign();
    // Reload when the active campaign's data is mutated in-place
    // (cloud restore, template update). Not triggered on initial
    // mount — the `_loadFromCampaign()` above covers that.
    _ref.listen<int>(campaignRevisionProvider, (_, _) {
      _loadFromCampaign();
    });
    // Linked karakter edit'leri hub'dan geldiğinde world görünümünü
    // otomatik tazele — kopya olmadığı için güncellemeler anında
    // yansımalı.
    _ref.listen(characterListProvider, (_, _) {
      if (_linkedCharacterIds.isNotEmpty) _loadFromCampaign();
    });
  }

  String? get _campaignId => _campaign.data?['world_id'] as String?;

  void _loadFromCampaign() {
    final data = _campaign.data;
    if (data == null) return;

    final raw = data['entities'] as Map<String, dynamic>? ?? {};
    final entities = <String, Entity>{};

    for (final entry in raw.entries) {
      try {
        final map = Map<String, dynamic>.from(entry.value as Map);
        entities[entry.key] = Entity(
          id: entry.key,
          name: (map['name'] as String?) ?? 'Unknown',
          categorySlug: _resolveCategory(map),
          source: (map['source'] as String?) ?? '',
          description: (map['description'] as String?) ?? '',
          images: _toStringList(map['images']),
          imagePath: (map['image_path'] as String?) ?? '',
          tags: _toStringList(map['tags']),
          dmNotes: (map['dm_notes'] as String?) ?? '',
          pdfs: _toStringList(map['pdfs']),
          locationId: map['location_id'] as String?,
          fields: _extractFields(map),
        );
      } catch (e) {
        debugPrint('Entity parse error for ${entry.key}: $e');
      }
    }

    // Linked karakterleri enjekte et: hub'daki karakterin entity'sini aynı
    // id ile map'e koyarız. Böylece world görünümü hub'taki canlı veriyi
    // gösterir; edit'lerde `characterListProvider` listen'i ile anında
    // reload yapılır.
    _linkedCharacterIds
      ..clear()
      ..addAll(
        (data['linked_character_ids'] as List?)?.whereType<String>() ??
            const [],
      );
    if (_linkedCharacterIds.isNotEmpty) {
      final chars = _ref.read(characterListProvider).valueOrNull ?? const [];
      for (final c in chars) {
        if (_linkedCharacterIds.contains(c.id)) {
          entities[c.entity.id] = c.entity;
        }
      }
    }

    state = entities;
  }

  void undo() {
    final restored = popUndo(state);
    if (restored != null) {
      state = restored;
      _syncToCampaign();
    }
  }

  void redo() {
    final restored = popRedo(state);
    if (restored != null) {
      state = restored;
      _syncToCampaign();
    }
  }

  /// Yeni entity oluştur — schema'dan default field değerleri ile.
  String create(String categorySlug, {String name = 'New Record'}) {
    pushUndo(state);
    final id = _uuid.v4();

    // Schema'dan default field değerlerini al — lazy read so the
    // notifier isn't coupled to worldSchemaProvider rebuilds.
    final schema = _ref.read(worldSchemaProvider);
    final cats = schema.categories.where((c) => c.slug == categorySlug);
    final cat = cats.isEmpty ? null : cats.first;

    final defaultFields = <String, dynamic>{};
    if (cat != null) {
      for (final field in cat.fields) {
        if (field.defaultValue != null) {
          defaultFields[field.fieldKey] = field.defaultValue;
        } else {
          // isList → boş liste, değilse tip bazlı tek değer
          if (field.isList) {
            defaultFields[field.fieldKey] = <dynamic>[];
          } else {
            defaultFields[field.fieldKey] = switch (field.fieldType) {
              FieldType.text || FieldType.textarea || FieldType.markdown => '',
              FieldType.integer => 0,
              FieldType.float_ => 0.0,
              FieldType.boolean_ => false,
              FieldType.enum_ => '',
              FieldType.relation => '',
              FieldType.tagList => <String>[],
              FieldType.statBlock => {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
              FieldType.combatStats => {'hp': '', 'max_hp': '', 'ac': '', 'speed': '', 'cr': '', 'xp': '', 'initiative': ''},
              FieldType.dice => '',
              FieldType.proficiencyTable => const {'rows': <dynamic>[]},
              FieldType.classFeatures => const <Map<String, dynamic>>[],
              FieldType.spellEffectList => const <Map<String, dynamic>>[],
              FieldType.rangedSenseList => const <Map<String, dynamic>>[],
              _ => null,
            };
          }
        }
      }
    }

    final entity = Entity(
      id: id,
      name: name,
      categorySlug: categorySlug,
      fields: defaultFields,
    );
    state = {...state, id: entity};
    _syncToCampaign();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.entityCreated,
      {'entity_id': id, 'entity_type': categorySlug, 'name': name},
      campaignId: _campaignId,
    ));
    return id;
  }

  void update(Entity entity) {
    if (identical(state[entity.id], entity)) return;
    pushUndo(state);
    state = {...state, entity.id: entity};
    _syncToCampaign();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.entityUpdated,
      {'entity_id': entity.id, 'changed_fields': const <String>[]},
      campaignId: _campaignId,
    ));
  }

  /// Birden fazla entity'yi tek seferde ekle (paket import için).
  /// Çağıran taraf önceden pushUndo() yapmalıdır.
  void addEntities(Map<String, Entity> entities) {
    state = {...state, ...entities};
    _syncToCampaign();
  }

  /// Mevcut entity map'inin bir kopyasını döndürür (import service için).
  Map<String, Entity> get currentEntities => Map.unmodifiable(state);

  void delete(String entityId) {
    final removed = state[entityId];
    pushUndo(state);
    state = Map.from(state)..remove(entityId);
    _syncToCampaign();
    _eventBus.emit(EventEnvelope.now(
      EventTypes.entityDeleted,
      {
        'entity_id': entityId,
        'entity_type': removed?.categorySlug ?? '',
      },
      campaignId: _campaignId,
    ));
  }

  void _syncToCampaign() {
    final data = _campaign.data;
    if (data == null) return;

    // Synchronously update in-memory campaign data.
    // Linked karakterler disk'e `entities` altına yazılmaz — world sadece
    // `linked_character_ids`'i tutar, veri hub'da kalır.
    final raw = <String, dynamic>{};
    for (final entry in state.entries) {
      final entity = entry.value;
      if (_linkedCharacterIds.contains(entity.id)) continue;
      raw[entry.key] = _entityToMap(entity);
    }
    data['entities'] = raw;
    _onDirty();
  }

  Map<String, dynamic> _entityToMap(Entity e) {
    return {
      'name': e.name,
      'type': e.categorySlug,
      'source': e.source,
      'description': e.description,
      'images': e.images,
      'image_path': e.imagePath,
      'tags': e.tags,
      'dm_notes': e.dmNotes,
      'pdfs': e.pdfs,
      'location_id': e.locationId,
      'attributes': e.fields,
    };
  }

  String _resolveCategory(Map<String, dynamic> map) {
    final type = (map['type'] as String?) ?? 'npc';
    return type.toLowerCase().replaceAll(' ', '-');
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  Map<String, dynamic> _extractFields(Map<String, dynamic> map) {
    final fields = <String, dynamic>{};

    final attrs = map['attributes'];
    if (attrs is Map) {
      for (final e in attrs.entries) {
        fields[e.key.toString()] = e.value;
      }
    }

    if (map.containsKey('stats')) fields['stat_block'] = map['stats'];
    if (map.containsKey('combat_stats')) fields['combat_stats'] = map['combat_stats'];

    for (final key in ['traits', 'actions', 'reactions', 'legendary_actions']) {
      if (map.containsKey(key)) fields[key] = map[key];
    }

    if (map.containsKey('spells')) fields['spells'] = map['spells'];
    if (map.containsKey('custom_spells')) fields['custom_spells'] = map['custom_spells'];
    if (map.containsKey('equipment_ids')) fields['equipment_ids'] = map['equipment_ids'];
    if (map.containsKey('inventory')) fields['inventory'] = map['inventory'];

    for (final key in [
      'saving_throws', 'skills', 'damage_vulnerabilities', 'damage_resistances',
      'damage_immunities', 'condition_immunities', 'proficiency_bonus', 'passive_perception',
    ]) {
      if (map.containsKey(key) && map[key] != null && map[key] != '') {
        fields[key] = map[key];
      }
    }

    return fields;
  }
}

final entityProvider =
    StateNotifierProvider<EntityNotifier, Map<String, Entity>>((ref) {
  // Watch only the active campaign name — a new notifier is created
  // when the user opens a different world/package. Data mutations
  // (cloud restore, template update) are observed via
  // campaignRevisionProvider inside the notifier, so the schema
  // rebuild no longer cascades into a full entity reparse.
  ref.watch(activeCampaignProvider);
  return EntityNotifier(
    ref.read(activeCampaignProvider.notifier),
    ref,
    () => ref.read(saveStateProvider.notifier).markDirty(),
    ref.read(eventBusProvider),
  );
});
