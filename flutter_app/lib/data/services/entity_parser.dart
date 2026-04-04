import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/world_schema.dart';

const _uuid = Uuid();

/// Converts external data (API responses, JSON imports) into Entity objects.
class EntityParser {
  /// Parse a raw JSON map into an Entity, mapping fields according to the schema.
  ///
  /// [data] is the raw key-value map from an API or JSON import.
  /// [categorySlug] is the target category slug (e.g. 'monster', 'spell').
  /// [schema] is the world schema used for field mapping.
  static Entity parseFromExternal(
    Map<String, dynamic> data,
    String categorySlug,
    WorldSchema schema,
  ) {
    final category =
        schema.categories.where((c) => c.slug == categorySlug).firstOrNull;

    final name = _extractString(data, ['name', 'title']) ?? 'Unnamed';
    final source = _extractString(data, ['source', 'src']) ?? '';
    final description =
        _extractString(data, ['description', 'desc', 'text']) ?? '';

    // Extract images
    final images = <String>[];
    if (data['image'] is String && (data['image'] as String).isNotEmpty) {
      images.add(data['image'] as String);
    }
    if (data['images'] is List) {
      images.addAll((data['images'] as List).whereType<String>());
    }

    // Extract tags
    final tags = <String>[];
    if (data['tags'] is List) {
      tags.addAll((data['tags'] as List).whereType<String>());
    }

    // Map remaining fields based on schema
    final fields = <String, dynamic>{};
    if (category != null) {
      for (final fieldSchema in category.fields) {
        final key = fieldSchema.fieldKey;
        // Try exact key match first, then try common variations
        final value =
            data[key] ?? data[_toCamelCase(key)] ?? data[_toSnakeCase(key)];
        if (value != null) {
          fields[key] = value;
        }
      }
    }

    // Also include raw 'attributes' map if present
    if (data['attributes'] is Map) {
      for (final entry in (data['attributes'] as Map).entries) {
        fields[entry.key.toString()] = entry.value;
      }
    }

    // Include special fields
    for (final key in [
      'stat_block',
      'stats',
      'combat_stats',
      'traits',
      'actions',
      'reactions',
      'legendary_actions',
      'spells',
    ]) {
      if (data.containsKey(key)) {
        fields[key == 'stats' ? 'stat_block' : key] = data[key];
      }
    }

    return Entity(
      id: _uuid.v4(),
      name: name,
      categorySlug: categorySlug,
      source: source,
      description: description,
      images: images,
      tags: tags,
      fields: fields,
      dmNotes: _extractString(data, ['dm_notes', 'dmNotes', 'notes']) ?? '',
    );
  }

  static String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final val = data[key];
      if (val is String && val.isNotEmpty) return val;
    }
    return null;
  }

  static String _toCamelCase(String snake) {
    final parts = snake.split('_');
    if (parts.length <= 1) return snake;
    return parts.first +
        parts
            .skip(1)
            .map((p) =>
                p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '')
            .join();
  }

  static String _toSnakeCase(String camel) {
    return camel.replaceAllMapped(
        RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  }
}
