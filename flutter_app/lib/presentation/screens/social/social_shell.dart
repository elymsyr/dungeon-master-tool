import 'package:flutter/material.dart';

import '../../../core/utils/screen_type.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/pill_tab_bar.dart';

/// Social alt sekmeleri için ortak shell — max-width constrained, pill
/// segmented control üstte (desktop) veya altta (mobile, ana bottom nav'ın
/// hemen üzerinde). Mobil'de bar bottom-center'da render edilir ki ana
/// NavigationBar ile alt hizada otursun.
class SocialShell extends StatelessWidget {
  final String currentTab;
  final ValueChanged<String> onTabChanged;
  final Widget child;
  /// Sağ üste opsiyonel action (örn. "New post", "New listing").
  final Widget? trailing;

  const SocialShell({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final phone = isPhone(context);
    final tabs = <PillTab<String>>[
      PillTab(id: 'feed', icon: Icons.dynamic_feed_outlined, label: l10n.socialTabFeed),
      PillTab(id: 'players', icon: Icons.groups_outlined, label: l10n.socialTabGameListings),
      PillTab(id: 'messages', icon: Icons.chat_bubble_outline, label: l10n.socialTabMessages),
      PillTab(id: 'marketplace', icon: Icons.storefront_outlined, label: l10n.socialTabMarketplace),
    ];
    final bar = PillTabBar<String>(
      tabs: tabs,
      currentTab: currentTab,
      onTabChanged: onTabChanged,
      trailing: trailing,
      phone: phone,
      showBorderTop: phone,
      showBorderBottom: !phone,
    );
    final content = phone
        ? child
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          );
    return Column(
      children: phone
          ? [Expanded(child: content), bar]
          : [bar, Expanded(child: content)],
    );
  }
}

/// Ortak card container — rounded, subtle border, consistent padding.
class SocialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const SocialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: palette.cbr,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Boş durum için ortak görsel.
class SocialEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const SocialEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.featureCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: palette.featureCardBorder),
              ),
              child: Icon(icon, size: 40, color: palette.sidebarLabelSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
