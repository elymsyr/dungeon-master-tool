import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/locale_provider.dart';
import '../../application/providers/theme_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/undo_redo_provider.dart';
import '../../core/utils/screen_type.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../theme/palettes.dart';
import '../widgets/entity_sidebar.dart';
import '../widgets/pdf_sidebar.dart';
import '../widgets/soundmap_sidebar.dart';
import 'database/database_screen.dart';
import 'map/world_map_screen.dart';
import 'mind_map/mind_map_screen.dart';
import 'session/session_screen.dart';

/// Ana ekran — Python ui/main_root.py karşılığı.
/// 4 tab (Database, Session, Mind Map, Map) + sidebar + toolbar.
/// Responsive: Desktop=sidebar+tabs, Tablet=rail+tabs, Mobile=bottomNav.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _editMode = false;
  String? _selectedEntityId;

  // Left sidebar state
  bool _sidebarOpen = true;
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 450;
  // ValueNotifier for drag-time rendering without full rebuild
  late final ValueNotifier<double> _sidebarWidthNotifier;

  // Right sidebar state (PDF / Soundmap — mutually exclusive)
  RightSidebar _rightSidebar = RightSidebar.none;
  double _pdfSidebarWidth = 450;
  List<String> _pdfOpenPaths = [];
  int _pdfActiveIndex = -1;
  static const double _minPdfSidebarWidth = 300;
  static const double _maxPdfSidebarWidth = 700;
  static const int _maxPdfTabs = 10;
  late final ValueNotifier<double> _pdfSidebarWidthNotifier;
  double _soundmapSidebarWidth = 450;
  static const double _minSoundmapSidebarWidth = 300;
  static const double _maxSoundmapSidebarWidth = 700;
  late final ValueNotifier<double> _soundmapSidebarWidthNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    // UiState'den restore et
    final uiState = ref.read(uiStateProvider);
    _tabIndex = uiState.mainTabIndex;
    _sidebarOpen = uiState.sidebarOpen;
    _sidebarWidth = uiState.sidebarWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
    _sidebarWidthNotifier = ValueNotifier(_sidebarWidth);
    // Right sidebar restore — silinen dosyaları temizle
    _rightSidebar = uiState.rightSidebar;
    _pdfSidebarWidth = uiState.pdfSidebarWidth.clamp(_minPdfSidebarWidth, _maxPdfSidebarWidth);
    _pdfSidebarWidthNotifier = ValueNotifier(_pdfSidebarWidth);
    _pdfOpenPaths = uiState.pdfOpenPaths.where((p) => File(p).existsSync()).toList();
    _pdfActiveIndex = _pdfOpenPaths.isEmpty ? -1 : uiState.pdfActiveIndex.clamp(0, _pdfOpenPaths.length - 1);
    _soundmapSidebarWidth = uiState.soundmapSidebarWidth.clamp(_minSoundmapSidebarWidth, _maxSoundmapSidebarWidth);
    _soundmapSidebarWidthNotifier = ValueNotifier(_soundmapSidebarWidth);
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    _pdfSidebarWidthNotifier.dispose();
    _soundmapSidebarWidthNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(saveStateProvider.notifier).saveNow();
    }
  }

  void _persistUiState() {
    ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
      mainTabIndex: _tabIndex,
      sidebarOpen: _sidebarOpen,
      sidebarWidth: _sidebarWidth,
      rightSidebar: _rightSidebar,
      pdfSidebarWidth: _pdfSidebarWidth,
      pdfOpenPaths: _pdfOpenPaths,
      pdfActiveIndex: _pdfActiveIndex,
      soundmapSidebarWidth: _soundmapSidebarWidth,
    ));
  }

  void _openPdfTab(String path) {
    // Zaten açıksa o tab'a geç
    final existing = _pdfOpenPaths.indexOf(path);
    if (existing != -1) {
      setState(() {
        _pdfActiveIndex = existing;
        _rightSidebar = RightSidebar.pdf;
      });
      _persistUiState();
      return;
    }
    // Maks 10 tab
    if (_pdfOpenPaths.length >= _maxPdfTabs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 PDFs can be open at the same time.')),
      );
      return;
    }
    setState(() {
      _pdfOpenPaths = [..._pdfOpenPaths, path];
      _pdfActiveIndex = _pdfOpenPaths.length - 1;
      _rightSidebar = RightSidebar.pdf;
    });
    _persistUiState();
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
    _persistUiState();
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
    Icons.storage,          // Database
    Icons.event_note,       // Session
    Icons.account_tree,     // Mind Map
    Icons.map,              // Map
    Icons.picture_as_pdf,   // PDF (mobile/tablet only)
    Icons.music_note,       // Soundmap (mobile/tablet only)
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
      l10n.tabPdf,
      l10n.tabSoundmap,
    ];

    // Listen for entity navigation requests from anywhere in the app
    ref.listen<String?>(entityNavigationProvider, (_, entityId) {
      if (entityId != null) {
        setState(() {
          _selectedEntityId = entityId;
          _tabIndex = 0;
        });
        _persistUiState();
        ref.read(entityNavigationProvider.notifier).state = null;
      }
    });

    // Listen for PDF navigation requests from anywhere in the app
    ref.listen<String?>(pdfNavigationProvider, (_, path) {
      if (path != null) {
        _openPdfTab(path);
        ref.read(pdfNavigationProvider.notifier).state = null;
      }
    });

    // Listen for soundmap navigation requests
    ref.listen<bool?>(soundmapNavigationProvider, (_, value) {
      if (value != null) {
        setState(() => _rightSidebar = RightSidebar.soundmap);
        _persistUiState();
        ref.read(soundmapNavigationProvider.notifier).state = null;
      }
    });

    // Desktop'ta tab index 4/5 geçersiz — guard
    if (screen == ScreenType.desktop && _tabIndex > 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _tabIndex = 0);
        _persistUiState();
      });
    }

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
        MindMapScreen(
          editMode: _editMode,
          onOpenEntity: (entityId) {
            setState(() {
              _selectedEntityId = entityId;
              _tabIndex = 0;
            });
            _persistUiState();
          },
        ),
        WorldMapScreen(
          onOpenEntity: (entityId) {
            setState(() {
              _selectedEntityId = entityId;
              _tabIndex = 0;
            });
            _persistUiState();
          },
        ),
        // PDF tab (mobile/tablet only — desktop uses overlay sidebar)
        PdfSidebar(
          openPaths: _pdfOpenPaths,
          activeIndex: _pdfActiveIndex,
          palette: palette,
          onTabSelect: (i) { setState(() => _pdfActiveIndex = i); _persistUiState(); },
          onTabClose: _closePdfTab,
          onOpenFile: _openPdfTab,
        ),
        // Soundmap tab (mobile/tablet only — desktop uses overlay sidebar)
        SoundmapSidebar(palette: palette),
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
          // Undo / Redo
          _UndoRedoButtons(tabIndex: _tabIndex),
          const SizedBox(width: 4),
          // Save indicator
          const _SaveIndicator(),
          const SizedBox(width: 4),
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
        // Desktop: Sidebar (sol) + Tab bar + content + PDF sidebar (overlay)
        ScreenType.desktop => Stack(
          children: [
            // Ana içerik: sol sidebar + tab bar/content
            Row(
              children: [
                // Sol sidebar — collapsible + resizable
                if (_sidebarOpen)
                  ValueListenableBuilder<double>(
                    valueListenable: _sidebarWidthNotifier,
                    builder: (_, width, child) => SizedBox(width: width, child: child),
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
                              _persistUiState();
                            },
                          ),
                        ),
                        // Drag handle — sürükleyerek genişletme
                        _DragHandle(
                          palette: palette,
                          onDragUpdate: (dx) {
                            _sidebarWidth = (_sidebarWidth + dx).clamp(_minSidebarWidth, _maxSidebarWidth);
                            _sidebarWidthNotifier.value = _sidebarWidth;
                          },
                          onDragEnd: () => _persistUiState(),
                        ),
                      ],
                    ),
                  ),
                // Orta: tab bar + tab content
                Expanded(
                  child: RepaintBoundary(
                    child: Column(
                      children: [
                        // Tab bar — sağ sidebar açıkken padding ile kontrolleri kaydır
                        ValueListenableBuilder<double>(
                          valueListenable: _rightSidebar == RightSidebar.pdf
                              ? _pdfSidebarWidthNotifier
                              : _soundmapSidebarWidthNotifier,
                          builder: (_, rightWidth, child) => Container(
                            color: palette.tabBg,
                            padding: EdgeInsets.only(
                              right: _rightSidebar != RightSidebar.none ? rightWidth : 0,
                            ),
                            child: child,
                          ),
                          child: Row(
                            children: [
                              // Database sidebar toggle
                              IconButton(
                                icon: Icon(
                                  _sidebarOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                                  size: 18,
                                ),
                                tooltip: _sidebarOpen ? 'Close Sidebar' : 'Open Sidebar',
                                onPressed: () { setState(() { _sidebarOpen = !_sidebarOpen; if (_sidebarOpen) _sidebarWidthNotifier.value = _sidebarWidth; }); _persistUiState(); },
                                color: palette.tabText,
                                iconSize: 18,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              // Tab butonları (desktop: 4 tab)
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
                              // PDF sidebar toggle
                              IconButton(
                                icon: Icon(
                                  _rightSidebar == RightSidebar.pdf ? Icons.chrome_reader_mode : Icons.chrome_reader_mode_outlined,
                                  size: 18,
                                ),
                                tooltip: _rightSidebar == RightSidebar.pdf ? 'Close PDF Viewer' : 'Open PDF Viewer',
                                color: _rightSidebar == RightSidebar.pdf ? palette.tabIndicator : palette.tabText,
                                onPressed: () { setState(() => _rightSidebar = _rightSidebar == RightSidebar.pdf ? RightSidebar.none : RightSidebar.pdf); _persistUiState(); },
                                iconSize: 18,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              // Soundmap sidebar toggle
                              IconButton(
                                icon: Icon(
                                  _rightSidebar == RightSidebar.soundmap ? Icons.music_note : Icons.music_note_outlined,
                                  size: 18,
                                ),
                                tooltip: _rightSidebar == RightSidebar.soundmap ? 'Close Soundmap' : 'Open Soundmap',
                                color: _rightSidebar == RightSidebar.soundmap ? palette.tabIndicator : palette.tabText,
                                onPressed: () { setState(() => _rightSidebar = _rightSidebar == RightSidebar.soundmap ? RightSidebar.none : RightSidebar.soundmap); _persistUiState(); },
                                iconSize: 18,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ],
                          ),
                        ),
                        // Tab content
                        Expanded(child: RepaintBoundary(child: tabStack)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Right sidebar — overlay olarak sağdan açılır (PDF veya Soundmap)
            if (_rightSidebar != RightSidebar.none)
              ValueListenableBuilder<double>(
                valueListenable: _rightSidebar == RightSidebar.pdf
                    ? _pdfSidebarWidthNotifier
                    : _soundmapSidebarWidthNotifier,
                builder: (_, width, child) => Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: width,
                  child: child!,
                ),
                child: Row(
                  children: [
                    // Drag handle — sürükleyerek genişletme
                    _DragHandle(
                      palette: palette,
                      onDragUpdate: (dx) {
                        if (_rightSidebar == RightSidebar.pdf) {
                          _pdfSidebarWidth = (_pdfSidebarWidth - dx).clamp(_minPdfSidebarWidth, _maxPdfSidebarWidth);
                          _pdfSidebarWidthNotifier.value = _pdfSidebarWidth;
                        } else {
                          _soundmapSidebarWidth = (_soundmapSidebarWidth - dx).clamp(_minSoundmapSidebarWidth, _maxSoundmapSidebarWidth);
                          _soundmapSidebarWidthNotifier.value = _soundmapSidebarWidth;
                        }
                      },
                      onDragEnd: () => _persistUiState(),
                    ),
                    // Sidebar content
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
                        child: _rightSidebar == RightSidebar.pdf
                            ? PdfSidebar(
                                openPaths: _pdfOpenPaths,
                                activeIndex: _pdfActiveIndex,
                                palette: palette,
                                onTabSelect: (i) { setState(() => _pdfActiveIndex = i); _persistUiState(); },
                                onTabClose: _closePdfTab,
                                onOpenFile: _openPdfTab,
                              )
                            : SoundmapSidebar(palette: palette),
                      ),
                    ),
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
                  6,
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
                6,
                (i) => NavigationDestination(
                  icon: Icon(_tabIcons[i]),
                  label: tabLabels[i],
                ),
              ),
            )
          : null,
    );
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (!ctrl) return false;

    // Ctrl+E: always toggle edit mode (even when a text field has focus)
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      setState(() => _editMode = !_editMode);
      return true;
    }

    // Ctrl+P: toggle PDF sidebar
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      setState(() => _rightSidebar = _rightSidebar == RightSidebar.pdf ? RightSidebar.none : RightSidebar.pdf);
      _persistUiState();
      return true;
    }

    // Ctrl+M: toggle Soundmap sidebar
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      setState(() => _rightSidebar = _rightSidebar == RightSidebar.soundmap ? RightSidebar.none : RightSidebar.soundmap);
      _persistUiState();
      return true;
    }

    // Ctrl+Z / Ctrl+Y: skip if a text field has focus (TextField handles its own undo)
    final focus = FocusManager.instance.primaryFocus;
    final isTextEditing = focus?.context?.findAncestorStateOfType<EditableTextState>() != null;
    if (isTextEditing) return false;

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final dispatcher = ref.read(undoRedoDispatcherProvider);
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (shift) {
        dispatcher.redo(_tabIndex);
      } else {
        dispatcher.undo(_tabIndex);
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
      dispatcher.redo(_tabIndex);
      return true;
    }
    return false;
  }
}

