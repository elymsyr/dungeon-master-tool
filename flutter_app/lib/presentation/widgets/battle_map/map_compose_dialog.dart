import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// Where the DM placed the added map, in the base map's pixel space. [rect]
/// may extend past the base (negative or beyond its size) — the composite
/// canvas grows to the union.
typedef MapPlacement = ({Rect rect, bool below});

/// Lets the DM drag/resize [overlay] over [base] and pick whether it sits on
/// top of or underneath the current map. Returns null on cancel.
Future<MapPlacement?> showMapComposeDialog(
  BuildContext context, {
  required ui.Image base,
  required ui.Image overlay,
}) {
  return showDialog<MapPlacement>(
    context: context,
    builder: (_) => _MapComposeDialog(base: base, overlay: overlay),
  );
}

class _MapComposeDialog extends StatefulWidget {
  final ui.Image base;
  final ui.Image overlay;

  const _MapComposeDialog({required this.base, required this.overlay});

  @override
  State<_MapComposeDialog> createState() => _MapComposeDialogState();
}

class _MapComposeDialogState extends State<_MapComposeDialog> {
  late double _scale;
  late Offset _center; // overlay center, base pixel space
  bool _below = false;

  // Preview view transform: screen = _origin + (p - region.topLeft) * _k * _zoom + _pan
  double _k = 1; // fits the region into the preview box at _zoom == 1
  Offset _origin = Offset.zero;
  double _zoom = 1;
  Offset _pan = Offset.zero;

  // Active gesture.
  bool _movingOverlay = false;
  double _zoomStart = 1;
  Offset _anchor = Offset.zero; // region point under the focal at gesture start

  Size get _baseSize =>
      Size(widget.base.width.toDouble(), widget.base.height.toDouble());
  Size get _overlaySize =>
      Size(widget.overlay.width.toDouble(), widget.overlay.height.toDouble());

  /// Editable area: the base map plus half its size on every side, so the
  /// new map can be placed beside it as well as over it.
  Rect get _region {
    final b = _baseSize;
    final m = math.max(b.width, b.height) / 2;
    return Rect.fromLTWH(-m, -m, b.width + 2 * m, b.height + 2 * m);
  }

  Rect get _overlayRect => Rect.fromCenter(
        center: _center,
        width: _overlaySize.width * _scale,
        height: _overlaySize.height * _scale,
      );

  @override
  void initState() {
    super.initState();
    final b = _baseSize;
    final o = _overlaySize;
    // Native pixel size keeps grids aligned when both maps share a scale;
    // shrink only if it would not fit on the base.
    _scale = math.min(1.0, math.min(b.width / o.width, b.height / o.height));
    _center = b.center(Offset.zero);
  }

  void _setScale(double v) =>
      setState(() => _scale = (v * 100).round().clamp(5, 400) / 100);

  Offset _toRegion(Offset screen) =>
      (screen - _origin - _pan) / (_k * _zoom) + _region.topLeft;

  /// Keeps [regionPt] under [screen] at [zoom].
  void _viewAt(Offset regionPt, Offset screen, double zoom) {
    _zoom = zoom.clamp(1.0, 10.0);
    _pan = screen - _origin - (regionPt - _region.topLeft) * _k * _zoom;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _anchor = _toRegion(d.localFocalPoint);
    _zoomStart = _zoom;
    _movingOverlay = d.pointerCount == 1 && _overlayRect.contains(_anchor);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (_movingOverlay) {
        final region = _region;
        final p = _center + d.focalPointDelta / (_k * _zoom);
        _center = Offset(
          p.dx.clamp(region.left, region.right),
          p.dy.clamp(region.top, region.bottom),
        );
      } else {
        _viewAt(_anchor, d.localFocalPoint, _zoomStart * d.scale);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final screen = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(l10n.bmComposeTitle, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: math.min(900, screen.width * 0.9),
        height: math.min(700, screen.height * 0.7),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final region = _region;
                _k = math.min(
                  c.maxWidth / region.width,
                  c.maxHeight / region.height,
                );
                _origin = Offset(
                  (c.maxWidth - region.width * _k) / 2,
                  (c.maxHeight - region.height * _k) / 2,
                );
                return Listener(
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) {
                      setState(() => _viewAt(
                            _toRegion(e.localPosition),
                            e.localPosition,
                            _zoom * (e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12),
                          ));
                    }
                  },
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    child: ClipRRect(
                      borderRadius: palette.cbr,
                      child: CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _ComposePainter(
                          base: widget.base,
                          overlay: widget.overlay,
                          region: region,
                          offset: _origin + _pan,
                          scale: _k * _zoom,
                          overlayRect: _overlayRect,
                          below: _below,
                          outline: palette.tabIndicator,
                          backdrop: palette.sidebarLabelSecondary
                              .withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bmComposeHint,
              style: TextStyle(fontSize: 12, color: palette.tabText),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                SegmentedButton<bool>(
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: palette.cbr),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.flip_to_front),
                      label: Text(l10n.bmComposeOnTop),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.flip_to_back),
                      label: Text(l10n.bmComposeBelow),
                    ),
                  ],
                  selected: {_below},
                  onSelectionChanged: (s) => setState(() => _below = s.first),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.bmComposeSize),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _setScale(_scale - 0.01),
                    ),
                    SizedBox(
                      width: 200,
                      child: Slider(
                        min: 0.05,
                        max: 4.0,
                        value: _scale,
                        onChanged: _setScale,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _setScale(_scale + 0.01),
                    ),
                    Text('${(_scale * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (rect: _overlayRect, below: _below)),
          child: Text(l10n.bmComposeApply),
        ),
      ],
    );
  }
}

class _ComposePainter extends CustomPainter {
  final ui.Image base;
  final ui.Image overlay;
  final Rect region;
  final Offset offset;
  final double scale;
  final Rect overlayRect;
  final bool below;
  final Color outline;
  final Color backdrop;

  _ComposePainter({
    required this.base,
    required this.overlay,
    required this.region,
    required this.offset,
    required this.scale,
    required this.overlayRect,
    required this.below,
    required this.outline,
    required this.backdrop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backdrop);
    final k = scale;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(k);
    canvas.translate(-region.left, -region.top);
    final img = Paint()..filterQuality = FilterQuality.medium;
    void drawOverlay() => canvas.drawImageRect(
          overlay,
          Offset.zero &
              Size(overlay.width.toDouble(), overlay.height.toDouble()),
          overlayRect,
          img,
        );
    if (below) drawOverlay();
    canvas.drawImage(base, Offset.zero, img);
    if (!below) drawOverlay();
    canvas.drawRect(
      overlayRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / k
        ..color = outline,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ComposePainter old) =>
      old.overlayRect != overlayRect ||
      old.below != below ||
      old.region != region ||
      old.offset != offset ||
      old.scale != scale ||
      old.outline != outline;
}
