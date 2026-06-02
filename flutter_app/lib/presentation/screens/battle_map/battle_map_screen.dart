import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/character_provider.dart';
import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/value_objects/creature_size.dart';
import '../../../domain/value_objects/map_shape.dart';
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
  late final BattleMapNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(battleMapProvider(widget.encounterId).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final encounter = ref.read(combatProvider).activeEncounter;
      if (encounter != null && encounter.id == widget.encounterId) {
        _notifier.init(encounter);
      }
    });
  }

  @override
  void dispose() {
    // Auto-save on screen dispose (tab switch / session close)
    unawaited(_notifier.save());
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = _notifier;

    // Only watch activeTool for gesture routing — scale/panOffset live in viewTransform
    final activeTool = ref.watch(
      battleMapProvider(widget.encounterId).select((s) => s.activeTool),
    );

    // Cross-device / CDC catch-up: activeEncounter content fresher than what
    // the notifier was init'd with → re-hydrate. Idempotent + pending-write
    // guarded inside syncFromEncounter.
    ref.listen(
      combatProvider.select((s) => s.activeEncounter),
      (prev, next) {
        if (next == null || next.id != widget.encounterId) return;
        _notifier.syncFromEncounter(next);
      },
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
              // Navigate tool: scale gesture handles pan + pinch-zoom, and a
              // single-finger drag that starts on a text label moves it.
              onScaleStart: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? (d) => _onNavScaleStart(d, notifier)
                  : null,
              onScaleUpdate: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? (d) => _onNavScaleUpdate(d, notifier)
                  : null,
              onScaleEnd: (!_tokenDragActive && activeTool == BattleMapTool.navigate)
                  ? (_) => _onNavScaleEnd(notifier)
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

              // Tap-driven tools: navigate (delete mark), text (place label
              // via dialog).
              onTapUp: (activeTool == BattleMapTool.navigate ||
                      activeTool == BattleMapTool.text)
                  ? (details) =>
                      _handleTapUp(details.localPosition, notifier, activeTool)
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
                            shapeTick: notifier.shapeTick,
                            palette: palette,
                            isDmView: true,
                            notifier: notifier,
                          ),
                        ),
                      );
                    }),

                    // Token layer — Transform wrapper applies canvas→screen projection
                    _buildTokenLayer(palette, notifier),

                    // Foreground vector shapes (object + GM layers + live draft),
                    // drawn ABOVE the tokens so object shapes sit over them
                    // (matches the player's z-order). IgnorePointer so it never
                    // steals token / canvas gestures.
                    Consumer(builder: (context, ref, _) {
                      final mapState =
                          ref.watch(battleMapProvider(widget.encounterId));
                      return IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: canvasSize,
                            painter: BattleMapForegroundPainter(
                              mapState: mapState,
                              viewTransform: notifier.viewTransform,
                              notifier: notifier,
                              shapeTick: notifier.shapeTick,
                            ),
                          ),
                        ),
                      );
                    }),
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

  /// Looks up the combatant's source entity. Falls back to the characters
  /// list because [entityProvider] only injects chars whose `worldId` matches
  /// the active world — encounters can still reference orphan or
  /// other-world PCs.
  Entity? _entityFor(String? entityId) {
    if (entityId == null) return null;
    final entities = ref.read(entityProvider);
    final fromProvider = entities[entityId];
    if (fromProvider != null) return fromProvider;
    // Combined source: own chars + other-player chars from the world mirror.
    // The DM may add another player's PC to a combat (via the world chars
    // mirror) — that entity is in neither `entityProvider` nor `character
    // ListProvider`. `combatCharactersProvider` unions both.
    final chars = ref.read(combatCharactersProvider);
    for (final c in chars) {
      if (c.entity.id == entityId) return c.entity;
    }
    return null;
  }

  String? _entityImagePath(String? entityId) {
    final entity = _entityFor(entityId);
    if (entity == null) return null;
    if (entity.images.isNotEmpty) return entity.images.first;
    if (entity.imagePath.isNotEmpty) return entity.imagePath;
    return null;
  }

  Color _categoryColor(String? entityId, DmToolColors palette) {
    final entity = _entityFor(entityId);
    if (entity == null) return palette.tokenBorderNeutral;
    final schema = ref.read(worldSchemaProvider);
    for (final cat in schema.categories) {
      if (cat.slug == entity.categorySlug) {
        final hex = cat.color;
        if (hex.startsWith('#') && hex.length == 7) {
          return Color(int.parse('FF${hex.substring(1)}', radix: 16));
        }
        break;
      }
    }
    return palette.tokenBorderNeutral;
  }

  /// Token size multiplier for a combatant. A manual resize (an explicit entry
  /// in [BattleMapState.tokenSizeMultipliers]) always wins; otherwise the
  /// creature's 5e size drives a grid-anchored footprint — `cells × gridSize /
  /// tokenSize`, so the rendered px (`tokenSize × multiplier`) equals exactly
  /// `cells × gridSize` and snaps to whole grid cells regardless of the global
  /// token-size slider. Falls back to Medium (1 cell) when size is unknown.
  double _effectiveSizeMultiplier(
    String combatantId,
    String? entityId,
    BattleMapState s,
  ) {
    final manual = s.tokenSizeMultipliers[combatantId];
    if (manual != null) return manual;
    final cells = tokenCellSpan(_entityFor(entityId), ref.read(entityProvider));
    return s.tokenSize > 0 ? cells * s.gridSize / s.tokenSize : cells;
  }

  Widget _buildTokenLayer(DmToolColors palette, BattleMapNotifier notifier) {
    final encounter = ref.watch(combatProvider.select((s) => s.activeEncounter));
    if (encounter == null) return const SizedBox.shrink();

    final mapState = ref.watch(battleMapProvider(widget.encounterId));
    // Tokens are only interactive in the navigate tool. With ruler/draw/fog
    // active, the user is operating on the canvas itself, so any pointer
    // event over a token should fall through to the gesture detector.
    final tokensInteractive = mapState.activeTool == BattleMapTool.navigate;

    // Assign default positions to newly added combatants
    final hasMissing = encounter.combatants.any(
      (c) => !mapState.tokenPositions.containsKey(c.id),
    );
    if (hasMissing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifier.ensureTokenPositions(encounter.combatants);
      });
    }

    // Canvas extent must be large enough so inverse-transformed screen
    // coordinates stay within the Stack's layout bounds for hit-testing.
    const canvasExtent = 10000.0;

    return ValueListenableBuilder<ViewTransform>(
      valueListenable: notifier.viewTransform,
      builder: (context, vt, child) {
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(vt.panOffset.dx, vt.panOffset.dy, 0, 1)
              ..scaleByDouble(vt.scale, vt.scale, 1, 1),
            child: child,
          ),
        );
      },
      child: IgnorePointer(
        ignoring: !tokensInteractive,
        child: SizedBox(
        width: canvasExtent,
        height: canvasExtent,
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
                tokenSize: (mapState.tokenSize *
                        _effectiveSizeMultiplier(c.id, c.entityId, mapState))
                    .round(),
                isActive: index == encounter.turnIndex,
                canvasPosition: pos,
                viewTransform: notifier.viewTransform,
                borderColor: _categoryColor(c.entityId, palette),
                imagePath: _entityImagePath(c.entityId),
                hidden: encounter.hiddenTokenIds.contains(c.id),
                palette: palette,
                onDragStart: () => setState(() => _tokenDragActive = true),
                onDragEnd: (id, finalCanvasPos) {
                  setState(() => _tokenDragActive = false);
                  // Commit final position to notifier
                  notifier.moveToken(id, finalCanvasPos);
                  if (mapState.gridSnap) notifier.snapTokenToGrid(id);
                  notifier.persistTokenPositions();
                },
                onContextMenu: (id) => _showTokenMenu(id, mapState, notifier),
              );
            }),
          ],
        ),
      ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Gesture dispatch for drawing tools
  // -------------------------------------------------------------------------

  // Label drag (navigate tool): set while a single-finger drag that began on a
  // text label is repositioning it instead of panning the map.
  String? _draggingLabelId;
  Offset _lastDragCanvas = Offset.zero;

  void _onNavScaleStart(ScaleStartDetails d, BattleMapNotifier notifier) {
    final canvas = notifier.screenToCanvas(d.localFocalPoint);
    final id = notifier.hitTextLabel(canvas);
    if (id != null) {
      _draggingLabelId = id;
      _lastDragCanvas = canvas;
      return;
    }
    notifier.onScaleStart(d);
  }

  void _onNavScaleUpdate(ScaleUpdateDetails d, BattleMapNotifier notifier) {
    if (_draggingLabelId != null) {
      final canvas = notifier.screenToCanvas(d.localFocalPoint);
      notifier.moveShapeBy(_draggingLabelId!, canvas - _lastDragCanvas);
      _lastDragCanvas = canvas;
      return;
    }
    notifier.onScaleUpdate(d);
  }

  void _onNavScaleEnd(BattleMapNotifier notifier) {
    if (_draggingLabelId != null) {
      _draggingLabelId = null;
      notifier.commitShapeMove();
      return;
    }
    notifier.onScaleEnd();
  }

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
      case BattleMapTool.aoeCone:
      case BattleMapTool.aoeLine:
      case BattleMapTool.aoeCircle:
      case BattleMapTool.aoeSquare:
      case BattleMapTool.aoeSector:
        notifier.startMeasurement(canvas);
      case BattleMapTool.eraseMark:
        // Whole-delete vector strokes/marks crossed + start an erase path that
        // pixel-clears the legacy annotation bitmap (baked-in old drawings).
        notifier.eraseMarksAt(canvas);
        notifier.startAnnotationStroke(canvas, erase: true);
      case BattleMapTool.rect:
        notifier.startShapeDraft(canvas, ShapeKind.rect);
      case BattleMapTool.line:
        notifier.startShapeDraft(canvas, ShapeKind.line);
      case BattleMapTool.text:
        break; // tap-driven (handled in onTapUp)
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
      case BattleMapTool.aoeCone:
      case BattleMapTool.aoeLine:
      case BattleMapTool.aoeCircle:
      case BattleMapTool.aoeSquare:
      case BattleMapTool.aoeSector:
        notifier.updateMeasurement(canvas);
      case BattleMapTool.eraseMark:
        notifier.eraseMarksAt(canvas);
        notifier.continueAnnotationStroke(canvas);
      case BattleMapTool.rect:
      case BattleMapTool.line:
        notifier.updateShapeDraft(canvas);
      case BattleMapTool.text:
        break; // tap-driven
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
      case BattleMapTool.aoeCone:
      case BattleMapTool.aoeLine:
      case BattleMapTool.aoeCircle:
      case BattleMapTool.aoeSquare:
      case BattleMapTool.aoeSector:
        notifier.commitMeasurement();
      case BattleMapTool.eraseMark:
        await notifier
            .commitEraseStroke(); // DM-cosmetic bitmap clear; vector deletes already synced live
      case BattleMapTool.rect:
      case BattleMapTool.line:
        notifier.commitShapeDraft();
      case BattleMapTool.text:
        break; // tap-driven
      case BattleMapTool.navigate:
        break;
    }
  }

  /// Tap handler for the tap-driven tools. Navigate deletes the nearest mark;
  /// polygon appends a vertex (closing when tapping near the first); text opens
  /// a dialog and places a label at the tapped point.
  Future<void> _handleTapUp(
      Offset localPos, BattleMapNotifier notifier, BattleMapTool activeTool) async {
    final canvas = notifier.screenToCanvas(localPos);
    switch (activeTool) {
      case BattleMapTool.navigate:
        notifier.deleteMeasurementAt(canvas);
      case BattleMapTool.text:
        final text = await _showTextShapeDialog();
        if (!mounted || text == null || text.trim().isEmpty) return;
        notifier.addTextShape(canvas, text);
      default:
        break;
    }
  }

  /// Single-field dialog for the text-label tool. Returns the entered string,
  /// or null if cancelled / empty.
  Future<String?> _showTextShapeDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Label text'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Token context menu (damage / heal / hide / resize)
  // -------------------------------------------------------------------------

  void _showTokenMenu(
    String id,
    BattleMapState mapState,
    BattleMapNotifier notifier,
  ) {
    var amount = 5;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // Read the notifier FRESH on every rebuild/press — never capture it.
          // combatProvider rebuilds on campaignRevisionProvider bumps (a CDC
          // echo from our own save fires one), disposing the old notifier; a
          // captured reference would throw "used after dispose".
          final enc = ref.read(combatProvider).activeEncounter;
          Combatant? c;
          if (enc != null) {
            for (final x in enc.combatants) {
              if (x.id == id) {
                c = x;
                break;
              }
            }
          }
          if (c == null) return const SizedBox.shrink();
          final hidden = enc!.hiddenTokenIds.contains(id);

          void quick(int delta) {
            ref.read(combatProvider.notifier).modifyHp(id, delta);
            setLocal(() {});
          }

          return AlertDialog(
            title: Text(c.name, overflow: TextOverflow.ellipsis),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'HP  ${c.hp} / ${c.maxHp}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$amount',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => amount = int.tryParse(v)?.abs() ?? 0,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => quick(-amount),
                        child: const Text('Damage'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => quick(amount),
                        child: const Text('Heal'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(combatProvider.notifier).toggleTokenHidden(id);
                          setLocal(() {});
                        },
                        icon: Icon(
                          hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                        label: Text(hidden ? 'Reveal' : 'Hide'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showResizeDialog(id, mapState, notifier);
                        },
                        icon: const Icon(Icons.aspect_ratio),
                        label: const Text('Resize'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Token resize dialog
  // -------------------------------------------------------------------------

  void _showResizeDialog(String id, BattleMapState mapState, BattleMapNotifier notifier) {
    // Seed from the effective multiplier so a Large creature opens showing its
    // auto ~2× footprint rather than 1×.
    String? entityId;
    final enc = ref.read(combatProvider).activeEncounter;
    if (enc != null) {
      for (final c in enc.combatants) {
        if (c.id == id) {
          entityId = c.entityId;
          break;
        }
      }
    }
    var multiplier = _effectiveSizeMultiplier(id, entityId, mapState);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token Size Multiplier'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${multiplier.toStringAsFixed(2)}x'),
              Slider(
                value: multiplier.clamp(0.25, 4.0),
                min: 0.25,
                max: 4.0,
                divisions: 15,
                onChanged: (v) => setDialogState(() => multiplier = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.setTokenSizeMultiplier(id, multiplier);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
