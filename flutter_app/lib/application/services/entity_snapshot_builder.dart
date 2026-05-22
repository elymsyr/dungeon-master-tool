import '../../domain/entities/entity.dart';
import '../../domain/entities/projection/entity_snapshot.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/value_objects/relation_value.dart';
import 'mention_text.dart';

/// Builds a serializable [EntitySnapshot] from a live [Entity] + the world
/// schema. Filters out DM-only / private fields so the player view never
/// sees them by accident.
class EntitySnapshotBuilder {
  /// [entities] is the live world entity map — used to resolve `relation`
  /// field ids to entity names so the projection never shows a raw id.
  ///
  /// [imageRemap] swaps image paths in [EntitySnapshot.imagePaths] — used by
  /// projection to inject quota-full transient refs (which are deliberately
  /// not persisted onto the entity) without mutating the entity.
  static EntitySnapshot build({
    required Entity entity,
    required WorldSchema schema,
    Map<String, Entity> entities = const {},
    Map<String, String> imageRemap = const {},
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
        final ft = field.fieldType;
        // Asset path/URI fields — never render as raw text.
        if (ft == FieldType.image ||
            ft == FieldType.file ||
            ft == FieldType.pdf) {
          continue;
        }
        final raw = entity.fields[field.fieldKey];
        if (raw == null) continue;

        final String str;
        if (ft == FieldType.relation) {
          // Resolve relation ids to entity names; drop unresolvable ids.
          str = extractRelationIds(raw)
              .map((id) => entities[id]?.name)
              .whereType<String>()
              .where((n) => n.isNotEmpty)
              .join(', ');
        } else if (ft == FieldType.text ||
            ft == FieldType.textarea ||
            ft == FieldType.markdown) {
          str = stripMentions(_stringify(raw));
        } else {
          str = _stringify(raw);
        }
        if (str.isEmpty) continue;

        fieldRows.add(EntityFieldSnapshot(
          label: field.label,
          value: str,
          groupLabel: field.groupId != null ? groupLabels[field.groupId] : null,
        ));
      }
    }

    // Image paths — combine legacy imagePath with images list, applying the
    // projection image remap (transient refs) if any.
    final imagePaths = <String>[
      if (entity.imagePath.isNotEmpty)
        imageRemap[entity.imagePath] ?? entity.imagePath,
      for (final img in entity.images) imageRemap[img] ?? img,
    ];

    return EntitySnapshot(
      id: entity.id,
      name: entity.name,
      categorySlug: entity.categorySlug,
      categoryName: cat?.name ?? entity.categorySlug,
      categoryColorHex: cat?.color ?? '#888888',
      description: stripMentions(entity.description),
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
