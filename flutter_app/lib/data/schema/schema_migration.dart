import 'package:uuid/uuid.dart';

import '../../core/utils/deep_copy.dart';

import '../../domain/entities/schema/default_dnd5e_schema.dart';
import 'legacy_maps.dart';

/// Handles migration of legacy Python campaign data to the Flutter schema format.
///
/// When opening campaigns that lack a `world_schema`, this class:
/// 1. Generates the default D&D 5e schema
/// 2. Translates entity type names (TR/EN) to Flutter slugs
/// 3. Translates attribute keys (TR) to Flutter fieldKeys
/// 4. Back-fills missing default fields
class SchemaMigration {
  /// Migrate campaign data in-place.
  /// Returns `true` if any migration was performed.
  static bool migrate(Map<String, dynamic> data) {
    bool changed = false;

    // Legacy schema migration (Python → Flutter)
    if (!data.containsKey('world_schema')) {
      // 1. Generate and inject default schema
      final schema = generateDefaultDnd5eSchema();
      data['world_schema'] = deepCopyJson(schema.toJson());

      // 2. Migrate entities
      final entities = data['entities'];
      if (entities is Map) {
        final migratedEntities = <String, dynamic>{};
        for (final entry in entities.entries) {
          final entity = entry.value;
          if (entity is Map) {
            final dynamicMap = Map<String, dynamic>.from(entity);
            _migrateEntity(dynamicMap);
            migratedEntities[entry.key.toString()] = dynamicMap;
          } else {
            migratedEntities[entry.key.toString()] = entity;
          }
        }
        data['entities'] = migratedEntities;
      } else if (entities is List) {
        final migratedList = <dynamic>[];
        for (final entity in entities) {
          if (entity is Map) {
            final dynamicMap = Map<String, dynamic>.from(entity);
            _migrateEntity(dynamicMap);
            migratedList.add(dynamicMap);
          } else {
            migratedList.add(entity);
          }
        }
        data['entities'] = migratedList;
      }

      changed = true;
    }

    // UUID backfill for existing campaigns
    if (!data.containsKey('world_id')) {
      data['world_id'] = const Uuid().v4();
      data['created_at'] ??= DateTime.now().toIso8601String();
      changed = true;
    }

    return changed;
  }

  static void _migrateEntity(Map<String, dynamic> entity) {
    // Translate type → slug
    _migrateType(entity);

    // Translate attribute keys
    _migrateAttributes(entity);

    // Back-fill missing default fields
    _backfillDefaults(entity);

    // Fix image_path → images migration
    _migrateImages(entity);
  }

  /// Translate `type` field from Turkish/English name to Flutter slug.
  static void _migrateType(Map<String, dynamic> entity) {
    final type = entity['type'];
    if (type is! String) return;

    // Try direct lookup in schemaMap (covers both TR and EN names)
    final slug = schemaMap[type];
    if (slug != null) {
      entity['type'] = slug;
      return;
    }

    // Fallback: normalize to lowercase-hyphenated
    entity['type'] = type.toLowerCase().replaceAll(' ', '-');
  }

  /// Translate Turkish attribute keys to Flutter fieldKeys.
  static void _migrateAttributes(Map<String, dynamic> entity) {
    final attrs = entity['attributes'];
    if (attrs is! Map) return;

    final migrated = <String, dynamic>{};
    for (final entry in attrs.entries) {
      final key = entry.key.toString();
      // Look up in propertyMap; if not found keep original key
      final newKey = propertyMap[key] ?? key;
      migrated[newKey] = entry.value;
    }
    entity['attributes'] = migrated;
  }

  /// Back-fill missing fields from the default entity structure.
  static void _backfillDefaults(Map<String, dynamic> entity) {
    for (final entry in defaultEntityFields.entries) {
      if (!entity.containsKey(entry.key)) {
        final value = entry.value;
        if (value == null) continue; // skip null defaults (e.g. location_id)
        // Deep-copy default value to avoid shared mutable state
        entity[entry.key] = _deepCopy(value);
      }
    }
  }

  /// Migrate `image_path` → `images` list.
  static void _migrateImages(Map<String, dynamic> entity) {
    final images = entity['images'];
    final imagePath = entity['image_path'];

    if ((images == null || (images is List && images.isEmpty)) &&
        imagePath is String &&
        imagePath.isNotEmpty) {
      entity['images'] = [imagePath];
    }
  }

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _deepCopy(v)));
    }
    if (value is List) {
      return value.map(_deepCopy).toList();
    }
    return value;
  }
}
