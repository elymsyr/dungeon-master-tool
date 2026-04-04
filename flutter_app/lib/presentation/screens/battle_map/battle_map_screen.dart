import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../theme/dm_tool_colors.dart';
import '../../../core/utils/screen_type.dart';
import '../../widgets/battle_map/battle_map_mobile_toolbar.dart';
import '../../widgets/battle_map/battle_map_toolbar.dart';
import '../../widgets/battle_map/token_widget.dart';
import 'battle_map_notifier.dart';
import 'battle_map_painter.dart';

/// Battle map tab content — Python ui/windows/battle_map_window.py karşılığı.
/// Session screen'deki "Battle Map" bottom tab'ına gömülür.
class BattleMapScreen extends ConsumerStatefulWidget {
  final String encounterId;

  const BattleMapScreen({required this.encounterId, super.key});

  @override
  ConsumerState<BattleMapScreen> createState() => _BattleMapScreenState();
}

class _BattleMapScreenState extends ConsumerState<BattleMapScreen> {
  // Suppress canvas gestures while a token is being dragged
  bool _tokenDragActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final encounter = ref.read(combatProvider).activeEncounter;
      if (encounter != null && encounter.id == widget.encounterId) {
        ref.read(battleMapProvider(widget.encounterId).notifier).init(encounter);
      }
    });
  }

  @override
  void dispose() {
    // Auto-save on screen dispose (tab switch / session close)
    unawaited(ref.read(battleMapProvider(widget.encounterId).notifier).save());
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(battleMapProvider(widget.encounterId).notifier);

    // Only watch activeTool for gesture routing — scale/panOffset live in viewTransform
    final activeTool = ref.watch(
      battleMapProvider(widget.encounterId).select((s) => s.activeTool),
    );

    final phone = isPhone(context);

    return Column(
      children: [
        // Toolbar (DM view only) — desktop/tablet gets the full horizontal toolbar
        if (!phone) BattleMapToolbar(encounterId: widget.encounterId),

        // Canvas area
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
            notifier.updateViewportSize(canvasSize);

            return Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  notifier.zoomAtPoint(event.localPosition, event.scrollDelta.dy);
                }
              },
              child: GestureDetector(
              // Navigate tool: scale gesture handles both pan and pinch-zoom
              onScaleStart: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? notifier.onScaleStart
                  : null,
              onScaleUpdate: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? notifier.onScaleUpdate
                  : null,
              onScaleEnd: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? (_) => notifier.onScaleEnd()
                  : null,

              // Drawing tools: pan gesture
              onPanStart: (!_tokenDragActive && activeTool != BattleMapTool.navigate)
                  ? (details) => _handlePanStart(details.localPosition, notifier, activeTool)
                  : null,
              onPanUpdate: (!_tokenDragActive && activeTool != BattleMapTool.navigate)
                  ? (details) => _handlePanUpdate(details.localPosition, notifier, activeTool)
                  : null,
              onPanEnd: (!_tokenDragActive && activeTool != BattleMapTool.navigate)
                  ? (_) => _handlePanEnd(notifier, activeTool)
                  : null,

              // Navigate: tap to delete measurement at point
              onTapUp: activeTool == BattleMapTool.navigate
                  ? (details) {
                      final canvas = notifier.screenToCanvas(details.localPosition);
                      notifier.deleteMeasurementAt(canvas);
                    }
                  : null,

              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dark background
                    ColoredBox(color: palette.canvasBg),

                    // Layers 1-6 via CustomPaint (repaint driven by Listenable)
                    Consumer(builder: (context, ref, _) {
                      final mapState = ref.watch(battleMapProvider(widget.encounterId));
                      return RepaintBoundary(
                        child: CustomPaint(
                          size: canvasSize,
                          painter: BattleMapPainter(
                            mapState: mapState,
                            viewTransform: notifier.viewTransform,
                            strokeTick: notifier.strokeTick,
                            palette: palette,
                            isDmView: true,
                            currentPath: notifier.currentPath,
                            currentColor: notifier.currentColor,
                            currentWidth: notifier.currentWidth,
                            currentIsErase: notifier.currentIsErase,
                          ),
                        ),
                      );
                    }),

                    // Token layer — Transform wrapper applies canvas→screen projection
                    _buildTokenLayer(palette, notifier),
                  ],
                ),
              ),
            ),  // GestureDetector
            );  // Listener
          }),
        ),

        // Mobile: compact bottom toolbar with expand-to-sheet
        if (phone) BattleMapMobileToolbar(encounterId: widget.encounterId),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Token layer with Transform wrapper
  // -------------------------------------------------------------------------

  Widget _buildTokenLayer(DmToolColors palette, BattleMapNotifier notifier) {
    final encounter = ref.watch(combatProvider.select((s) => s.activeEncounter));
    if (encounter == null) return const SizedBox.shrink();

    final mapState = ref.watch(battleMapProvider(widget.encounterId));

    return ValueListenableBuilder<ViewTransform>(
      valueListenable: notifier.viewTransform,
      builder: (context, vt, child) {
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(vt.panOffset.dx, vt.panOffset.dy, 0, 1)
            ..scaleByDouble(vt.scale, vt.scale, 1, 1),
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...encounter.combatants.indexed.map((indexed) {
            final (index, c) = indexed;
            final pos = mapState.tokenPositions[c.id];
            if (pos == null) return const SizedBox.shrink();
            return TokenWidget(
              key: ValueKey('token_${c.id}'),
              combatant: c,
              tokenSize: mapState.tokenSizeOverrides[c.id] ?? mapState.tokenSize,
              isActive: index == encounter.turnIndex,
              canvasPosition: pos,
              viewTransform: notifier.viewTransform,
              palette: palette,
              onDragStart: () => setState(() => _tokenDragActive = true),
              onDragEnd: (id, finalCanvasPos) {
                setState(() => _tokenDragActive = false);
                // Commit final position to notifier
                notifier.moveToken(id, finalCanvasPos);
                if (mapState.gridSnap) notifier.snapTokenToGrid(id);
                notifier.persistTokenPositions();
              },
              onResizeRequested: (id) => _showResizeDialog(id, mapState, notifier),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Gesture dispatch for drawing tools
  // -------------------------------------------------------------------------

  void _handlePanStart(Offset localPos, BattleMapNotifier notifier, BattleMapTool activeTool) {
    final canvas = notifier.screenToCanvas(localPos);
    switch (activeTool) {
      case BattleMapTool.fogAdd:
      case BattleMapTool.fogErase:
        notifier.startFogDraft(canvas);
      case BattleMapTool.draw:
        notifier.startAnnotationStroke(canvas);
      case BattleMapTool.ruler:
      case BattleMapTool.circle:
        notifier.startMeasurement(canvas);
      case BattleMapTool.navigate:
        break;
    }
  }

  void _handlePanUpdate(Offset localPos, BattleMapNotifier notifier, BattleMapTool activeTool) {
    final canvas = notifier.screenToCanvas(localPos);
    switch (activeTool) {
      case BattleMapTool.fogAdd:
      case BattleMapTool.fogErase:
        notifier.continueFogDraft(canvas);
      case BattleMapTool.draw:
        notifier.continueAnnotationStroke(canvas);
      case BattleMapTool.ruler:
      case BattleMapTool.circle:
        notifier.updateMeasurement(canvas);
      case BattleMapTool.navigate:
        break;
    }
  }

  Future<void> _handlePanEnd(BattleMapNotifier notifier, BattleMapTool activeTool) async {
    switch (activeTool) {
      case BattleMapTool.fogAdd:
      case BattleMapTool.fogErase:
        await notifier.commitFogDraft();
      case BattleMapTool.draw:
        notifier.endAnnotationStroke();
      case BattleMapTool.ruler:
      case BattleMapTool.circle:
        notifier.commitMeasurement();
      case BattleMapTool.navigate:
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Token resize dialog
  // -------------------------------------------------------------------------

  void _showResizeDialog(String id, BattleMapState mapState, BattleMapNotifier notifier) {
    final current = mapState.tokenSizeOverrides[id] ?? mapState.tokenSize;
    var newSize = current;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token Size'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$newSize px'),
              Slider(
                value: newSize.toDouble(),
                min: 20,
                max: 400,
                divisions: 38,
                onChanged: (v) => setDialogState(() => newSize = v.round()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.setTokenSizeOverride(id, newSize);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
