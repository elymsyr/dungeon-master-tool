import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_characters` (migration 026 + 039 unified).
///
/// `payloadJson` (mapped to SQL column `payload_json`) is the **opaque**
/// serialized Character.entity blob. NEVER normalize, parse, or re-serialize —
/// see `Character Mechanics Preservation` in `docs/full_drift_migration_plan.md`.
/// Mechanics are derived at read-time by [CharacterResolver]; losing fields
/// here orphans level-up state.
@DataClassName('WorldCharacterRow')
class WorldCharacters extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get ownerId => text().nullable()();
  TextColumn get templateId => text()();
  TextColumn get templateName => text()();
  TextColumn get payloadJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get referencedEntityIdsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
