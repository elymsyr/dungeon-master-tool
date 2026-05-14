import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/edit_mode_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/save_state_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/undo_redo_provider.dart';
import '../../../application/providers/world_mirror_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/entity_sidebar.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/pdf_sidebar.dart';
import '../../widgets/save_sync_indicator.dart';
import '../../widgets/soundmap_player_sidebar.dart';
import '../database/database_screen.dart';
import '../mind_map/mind_map_screen.dart';
import 'player_character_tab.dart';
import 'player_second_screen_tab.dart';

/// Player için MainScreen. DM görünümünü birebir takip eder (sol entity
/// sidebar, tab bar, sağ PDF/Soundmap overlay, AppBar action butonları),
/// fakat yetki kısıtlı: media gallery yok, package import yok (view-only),
/// projection icon yok, share/import butonları role-gated.
class PlayerMainScreen extends ConsumerStatefulWidget {
  const PlayerMainScreen({super.key});

  @override
  ConsumerState<PlayerMainScreen> createState() => _PlayerMainScreenState();
}

class _PlayerMainScreenState extends ConsumerState<PlayerMainScreen> {
  int _tabIndex = 0;
  String? _selectedEntityId;

  // Left sidebar state
  bool _sidebarOpen = true;
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 450;
  late final ValueNotifier<double> _sidebarWidthNotifier;

  // Right sidebar state (PDF / Soundmap — mutually exclusive)
  _RightSidebar _rightSidebar = _RightSidebar.none;
  double _rightSidebarWidth = 450;
  static const double _minRightSidebarWidth = 300;
  static const double _maxRightSidebarWidth = 700;
  late final ValueNotifier<double> _rightSidebarWidthNotifier;
  static const double _minCenterWidth = 480;

  // PDF tab state
  List<String> _pdfOpenPaths = [];
  int _pdfActiveIndex = -1;
  static const int _maxPdfTabs = 10;

  static const _tabIcons = [
    Icons.storage, // Database
    Icons.account_tree, // Mind Map
    Icons.person, // Character
    Icons.cast, // Second Screen
  ];

  /// Map player tab index → undoRedoDispatcher tab index.
  /// Database (0) → 0, Mind Map (1) → 2. Others → -1 (no undo/redo).
  int _undoTabIndex(int playerTab) => switch (playerTab) {
        0 => 0,
        1 => 2,
        _ => -1,
      };

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _sidebarWidthNotifier = ValueNotifier(_sidebarWidth);
    _rightSidebarWidthNotifier = ValueNotifier(_rightSidebarWidth);
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    _rightSidebarWidthNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  Future<void> _exitToHub() async {
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'save-world',
      'Saving world...',
      () => ref.read(saveStateProvider.notifier).saveNow(),
    );
    if (!mounted) return;
    ref.invalidate(campaignListProvider);
    ref.invalidate(campaignInfoListProvider);
    if (mounted) context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final campaignName = ref.read(activeCampaignProvider) ?? '';
    ref.watch(worldSyncAutoSubscribeProvider);

    final editMode = ref.watch(editModeProvider);
    final schema = ref.read(worldSchemaProvider);
    final screen = getScreenType(context);
    final isLandscapePhone = screen == ScreenType.phone &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final tabLabels = [
      l10n.tabDatabase,
      l10n.tabMindMap,
      'Character',
      'Second Screen',
    ];

