import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncValue;

import '../../data/database/database_provider.dart';
import 'campaign_provider.dart';
import 'online_worlds_provider.dart';
import 'package_provider.dart';

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

/// Active-item scoped outbox status. UI consumes this so a fresh offline
/// world doesn't show "pending sync" because some unrelated cloud_backups
/// row exists.
///
/// Scope rules:
///   - Active world (online) → rows where `scope_id = worldId`. Mirror push
///     helpers already write the world id into `scope_id`; row-level filter
///     matches exactly.
///   - Active world (offline) → empty. Offline worlds don't sync — UI must
///     read "Cloud synced" / "Auto-saving…" without the cloud-pending tail.
///   - Active package (no campaign) → rows whose `target_pk` equals the
///     package name or begins with `<packageName>:` (covers
///     `personal_packages` + `personal_package_entities`).
///   - No active item → empty.
final activeItemOutboxStatusProvider = StreamProvider<OutboxStatus>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final activeCampaign = ref.watch(activeCampaignProvider);
  final activePackage = ref.watch(activePackageProvider);
  final onlineIds = ref.watch(onlineWorldIdsProvider);

  if (activeCampaign == null && activePackage == null) {
    return Stream.value(OutboxStatus.empty);
  }

  String? worldId;
  if (activeCampaign != null) {
    final data = ref.read(activeCampaignProvider.notifier).data;
    worldId = data?['world_id'] as String?;
    if (worldId == null || !onlineIds.contains(worldId)) {
      return Stream.value(OutboxStatus.empty);
    }
  }

  final localWorldId = worldId;
  final q = db.select(db.syncOutbox)
    ..where((t) {
      if (localWorldId != null) {
        return t.scopeId.equals(localWorldId);
      }
      final pkg = activePackage;
      if (pkg != null) {
        return t.targetPk.equals(pkg) |
            t.targetPk.like('$pkg:%');
      }
      return const Constant(false);
    });

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
