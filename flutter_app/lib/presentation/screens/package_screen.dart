import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:path/path.dart' as p;

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/manual_backup_provider.dart';
import '../../application/providers/event_bus_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/media_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/personal_online_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/undo_redo_provider.dart';
import '../../application/providers/world_packages_provider.dart';
import '../../domain/entities/online/world_role.dart';
import '../../core/config/supabase_config.dart';
import '../../application/services/srd_core_package_bootstrap.dart';
import '../../core/config/app_paths.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../../core/utils/screen_type.dart';
import '../dialogs/media_gallery_dialog.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/entity_sidebar.dart';
import 'database/database_screen.dart';

/// Paket düzenleme ekranı — sadeleştirilmiş MainScreen.
/// Yalnızca Database tab + entity sidebar.
/// ProviderScope override ile mevcut widget'ları paket verisine bağlar.
class PackageScreen extends ConsumerStatefulWidget {
  const PackageScreen({super.key});

  @override
  ConsumerState<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends ConsumerState<PackageScreen> {
  @override
  Widget build(BuildContext context) {
    final packageName = ref.watch(activePackageProvider) ?? '';
    final packageNotifier = ref.read(activePackageProvider.notifier);
    final data = packageNotifier.data;

    if (data == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/hub');
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/hub'),
            ),
            title: const Text('Package'),
          ),
          body: const Center(child: Text('No package loaded')),
        ),
      );
    }

    // Schema'yı paket verisinden oku
    WorldSchema? schema;
    if (data.containsKey('world_schema')) {
      try {
        schema = WorldSchema.fromJson(
          Map<String, dynamic>.from(data['world_schema'] as Map),
        );
      } catch (_) {}
    }

    if (schema == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/hub');
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/hub'),
            ),
            title: Text(packageName),
          ),
          body: const Center(child: Text('No template found for this package')),
        ),
      );
    }

    // ProviderScope override: mevcut widget'ları paket verisine bağla.
    // activeCampaignProvider override → EntityNotifier paket data'yı yazar.
    // worldSchemaProvider override → doğru schema'yı döner.
    // saveStateProvider override → paketi kaydeder.
    // Riverpod scoped override: bir provider override edildiğinde,
    // ona bağımlı tüm provider'lar da override edilmeli.
    // Zincir: activeCampaignProvider → saveStateProvider → entityProvider → undoRedoDispatcherProvider
    return ProviderScope(
      overrides: [
        activeCampaignProvider.overrideWith(
          (ref) {
            final repo = _PackageAsCampaignRepo(packageNotifier);
            final notifier = ActiveCampaignNotifier(repo, ref);
            notifier.preload(packageName, data);
            return notifier;
          },
        ),
        worldSchemaProvider.overrideWithValue(schema),
        mediaDirectoryProvider.overrideWithValue(
          p.join(AppPaths.packagesDir, packageName, 'media'),
        ),
        saveStateProvider.overrideWith(
          (ref) => SaveStateNotifier(ref),
        ),
        entityProvider.overrideWith(
          (ref) {
            final campaignNotifier =
                ref.read(activeCampaignProvider.notifier);
            return EntityNotifier(
              campaignNotifier,
              ref,
              () => ref.read(saveStateProvider.notifier).markDirty(),
              ref.read(eventBusProvider),
            );
          },
        ),
        undoRedoDispatcherProvider.overrideWith(
          (ref) => UndoRedoDispatcher(ref),
        ),
      ],
      child: _PackageScreenContent(
        packageName: packageName,
        schema: schema,
      ),
    );
  }
}

/// ActivePackageNotifier'ın verisini CampaignRepository arayüzüne saran adapter.
/// EntityNotifier, bu adapter üzerinden entity'leri okur/yazar.
class _PackageAsCampaignRepo implements CampaignRepository {
  final ActivePackageNotifier _packageNotifier;

  _PackageAsCampaignRepo(this._packageNotifier);

  @override
  Future<List<String>> getAvailable() async => [];

  @override
  Future<Map<String, dynamic>> load(String name) async =>
      _packageNotifier.data ?? {};