    final tabStack = LazyIndexedStack(
      index: _tabIndex,
      children: [
        DatabaseScreen(
          editMode: editMode,
          selectedEntityId: _selectedEntityId,
          selectedEntityPanel: null,
          onEntitySelected: (id) => setState(() => _selectedEntityId = id),
        ),
        MindMapScreen(
          editMode: editMode,
          onOpenEntity: (id) => setState(() {
            _selectedEntityId = id;
            _tabIndex = 0;
          }),
        ),
        const PlayerCharacterTab(),
        const PlayerSecondScreenTab(),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitToHub();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: isLandscapePhone ? 0 : 8,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              isLandscapePhone ? Icons.menu : Icons.arrow_back,
              size: 22,
            ),
            tooltip: isLandscapePhone ? 'Menu' : 'Back to hub',
            onPressed: isLandscapePhone
                ? () => _showLandscapeNavSheet(tabLabels, palette)
                : _exitToHub,
          ),
          title: Row(
            children: [
              const AppIconImage(size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  campaignName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.tabBg,
                  borderRadius: palette.chr,
                  border: Border.all(color: palette.featureCardAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person,
                        size: 11, color: palette.featureCardAccent),
                    const SizedBox(width: 4),
                    Text(
                      'PLAYER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            _UndoRedoButtons(undoTabIndex: _undoTabIndex(_tabIndex)),
            const SizedBox(width: 4),
            const SaveSyncIndicator(),
            const SizedBox(width: 4),
            // Edit Mode toggle
            IconButton(
              icon: Icon(
                editMode ? Icons.edit : Icons.visibility,
                color: editMode ? palette.tokenBorderActive : null,
              ),
              tooltip: editMode ? 'Edit mode' : 'View mode',
              onPressed: () =>
                  ref.read(editModeProvider.notifier).update((s) => !s),
            ),
            // Packages — view-only (player can browse but cannot install)
            IconButton(
              icon: const Icon(Icons.inventory_2, size: 20),
              tooltip: 'Packages',
              onPressed: () =>
                  ImportPackageDialog.show(context, viewOnly: true),
            ),
            // Theme
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
                                border:
                                    Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name[0].toUpperCase() + name.substring(1)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            // Language
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
            // Bug report
            IconButton(
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              tooltip: 'Report a Bug',
              onPressed: () => BugReportDialog.show(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: RepaintBoundary(
          child: switch (screen) {
            ScreenType.desktop => _buildDesktopBody(
                palette: palette,
                schema: schema,
                tabStack: tabStack,
                tabLabels: tabLabels,
              ),
            ScreenType.tablet => Row(
                children: [
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height -
                            kToolbarHeight -
                            MediaQuery.paddingOf(context).top,
                      ),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: _tabIndex,
                          onDestinationSelected: (i) =>
                              setState(() => _tabIndex = i),
                          labelType: NavigationRailLabelType.selected,
                          destinations: List.generate(
                            tabLabels.length,
                            (i) => NavigationRailDestination(
                              icon: Icon(_tabIcons[i]),
                              label: Text(tabLabels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: tabStack),
                ],
              ),
            ScreenType.phone => tabStack,
          },
        ),
        floatingActionButton: (screen != ScreenType.desktop && _tabIndex == 0)
            ? FloatingActionButton.small(
                heroTag: 'player_main_screen_entity_sidebar_fab',
                onPressed: _showMobileSidebar,
                child: const Icon(Icons.list),
              )
            : null,
        bottomNavigationBar: (screen == ScreenType.phone && !isLandscapePhone)
            ? _PlayerBottomTabBar(
                tabIcons: _tabIcons,
                tabLabels: tabLabels,
                selectedIndex: _tabIndex,
                onSelect: (i) => setState(() => _tabIndex = i),
                palette: palette,
              )
            : null,
      ),
    );
  }

  Widget _buildDesktopBody({
    required DmToolColors palette,
    required dynamic schema,
    required Widget tabStack,
    required List<String> tabLabels,
  }) {
    return Stack(
          children: [
            Row(
              children: [
                  // Left sidebar — collapsible + resizable
                  if (_sidebarOpen)
                    ValueListenableBuilder<double>(
                      valueListenable: _sidebarWidthNotifier,
                      builder: (_, width, child) =>
                          SizedBox(width: width, child: child),
                      child: Row(
                        children: [
                          Expanded(
                            child: EntitySidebar(
                              schema: schema,
                              onEntitySelected: (id) {
                                setState(() {
                                  _selectedEntityId = id;
                                  _tabIndex = 0;
                                });
                              },
                            ),
                          ),
                          _DragHandle(
                            palette: palette,
                            onDragUpdate: (dx) {
                              _sidebarWidth = (_sidebarWidth + dx)
                                  .clamp(_minSidebarWidth, _maxSidebarWidth);
                              _sidebarWidthNotifier.value = _sidebarWidth;
                            },
                            onDragEnd: () {},
                          ),
                        ],
                      ),
                    ),
                  // Center: tab bar + tab content
                  Expanded(
                    child: RepaintBoundary(
                      child: Column(
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: _rightSidebarWidthNotifier,
                            builder: (_, rightWidth, child) => Container(
                              color: palette.tabBg,
                              padding: EdgeInsets.only(
                                right: _rightSidebar != _RightSidebar.none
                                    ? rightWidth
                                    : 0,
                              ),
                              child: child,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Sidebar toggle
                                        IconButton(
                                          icon: Icon(
                                            _sidebarOpen
                                                ? Icons.view_sidebar
                                                : Icons.view_sidebar_outlined,
                                            size: 18,
                                          ),
                                          tooltip: _sidebarOpen
                                              ? 'Close Sidebar'
                                              : 'Open Sidebar',
                                          onPressed: () => setState(() {
                                            _sidebarOpen = !_sidebarOpen;
                                            if (_sidebarOpen) {
                                              _sidebarWidthNotifier.value =
                                                  _sidebarWidth;
                                            }
                                          }),
                                          color: palette.tabText,
                                          iconSize: 18,
                                          constraints: const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        ...List.generate(tabLabels.length,
                                            (i) {
                                          final isActive = i == _tabIndex;
                                          return InkWell(
                                            onTap: () => setState(
                                                () => _tabIndex = i),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? palette.tabActiveBg
                                                    : palette.tabBg,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _tabIcons[i],
                                                    size: 18,
                                                    color: isActive
                                                        ? palette.tabActiveText
                                                        : palette.tabText,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    tabLabels[i],
                                                    style: TextStyle(
                                                      color: isActive
                                                          ? palette
                                                              .tabActiveText
                                                          : palette.tabText,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                                // PDF toggle
                                IconButton(
                                  icon: Icon(
                                    _rightSidebar == _RightSidebar.pdf
                                        ? Icons.chrome_reader_mode
                                        : Icons.chrome_reader_mode_outlined,
                                    size: 18,
                                  ),
                                  tooltip: _rightSidebar == _RightSidebar.pdf
                                      ? 'Close PDF Viewer'
                                      : 'Open PDF Viewer',
                                  color: _rightSidebar == _RightSidebar.pdf
                                      ? palette.tabIndicator
                                      : palette.tabText,
                                  onPressed: () => setState(() =>
                                      _rightSidebar =
                                          _rightSidebar == _RightSidebar.pdf
                                              ? _RightSidebar.none
                                              : _RightSidebar.pdf),
                                  iconSize: 18,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                ),
                                // Soundmap toggle
                                IconButton(
                                  icon: Icon(
                                    _rightSidebar == _RightSidebar.soundmap
                                        ? Icons.music_note
                                        : Icons.music_note_outlined,
                                    size: 18,
                                  ),
                                  tooltip:
                                      _rightSidebar == _RightSidebar.soundmap
                                          ? 'Close Soundmap'
                                          : 'Open Soundmap',
                                  color:
                                      _rightSidebar == _RightSidebar.soundmap
                                          ? palette.tabIndicator
                                          : palette.tabText,
                                  onPressed: () => setState(() =>
                                      _rightSidebar = _rightSidebar ==
                                              _RightSidebar.soundmap
                                          ? _RightSidebar.none
                                          : _RightSidebar.soundmap),
                                  iconSize: 18,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: RepaintBoundary(child: tabStack)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Right sidebar — overlay (PDF / Soundmap)
              if (_rightSidebar != _RightSidebar.none)
                ValueListenableBuilder<double>(
                  valueListenable: _rightSidebarWidthNotifier,
                  builder: (_, width, child) => Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: width,
                    child: child!,
                  ),
                  child: Row(
                    children: [
                      _DragHandle(
                        palette: palette,
                        onDragUpdate: (dx) {
                          final totalW = MediaQuery.sizeOf(context).width;
                          final leftW = _sidebarOpen
                              ? _sidebarWidthNotifier.value
                              : 0.0;
                          final dynamicMax = (totalW - leftW - _minCenterWidth)
                              .clamp(0.0, _maxRightSidebarWidth);
                          _rightSidebarWidth = (_rightSidebarWidth - dx)
                              .clamp(_minRightSidebarWidth, dynamicMax);
                          _rightSidebarWidthNotifier.value =
                              _rightSidebarWidth;
                        },
                        onDragEnd: () {},
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.canvasBg,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: switch (_rightSidebar) {
                            _RightSidebar.pdf => PdfSidebar(
                                openPaths: _pdfOpenPaths,
                                activeIndex: _pdfActiveIndex,
                                palette: palette,
                                onTabSelect: (i) =>
                                    setState(() => _pdfActiveIndex = i),
                                onTabClose: _closePdfTab,
                                onOpenFile: _openPdfTab,
                              ),
                            _RightSidebar.soundmap =>
                              SoundmapPlayerSidebar(palette: palette),
                            _RightSidebar.none => const SizedBox.shrink(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
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
          },
        ),
      ),
    );
  }

  void _showLandscapeNavSheet(List<String> tabLabels, DmToolColors palette) {
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
            children: List.generate(tabLabels.length, (i) {
              final isActive = i == _tabIndex;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _tabIndex = i);
                },
                child: SizedBox(
                  width: 90,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabIcons[i],
                            size: 24,
                            color: isActive
                                ? palette.tabIndicator
                                : palette.tabText),
                        const SizedBox(height: 4),
                        Text(tabLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive
                                  ? palette.tabIndicator
                                  : palette.tabText,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis),
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

  void _openPdfTab(String path) {
    final existing = _pdfOpenPaths.indexOf(path);
    if (existing != -1) {
      setState(() {
        _pdfActiveIndex = existing;
        _rightSidebar = _RightSidebar.pdf;
      });
      return;
    }
    if (_pdfOpenPaths.length >= _maxPdfTabs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Maximum 10 PDFs can be open at the same time.')),
      );
      return;
    }
    setState(() {
      _pdfOpenPaths = [..._pdfOpenPaths, path]
          .where((p) => File(p).existsSync() || p == path)
          .toList();
      _pdfActiveIndex = _pdfOpenPaths.length - 1;
      _rightSidebar = _RightSidebar.pdf;
    });
  }

  void _closePdfTab(int index) {
    if (index < 0 || index >= _pdfOpenPaths.length) return;
    setState(() {
      _pdfOpenPaths = [..._pdfOpenPaths]..removeAt(index);
      if (_pdfOpenPaths.isEmpty) {
        _pdfActiveIndex = -1;
      } else if (_pdfActiveIndex >= _pdfOpenPaths.length) {
        _pdfActiveIndex = _pdfOpenPaths.length - 1;
      } else if (_pdfActiveIndex > index) {
        _pdfActiveIndex--;
      }
    });
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (!ctrl) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      ref.read(editModeProvider.notifier).update((s) => !s);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      setState(() => _rightSidebar = _rightSidebar == _RightSidebar.pdf
          ? _RightSidebar.none
          : _RightSidebar.pdf);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      setState(() => _rightSidebar = _rightSidebar == _RightSidebar.soundmap
          ? _RightSidebar.none
          : _RightSidebar.soundmap);
      return true;
    }

    final focus = FocusManager.instance.primaryFocus;
    final isTextEditing =
        focus?.context?.findAncestorStateOfType<EditableTextState>() != null;
    if (isTextEditing) return false;

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final dispatcher = ref.read(undoRedoDispatcherProvider);
    final undoIdx = _undoTabIndex(_tabIndex);
    if (undoIdx < 0) return false;
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      shift ? dispatcher.redo(undoIdx) : dispatcher.undo(undoIdx);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
      dispatcher.redo(undoIdx);
      return true;
    }
    return false;
  }
}

enum _RightSidebar { none, pdf, soundmap }

class _UndoRedoButtons extends ConsumerWidget {
  /// Maps to UndoRedoDispatcher's internal tab indices.
  /// -1 disables both buttons (active tab has no undo target).
  final int undoTabIndex;
  const _UndoRedoButtons({required this.undoTabIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    if (undoTabIndex < 0) {
      // Render disabled placeholders for layout stability.
      return _disabledRow(palette);
    }
    final dispatcher = ref.read(undoRedoDispatcherProvider);
    final (canUndoVN, canRedoVN) = dispatcher.activeNotifiers(undoTabIndex);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: canUndoVN,
          builder: (_, canUndo, _) => IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: canUndo ? () => dispatcher.undo(undoTabIndex) : null,
            color: palette.tabActiveText,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: canRedoVN,
          builder: (_, canRedo, _) => IconButton(
            icon: const Icon(Icons.redo, size: 18),
            tooltip: 'Redo (Ctrl+Shift+Z)',
            onPressed: canRedo ? () => dispatcher.redo(undoTabIndex) : null,
            color: palette.tabActiveText,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ),
      ],
    );
  }

  Widget _disabledRow(DmToolColors palette) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Undo',
            onPressed: null,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            tooltip: 'Redo',
            onPressed: null,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ],
      );
}

class _DragHandle extends StatelessWidget {
  final DmToolColors palette;
  final void Function(double dx) onDragUpdate;
  final VoidCallback onDragEnd;

  const _DragHandle({
    required this.palette,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
      onHorizontalDragEnd: (_) => onDragEnd(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: palette.sidebarDivider,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerBottomTabBar extends StatelessWidget {
  final List<IconData> tabIcons;
  final List<String> tabLabels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final DmToolColors palette;

  const _PlayerBottomTabBar({
    required this.tabIcons,
    required this.tabLabels,
    required this.selectedIndex,
    required this.onSelect,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.tabBg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tabLabels.length; i++)
                  _TabItem(
                    icon: tabIcons[i],
                    label: tabLabels[i],
                    active: i == selectedIndex,
                    onTap: () => onSelect(i),
                    palette: palette,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final DmToolColors palette;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.tabIndicator : palette.tabText;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
