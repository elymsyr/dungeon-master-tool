import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/beta_provider.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/connectivity_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/edit_mode_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/locale_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/projection_output_provider.dart';
import '../../application/providers/projection_provider.dart';
import '../../domain/entities/projection/projection_output_mode.dart';
import '../dialogs/screencast_display_picker.dart';
import '../../application/providers/theme_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/soundpad_provider.dart';
import '../../application/providers/undo_redo_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/sync_engine_provider.dart';
import '../../application/providers/world_mirror_provider.dart';
import '../../application/providers/world_sync_provider.dart';
import '../../application/providers/personal_sync_provider.dart';
import '../../application/services/pending_write_buffer.dart';
import '../../domain/entities/online/world_role.dart';
import '../../core/utils/screen_type.dart';
import '../dialogs/bug_report_dialog.dart';
import '../dialogs/import_package_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../theme/palettes.dart';
import '../widgets/app_icon_image.dart';
import '../widgets/characters_sidebar.dart';
import '../widgets/entity_sidebar.dart';
import '../widgets/lazy_indexed_stack.dart';
import '../widgets/pdf_sidebar.dart';
import '../widgets/projection/projection_status_icon.dart';
import '../widgets/save_sync_indicator.dart';
import '../widgets/soundmap_sidebar.dart';
import 'database/database_screen.dart';
import 'map/world_map_screen.dart';
import 'mind_map/mind_map_screen.dart';
import 'player/player_main_screen.dart';
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
  String? _selectedEntityId;
  String? _selectedEntityPanel;

  // Left sidebar state
  bool _sidebarOpen = true;
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 450;
  // ValueNotifier for drag-time rendering without full rebuild
  late final ValueNotifier<double> _sidebarWidthNotifier;

  // Right sidebar state (PDF / Soundmap — mutually exclusive, ortak genislik)
  // Hosted in a ValueNotifier so toggles + sub-tab switches don't trigger a
  // top-level MainScreen rebuild. Only the small VLBs wrapping the toggle
  // buttons + the sidebar overlay rebuild.
  late final ValueNotifier<RightSidebar> _rightSidebarCtrl;
  RightSidebar get _rightSidebar => _rightSidebarCtrl.value;
  double _rightSidebarWidth = 450;
  static const double _minRightSidebarWidth = 360;
  static const double _maxRightSidebarWidth = 700;
  late final ValueNotifier<double> _rightSidebarWidthNotifier;
  // PDF tab state
  List<String> _pdfOpenPaths = [];
  late final ValueNotifier<int> _pdfActiveIndexNotifier;
  int get _pdfActiveIndex => _pdfActiveIndexNotifier.value;
  static const int _maxPdfTabs = 10;
  // Tab bar'daki butonlarin sigmasi icin gereken minimum merkez genislik
  static const double _minCenterWidth = 480;
  static const double _tabBarHeight = 38;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    // Beta heartbeat: ilk launch'ta tek bir best-effort ping. Beta'da değilse
    // sunucu no-op yapar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(betaProvider.notifier).heartbeat();
    });
    // UiState'den restore et
    final uiState = ref.read(uiStateProvider);
    _tabIndex = uiState.mainTabIndex;
    _sidebarOpen = uiState.sidebarOpen;
    _sidebarWidth = uiState.sidebarWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
    _sidebarWidthNotifier = ValueNotifier(_sidebarWidth);
    // Right sidebar restore — silinen dosyaları temizle
    _rightSidebarCtrl = ValueNotifier(uiState.rightSidebar);
    _rightSidebarWidth = uiState.pdfSidebarWidth.clamp(_minRightSidebarWidth, _maxRightSidebarWidth);
    _rightSidebarWidthNotifier = ValueNotifier(_rightSidebarWidth);
    // Optimistic: assume saved paths still exist; verify async so initState
    // doesn't block first paint on a slow mobile filesystem.
    _pdfOpenPaths = List<String>.from(uiState.pdfOpenPaths);
    _pdfActiveIndexNotifier = ValueNotifier(
      _pdfOpenPaths.isEmpty
          ? -1
          : uiState.pdfActiveIndex.clamp(0, _pdfOpenPaths.length - 1),
    );
    unawaited(_pruneMissingPdfPaths());
  }

  Future<void> _pruneMissingPdfPaths() async {
    final pending = List<String>.from(_pdfOpenPaths);
    final survivors = <String>[];
    for (final path in pending) {
      if (await File(path).exists()) survivors.add(path);
    }
    if (!mounted || survivors.length == _pdfOpenPaths.length) return;
    setState(() {
      _pdfOpenPaths = survivors;
    });
    if (_pdfOpenPaths.isEmpty) {
      _pdfActiveIndexNotifier.value = -1;
    } else if (_pdfActiveIndex >= _pdfOpenPaths.length) {
      _pdfActiveIndexNotifier.value = _pdfOpenPaths.length - 1;
    }
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    _rightSidebarWidthNotifier.dispose();
    _rightSidebarCtrl.dispose();
    _pdfActiveIndexNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto sync: pause'da pending writes flush + outbox forceTick (OS suspend
    // etmeden önce slow tier'i da drain), realtime kanallarını kapat.
    // Resume'da `worldMirrorApplierProvider` invalidate edilir → PR-2'nin
    // FutureProvider yeniden resolve olur, subscribe + applyInitialState
    // tetiklenir.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Combat/entity/etc. row-level writes ride PendingWriteBuffer with up
      // to 2s debounce. App close mid-debounce dropped them silently —
      // e.g. monster HP edits reverting on next launch. Flush before kanal
      // teardown so the disk write completes.
      unawaited(() async {
        await ref.read(pendingWriteBufferProvider).flush();
        // Force drain — slow tier rows would otherwise wait `cloudDelay`
        // (10s) past the OS suspend boundary.
        await ref.read(syncEngineProvider).forceTick();
      }());
      final worldSync = ref.read(worldSyncServiceProvider);
      if (worldSync != null) unawaited(worldSync.unsubscribeAll());
      final personalSync = ref.read(personalSyncServiceProvider);
      if (personalSync != null) unawaited(personalSync.stop());
    } else if (state == AppLifecycleState.resumed) {
      ref.invalidate(worldMirrorApplierProvider);
    }
  }

  /// Hub'a dönüşte tetiklenen ortak exit akışı:
  /// Pending row-level edit'leri flush + (online ise) outbox forceTick
  /// "Saving..." overlay ile bekletilir. Sonra liste provider'ları invalidate
  /// + /hub. Kullanıcı arka tarafta data kaybetmesin diye sync zorlanır.
  Future<void> _exitToHub() async {
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'exit-world',
      'Saving...',
      () async {
        await ref.read(pendingWriteBufferProvider).flush();
        final online =
            ref.read(connectivityStreamProvider).valueOrNull ?? false;
        if (online) {
          await ref.read(syncEngineProvider).forceTick();
        }
      },
    );
    ref.invalidate(campaignListProvider);
    ref.invalidate(campaignInfoListProvider);
    if (mounted) context.go('/hub');
  }

  void _persistUiState() {
    ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
      mainTabIndex: _tabIndex,
      sidebarOpen: _sidebarOpen,
      sidebarWidth: _sidebarWidth,
      rightSidebar: _rightSidebar,
      pdfSidebarWidth: _rightSidebarWidth,
      pdfOpenPaths: _pdfOpenPaths,
      pdfActiveIndex: _pdfActiveIndex,
    ));
  }

  void _openPdfTab(String path) {
    // Zaten açıksa o tab'a geç
    final existing = _pdfOpenPaths.indexOf(path);
    if (existing != -1) {
      _pdfActiveIndexNotifier.value = existing;
      _rightSidebarCtrl.value = RightSidebar.pdf;
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
    });
    _pdfActiveIndexNotifier.value = _pdfOpenPaths.length - 1;
    _rightSidebarCtrl.value = RightSidebar.pdf;
    _persistUiState();
  }

  void _closePdfTab(int index) {
    if (index < 0 || index >= _pdfOpenPaths.length) return;
    setState(() {
      _pdfOpenPaths = [..._pdfOpenPaths]..removeAt(index);
    });
    final cur = _pdfActiveIndex;
    if (_pdfOpenPaths.isEmpty) {
      _pdfActiveIndexNotifier.value = -1;
    } else if (cur >= _pdfOpenPaths.length) {
      _pdfActiveIndexNotifier.value = _pdfOpenPaths.length - 1;
    } else if (cur > index) {
      _pdfActiveIndexNotifier.value = cur - 1;
    }
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

  Future<void> _openScreencastPicker(ProjectionController controller) async {
    final display = await ScreencastDisplayPicker.show(context);
    if (display == null || !mounted) return;
    controller.activateOutput(
      ProjectionOutputMode.screencast,
      displayId: display.id,
    );
  }

  /// Phone overflow-menu projection toggle. Mirrors [ProjectionStatusIcon]:
  /// deactivate when active, otherwise activate the first available output
  /// (screencast picker on mobile, second window on desktop layouts).
  Future<void> _togglePhoneProjection() async {
    final controller = ref.read(projectionControllerProvider.notifier);
    final state = ref.read(projectionControllerProvider);
    if (state.isActive) {
      controller.deactivateOutput();
      return;
    }
    final available = ref.read(availableProjectionOutputsProvider);
    if (available.isEmpty) return;
    final mode = available.first;
    if (mode == ProjectionOutputMode.screencast) {
      await _openScreencastPicker(controller);
    } else {
      await controller.activateOutput(mode);
    }
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
            children: List.generate(7, (i) {
              final isActive = i == _tabIndex;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _tabIndex = i);
                  _persistUiState();
                },
                child: SizedBox(
                  width: 80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabIcons[i], size: 24,
                            color: isActive ? palette.tabIndicator : palette.tabText),
                        const SizedBox(height: 4),
                        Text(tabLabels[i],
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

  static const _tabIcons = [
    Icons.storage,          // Database
    Icons.event_note,       // Session
    Icons.account_tree,     // Mind Map
    Icons.map,              // Map
    Icons.picture_as_pdf,   // PDF (mobile/tablet only)
    Icons.music_note,       // Soundmap (mobile/tablet only)
    Icons.people,           // Characters (mobile/tablet only)
  ];

  @override
  Widget build(BuildContext context) {
    // Online player ise tamamen ayrı, sade shell. role henüz resolve
    // olmadıysa DM görünümü ile başlar; resolve sonrası rebuild ile
    // PlayerMainScreen'e geçer.
    // U1: .select ile yalnızca çözülmüş role DEĞERİ değişince rebuild —
    // loading→data AsyncValue geçişleri tüm shell'i rebuild ettirmez.
    final roleState = ref.watch(
      currentWorldRoleProvider.select(
        (r) => (value: r.valueOrNull, loading: r.isLoading),
      ),
    );
    final roleHint = ref.watch(worldRoleHintProvider);
    final resolvedRole = roleState.value;
    // Resolve önceliği: provider somut dm/player verdiyse ona güven.
    // currentWorldRoleProvider re-resolve olurken AsyncLoading önceki
    // değeri (stale `none`) tutar → `valueOrNull` `null` değil `none`
    // döner. Bu yüzden `none`/`null` durumda açılış ipucuna düşeriz;
    // ipucu da yoksa ve hâlâ loading ise nötr splash → DM flash olmaz.
    final WorldRole? role;
    if (resolvedRole == WorldRole.dm || resolvedRole == WorldRole.player) {
      role = resolvedRole;
    } else if (roleHint != null) {
      role = roleHint;
    } else if (roleState.loading) {
      role = null;
    } else {
      role = WorldRole.none;
    }

    // Auto sync: worldMirrorApplierProvider'i watch et — provider hayatta
    // tutulur world açıkken. Provider içinde activeCampaignId/role resolve
    // olunca otomatik subscribe + applyInitialState çalışır. Role branch'ten
    // ÖNCE watch edilir ki player (PlayerMainScreen) de auto-sync alsın.
    // U1: .select((_) => 0) → keep-alive ama applier resolve/rebuild'i shell'i
    // rebuild ETTİRMEZ (dönüş değeri burada kullanılmıyor).
    ref.watch(worldMirrorApplierProvider.select((_) => 0));

    if (role == null) {
      // Rol henüz çözülmedi ve ipucu yok — nötr splash, DM flash etme.
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.shrink(),
      );
    }

    if (role == WorldRole.player) {
      return const PlayerMainScreen();
    }

    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final campaignName = ref.read(activeCampaignProvider) ?? '';

    ref.listen(activeCampaignSyncProvider, (_, _) {});
    // U1: keep-alive only — sync state değişimi shell'i rebuild ettirmesin.
    ref.watch(activeCampaignSyncProvider.select((_) => 0));
    final screen = getScreenType(context);
    final isLandscapePhone = screen == ScreenType.phone &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final tabLabels = [
      l10n.tabDatabase,
      l10n.tabSession,
      l10n.tabMindMap,
      l10n.tabMap,
      l10n.tabPdf,
      l10n.tabSoundmap,
      'Characters',
    ];

    // Listen for entity navigation requests from anywhere in the app
    ref.listen<String?>(entityNavigationProvider, (_, entityId) {
      if (entityId != null) {
        final panel = ref.read(entityNavigationTargetPanelProvider);
        setState(() {
          _selectedEntityId = entityId;
          _selectedEntityPanel = panel;
          _tabIndex = 0;
        });
        _persistUiState();
        ref.read(entityNavigationProvider.notifier).state = null;
        ref.read(entityNavigationTargetPanelProvider.notifier).state = null;
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
        _rightSidebarCtrl.value = RightSidebar.soundmap;
        _persistUiState();
        ref.read(soundmapNavigationProvider.notifier).state = null;
      }
    });

    // Keep battle map and entity card projections in sync with their
    // source state. Watching these providers installs their inner
    // listeners, which rebuild snapshots whenever the underlying data
    // changes. Both are no-ops when no matching projection items exist.
    // U1: .select((_) => 0) → inner listener'lar kurulur ama provider
    // emit'leri main shell'i rebuild ettirmez.
    ref.watch(projectionBattleMapSyncProvider.select((_) => 0));
    ref.watch(projectionEntitySyncProvider.select((_) => 0));

    final editMode = ref.watch(editModeProvider);

    // Listen for projection panel navigation requests
    ref.listen<bool?>(projectionPanelNavigationProvider, (_, value) {
      if (value == true) {
        setState(() => _tabIndex = 1);
        ref.read(uiStateProvider.notifier).update(
              (s) => s.copyWith(mainTabIndex: 1, sessionBottomTab: 2),
            );
        ref.read(projectionPanelNavigationProvider.notifier).state = null;
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

    final tabStack = LazyIndexedStack(
      index: _tabIndex,
      // Pre-warm offstage tabs after first paint so tab switches are
      // cheap IndexedStack swaps instead of cold subtree mounts.
      prewarm: true,
      children: [
        DatabaseScreen(
          editMode: editMode,
          selectedEntityId: _selectedEntityId,
          selectedEntityPanel: _selectedEntityPanel,
          onEntitySelected: (id) => setState(() => _selectedEntityId = id),
        ),
        const SessionScreen(),
        MindMapScreen(
          editMode: editMode,
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
        ValueListenableBuilder<int>(
          valueListenable: _pdfActiveIndexNotifier,
          builder: (_, activeIdx, _) => PdfSidebar(
            openPaths: _pdfOpenPaths,
            activeIndex: activeIdx,
            palette: palette,
            onTabSelect: (i) {
              _pdfActiveIndexNotifier.value = i;
              _persistUiState();
            },
            onTabClose: _closePdfTab,
            onOpenFile: _openPdfTab,
          ),
        ),
        // Soundmap tab (mobile/tablet only — desktop uses overlay sidebar)
        SoundmapSidebar(palette: palette),
        // Characters tab (mobile/tablet only — desktop uses overlay sidebar)
        CharactersSidebar(palette: palette),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitToHub();
        }
      },
      child: Scaffold(
      // --- Toolbar (AppBar) ---
      appBar: AppBar(
        titleSpacing: isLandscapePhone ? 0 : 8,
        leading: IconButton(
          icon: Icon(
            isLandscapePhone ? Icons.menu : Icons.arrow_back,
            size: 22,
          ),
          tooltip: isLandscapePhone ? l10n.mainMenu : l10n.mainBackToHub,
          onPressed: isLandscapePhone
              ? () => _showLandscapeNavSheet(tabLabels, palette)
              : _exitToHub,
        ),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const AppIconImage(size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                campaignName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
        actions: [
          // Undo / Redo
          _UndoRedoButtons(tabIndex: _tabIndex),
          const SizedBox(width: 4),
          // Save indicator — unified local + cloud + live-link status.
          const SaveSyncIndicator(),
          const SizedBox(width: 4),
          // Edit Mode toggle
          IconButton(
            icon: Icon(
              editMode ? Icons.edit : Icons.visibility,
              color: editMode ? palette.tokenBorderActive : null,
            ),
            tooltip: editMode ? l10n.mainEditMode : l10n.mainViewMode,
            onPressed: () => ref
                .read(editModeProvider.notifier)
                .update((s) => !s),
          ),
          // Player window status — desktop/tablet only. Phone collapses it
          // into the overflow menu below ("Player Window") to save AppBar
          // real estate.
          if (screen != ScreenType.phone) const ProjectionStatusIcon(),
          // Phone: collapse infrequent actions into overflow menu
          if (screen == ScreenType.phone) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (action) {
                switch (action) {
                  case 'projection':
                    _togglePhoneProjection();
                  case 'import':
                    ImportPackageDialog.show(context);
                  case 'bug':
                    BugReportDialog.show(context);
                  default:
                    // Theme selection
                    if (action.startsWith('theme:')) {
                      ref.read(themeProvider.notifier).setTheme(action.substring(6));
                    }
                    // Language selection
                    if (action.startsWith('lang:')) {
                      ref.read(localeProvider.notifier).setLocale(action.substring(5));
                    }
                }
              },
              itemBuilder: (_) {
                final projState = ref.read(projectionControllerProvider);
                final projAvail = ref.read(availableProjectionOutputsProvider);
                final projLabel = projState.isActive
                    ? 'Close Player Window'
                    : 'Open Player Window';
                final canProject = projState.isActive || projAvail.isNotEmpty;
                return [
                  if (canProject)
                    PopupMenuItem(
                      value: 'projection',
                      child: Row(children: [
                        Icon(
                          projState.isActive
                              ? Icons.cast_connected
                              : Icons.cast,
                          size: 18,
                          color: projState.isActive
                              ? palette.tokenBorderActive
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(projLabel),
                      ]),
                    ),
                PopupMenuItem(value: 'import', child: Row(children: [const Icon(Icons.inventory_2, size: 18), const SizedBox(width: 8), Text(l10n.importPackage)])),
                const PopupMenuDivider(),
                ...themeNames.map((name) => PopupMenuItem(
                  value: 'theme:$name',
                  child: Row(children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: themePalettes[name]?.canvasBg, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
                    const SizedBox(width: 8),
                    Text(name[0].toUpperCase() + name.substring(1)),
                  ]),
                )),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'lang:en', child: Text('English')),
                const PopupMenuItem(value: 'lang:tr', child: Text('Türkçe')),
                const PopupMenuItem(value: 'lang:de', child: Text('Deutsch')),
                const PopupMenuItem(value: 'lang:fr', child: Text('Français')),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'bug', child: Row(children: [const Icon(Icons.bug_report_outlined, size: 18), const SizedBox(width: 8), Text(l10n.menuReportBug)])),
                ];
              },
            ),
          ] else ...[
            // Desktop/Tablet: show all buttons
            // Import Package
            IconButton(
              icon: const Icon(Icons.inventory_2, size: 20),
              tooltip: l10n.importPackage,
              onPressed: () => ImportPackageDialog.show(context),
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
            // Bug report
            IconButton(
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              tooltip: l10n.menuReportBug,
              onPressed: () => BugReportDialog.show(context),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),

      // --- Body: Responsive Layout ---
      body: RepaintBoundary(
        child: switch (screen) {
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
                        // Tab bar — sağ sidebar overlay top:_tabBarHeight'tan başlar,
                        // toggle butonları her zaman ekranın en sağında sabit.
                        SizedBox(
                          height: _tabBarHeight,
                          child: Container(
                            color: palette.tabBg,
                            child: Row(
                            children: [
                              // Sol kisim: sidebar toggle + tab butonlari (scrollable)
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Database sidebar toggle
                                      IconButton(
                                        icon: Icon(
                                          _sidebarOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                                          size: 18,
                                        ),
                                        tooltip: _sidebarOpen ? l10n.mainCloseSidebar : l10n.mainOpenSidebar,
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
                                    ],
                                  ),
                                ),
                              ),
                              // Right-sidebar toggle group — wrapped in a single
                              // VLB so toggling any of the three rebuilds only
                              // this 3-button cluster (icons/color), not the
                              // whole MainScreen tab bar.
                              ValueListenableBuilder<RightSidebar>(
                                valueListenable: _rightSidebarCtrl,
                                builder: (context, current, _) {
                                  void toggle(RightSidebar target) {
                                    _rightSidebarCtrl.value =
                                        current == target ? RightSidebar.none : target;
                                    _persistUiState();
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // PDF sidebar toggle
                                      IconButton(
                                        icon: Icon(
                                          current == RightSidebar.pdf ? Icons.chrome_reader_mode : Icons.chrome_reader_mode_outlined,
                                          size: 18,
                                        ),
                                        tooltip: current == RightSidebar.pdf ? l10n.mainClosePdf : l10n.mainOpenPdf,
                                        color: current == RightSidebar.pdf ? palette.tabIndicator : palette.tabText,
                                        onPressed: () => toggle(RightSidebar.pdf),
                                        iconSize: 18,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      // Soundmap sidebar toggle
                                      IconButton(
                                        icon: Icon(
                                          current == RightSidebar.soundmap ? Icons.music_note : Icons.music_note_outlined,
                                          size: 18,
                                        ),
                                        tooltip: current == RightSidebar.soundmap ? l10n.mainCloseSoundmap : l10n.mainOpenSoundmap,
                                        color: current == RightSidebar.soundmap ? palette.tabIndicator : palette.tabText,
                                        onPressed: () => toggle(RightSidebar.soundmap),
                                        iconSize: 18,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      // Characters sidebar toggle
                                      IconButton(
                                        icon: Icon(
                                          current == RightSidebar.characters ? Icons.people : Icons.people_outline,
                                          size: 18,
                                        ),
                                        tooltip: current == RightSidebar.characters ? l10n.mainCloseCharacters : l10n.mainOpenCharacters,
                                        color: current == RightSidebar.characters ? palette.tabIndicator : palette.tabText,
                                        onPressed: () => toggle(RightSidebar.characters),
                                        iconSize: 18,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
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
            // Right sidebar — overlay olarak sağdan açılır (PDF / Soundmap /
            // Characters). Always rendered so sub-sidebars (visited via
            // LazyIndexedStack) preserve their state across toggles. When
            // current == none, the Positioned collapses to width 0 + Offstage
            // skips layout/paint of the inner subtree, while TickerMode
            // disables any animations of the hidden sidebars.
            ValueListenableBuilder<RightSidebar>(
              valueListenable: _rightSidebarCtrl,
              builder: (context, current, _) {
                final visible = current != RightSidebar.none;
                final sidebarIdx = switch (current) {
                  RightSidebar.none => 0,
                  RightSidebar.pdf => 1,
                  RightSidebar.soundmap => 2,
                  RightSidebar.characters => 3,
                };
                final content = Offstage(
                  offstage: !visible,
                  child: TickerMode(
                    enabled: visible,
                    child: Row(
                      children: [
                        // Drag handle — sürükleyerek genişletme
                        _DragHandle(
                          palette: palette,
                          dividerOnRight: true,
                          onDragUpdate: (dx) {
                            final totalW = MediaQuery.sizeOf(context).width;
                            final leftW = _sidebarOpen ? _sidebarWidthNotifier.value : 0.0;
                            final dynamicMax = (totalW - leftW - _minCenterWidth).clamp(0.0, _maxRightSidebarWidth);
                            _rightSidebarWidth = (_rightSidebarWidth - dx).clamp(_minRightSidebarWidth, dynamicMax);
                            _rightSidebarWidthNotifier.value = _rightSidebarWidth;
                          },
                          onDragEnd: () => _persistUiState(),
                        ),
                        // Sidebar content — LazyIndexedStack mounts each
                        // sub-sidebar at most once (on first visit) and keeps
                        // it alive afterwards, so re-opening PDF/Soundmap/
                        // Characters skips the cold-mount + provider re-init.
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
                            child: LazyIndexedStack(
                              index: sidebarIdx,
                              children: [
                                // 0: none → empty placeholder so untouched
                                // sub-sidebars don't mount until first open.
                                const SizedBox.shrink(),
                                // 1: PDF (activeIndex scoped to inner VLB).
                                ValueListenableBuilder<int>(
                                  valueListenable: _pdfActiveIndexNotifier,
                                  builder: (_, idx, _) => PdfSidebar(
                                    openPaths: _pdfOpenPaths,
                                    activeIndex: idx,
                                    palette: palette,
                                    onTabSelect: (i) {
                                      _pdfActiveIndexNotifier.value = i;
                                      _persistUiState();
                                    },
                                    onTabClose: _closePdfTab,
                                    onOpenFile: _openPdfTab,
                                  ),
                                ),
                                // 2: Soundmap.
                                SoundmapSidebar(palette: palette),
                                // 3: Characters.
                                CharactersSidebar(palette: palette),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return ValueListenableBuilder<double>(
                  valueListenable: _rightSidebarWidthNotifier,
                  builder: (_, width, child) => Positioned(
                    top: _tabBarHeight,
                    bottom: 0,
                    right: 0,
                    // Collapse to 0 when hidden so the center pane reclaims
                    // the space without paying any sidebar layout cost.
                    width: visible ? width : 0,
                    child: child!,
                  ),
                  child: content,
                );
              },
            ),
          ],
        ),

        // Tablet: NavigationRail + content
        ScreenType.tablet => Row(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - kToolbarHeight - MediaQuery.paddingOf(context).top),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _tabIndex,
                      onDestinationSelected: (i) { setState(() => _tabIndex = i); _persistUiState(); },
                      labelType: NavigationRailLabelType.selected,
                      destinations: List.generate(
                        7,
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

        // Mobile: portrait=BottomNav, landscape=leading menu in AppBar
        ScreenType.phone => tabStack,
        },
      ),

      // FAB for mobile/tablet entity sidebar
      floatingActionButton: (screen != ScreenType.desktop && _tabIndex == 0)
          ? FloatingActionButton.small(
              heroTag: 'main_screen_entity_sidebar_fab',
              onPressed: _showMobileSidebar,
              child: const Icon(Icons.list),
            )
          : null,

      // Mobile bottom nav (portrait only — landscape uses burger menu overlay).
      // Display order: database, session, mindmap, map, characters, soundmap,
      // pdf. Horizontal scroll so labels don't compress at narrow widths.
      bottomNavigationBar: (screen == ScreenType.phone && !isLandscapePhone)
          ? _MobileBottomTabBar(
              physicalOrder: const [0, 1, 2, 3, 6, 5, 4],
              tabIcons: _tabIcons,
              tabLabels: tabLabels,
              selectedPhysicalIndex: _tabIndex,
              onSelect: (i) {
                setState(() => _tabIndex = i);
                _persistUiState();
              },
              palette: palette,
            )
          : null,
    ),
    );
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // F9: toggle player window blackout — works without Ctrl, from any tab
    if (event.logicalKey == LogicalKeyboardKey.f9) {
      ref.read(projectionControllerProvider.notifier).toggleBlackout();
      return true;
    }

    if (!ctrl) return false;

    // Ctrl+E: always toggle edit mode (even when a text field has focus)
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      ref.read(editModeProvider.notifier).update((s) => !s);
      return true;
    }

    // Ctrl+Shift+P: toggle projection output
    if (shiftPressed && event.logicalKey == LogicalKeyboardKey.keyP) {
      final controller = ref.read(projectionControllerProvider.notifier);
      final pState = ref.read(projectionControllerProvider);
      if (pState.isActive) {
        controller.deactivateOutput();
      } else {
        // Activate with platform default (first available mode).
        final available = ref.read(availableProjectionOutputsProvider);
        if (available.isNotEmpty) {
          final mode = available.first;
          if (mode == ProjectionOutputMode.screencast) {
            _openScreencastPicker(controller);
          } else {
            controller.activateOutput(mode);
          }
        }
      }
      return true;
    }

    // Ctrl+P: toggle PDF sidebar
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      _rightSidebarCtrl.value = _rightSidebar == RightSidebar.pdf
          ? RightSidebar.none
          : RightSidebar.pdf;
      _persistUiState();
      return true;
    }

    // Ctrl+M: toggle Soundmap sidebar
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _rightSidebarCtrl.value = _rightSidebar == RightSidebar.soundmap
          ? RightSidebar.none
          : RightSidebar.soundmap;
      _persistUiState();
      return true;
    }

    // Ctrl+H: toggle Characters sidebar
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      _rightSidebarCtrl.value = _rightSidebar == RightSidebar.characters
          ? RightSidebar.none
          : RightSidebar.characters;
      _persistUiState();
      return true;
    }

    // Ctrl+. : stop all sounds
    if (event.logicalKey == LogicalKeyboardKey.period) {
      ref.read(soundpadStateProvider.notifier).stopAll();
      return true;
    }

    // Ctrl+, : stop ambience
    if (event.logicalKey == LogicalKeyboardKey.comma) {
      ref.read(soundpadStateProvider.notifier).stopAmbience();
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
    final l10n = L10n.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: canUndoVN,
          builder: (_, canUndo, _) => IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: l10n.mainUndoTooltip,
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
            tooltip: l10n.mainRedoTooltip,
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

/// İnce drag handle — sidebar kenarında sürükleyerek genişletme.
/// ValueNotifier ile çalışır, setState çağırmaz — performanslı.
class _DragHandle extends StatelessWidget {
  final DmToolColors palette;
  final void Function(double dx) onDragUpdate;
  final VoidCallback onDragEnd;

  final bool dividerOnRight;

  const _DragHandle({
    required this.palette,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.dividerOnRight = false,
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
          alignment: dividerOnRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 1,
            height: double.infinity,
            color: palette.sidebarDivider,
          ),
        ),
      ),
    );
  }
}

class _MobileBottomTabBar extends StatelessWidget {
  final List<int> physicalOrder;
  final List<IconData> tabIcons;
  final List<String> tabLabels;
  final int selectedPhysicalIndex;
  final ValueChanged<int> onSelect;
  final DmToolColors palette;

  const _MobileBottomTabBar({
    required this.physicalOrder,
    required this.tabIcons,
    required this.tabLabels,
    required this.selectedPhysicalIndex,
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
                for (final i in physicalOrder)
                  _TabItem(
                    icon: tabIcons[i],
                    label: tabLabels[i],
                    active: i == selectedPhysicalIndex,
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
        width: 76,
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