  @override
  Future<void> save(String name, Map<String, dynamic> data) =>
      _packageNotifier.save();

  @override
  Future<void> delete(String name) async {}

  @override
  Future<void> purge(String name) async {}

  @override
  Future<String> create(String name, {WorldSchema? template}) async => name;
}

/// Paket düzenleme ekranının asıl içeriği — ProviderScope içinde çalışır.
class _PackageScreenContent extends ConsumerStatefulWidget {
  final String packageName;
  final WorldSchema schema;

  const _PackageScreenContent({
    required this.packageName,
    required this.schema,
  });

  @override
  ConsumerState<_PackageScreenContent> createState() =>
      _PackageScreenContentState();
}

class _PackageScreenContentState
    extends ConsumerState<_PackageScreenContent> {
  bool _editMode = false;
  String? _selectedEntityId;

  // Sidebar state
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 450;
  late final ValueNotifier<double> _sidebarWidthNotifier;

  @override
  void initState() {
    super.initState();
    _sidebarWidthNotifier = ValueNotifier(_sidebarWidth);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  /// Hub'a donuse tetiklenen ortak exit akisi (sessiz):
  /// 1) Local save (saveNow)
  /// 2) Package list invalidate
  /// 3) /hub'a git
  Future<void> _exitToHub() async {
    await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'save-package',
      'Saving package...',
      () async {
        await ref.read(saveStateProvider.notifier).saveNow(pushAfter: true);
        await ref.read(manualBackupRunnerProvider).backupActiveItem();
      },
    );
    if (!mounted) return;
    ref.invalidate(packageListProvider);
    if (mounted) context.go('/hub');
  }

  /// Phone overflow-menu sync toggle. Mirrors [_PackageOnlineButton]:
  /// flushes local then flips the personal-online flag, surfacing snackbar
  /// feedback for both directions.
  Future<void> _togglePackageOnline(bool currentlyOnline) async {
    try {
      final notifier = ref.read(activePackageProvider.notifier);
      if (currentlyOnline) {
        await notifier.makeOffline();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package is now offline')),
        );
      } else {
        await notifier.save();
        await notifier.makeOnline();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package is now online')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Text field'da ise pass
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return false;
    }

    if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      ref.read(undoRedoDispatcherProvider).undo(0);
      return true;
    }
    if (ctrl &&
        shift &&
        (event.logicalKey == LogicalKeyboardKey.keyZ ||
            event.logicalKey == LogicalKeyboardKey.keyY)) {
      ref.read(undoRedoDispatcherProvider).redo(0);
      return true;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      ref.read(undoRedoDispatcherProvider).redo(0);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final dispatcher = ref.read(undoRedoDispatcherProvider);
    final (canUndoVN, canRedoVN) = dispatcher.activeNotifiers(0);

    // Save indicator
    final saveStatus = ref.watch(saveStateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitToHub();
      },
      child: Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitToHub,
        ),
        title: Row(
          children: [
            Icon(Icons.inventory_2, size: 20, color: palette.tabIndicator),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.packageName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
        actions: [
          // Undo / Redo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: canUndoVN,
                builder: (_, canUndo, _) => IconButton(
                  icon: const Icon(Icons.undo, size: 18),
                  tooltip: 'Undo (Ctrl+Z)',
                  onPressed: canUndo ? () => dispatcher.undo(0) : null,
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
                  onPressed: canRedo ? () => dispatcher.redo(0) : null,
                  color: palette.tabActiveText,
                  disabledColor: palette.tabText.withValues(alpha: 0.3),
                  iconSize: 18,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Save indicator
          Tooltip(
            message: switch (saveStatus) {
              SaveStatus.saved => 'All changes saved',
              SaveStatus.dirty => 'Unsaved changes',
              SaveStatus.saving => 'Saving...',
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: saveStatus == SaveStatus.saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.uiAutosaveTextEditing),
                    )
                  : Icon(
                      saveStatus == SaveStatus.saved
                          ? Icons.cloud_done
                          : Icons.cloud_upload,
                      size: 18,
                      color: saveStatus == SaveStatus.saved
                          ? palette.uiAutosaveTextSaved
                          : palette.uiAutosaveTextEditing,
                    ),
            ),
          ),
          const SizedBox(width: 4),
          // Online toggle — personal multi-device sync. Built-in pack
          // can't be made online (read-only on every device). Phone
          // collapses this into the overflow menu below.
          if (SupabaseConfig.isConfigured &&
              widget.packageName != srdCorePackageName &&
              getScreenType(context) != ScreenType.phone)
            _PackageOnlineButton(packageName: widget.packageName),
          // PR-SYNC-5: DM-only — share this package into the active world.
          if (SupabaseConfig.isConfigured &&
              widget.packageName != srdCorePackageName)
            _ShareToWorldButton(packageName: widget.packageName),
          // Edit Mode toggle — disabled for built-in (read-only) packages.
          Builder(builder: (_) {
            final isBuiltin = widget.packageName == srdCorePackageName;
            return IconButton(
              icon: Icon(
                isBuiltin
                    ? Icons.visibility_off_outlined
                    : (_editMode ? Icons.edit : Icons.visibility),
                color: _editMode && !isBuiltin
                    ? palette.tokenBorderActive
                    : null,
              ),
              tooltip: isBuiltin
                  ? 'Built-in package — read only. Use "Copy" from the Packages tab to make an editable clone.'
                  : (_editMode ? 'View mode' : 'Edit mode'),
              onPressed: isBuiltin
                  ? null
                  : () => setState(() => _editMode = !_editMode),
            );
          }),
          // Phone: collapse infrequent actions into overflow menu.
          // Desktop/Tablet: show inline.
          if (getScreenType(context) == ScreenType.phone)
            Builder(builder: (popupCtx) {
              final canSync = SupabaseConfig.isConfigured &&
                  widget.packageName != srdCorePackageName;
              final isOnline = canSync &&
                  ref
                      .watch(personalOnlinePackageNamesProvider)
                      .contains(widget.packageName);
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) async {
                  switch (action) {
                    case 'sync':
                      await _togglePackageOnline(isOnline);
                    case 'media':
                      final mediaDir = ref.read(mediaDirectoryProvider);
                      if (mediaDir.isNotEmpty) {
                        MediaGalleryDialog.show(
                          context,
                          mediaDir: mediaDir,
                          campaignId: 'package:${widget.packageName}',
                        );
                      }
                  }
                },
                itemBuilder: (_) => [
                  if (canSync)
                    PopupMenuItem(
                      value: 'sync',
                      child: Row(children: [
                        Icon(
                          isOnline ? Icons.cloud_done : Icons.cloud_outlined,
                          size: 18,
                          color: isOnline ? palette.successBtnBg : null,
                        ),
                        const SizedBox(width: 8),
                        Text(isOnline
                            ? 'Online — tap to make offline'
                            : 'Save & Sync (Make Online)'),
                      ]),
                    ),
                  if (canSync) const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'media',
                    child: Row(children: [
                      Icon(Icons.photo_library_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Media Gallery'),
                    ]),
                  ),
                ],
              );
            })
          else
            // Media Gallery
            IconButton(
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              tooltip: 'Media Gallery',
              onPressed: () {
                final mediaDir = ref.read(mediaDirectoryProvider);
                if (mediaDir.isNotEmpty) {
                  MediaGalleryDialog.show(
                    context,
                    mediaDir: mediaDir,
                    campaignId: 'package:${widget.packageName}',
                  );
                }
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Builder(builder: (context) {
        final screen = getScreenType(context);
        final showSidebar = screen != ScreenType.phone;
        return Row(
          children: [
            // Sol sidebar — desktop/tablet only
            if (showSidebar)
              ValueListenableBuilder<double>(
                valueListenable: _sidebarWidthNotifier,
                builder: (_, width, child) =>
                    SizedBox(width: width, child: child),
                child: Row(
                  children: [
                    Expanded(
                      child: EntitySidebar(
                        schema: widget.schema,
                        onEntitySelected: (id) {
                          setState(() {
                            _selectedEntityId = id;
                          });
                        },
                      ),
                    ),
                    // Drag handle
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        _sidebarWidth = (_sidebarWidth + details.delta.dx)
                            .clamp(_minSidebarWidth, _maxSidebarWidth);
                        _sidebarWidthNotifier.value = _sidebarWidth;
                      },
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
                    ),
                  ],
                ),
              ),
            // Database screen
            Expanded(
              child: DatabaseScreen(
                editMode: _editMode,
                selectedEntityId: _selectedEntityId,
                onEntitySelected: (id) =>
                    setState(() => _selectedEntityId = id),
              ),
            ),
          ],
        );
      }),
      // FAB for mobile entity sidebar
      floatingActionButton: Builder(builder: (context) {
        final screen = getScreenType(context);
        if (screen == ScreenType.phone) {
          return FloatingActionButton.small(
            heroTag: 'package_screen_entity_sidebar_fab',
            onPressed: _showMobileSidebar,
            child: const Icon(Icons.list),
          );
        }
        return const SizedBox.shrink();
      }),
    ),
    );
  }

  void _showMobileSidebar() {
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
          schema: widget.schema,
          onEntitySelected: (id) {
            Navigator.pop(ctx);
            setState(() {
              _selectedEntityId = id;
            });
          },
        ),
      ),
    );
  }
}

