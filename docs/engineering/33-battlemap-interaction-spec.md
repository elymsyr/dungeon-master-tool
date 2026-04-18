# 33 — Battlemap Interaction Spec

> **For Claude.** Pan/zoom, token drag, drawing tools, measurement, AoE placement, fog brushes. Touch vs mouse vs stylus.
> **Existing:** [battle_map_painter.dart:27](../../flutter_app/lib/presentation/screens/battle_map/battle_map_painter.dart#L27), 6-layer render, ViewTransform with ValueNotifier.
> **Target:** `flutter_app/lib/presentation/screens/dnd5e/battlemap/`

## Tool Palette

```dart
enum BattleMapTool {
  pan,             // default
  select,          // pick token to inspect/move
  drawFreehand,
  drawLine,
  drawShape,       // rectangle/circle
  drawText,
  erase,           // erase strokes
  measureRuler,
  measureCircle,
  fogBrush,        // DM only
  fogReveal,       // DM only (eraser for fog)
  aoePreview,      // active during spell cast flow
}
```

Tools per role:

| Tool | DM | Player |
|---|---|---|
| Pan, select | ✓ | ✓ |
| Draw* | ✓ | ✓ (own strokes only) |
| Erase | ✓ (any stroke) | ✓ (own strokes only) |
| Measure | ✓ | ✓ |
| Fog | ✓ | ✗ |
| AoE preview | ✓ | ✓ (during cast flow) |

## Pan & Zoom

```dart
class ViewportController {
  final ValueNotifier<ViewTransform> transform;

  void pan(Offset delta) { /* update transform.translation */ }
  void zoom(double scale, Offset focal) { /* update transform.scale around focal */ }
  void resetView() { /* center map at fit-to-screen */ }
  void centerOn(GridCell cell) { /* animate to cell */ }
}

class ViewTransform {
  final Offset translation;
  final double scale;       // 0.1 to 10.0
}
```

### Gesture Bindings

| Action | Touch | Mouse | Stylus |
|---|---|---|---|
| Pan | 2-finger drag | middle-click drag OR space+left-drag | 2-finger drag (palm rejection) |
| Zoom | pinch | scroll wheel (around cursor) | pinch |
| Pan from any tool | 2-finger drag | middle-click | 2-finger drag |

When pan tool active: 1-finger drag also pans.

### Performance

- Use `ValueListenableBuilder<ViewTransform>` to repaint only the canvas, not surrounding UI. Already implemented (see existing painter).
- Fog bitmap rendered with `Canvas.drawImage` once, transformed via `Canvas.transform` matrix. No per-frame fog redraw.
- Strokes rendered with `Canvas.drawPath` per stroke. Cached as a `Picture` per stroke; rebuilt only on stroke add/edit.

## Token Drag

```dart
class TokenInteraction {
  void onTokenDragStart(Combatant c, Offset startPos) { ... }
  void onTokenDragUpdate(Offset currentPos) {
    // Update preview overlay; show ft counter, snake-line path.
  }
  void onTokenDragEnd(Offset endPos) {
    if (role == ViewerRole.dm) {
      // DM moves token directly; persists to encounter state.
      _encounterService.moveToken(combatantId: c.id, newPos: snapToGrid(endPos));
    } else if (role == ViewerRole.player && c.id == myCombatantId) {
      // Player declares movement (per 24).
      _playerActionService.declareMovement(...);
    } else {
      // Cancel — not allowed.
    }
  }
}
```

### Snap to Grid

Configurable per encounter. When on:
- Token center snaps to nearest cell center.
- Stroke endpoints snap if within 10px of cell intersection.
- AoE origin snaps to cell center (or vertex, configurable).

### Distance Calculation

Per SRD §8.2 grid rule: count squares from adjacent square via shortest route (Chebyshev). Display: `15 ft (3 sq)`.

```dart
double distanceFt(GridCell from, GridCell to, int feetPerCell) {
  final dx = (from.col - to.col).abs();
  final dy = (from.row - to.row).abs();
  final squares = math.max(dx, dy);    // Chebyshev
  return squares * feetPerCell.toDouble();
}
```

For diagonal: SRD allows simple Chebyshev by default. Variant rule "5/10/5/10" exists; out of MVP.

## Drawing Tools

```dart
sealed class DrawingPrimitive {
  String get id;
  String get authorUserId;
  Color get color;
  double get strokeWidth;
}

class FreehandStroke extends DrawingPrimitive {
  final List<Offset> points;
}

class LineStroke extends DrawingPrimitive {
  final Offset start;
  final Offset end;
}

class ShapeStroke extends DrawingPrimitive {
  final ShapeKind kind;            // rectangle | circle
  final Offset topLeft;
  final Offset bottomRight;
}

class TextAnnotation extends DrawingPrimitive {
  final Offset position;
  final String text;
  final double fontSize;
}
```

### Per-Tool Behavior

- **Freehand:** continuous capture of pointer move events; stored as `List<Offset>`. Smoothing applied on commit (Catmull-Rom or simple douglas-peucker).
- **Line:** capture down + drag + up; preview line during drag.
- **Shape:** down + drag + up; preview rectangle/circle during drag.
- **Text:** tap → inline text editor at position.
- **Erase:** any stroke under pointer is removed (DM: any author; player: own only).

### Stylus Pressure

If `PointerEvent.kind == PointerDeviceKind.stylus`, use `pressure` to vary stroke width within `[strokeWidth * 0.5, strokeWidth * 1.5]`.

## Measurement Tools

### Ruler

Two clicks: start, end. Persistent line on map until cleared. Shows distance label.

### Circle

Click center → drag radius → release. Persistent circle with radius label.

Both auto-expire after 5 minutes (per [23](./23-battlemap-sync-protocol.md)).

## Fog of War

```dart
class FogTool {
  final FogOperation op;     // brush | reveal
  final double brushRadiusFt;
  final FogShape shape;      // circle | square
}
```

DM brushes:
- **Brush:** add fog (hide area).
- **Reveal:** remove fog (show area).
- Brush radius adjustable (5 ft default).

Implementation: paint to fog bitmap (existing `fogData` PNG approach). Composite as semi-opaque overlay on player view.

```dart
void _applyFogStroke(Offset point, double radiusFt) {
  final px = _ftToPixels(radiusFt);
  // Modify fog bitmap.
  final paint = Paint()..blendMode = (op == brush ? BlendMode.dstOver : BlendMode.clear);
  fogCanvas.drawCircle(point, px, paint);
  // Mark dirty; throttle uploads.
}
```

Throttle fog uploads (publish every 100ms during active brushing).

## AoE Preview Mode

Activated by spell cast flow ([24](./24-player-action-protocol.md)).

```dart
class AoEPreviewTool {
  final AreaOfEffect aoe;
  GridCell? origin;
  GridDirection? direction;     // for Cone/Line/Cube
  bool placed = false;
}
```

UI:
1. First tap → set origin (snaps to grid cell).
2. For Cone/Line/Cube: drag → set direction. Visual handle shown.
3. Confirm button at bottom → commits action.
4. Cancel button → exits AoE mode.

Render: translucent shape over grid. Affected cells highlighted. Affected combatant tokens get red outline.

## Selection

Tap a token (or other element):
- Token: opens compact stat card overlay (HP, AC, conditions).
- Stroke: highlights it; right-click → "Erase" or "Convert to fog stroke" (DM only).

## Right-Click / Long-Press Context Menu

| Target | Menu Items |
|---|---|
| Token | Open Sheet, Edit HP, Add Condition, Move (DM), Remove (DM) |
| Stroke | Erase, Change Color (own strokes) |
| Empty cell | Add Token (DM), Place Marker, Measure From Here |

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `1` | Pan tool |
| `2` | Select tool |
| `3` | Freehand draw |
| `4` | Line |
| `5` | Shape |
| `6` | Text |
| `7` | Erase |
| `8` | Ruler |
| `9` | Circle |
| `F` | Fog brush (DM) |
| `R` | Fog reveal (DM) |
| `+` `-` | Zoom |
| `0` | Reset view |
| `Space + drag` | Pan from any tool |
| `Esc` | Cancel current operation |
| `Delete` | Erase selected stroke |

Desktop only. Mobile: tools via bottom palette.

## Mobile UI

- Floating tool palette (bottom or side, draggable).
- Tap-to-select.
- Long-press for context menu.
- Pinch to zoom.
- Two-finger drag to pan.

## Tablet UI

- Persistent tool sidebar.
- Stylus optimized: palm rejection, pressure sensitivity.
- Two-finger drag for pan (one-finger = drawing per active tool).

## Desktop UI

- Tool palette (toolbar at top).
- Mouse + keyboard primary input.
- Hover tooltips on tools.
- Right-click context menu.
- Scroll wheel to zoom.

## Acceptance

- DM can pan/zoom on mobile + desktop with respective gestures.
- DM can draw freehand stroke; appears on player screens within 500 ms.
- DM can paint fog; player view shows updated obscured areas within 500 ms.
- Player can drag own token; DM gets movement declaration (per [24](./24-player-action-protocol.md)).
- Token movement preview shows correct ft count using Chebyshev distance.
- AoE preview correctly highlights affected cells per shape type.
- Tools selectable via keyboard shortcut on desktop.
- Stylus drawing on tablet uses pressure if available.

## Open Questions

1. Should grid be hex-supported? → Out of MVP. Square grid only.
2. Layered drawings (DM-private overlay layer)? → Yes; existing layer system supports this. Add toggle.
3. Animated tokens (e.g., "running" GIF)? → Out of MVP.
