import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/save_state_provider.dart';

/// Item kapatılırken çalışan flush. Auto-save kaldırıldığı için close noktası
/// son-save+push fırsatıdır. Sessizce diske yazar ve mirror'a push'lar; cloud
/// snapshot (`manualBackupRunnerProvider`) ayrı bir aksiyondur ve burada
/// otomatik tetiklenmez. Hata olsa bile close akışını engellemiyoruz.
Future<bool> confirmCloseWithBackupCheck({
  required BuildContext context,
  required WidgetRef ref,
  required String itemName,
}) async {
  try {
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'close-guard-save',
      'Saving "$itemName"...',
      () => ref.read(saveStateProvider.notifier).saveNow(pushAfter: true),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
  return true;
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
