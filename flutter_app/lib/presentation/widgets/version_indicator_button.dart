import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/release_check_provider.dart';
import '../../core/constants.dart';
import '../../data/network/release_check_service.dart';
import '../theme/dm_tool_colors.dart';

/// Compact AppBar action showing the current app version and, when a
/// newer GitHub release is available, an update badge that opens a
/// dialog with release notes + a Download button.
class VersionIndicatorButton extends ConsumerWidget {
  const VersionIndicatorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final asyncRelease = ref.watch(latestReleaseProvider);

    final isUpdate = asyncRelease.maybeWhen(
      data: (info) => info != null && info.isNewerThan(appReleaseTag),
      orElse: () => false,
    );

    final label = Text(
      appReleaseTag,
      style: TextStyle(
        fontSize: 12,
        fontWeight: isUpdate ? FontWeight.w600 : FontWeight.w500,
        color: isUpdate
            ? palette.featureCardAccent
            : palette.sidebarLabelSecondary,
      ),
    );

    final tooltip = asyncRelease.when(
      data: (info) {
        if (info == null) return 'Version $appReleaseTag';
        if (info.isNewerThan(appReleaseTag)) {
          return 'Update available: ${info.tag}';
        }
        return "You're up to date ($appReleaseTag)";
      },
      loading: () => 'Checking for updates...',
      error: (_, _) => 'Version $appReleaseTag',
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUpdate) ...[
            Icon(
              Icons.arrow_circle_up,
              size: 16,
              color: palette.featureCardAccent,
            ),
            const SizedBox(width: 4),
          ],
          label,
        ],
      ),
    );

    return Tooltip(
      message: tooltip,
      child: isUpdate
          ? InkWell(
              borderRadius: palette.br,
              onTap: () => _showUpdateDialog(
                context,
                asyncRelease.value!,
                palette,
              ),
              child: content,
            )
          : content,
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    ReleaseInfo info,
    DmToolColors palette,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.arrow_circle_up, color: palette.featureCardAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text('Update available')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current: $appReleaseTag',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Latest: ${info.tag}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.featureCardAccent,
                  ),
                ),
                const SizedBox(height: 12),
                if (info.body.isNotEmpty)
                  Text(
                    info.body,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  )
                else
                  Text(
                    info.name,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Download'),
            onPressed: () async {
              final uri = Uri.parse(info.htmlUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
