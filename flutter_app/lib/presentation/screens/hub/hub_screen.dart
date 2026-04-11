import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../theme/dm_tool_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);
    final isLandscapePhone = screen == ScreenType.phone &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final authState = ref.watch(authProvider);

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
            Icon(Icons.castle, size: 20, color: palette.featureCardAccent),
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
          IconButton(
            tooltip: 'Report a Bug',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => BugReportDialog.show(
              context,
              screenshotKey: _screenshotKey,
            ),
          ),
          // Auth button — sign in / sign out
          if (SupabaseConfig.isConfigured)
            authState != null
                ? IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    tooltip: 'Sign Out (${authState.email})',
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                  )
                : IconButton(
                    icon: const Icon(Icons.login, size: 20),
                    tooltip: 'Sign In',
                    onPressed: () => context.go('/'),
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: RepaintBoundary(
        key: _screenshotKey,
        child: switch (screen) {
          // Desktop/Tablet: sol rail + sağ content
          ScreenType.desktop || ScreenType.tablet => Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  labelType: NavigationRailLabelType.selected,
                  destinations: _tabs.map((t) => NavigationRailDestination(
                    icon: Icon(t.icon),
                    label: Text(t.label),
                  )).toList(),
                ),
                VerticalDivider(width: 1, color: palette.sidebarDivider),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: _tabContent,
                  ),
                ),
              ],
            ),
          // Mobile: portrait=BottomNav, landscape=leading burger menu
          ScreenType.phone => IndexedStack(
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
