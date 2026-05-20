import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/sync_engine_provider.dart';
import '../../../domain/entities/map_data.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/unbounded_stack.dart';
import 'epoch_scroll_bar.dart';
import 'epoch_waypoint_dialog.dart';
import 'timeline_entry_dialog.dart';
import 'widgets/pin_edit_dialog.dart';
import 'world_map_notifier.dart';

/// World Map tab root — toolbar + pannable/zoomable image canvas with pins
/// and timeline support.
class WorldMapScreen extends ConsumerStatefulWidget {
  final void Function(String entityId)? onOpenEntity;

  const WorldMapScreen({super.key, this.onOpenEntity});

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> {
  final FocusNode _canvasFocusNode = FocusNode(debugLabel: 'WorldMapCanvas');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    super.dispose();
  }

  void _init() {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final mapData = Map<String, dynamic>.from(data['map_data'] as Map? ?? {});
    // Viewport now lives in sibling `map_view` (local-only). Prefer it; fall
    // back to legacy nested scale/pan keys inside `map_data` for worlds saved
    // before the split. `init` reads scale/pan_x/pan_y off the map it receives.
    final mapView = data['map_view'] as Map?;
    if (mapView != null) {
      if (mapView['scale'] != null) mapData['scale'] = mapView['scale'];
      if (mapView['pan_x'] != null) mapData['pan_x'] = mapView['pan_x'];
      if (mapView['pan_y'] != null) mapData['pan_y'] = mapView['pan_y'];
    }
    ref.read(worldMapProvider.notifier).init(mapData);
  }

