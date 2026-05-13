import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/edit_mode_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/world_mirror_provider.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/pdf_sidebar.dart';
import '../../widgets/soundmap_player_sidebar.dart';
import '../database/database_screen.dart';
import '../mind_map/mind_map_screen.dart';
import 'player_character_tab.dart';
import 'player_second_screen_tab.dart';

/// Player için MainScreen. Sade shell: 4 tab (Database, Mind Map, Character,
/// Second Screen) + PDF/Soundmap sağ sidebar'ları. DM-only butonlar yok.
class PlayerMainScreen extends ConsumerStatefulWidget {
  const PlayerMainScreen({super.key});

  @override
  ConsumerState<PlayerMainScreen> createState() => _PlayerMainScreenState();
}

class _PlayerMainScreenState extends ConsumerState<PlayerMainScreen> {
  int _tabIndex = 0;
  RightSidebar _rightSidebar = RightSidebar.none;
  List<String> _pdfOpenPaths = [];
  int _pdfActiveIndex = -1;
  static const int _maxPdfTabs = 10;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final campaignName = ref.read(activeCampaignProvider) ?? '';

    // Sync/mirror lifecycle — DM ile aynı, paylaşılmış provider.
    ref.watch(worldSyncAutoSubscribeProvider);

    const tabs = [
      _TabDef(icon: Icons.storage, label: 'Database'),
      _TabDef(icon: Icons.account_tree, label: 'Mind Map'),
      _TabDef(icon: Icons.person, label: 'Character'),
      _TabDef(icon: Icons.cast, label: 'Second Screen'),
    ];

    final stack = LazyIndexedStack(
      index: _tabIndex,
      children: [
        DatabaseScreen(
          editMode: ref.watch(editModeProvider),
          selectedEntityId: null,
          selectedEntityPanel: null,
          onEntitySelected: (_) {},
        ),
        MindMapScreen(
          editMode: ref.watch(editModeProvider),
          onOpenEntity: (_) {
            setState(() => _tabIndex = 0);
          },
        ),
        const PlayerCharacterTab(),
        const PlayerSecondScreenTab(),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/hub');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            tooltip: 'Back to hub',
            onPressed: () => context.go('/hub'),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  campaignName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.featureCardAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'PLAYER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: palette.tabIndicator,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'PDF',
              icon: Icon(Icons.picture_as_pdf,
                  color: _rightSidebar == RightSidebar.pdf
                      ? palette.tabIndicator
                      : null),
              onPressed: () => _toggleSidebar(RightSidebar.pdf),
            ),
            IconButton(
              tooltip: 'Soundmap',
              icon: Icon(Icons.music_note,
                  color: _rightSidebar == RightSidebar.soundmap
                      ? palette.tabIndicator
                      : null),
              onPressed: () => _toggleSidebar(RightSidebar.soundmap),
            ),
          ],
        ),
        body: Column(
          children: [
            _TabBar(
              palette: palette,
              tabs: tabs,
              selectedIndex: _tabIndex,
              onSelect: (i) => setState(() => _tabIndex = i),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: stack),
                  if (_rightSidebar != RightSidebar.none)
                    _buildRightSidebar(palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar(DmToolColors palette) {
    const width = 420.0;
    Widget child;
    switch (_rightSidebar) {
      case RightSidebar.pdf:
        child = PdfSidebar(
          openPaths: _pdfOpenPaths,
          activeIndex: _pdfActiveIndex,
          palette: palette,
          onTabSelect: (i) => setState(() => _pdfActiveIndex = i),
          onTabClose: _closePdfTab,
          onOpenFile: _openPdfTab,
        );
      case RightSidebar.soundmap:
        child = SoundmapPlayerSidebar(palette: palette);
      case RightSidebar.characters:
      case RightSidebar.none:
        return const SizedBox.shrink();
    }
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.sidebarDivider)),
      ),
      child: child,
    );
  }

  void _toggleSidebar(RightSidebar target) {
    setState(() {
      _rightSidebar = _rightSidebar == target ? RightSidebar.none : target;
    });
  }

  void _openPdfTab(String path) {
    final idx = _pdfOpenPaths.indexOf(path);
    if (idx >= 0) {
      setState(() => _pdfActiveIndex = idx);
      return;
    }
    if (_pdfOpenPaths.length >= _maxPdfTabs) return;
    setState(() {
      _pdfOpenPaths = [..._pdfOpenPaths, path];
      _pdfActiveIndex = _pdfOpenPaths.length - 1;
      _rightSidebar = RightSidebar.pdf;
    });
  }

  void _closePdfTab(int index) {
    if (index < 0 || index >= _pdfOpenPaths.length) return;
    setState(() {
      final next = [..._pdfOpenPaths]..removeAt(index);
      _pdfOpenPaths = next;
      if (_pdfActiveIndex >= next.length) {
        _pdfActiveIndex = next.length - 1;
      }
    });
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}

class _TabBar extends StatelessWidget {
  final DmToolColors palette;
  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _TabBar({
    required this.palette,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final t = tabs[i];
          final active = i == selectedIndex;
          return InkWell(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        active ? palette.tabIndicator : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(t.icon,
                      size: 16,
                      color: active
                          ? palette.tabIndicator
                          : palette.tabText),
                  const SizedBox(width: 6),
                  Text(t.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                        color: active
                            ? palette.tabIndicator
                            : palette.tabText,
                      )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
