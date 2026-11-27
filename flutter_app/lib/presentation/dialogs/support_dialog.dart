import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/promoted_links_provider.dart';
import '../../data/datasources/remote/promoted_links_remote_ds.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

class SupportLink {
  const SupportLink({
    required this.label,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.color,
    this.imageUrl,
  });

  /// Admin-managed promoted link; its image (if any) replaces [icon].
  factory SupportLink.promoted(PromotedLink p, Color color) => SupportLink(
        label: p.label,
        subtitle: p.url.replaceFirst(RegExp(r'^https?://', caseSensitive: false), ''),
        url: p.url,
        icon: Icons.link,
        color: color,
        imageUrl: p.imageUrl,
      );

  final String label;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color color;
  final String? imageUrl;
}

class SupportDialog extends ConsumerWidget {
  const SupportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SupportDialog(),
    );
  }

  static const _links = <SupportLink>[
    SupportLink(
      label: 'Patreon',
      subtitle: 'patreon.com/elymsyr',
      url: 'https://www.patreon.com/elymsyr',
      icon: Icons.favorite,
      color: Color(0xFFF96854),
    ),
    SupportLink(
      label: 'thanks.dev',
      subtitle: 'thanks.dev/u/gh/elymsyr',
      url: 'https://thanks.dev/u/gh/elymsyr',
      icon: Icons.volunteer_activism,
      color: Color(0xFF2EBC4F),
    ),
    SupportLink(
      label: 'GroupFinder',
      subtitle: 'groupfinder.eu/library/dungeon-master-tool',
      url: 'https://groupfinder.eu/library/dungeon-master-tool',
      icon: Icons.groups_outlined,
      color: Color(0xFF7B61FF),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Hidden while loading / offline / on error — the static links still work.
    final promoted = ref.watch(promotedLinksProvider).valueOrNull ?? const [];
    final accent = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      title: Text(l10n.profileMenuSupport),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileMenuSupportBody,
              style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final link in _links) ...[
              SupportLinkTile(link: link),
              const SizedBox(height: 8),
            ],
            if (promoted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.supportPromoted,
                style: TextStyle(
                  color: palette.tabActiveText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in promoted) ...[
                SupportLinkTile(link: SupportLink.promoted(p, accent)),
                const SizedBox(height: 8),
              ],
            ],
          ],
        )),
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

class SupportLinkTile extends StatelessWidget {
  const SupportLinkTile({super.key, required this.link});

  final SupportLink link;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(link.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.couldNotOpen(link.url))),
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
                clipBehavior: Clip.antiAlias,
                child: link.imageUrl == null
                    ? Icon(link.icon, color: link.color, size: 20)
                    : Image.network(
                        link.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(link.icon, color: link.color, size: 20),
                      ),
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
