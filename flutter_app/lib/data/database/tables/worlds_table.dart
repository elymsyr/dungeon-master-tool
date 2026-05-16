import 'package:drift/drift.dart';

/// Mirrors Postgres `public.worlds` (migration 026).
///
/// `templateId` / `templateHash` / `templateOriginalHash` absorb the old
/// `world_schemas` table — Postgres keeps them flat on `worlds`. The legacy
/// `state_json` blob is gone; granular state lives in [WorldMapData],
/// [WorldSessions], [WorldSettings] (migration 042).
class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  TextColumn get worldName => text()();
  TextColumn get templateId => text().nullable()();
  TextColumn get templateHash => text().nullable()();
  TextColumn get templateOriginalHash => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastCloudPushAt => dateTime().nullable()();
  TextColumn get lastPushedHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
