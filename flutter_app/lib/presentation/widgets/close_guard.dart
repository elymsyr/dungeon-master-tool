import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/cloud_sync_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../core/config/supabase_config.dart';

/// Confirms that the user wants to close an item (world/package) when local
/// or cloud state is not up-to-date.
///
/// Behavior:
///   - Returns `true` immediately if there's nothing to warn about:
///     local is saved AND (cloud not configured / signed-out / already
///     synced with zero failures).
///   - Otherwise ALWAYS shows a 3-choice dialog: Cancel / Close Anyway /
///     Backup & Close. (There is intentionally no "auto backup" setting —
///     the user asked us to always ask when state isn't current.)
///   - The "Backup & Close" branch runs local save + cloud backup under
///     a loading overlay before returning `true`.
///
/// Return value: `true` means "proceed with close"; `false` means "stay".
Future<bool> confirmCloseWithBackupCheck({
  required BuildContext context,
  required WidgetRef ref,
  required String itemName,
}) async {
  final hasCloud = SupabaseConfig.isConfigured;
  final isAuthed = ref.read(authProvider) != null;

  final saveStatus = ref.read(saveStateProvider);
  final localClean = saveStatus == SaveStatus.saved;

  // No cloud → only local state matters.
  if (!hasCloud || !isAuthed) {
    if (localClean) return true;
    return _askLocalOnly(context, ref, itemName);
  }

  final syncState = ref.read(cloudSyncProvider);
  final cloudClean = syncState.status == CloudSyncStatus.synced &&
      syncState.failedCount == 0;
  if (localClean && cloudClean) return true;

  if (!context.mounted) return true;

  final body = StringBuffer();
  if (!localClean) body.writeln('• Local save pending');
  if (!cloudClean) body.writeln('• Cloud backup not up to date');
  body.write('\nWhat would you like to do?');

  final choice = await showDialog<_CloseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('"$itemName" — unsaved changes'),
      content: Text(body.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.closeAnyway),
          child: const Text('Close Anyway'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.backupAndClose),
          child: const Text('Backup & Close'),
        ),
      ],
    ),
  );

  switch (choice) {
    case null:
    case _CloseChoice.cancel:
      return false;
    case _CloseChoice.closeAnyway:
      return true;
    case _CloseChoice.backupAndClose:
      try {
        await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'close-guard-backup',
          'Saving and backing up "$itemName"...',
          () async {
            await ref.read(saveStateProvider.notifier).saveNow();
            await ref.read(cloudSyncProvider.notifier).backupActiveItem();
          },
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup failed: $e')),
          );
        }
      }
      return true;
  }
}

/// Cloud-less fallback: only warn about local save state.
Future<bool> _askLocalOnly(
  BuildContext context,
  WidgetRef ref,
  String itemName,
) async {
  if (!context.mounted) return true;
  final choice = await showDialog<_CloseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('"$itemName" — unsaved changes'),
      content: const Text('Local save pending.\nWhat would you like to do?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.closeAnyway),
          child: const Text('Close Anyway'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _CloseChoice.backupAndClose),
          child: const Text('Save & Close'),
        ),
      ],
    ),
  );
  switch (choice) {
    case null:
    case _CloseChoice.cancel:
      return false;
    case _CloseChoice.closeAnyway:
      return true;
    case _CloseChoice.backupAndClose:
      await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'close-guard-save',
        'Saving "$itemName"...',
        () => ref.read(saveStateProvider.notifier).saveNow(),
      );
      return true;
  }
}

/// Simple unconditional confirmation for contexts (like the template editor)
/// that have no dirty-state tracking. Returns `true` when the user
/// confirms closing.
Future<bool> confirmCloseUnconditional({
  required BuildContext context,
  required String title,
  String body = 'Any unsaved edits will be lost. Close?',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  return result ?? false;
}

enum _CloseChoice { cancel, closeAnyway, backupAndClose }