/// Paket "Make Online" toggle butonu — `OnlineWorldSection`'un paket
/// karşılığı. Tek tıklama, davet/üyelik yok; sahip kendi cihazları
/// arasında sync. Built-in SRD packı kullanıcıya read-only olduğu için
/// bu buton parent'ta gizlenir.
class _PackageOnlineButton extends ConsumerStatefulWidget {
  final String packageName;

  const _PackageOnlineButton({required this.packageName});

  @override
  ConsumerState<_PackageOnlineButton> createState() =>
      _PackageOnlineButtonState();
}

class _PackageOnlineButtonState
    extends ConsumerState<_PackageOnlineButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final isOnline = ref
        .watch(personalOnlinePackageNamesProvider)
        .contains(widget.packageName);

    return IconButton(
      icon: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.tabActiveText,
              ),
            )
          : Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_outlined,
              size: 18,
              color: isOnline
                  ? palette.successBtnBg
                  : palette.tabActiveText,
            ),
      tooltip: isOnline
          ? 'Online — tap to make offline'
          : 'Make Online (sync to your other devices)',
      onPressed: _busy ? null : () => _toggle(isOnline),
    );
  }

  Future<void> _toggle(bool currentlyOnline) async {
    setState(() => _busy = true);
    try {
      final notifier = ref.read(activePackageProvider.notifier);
      if (currentlyOnline) {
        await notifier.makeOffline();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package is now offline')),
        );
      } else {
        await notifier.save();
        await notifier.makeOnline();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package is now online')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// PR-SYNC-5: AppBar action — DM of the active world shares the currently
/// open package into that world. Hidden when there's no active world or
/// the user isn't its DM. One-tap re-share refreshes the cloud state.
class _ShareToWorldButton extends ConsumerWidget {
  final String packageName;
  const _ShareToWorldButton({required this.packageName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ref.watch(activeCampaignProvider);
    if (worldId == null) return const SizedBox.shrink();
    final roleAsync = ref.watch(currentWorldRoleProvider);
    final role = roleAsync.valueOrNull;
    if (role != WorldRole.dm) return const SizedBox.shrink();
    final shared =
        ref.watch(worldPackagesProvider(worldId)).valueOrNull ?? const [];
    final existing =
        shared.where((r) => r.packageName == packageName).firstOrNull;
    return IconButton(
      tooltip: existing != null
          ? 'Re-share with world'
          : 'Share with world',
      icon: Icon(
        existing != null ? Icons.cloud_sync : Icons.public,
        size: 18,
      ),
      onPressed: () async {
        try {
          await shareLocalPackageToWorld(
            ref: ref,
            worldId: worldId,
            packageName: packageName,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shared $packageName with world')),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e')),
          );
        }
      },
    );
  }
}
