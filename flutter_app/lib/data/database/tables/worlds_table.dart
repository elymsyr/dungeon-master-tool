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
  DateTimeColumn get renamedAt => dateTime().nullable()();

  /// Faz 4 — dünyanın bulut aynası açık mı. Bulut `world_members` satırından
  /// türetilebilir ama push kararı **çevrimdışıyken de** verilebilmeli.
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();

  /// Faz 4 — bu cihazın gördüğü son bulut revizyonu (`world_revisions`).
  /// Push yazmaz, Faz 5 pull'u okur.
  IntColumn get cloudRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
