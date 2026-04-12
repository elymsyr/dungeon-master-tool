import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/user_session_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/profile_edit_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/help_icon_button.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/profile_menu_button.dart';
import '../../widgets/save_sync_indicator.dart';
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
  int _tabIndex = 2; // Worlds tab default
  final GlobalKey _screenshotKey = GlobalKey();
  bool _profileDialogOpen = false;

  static const _tabs = [
    (icon: Icons.people, label: 'Social'),
    (icon: Icons.settings, label: 'Settings'),
    (icon: Icons.public, label: 'Worlds'),
    (icon: Icons.description, label: 'Templates'),
    (icon: Icons.inventory_2, label: 'Packages'),
  ];

  // IndexedStack ile state korunur — tab değişince widget'lar yeniden oluşturulmaz
  final _tabContent = const [
    SocialTab(),
    SettingsTab(),
    WorldsTab(),
    TemplatesTab(),
    PackagesTab(),
  ];

  void _showLandscapeNavSheet(DmToolColors palette) {
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
            children: List.generate(_tabs.length, (i) {
              final t = _tabs[i];
              final isActive = i == _tabIndex;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _tabIndex = i);
                },
                child: SizedBox(
                  width: 80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 24,
                            color: isActive ? palette.tabIndicator : palette.tabText),
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
            }),
          ),
        ),
      ),
    );
  }

  ({String title, String body}) _helpForTab(L10n l10n, int index) {
    switch (index) {
      case 0:
        return (title: l10n.helpSocialTitle, body: l10n.helpSocialBody);
      case 1:
        return (title: l10n.helpSettingsTitle, body: l10n.helpSettingsBody);
      case 2:
        return (title: l10n.helpWorldsTitle, body: l10n.helpWorldsBody);
      case 3:
        return (title: l10n.helpTemplatesTitle, body: l10n.helpTemplatesBody);
      case 4:
      default:
        return (title: l10n.helpPackagesTitle, body: l10n.helpPackagesBody);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final help = _helpForTab(l10n, _tabIndex);
    final screen = getScreenType(context);
    final isLandscapePhone = screen == ScreenType.phone &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

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
                onPressed: () => _showLandscapeNavSheet(palette),
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
          const SaveSyncIndicator(compact: true),
          HelpIconButton(title: help.title, body: help.body),
          IconButton(
            tooltip: 'Report a Bug',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => BugReportDialog.show(
              context,
              screenshotKey: _screenshotKey,
            ),
          ),
          // Profile menu — avatar + username with popup actions
          const ProfileMenuButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: RepaintBoundary(
        key: _screenshotKey,
        child: switch (screen) {
          // Desktop/Tablet: sol rail + sağ content
          ScreenType.desktop || ScreenType.tablet => Row(
              children: [
                _HubSideRail(
                  tabs: _tabs,
                  selectedIndex: _tabIndex,
                  onSelected: (i) => setState(() => _tabIndex = i),
                  palette: palette,
                ),
                VerticalDivider(width: 1, color: palette.sidebarDivider),
                Expanded(
                  child: LazyIndexedStack(
                    index: _tabIndex,
                    children: _tabContent,
                  ),
                ),
              ],
            ),
          // Mobile: portrait=BottomNav, landscape=leading burger menu
          ScreenType.phone => LazyIndexedStack(
            index: _tabIndex,
            children: _tabContent,
          ),
        },
      ),
      bottomNavigationBar: (screen == ScreenType.phone && !isLandscapePhone)
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: _tabs.map((t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              )).toList(),
            )
          : null,
    ),
    );
  }
}

class _HubSideRail extends StatelessWidget {
  final List<({IconData icon, String label})> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final DmToolColors palette;

  const _HubSideRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _SideRailButton(
                icon: tabs[i].icon,
                tooltip: tabs[i].label,
                selected: i == selectedIndex,
                palette: palette,
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
  final VoidCallback onTap;

  const _SideRailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: palette.br,
    );
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
            child: Icon(
              icon,
              size: selected ? 24 : 22,
              color: selected
                  ? palette.featureCardAccent
                  : palette.sidebarLabelSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
