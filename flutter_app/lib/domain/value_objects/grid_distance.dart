import 'dart:math' as math;
import 'dart:ui';

/// How diagonal movement is counted when measuring distance on the grid.
/// Index is stable (persisted as an int on the encounter + snapshot) — append
/// new rules at the end, never reorder.
enum DiagonalRule {
  /// True straight-line distance: `sqrt(dx² + dy²)`. The app's original
  /// behaviour and the default.
  euclidean,

  /// DMG variant: diagonals alternate 5ft / 10ft, i.e. every second diagonal
  /// step costs double. `max(dx,dy) + floor(min(dx,dy) / 2)` cells.
  fiveTenFive,

  /// PHB simple rule: every square (including diagonals) is 5ft.
  /// Chebyshev distance `max(dx, dy)` cells.
  fiveFiveFive,
}

/// Decodes the persisted int back to a [DiagonalRule], defaulting to
/// [DiagonalRule.euclidean] for unknown / out-of-range values.
DiagonalRule diagonalRuleFromInt(int v) {
  if (v >= 0 && v < DiagonalRule.values.length) return DiagonalRule.values[v];
  return DiagonalRule.euclidean;
}

/// Short human label for the rule selector.
String diagonalRuleLabel(DiagonalRule rule) {
  switch (rule) {
    case DiagonalRule.euclidean:
      return 'Euclid';
    case DiagonalRule.fiveTenFive:
      return '5-10-5';
    case DiagonalRule.fiveFiveFive:
      return '5-5-5';
  }
}

/// Distance in feet between two canvas-space points under the given 5e
/// diagonal [rule]. [gridSize] is the cell side in canvas px; [feetPerCell]
/// the in-world feet a cell represents. Returns 0 when [gridSize] <= 0.
double gridDistanceFeet(
  Offset a,
  Offset b, {
  required double gridSize,
  required double feetPerCell,
  required DiagonalRule rule,
}) {
  if (gridSize <= 0) return 0;
  final dx = (a.dx - b.dx).abs() / gridSize;
  final dy = (a.dy - b.dy).abs() / gridSize;
  switch (rule) {
    case DiagonalRule.euclidean:
      return math.sqrt(dx * dx + dy * dy) * feetPerCell;
    case DiagonalRule.fiveFiveFive:
      return math.max(dx, dy) * feetPerCell;
    case DiagonalRule.fiveTenFive:
      final hi = math.max(dx, dy);
      final lo = math.min(dx, dy);
      return (hi + (lo / 2).floorToDouble()) * feetPerCell;
  }
}

// ---------------------------------------------------------------------------
// AoE template geometry — pure functions on screen-space points so the DM
// painter and the player painter build IDENTICAL vertices (each passes its
// own already-transformed endpoints). All space-agnostic.
// ---------------------------------------------------------------------------

/// 5e cone as a filled triangle. In 5e a cone's width at any point equals its
/// distance from the origin, so the far edge half-width is `L/2` ⇒ full apex
/// angle `2·atan(0.5)` ≈ 53°. [apex] is the origin, [far] the cursor point.
Path aoeConePath(Offset apex, Offset far) {
  final v = far - apex;
  final len = v.distance;
  final path = Path()..moveTo(apex.dx, apex.dy);
  if (len < 0.01) return path..close();
  final dir = v / len;
  final perp = Offset(-dir.dy, dir.dx);
  final mid = apex + dir * len;
  final p1 = mid + perp * (len / 2);
  final p2 = mid - perp * (len / 2);
  return path
    ..lineTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..close();
}

/// 5e line as a rotated rectangle from [start] to [end] with the given
/// [width] (in the same space as the points — i.e. one cell = 5ft wide).
Path aoeLinePath(Offset start, Offset end, double width) {
  final v = end - start;
  final len = v.distance;
  final path = Path();
  if (len < 0.01) return path;
  final dir = v / len;
  final perp = Offset(-dir.dy, dir.dx) * (width / 2);
  final a = start + perp;
  final b = end + perp;
  final c = end - perp;
  final d = start - perp;
  return path
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..lineTo(d.dx, d.dy)
    ..close();
}

/// Circular sector ("kesik daire" / pie wedge): radius `|end-center|`, swept
/// [sweepDeg] degrees CENTERED on the center→end direction. Built as a
/// closed wedge (center → arc → center) so it fills like a pie slice.
Path aoeSectorPath(Offset center, Offset edge, double sweepDeg) {
  final v = edge - center;
  final r = v.distance;
  final path = Path()..moveTo(center.dx, center.dy);
  if (r < 0.01) return path..close();
  final baseAng = math.atan2(v.dy, v.dx);
  final sweepRad = sweepDeg * math.pi / 180.0;
  final startAng = baseAng - sweepRad / 2;
  // arcTo (forceMoveTo: false) draws center→arc-start, then the arc; close()
  // joins arc-end back to center.
  path.arcTo(Rect.fromCircle(center: center, radius: r), startAng, sweepRad, false);
  return path..close();
}

/// 5e cube as an axis-aligned square. One corner anchored at [start], the
/// square grows toward [end]'s quadrant; side = `max(|dx|, |dy|)`.
Rect aoeSquareRect(Offset start, Offset end) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final side = math.max(dx.abs(), dy.abs());
  final left = dx >= 0 ? start.dx : start.dx - side;
  final top = dy >= 0 ? start.dy : start.dy - side;
  return Rect.fromLTWH(left, top, side, side);
}

// ---------------------------------------------------------------------------
// Generic vector-shape geometry (Phase 6). Pure, space-agnostic — callers pass
// already-projected points so both painters build identical vertices.
// ---------------------------------------------------------------------------

/// Axis-aligned rectangle from two opposite corners (any space).
Path rectPath(Offset a, Offset b) => Path()..addRect(Rect.fromPoints(a, b));

/// Polyline through [points] (any space). When [closed] (and >2 points) the
/// last vertex joins back to the first (polygon); otherwise it stays open
/// (multi-segment line). Empty input yields an empty path.
Path polygonPath(List<Offset> points, {bool closed = true}) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  if (closed && points.length > 2) path.close();
  return path;
}
