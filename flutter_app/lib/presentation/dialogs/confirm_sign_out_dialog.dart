import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/services/guest_promotion_service.dart';
import '../../core/config/app_paths.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Shows a confirmation dialog before signing out. If confirmed, calls
/// [authProvider]'s signOut. Navigation to the landing screen is handled
/// by the hub_screen auth listener.
///
/// **O4** adds one line to the dialog, and only when it is true: if this
/// account has spent the device's guest workspace, signing out lands in an
/// empty one rather than in the data the user remembers being there. Saying so
/// up front is cheaper than the support thread that follows an empty hub.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  // **O6.** The claim used to be the flag here, but it is now deleted as soon
  // as the content it names reaches the archive, so it is false almost every
  // time the dialog opens. The question the line answers is "did *this* account
  // absorb the workspace", and that is what the account's own marker records.
  final userId = AppPaths.currentUserId;
  final guestTreeSpent = userId != null &&
      GuestPromotionService(dataRoot: AppPaths.dataRoot).isPromoted(userId);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.signOutConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.signOutConfirmBody),
          if (guestTreeSpent) ...[
            const SizedBox(height: 12),
            Text(
              l10n.signOutLocalDataNote,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.logout, size: 16),
          label: Text(l10n.signOut),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: palette.dangerBtnBg,
            foregroundColor: palette.dangerBtnText,
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authProvider.notifier).signOut();
  }
}
