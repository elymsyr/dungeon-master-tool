import 'package:drift/drift.dart';

/// Hub-level character row. Replaces the per-file JSON storage under
/// `AppPaths.charactersDir`; outbox-driven sync (PR-SYNC-1) and transactional
/// mutations depend on this table.
///
/// `entityJson` carries the serialized [Character.entity] blob (name/fields/
/// tags/images/...). The wrapping Character (templateId / worldId / ownerId /
/// timestamps) is split into typed columns so list/filter queries don't have
/// to decode the blob.
@DataClassName('CharacterRow')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get templateName => text()();
  TextColumn get entityJson => text()();
  TextColumn get worldId => text().nullable()();
  TextColumn get ownerId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
