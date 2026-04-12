import 'package:flutter/material.dart';

import '../../../core/utils/screen_type.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// Social alt sekmeleri için ortak shell — max-width constrained, üstte pill
/// segmented control, altta scroll'lanabilir içerik. Desktop'ta Material
/// TabBar yerine daha rafine bir pill bar kullanılır.
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
    final tabs = <(String, IconData, String)>[
      ('feed', Icons.dynamic_feed_outlined, l10n.socialTabFeed),
      ('players', Icons.groups_outlined, l10n.socialTabGameListings),
      ('messages', Icons.chat_bubble_outline, l10n.socialTabMessages),
      ('marketplace', Icons.storefront_outlined, l10n.socialTabMarketplace),
    ];
    return Column(
      children: [
        _PillBar(
          tabs: tabs,
          currentTab: currentTab,
          onTabChanged: onTabChanged,
          trailing: trailing,
          phone: phone,
        ),
        Expanded(
          child: phone
              ? child
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: child,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PillBar extends StatelessWidget {
  final List<(String, IconData, String)> tabs;
  final String currentTab;
  final ValueChanged<String> onTabChanged;
  final Widget? trailing;
  final bool phone;

  const _PillBar({
    required this.tabs,
    required this.currentTab,
    required this.onTabChanged,
    required this.phone,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 8 : 24,
        vertical: phone ? 8 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.featureCardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: palette.cbr,
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: tabs.map((t) {
                    final isActive = t.$1 == currentTab;
                    return InkWell(
                      borderRadius: palette.br,
                      onTap: () => onTabChanged(t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 12 : 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? palette.featureCardAccent : Colors.transparent,
                          borderRadius: palette.br,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.$2,
                              size: 16,
                              color: isActive ? Colors.white : palette.sidebarLabelSecondary,
                            ),
                            if (!phone) ...[
                              const SizedBox(width: 6),
                              Text(
                                t.$3,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                  color: isActive ? Colors.white : palette.tabText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
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
