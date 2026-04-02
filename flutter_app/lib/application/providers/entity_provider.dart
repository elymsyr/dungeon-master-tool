import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'campaign_provider.dart';

const _uuid = Uuid();

/// WorldSchema provider — aktif kampanyadan schema okur, yoksa default üretir.
final worldSchemaProvider = Provider<WorldSchema>((ref) {
  // State değişikliğini izle (kampanya değişince tetiklenir)
  ref.watch(activeCampaignProvider);
  final campaign = ref.read(activeCampaignProvider.notifier);
  final data = campaign.data;

  if (data != null && data.containsKey('world_schema')) {
    try {
      return WorldSchema.fromJson(
        Map<String, dynamic>.from(data['world_schema'] as Map),
      );
    } catch (e) {
      debugPrint('WorldSchema parse error: $e');
    }
  }

  // Fallback: default schema üret ve kampanyaya kaydet
  final schema = generateDefaultDnd5eSchema();
  if (data != null) {
    data['world_schema'] = schema.toJson();
  }
  return schema;
});

/// Aktif kampanyadaki entity'lerin reactive state'i.
class EntityNotifier extends StateNotifier<Map<String, Entity>> {
  final ActiveCampaignNotifier _campaign;
  final WorldSchema _schema;

  EntityNotifier(this._campaign, this._schema) : super({}) {
    _loadFromCampaign();
  }

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

    state = entities;
  }

  /// Yeni entity oluştur — schema'dan default field değerleri ile.
  String create(String categorySlug, {String name = 'New Record'}) {
    final id = _uuid.v4();

    // Schema'dan default field değerlerini al
    final cats = _schema.categories.where((c) => c.slug == categorySlug);
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
    return id;
  }

  void update(Entity entity) {
    state = {...state, entity.id: entity};
    _syncToCampaign();
  }

  void delete(String entityId) {
    state = Map.from(state)..remove(entityId);
    _syncToCampaign();
  }

  void _syncToCampaign() {
    final data = _campaign.data;
    if (data == null) return;

    final raw = <String, dynamic>{};
    for (final entry in state.entries) {
      raw[entry.key] = _entityToMap(entry.value);
    }
    data['entities'] = raw;
    _campaign.save();
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
  final schema = ref.watch(worldSchemaProvider);
  return EntityNotifier(ref.read(activeCampaignProvider.notifier), schema);
});
