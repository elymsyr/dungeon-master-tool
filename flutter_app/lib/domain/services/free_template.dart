import '../entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import '../entities/schema/world_schema.dart';
import '../entities/schema/world_schema_hash.dart';

/// The one gate between the built-in and the free code paths
/// (docs/free-template/ROADMAP.md K3).
bool isFreeTemplate(WorldSchema schema) => schema.freeRootId != null;

/// True when [schema] descends from the built-in SRD template.
bool isSrdLineage(WorldSchema schema) =>
    schema.freeRootId == builtinDnd5eV2SchemaId;

/// SRD types that have no place in a free template yet (ROADMAP §6). Later
/// phases convert more types instead of dropping them.
const _droppedOnCopy = {FieldType.crCalculator};

/// [source] copied as a new free template [id] named [name]. Works for the
/// built-in template (SRD copy, DESIGN §16) and for a free one (the lineage
/// root is kept). Category and field ids are kept: they are scoped to the
/// schema. The original hash is frozen here, at creation.
WorldSchema copyAsFreeTemplate(
  WorldSchema source, {
  required String id,
  required String name,
  required String now,
}) {
  final fromBuiltin = !isFreeTemplate(source);
  final copy = source.copyWith(
    schemaId: id,
    name: name,
    freeRootId: source.freeRootId ?? source.schemaId,
    createdAt: now,
    updatedAt: now,
    originalHash: null,
    categories: [
      for (final c in source.categories)
        c.copyWith(
          schemaId: id,
          isPlayerCard: fromBuiltin
              ? (c.slug == 'player-character' ? true : null)
              : c.isPlayerCard,
          fields: [
            for (final f in c.fields)
              if (!_droppedOnCopy.contains(f.fieldType)) f,
          ],
        ),
    ],
  );
  return copy.copyWith(originalHash: computeWorldSchemaContentHash(copy));
}

/// A new free template holding only the player card (V1). Its fixed fields
/// (level, automatic resources) arrive in Faz 6.
WorldSchema emptyFreeTemplate({
  required String id,
  required String name,
  required String playerCardName,
  required String now,
}) {
  final schema = WorldSchema(
    schemaId: id,
    name: name,
    freeRootId: id,
    createdAt: now,
    updatedAt: now,
    categories: [
      EntityCategorySchema(
        categoryId: '$id-player',
        schemaId: id,
        name: playerCardName,
        slug: 'player-character',
        icon: 'person_outline',
        color: '#4caf50',
        isPlayerCard: true,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
  return schema.copyWith(originalHash: computeWorldSchemaContentHash(schema));
}
