import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// A small "?" icon in an AppBar action area that opens a localized
/// explanation dialog. Used per-tab in the Hub to give the user a quick
/// orientation for the section they're currently looking at.
class HelpIconButton extends StatelessWidget {
  final String title;
  final String body;

  const HelpIconButton({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return IconButton(
      tooltip: l10n.helpButtonTooltip,
      icon: const Icon(Icons.help_outline),
      onPressed: () => _show(context),
    );
  }

  void _show(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: palette.featureCardAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: palette.tabActiveText,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.btnClose),
          ),
        ],
      ),
    );
  }
}
