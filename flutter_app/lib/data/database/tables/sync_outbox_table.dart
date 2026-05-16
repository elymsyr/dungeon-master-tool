import 'package:drift/drift.dart';

/// Persistent outbox for cloud-sync operations (PR-SYNC-1).
///
/// Every mutation that should mirror to the cloud writes a row here in the
/// same Drift transaction as the local change. [SyncEngine] drains the table
/// in arrival order, with per-(entityKind,entityId) coalescing inside the
/// DAO so back-to-back edits collapse to a single upload.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  /// UUID v4 PK — stable across retries so the engine can identify the row.
  TextColumn get opId => text()();

  /// Domain kind: `world_entity`, `world_character`, `world_state`,
  /// `world_map_data`, `world_session`, `world_settings`, `world_package`,
  /// `personal_package`, `cloud_backup_world`, `cloud_backup_package`.
  TextColumn get entityKind => text()();

  /// Domain id (entityId / characterId / packageId / worldId etc).
  TextColumn get entityId => text()();

  /// Optional scope (worldId for world-scoped rows). Used for fan-out filters.
  TextColumn get scopeId => text().nullable()();

  /// `upsert` | `delete`.
  TextColumn get opType => text()();

  /// Serialized payload (JSON). For deletes typically `{}` plus any tombstone
  /// metadata the handler needs.
  TextColumn get payloadJson => text()();

  IntColumn get payloadBytes =>
      integer().withDefault(const Constant(0))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Earliest time the row is eligible to retry. Defaults to now (= ready).
  DateTimeColumn get nextAttemptAt =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}
