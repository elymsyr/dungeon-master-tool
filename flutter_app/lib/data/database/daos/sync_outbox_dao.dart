import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_outbox_table.dart';

part 'sync_outbox_dao.g.dart';

/// v12 sync outbox — per-row ops + coalescing.
///
/// **Coalescing rule** (PR-D5 enqueue path): before inserting, if a pending
/// row with same `(targetTable, targetPk, opType)` exists, overwrite its
/// payload + bump `createdAt`/`nextAttemptAt` instead of inserting a new row.
/// Prevents outbox bloat under rapid typing.
@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  Future<List<SyncOutboxRow>> readyBatch({
    required DateTime now,
    int limit = 100,
  }) =>
      (select(syncOutbox)
            ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
            ..orderBy([
              (t) => OrderingTerm.asc(t.nextAttemptAt),
              (t) => OrderingTerm.asc(t.createdAt),
            ])
            ..limit(limit))
          .get();

  Future<SyncOutboxRow?> findPending({
    required String targetTable,
    required String targetPk,
    required String opType,
  }) =>
      (select(syncOutbox)
            ..where((t) =>
                t.targetTable.equals(targetTable) &
                t.targetPk.equals(targetPk) &
                t.opType.equals(opType))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Coalescing enqueue. Returns the opId of the live row (existing or new).
  Future<String> enqueueCoalesced({
    required String opId,
    required String targetTable,
    required String targetPk,
    required String opType,
    required String payloadJson,
    String? scopeId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    return transaction(() async {
      final existing = await findPending(
        targetTable: targetTable,
        targetPk: targetPk,
        opType: opType,
      );
      if (existing != null) {
        await (update(syncOutbox)
              ..where((t) => t.opId.equals(existing.opId)))
            .write(
          SyncOutboxCompanion(
            payloadJson: Value(payloadJson),
            payloadBytes: Value(payloadJson.length),
            scopeId: Value(scopeId),
            attempts: const Value(0),
            lastError: const Value(null),
            lastAttemptAt: const Value(null),
            nextAttemptAt: Value(ts),
            createdAt: Value(ts),
          ),
        );
        return existing.opId;
      }
      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        opId: opId,
        targetTable: targetTable,
        targetPk: targetPk,
        opType: opType,
        scopeId: Value(scopeId),
        payloadJson: payloadJson,
        payloadBytes: Value(payloadJson.length),
        createdAt: Value(ts),
        nextAttemptAt: Value(ts),
      ));
      return opId;
    });
  }

  Future<int> markFailed(
    String opId, {
    required String error,
    required DateTime nextAttemptAt,
  }) =>
      (update(syncOutbox)..where((t) => t.opId.equals(opId))).write(
        SyncOutboxCompanion(
          attempts: const Value.absent(),
          lastError: Value(error),
          lastAttemptAt: Value(DateTime.now()),
          nextAttemptAt: Value(nextAttemptAt),
        ),
      );

  Future<int> incrementAttempts(String opId) async {
    return customUpdate(
      'UPDATE sync_outbox SET attempts = attempts + 1, '
      'last_attempt_at = ? WHERE op_id = ?',
      variables: [
        Variable<DateTime>(DateTime.now()),
        Variable<String>(opId),
      ],
      updates: {syncOutbox},
    );
  }

  Future<int> deleteById(String opId) =>
      (delete(syncOutbox)..where((t) => t.opId.equals(opId))).go();

  Future<int> deleteAll() => delete(syncOutbox).go();

  Stream<int> watchPendingCount() {
    final query = selectOnly(syncOutbox)
      ..addColumns([syncOutbox.opId.count()]);
    return query
        .map((row) => row.read(syncOutbox.opId.count()) ?? 0)
        .watchSingle()
        .distinct();
  }
}
