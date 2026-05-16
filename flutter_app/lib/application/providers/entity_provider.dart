import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../services/event_bus.dart';
import '../services/undo_redo_mixin.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'event_bus_provider.dart';
import 'online_worlds_provider.dart';
import 'role_provider.dart';
import 'auth_provider.dart';
import 'save_state_provider.dart';
import 'sync_engine_provider.dart';

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
      var schema = WorldSchema.fromJson(
        Map<String, dynamic>.from(rawSource),
      );
      final migrated = _migrateStaleEnumRelations(schema);
      if (migrated != null) {
        schema = migrated;
        if (data != null) {
          final serialized = deepCopyJson(schema.toJson());
          data['world_schema'] = serialized;
          _cachedWorldSchemaSource = serialized;
        }
      } else {
        _cachedWorldSchemaSource = rawSource;
      }
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

/// Fix legacy campaigns whose stored `world_schema` left these keys as
/// `FieldType.enum_` after the code migrated them to `relation`. The
/// stored entity values are already real Tier-0 UUIDs (resolved at SRD
/// import time), so flipping the schema type makes the relation widget
/// render names instead of raw UUIDs. Returns a new schema if any field
/// was patched, otherwise null.
const Map<String, List<String>> _staleEnumToRelation = {
  'weapon_proficiency_categories': ['weapon-category'],
  'armor_training_refs': ['armor-category'],
  'armor_trainings': ['armor-category'],
  'weapon_proficiency_specifics': ['weapon'],
};

