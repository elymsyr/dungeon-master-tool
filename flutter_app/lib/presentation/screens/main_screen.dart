import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/locale_provider.dart';
import '../../application/providers/theme_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../core/utils/screen_type.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../theme/palettes.dart';
import '../widgets/entity_sidebar.dart';
import 'database/database_screen.dart';
import 'session/session_screen.dart';

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

  // Sidebar state
  bool _sidebarOpen = true;
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 450;

  @override
  void initState() {
    super.initState();
    // UiState'den restore et
    final uiState = ref.read(uiStateProvider);
    _tabIndex = uiState.mainTabIndex;
    _sidebarOpen = uiState.sidebarOpen;
    _sidebarWidth = uiState.sidebarWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
  }

  void _persistUiState() {
    ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
      mainTabIndex: _tabIndex,
      sidebarOpen: _sidebarOpen,
      sidebarWidth: _sidebarWidth,
    ));
  }

  void _showMobileSidebar() {
    final schema = ref.read(worldSchemaProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => EntitySidebar(
          schema: schema,
          onEntitySelected: (id) {
            Navigator.pop(ctx);
            setState(() {
              _selectedEntityId = id;
              _tabIndex = 0;
            });
            _persistUiState();
          },
        ),
      ),
    );
  }

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
    final campaignName = ref.read(activeCampaignProvider) ?? '';
    final screen = getScreenType(context);

    final tabLabels = [
      l10n.tabDatabase,
      l10n.tabSession,
      l10n.tabMindMap,
      l10n.tabMap,
    ];

    final schema = ref.read(worldSchemaProvider);

    final tabStack = IndexedStack(
      index: _tabIndex,
      children: [
        DatabaseScreen(
          editMode: _editMode,
          selectedEntityId: _selectedEntityId,
          onEntitySelected: (id) => setState(() => _selectedEntityId = id),
        ),
        const SessionScreen(),
        _PlaceholderTab(title: l10n.tabMindMap, icon: _tabIcons[2]),
        _PlaceholderTab(title: l10n.tabMap, icon: _tabIcons[3]),
      ],
    );

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
              context.go('/hub');
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
              // Sol sidebar — collapsible + resizable
              if (_sidebarOpen)
                SizedBox(
                  width: _sidebarWidth,
                  child: EntitySidebar(
                    schema: schema,
                    onEntitySelected: (id) {
                      setState(() {
                        _selectedEntityId = id;
                        _tabIndex = 0;
                      });
                      _persistUiState();
                    },
                  ),
                ),
              // Sidebar divider with toggle + drag resize
              _SidebarDivider(
                isOpen: _sidebarOpen,
                palette: palette,
                onToggle: () { setState(() => _sidebarOpen = !_sidebarOpen); _persistUiState(); },
                onDragUpdate: _sidebarOpen
                    ? (dx) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + dx).clamp(_minSidebarWidth, _maxSidebarWidth);
                        });
                      }
                    : null,
                onDragEnd: _sidebarOpen ? () => _persistUiState() : null,
              ),
              // Sağ: tab bar + tab content
              Expanded(
                child: Column(
                  children: [
                    // Tab bar
                    Container(
                      color: palette.tabBg,
                      child: Row(
                        children: [
                          ...List.generate(4, (i) {
                            final isActive = i == _tabIndex;
                            return InkWell(
                              onTap: () { setState(() => _tabIndex = i); _persistUiState(); },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isActive ? palette.tabActiveBg : palette.tabBg,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_tabIcons[i], size: 18,
                                      color: isActive ? palette.tabActiveText : palette.tabText),
                                    const SizedBox(width: 6),
                                    Text(tabLabels[i],
                                      style: TextStyle(
                                        color: isActive ? palette.tabActiveText : palette.tabText,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const Spacer(),
                        ],
                      ),
                    ),
                    // Tab content
                    Expanded(child: tabStack),
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
                onDestinationSelected: (i) { setState(() => _tabIndex = i); _persistUiState(); },
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
              Expanded(child: tabStack),
            ],
          ),

        // Mobile: BottomNavigationBar
        ScreenType.phone => tabStack,
      },

      // FAB for mobile/tablet entity sidebar
      floatingActionButton: (screen != ScreenType.desktop && _tabIndex == 0)
          ? FloatingActionButton.small(
              onPressed: _showMobileSidebar,
              child: const Icon(Icons.list),
            )
          : null,

      // Mobile bottom nav
      bottomNavigationBar: screen == ScreenType.phone
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) { setState(() => _tabIndex = i); _persistUiState(); },
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

/// Sidebar divider — toggle butonu + sürükleyerek genişletme.
class _SidebarDivider extends StatefulWidget {
  final bool isOpen;
  final DmToolColors palette;
  final VoidCallback onToggle;
  final void Function(double dx)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const _SidebarDivider({
    required this.isOpen,
    required this.palette,
    required this.onToggle,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<_SidebarDivider> createState() => _SidebarDividerState();
}

class _SidebarDividerState extends State<_SidebarDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.onDragUpdate != null
          ? (details) => widget.onDragUpdate!(details.delta.dx)
          : null,
      onHorizontalDragEnd: widget.onDragEnd != null
          ? (_) => widget.onDragEnd!()
          : null,
      child: MouseRegion(
        cursor: widget.isOpen ? SystemMouseCursors.resizeColumn : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onToggle,
          child: Container(
            width: 10,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 1,
                height: double.infinity,
                color: _hovered
                    ? widget.palette.tabIndicator.withValues(alpha: 0.6)
                    : widget.palette.sidebarDivider,
              ),
            ),
          ),
        ),
      ),
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

