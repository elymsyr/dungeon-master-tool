import 'package:flutter/material.dart';

/// One-time notice shown after a v4→v5 upgrade has purged legacy data.
///
/// See [docs/engineering/42-fresh-start-db-reset.md](../../../../docs/engineering/42-fresh-start-db-reset.md).
class V5UpgradeNoticeDialog extends StatelessWidget {
  const V5UpgradeNoticeDialog({super.key, this.backupPath});

  /// Optional path to the v4 DB backup, if one was preserved before the purge.
  final String? backupPath;

  static Future<void> show(BuildContext context, {String? backupPath}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => V5UpgradeNoticeDialog(backupPath: backupPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.info_outline, size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('Big update')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This version replaces the previous flexible Template system '
                'with native D&D 5e support.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your previous campaigns, characters, and templates have been '
                'removed because they cannot be automatically converted to the '
                'new format.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Going forward, all D&D 5e content is built-in and you can '
                'install community packages from the Marketplace.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              if (backupPath != null) ...[
                const SizedBox(height: 14),
                Text(
                  'A backup of your v4 database was saved at:\n$backupPath',
                  style: const TextStyle(height: 1.4, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    );
  }
}
