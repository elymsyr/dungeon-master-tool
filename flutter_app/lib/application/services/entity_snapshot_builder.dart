import '../../domain/entities/entity.dart';
import '../../domain/entities/projection/entity_snapshot.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';

/// Builds a serializable [EntitySnapshot] from a live [Entity] + the world
/// schema. Filters out DM-only / private fields so the player view never
/// sees them by accident.
class EntitySnapshotBuilder {
  static EntitySnapshot build({
    required Entity entity,
    required WorldSchema schema,
  }) {
    EntityCategorySchema? cat;
    for (final c in schema.categories) {
      if (c.slug == entity.categorySlug) {
        cat = c;
        break;
      }
    }

    // Build the field rows in order, skipping hidden fields
    final fieldRows = <EntityFieldSnapshot>[];
    if (cat != null) {
      // Group lookup
      final groupLabels = <String, String>{
        for (final g in cat.fieldGroups) g.groupId: g.name,
      };
      final orderedFields = [...cat.fields]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      for (final field in orderedFields) {
        if (field.visibility == FieldVisibility.dmOnly ||
            field.visibility == FieldVisibility.private_) {
          continue;
        }
        final raw = entity.fields[field.fieldKey];
        if (raw == null) continue;
        final str = _stringify(raw);
        if (str.isEmpty) continue;
        fieldRows.add(EntityFieldSnapshot(
          label: field.label,
          value: str,
          groupLabel: field.groupId != null ? groupLabels[field.groupId] : null,
        ));
      }
    }

    // Image paths — combine legacy imagePath with images list
    final imagePaths = <String>[
      if (entity.imagePath.isNotEmpty) entity.imagePath,
      ...entity.images,
    ];

    return EntitySnapshot(
      id: entity.id,
      name: entity.name,
      categorySlug: entity.categorySlug,
      categoryName: cat?.name ?? entity.categorySlug,
      categoryColorHex: cat?.color ?? '#888888',
      description: entity.description,
      source: entity.source,
      tags: entity.tags,
      imagePaths: imagePaths,
      fields: fieldRows,
    );
  }

  static String _stringify(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    if (v is List) return v.map(_stringify).where((s) => s.isNotEmpty).join(', ');
    if (v is Map) {
      final parts = <String>[];
      v.forEach((k, val) {
        final s = _stringify(val);
        if (s.isNotEmpty) parts.add('$k: $s');
      });
      return parts.join(', ');
    }
    return v.toString();
  }
}
