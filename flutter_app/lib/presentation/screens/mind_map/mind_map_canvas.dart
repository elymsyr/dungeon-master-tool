import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/mind_map.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/unbounded_stack.dart';
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

  // Pen input — raw pointer events, so a stroke starts on the first sample
  // instead of after the gesture arena's pan slop.
  final _live = LiveStroke();
  int? _penPointer;
  PointerDeviceKind? _penKind;
  final _downPointers = <int>{};
  // Once a stylus touches the canvas, fingers stop drawing (palm rejection)
  // and only pan/zoom.
  bool _stylusSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    _live.dispose();
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
    final notifier = ref.read(mindMapProvider.notifier);
    // Strokes are left out so a finished stroke doesn't rebuild every node
    // card (a visible hitch at pen-up); the stroke layer watches them alone.
    final mapState = ref.watch(
        mindMapProvider.select((s) => s.copyWith(strokes: const [])));
    return ListenableBuilder(
      listenable: Listenable.merge([notifier.penColor, notifier.erasing]),
      builder: (context, _) =>
          _buildBody(context, notifier, mapState, notifier.penColor.value),
    );
  }

  Widget _buildBody(BuildContext context, MindMapNotifier notifier,
      MindMapState mapState, Color? penColor) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final penOn = penColor != null;
    if (!penOn) _resetPen();

    final inMoveMode = mapState.moveModeNodeId != null;
    final cursor = penOn
        ? (notifier.erasing.value
            ? SystemMouseCursors.cell
            : SystemMouseCursors.precise)
        : inMoveMode
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
            onPointerDown: penOn ? (e) => _penDown(e, notifier) : null,
            onPointerMove: penOn ? (e) => _penMove(e, notifier) : null,
            onPointerUp: penOn ? (e) => _penUp(e, notifier) : null,
            onPointerCancel: penOn ? _penCancel : null,
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
              // Exclude trackpad so touchpad two-finger scroll falls through
              // to the Listener's onPointerSignal for zoom (GitHub #90).
              supportedDevices: const {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
              },
              onScaleStart: notifier.onScaleStart,
              onScaleUpdate: (d) {
                // A live stroke owns the single pointer; pinch/pan resume
                // once a second finger cancels it.
                if (_penPointer != null) return;
                notifier.onScaleUpdate(d);
              },
              onScaleEnd: (_) => notifier.onScaleEnd(),
              onTapUp: penOn
                  ? null
                  : inMoveMode
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
              onLongPressStart: penOn
                  ? null
                  : (d) {
                      _handleContextMenu(d.localPosition, d.globalPosition,
                          notifier, palette);
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
                          child: IgnorePointer(
                            ignoring: penOn,
                            child: _buildCanvasContent(
                                palette, notifier, mapState, penOn),
                          ),
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
    bool penOn,
  ) {
    final vt = notifier.viewTransform.value;
    final scale = vt.scale;
    final lodZone = notifier.lodZone;

    // F8: viewport rect in canvas-space for culling. Inflate by a constant
    // screen-space buffer (~200px) divided by the current scale → the
    // canvas-space buffer auto-shrinks when zoomed in and grows when
    // zoomed out, keeping the on-screen edge band stable.
    final viewportRect =
        _computeViewportRect(notifier).inflate(200 / scale);

    return UnboundedStack(
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

            // F7: per-node override notifier — single listener per node;
            //     a drag on node X fires only X's builder, not all N.
            return ValueListenableBuilder<NodeOverride>(
              key: ValueKey('node_${node.id}'),
              valueListenable: notifier.nodeOverrideOf(node.id),
              builder: (_, override, child) {
                final pos = override.pos;
                final size = override.size;
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

        // Pen strokes sit above nodes so cards can be circled/annotated.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Consumer(
                builder: (_, ref, _) {
                  final strokes =
                      ref.watch(mindMapProvider.select((s) => s.strokes));
                  // Width depends on zoom (clamped) → repaint on zoom (paths
                  // stay cached); a pan doesn't repaint, shouldRepaint skips it.
                  return ValueListenableBuilder<MindMapViewTransform>(
                    valueListenable: notifier.viewTransform,
                    builder: (_, vt, _) => CustomPaint(
                      painter: MindMapStrokesPainter(strokes, vt.scale),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: LiveStrokePainter(_live)),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Pen input
  // -------------------------------------------------------------------------

  /// Eraser reach around the nib, screen px.
  static const double _eraserRadius = 10;

  // Eraser drag state: last probe (canvas) and whether this drag already
  // pushed its single undo step.
  Offset? _eraseLast;
  bool _eraseUndone = false;

  void _penDown(PointerDownEvent e, MindMapNotifier notifier) {
    _downPointers.add(e.pointer);
    if (e.kind == PointerDeviceKind.stylus) _stylusSeen = true;

    if (_penPointer != null) {
      // Second finger on a finger-stroke → it's a pinch, drop the stroke.
      // A stylus stroke ignores the palm.
      if (_penKind == PointerDeviceKind.touch) _cancelStroke();
      return;
    }
    if (_downPointers.length > 1) return;

    final canDraw = switch (e.kind) {
      PointerDeviceKind.stylus => true,
      PointerDeviceKind.touch => !_stylusSeen,
      PointerDeviceKind.mouse => e.buttons == kPrimaryMouseButton,
      _ => false,
    };
    final color = notifier.penColor.value;
    if (!canDraw || color == null) return;

    _penPointer = e.pointer;
    _penKind = e.kind;
    final pos = notifier.screenToCanvas(e.localPosition);
    if (notifier.erasing.value) {
      _eraseUndone = false;
      _eraseLast = pos;
      _erase(pos, notifier);
      return;
    }
    final scale = notifier.viewTransform.value.scale;
    _live.start(pos, color, notifier.penWidth.value, scale);
  }

  void _erase(Offset to, MindMapNotifier notifier) {
    final from = _eraseLast ?? to;
    _eraseLast = to;
    final scale = notifier.viewTransform.value.scale;
    if (notifier.eraseStrokes(from, to, _eraserRadius / scale,
        pushUndo: !_eraseUndone)) {
      _eraseUndone = true;
    }
  }

  void _penMove(PointerMoveEvent e, MindMapNotifier notifier) {
    if (e.pointer != _penPointer) return;
    final pos = notifier.screenToCanvas(e.localPosition);
    if (_eraseLast != null) return _erase(pos, notifier);
    final scale = notifier.viewTransform.value.scale;
    _live.add(pos, 1.5 / scale);
  }

  void _penUp(PointerUpEvent e, MindMapNotifier notifier) {
    _downPointers.remove(e.pointer);
    if (e.pointer != _penPointer) return;
    if (_eraseLast != null) return _cancelStroke();
    _live.add(notifier.screenToCanvas(e.localPosition), double.infinity);
    final scale = notifier.viewTransform.value.scale;
    notifier.addStroke(
        simplifyStroke(_live.rendered, 0.3 / scale), _live.color, _live.width,
        zoom: _live.scale);
    _cancelStroke();
  }

  void _penCancel(PointerCancelEvent e) {
    _downPointers.remove(e.pointer);
    if (e.pointer == _penPointer) _cancelStroke();
  }

  void _cancelStroke() {
    _penPointer = null;
    _penKind = null;
    _eraseLast = null;
    _live.clear();
  }

  void _resetPen() {
    _downPointers.clear();
    if (_penPointer != null) _cancelStroke();
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
    final edgeId = notifier.hitTestEdge(
        canvasPos, threshold: MindMapNotifier.edgeContextHitRadius / scale);
    final strokeId = edgeId == null
        ? notifier.hitTestStroke(canvasPos, threshold: 12 / scale)
        : null;
    if (edgeId != null) {
      notifier.setSelectedEdge(edgeId);
      showMindMapEdgeMenu(
          context, globalPosition, edgeId, notifier, palette);
    } else if (strokeId != null) {
      _showStrokeMenu(globalPosition, strokeId, notifier, palette);
    } else {
      _showCanvasContextMenu(
          context, globalPosition, canvasPos, notifier, palette);
    }
  }

  void _showStrokeMenu(
    Offset globalPos,
    String strokeId,
    MindMapNotifier notifier,
    DmToolColors palette,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: palette.uiFloatingBg,
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
              const SizedBox(width: 8),
              Text(L10n.of(context)!.mindMapDeleteDrawing,
                  style: TextStyle(color: Colors.red[300], fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') notifier.deleteStroke(strokeId);
    });
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
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'entity',
          child: _menuItem(Icons.dataset_outlined, 'Add from Database', palette),
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
        case 'entity':
          _showEntityPicker(canvasPos, notifier);
      }
    });
  }

  void _showEntityPicker(Offset canvasPos, MindMapNotifier notifier) async {
    final result = await showEntitySelectorDialog(
      context: context,
      ref: ref,
    );
    if (result == null || result.isEmpty) return;
    final entityId = result.first;
    final entities = ref.read(entityProvider);
    final entity = entities[entityId];
    if (entity == null) return;
    notifier.addEntityNode(canvasPos, entityId, entity.name);
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
      if (notifier.penColor.value != null) {
        notifier.exitPen();
      } else if (mapState.moveModeNodeId != null) {
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

// Local _UnboundedStack moved to widgets/unbounded_stack.dart (shared with
// world map). Use UnboundedStack from that import.
