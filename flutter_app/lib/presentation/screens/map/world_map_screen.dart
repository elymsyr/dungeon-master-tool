import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/save_state_provider.dart';
import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';
import 'epoch_scroll_bar.dart';
import 'epoch_waypoint_dialog.dart';
import 'timeline_entry_dialog.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final mapData = Map<String, dynamic>.from(
      data['map_data'] as Map? ?? {},
    );
    ref.read(worldMapProvider.notifier).init(mapData);
  }

  @override
  void deactivate() {
    // ref `dispose()` içinde geçersiz olur — sync'i widget tree'den
    // çıkarken (`deactivate`) yap.
    try {
      ref.read(worldMapProvider.notifier).syncToCampaignData();
      ref.read(saveStateProvider.notifier).markDirty();
    } catch (_) {
      // best-effort: widget hayatı boyunca container kapanmış olabilir
    }
    super.deactivate();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(worldMapProvider.notifier);
    final mapState = ref.watch(worldMapProvider);

    return Column(
      children: [
        _buildToolbar(palette, notifier, mapState),
        Expanded(
          child: Stack(
            children: [
              _buildCanvas(palette, notifier, mapState),
              if (mapState.epochs.length > 1)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: EpochScrollBar(
                    epochs: mapState.epochs,
                    waypoints: mapState.waypoints,
                    activeEpochIndex: mapState.activeEpochIndex,
                    epochNames: notifier.epochNames,
                    palette: palette,
                    startLabel: mapState.epochStartLabel,
                    endLabel: mapState.epochEndLabel,
                    onSwitchEpoch: notifier.switchEpoch,
                    onAddWaypoint: (insertIdx) =>
                        _showAddWaypointDialog(insertIdx, notifier, palette),
                    onDeleteWaypoint: (wpIdx) =>
                        _showDeleteWaypointDialog(wpIdx, notifier, palette),
                    onRenameWaypoint: (wpIdx) =>
                        _showRenameWaypointDialog(wpIdx, notifier, palette),
                    onRenameBoundary: (s, e) =>
                        notifier.updateEpochBoundaryLabels(
                            startLabel: s, endLabel: e),
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
        (t) => mapState.hiddenPinTypes.contains(t));

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

          // Non-player timeline (only when timeline visible)
          if (mapState.showTimeline)
            _ToolbarCheckbox(
              label: 'All Timeline',
              value: mapState.showNonPlayerTimeline,
              palette: palette,
              onChanged: (_) => notifier.toggleNonPlayerTimeline(),
            ),

          _VertDiv(palette: palette),

          // Entity filter
          _ToolbarButton(
            icon: Icons.filter_list,
            label: mapState.activeEntityFilters.isEmpty
                ? 'Filter'
                : 'Filter (${mapState.activeEntityFilters.length})',
            palette: palette,
            highlight: mapState.activeEntityFilters.isNotEmpty,
            onTap: () => _showEntityFilterDialog(notifier, palette),
          ),
          if (mapState.activeEntityFilters.isNotEmpty)
            InkWell(
              key: const ValueKey('clear_filter'),
              onTap: notifier.clearEntityFilter,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Icon(Icons.filter_list_off, size: 14,
                    color: Colors.red[300]),
              ),
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
                mapState.activeEpochIndex, notifier, palette),
          ),

          // Status text
          if (mapState.isLinkMode)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Click pin to link · Click empty to create · Esc to cancel',
                style: TextStyle(fontSize: 10, color: Colors.amber.withValues(alpha: 0.8))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Double-click to place pin · Drag to pan · Scroll to zoom',
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

    return KeyboardListener(
      focusNode: FocusNode(),
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
                  notifier.zoomAtPoint(event.localPosition, event.scrollDelta.dy);
                }
              },
              child: GestureDetector(
                onScaleStart: notifier.onScaleStart,
                onScaleUpdate: notifier.onScaleUpdate,
                onScaleEnd: (_) => notifier.onScaleEnd(),
                onTapUp: inLinkMode
                    ? (d) => _handleCanvasTap(d.localPosition, notifier, mapState)
                    : null,
                onDoubleTapDown: (details) {
                  final canvasPos = notifier.screenToCanvas(details.localPosition);
                  if (mapState.showTimeline) {
                    _showTimelineEntryDialog(canvasPos, notifier, palette);
                  } else {
                    _showAddPinDialog(canvasPos, notifier);
                  }
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
  }

  void _handleCanvasTap(
      Offset localPos, WorldMapNotifier notifier, WorldMapState mapState) {
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
    return ValueListenableBuilder<WorldMapViewTransform>(
      valueListenable: notifier.viewTransform,
      builder: (context, vt, _) {
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(vt.panOffset.dx, vt.panOffset.dy, 0, 1)
            ..scaleByDouble(vt.scale, vt.scale, 1, 1),
          alignment: Alignment.topLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background image
              if (mapState.imagePath.isNotEmpty &&
                  File(mapState.imagePath).existsSync())
                Image.file(
                  File(mapState.imagePath),
                  fit: BoxFit.none,
                  alignment: Alignment.topLeft,
                )
              else
                _buildEmptyMapPlaceholder(palette),

              // Timeline connections (dashed lines)
              if (mapState.showTimeline)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _TimelineConnectionPainter(
                        pins: notifier.visibleTimelinePins,
                      ),
                    ),
                  ),
                ),

              // Map pins
              ...notifier.visiblePins.map(
                (pin) => _DraggablePin(
                  key: ValueKey('pin_${pin.id}'),
                  pin: pin,
                  palette: palette,
                  notifier: notifier,
                  pinSize: mapState.pinSize,
                  onTap: () => _showPinDetail(context, pin, notifier, palette),
                  onInspect: pin.entityId != null
                      ? () => widget.onOpenEntity?.call(pin.entityId!)
                      : null,
                  onEditNote: () => _showEditPinNoteDialog(pin, notifier, palette),
                  onChangeColor: () => _showPinColorPicker(pin, notifier, palette),
                  onDelete: () => notifier.deletePin(pin.id),
                  onCopyToEpoch: mapState.epochs.length > 1
                      ? () => _showCopyToEpochDialog(
                          notifier, palette, pinId: pin.id)
                      : null,
                ),
              ),

              // Timeline pins
              ...notifier.visibleTimelinePins.map(
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
                  onAddConnected: () =>
                      _addConnectedTimeline(pin, notifier, palette),
                  onLinkNew: () => notifier.startLinkMode(pin.id),
                  onEdit: () => _showTimelineEditDialog(pin, notifier, palette),
                  onChangeColor: () =>
                      _showTimelineColorPicker(pin, notifier, palette),
                  onDelete: () => notifier.deleteTimelinePin(pin.id),
                  onEntityDrop: (entityId) =>
                      _onEntityDropOnTimelinePin(context, pin, entityId, notifier),
                  onCopyToEpoch: mapState.epochs.length > 1
                      ? () => _showCopyToEpochDialog(
                          notifier, palette, timelinePinId: pin.id)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
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
    if (category == null ||
        !category.allowedInSections.contains('worldmap')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${entity.name} (${entity.categorySlug}) is not allowed on the world map'),
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
    notifier.addPin(canvasPos,
        entityId: entityId, label: entity.name, pinType: pinType);
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
    if (category == null ||
        !category.allowedInSections.contains('worldmap')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${entity.name} (${entity.categorySlug}) is not allowed on the world map'),
          ),
        );
      }
      return;
    }

    notifier.updateTimelinePin(
      pin.id,
      entityIds: [...pin.entityIds, entityId],
    );
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

  void _showAddPinDialog(Offset canvasPos, WorldMapNotifier notifier) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final labelCtrl = TextEditingController();

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
              autofocus: true,
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
                Icon(Icons.info_outline, size: 14,
                    color: palette.uiFloatingText.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'To add entities, drag them from the sidebar.',
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
            child: Text('Cancel',
                style: TextStyle(color: palette.uiFloatingText)),
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
    );
  }

  /// Build entityId → name map for display in dialogs.
  Map<String, String> _entityNameMap(List<String> entityIds) {
    final entities = ref.read(entityProvider);
    return {
      for (final eid in entityIds)
        eid: entities[eid]?.name ?? eid,
    };
  }

  /// Add a connected timeline pin: copies entities + session from parent,
  /// opens the timeline entry dialog pre-filled.
  void _addConnectedTimeline(
      TimelinePin parent, WorldMapNotifier notifier, DmToolColors palette) {
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
      Offset canvasPos, WorldMapNotifier notifier, DmToolColors palette) {
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
      TimelinePin pin, WorldMapNotifier notifier, DmToolColors palette) {
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
      );
    });
  }

  // -------------------------------------------------------------------------
  // Epoch dialogs
  // -------------------------------------------------------------------------

  void _showAddWaypointDialog(
      int insertIndex, WorldMapNotifier notifier, DmToolColors palette) {
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
      int wpIndex, WorldMapNotifier notifier, DmToolColors palette) {
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
      int wpIndex, WorldMapNotifier notifier, DmToolColors palette) {
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

  void _showPinDetail(
    BuildContext context,
    MapPin pin,
    WorldMapNotifier notifier,
    DmToolColors palette,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.uiFloatingBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _PinDetailSheet(
        pin: pin,
        palette: palette,
        notifier: notifier,
      ),
    );
  }

  void _showEditPinNoteDialog(
      MapPin pin, WorldMapNotifier notifier, DmToolColors palette) {
    final ctrl = TextEditingController(text: pin.note);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Edit Note',
            style: TextStyle(fontSize: 14, color: palette.uiFloatingText)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: TextStyle(fontSize: 12, color: palette.uiFloatingText),
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderSide: BorderSide(color: palette.uiFloatingBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: palette.uiFloatingText)),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.updatePinNote(pin.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPinColorPicker(
      MapPin pin, WorldMapNotifier notifier, DmToolColors palette) {
    const colors = [
      '#42a5f5', '#ef5350', '#66bb6a', '#ffa726', '#ab47bc',
      '#26c6da', '#ec407a', '#8d6e63', '#78909c', '#ffee58',
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Pick Color',
            style: TextStyle(fontSize: 14, color: palette.uiFloatingText)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((hex) {
            final c =
                Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));
            return GestureDetector(
              onTap: () {
                notifier.updatePinColor(pin.id, hex);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: pin.color == hex
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTimelineColorPicker(
      TimelinePin pin, WorldMapNotifier notifier, DmToolColors palette) {
    const colors = [
      '#42a5f5', '#ef5350', '#66bb6a', '#ffa726', '#ab47bc',
      '#26c6da', '#ec407a', '#8d6e63', '#78909c', '#ffee58',
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Pick Color (chain)',
            style: TextStyle(fontSize: 14, color: palette.uiFloatingText)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((hex) {
            final c =
                Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));
            return GestureDetector(
              onTap: () {
                notifier.updateTimelineChainColor(pin.id, hex);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: pin.color == hex
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEntityFilterDialog(
      WorldMapNotifier notifier, DmToolColors palette) {
    // Only show entities whose category allows 'worldmap'
    final allEntities = ref.read(entityProvider);
    final schema = ref.read(worldSchemaProvider);
    final allowedSlugs = schema.categories
        .where((c) => c.allowedInSections.contains('worldmap'))
        .map((c) => c.slug)
        .toSet();
    final entities = Map.fromEntries(allEntities.entries
        .where((e) => allowedSlugs.contains(e.value.categorySlug)));
    if (entities.isEmpty) return;

    final mapState = ref.read(worldMapProvider);
    final selected = Set<String>.from(mapState.activeEntityFilters);

    showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: palette.uiFloatingBg,
          title: Text('Filter by Entity',
              style: TextStyle(
                  fontSize: 14, color: palette.uiFloatingText)),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView(
              children: entities.entries.map((e) {
                final isChecked = selected.contains(e.key);
                return CheckboxListTile(
                  dense: true,
                  title: Text(e.value.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: palette.uiFloatingText)),
                  value: isChecked,
                  onChanged: (v) {
                    setDlgState(() {
                      if (v == true) {
                        selected.add(e.key);
                      } else {
                        selected.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: palette.uiFloatingText)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result != null) {
        notifier.setEntityFilter(result);
      }
    });
  }

  void _projectMap(DmToolColors palette) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project Map: Player window not yet implemented'),
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
  final VoidCallback onTap;
  final VoidCallback? onInspect;
  final VoidCallback? onEditNote;
  final VoidCallback? onChangeColor;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyToEpoch;
  final PinSize pinSize;

  const _DraggablePin({
    super.key,
    required this.pin,
    required this.palette,
    required this.notifier,
    required this.onTap,
    this.onInspect,
    this.onEditNote,
    this.onChangeColor,
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
        ? Color(int.parse(pin.color.replaceAll('#', 'FF'), radix: 16))
        : _pinColor(pin.pinType);

    final x = _dragOffset?.dx ?? pin.x;
    final y = _dragOffset?.dy ?? pin.y;
    final iconSize = _iconSize;
    final label = pin.label.isNotEmpty ? pin.label : pin.pinType;

    return Positioned(
      left: x - iconSize / 2,
      top: y - iconSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTapUp: (d) =>
            _showContextMenu(context, d.globalPosition),
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
        onPanEnd: (_) {
          if (_dragOffset != null) {
            widget.notifier.updatePin(pin.id, pos: _dragOffset!);
          }
          _dragStart = null;
          _pinStartPos = null;
          _dragOffset = null;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_pin,
              size: iconSize,
              color: displayColor,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
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

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final palette = widget.palette;
    final items = <PopupMenuEntry<String>>[];

    if (widget.onInspect != null) {
      items.add(PopupMenuItem(
        value: 'inspect',
        child: _menuRow(Icons.open_in_new, 'Inspect Entity', palette),
      ));
    }
    items.addAll([
      PopupMenuItem(
        value: 'edit_note',
        child: _menuRow(Icons.edit_note, 'Edit Note', palette),
      ),
      PopupMenuItem(
        value: 'change_color',
        child: _menuRow(Icons.palette, 'Change Color', palette),
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
        child:
            _menuRow(Icons.delete_outline, 'Delete', palette, danger: true),
      ),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: palette.uiFloatingBg,
      items: items,
    ).then((value) {
      switch (value) {
        case 'inspect':
          widget.onInspect?.call();
        case 'edit_note':
          widget.onEditNote?.call();
        case 'change_color':
          widget.onChangeColor?.call();
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
  final VoidCallback? onChangeColor;
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
    this.onChangeColor,
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
  bool _isHovered = false;

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
    final palette = widget.palette;
    final color =
        Color(int.parse(pin.color.replaceAll('#', 'FF'), radix: 16));

    final x = _dragOffset?.dx ?? pin.x;
    final y = _dragOffset?.dy ?? pin.y;
    final size = _boxSize;
    final half = size / 2;

    final isDragging = _dragOffset != null;

    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: _isDragOver
              ? Colors.yellowAccent
              : pin.sessionId != null
                  ? Colors.white
                  : Colors.black54,
          width: _isDragOver ? 3 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
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
                    if (!isDragging) setState(() => _isHovered = true);
                  },
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    onSecondaryTapUp: (d) =>
                        _showContextMenu(context, d.globalPosition),
                    onPanStart: (d) {
                      _dragStart = d.globalPosition;
                      _pinStartPos = Offset(pin.x, pin.y);
                      setState(() => _isHovered = false);
                    },
                    onPanUpdate: (d) {
                      if (_dragStart == null || _pinStartPos == null) return;
                      final scale =
                          widget.notifier.viewTransform.value.scale;
                      final delta = (d.globalPosition - _dragStart!) / scale;
                      setState(() => _dragOffset = _pinStartPos! + delta);
                    },
                    onPanEnd: (_) {
                      if (_dragOffset != null) {
                        widget.notifier.updateTimelinePin(pin.id,
                            pos: _dragOffset!);
                      }
                      _dragStart = null;
                      _pinStartPos = null;
                      _dragOffset = null;
                    },
                    child: container,
                  ),
                );
              },
            ),
            // Hover card — outside DragTarget so it doesn't affect layout
            if (_isHovered && !isDragging)
              Positioned(
                left: size + 6,
                top: -4,
                child: IgnorePointer(
                  child: _buildHoverCard(palette, pin),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoverCard(DmToolColors palette, TimelinePin pin) {
    final hasNote = pin.note.isNotEmpty;
    final hasEntities = widget.entityNames.isNotEmpty;
    final hasSession = pin.sessionId != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.uiFloatingBg,
        border: Border.all(color: palette.uiFloatingBorder),
        borderRadius: BorderRadius.circular(4),
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
            ...widget.entityNames.values.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 10,
                        color: palette.uiFloatingText.withValues(alpha: 0.5)),
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
                Icon(Icons.event, size: 10,
                    color: palette.uiFloatingText.withValues(alpha: 0.5)),
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

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final palette = widget.palette;
    final pin = widget.pin;
    final items = <PopupMenuEntry<String>>[];

    if (pin.sessionId != null) {
      items.add(PopupMenuItem(
        value: 'goto_session',
        child: _menuRow(Icons.event, 'Go to Session', palette),
      ));
      items.add(const PopupMenuDivider());
    }

    items.addAll([
      PopupMenuItem(
        value: 'add_connected',
        child: _menuRow(
            Icons.add_link, 'Add Connected Timeline', palette),
      ),
      PopupMenuItem(
        value: 'link_existing',
        child: _menuRow(Icons.link, 'Link Existing', palette),
      ),
      PopupMenuItem(
        value: 'edit',
        child: _menuRow(Icons.edit, 'Edit', palette),
      ),
      PopupMenuItem(
        value: 'change_color',
        child:
            _menuRow(Icons.palette, 'Change Color (chain)', palette),
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
        child:
            _menuRow(Icons.delete_outline, 'Delete', palette, danger: true),
      ),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: palette.uiFloatingBg,
      items: items,
    ).then((value) {
      switch (value) {
        case 'add_connected':
          widget.onAddConnected?.call();
        case 'link_existing':
          widget.onLinkNew?.call();
        case 'edit':
          widget.onEdit?.call();
        case 'change_color':
          widget.onChangeColor?.call();
        case 'copy_to_epoch':
          widget.onCopyToEpoch?.call();
        case 'delete':
          widget.onDelete?.call();
      }
    });
  }
}

Widget _menuRow(IconData icon, String label, DmToolColors palette,
    {bool danger = false}) {
  return Row(
    children: [
      Icon(icon,
          size: 16,
          color: danger ? Colors.red[300] : palette.uiFloatingText),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: danger ? Colors.red[300] : palette.uiFloatingText)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Timeline connection painter (dashed lines)
// ---------------------------------------------------------------------------

class _TimelineConnectionPainter extends CustomPainter {
  final List<TimelinePin> pins;

  _TimelineConnectionPainter({required this.pins});

  @override
  void paint(Canvas canvas, Size size) {
    if (pins.isEmpty) return;
    final pinMap = {for (final p in pins) p.id: p};

    for (final pin in pins) {
      for (final parentId in pin.parentIds) {
        final parent = pinMap[parentId];
        if (parent == null) continue;

        final color = Color(
            int.parse(pin.color.replaceAll('#', 'FF'), radix: 16));
        _drawDashedLine(
          canvas,
          Offset(parent.x, parent.y),
          Offset(pin.x, pin.y),
          color,
        );
      }
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    const dashLen = 8.0;
    const gapLen = 4.0;
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segLen =
            math.min(draw ? dashLen : gapLen, metric.length - distance);
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
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _TimelineConnectionPainter old) {
    return old.pins != pins;
  }
}

// ---------------------------------------------------------------------------
// Pin detail bottom sheet (legacy — kept for left-click)
// ---------------------------------------------------------------------------

class _PinDetailSheet extends StatefulWidget {
  final MapPin pin;
  final DmToolColors palette;
  final WorldMapNotifier notifier;

  const _PinDetailSheet({
    required this.pin,
    required this.palette,
    required this.notifier,
  });

  @override
  State<_PinDetailSheet> createState() => _PinDetailSheetState();
}

class _PinDetailSheetState extends State<_PinDetailSheet> {
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.pin.label);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.location_pin, size: 20,
                  color: _pinColor(widget.pin.pinType)),
              const SizedBox(width: 8),
              Text(
                'Pin Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.tabActiveText,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                tooltip: 'Delete pin',
                onPressed: () {
                  widget.notifier.deletePin(widget.pin.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Label field
          TextField(
            controller: _labelCtrl,
            style: TextStyle(fontSize: 12, color: palette.tabText),
            decoration: InputDecoration(
              labelText: 'Label',
              labelStyle: TextStyle(
                fontSize: 11,
                color: palette.tabText.withValues(alpha: 0.6),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: palette.sidebarDivider),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Save
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.notifier.updatePin(
                  widget.pin.id,
                  label: _labelCtrl.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
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
            Icon(icon, size: 14,
                color: highlight ? Colors.red[300] : palette.tabText),
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
                      color: palette.tabText.withValues(alpha: 0.5), width: 1),
                ),
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, color: palette.tabText)),
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
    final visibleCount =
        _pinTypes.where((t) => !hiddenPinTypes.contains(t)).length;

    return PopupMenuButton<String>(
      tooltip: 'Pin categories',
      offset: const Offset(0, 36),
      color: palette.uiFloatingBg,
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
                      width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _pinColor(type),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(
                      fontSize: 11, color: palette.uiFloatingText)),
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
            Text('Categories ($visibleCount/${_pinTypes.length})',
                style: TextStyle(fontSize: 10, color: palette.tabText)),
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

Color _pinColor(String pinType) {
  return switch (pinType) {
    'npc' => Colors.orange,
    'monster' => Colors.red,
    'location' => Colors.blue,
    'event' => Colors.purple,
    _ => Colors.grey,
  };
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
