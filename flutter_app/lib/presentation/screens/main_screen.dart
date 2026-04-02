import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/locale_provider.dart';
import '../../application/providers/theme_provider.dart';
import '../../core/utils/screen_type.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../theme/palettes.dart';
import '../widgets/entity_sidebar.dart';
import 'database/database_screen.dart';
import 'hub/hub_screen.dart';

/// Ana ekran — Python ui/main_root.py karşılığı.
/// 4 tab (Database, Session, Mind Map, Map) + sidebar + toolbar.
/// Responsive: Desktop=sidebar+tabs, Tablet=rail+tabs, Mobile=bottomNav.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _tabIndex = 0;
  bool _editMode = false;
  String? _selectedEntityId;

  static const _tabIcons = [
    Icons.storage,       // Database
    Icons.event_note,    // Session
    Icons.account_tree,  // Mind Map
    Icons.map,           // Map
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final campaignName = ref.watch(activeCampaignProvider) ?? '';
    final screen = getScreenType(context);

    final tabLabels = [
      l10n.tabDatabase,
      l10n.tabSession,
      l10n.tabMindMap,
      l10n.tabMap,
    ];

    final schema = ref.watch(worldSchemaProvider);

    final tabContent = [
      DatabaseScreen(
        editMode: _editMode,
        selectedEntityId: _selectedEntityId,
        onEntitySelected: (id) => setState(() => _selectedEntityId = id),
      ),
      _PlaceholderTab(title: l10n.tabSession, icon: _tabIcons[1]),
      _PlaceholderTab(title: l10n.tabMindMap, icon: _tabIcons[2]),
      _PlaceholderTab(title: l10n.tabMap, icon: _tabIcons[3]),
    ];

    return Scaffold(
      // --- Toolbar (AppBar) ---
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            Icon(Icons.castle, size: 20, color: palette.tabIndicator),
            const SizedBox(width: 8),
            Text(
              campaignName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        actions: [
          // Edit Mode toggle
          IconButton(
            icon: Icon(
              _editMode ? Icons.lock_open : Icons.lock,
              color: _editMode ? palette.tokenBorderActive : null,
            ),
            tooltip: 'Edit Mode',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          // Tema
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette, size: 20),
            tooltip: l10n.lblTheme,
            onSelected: (name) =>
                ref.read(themeProvider.notifier).setTheme(name),
            itemBuilder: (_) => themeNames
                .map((name) => PopupMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: themePalettes[name]?.canvasBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(name[0].toUpperCase() + name.substring(1)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          // Dil
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, size: 20),
            tooltip: l10n.lblLanguage,
            onSelected: (code) =>
                ref.read(localeProvider.notifier).setLocale(code),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'tr', child: Text('Türkçe')),
              PopupMenuItem(value: 'de', child: Text('Deutsch')),
              PopupMenuItem(value: 'fr', child: Text('Français')),
            ],
          ),
          // Switch World
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20),
            tooltip: 'Switch World',
            onPressed: () {
              ref.invalidate(campaignListProvider);
              ref.invalidate(campaignInfoListProvider);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const HubScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // --- Body: Responsive Layout ---
      body: switch (screen) {
        // Desktop: Sidebar (sol) + Tab bar + content (sağ)
        ScreenType.desktop => Row(
            children: [
              // Sol sidebar — tüm tab'larda ortak
              SizedBox(
                width: 280,
                child: EntitySidebar(
                  schema: schema,
                  onEntitySelected: (id) {
                    setState(() {
                      _selectedEntityId = id;
                      _tabIndex = 0; // Database tab'a geç
                    });
                  },
                ),
              ),
              VerticalDivider(width: 1, color: palette.sidebarDivider),
              // Sağ: tab bar + tab content
              Expanded(
                child: Column(
                  children: [
                    // Tab bar
                    Container(
                      color: palette.tabBg,
                      child: Row(
                        children: List.generate(4, (i) {
                          final isActive = i == _tabIndex;
                          return Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _tabIndex = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isActive ? palette.tabActiveBg : palette.tabBg,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isActive ? palette.tabIndicator : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_tabIcons[i], size: 18,
                                      color: isActive ? palette.tabActiveText : palette.tabText),
                                    const SizedBox(width: 6),
                                    Text(tabLabels[i],
                                      style: TextStyle(
                                        color: isActive ? palette.tabActiveText : palette.tabText,
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Tab content
                    Expanded(child: tabContent[_tabIndex]),
                  ],
                ),
              ),
            ],
          ),

        // Tablet: NavigationRail + content
        ScreenType.tablet => Row(
            children: [
              NavigationRail(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) =>
                    setState(() => _tabIndex = i),
                labelType: NavigationRailLabelType.all,
                destinations: List.generate(
                  4,
                  (i) => NavigationRailDestination(
                    icon: Icon(_tabIcons[i]),
                    label: Text(tabLabels[i]),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: tabContent[_tabIndex]),
            ],
          ),

        // Mobile: BottomNavigationBar
        ScreenType.phone => tabContent[_tabIndex],
      },

      // Mobile bottom nav
      bottomNavigationBar: screen == ScreenType.phone
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) =>
                  setState(() => _tabIndex = i),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(_tabIcons[i]),
                  label: tabLabels[i],
                ),
              ),
            )
          : null,
    );
  }
}

/// Placeholder tab content — Sprint 1'de gerçek widget'larla değişecek.
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coming in Sprint 1',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
          ),
        ],
      ),
    );
  }
}