WorldSchema? _migrateStaleEnumRelations(WorldSchema schema) {
  var dirty = false;
  final newCats = <EntityCategorySchema>[];
  for (final cat in schema.categories) {
    var catDirty = false;
    final newFields = <FieldSchema>[];
    for (final f in cat.fields) {
      final expectedTypes = _staleEnumToRelation[f.fieldKey];
      if (expectedTypes != null && f.fieldType == FieldType.enum_) {
        newFields.add(f.copyWith(
          fieldType: FieldType.relation,
          isList: true,
          validation: f.validation.copyWith(
            allowedTypes: List<String>.from(expectedTypes),
            allowedValues: null,
          ),
        ));
        catDirty = true;
        dirty = true;
      } else {
        newFields.add(f);
      }
    }
    newCats.add(catDirty ? cat.copyWith(fields: newFields) : cat);
  }
  if (!dirty) return null;
  return schema.copyWith(categories: newCats);
}

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
    // yansımalı. Sadece linked karakter entity'lerinin diff'ini enjekte
    // et; tüm map'i yeniden parse etme — aksi halde aktif kart Open'ken
    // entity referansı her hub güncellemesinde değişir ve UI flicker'lar.
    _ref.listen(characterListProvider, (_, next) {
      if (_linkedCharacterIds.isEmpty) return;
      final list = next.valueOrNull;
      if (list == null) return;
      var changed = false;
      final patched = Map<String, Entity>.from(state);
      for (final c in list) {
        if (!_linkedCharacterIds.contains(c.id)) continue;
        final existing = patched[c.entity.id];
        if (!identical(existing, c.entity)) {
          patched[c.entity.id] = c.entity;
          changed = true;
        }
      }
      if (changed) state = patched;
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
          packageId: map['package_id'] as String?,
          packageEntityId: map['package_entity_id'] as String?,
          linked: (map['linked'] as bool?) ?? false,
        );
      } catch (e) {
        debugPrint('Entity parse error for ${entry.key}: $e');
      }
    }

    // 039 model: hub-level karakterlerin entity'sini world'e enjekte et.
    // Kanon link `Character.worldId == activeWorldId`. Eski `linked_character_ids`
    // side-band list 039 ile birlikte retire edildi.
    _linkedCharacterIds.clear();
    final activeWorldId =
        _ref.read(activeCampaignIdProvider).valueOrNull;
    final chars = _ref.read(characterListProvider).valueOrNull ?? const [];
    if (activeWorldId != null) {
      for (final c in chars) {
        if (c.worldId == activeWorldId) {
          entities[c.entity.id] = c.entity;
          _linkedCharacterIds.add(c.entity.id);
        }
      }
    }

    // Preserve identity of unchanged entities so widgets like EntityCard
    // that watch via `.select((map) => map[id])` don't rebuild when a
    // background reload (e.g. PackageSync auto-trigger) re-parses the
    // exact same content. New instances would otherwise propagate to
    // every open card and discard their cached subtitle / schema layout.
    final prev = state;
    if (prev.isNotEmpty) {
      for (final entry in entities.entries) {
        final existing = prev[entry.key];
        if (existing != null && existing == entry.value) {
          entities[entry.key] = existing;
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
              FieldType.grantedModifiers => const <Map<String, dynamic>>[],
              FieldType.equipmentChoiceGroups => const <Map<String, dynamic>>[],
              FieldType.featEffectList => const <Map<String, dynamic>>[],
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
      source: 'Homebrew',
    );
    state = {...state, id: entity};
    // F13: incremental write — set this entity's row in the campaign
    // entities map instead of rebuilding the whole map.
    _writeEntityToCampaign(entity);
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
    // Detach-on-edit: any content change marks the entity as homebrew.
    // Linked pack entities break the link; pack-side row is unaffected.
    // Manual source edits (source field changed in this update) are
    // preserved — only auto-stamp Homebrew when the user didn't set one.
    final prev = state[entity.id];
    var next = entity;
    if (prev != null && _isContentChanged(prev, entity)) {
      final userEditedSource = entity.source != prev.source;
      next = entity.copyWith(
        linked: false,
        source: userEditedSource ? entity.source : 'Homebrew',
      );
    }
    state = {...state, next.id: next};
    // F13: incremental write — O(1) instead of O(N) full re-serialize.
    _writeEntityToCampaign(next);
    _eventBus.emit(EventEnvelope.now(
      EventTypes.entityUpdated,
      {'entity_id': next.id, 'changed_fields': const <String>[]},
      campaignId: _campaignId,
    ));
  }

  /// True when [next] differs from [prev] in any user-editable surface.
  /// Pack-link metadata changes alone don't trigger detach.
  bool _isContentChanged(Entity prev, Entity next) {
    return prev.name != next.name ||
        prev.description != next.description ||
        prev.imagePath != next.imagePath ||
        prev.dmNotes != next.dmNotes ||
        prev.locationId != next.locationId ||
        !_listEquals(prev.images, next.images) ||
        !_listEquals(prev.tags, next.tags) ||
        !_listEquals(prev.pdfs, next.pdfs) ||
        !_mapEquals(prev.fields, next.fields);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // E4 / F1: deep-equality via `DeepCollectionEquality` from
  // package:collection. Replaces the previous per-key `jsonEncode`
  // pairwise comparison — that was allocating two JSON strings for every
  // field on every update. With 50-field characters this dominated CPU
  // during description editing.
  static const _kFieldEquality = DeepCollectionEquality();

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _kFieldEquality.equals(a, b);

  /// Birden fazla entity'yi tek seferde ekle (paket import için).
  /// Çağıran taraf önceden pushUndo() yapmalıdır.
  void addEntities(Map<String, Entity> entities) {
    state = {...state, ...entities};
    // F13 follow-up: patch each entity individually instead of full
    // re-serialization. Package import with N entities goes from O(N²)
    // (full sync per call) to O(N) total work in the campaign blob.
    // Bulk-patch then a single dirty mark so the autosave debounce
    // fires once for the whole batch.
    final data = _campaign.data;
    if (data == null) return;
    final raw = data['entities'];
    final Map<String, dynamic> existing;
    if (raw is Map<String, dynamic>) {
      existing = raw;
    } else {
      existing = <String, dynamic>{};
      data['entities'] = existing;
    }
    for (final entity in entities.values) {
      if (_linkedCharacterIds.contains(entity.id)) continue;
      existing[entity.id] = _entityToMap(entity);
    }
    _onDirty();
  }

  /// Mevcut entity map'inin bir kopyasını döndürür (import service için).
  Map<String, Entity> get currentEntities => Map.unmodifiable(state);

  void delete(String entityId) {
    final removed = state[entityId];
    pushUndo(state);
    state = Map.from(state)..remove(entityId);
    // F13: incremental delete — drop the single key instead of
    // rewriting the entire entities blob.
    _removeEntityFromCampaign(entityId);
    _eventBus.emit(EventEnvelope.now(
      EventTypes.entityDeleted,
      {
        'entity_id': entityId,
        'entity_type': removed?.categorySlug ?? '',
      },
      campaignId: _campaignId,
    ));
    // Remote mirror — routed through outbox. Engine handles RLS rejection
    // by retrying with backoff; benign no-op when world isn't online.
    final worldId = _campaignId;
    if (worldId != null &&
        _ref.read(authProvider) != null &&
        _ref.read(onlineWorldIdsProvider).contains(worldId)) {
      // ignore: discarded_futures
      _ref.read(syncEngineProvider).enqueueWorldEntityDelete(
            worldId: worldId,
            entityId: entityId,
          );
    }
  }

  /// Full re-serialization fallback. Used by undo/redo/setAll/addEntities
  /// where the diff is unknown. For single-entity edits prefer
  /// [_writeEntityToCampaign] / [_removeEntityFromCampaign] — those are
  /// O(1) where this is O(N).
  void _syncToCampaign() {
    final data = _campaign.data;
    if (data == null) return;
    final raw = <String, dynamic>{};
    for (final entry in state.entries) {
      final entity = entry.value;
      if (_linkedCharacterIds.contains(entity.id)) continue;
      raw[entry.key] = _entityToMap(entity);
    }
    data['entities'] = raw;
    _onDirty();
  }

  /// F13: incremental write. Serializes one entity and patches the
  /// campaign's `entities` map in place. Linked characters are
  /// intentionally not persisted to the world blob — they live on the
  /// hub side and only their id is tracked via `linked_character_ids`.
  void _writeEntityToCampaign(Entity entity) {
    final data = _campaign.data;
    if (data == null) return;
    if (_linkedCharacterIds.contains(entity.id)) return;
    final raw = data['entities'];
    final Map<String, dynamic> entities;
    if (raw is Map<String, dynamic>) {
      entities = raw;
    } else {
      entities = <String, dynamic>{};
      data['entities'] = entities;
    }
    entities[entity.id] = _entityToMap(entity);
    _onDirty();
  }

  /// F13: incremental delete. Drops a single id from the campaign's
  /// `entities` blob.
  void _removeEntityFromCampaign(String entityId) {
    final data = _campaign.data;
    if (data == null) return;
    final raw = data['entities'];
    if (raw is Map<String, dynamic>) {
      raw.remove(entityId);
      _onDirty();
    }
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
      if (e.packageId != null) 'package_id': e.packageId,
      if (e.packageEntityId != null) 'package_entity_id': e.packageEntityId,
      if (e.linked) 'linked': true,
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
