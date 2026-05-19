import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/beta_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/outbox_status_provider.dart';
import '../../application/providers/personal_sync_provider.dart';
import '../../application/providers/sync_engine_provider.dart';
import '../../application/providers/world_mirror_provider.dart';
import '../../application/services/cloud_catchup_service.dart';
import '../../application/services/world_reconciler.dart';
import '../../core/utils/error_format.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../theme/dm_tool_colors.dart';

/// Full manual sync chain — push personal + world outboxes, reconcile world
/// mirror, drain outbox, then run catch-up pulls. Shared by world and
/// character Save & Sync dialogs.
Future<void> runFullManualSync(WidgetRef ref) async {
  await runManualPersonalSync(ref);
  await runManualWorldSync(ref);
  await ref.read(worldReconcilerProvider).reconcile();
  await ref.read(syncEngineProvider).forceTick();
  await ref.read(cloudCatchupServiceProvider).runAll();
}

class SectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const SectionLabel(this.text, this.palette, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DmToolColors palette;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: palette.featureCardBorder),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Shared "Sync" button — runs [runFullManualSync] when [enabled] is true.
/// Caller computes enabled-ness from its own context (world online state,
/// char beta/online routing, etc.) and supplies tooltips.
class SyncButton extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final bool enabled;
  final String enabledTooltip;
  final String disabledTooltip;

  const SyncButton({
    super.key,
    required this.palette,
    required this.enabled,
    this.enabledTooltip = 'Force sync now (auto-sync on)',
    this.disabledTooltip = 'Sign in + join beta to sync',
  });

  @override
  ConsumerState<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<SyncButton> {
  bool _busy = false;

  Future<void> _sync() async {
    if (_busy) return;
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    debugPrint('[SyncButton] ▶ manual sync started');
    try {
      await runFullManualSync(ref);
      debugPrint('[SyncButton] ✓ sync complete ${sw.elapsedMilliseconds}ms');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete')),
      );
    } catch (e, st) {
      debugPrint('[SyncButton] ✗ sync failed ${sw.elapsedMilliseconds}ms: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.enabled ? widget.enabledTooltip : widget.disabledTooltip,
      child: ActionButton(
        icon: Icons.cloud_sync,
        label: _busy ? 'Syncing...' : 'Sync',
        onPressed: (widget.enabled && !_busy) ? _sync : null,
        palette: widget.palette,
      ),
    );
  }
}

/// Cloud storage usage bar — used MB / quota MB + per-item limit hint.
class StorageUsageBar extends ConsumerWidget {
  final DmToolColors palette;
  const StorageUsageBar({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(cloudStorageUsedProvider);
    final quotaBytes = ref.watch(betaProvider).quotaBytes;

    return storageAsync.when(
      data: (bytes) {
        final usedMb = bytes / (1024 * 1024);
        final totalMb = quotaBytes / (1024 * 1024);
        const itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / quotaBytes).clamp(0.0, 1.0);
        final remainingMb = totalMb - usedMb;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: palette.br,
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: palette.featureCardBorder,
                      color: ratio > 0.9
                          ? palette.dangerBtnBg
                          : palette.featureCardAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${usedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(0)} MB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${remainingMb.toStringAsFixed(1)} MB remaining  |  Max ${itemLimitMb.toStringAsFixed(0)} MB per item',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: palette.featureCardAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Combined: cloud backups + media assets. Temporary limit.',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 8,
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        isOfflineError(e)
            ? "You're offline — storage info unavailable."
            : 'Could not load storage info',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
    );
  }
}

/// Persistent outbox depth row + "Retry now" button. When rows are stuck
/// (>3 attempts) the most-recent error is surfaced beneath the label.
class OutboxStatusRow extends ConsumerWidget {
  final OutboxStatus outbox;
  final DmToolColors palette;
  const OutboxStatusRow({
    super.key,
    required this.outbox,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stuck = outbox.hasIssue;
    final color = stuck ? palette.dangerBtnBg : palette.featureCardAccent;
    final icon = stuck ? Icons.cloud_off : Icons.cloud_sync;
    final label = stuck
        ? 'Stuck (${outbox.maxAttempts} attempts)'
        : '${outbox.pending} pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: color)),
                if (stuck && outbox.lastError != null)
                  Text(
                    outbox.lastError!,
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref.read(syncEngineProvider).forceTick(),
            child: const Text('Retry now', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
