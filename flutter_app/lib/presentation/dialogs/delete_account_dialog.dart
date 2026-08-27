import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/account_deletion_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Tek tuşla hesap + veri silme. Onaylanırsa
/// [deleteAccountAndData] çalışır; kullanıcı sign-out olur ve hub'ın auth
/// listener'ı landing'e götürür.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteAccountConfirmTitle),
      content: Text(l10n.deleteAccountConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.delete_forever, size: 16),
          label: Text(l10n.deleteAccount),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: palette.dangerBtnBg,
            foregroundColor: palette.dangerBtnText,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Silme sırasında ekranı kilitle — yarıda kalan bir akışta kullanıcı başka
  // bir şeye dokunmasın.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final String uid;
  try {
    uid = await deleteCloudAccountData(ref);
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.deleteAccountFailed(e.toString()))),
    );
    return;
  }

  // İlerleme dialog'u oturum kapanmadan ÖNCE kapanır: `signOut` hub listener'ı
  // üzerinden landing'e navigate ediyor, açık kalan route dispose olan bir
  // Navigator'da pop edilmiş oluyordu (`!_debugLocked` assert'i).
  navigator.pop();
  messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountSuccess)));
  await finishAccountDeletion(ref, uid);
}
