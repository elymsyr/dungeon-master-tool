import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

class _SupportLink {
  const _SupportLink({
    required this.label,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color color;
}

class SupportDialog extends StatelessWidget {
  const SupportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SupportDialog(),
    );
  }

  static const _links = <_SupportLink>[
    _SupportLink(
      label: 'Patreon',
      subtitle: 'patreon.com/elymsyr',
      url: 'https://www.patreon.com/elymsyr',
      icon: Icons.favorite,
      color: Color(0xFFF96854),
    ),
    _SupportLink(
      label: 'thanks.dev',
      subtitle: 'thanks.dev/u/gh/elymsyr',
      url: 'https://thanks.dev/u/gh/elymsyr',
      icon: Icons.volunteer_activism,
      color: Color(0xFF2EBC4F),
    ),
    _SupportLink(
      label: 'GroupFinder',
      subtitle: 'groupfinder.eu/library/dungeon-master-tool',
      url: 'https://groupfinder.eu/library/dungeon-master-tool',
      icon: Icons.groups_outlined,
      color: Color(0xFF7B61FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      title: Text(l10n.profileMenuSupport),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileMenuSupportBody,
              style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final link in _links) ...[
              _SupportLinkTile(link: link),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btnClose),
        ),
      ],
    );
  }
}

class _SupportLinkTile extends StatelessWidget {
  const _SupportLinkTile({required this.link});

  final _SupportLink link;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(link.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${link.url}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Material(
      color: palette.featureCardBg,
      borderRadius: palette.cbr,
      child: InkWell(
        borderRadius: palette.cbr,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: link.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(link.icon, color: link.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.label,
                      style: TextStyle(
                        color: palette.tabActiveText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      link.subtitle,
                      style: TextStyle(
                        color: palette.sidebarLabelSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: palette.sidebarLabelSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
