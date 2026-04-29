import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/cloud_remote_check_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/user_session_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/profile_edit_dialog.dart';
import '../../dialogs/welcome_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/help_icon_button.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/profile_menu_button.dart';
import '../../widgets/save_sync_indicator.dart';
import '../../widgets/version_indicator_button.dart';
import 'characters_tab.dart';
import 'packages_tab.dart';
import 'settings_tab.dart';
import 'social_tab.dart';
import 'templates_tab.dart';
import 'worlds_tab.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  bool _profileDialogOpen = false;

  static const _settingsTabIndex = settingsTabIndex;

  @override
  void initState() {
    super.initState();
    // Uygulama ilk kez açıldığında karşılama + beta bildirim dialog'u.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ui = ref.read(uiStateProvider);
      if (ui.welcomeSeen) return;
      await WelcomeDialog.show(context);
      if (!mounted) return;
      ref.read(uiStateProvider.notifier).update((s) => s.copyWith(welcomeSeen: true));
    });
  }

  static const _tabs = [
    (icon: Icons.people, label: 'Social'),
    (icon: Icons.settings, label: 'Settings'),
    (icon: Icons.public, label: 'Worlds'),
    (icon: Icons.person, label: 'Characters'),
    (icon: Icons.description, label: 'Templates'),
    (icon: Icons.inventory_2, label: 'Packages'),
  ];

  /// Renders [icon], optionally layered with a small accent dot in the top-
  /// right when [showBadge] is true. Shared by every navigation surface
  /// (side rail, bottom nav, landscape sheet) so the multi-device hint is
  /// consistent wherever the Settings icon appears.
  Widget _tabIcon({
    required IconData icon,
    required Color color,
    required bool showBadge,
    required Color badgeColor,
    double size = 22,
  }) {
    final iconWidget = Icon(icon, size: size, color: color);
    if (!showBadge) return iconWidget;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 3,
            child: iconWidget,
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // IndexedStack ile state korunur — tab değişince widget'lar yeniden oluşturulmaz
  final _tabContent = const [
    SocialTab(),
    SettingsTab(),
    WorldsTab(),
    CharactersTab(),
    TemplatesTab(),
    PackagesTab(),
  ];

  void _showLandscapeNavSheet(
    DmToolColors palette,
    bool cloudBadge, {
    bool hasUnread = false,
    required int currentTabIndex,
    required List<int> visibleTabs,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final i in visibleTabs)
                _buildLandscapeSheetTile(
                  ctx: ctx,
                  index: i,
                  palette: palette,
                  cloudBadge: cloudBadge,
                  hasUnread: hasUnread,
                  currentTabIndex: currentTabIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeSheetTile({
    required BuildContext ctx,
    required int index,
    required DmToolColors palette,
    required bool cloudBadge,
    required bool hasUnread,
    required int currentTabIndex,
  }) {
    final t = _tabs[index];
    final isActive = index == currentTabIndex;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        ref.read(hubTabIndexProvider.notifier).state = index;
      },
      child: SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabIcon(
                icon: t.icon,
                size: 24,
                color: isActive ? palette.tabIndicator : palette.tabText,
                showBadge:
                    (index == _settingsTabIndex && cloudBadge) ||
                    (index == 0 && hasUnread),
                badgeColor: palette.featureCardAccent,
              ),
              const SizedBox(height: 4),
              Text(t.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? palette.tabIndicator : palette.tabText,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String title, String body}) _helpForTab(
    L10n l10n,
    int index,
    String socialSubTab,
  ) {
    switch (index) {
      case 0:
        if (socialSubTab == 'marketplace') {
          return (
            title: l10n.helpMarketplaceTitle,
            body: l10n.helpMarketplaceBody,
          );
        }
        return (title: l10n.helpSocialTitle, body: l10n.helpSocialBody);
      case 1:
        return (title: l10n.helpSettingsTitle, body: l10n.helpSettingsBody);
      case 2:
        return (title: l10n.helpWorldsTitle, body: l10n.helpWorldsBody);
      case 3:
        return (
          title: 'Characters',
          body:
              'View, edit, and delete every character across your worlds. Create new characters from inside a world via the Characters sidebar.',
        );
      case 4:
        return (title: l10n.helpTemplatesTitle, body: l10n.helpTemplatesBody);
      case 5:
      default:
        return (title: l10n.helpPackagesTitle, body: l10n.helpPackagesBody);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final socialSubTab = ref.watch(socialSubTabProvider);
    final tabIndex = ref.watch(hubTabIndexProvider);
    final help = _helpForTab(l10n, tabIndex, socialSubTab);
    final screen = getScreenType(context);
    final isLandscapePhone = screen == ScreenType.phone &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // Settings is accessible only via the profile menu — hidden on desktop
    // side rail, mobile bottom nav, and landscape sheet.
    final visibleTabs = <int>[
      for (var i = 0; i < _tabs.length; i++)
        if (i != _settingsTabIndex) i,
    ];
    // Multi-device hint — another device uploaded changes we haven't pulled.
    final cloudBadge = ref.watch(cloudRemoteHasNewerProvider);
    // Unread messages — badge on Social tab.
    final hasUnread = (ref.watch(totalNotificationCountProvider).value ?? 0) > 0;

    // Redirect to landing on sign-out when Supabase is configured.
    ref.listen(authProvider, (prev, next) async {
      if (prev != null && next == null && SupabaseConfig.isConfigured) {
        await ref.read(userSessionProvider.notifier).deactivate();
        if (context.mounted) context.go('/');
      }
    });

    // Yeni sign-in olan kullanıcı profile yoksa username seçim dialog'u zorla aç.
    // Flag yalnızca sign-out'ta resetlenir; dialog kapanınca resetlenmez —
    // aksi halde invalidate sonrası yarış (refetch null döner) dialog'u
    // ikinci kez açabiliyor.
    ref.listen(currentProfileProvider, (prev, next) {
      next.whenData((profile) {
        if (profile != null) return;
        if (!SupabaseConfig.isConfigured) return;
        if (ref.read(authProvider) == null) return;
        if (_profileDialogOpen) return;
        _profileDialogOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ProfileEditDialog.show(context);
        });
      });
    });
    // Sign-out sonrası flag'i temizle (yeni kullanıcı için tekrar açılabilsin).
    ref.listen(authProvider, (prev, next) {
      if (next == null) _profileDialogOpen = false;
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
      appBar: AppBar(
        leading: isLandscapePhone
            ? IconButton(
                icon: const Icon(Icons.menu, size: 22),
                onPressed: () => _showLandscapeNavSheet(
                  palette,
                  cloudBadge,
                  hasUnread: hasUnread,
                  currentTabIndex: tabIndex,
                  visibleTabs: visibleTabs,
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const AppIconImage(size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Dungeon Master Tool',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          const VersionIndicatorButton(),
          const SaveSyncIndicator(compact: true),
          HelpIconButton(title: help.title, body: help.body),
          IconButton(
            tooltip: 'Report a Bug',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => BugReportDialog.show(context),
          ),
          // Profile menu — avatar + username with popup actions
          const ProfileMenuButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: RepaintBoundary(
        child: switch (screen) {
          // Desktop/Tablet: sol rail + sağ content
          ScreenType.desktop || ScreenType.tablet => Row(
              children: [
                _HubSideRail(
                  tabs: _tabs,
                  visibleTabs: visibleTabs,
                  selectedIndex: tabIndex,
                  onSelected: (i) =>
                      ref.read(hubTabIndexProvider.notifier).state = i,
                  palette: palette,
                  settingsBadge: cloudBadge,
                  settingsTabIndex: _settingsTabIndex,
                  socialBadge: hasUnread,
                ),
                VerticalDivider(width: 1, color: palette.sidebarDivider),
                Expanded(
                  child: LazyIndexedStack(
                    index: tabIndex,
                    children: _tabContent,
                  ),
                ),
              ],
            ),
          // Mobile: portrait=BottomNav, landscape=leading burger menu
          ScreenType.phone => LazyIndexedStack(
            index: tabIndex,
            children: _tabContent,
          ),
        },
      ),
      bottomNavigationBar: (screen == ScreenType.phone && !isLandscapePhone)
          ? _MobileHubNavBar(
              tabs: _tabs,
              visibleTabs: visibleTabs,
              selectedTabIndex: tabIndex,
              onSelected: (i) =>
                  ref.read(hubTabIndexProvider.notifier).state = i,
              palette: palette,
              settingsTabIndex: _settingsTabIndex,
              cloudBadge: cloudBadge,
              socialBadge: hasUnread,
            )
          : null,
    ),
    );
  }
}

class _HubSideRail extends StatelessWidget {
  final List<({IconData icon, String label})> tabs;
  final List<int> visibleTabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final DmToolColors palette;
  final bool settingsBadge;
  final int settingsTabIndex;
  final bool socialBadge;

  const _HubSideRail({
    required this.tabs,
    required this.visibleTabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.palette,
    required this.settingsBadge,
    required this.settingsTabIndex,
    this.socialBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (final i in visibleTabs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _SideRailButton(
                icon: tabs[i].icon,
                tooltip: tabs[i].label,
                selected: i == selectedIndex,
                palette: palette,
                showBadge: (i == settingsTabIndex && settingsBadge) || (i == 0 && socialBadge),
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideRailButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final DmToolColors palette;
  final bool showBadge;
  final VoidCallback onTap;

  const _SideRailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.palette,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: palette.br,
    );
    final size = selected ? 24.0 : 22.0;
    final iconColor = selected
        ? palette.featureCardAccent
        : palette.sidebarLabelSecondary;
    return Material(
      color: selected
          ? palette.featureCardAccent.withValues(alpha: 0.18)
          : Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: palette.br,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: size, color: iconColor),
                if (showBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Themed mobile bottom navigation. Replaces Material's default NavigationBar
/// so hover/active states respect DmToolColors (accent fill, themed radius,
/// tab text colors).
class _MobileHubNavBar extends StatelessWidget {
  final List<({IconData icon, String label})> tabs;
  final List<int> visibleTabs;
  final int selectedTabIndex;
  final ValueChanged<int> onSelected;
  final DmToolColors palette;
  final int settingsTabIndex;
  final bool cloudBadge;
  final bool socialBadge;

  const _MobileHubNavBar({
    required this.tabs,
    required this.visibleTabs,
    required this.selectedTabIndex,
    required this.onSelected,
    required this.palette,
    required this.settingsTabIndex,
    required this.cloudBadge,
    required this.socialBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.tabBg,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: palette.sidebarDivider, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (final i in visibleTabs)
                Expanded(
                  child: _MobileNavTile(
                    icon: tabs[i].icon,
                    label: tabs[i].label,
                    selected: i == selectedTabIndex,
                    palette: palette,
                    showBadge: (i == settingsTabIndex && cloudBadge) ||
                        (i == 0 && socialBadge),
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final DmToolColors palette;
  final bool showBadge;
  final VoidCallback onTap;

  const _MobileNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = palette.featureCardAccent;
    final bg = selected ? activeColor.withValues(alpha: 0.18) : Colors.transparent;
    final fg = selected ? activeColor : palette.tabText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: bg,
        borderRadius: palette.br,
        child: InkWell(
          onTap: onTap,
          borderRadius: palette.br,
          hoverColor: activeColor.withValues(alpha: 0.10),
          splashColor: activeColor.withValues(alpha: 0.22),
          highlightColor: activeColor.withValues(alpha: 0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: selected ? 24 : 22, color: fg),
                    if (showBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.tabBg,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
