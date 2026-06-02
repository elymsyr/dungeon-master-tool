import 'dart:ui';

/// Geometric vector shapes placed on the battle map (VTT Phase 6). Distinct
/// from freehand strokes (`DrawStroke`) and AoE measurement marks
/// (`MeasurementMark`) — these are persistent, individually-deletable
/// annotations stored in the encounter's versioned scene blob
/// (`Encounter.sceneVectorJson`) and projected to players via `ShapeSnapshot`.
///
/// All coordinates are CANVAS-space; each painter projects them to screen.

/// Kind of geometric shape. Index is stable (persisted) — append only.
enum ShapeKind { rect, line, polygon, text }

ShapeKind shapeKindFromInt(int v) =>
    (v >= 0 && v < ShapeKind.values.length) ? ShapeKind.values[v] : ShapeKind.rect;

/// Drawing layer / z-band. Index is stable (persisted) — append only.
/// `gm` shapes are DM-only: they never leave the DM (filtered send-side, like
/// hidden tokens / erase strokes), so a `ShapeSnapshot` only ever carries
/// `background` or `object`.
enum ShapeLayer { background, object, gm }

ShapeLayer shapeLayerFromInt(int v) =>
    (v >= 0 && v < ShapeLayer.values.length) ? ShapeLayer.values[v] : ShapeLayer.object;

/// Fixed default stroke color per layer (no per-shape picker in v1; the
/// `colorHex` field is stored so a picker can be added additively later).
String defaultShapeColorHex(ShapeLayer layer) {
  switch (layer) {
    case ShapeLayer.background:
      return '#66bb6a'; // green
    case ShapeLayer.object:
      return '#ffca28'; // amber
    case ShapeLayer.gm:
      return '#ef5350'; // red
  }
}

class MapShape {
  final String id;
  final ShapeKind kind;
  final ShapeLayer layer;

  /// Canvas-space vertices. `rect`/`line` = two points; `polygon` = N vertices
  /// (>=3, implicitly closed); `text` = a single anchor point.
  final List<Offset> points;
  final String colorHex;
  final double strokeWidth;
  final bool filled;

  /// `text` kind only.
  final String? text;

  /// `text` kind only — font size in CANVAS units (×scale at paint time so the
  /// label zooms with the map).
  final double? fontSize;

  const MapShape({
    required this.id,
    required this.kind,
    required this.layer,
    required this.points,
    this.colorHex = '#ffca28',
    this.strokeWidth = 2,
    this.filled = false,
    this.text,
    this.fontSize,
  });

  MapShape copyWith({
    String? id,
    ShapeKind? kind,
    ShapeLayer? layer,
    List<Offset>? points,
    String? colorHex,
    double? strokeWidth,
    bool? filled,
    String? text,
    double? fontSize,
  }) =>
      MapShape(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        layer: layer ?? this.layer,
        points: points ?? this.points,
        colorHex: colorHex ?? this.colorHex,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        filled: filled ?? this.filled,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind.index,
        'l': layer.index,
        'p': [for (final pt in points) ...[pt.dx, pt.dy]],
        'c': colorHex,
        'w': strokeWidth,
        if (filled) 'f': true,
        if (text != null) 't': text,
        if (fontSize != null) 'fs': fontSize,
      };

  factory MapShape.fromJson(Map<String, dynamic> json) {
    final flat =
        (json['p'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
            const <double>[];
    final pts = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(flat[i], flat[i + 1]));
    }
    return MapShape(
      id: json['id'] as String? ?? '',
      kind: shapeKindFromInt((json['k'] as num?)?.toInt() ?? 0),
      layer: shapeLayerFromInt((json['l'] as num?)?.toInt() ?? 1),
      points: pts,
      colorHex: json['c'] as String? ?? '#ffca28',
      strokeWidth: (json['w'] as num?)?.toDouble() ?? 2,
      filled: json['f'] as bool? ?? false,
      text: json['t'] as String?,
      fontSize: (json['fs'] as num?)?.toDouble(),
    );
  }
}