/// Undo / Redo buttons that dispatch to the active tab's notifier.
class _UndoRedoButtons extends ConsumerWidget {
  final int tabIndex;
  const _UndoRedoButtons({required this.tabIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatcher = ref.read(undoRedoDispatcherProvider);
    final (canUndoVN, canRedoVN) = dispatcher.activeNotifiers(tabIndex);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: canUndoVN,
          builder: (_, canUndo, _) => IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: canUndo ? () => dispatcher.undo(tabIndex) : null,
            color: palette.tabActiveText,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: canRedoVN,
          builder: (_, canRedo, _) => IconButton(
            icon: const Icon(Icons.redo, size: 18),
            tooltip: 'Redo (Ctrl+Shift+Z)',
            onPressed: canRedo ? () => dispatcher.redo(tabIndex) : null,
            color: palette.tabActiveText,
            disabledColor: palette.tabText.withValues(alpha: 0.3),
            iconSize: 18,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ),
      ],
    );
  }
}

/// Save status indicator — icon-only with tooltip.
class _SaveIndicator extends ConsumerWidget {
  const _SaveIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(saveStateProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    final (IconData? icon, Color color, String tooltip) = switch (status) {
      SaveStatus.saved => (Icons.cloud_done, palette.uiAutosaveTextSaved, 'All changes saved'),
      SaveStatus.dirty => (Icons.cloud_upload, palette.uiAutosaveTextEditing, 'Unsaved changes'),
      SaveStatus.saving => (null, palette.uiAutosaveTextEditing, 'Saving...'),
    };

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: icon != null
            ? Icon(icon, size: 18, color: color)
            : SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
      ),
    );
  }
}

/// İnce drag handle — sidebar kenarında sürükleyerek genişletme.
/// ValueNotifier ile çalışır, setState çağırmaz — performanslı.
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
