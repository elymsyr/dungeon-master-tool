import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';
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
  void dispose() {
    unawaited(ref.read(worldMapProvider.notifier).save());
    super.dispose();
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
        Expanded(child: _buildCanvas(palette, notifier, mapState)),
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
      height: 36,
      color: palette.tabBg,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Pick map image
          _ToolbarButton(
            icon: Icons.map_outlined,
            label: mapState.imagePath.isEmpty ? 'Load Map' : 'Change',
            palette: palette,
            onTap: notifier.pickMapImage,
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
            Tooltip(
              message: 'Clear filter',
              child: InkWell(
                onTap: notifier.clearEntityFilter,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(Icons.filter_list_off, size: 14,
                      color: Colors.red[300]),
                ),
              ),
            ),

          _VertDiv(palette: palette),

          // Zoom controls
          Tooltip(
            message: 'Zoom in',
            child: InkWell(
              onTap: () => notifier.zoomAtPoint(const Offset(0, 0), -1),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.add, size: 16, color: palette.tabText),
              ),
            ),
          ),
          Tooltip(
            message: 'Zoom out',
            child: InkWell(
              onTap: () => notifier.zoomAtPoint(const Offset(0, 0), 1),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.remove, size: 16, color: palette.tabText),
              ),
            ),
          ),
          Tooltip(
            message: 'Reset view',
            child: InkWell(
              onTap: notifier.resetView,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.fit_screen, size: 16, color: palette.tabText),
              ),
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

          const Spacer(),

          // Status text
          if (mapState.movingPinId != null)
            Text('Click to place · Esc to cancel',
              style: TextStyle(fontSize: 10, color: Colors.amber.withValues(alpha: 0.8)))
          else if (mapState.isLinkMode)
            Text('Click pin to link · Click empty to create · Esc to cancel',
              style: TextStyle(fontSize: 10, color: Colors.amber.withValues(alpha: 0.8)))
          else
            Text(
              'Double-click to place pin · Drag to pan · Scroll to zoom',
              style: TextStyle(
                fontSize: 10,
                color: palette.tabText.withValues(alpha: 0.4),
              ),
            ),
          const SizedBox(width: 8),
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
    final inMoveMode = mapState.movingPinId != null;
    final inLinkMode = mapState.isLinkMode;
    final cursor = (inMoveMode || inLinkMode)
        ? SystemMouseCursors.precise
        : SystemMouseCursors.basic;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (inMoveMode) notifier.cancelMoveMode();
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
                onTapUp: (inMoveMode || inLinkMode)
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
    final canvasPos = notifier.screenToCanvas(localPos);

    if (mapState.movingPinId != null) {
      notifier.completePinMove(canvasPos);
      return;
    }

    if (mapState.isLinkMode) {
      // Check if tap is on a timeline pin (simplified — just create new)
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
                (pin) => Positioned(
                  left: pin.x - 12,
                  top: pin.y - 24,
                  child: _PinWidget(
                    pin: pin,
                    palette: palette,
                    onTap: () => _showPinDetail(context, pin, notifier, palette),
                    onInspect: pin.entityId != null
                        ? () => widget.onOpenEntity?.call(pin.entityId!)
                        : null,
                    onEditNote: () => _showEditPinNoteDialog(pin, notifier, palette),
                    onChangeColor: () => _showPinColorPicker(pin, notifier, palette),
                    onMove: () => notifier.startPinMoveMode(pin.id, 'pin'),
                    onDelete: () => notifier.deletePin(pin.id),
                  ),
                ),
              ),

              // Timeline pins
              ...notifier.visibleTimelinePins.map(
                (pin) => Positioned(
                  left: pin.x - 14,
                  top: pin.y - 14,
                  child: _TimelinePinWidget(
                    pin: pin,
                    palette: palette,
                    isLinkMode: mapState.isLinkMode,
                    onTap: () {
                      if (mapState.isLinkMode) {
                        notifier.handleLinkToExisting(pin.id);
                      } else {
                        _showTimelineEditDialog(pin, notifier, palette);
                      }
                    },
                    onLinkNew: () => notifier.startLinkMode(pin.id),
                    onEdit: () => _showTimelineEditDialog(pin, notifier, palette),
                    onChangeColor: () =>
                        _showTimelineColorPicker(pin, notifier, palette),
                    onMove: () => notifier.startPinMoveMode(pin.id, 'timeline'),
                    onDelete: () => notifier.deleteTimelinePin(pin.id),
                  ),
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

    final box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.offset);
    final canvasPos = notifier.screenToCanvas(localPos);
    notifier.addPin(canvasPos, entityId: entityId, label: entity.name);
  }

  // -------------------------------------------------------------------------
  // Dialogs / Sheets
  // -------------------------------------------------------------------------

  void _showAddPinDialog(Offset canvasPos, WorldMapNotifier notifier) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    String selectedType = 'default';
    final labelCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: palette.uiFloatingBg,
          title: Text(
            'Add Pin',
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
              const SizedBox(height: 12),
              Text(
                'Pin type',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.uiFloatingText.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['default', 'npc', 'monster', 'location', 'event']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(
                          t,
                          style: TextStyle(fontSize: 10, color: palette.tabText),
                        ),
                        selected: selectedType == t,
                        selectedColor: _pinColor(t).withValues(alpha: 0.25),
                        onSelected: (_) => setDlgState(() => selectedType = t),
                      ),
                    )
                    .toList(),
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
                notifier.addPin(
                  canvasPos,
                  pinType: selectedType,
                  label: labelCtrl.text,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
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
      builder: (ctx) => TimelineEntryDialog(palette: palette, existing: pin),
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
    final entities = ref.read(entityProvider);
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
// Pin widget (icon on canvas) with context menu
// ---------------------------------------------------------------------------

class _PinWidget extends StatelessWidget {
  final MapPin pin;
  final DmToolColors palette;
  final VoidCallback onTap;
  final VoidCallback? onInspect;
  final VoidCallback? onEditNote;
  final VoidCallback? onChangeColor;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const _PinWidget({
    required this.pin,
    required this.palette,
    required this.onTap,
    this.onInspect,
    this.onEditNote,
    this.onChangeColor,
    this.onMove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = pin.color.isNotEmpty
        ? Color(int.parse(pin.color.replaceAll('#', 'FF'), radix: 16))
        : _pinColor(pin.pinType);

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: Tooltip(
        message: pin.label.isEmpty ? pin.pinType : pin.label,
        child: Icon(
          Icons.location_pin,
          size: 24,
          color: displayColor,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final items = <PopupMenuEntry<String>>[];

    if (onInspect != null) {
      items.add(PopupMenuItem(
        value: 'inspect',
        child: _menuRow(Icons.open_in_new, 'Inspect Entity'),
      ));
    }
    items.addAll([
      PopupMenuItem(
        value: 'edit_note',
        child: _menuRow(Icons.edit_note, 'Edit Note'),
      ),
      PopupMenuItem(
        value: 'change_color',
        child: _menuRow(Icons.palette, 'Change Color'),
      ),
      PopupMenuItem(
        value: 'move',
        child: _menuRow(Icons.open_with, 'Move'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(Icons.delete_outline, 'Delete', danger: true),
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
          onInspect?.call();
        case 'edit_note':
          onEditNote?.call();
        case 'change_color':
          onChangeColor?.call();
        case 'move':
          onMove?.call();
        case 'delete':
          onDelete?.call();
      }
    });
  }

  Widget _menuRow(IconData icon, String label, {bool danger = false}) {
    return Row(
      children: [
        Icon(icon, size: 16,
            color: danger ? Colors.red[300] : palette.uiFloatingText),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: danger ? Colors.red[300] : palette.uiFloatingText)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline pin widget
// ---------------------------------------------------------------------------

class _TimelinePinWidget extends StatelessWidget {
  final TimelinePin pin;
  final DmToolColors palette;
  final bool isLinkMode;
  final VoidCallback onTap;
  final VoidCallback? onLinkNew;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeColor;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const _TimelinePinWidget({
    required this.pin,
    required this.palette,
    required this.onTap,
    this.isLinkMode = false,
    this.onLinkNew,
    this.onEdit,
    this.onChangeColor,
    this.onMove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
        int.parse(pin.color.replaceAll('#', 'FF'), radix: 16));

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: Tooltip(
        message: _tooltipText(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: pin.sessionId != null ? Colors.white : Colors.black54,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 3),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${pin.day}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipText() {
    final parts = <String>[];
    parts.add('Day ${pin.day}');
    if (pin.note.isNotEmpty) parts.add(pin.note);
    if (pin.sessionId != null) parts.add('(linked)');
    return parts.join('\n');
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final items = <PopupMenuEntry<String>>[];

    if (pin.sessionId != null) {
      items.add(PopupMenuItem(
        value: 'goto_session',
        child: _menuRow(Icons.event, 'Go to Session'),
      ));
      items.add(const PopupMenuDivider());
    }

    items.addAll([
      PopupMenuItem(
        value: 'link_new',
        child: _menuRow(Icons.link, 'Link New'),
      ),
      PopupMenuItem(
        value: 'edit',
        child: _menuRow(Icons.edit, 'Edit'),
      ),
      PopupMenuItem(
        value: 'change_color',
        child: _menuRow(Icons.palette, 'Change Color (chain)'),
      ),
      PopupMenuItem(
        value: 'move',
        child: _menuRow(Icons.open_with, 'Move'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(Icons.delete_outline, 'Delete', danger: true),
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
        case 'goto_session':
          break; // TODO: navigate to session tab
        case 'link_new':
          onLinkNew?.call();
        case 'edit':
          onEdit?.call();
        case 'change_color':
          onChangeColor?.call();
        case 'move':
          onMove?.call();
        case 'delete':
          onDelete?.call();
      }
    });
  }

  Widget _menuRow(IconData icon, String label, {bool danger = false}) {
    return Row(
      children: [
        Icon(icon, size: 16,
            color: danger ? Colors.red[300] : palette.uiFloatingText),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: danger ? Colors.red[300] : palette.uiFloatingText)),
      ],
    );
  }
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
  late String _pinType;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.pin.label);
    _pinType = widget.pin.pinType;
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
              Icon(Icons.location_pin, size: 20, color: _pinColor(_pinType)),
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
          const SizedBox(height: 12),

          // Pin type selector
          Text(
            'Type',
            style: TextStyle(
              fontSize: 11,
              color: palette.tabText.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['default', 'npc', 'monster', 'location', 'event']
                .map(
                  (t) => ChoiceChip(
                    label: Text(
                      t,
                      style: TextStyle(fontSize: 10, color: palette.tabText),
                    ),
                    selected: _pinType == t,
                    selectedColor: _pinColor(t).withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _pinType = t),
                  ),
                )
                .toList(),
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
                  pinType: _pinType,
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
