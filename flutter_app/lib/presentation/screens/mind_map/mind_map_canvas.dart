import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/mind_map.dart';
import '../../theme/dm_tool_colors.dart';
import 'mind_map_notifier.dart';
import 'mind_map_painter.dart';
import 'mind_map_node_widget.dart';

/// Infinite-canvas mind map viewport.
///
/// Uses custom gesture handling (Listener + GestureDetector + Transform)
/// with ValueListenableBuilder for 60fps pan/zoom. Supports DragTarget
/// for entity drops from sidebar.
class MindMapCanvas extends ConsumerStatefulWidget {
  final String? mapId;
  final bool editMode;
  final void Function(String entityId)? onOpenEntity;

  const MindMapCanvas({
    super.key,
    this.mapId,
    this.editMode = false,
    this.onOpenEntity,
  });

  @override
  ConsumerState<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends ConsumerState<MindMapCanvas>
    with WidgetsBindingObserver {
  // Cursor position in canvas space (for connecting-draft line)
  Offset? _cursorCanvas;
  final _canvasFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Update viewport size on window resize without rebuilding widget tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        ref.read(mindMapProvider.notifier).updateViewportSize(box.size);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(mindMapProvider.notifier);
    final mapState = ref.watch(mindMapProvider);

    final inMoveMode = mapState.moveModeNodeId != null;
    final cursor = inMoveMode
        ? SystemMouseCursors.move
        : SystemMouseCursors.basic;

    return KeyboardListener(
      focusNode: _canvasFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKey(event, notifier, mapState),
      child: MouseRegion(
          cursor: cursor,
          onHover: (event) {
            if (mapState.connectingFromId != null) {
              final canvasPos = notifier.screenToCanvas(event.localPosition);
              setState(() => _cursorCanvas = canvasPos);
            }
          },
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                final canvasPos = notifier.screenToCanvas(signal.localPosition);
                if (!notifier.isPointOverScrollableNode(canvasPos)) {
                  notifier.zoomAtPoint(
                    signal.localPosition,
                    signal.scrollDelta.dy,
                  );
                }
              }
            },
            child: GestureDetector(
              onScaleStart: notifier.onScaleStart,
              onScaleUpdate: (d) {
                notifier.onScaleUpdate(d);
              },
              onScaleEnd: (_) => notifier.onScaleEnd(),
              onTapUp: inMoveMode
                  ? (d) {
                      final canvasPos =
                          notifier.screenToCanvas(d.localPosition);
                      notifier.placeNodeAtPosition(canvasPos);
                    }
                  : (d) {
                      if (mapState.connectingFromId != null) {
                        notifier.cancelConnecting();
                        return;
                      }
                      // Hit-test edges before clearing selection
                      final canvasPos =
                          notifier.screenToCanvas(d.localPosition);
                      final scale = notifier.viewTransform.value.scale;
                      final edgeId = notifier.hitTestEdge(canvasPos,
                          threshold: 10.0 / scale);
                      if (edgeId != null) {
                        notifier.setSelectedEdge(edgeId);
                      } else {
                        notifier.clearSelection();
                        notifier.exitResizeMode();
                      }
                    },
              onDoubleTapDown: null,
              // Secondary tap on the outer GestureDetector so it shares
              // the gesture arena with ScaleGestureRecognizer — the
              // TapGestureRecognizer resolves immediately on pointer-up,
              // beating the scale recognizer. Node-level secondary tap
              // handlers still win because they're closer in hit-test order.
              onSecondaryTapUp: (d) {
                _handleContextMenu(
                    d.localPosition, d.globalPosition, notifier, palette);
              },
              onLongPressStart: (d) {
                _handleContextMenu(
                    d.localPosition, d.globalPosition, notifier, palette);
              },
              child: DragTarget<String>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) =>
                    _onEntityDrop(context, details, notifier),
                builder: (context, candidateData, rejectedData) {
                  return ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background — opaque hit target for empty canvas area
                        ColoredBox(color: palette.canvasBg),

                        // Canvas-space content with Transform
                        ValueListenableBuilder<MindMapViewTransform>(
                          valueListenable: notifier.viewTransform,
                          builder: (_, vt, child) {
                            return Transform(
                              transform: Matrix4.identity()
                                ..translateByDouble(
                                    vt.panOffset.dx, vt.panOffset.dy, 0, 1)
                                ..scaleByDouble(vt.scale, vt.scale, 1, 1),
                              child: child,
                            );
                          },
                          child: _buildCanvasContent(
                              palette, notifier, mapState),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildCanvasContent(
    DmToolColors palette,
    MindMapNotifier notifier,
    MindMapState mapState,
  ) {
    final vt = notifier.viewTransform.value;
    final scale = vt.scale;
    final lodZone = notifier.lodZone;

    // Compute viewport rect in canvas-space for culling.
    // Inflate generously so nodes near edges aren't culled when
    // the child widget is cached across viewTransform changes.
    final viewportRect = _computeViewportRect(notifier).inflate(500);

    return _UnboundedStack(
      clipBehavior: Clip.none,
      children: [
        // Grid + edges + workspaces + LOD templates
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: notifier.edgeTick,
            builder: (_, _, _) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: MindMapPainter(
                    mapState: mapState,
                    scale: scale,
                    viewportRect: viewportRect,
                    palette: palette,
                    connectingFromId: mapState.connectingFromId,
                    connectingToCanvas: _cursorCanvas,
                    lodZone: lodZone,
                    dragOverrides: notifier.dragOverrides.value,
                  ),
                ),
              );
            },
          ),
        ),

        // Node widgets (only at LOD 0 and 1)
        // Wrapped in ValueListenableBuilder so drag/resize overrides
        // update Positioned coordinates at 60fps without Riverpod rebuild.
        if (lodZone < 2)
          ...notifier.sortedNodes
              .where((n) => _isInViewport(n, viewportRect))
              .map((node) {
            final isSelected = node.id == mapState.selectedNodeId;
            final isConnecting = node.id == mapState.connectingFromId;
            final canConnectTo =
                mapState.connectingFromId != null && !isConnecting;
            final showResizeHandle = isSelected;

            return ValueListenableBuilder<Map<String, Offset>>(
              key: ValueKey('node_${node.id}'),
              valueListenable: notifier.dragOverrides,
              builder: (_, dragMap, child) {
                final sizeMap = notifier.sizeOverrides.value;
                final pos = dragMap[node.id];
                final size = sizeMap[node.id];
                final cx = pos?.dx ?? node.x;
                final cy = pos?.dy ?? node.y;
                final w = size?.width ?? node.width;
                final h = size?.height ?? node.height;

                return Positioned(
                  left: cx - w / 2,
                  top: cy - h / 2,
                  width: w,
                  height: h,
                  child: child!,
                );
              },
              child: RepaintBoundary(
                child: MindMapNodeWidget(
                  node: node,
                  isSelected: isSelected,
                  isConnecting: isConnecting,
                  canConnectTo: canConnectTo,
                  palette: palette,
                  notifier: notifier,
                  editMode: widget.editMode,
                  lodZone: lodZone,
                  showResizeHandle: showResizeHandle,
                  onOpenEntity: widget.onOpenEntity,
                ),
              ),
            );
          }),
      ],
    );
  }

  Rect _computeViewportRect(MindMapNotifier notifier) {
    final vt = notifier.viewTransform.value;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Rect.fromLTWH(-5000, -5000, 10000, 10000);
    final size = box.size;
    return Rect.fromLTWH(
      -vt.panOffset.dx / vt.scale,
      -vt.panOffset.dy / vt.scale,
      size.width / vt.scale,
      size.height / vt.scale,
    );
  }

  bool _isInViewport(MindMapNode node, Rect viewport) {
    final hw = node.width / 2 + 50;
    final hh = node.height / 2 + 50;
    return node.x + hw > viewport.left &&
        node.x - hw < viewport.right &&
        node.y + hh > viewport.top &&
        node.y - hh < viewport.bottom;
  }

  // -------------------------------------------------------------------------
  // Entity drop from sidebar
  // -------------------------------------------------------------------------

  void _onEntityDrop(
    BuildContext context,
    DragTargetDetails<String> details,
    MindMapNotifier notifier,
  ) {
    final entityId = details.data;
    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    if (entity == null) return;

    final box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.offset);
    final canvasPos = notifier.screenToCanvas(localPos);
    notifier.addEntityNode(canvasPos, entityId, entity.name);
  }

  // -------------------------------------------------------------------------
  // Canvas context menu
  // -------------------------------------------------------------------------

  void _handleContextMenu(
    Offset localPosition,
    Offset globalPosition,
    MindMapNotifier notifier,
    DmToolColors palette,
  ) {
    final canvasPos = notifier.screenToCanvas(localPosition);
    final scale = notifier.viewTransform.value.scale;
    final edgeId = notifier.hitTestEdge(canvasPos, threshold: 10.0 / scale);
    if (edgeId != null) {
      notifier.setSelectedEdge(edgeId);
      _showEdgeContextMenu(context, globalPosition, edgeId, notifier, palette);
    } else {
      _showCanvasContextMenu(
          context, globalPosition, canvasPos, notifier, palette);
    }
  }

  void _showCanvasContextMenu(
    BuildContext context,
    Offset globalPos,
    Offset canvasPos,
    MindMapNotifier notifier,
    DmToolColors palette,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      color: palette.uiFloatingBg,
      items: [
        PopupMenuItem(
          value: 'note',
          child: _menuItem(Icons.note_add, 'Add Note', palette),
        ),
        PopupMenuItem(
          value: 'image',
          child: _menuItem(Icons.image, 'Add Image', palette),
        ),
        PopupMenuItem(
          value: 'workspace',
          child: _menuItem(Icons.grid_view, 'Add Workspace', palette),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'note':
          notifier.addNode(canvasPos, 'note');
        case 'image':
          notifier.addNode(canvasPos, 'image');
        case 'workspace':
          notifier.addWorkspace(canvasPos);
      }
    });
  }

  void _showEdgeContextMenu(
    BuildContext context,
    Offset globalPos,
    String edgeId,
    MindMapNotifier notifier,
    DmToolColors palette,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      color: palette.uiFloatingBg,
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
              const SizedBox(width: 8),
              Text('Delete Connection',
                  style: TextStyle(color: Colors.red[300], fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        notifier.deleteEdge(edgeId);
      }
    });
  }

  Widget _menuItem(IconData icon, String text, DmToolColors palette) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.uiFloatingText),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: palette.uiFloatingText, fontSize: 13)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Keyboard shortcuts
  // -------------------------------------------------------------------------

  void _handleKey(
      KeyEvent event, MindMapNotifier notifier, MindMapState mapState) {
    if (event is! KeyDownEvent) return;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (mapState.moveModeNodeId != null) {
        notifier.exitMoveMode();
      } else if (mapState.resizeModeNodeId != null) {
        notifier.exitResizeMode();
      } else if (mapState.connectingFromId != null) {
        notifier.cancelConnecting();
      } else {
        notifier.clearSelection();
      }
      return;
    }

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (shift) {
        notifier.redo();
      } else {
        notifier.undo();
      }
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      notifier.redo();
    } else if (!widget.editMode &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace)) {
      if (mapState.selectedNodeId != null) {
        notifier.deleteNode(mapState.selectedNodeId!);
      } else if (mapState.selectedEdgeId != null) {
        notifier.deleteEdge(mapState.selectedEdgeId!);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Stack whose hit-testing is not bounded by its layout size.
//
// In the infinite canvas the Transform inverse-maps screen coordinates to
// canvas coordinates which can exceed the Stack's viewport-sized bounds.
// Flutter's default RenderBox.hitTest checks size.contains(position) and
// rejects those hits.  This widget removes that check so Positioned children
// at any canvas coordinate receive pointer events.
// ---------------------------------------------------------------------------

class _UnboundedStack extends Stack {
  const _UnboundedStack({
    super.clipBehavior = Clip.none,
    super.children = const <Widget>[],
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _RenderUnboundedStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

}

class _RenderUnboundedStack extends RenderStack {
  _RenderUnboundedStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Skip the default size.contains(position) check so that children
    // at any canvas coordinate receive pointer events (right-click, tap, drag).
    if (hitTestChildren(result, position: position) ||
        hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
