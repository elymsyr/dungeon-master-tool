import 'dart:ui';

// Freehand stroke geometry shared by the mind map pen, the battle map pen and
// the token movement trails (DM and player).

/// Smooth path through [pts]: quadratic segments between midpoints, so raw
/// pointer samples never show as corners.
Path buildStrokePath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// Ramer–Douglas–Peucker: drops points that lie within [eps] of the line
/// through their neighbours. Shape is kept to [eps]; the saved stroke (and
/// the synced blob) shrinks several-fold.
List<Offset> simplifyStroke(List<Offset> pts, double eps) {
  if (pts.length < 3) return List.of(pts);
  final keep = List<bool>.filled(pts.length, false)
    ..[0] = true
    ..[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    final ab = pts[b] - pts[a];
    final len = ab.distance;
    var maxD = 0.0;
    var idx = -1;
    for (var i = a + 1; i < b; i++) {
      final ap = pts[i] - pts[a];
      final d = len == 0
          ? ap.distance
          : (ab.dx * ap.dy - ab.dy * ap.dx).abs() / len;
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx >= 0 && maxD > eps) {
      keep[idx] = true;
      stack
        ..add((a, idx))
        ..add((idx, b));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}
