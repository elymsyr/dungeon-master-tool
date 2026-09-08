import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a brief snackbar telling the user the per-entity image cap
/// ([kMaxEntityImages]) was hit and extra picked files were dropped.
void showImageLimitSnackbar(BuildContext context, int limit) {
  final l10n = L10n.of(context);
  if (l10n == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(l10n.mediaImageLimitReached(limit))),
  );
}
