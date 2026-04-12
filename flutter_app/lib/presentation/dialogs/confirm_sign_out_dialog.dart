import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Shows a confirmation dialog before signing out. If confirmed, calls
/// [authProvider]'s signOut. Navigation to the landing screen is handled
/// by the hub_screen auth listener.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.signOutConfirmTitle),
      content: Text(l10n.signOutConfirmBody),
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
