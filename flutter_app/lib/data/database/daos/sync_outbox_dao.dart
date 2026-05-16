import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_outbox_table.dart';

part 'sync_outbox_dao.g.dart';

/// Outbox entity kinds — keep aligned with [SyncEngine] handler switch.
class OutboxKind {
  static const worldEntity = 'world_entity';
  static const worldCharacter = 'world_character';
  static const worldState = 'world_state';
  static const worldMapData = 'world_map_data';
  static const worldSession = 'world_session';
  static const worldSettings = 'world_settings';
  static const worldPackage = 'world_package';
  static const personalPackage = 'personal_package';
  static const cloudBackupWorld = 'cloud_backup_world';
  static const cloudBackupPackage = 'cloud_backup_package';
}

class OutboxOp {
  static const upsert = 'upsert';
  static const delete = 'delete';
}

@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  /// Inserts (or coalesces) an outbox op. MUST be called inside the same
  /// Drift transaction as the local mutation, so the outbox row commits
  /// atomically with the data change.
  ///
  /// Coalescing rules:
  ///   - existing `upsert` + new `upsert` → swap payload, reset attempts,
  ///     reschedule now, keep original opId.
  ///   - existing `upsert` + new `delete` → drop the upsert, insert delete.
  ///   - existing `delete` + anything → leave the delete (it wins).
  Future<String> enqueue({
    required String opId,
    required String entityKind,
    required String entityId,
    String? scopeId,
    required String opType,
    required String payloadJson,
  }) async {
    final now = DateTime.now().toUtc();
    final bytes = payloadJson.length;

    final existing = await (select(syncOutbox)
          ..where((t) =>
              t.entityKind.equals(entityKind) & t.entityId.equals(entityId)))
        .get();

    if (existing.isEmpty) {
      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          opId: opId,
          entityKind: entityKind,
          entityId: entityId,
          scopeId: Value(scopeId),
          opType: opType,
          payloadJson: payloadJson,
          payloadBytes: Value(bytes),
          createdAt: Value(now),
          nextAttemptAt: Value(now),
        ),
      );
      return opId;
    }

    if (opType == OutboxOp.delete) {
      final hasDelete = existing.any((r) => r.opType == OutboxOp.delete);
      if (hasDelete) return existing.first.opId;
      // Drop pending upsert(s), insert delete.
      await (delete(syncOutbox)
            ..where((t) =>
                t.entityKind.equals(entityKind) &
                t.entityId.equals(entityId)))
          .go();
      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          opId: opId,
          entityKind: entityKind,
          entityId: entityId,
          scopeId: Value(scopeId),
          opType: OutboxOp.delete,
          payloadJson: payloadJson,
          payloadBytes: Value(bytes),
          createdAt: Value(now),
          nextAttemptAt: Value(now),
        ),
      );
      return opId;
    }

    // opType == upsert
    final deleteRow =
        existing.where((r) => r.opType == OutboxOp.delete).cast<SyncOutboxRow?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
    if (deleteRow != null) {
      // Pending delete wins — don't re-enqueue upsert.
      return deleteRow.opId;
    }
    final upRow = existing.first;
    await (update(syncOutbox)..where((t) => t.opId.equals(upRow.opId))).write(
      SyncOutboxCompanion(
        payloadJson: Value(payloadJson),
        payloadBytes: Value(bytes),
        scopeId: Value(scopeId),
        attempts: const Value(0),
        lastError: const Value(null),
        nextAttemptAt: Value(now),
      ),
    );
    return upRow.opId;
  }

  /// Stream that fires whenever any row is ready (next_attempt_at <= now).
  /// SyncEngine listens here to wake up.
  Stream<int> watchReadyCount() {
    final now = DateTime.now().toUtc();
    final c = syncOutbox.opId.count();
    final q = selectOnly(syncOutbox)
      ..addColumns([c])
      ..where(syncOutbox.nextAttemptAt
          .isSmallerOrEqualValue(now));
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }

  /// Cheaper signal: fire on any change to the table; engine re-checks.
  Stream<void> watchAnyChange() => select(syncOutbox).watch().map((_) {});

  /// Dead-letter threshold — rows past this attempt count are inert until a
  /// developer inspects them. Keep in sync with [SyncEngine._dlqAttempts].
  static const int dlqAttempts = 50;

  Future<List<SyncOutboxRow>> nextBatch({int limit = 20}) {
    final now = DateTime.now().toUtc();
    return (select(syncOutbox)
          ..where((t) =>
              t.nextAttemptAt.isSmallerOrEqualValue(now) &
              t.attempts.isSmallerThanValue(dlqAttempts))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> totalCount() async {
    final c = syncOutbox.opId.count();
    final q = selectOnly(syncOutbox)..addColumns([c]);
    final r = await q.getSingle();
    return r.read(c) ?? 0;
  }

  Future<int> readyCount() async {
    final now = DateTime.now().toUtc();
    final c = syncOutbox.opId.count();
    final q = selectOnly(syncOutbox)
      ..addColumns([c])
      ..where(syncOutbox.nextAttemptAt.isSmallerOrEqualValue(now));
    final r = await q.getSingle();
    return r.read(c) ?? 0;
  }

  Future<int> deleteOp(String opId) =>
      (delete(syncOutbox)..where((t) => t.opId.equals(opId))).go();

  Future<void> markFailure({
    required String opId,
    required String error,
    required Duration nextDelay,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(syncOutbox)..where((t) => t.opId.equals(opId))).write(
      SyncOutboxCompanion(
        attempts: const Value.absent(), // bumped by raw stmt below
        lastError: Value(error),
        lastAttemptAt: Value(now),
        nextAttemptAt: Value(now.add(nextDelay)),
      ),
    );
    await customStatement(
        'UPDATE sync_outbox SET attempts = attempts + 1 WHERE op_id = ?',
        [opId]);
  }

  /// Manual force-tick helper: reset next_attempt_at to now for live rows
  /// (used by the "Retry now" UI affordance). DLQ rows are skipped — once
  /// past [dlqAttempts] they require explicit inspection, not a blanket
  /// revival that re-spins the drain loop.
  Future<int> rescheduleAllNow() async {
    final now = DateTime.now().toUtc();
    return (update(syncOutbox)
          ..where((t) => t.attempts.isSmallerThanValue(dlqAttempts)))
        .write(SyncOutboxCompanion(nextAttemptAt: Value(now)));
  }
}
