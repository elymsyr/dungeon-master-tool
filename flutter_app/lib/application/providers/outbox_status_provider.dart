import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';

/// PR-SYNC-6: outbox-derived sync status. Replaces `CloudSyncState` so the
/// UI sources progress straight from the persistent queue. `maxAttempts`
/// surfaces the "stuck — investigate" signal; `pending` is the live row
/// count.
class OutboxStatus {
  final int pending;
  final int maxAttempts;
  final String? lastError;
  const OutboxStatus({
    required this.pending,
    required this.maxAttempts,
    this.lastError,
  });

  static const empty = OutboxStatus(pending: 0, maxAttempts: 0);

  bool get isSyncing => pending > 0 && maxAttempts == 0;
  bool get hasIssue => maxAttempts > 3;
}

final outboxStatusProvider = StreamProvider<OutboxStatus>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = db.syncOutbox;
  final q = db.select(outbox);
  return q.watch().map((rows) {
    if (rows.isEmpty) return OutboxStatus.empty;
    var maxA = 0;
    String? lastErr;
    for (final r in rows) {
      if (r.attempts > maxA) {
        maxA = r.attempts;
        lastErr = r.lastError;
      }
    }
    return OutboxStatus(
      pending: rows.length,
      maxAttempts: maxA,
      lastError: lastErr,
    );
  });
});
