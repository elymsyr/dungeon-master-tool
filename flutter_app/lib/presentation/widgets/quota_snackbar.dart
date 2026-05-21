import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a brief snackbar telling the user their cloud storage quota is full
/// and the freshly picked image was kept on the device instead. Called from
/// every image-pick site after `uploadEntityImageRef` reports `quotaExceeded`.
void showQuotaFullSnackbar(BuildContext context) {
  final l10n = L10n.of(context);
  if (l10n == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(l10n.mediaQuotaFull)),
  );
}
