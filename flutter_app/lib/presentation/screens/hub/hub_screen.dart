import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/screen_type.dart';
import '../../theme/dm_tool_colors.dart';
import '../landing/landing_screen.dart';
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

  static const _tabs = [
    (icon: Icons.people, label: 'Social'),
    (icon: Icons.settings, label: 'Settings'),
    (icon: Icons.public, label: 'Worlds'),
    (icon: Icons.description, label: 'Templates'),
  ];

  // IndexedStack ile state korunur — tab değişince widget'lar yeniden oluşturulmaz
  final _tabContent = const [
    SocialTab(),
    SettingsTab(),
    WorldsTab(),
    TemplatesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = getScreenType(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LandingScreen()),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.castle, size: 20, color: palette.featureCardAccent),
            const SizedBox(width: 8),
            const Text('Dungeon Master Tool', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: switch (screen) {
        // Desktop: sol rail + sağ content
        ScreenType.desktop || ScreenType.tablet => Row(
            children: [
              NavigationRail(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
                labelType: NavigationRailLabelType.all,
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
        // Mobile: bottom nav — IndexedStack ile state korunur
        ScreenType.phone => IndexedStack(
          index: _tabIndex,
          children: _tabContent,
        ),
      },
      bottomNavigationBar: screen == ScreenType.phone
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: _tabs.map((t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              )).toList(),
            )
          : null,
    );
  }
}
