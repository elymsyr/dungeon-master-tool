// Shared AoE-template rendering core for the two battle-map painters
// (DM `BattleMapPainter` + player `_BattleMapProjectionPainter`). Pure:
// screen-space `Path` + `Color` in, draws on the passed `Canvas`. Holds NO
// coordinate/transform/label/fog/grid/token logic — those stayed per-painter
// (they drifted on purpose). This module exists only to delete the duplicated
// hex→Color memo + fill/stroke draw that both painters carried verbatim.
import 'dart:ui';

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
