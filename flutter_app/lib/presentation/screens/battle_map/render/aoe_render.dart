// Shared AoE-template rendering core for the two battle-map painters
// (DM `BattleMapPainter` + player `_BattleMapProjectionPainter`). Pure:
// screen-space `Path` + `Color` in, draws on the passed `Canvas`. Holds NO
// coordinate/transform/label/fog/grid/token logic — those stayed per-painter
// (they drifted on purpose). This module exists only to delete the duplicated
// hex→Color memo + fill/stroke draw that both painters carried verbatim.
//
// Phase 6 adds the shared vector-shape draw (`drawVectorShape` / `drawShapeLabel`)
// — both painters project their own points (DM canvas-space or `_toScreen`,
// player baked `dx + x*scale`) and pass already-scaled stroke/font sizes, so the
// geometry + paint stay identical across surfaces while the transforms drift.
import 'package:flutter/material.dart';

import '../../../../domain/value_objects/grid_distance.dart';
import '../../../../domain/value_objects/map_shape.dart';

/// Cross-painter hex→Color memo. Replaces the painters' previously-separate
/// `_aoeColorCache` (DM) and `_hexCache` (player) — identical bodies, now one
/// insert-only map (idempotent `putIfAbsent`, no eviction, tiny bounded key
/// set). Top-level so it survives each painter's per-frame reconstruction.
final Map<String, Color> _hexColorCache = {};

/// Parse `'#rrggbb'` / `'#aarrggbb'` (with or without `#`) to a [Color],
/// memoized. 6-digit input is treated as fully opaque (`FF` prefix). Exact
/// port of both painters' prior lambda — no behavior change. Callers resolve
/// their own default/fallback hex BEFORE calling (DM uses `defaultAoeColorHex`,
/// player a literal `#ff9800`); keeping that caller-side preserves the
/// intentional per-tool-default drift between the two surfaces.
Color hexToColor(String hex) => _hexColorCache.putIfAbsent(hex, () {
      var clean = hex.replaceFirst('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    });

/// Fill + stroke an AoE shape using the caller's two reusable Paints, so each
/// painter keeps its existing allocation lifetime (DM instance fields, player
/// per-`paint()` locals) and its own `stroke.strokeWidth` (DM 2, player
/// `compact ? 1.2 : 2`). Mutates only `fill.color` (at [fillAlpha]) and
/// `stroke.color`. Draws NO label — labels differ between painters, so each
/// draws its own after calling this.
void drawAoeShape(
  Canvas canvas,
  Path path,
  Color color,
  Paint fill,
  Paint stroke, {
  double fillAlpha = 0.25,
}) {
  fill.color = color.withValues(alpha: fillAlpha);
  canvas.drawPath(path, fill);
  stroke.color = color;
  canvas.drawPath(path, stroke);
}

/// Draws one Phase 6 vector shape. [pts] are ALREADY projected to the target
/// space (DM canvas/screen, player baked); [strokeWidth] + [fontSize] are
/// ALREADY scaled by the caller's transform. Reuses the caller's [fill]/[stroke]
/// Paints (DM instance fields, player per-`paint()` locals). Text shapes route
/// to [drawShapeLabel].
void drawVectorShape(
  Canvas canvas, {
  required ShapeKind kind,
  required List<Offset> pts,
  required Color color,
  required bool filled,
  required double strokeWidth,
  String? text,
  double? fontSize,
  required Paint fill,
  required Paint stroke,
}) {
  switch (kind) {
    case ShapeKind.rect:
      if (pts.length < 2) return;
      _strokeOrFill(canvas, rectPath(pts[0], pts[1]), color, filled, strokeWidth,
          fill, stroke);
    case ShapeKind.line:
      if (pts.length < 2) return;
      stroke
        ..color = color
        ..strokeWidth = strokeWidth;
      canvas.drawLine(pts[0], pts[1], stroke);
    case ShapeKind.polygon:
      if (pts.length < 2) return;
      _strokeOrFill(canvas, polygonPath(pts, closed: pts.length > 2), color,
          filled && pts.length > 2, strokeWidth, fill, stroke);
    case ShapeKind.text:
      if (pts.isEmpty || text == null || text.isEmpty) return;
      drawShapeLabel(canvas, pts.first, text, color, fontSize ?? 14);
  }
}

void _strokeOrFill(Canvas canvas, Path path, Color color, bool filled,
    double strokeWidth, Paint fill, Paint stroke) {
  if (filled) {
    fill.color = color.withValues(alpha: 0.25);
    canvas.drawPath(path, fill);
  }
  stroke
    ..color = color
    ..strokeWidth = strokeWidth;
  canvas.drawPath(path, stroke);
}

/// Draws a shape's text label anchored top-left at [at] (already projected),
/// at the already-scaled [fontSize], with the standard black shadow used by the
/// other map labels.
void drawShapeLabel(
    Canvas canvas, Offset at, String text, Color color, double fontSize) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at);
}
