import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Single tab spec for [PillTabBar].
class PillTab<T> {
  const PillTab({required this.id, required this.icon, required this.label, this.badgeCount});
  final T id;
  final IconData icon;
  final String label;
  final int? badgeCount;
}

/// Compact pill-shaped segmented control used across Social, Profile and
/// other places that need an unobtrusive top/bottom selector. Visual
/// parity with the original `_PillBar` from social_shell.dart — just
/// promoted so multiple screens can share it.
class PillTabBar<T> extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.tabs,
    required this.currentTab,
    required this.onTabChanged,
    required this.phone,
    this.trailing,
    this.showBorderTop = false,
    this.showBorderBottom = true,
    this.showLabels,
  });

  final List<PillTab<T>> tabs;
  final T currentTab;
  final ValueChanged<T> onTabChanged;
  final Widget? trailing;
  final bool phone;
  final bool showBorderTop;
  final bool showBorderBottom;

  /// Overrides the default label visibility. When `null`, labels are
  /// hidden on phone and shown on desktop (matches Social's behavior).
  final bool? showLabels;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final withLabels = showLabels ?? !phone;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 8 : 24,
        vertical: phone ? 8 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: showBorderTop
              ? BorderSide(color: palette.featureCardBorder)
              : BorderSide.none,
          bottom: showBorderBottom
              ? BorderSide(color: palette.featureCardBorder)
              : BorderSide.none,
        ),
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
                    final isActive = t.id == currentTab;
                    return InkWell(
                      borderRadius: palette.br,
                      onTap: () => onTabChanged(t.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 12 : 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? palette.featureCardAccent
                              : Colors.transparent,
                          borderRadius: palette.br,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BadgedIcon(
                              icon: t.icon,
                              size: 16,
                              color: isActive
                                  ? Colors.white
                                  : palette.sidebarLabelSecondary,
                              showBadge: t.badgeCount != null && t.badgeCount! > 0,
                              badgeColor: isActive
                                  ? Colors.white
                                  : palette.dangerBtnBg,
                            ),
                            if (withLabels) ...[
                              const SizedBox(width: 6),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : palette.tabText,
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

class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final bool showBadge;
  final Color badgeColor;

  const _BadgedIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.showBadge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: size, color: color);
    if (!showBadge) return iconWidget;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 3, child: iconWidget),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
