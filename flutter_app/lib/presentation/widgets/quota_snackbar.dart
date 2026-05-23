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

/// Shows a brief snackbar telling the user the per-entity image cap
/// ([kMaxEntityImages]) was hit and extra picked files were dropped.
void showImageLimitSnackbar(BuildContext context, int limit) {
  final l10n = L10n.of(context);
  if (l10n == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(l10n.mediaImageLimitReached(limit))),
  );
}

/// Shows a brief snackbar telling the user a freshly picked image exceeded the
/// per-kind upload size limit ([maxBytes]) so it was kept on the device only
/// and NOT backed up to the cloud. [actualBytes] is the rejected file's size
/// so the user sees both numbers (e.g. "5.2 MB, limit 4 MB"). When unknown,
/// pass `null` and the message degrades to the limit alone.
/// Called from every image-pick site after an upload helper reports `tooLarge`.
void showImageTooLargeSnackbar(
  BuildContext context, {
  required int maxBytes,
  int? actualBytes,
}) {
  final l10n = L10n.of(context);
  if (l10n == null) return;
  final maxMb = (maxBytes / (1024 * 1024)).round();
  final actualMb = actualBytes == null
      ? '?'
      : (actualBytes / (1024 * 1024)).toStringAsFixed(1);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(l10n.mediaImageTooLarge(actualMb, maxMb))),
  );
}
