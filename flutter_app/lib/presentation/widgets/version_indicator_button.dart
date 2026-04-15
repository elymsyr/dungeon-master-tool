import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/release_check_provider.dart';
import '../../core/constants.dart';
import '../../data/network/release_check_service.dart';
import '../theme/dm_tool_colors.dart';

/// Compact AppBar action showing the current app version. Always clickable:
/// opens the latest GitHub release notes dialog (markdown-rendered). When an
/// update is available, shows an "Update available" header with a Download
/// action that opens the release page.
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
      child: InkWell(
        borderRadius: palette.br,
        onTap: () => _onTap(context, asyncRelease, palette, isUpdate),
        child: content,
      ),
    );
  }

  void _onTap(
    BuildContext context,
    AsyncValue<ReleaseInfo?> asyncRelease,
    DmToolColors palette,
    bool isUpdate,
  ) {
    final info = asyncRelease.valueOrNull;
    if (info == null) {
      final msg = asyncRelease.isLoading
          ? 'Checking for updates…'
          : 'Release info unavailable.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    _showReleaseDialog(context, info, palette, isUpdate: isUpdate);
  }

  Future<void> _showReleaseDialog(
    BuildContext context,
    ReleaseInfo info,
    DmToolColors palette, {
    required bool isUpdate,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isUpdate ? Icons.arrow_circle_up : Icons.info_outline,
              color: palette.featureCardAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isUpdate ? 'Update available' : 'Release notes'),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
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
                  MarkdownBody(
                    data: info.body,
                    selectable: true,
                    onTapLink: (text, href, title) async {
                      if (href == null) return;
                      final uri = Uri.tryParse(href);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: const TextStyle(fontSize: 13, height: 1.4),
                    ),
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
        actions: isUpdate
            ? [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Later'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Download'),
                  onPressed: () async {
                    final uri = Uri.parse(info.htmlUrl);
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View on GitHub'),
                  onPressed: () async {
                    final uri = Uri.parse(info.htmlUrl);
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  },
                ),
              ],
      ),
    );
  }
}