  @override
  void deactivate() {
    // Provider mutation during deactivate fails Riverpod's "modify while
    // building" assertion when the parent rebuild is still in flight.
    // Capture notifiers (provider singletons outlive this widget) and run
    // the sync after the current frame.
    //
    // F3 row-level: write `map_data` key only in settings_json via
    // saveSettingsPatch — no global markDirty / world-wide bulk save.
    // F6 follow-up: also enqueue typed `world_map_data` row so other
    // online devices see the change (previously routed through the
    // deleted `_bundleAndPush` close-time push).
    final mapNotifier = ref.read(worldMapProvider.notifier);
    final campaign = ref.read(activeCampaignProvider.notifier);
    final worldId =
        ref.read(activeCampaignIdProvider).valueOrNull;
    final online = worldId != null &&
        ref.read(onlineWorldIdsProvider).contains(worldId);
    final auth = ref.read(authProvider);
    final isDm =
        ref.read(currentWorldRoleProvider).valueOrNull == WorldRole.dm;
    final engine = ref.read(syncEngineProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        mapNotifier.syncToCampaignData();
        final mapData = campaign.data?['map_data'];
        if (mapData is Map) {
          final mapMap = Map<String, dynamic>.from(mapData);
          // ignore: discarded_futures
          campaign.saveSettingsPatch({'map_data': mapMap});
          // DM-only: world_map_data RLS rejects players (engine drops
          // 42501 but pre-empting avoids the round-trip).
          if (online && auth != null && isDm) {
            // ignore: discarded_futures
            engine.enqueueWorldMapData(worldId: worldId, data: mapMap);
          }
        }
        // Viewport sibling key — local only, never cloud.
        final mapView = campaign.data?['map_view'];
        if (mapView is Map) {
          // ignore: discarded_futures
          campaign.saveSettingsPatchLocalOnly(
            {'map_view': Map<String, dynamic>.from(mapView)},
          );
        }
      } catch (_) {}
    });
    super.deactivate();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(worldMapProvider.notifier);

    // Each Consumer subtree watches the world map provider independently so a
    // toolbar toggle does not invalidate the canvas, and an epoch switch does
    // not rebuild the toolbar. The canvas Consumer holds the heaviest paint
    // workload, so isolating its rebuild surface is the highest-leverage win.
    return Column(
      children: [
        Consumer(
          builder: (context, ref, _) {
            final mapState = ref.watch(worldMapProvider);
            return _buildToolbar(palette, notifier, mapState);
          },
        ),
        Expanded(
          child: Stack(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final mapState = ref.watch(worldMapProvider);
                  return _buildCanvas(palette, notifier, mapState);
                },
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Consumer(
                  builder: (context, ref, _) {
                    final epochs = ref.watch(
                      worldMapProvider.select((s) => s.epochs),
                    );
                    if (epochs.length <= 1) return const SizedBox.shrink();
                    final waypoints = ref.watch(
                      worldMapProvider.select((s) => s.waypoints),
                    );
                    final activeEpochIndex = ref.watch(
                      worldMapProvider.select((s) => s.activeEpochIndex),
                    );
                    final startLabel = ref.watch(
                      worldMapProvider.select((s) => s.epochStartLabel),
                    );
                    final endLabel = ref.watch(
                      worldMapProvider.select((s) => s.epochEndLabel),
                    );
                    return EpochScrollBar(
                      epochs: epochs,
                      waypoints: waypoints,
                      activeEpochIndex: activeEpochIndex,
                      epochNames: notifier.epochNames,
                      palette: palette,
                      startLabel: startLabel,
                      endLabel: endLabel,
                      onSwitchEpoch: notifier.switchEpoch,
                      onAddWaypoint: (insertIdx) =>
                          _showAddWaypointDialog(insertIdx, notifier, palette),
                      onDeleteWaypoint: (wpIdx) =>
                          _showDeleteWaypointDialog(wpIdx, notifier, palette),
                      onRenameWaypoint: (wpIdx) =>
                          _showRenameWaypointDialog(wpIdx, notifier, palette),
                      onRenameBoundary: (s, e) =>
                          notifier.updateEpochBoundaryLabels(
                            startLabel: s,
                            endLabel: e,
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Toolbar
  // -------------------------------------------------------------------------

  Widget _buildToolbar(
    DmToolColors palette,
    WorldMapNotifier notifier,
    WorldMapState mapState,
  ) {
    const pinTypes = ['npc', 'monster', 'location', 'event', 'default'];
    final allHidden = pinTypes.every(
      (t) => mapState.hiddenPinTypes.contains(t),
    );

    return Container(
      width: double.infinity,
      color: palette.tabBg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 0,
        runSpacing: 2,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Pick map image
          _ToolbarButton(
            icon: Icons.map_outlined,
            label: mapState.imagePath.isEmpty ? 'Load Map' : 'Change',
            palette: palette,
            onTap: () => notifier.pickMapImage(context),
          ),

          // Mobile-only: add pin from database (no right-click on touch).
          if (Platform.isAndroid || Platform.isIOS) ...[
            _VertDiv(palette: palette),
            _ToolbarButton(
              icon: Icons.add_location_alt_outlined,
              label: 'Add from DB',
              palette: palette,
              onTap: () => _showEntityPickerForMap(
                notifier.viewportCenterCanvas,
                notifier,
              ),
            ),
          ],

          _VertDiv(palette: palette),

          // Pin category dropdown
          _PinCategoryDropdown(
            palette: palette,
            hiddenPinTypes: mapState.hiddenPinTypes,
            onToggle: notifier.togglePinTypeVisibility,
          ),

          // Hide all checkbox
          _ToolbarCheckbox(
            label: 'Hide All',
            value: allHidden,
            palette: palette,
            onChanged: (v) {
              for (final t in pinTypes) {
                final hidden = mapState.hiddenPinTypes.contains(t);
                if (v == true && !hidden) {
                  notifier.togglePinTypeVisibility(t);
                } else if (v == false && hidden) {
                  notifier.togglePinTypeVisibility(t);
                }
              }
            },
          ),

          // Pin size
          InkWell(
            key: const ValueKey('pin_size'),
            onTap: notifier.cyclePinSize,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(
                Icons.circle,
                size: switch (mapState.pinSize) {
                  PinSize.small => 8,
                  PinSize.medium => 12,
                  PinSize.large => 16,
                },
                color: palette.tabText,
              ),
            ),
          ),

          _VertDiv(palette: palette),

          // Timeline checkbox
          _ToolbarCheckbox(
            label: 'Timeline',
            value: mapState.showTimeline,
            palette: palette,
            onChanged: (_) => notifier.toggleTimelineVisibility(),
          ),

          // Pins checkbox
          _ToolbarCheckbox(
            label: 'Pins',
            value: mapState.showMapPins,
            palette: palette,
            onChanged: (_) => notifier.toggleMapPinsVisibility(),
          ),

          _VertDiv(palette: palette),

          // Zoom controls
          InkWell(
            key: const ValueKey('zoom_in'),
            onTap: () => notifier.zoomAtPoint(const Offset(0, 0), -1),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 14, color: palette.tabText),
            ),
          ),
          InkWell(
            key: const ValueKey('zoom_out'),
            onTap: () => notifier.zoomAtPoint(const Offset(0, 0), 1),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 14, color: palette.tabText),
            ),
          ),
          InkWell(
            key: const ValueKey('reset_view'),
            onTap: notifier.resetView,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.fit_screen, size: 14, color: palette.tabText),
            ),
          ),

          _VertDiv(palette: palette),

          // Project Map (export)
          _ToolbarButton(
            icon: Icons.photo_camera,
            label: 'Project',
            palette: palette,
            onTap: () => _projectMap(palette),
          ),

          _VertDiv(palette: palette),

          // Epochs
          _ToolbarButton(
            icon: Icons.timeline,
            label: mapState.epochs.length > 1
                ? 'Epochs (${mapState.epochs.length})'
                : 'Epochs',
            palette: palette,
            highlight: mapState.epochs.length > 1,
            onTap: () => _showAddWaypointDialog(
              mapState.activeEpochIndex,
              notifier,
              palette,
            ),
          ),

          // Status text
          if (mapState.isLinkMode)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Click pin to link · Click empty to create · Esc to cancel',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber.withValues(alpha: 0.8),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Right-click to place pin · Drag to pan · Scroll to zoom',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.tabText.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Canvas
  // -------------------------------------------------------------------------

  Widget _buildCanvas(
    DmToolColors palette,
    WorldMapNotifier notifier,
    WorldMapState mapState,
  ) {
    final inLinkMode = mapState.isLinkMode;
    final cursor = inLinkMode
        ? SystemMouseCursors.precise
        : SystemMouseCursors.basic;

    return LayoutBuilder(
      builder: (context, constraints) {
        notifier.updateViewportSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return KeyboardListener(
          focusNode: _canvasFocusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (inLinkMode) notifier.cancelLinkMode();
            }
          },
          child: MouseRegion(
            cursor: cursor,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) =>
                  _onEntityDrop(context, details, notifier),
              builder: (context, _, _) {
                return Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      notifier.zoomAtPoint(
                        event.localPosition,
                        event.scrollDelta.dy,
                      );
                    }
                  },
                  child: GestureDetector(
                    onScaleStart: notifier.onScaleStart,
                    onScaleUpdate: notifier.onScaleUpdate,
                    onScaleEnd: (_) => notifier.onScaleEnd(),
                    onTapUp: inLinkMode
                        ? (d) => _handleCanvasTap(
                            d.localPosition,
                            notifier,
                            mapState,
                          )
                        : null,
                    onDoubleTapDown: mapState.showTimeline
                        ? (details) {
                            final canvasPos = notifier.screenToCanvas(
                              details.localPosition,
                            );
                            _showTimelineEntryDialog(
                              canvasPos,
                              notifier,
                              palette,
                            );
                          }
                        : null,
                    onSecondaryTapUp: (d) {
                      _showCanvasContextMenu(
                        d.localPosition,
                        d.globalPosition,
                        notifier,
                        palette,
                        isTimelineMode: mapState.showTimeline,
                      );
                    },
                    onLongPressStart: (d) {
                      _showCanvasContextMenu(
                        d.localPosition,
                        d.globalPosition,
                        notifier,
                        palette,
                        isTimelineMode: mapState.showTimeline,
                      );
                    },
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: palette.canvasBg),
                          _buildImageAndPins(palette, notifier, mapState),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleCanvasTap(
    Offset localPos,
    WorldMapNotifier notifier,
    WorldMapState mapState,
  ) {
    if (mapState.isLinkMode) {
      final canvasPos = notifier.screenToCanvas(localPos);
      notifier.handleLinkToNew(canvasPos);
    }
  }

  Widget _buildImageAndPins(
    DmToolColors palette,
    WorldMapNotifier notifier,
    WorldMapState mapState,
  ) {
    // F1: Transform isolated in ValueListenableBuilder's `builder` slot;
    //     pin Stack lives in the `child` slot so it's built once per outer
    //     rebuild instead of every viewTransform tick.
    return ValueListenableBuilder<WorldMapViewTransform>(
      valueListenable: notifier.viewTransform,
      builder: (_, vt, child) => Transform(
        transform: Matrix4.identity()
          ..translateByDouble(vt.panOffset.dx, vt.panOffset.dy, 0, 1)
          ..scaleByDouble(vt.scale, vt.scale, 1, 1),
        alignment: Alignment.topLeft,
        child: child,
      ),
      // UnboundedStack: Transform inverse-maps screen → canvas coords that
      // exceed this Stack's viewport-sized bounds. Default Stack.hitTest
      // rejects out-of-bounds positions, blocking pin tap/long-press.
      child: UnboundedStack(
        clipBehavior: Clip.none,
        children: [
          // Background image — OverflowBox removes parent constraints
          // so Image renders at full natural size (Transform handles zoom).
          // RepaintBoundary keeps the static image layer cached across
          // pan/zoom so pin movements don't invalidate the image picture.
          // F5: cacheWidth paired with cacheHeight caps decoded RAM on
          //     wide landscape maps; Image SDK preserves aspect ratio.
          if (mapState.imagePath.isNotEmpty &&
              File(mapState.imagePath).existsSync())
            RepaintBoundary(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Image.file(
                  File(mapState.imagePath),
                  fit: BoxFit.none,
                  cacheWidth: 4096,
                  cacheHeight: 4096,
                ),
              ),
            )
          else
            _buildEmptyMapPlaceholder(palette),

          // F2/F3: viewport-culled pin + painter layer. Rebuilds at
          //        cullTick (gesture-END / discrete zoom), not on every
          //        scale tick.
          ValueListenableBuilder<int>(
            valueListenable: notifier.cullTick,
            builder: (_, _, _) =>
                _buildCulledPinLayer(palette, notifier, mapState),
          ),
        ],
      ),
    );
  }

  Widget _buildCulledPinLayer(
    DmToolColors palette,
    WorldMapNotifier notifier,
    WorldMapState mapState,
  ) {
    final viewport = notifier.computeCullViewport();
    bool inside(double x, double y) =>
        x >= viewport.left &&
        x <= viewport.right &&
        y >= viewport.top &&
        y <= viewport.bottom;

    final culledPins =
        notifier.visiblePins.where((p) => inside(p.x, p.y)).toList();
    final culledTimeline =
        notifier.visibleTimelinePins.where((p) => inside(p.x, p.y)).toList();

    return UnboundedStack(
      clipBehavior: Clip.none,
      children: [
        // Timeline connections (dashed lines) — segment-level cull inside
        // the painter so a culled child whose parent is still visible
        // doesn't drop its incoming line.
        if (mapState.showTimeline)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TimelineConnectionPainter(
                  pins: notifier.visibleTimelinePins,
                  viewport: viewport,
                ),
              ),
            ),
          ),

        // Map pins
        ...culledPins.map(
          (pin) => _DraggablePin(
            key: ValueKey('pin_${pin.id}'),
            pin: pin,
            palette: palette,
            notifier: notifier,
            pinSize: mapState.pinSize,
            iconData: _pinIcon(pin, ref),
            onEdit: () => _editPin(pin, notifier, palette),
            onInspect: pin.entityId != null
                ? () => widget.onOpenEntity?.call(pin.entityId!)
                : null,
            onDelete: () => notifier.deletePin(pin.id),
            onCopyToEpoch: mapState.epochs.length > 1
                ? () => _showCopyToEpochDialog(
                      notifier,
                      palette,
                      pinId: pin.id,
                    )
                : null,
          ),
        ),

        // F4: single canvas-level hover overlay for the timeline pin under
        //     cursor. Replaces 100x per-pin MouseRegion+setState fanout.
        ValueListenableBuilder<String?>(
          valueListenable: notifier.hoveredTimelinePinId,
          builder: (_, hoveredId, _) {
            if (hoveredId == null) return const SizedBox.shrink();
            final hovered = culledTimeline
                .where((p) => p.id == hoveredId)
                .firstOrNull;
            if (hovered == null) return const SizedBox.shrink();
            final half = switch (mapState.pinSize) {
              PinSize.small => 9.0,
              PinSize.medium => 11.0,
              PinSize.large => 14.0,
            };
            return Positioned(
              left: hovered.x + half + 6,
              top: hovered.y - half - 4,
              child: IgnorePointer(
                child: _timelineHoverCard(
                  palette,
                  hovered,
                  _entityNameMap(hovered.entityIds),
                ),
              ),
            );
          },
        ),

        // Timeline pins
        ...culledTimeline.map(
          (pin) => _DraggableTimelinePin(
            key: ValueKey('tpin_${pin.id}'),
            pin: pin,
            palette: palette,
            notifier: notifier,
            pinSize: mapState.pinSize,
            isLinkMode: mapState.isLinkMode,
            entityNames: _entityNameMap(pin.entityIds),
            onTap: () {
              if (mapState.isLinkMode) {
                notifier.handleLinkToExisting(pin.id);
              } else {
                _showTimelineEditDialog(pin, notifier, palette);
              }
            },
            onAddConnected: () => _addConnectedTimeline(pin, notifier, palette),
            onLinkNew: () => notifier.startLinkMode(pin.id),
            onEdit: () => _showTimelineEditDialog(pin, notifier, palette),
            onDelete: () => notifier.deleteTimelinePin(pin.id),
            onEntityDrop: (entityId) => _onEntityDropOnTimelinePin(
              context,
              pin,
              entityId,
              notifier,
            ),
            onCopyToEpoch: mapState.epochs.length > 1
                ? () => _showCopyToEpochDialog(
                      notifier,
                      palette,
                      timelinePinId: pin.id,
                    )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMapPlaceholder(DmToolColors palette) {
    return SizedBox(
      width: 800,
      height: 600,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: palette.tabText.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No map image loaded',
              style: TextStyle(
                fontSize: 14,
                color: palette.tabText.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Click "Load Map Image" in the toolbar to get started',
              style: TextStyle(
                fontSize: 11,
                color: palette.tabText.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Entity drop from sidebar
  // -------------------------------------------------------------------------

  void _onEntityDrop(
    BuildContext context,
    DragTargetDetails<String> details,
    WorldMapNotifier notifier,
  ) {
    final entityId = details.data;
    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    if (entity == null) return;

    // Validate: only entities whose category allows 'worldmap'
    final schema = ref.read(worldSchemaProvider);
    final category = schema.categories
        .where((c) => c.slug == entity.categorySlug)
        .firstOrNull;
    if (category == null || !category.allowedInSections.contains('worldmap')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entity.name} (${entity.categorySlug}) is not allowed on the world map',
            ),
          ),
        );
      }
      return;
    }

    // Auto pinType from category slug
    final pinType = _pinTypeFromCategorySlug(entity.categorySlug);

    final box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.offset);
    final canvasPos = notifier.screenToCanvas(localPos);
    notifier.addPin(
      canvasPos,
      entityId: entityId,
      label: entity.name,
      pinType: pinType,
    );
  }

  void _onEntityDropOnTimelinePin(
    BuildContext context,
    TimelinePin pin,
    String entityId,
    WorldMapNotifier notifier,
  ) {
    if (pin.entityIds.contains(entityId)) return;

    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    if (entity == null) return;

    final schema = ref.read(worldSchemaProvider);
    final category = schema.categories
        .where((c) => c.slug == entity.categorySlug)
        .firstOrNull;
    if (category == null || !category.allowedInSections.contains('worldmap')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entity.name} (${entity.categorySlug}) is not allowed on the world map',
            ),
          ),
        );
      }
      return;
    }

    notifier.updateTimelinePin(pin.id, entityIds: [...pin.entityIds, entityId]);
  }

  /// Map category slug → pin type for display/filtering.
  static String _pinTypeFromCategorySlug(String slug) {
    return switch (slug) {
      'npc' => 'npc',
      'monster' => 'monster',
      'player' => 'npc',
      'location' => 'location',
      _ => 'default',
    };
  }

  // -------------------------------------------------------------------------
  // Dialogs / Sheets
  // -------------------------------------------------------------------------

  void _showCanvasContextMenu(
    Offset localPosition,
    Offset globalPosition,
    WorldMapNotifier notifier,
    DmToolColors palette, {
    bool isTimelineMode = false,
  }) {
    final canvasPos = notifier.screenToCanvas(localPosition);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: palette.uiFloatingBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      items: [
        if (isTimelineMode)
          PopupMenuItem(
            value: 'addTimelinePin',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: palette.uiFloatingText,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Timeline Pin',
                  style: TextStyle(color: palette.uiFloatingText, fontSize: 13),
                ),
              ],
            ),
          )
        else ...[
          PopupMenuItem(
            value: 'addPin',
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 16,
                  color: palette.uiFloatingText,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Pin',
                  style: TextStyle(color: palette.uiFloatingText, fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'addFromDb',
            child: Row(
              children: [
                Icon(
                  Icons.dataset_outlined,
                  size: 16,
                  color: palette.uiFloatingText,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add from Database',
                  style: TextStyle(color: palette.uiFloatingText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'addPin':
          _showAddPinDialog(canvasPos, notifier);
        case 'addFromDb':
          _showEntityPickerForMap(canvasPos, notifier);
        case 'addTimelinePin':
          _showTimelineEntryDialog(canvasPos, notifier, palette);
      }
    });
  }

  void _showEntityPickerForMap(
    Offset canvasPos,
    WorldMapNotifier notifier,
  ) async {
    // Only show entities whose categories are allowed on the world map.
    final schema = ref.read(worldSchemaProvider);
    final allowedSlugs = schema.categories
        .where((c) => c.allowedInSections.contains('worldmap'))
        .map((c) => c.slug)
        .toList();

    final result = await showEntitySelectorDialog(
      context: context,
      ref: ref,
      allowedTypes: allowedSlugs.isEmpty ? null : allowedSlugs,
    );
    if (result == null || result.isEmpty) return;

    final entityId = result.first;
    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    if (entity == null) return;

    final pinType = _pinTypeFromCategorySlug(entity.categorySlug);
    notifier.addPin(
      canvasPos,
      entityId: entityId,
      label: entity.name,
      pinType: pinType,
    );
  }

  void _showAddPinDialog(Offset canvasPos, WorldMapNotifier notifier) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final labelCtrl = TextEditingController();
    final labelFocus = FocusNode();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (labelFocus.canRequestFocus) labelFocus.requestFocus();
    });

    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text(
          'Add to Map',
          style: TextStyle(fontSize: 14, color: palette.uiFloatingText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: labelCtrl,
              focusNode: labelFocus,
              style: TextStyle(fontSize: 12, color: palette.uiFloatingText),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: palette.uiFloatingText.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.uiFloatingBorder),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            // Hint about entities
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: palette.uiFloatingText.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'To add entities, right-click the map or drag them from the sidebar.',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.uiFloatingText.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: palette.uiFloatingText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.addPin(canvasPos, label: labelCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Add Pin'),
          ),
        ],
      ),
    ).whenComplete(labelCtrl.dispose);
  }

  /// Build entityId → name map for display in dialogs.
  Map<String, String> _entityNameMap(List<String> entityIds) {
    final entities = ref.read(entityProvider);
    return {for (final eid in entityIds) eid: entities[eid]?.name ?? eid};
  }

  /// Add a connected timeline pin: copies entities + session from parent,
  /// opens the timeline entry dialog pre-filled.
  void _addConnectedTimeline(
    TimelinePin parent,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    final prefilled = TimelinePin(
      id: '',
      x: parent.x + 40,
      y: parent.y + 40,
      day: parent.day,
      note: '',
      entityIds: List<String>.from(parent.entityIds),
      sessionId: parent.sessionId,
      parentIds: [parent.id],
      color: parent.color,
    );
    showDialog<TimelinePin>(
      context: context,
      builder: (ctx) => TimelineEntryDialog(
        palette: palette,
        existing: prefilled,
        entityNames: _entityNameMap(prefilled.entityIds),
      ),
    ).then((result) {
      if (result == null) return;
      notifier.addTimelinePin(
        Offset(parent.x + 40, parent.y + 40),
        day: result.day,
        note: result.note,
        color: result.color,
        entityIds: result.entityIds,
        sessionId: result.sessionId,
        parentId: parent.id,
      );
    });
  }

  void _showTimelineEntryDialog(
    Offset canvasPos,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    showDialog<TimelinePin>(
      context: context,
      builder: (ctx) => TimelineEntryDialog(palette: palette),
    ).then((result) {
      if (result == null) return;
      notifier.addTimelinePin(
        canvasPos,
        day: result.day,
        note: result.note,
        color: result.color,
        entityIds: result.entityIds,
        sessionId: result.sessionId,
      );
    });
  }

  void _showTimelineEditDialog(
    TimelinePin pin,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    showDialog<TimelinePin>(
      context: context,
      builder: (ctx) => TimelineEntryDialog(
        palette: palette,
        existing: pin,
        entityNames: _entityNameMap(pin.entityIds),
      ),
    ).then((result) {
      if (result == null) return;
      notifier.updateTimelinePin(
        pin.id,
        day: result.day,
        note: result.note,
        color: result.color,
        entityIds: result.entityIds,
        sessionId: result.sessionId,
        style: result.style,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Epoch dialogs
  // -------------------------------------------------------------------------

  void _showAddWaypointDialog(
    int insertIndex,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    showDialog<AddWaypointResult>(
      context: context,
      builder: (ctx) => AddWaypointDialog(palette: palette),
    ).then((result) {
      if (result == null) return;
      notifier.addWaypoint(
        insertIndex,
        result.label,
        copyPins: result.copyPins,
        copyTimelinePins: result.copyTimelinePins,
      );
    });
  }

  void _showDeleteWaypointDialog(
    int wpIndex,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    final mapState = ref.read(worldMapProvider);
    final label = mapState.waypoints[wpIndex].label;
    showDialog<EpochMergeStrategy>(
      context: context,
      builder: (ctx) =>
          DeleteWaypointDialog(palette: palette, waypointLabel: label),
    ).then((strategy) {
      if (strategy == null) return;
      notifier.deleteWaypoint(wpIndex, strategy);
    });
  }

  void _showRenameWaypointDialog(
    int wpIndex,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    final mapState = ref.read(worldMapProvider);
    final current = mapState.waypoints[wpIndex].label;
    showDialog<String>(
      context: context,
      builder: (ctx) =>
          RenameWaypointDialog(palette: palette, currentLabel: current),
    ).then((newLabel) {
      if (newLabel == null) return;
      notifier.updateWaypointLabel(wpIndex, newLabel);
    });
  }

  void _showCopyToEpochDialog(
    WorldMapNotifier notifier,
    DmToolColors palette, {
    String? pinId,
    String? timelinePinId,
  }) {
    final mapState = ref.read(worldMapProvider);
    if (mapState.epochs.length <= 1) return;
    showDialog<int>(
      context: context,
      builder: (ctx) => CopyToEpochDialog(
        palette: palette,
        epochNames: notifier.epochNames,
        currentEpochIndex: mapState.activeEpochIndex,
      ),
    ).then((targetIdx) {
      if (targetIdx == null) return;
      if (pinId != null) {
        notifier.copyPinToEpoch(pinId, targetIdx);
      } else if (timelinePinId != null) {
        notifier.copyTimelinePinToEpoch(timelinePinId, targetIdx);
      }
    });
  }

  Future<void> _editPin(
    MapPin pin,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) async {
    final result = await PinEditDialog.show(context, pin, palette);
    if (result == null) return;
    final updated = result.pin;
    if (updated == null) {
      notifier.deletePin(pin.id);
      return;
    }
    notifier.updatePin(
      pin.id,
      label: updated.label,
      note: updated.note,
      color: updated.color,
      style: updated.style,
    );
  }

  void _projectMap(DmToolColors palette) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Project Map: Player window not yet implemented'),
        backgroundColor: palette.tabBg,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draggable map pin (hold-and-drag to move)
// ---------------------------------------------------------------------------

class _DraggablePin extends StatefulWidget {
  final MapPin pin;
  final DmToolColors palette;
  final WorldMapNotifier notifier;
  final VoidCallback onEdit;
  final VoidCallback? onInspect;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyToEpoch;
  final PinSize pinSize;
  final IconData iconData;

  const _DraggablePin({
    super.key,
    required this.pin,
    required this.palette,
    required this.notifier,
    required this.onEdit,
    required this.iconData,
    this.onInspect,
    this.onDelete,
    this.onCopyToEpoch,
    this.pinSize = PinSize.medium,
  });

  @override
  State<_DraggablePin> createState() => _DraggablePinState();
}

class _DraggablePinState extends State<_DraggablePin> {
  Offset? _dragStart;
  Offset? _pinStartPos;
  // Local drag offset — avoids Riverpod rebuilds during drag for smoothness.
  Offset? _dragOffset;

  double get _iconSize => switch (widget.pinSize) {
    PinSize.small => 18,
    PinSize.medium => 24,
    PinSize.large => 32,
  };

  double get _fontSize => switch (widget.pinSize) {
    PinSize.small => 8,
    PinSize.medium => 9,
    PinSize.large => 11,
  };

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final displayColor = pin.color.isNotEmpty
        ? _parseHexColor(pin.color)
        : _pinColor(pin.pinType, widget.palette);

    final x = _dragOffset?.dx ?? pin.x;
    final y = _dragOffset?.dy ?? pin.y;
    final iconSize = _iconSize;
    final label = pin.label.isNotEmpty ? pin.label : pin.pinType;

    return Positioned(
      left: x - iconSize / 2,
      top: y - iconSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap = open context menu (sil/see-card/edit). Same on mobile tap
        // and desktop left-click; detail sheet reachable as menu item.
        onTapUp: (d) => _showContextMenu(context, d.globalPosition),
        onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
        // Touch: hold-and-drag via long-press chain.
        onLongPressStart: (d) {
          _dragStart = d.globalPosition;
          _pinStartPos = Offset(pin.x, pin.y);
        },
        onLongPressMoveUpdate: (d) {
          if (_dragStart == null || _pinStartPos == null) return;
          final scale = widget.notifier.viewTransform.value.scale;
          final delta = (d.globalPosition - _dragStart!) / scale;
          setState(() => _dragOffset = _pinStartPos! + delta);
        },
        onLongPressEnd: (_) => _commitDrag(),
        // Desktop mouse: click-drag without delay.
        onPanStart: (d) {
          _dragStart = d.globalPosition;
          _pinStartPos = Offset(pin.x, pin.y);
        },
        onPanUpdate: (d) {
          if (_dragStart == null || _pinStartPos == null) return;
          final scale = widget.notifier.viewTransform.value.scale;
          final delta = (d.globalPosition - _dragStart!) / scale;
          setState(() => _dragOffset = _pinStartPos! + delta);
        },
        onPanEnd: (_) => _commitDrag(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.iconData,
              size: iconSize,
              color: displayColor,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 3),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _commitDrag() {
    if (_dragOffset != null) {
      widget.notifier.updatePin(widget.pin.id, pos: _dragOffset!);
    }
    _dragStart = null;
    _pinStartPos = null;
    _dragOffset = null;
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final palette = widget.palette;
    final items = <PopupMenuEntry<String>>[];

    if (widget.onInspect != null) {
      items.add(
        PopupMenuItem(
          value: 'inspect',
          child: _menuRow(Icons.open_in_new, 'See Card', palette),
        ),
      );
    }
    items.addAll([
      PopupMenuItem(
        value: 'edit_pin',
        child: _menuRow(Icons.edit, 'Edit Pin', palette),
      ),
      if (widget.onCopyToEpoch != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy_to_epoch',
          child: _menuRow(Icons.copy, 'Copy to Epoch...', palette),
        ),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(Icons.delete_outline, 'Delete', palette, danger: true),
      ),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      color: palette.uiFloatingBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      items: items,
    ).then((value) {
      switch (value) {
        case 'inspect':
          widget.onInspect?.call();
        case 'edit_pin':
          widget.onEdit();
        case 'copy_to_epoch':
          widget.onCopyToEpoch?.call();
        case 'delete':
          widget.onDelete?.call();
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Draggable timeline pin (hold-and-drag to move)
// ---------------------------------------------------------------------------

class _DraggableTimelinePin extends StatefulWidget {
  final TimelinePin pin;
  final DmToolColors palette;
  final WorldMapNotifier notifier;
  final bool isLinkMode;
  final VoidCallback onTap;
  final VoidCallback? onAddConnected;
  final VoidCallback? onLinkNew;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(String entityId)? onEntityDrop;
  final Map<String, String> entityNames;
  final VoidCallback? onCopyToEpoch;
  final PinSize pinSize;

  const _DraggableTimelinePin({
    super.key,
    required this.pin,
    required this.palette,
    required this.notifier,
    required this.onTap,
    this.isLinkMode = false,
    this.onAddConnected,
    this.onLinkNew,
    this.onEdit,
    this.onDelete,
    this.onEntityDrop,
    this.onCopyToEpoch,
    this.entityNames = const {},
    this.pinSize = PinSize.medium,
  });

  @override
  State<_DraggableTimelinePin> createState() => _DraggableTimelinePinState();
}

class _DraggableTimelinePinState extends State<_DraggableTimelinePin> {
  Offset? _dragStart;
  Offset? _pinStartPos;
  Offset? _dragOffset;
  bool _isDragOver = false;

  // F4: hover state moved to WorldMapNotifier.hoveredTimelinePinId. This
  // widget only WRITES on enter/exit; canvas-level VLB does the card render.
  void _setHovered(bool hovered) {
    final n = widget.notifier.hoveredTimelinePinId;
    if (hovered) {
      if (n.value != widget.pin.id) n.value = widget.pin.id;
    } else if (n.value == widget.pin.id) {
      n.value = null;
    }
  }

  // Timeline pins are one step smaller than map pins
  double get _boxSize => switch (widget.pinSize) {
    PinSize.small => 18,
    PinSize.medium => 22,
    PinSize.large => 28,
  };

  double get _fontSize => switch (widget.pinSize) {
    PinSize.small => 7,
    PinSize.medium => 9,
    PinSize.large => 11,
  };

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final color = _parseHexColor(pin.color);

    final x = _dragOffset?.dx ?? pin.x;
    final y = _dragOffset?.dy ?? pin.y;
    final size = _boxSize;
    final half = size / 2;

    final isDragging = _dragOffset != null;

    final iconOverride = pin.style['icon'];
    final hasIcon = iconOverride is String && iconOverride.isNotEmpty;
    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: widget.palette.br,
        border: Border.all(
          color: _isDragOver
              ? Colors.yellowAccent
              : pin.sessionId != null
              ? Colors.white
              : Colors.black54,
          width: _isDragOver ? 3 : 1.5,
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      alignment: Alignment.center,
      child: hasIcon
          ? Icon(
              _iconFromName(iconOverride),
              size: size * 0.6,
              color: Colors.white,
            )
          : Text(
              '${pin.day}',
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );

    return Positioned(
      left: x - half,
      top: y - half,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DragTarget<String>(
              onWillAcceptWithDetails: (_) => widget.onEntityDrop != null,
              onAcceptWithDetails: (details) {
                setState(() => _isDragOver = false);
                widget.onEntityDrop?.call(details.data);
              },
              onMove: (_) {
                if (!_isDragOver) setState(() => _isDragOver = true);
              },
              onLeave: (_) {
                if (_isDragOver) setState(() => _isDragOver = false);
              },
              builder: (context, candidateData, _) {
                return MouseRegion(
                  onEnter: (_) {
                    if (!isDragging) _setHovered(true);
                  },
                  onExit: (_) => _setHovered(false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Tap = context menu (sil/edit/see card). Link mode'da
                    // tap eski davranışı (link bağla) korur.
                    onTapUp: (d) {
                      if (widget.isLinkMode) {
                        widget.onTap();
                      } else {
                        _showContextMenu(context, d.globalPosition);
                      }
                    },
                    onSecondaryTapUp: (d) =>
                        _showContextMenu(context, d.globalPosition),
                    // Touch: hold-and-drag via long-press chain.
                    onLongPressStart: (d) {
                      _dragStart = d.globalPosition;
                      _pinStartPos = Offset(pin.x, pin.y);
                      _setHovered(false);
                    },
                    onLongPressMoveUpdate: (d) {
                      if (_dragStart == null || _pinStartPos == null) return;
                      final scale = widget.notifier.viewTransform.value.scale;
                      final delta = (d.globalPosition - _dragStart!) / scale;
                      setState(() => _dragOffset = _pinStartPos! + delta);
                    },
                    onLongPressEnd: (_) => _commitDrag(),
                    // Desktop mouse: hızlı tıkla-sürükle aynı pan handler'la.
                    onPanStart: (d) {
                      _dragStart = d.globalPosition;
                      _pinStartPos = Offset(pin.x, pin.y);
                      _setHovered(false);
                    },
                    onPanUpdate: (d) {
                      if (_dragStart == null || _pinStartPos == null) return;
                      final scale = widget.notifier.viewTransform.value.scale;
                      final delta = (d.globalPosition - _dragStart!) / scale;
                      setState(() => _dragOffset = _pinStartPos! + delta);
                    },
                    onPanEnd: (_) => _commitDrag(),
                    child: container,
                  ),
                );
              },
            ),
            // Hover card moved to canvas level (F4) — see
            // _buildTimelineHoverOverlay.
          ],
        ),
      ),
    );
  }

  void _commitDrag() {
    if (_dragOffset != null) {
      widget.notifier.updateTimelinePin(widget.pin.id, pos: _dragOffset!);
    }
    _dragStart = null;
    _pinStartPos = null;
    _dragOffset = null;
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final palette = widget.palette;
    final pin = widget.pin;
    final items = <PopupMenuEntry<String>>[];

    if (pin.sessionId != null) {
      items.add(
        PopupMenuItem(
          value: 'goto_session',
          child: _menuRow(Icons.event, 'Go to Session', palette),
        ),
      );
      items.add(const PopupMenuDivider());
    }

    items.addAll([
      PopupMenuItem(
        value: 'add_connected',
        child: _menuRow(Icons.add_link, 'Add Connected Timeline', palette),
      ),
      PopupMenuItem(
        value: 'link_existing',
        child: _menuRow(Icons.link, 'Link Existing', palette),
      ),
      PopupMenuItem(
        value: 'edit',
        child: _menuRow(Icons.edit, 'Edit', palette),
      ),
      if (widget.onCopyToEpoch != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy_to_epoch',
          child: _menuRow(Icons.copy, 'Copy to Epoch...', palette),
        ),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(Icons.delete_outline, 'Delete', palette, danger: true),
      ),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      color: palette.uiFloatingBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      items: items,
    ).then((value) {
      switch (value) {
        case 'add_connected':
          widget.onAddConnected?.call();
        case 'link_existing':
          widget.onLinkNew?.call();
        case 'edit':
          widget.onEdit?.call();
        case 'copy_to_epoch':
          widget.onCopyToEpoch?.call();
        case 'delete':
          widget.onDelete?.call();
      }
    });
  }
}

// F4: top-level builder shared by canvas-level hover overlay.
Widget _timelineHoverCard(
  DmToolColors palette,
  TimelinePin pin,
  Map<String, String> entityNames,
) {
  final hasNote = pin.note.isNotEmpty;
  final hasEntities = entityNames.isNotEmpty;
  final hasSession = pin.sessionId != null;

  return Container(
    constraints: const BoxConstraints(maxWidth: 200),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: palette.uiFloatingBg,
      border: Border.all(color: palette.uiFloatingBorder),
      borderRadius: palette.cbr,
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(1, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Day ${pin.day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: palette.uiFloatingText,
          ),
        ),
        if (hasNote) ...[
          const SizedBox(height: 3),
          Text(
            pin.note,
            style: TextStyle(
              fontSize: 10,
              color: palette.uiFloatingText.withValues(alpha: 0.8),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (hasEntities) ...[
          const SizedBox(height: 4),
          ...entityNames.values.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    size: 10,
                    color: palette.uiFloatingText.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.uiFloatingText.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (hasSession) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event,
                size: 10,
                color: palette.uiFloatingText.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 3),
              Text(
                'Session linked',
                style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: palette.uiFloatingText.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _menuRow(
  IconData icon,
  String label,
  DmToolColors palette, {
  bool danger = false,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 16,
        color: danger ? Colors.red[300] : palette.uiFloatingText,
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: danger ? Colors.red[300] : palette.uiFloatingText,
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Timeline connection painter (dashed lines)
// ---------------------------------------------------------------------------

class _TimelineConnectionPainter extends CustomPainter {
  final List<TimelinePin> pins;
  final Rect? viewport;
  late final Map<String, TimelinePin> _pinMap = {
    for (final p in pins) p.id: p,
  };
  late final int _fingerprint = _computeFingerprint(pins);

  // Cache the per-color stroke Paint. withValues allocates on every call;
  // memoizing here avoids one allocation per dashed line.
  // M2: tavanlı — uzun oturumda farklı pin renkleri Paint birikimi yapmasın.
  static final Map<int, Paint> _paintCache = <int, Paint>{};
  static const int _paintCacheCap = 256;

  // Cache the dashed Path geometry per segment key. Key encodes endpoints;
  // flips when a parent or child pin moves. Bounded — drag spam can churn it.
  static final Map<String, Path> _dashedPathCache = <String, Path>{};
  static const int _dashedPathCacheCap = 512;

  static const double _dashLen = 8.0;
  static const double _gapLen = 4.0;

  _TimelineConnectionPainter({required this.pins, this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    if (pins.isEmpty) return;

    final vp = viewport;
    for (final pin in pins) {
      if (pin.parentIds.isEmpty) continue;
      for (final parentId in pin.parentIds) {
        final parent = _pinMap[parentId];
        if (parent == null) continue;

        // F3: segment-level cull. inflate(8) covers stroke width.
        if (vp != null) {
          final segRect = Rect.fromPoints(
            Offset(parent.x, parent.y),
            Offset(pin.x, pin.y),
          ).inflate(8);
          if (!vp.overlaps(segRect)) continue;
        }

        final color = _parseHexColor(pin.color);
        final paint = _paintFor(color);
        final segKey =
            '${parent.x.toStringAsFixed(2)},${parent.y.toStringAsFixed(2)}->'
            '${pin.x.toStringAsFixed(2)},${pin.y.toStringAsFixed(2)}';
        final dashedPath = _dashedPathCache.putIfAbsent(segKey, () {
          if (_dashedPathCache.length >= _dashedPathCacheCap) {
            _dashedPathCache.clear();
          }
          return _buildDashedPath(
            Offset(parent.x, parent.y),
            Offset(pin.x, pin.y),
          );
        });
        canvas.drawPath(dashedPath, paint);
      }
    }
  }

  static Paint _paintFor(Color color) {
    final faded = color.withValues(alpha: 0.7);
    return _paintCache.putIfAbsent(
      faded.toARGB32(),
      () {
        if (_paintCache.length >= _paintCacheCap) _paintCache.clear();
        return Paint()
          ..color = faded
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
      },
    );
  }

  static Path _buildDashedPath(Offset start, Offset end) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segLen = math.min(
          draw ? _dashLen : _gapLen,
          metric.length - distance,
        );
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, distance + segLen),
            Offset.zero,
          );
        }
        distance += segLen;
        draw = !draw;
      }
    }
    return dashedPath;
  }

  // Cheap content fingerprint over fields that influence the drawn output.
  // Parent list joined into the hash so re-parenting invalidates.
  static int _computeFingerprint(List<TimelinePin> pins) {
    var h = pins.length;
    for (final p in pins) {
      h = Object.hash(h, p.id, p.x, p.y, p.color, Object.hashAll(p.parentIds));
    }
    return h;
  }

  @override
  bool shouldRepaint(covariant _TimelineConnectionPainter old) {
    return old._fingerprint != _fingerprint || old.viewport != viewport;
  }
}

// ---------------------------------------------------------------------------
// Toolbar helpers
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final DmToolColors palette;
  final VoidCallback onTap;
  final bool highlight;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: highlight
            ? BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: highlight ? Colors.red[300] : palette.tabText,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: highlight ? Colors.red[300] : palette.tabText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final DmToolColors palette;
  final ValueChanged<bool?> onChanged;

  const _ToolbarCheckbox({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: palette.tabText.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: palette.tabText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinCategoryDropdown extends StatelessWidget {
  final DmToolColors palette;
  final Set<String> hiddenPinTypes;
  final void Function(String) onToggle;

  static const _pinTypes = ['npc', 'monster', 'location', 'event', 'default'];

  const _PinCategoryDropdown({
    required this.palette,
    required this.hiddenPinTypes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = _pinTypes
        .where((t) => !hiddenPinTypes.contains(t))
        .length;

    return PopupMenuButton<String>(
      tooltip: 'Pin categories',
      offset: const Offset(0, 36),
      color: palette.uiFloatingBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      onSelected: onToggle,
      itemBuilder: (_) => _pinTypes.map((type) {
        final visible = !hiddenPinTypes.contains(type);
        return PopupMenuItem<String>(
          value: type,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 32,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: visible,
                  onChanged: (_) {},
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: palette.uiFloatingText.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _pinColor(type, palette),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                type[0].toUpperCase() + type.substring(1),
                style: TextStyle(fontSize: 11, color: palette.uiFloatingText),
              ),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category, size: 14, color: palette.tabText),
            const SizedBox(width: 4),
            Text(
              'Categories ($visibleCount/${_pinTypes.length})',
              style: TextStyle(fontSize: 10, color: palette.tabText),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: palette.tabText),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _pinColor(String pinType, DmToolColors palette) {
  return switch (pinType) {
    'npc' => palette.pinNpc,
    'monster' => palette.pinMonster,
    'location' => palette.pinLocation,
    'player' => palette.pinPlayer,
    _ => palette.pinDefault,
  };
}

/// Map builtin EntityCategorySchema.icon string (Material icon name) → IconData.
/// Covers every builtin category icon plus a few extras for hand-picked pin
/// types. Unknown names fall back to a generic location pin.
IconData _iconFromName(String name) {
  return switch (name) {
    // Builtin EntityCategorySchema icons
    'workspaces' => Icons.workspaces,
    'fork_right' => Icons.fork_right,
    'diversity_3' => Icons.diversity_3,
    'history_edu' => Icons.history_edu,
    'stars' => Icons.stars,
    'auto_awesome' => Icons.auto_awesome,
    'colorize' => Icons.colorize,
    'shield' => Icons.shield,
    'build' => Icons.build,
    'inventory_2' => Icons.inventory_2,
    'album' => Icons.album,
    'backpack' => Icons.backpack,
    'pets' => Icons.pets,
    'directions_boat' => Icons.directions_boat,
    'diamond' => Icons.diamond,
    'auto_fix_high' => Icons.auto_fix_high,
    'coronavirus' => Icons.colorize, // monster builtin → kılıç silüetine yakın
    // Builtin default_* category icon strings
    'default_npc' => Icons.person_pin,
    'default_monster' => Icons.colorize,
    'default_player' => Icons.person,
    'default_spell' => Icons.auto_awesome,
    'default_equipment' => Icons.backpack,
    'default_class' => Icons.shield,
    'default_race' => Icons.diversity_3,
    'default_location' => Icons.location_on,
    'default_quest' => Icons.flag,
    'default_lore' => Icons.history_edu,
    'default_status-effect' => Icons.flash_on,
    'default_feat' => Icons.stars,
    'default_background' => Icons.album,
    'default_plane' => Icons.workspaces,
    'default_condition' => Icons.cruelty_free,
    'default_trait' => Icons.fork_right,
    'default_action' => Icons.flash_on,
    'default_reaction' => Icons.fork_right,
    'default_legendary-action' => Icons.auto_fix_high,
    'flash_on' => Icons.flash_on,
    'cruelty_free' => Icons.cruelty_free,
    // Common alternates a custom category might pick
    'person' => Icons.person,
    'person_pin' => Icons.person_pin,
    'location_on' => Icons.location_on,
    'location_city' => Icons.location_city,
    'event' => Icons.event,
    'castle' => Icons.castle,
    'forest' => Icons.forest,
    'home' => Icons.home,
    'map' => Icons.map,
    'flag' => Icons.flag,
    _ => Icons.location_pin,
  };
}

/// Pin icon resolved from the linked entity's category icon when present;
/// falls back to a pinType-keyed default for entity-less manual pins.
IconData _pinIcon(MapPin pin, WidgetRef ref) {
  final override = pin.style['icon'];
  if (override is String && override.isNotEmpty) {
    return _iconFromName(override);
  }
  final entityId = pin.entityId;
  if (entityId != null) {
    final entity = ref.read(entityProvider)[entityId];
    if (entity != null) {
      final schema = ref.read(worldSchemaProvider);
      final cat = schema.categories
          .where((c) => c.slug == entity.categorySlug)
          .firstOrNull;
      if (cat != null && cat.icon.isNotEmpty) {
        return _iconFromName(cat.icon);
      }
    }
  }
  return switch (pin.pinType) {
    'npc' => Icons.person_pin,
    'monster' => Icons.colorize,
    'location' => Icons.location_on,
    'event' => Icons.event,
    'player' => Icons.person,
    _ => Icons.location_pin,
  };
}

final Map<String, Color> _hexColorCache = <String, Color>{};

Color _parseHexColor(String hex) {
  return _hexColorCache.putIfAbsent(
    hex,
    () => Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16)),
  );
}

class _VertDiv extends StatelessWidget {
  final DmToolColors palette;
  const _VertDiv({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: VerticalDivider(width: 1, color: palette.sidebarDivider),
    );
  }
}
