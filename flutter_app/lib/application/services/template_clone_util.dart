import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/world_schema.dart';

const _uuid = Uuid();

/// Deep-clones a template with fresh UUIDs on every nested entity so the
/// new template is fully independent of the source. `originalHash` is
/// cleared so the fork gets a brand-new lineage on first save.
///
/// Templates tab, worlds tab ve packages tab "Copy built-in first" akışında
/// bu helper'ı ortak kullanır.
WorldSchema cloneTemplateAsNew(WorldSchema t, String newName) {
  final now = DateTime.now().toUtc().toIso8601String();
  final newId = _uuid.v4();
  return t.copyWith(
    schemaId: newId,
    name: newName,
    createdAt: now,
    updatedAt: now,
    originalHash: null,
    categories: t.categories
        .map((c) => c.copyWith(
              categoryId: _uuid.v4(),
              schemaId: newId,
              isBuiltin: false,
              fields: c.fields
                  .map((f) => f.copyWith(
                        fieldId: _uuid.v4(),
                        isBuiltin: false,
                      ))
                  .toList(),
            ))
        .toList(),
  );
}
