import 'package:drift/drift.dart';

/// Persistent outbox for cloud-sync operations. v12 shape (PR-D5):
/// per-row ops, not per-kind blobs. Idempotency keyed on
/// (target_table, target_pk, op_type) — coalesce same-row pending edits to
/// avoid bloat under rapid typing.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  /// UUID v4 PK — stable across retries.
  TextColumn get opId => text()();

  /// Postgres table name (e.g. `world_entities`, `world_sessions`).
  TextColumn get targetTable => text()();

  /// Primary key value in the target table (composite PKs serialized as
  /// `worldId:packageId` etc).
  TextColumn get targetPk => text()();

  /// `upsert` | `delete`.
  TextColumn get opType => text()();

  /// Optional scope (worldId for world-scoped rows). Used by fan-out filters.
  TextColumn get scopeId => text().nullable()();

  /// Row snapshot (JSON). For deletes typically `{}` plus any tombstone
  /// metadata the handler needs.
  TextColumn get payloadJson => text()();

  IntColumn get payloadBytes =>
      integer().withDefault(const Constant(0))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get nextAttemptAt =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}
