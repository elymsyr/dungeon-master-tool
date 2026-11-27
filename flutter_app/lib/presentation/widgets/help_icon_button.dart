import 'package:flutter/material.dart';

import '../dialogs/help_wiki_dialog.dart';
import '../l10n/app_localizations.dart';

/// A small "?" icon in an AppBar action area that opens the help wiki at
/// [page] — the topic id of the section the user is looking at.
class HelpIconButton extends StatelessWidget {
  final String page;

  const HelpIconButton({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return IconButton(
      tooltip: l10n.helpButtonTooltip,
      icon: const Icon(Icons.help_outline),
      onPressed: () => HelpWikiDialog.show(context, page),
    );
  }
}
