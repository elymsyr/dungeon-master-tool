/// A serializable snapshot of a battle map state, sized for IPC transport
/// to the player sub-window. Excludes ui.Image/Path objects — only file
/// paths, base64 fog bitmap, and primitive token data.
///
/// The DM side rebuilds this snapshot whenever the active battle map
/// projection's underlying combat/battle-map state changes; the player side
/// decodes it once per push and renders.
class BattleMapSnapshot {
  /// Background map image path (loaded from disk in the sub-isolate).
  final String? mapPath;

  /// Pre-rendered fog of war PNG, base64-encoded. Same format the encounter
  /// stores in `Encounter.fogData`. Decoded once on receipt.
  final String? fogDataBase64;

  /// Logical canvas dimensions (used by the player view to scale fog/tokens).
  final int canvasWidth;
  final int canvasHeight;

  /// Grid settings.
  final int gridSize;
  final bool gridVisible;
  final int feetPerCell;

  /// Token sizing.
  final int tokenSize;
  final Map<String, double> tokenSizeMultipliers;

  /// All combatants with their canvas-space positions and visual data.
  final List<TokenSnapshot> tokens;

  /// Index of the active turn (-1 if none).
  final int turnIndex;

  /// Committed annotation strokes (the Draw tool). Each stroke is a polyline
  /// in canvas-space coordinates. Erase strokes are NOT projected — the
  /// player only sees what the DM has chosen to reveal.
  final List<StrokeSnapshot> strokes;

  /// Persistent measurement marks (ruler + circle). Active in-progress
  /// measurements are NOT projected — only commit-time state.
  final List<MeasurementSnapshot> measurements;

  /// What part of the canvas the player should display, expressed as a
  /// rect in **normalized** 0..1 canvas coordinates `(left, top, w, h)`.
  /// `null` means "fit the entire canvas to the player viewport".
  ///
  /// The player view uses this rect to compute its own scale + offset
  /// (via BoxFit.contain semantics) — so DM and player can have completely
  /// different physical viewport aspect ratios and still mirror in proportion.
  final NormalizedRect? viewportNormalized;

  const BattleMapSnapshot({
    this.mapPath,
    this.fogDataBase64,
    this.canvasWidth = 2048,
    this.canvasHeight = 2048,
    this.gridSize = 50,
    this.gridVisible = false,
    this.feetPerCell = 5,
    this.tokenSize = 50,
    this.tokenSizeMultipliers = const {},
    this.tokens = const [],
    this.turnIndex = -1,
    this.strokes = const [],
    this.measurements = const [],
    this.viewportNormalized,
  });

  BattleMapSnapshot copyWith({
    String? mapPath,
    String? fogDataBase64,
    int? canvasWidth,
    int? canvasHeight,
    int? gridSize,
    bool? gridVisible,
    int? feetPerCell,
    int? tokenSize,
    Map<String, double>? tokenSizeMultipliers,
    List<TokenSnapshot>? tokens,
    int? turnIndex,
    List<StrokeSnapshot>? strokes,
    List<MeasurementSnapshot>? measurements,
    NormalizedRect? viewportNormalized,
    bool clearViewport = false,
    bool clearFog = false,
  }) {
    return BattleMapSnapshot(
      mapPath: mapPath ?? this.mapPath,
      fogDataBase64: clearFog ? null : (fogDataBase64 ?? this.fogDataBase64),
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      gridSize: gridSize ?? this.gridSize,
      gridVisible: gridVisible ?? this.gridVisible,
      feetPerCell: feetPerCell ?? this.feetPerCell,
      tokenSize: tokenSize ?? this.tokenSize,
      tokenSizeMultipliers: tokenSizeMultipliers ?? this.tokenSizeMultipliers,
      tokens: tokens ?? this.tokens,
      turnIndex: turnIndex ?? this.turnIndex,
      strokes: strokes ?? this.strokes,
      measurements: measurements ?? this.measurements,
      viewportNormalized: clearViewport
          ? null
          : (viewportNormalized ?? this.viewportNormalized),
    );
  }

  Map<String, dynamic> toJson() => {
        if (mapPath != null) 'mapPath': mapPath,
        if (fogDataBase64 != null) 'fogDataBase64': fogDataBase64,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'gridSize': gridSize,
        'gridVisible': gridVisible,
        'feetPerCell': feetPerCell,
        'tokenSize': tokenSize,
        'tokenSizeMultipliers': tokenSizeMultipliers,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'turnIndex': turnIndex,
        if (strokes.isNotEmpty)
          'strokes': strokes.map((s) => s.toJson()).toList(),
        if (measurements.isNotEmpty)
          'measurements': measurements.map((m) => m.toJson()).toList(),
        if (viewportNormalized != null)
          'viewportNormalized': viewportNormalized!.toJson(),
      };

  factory BattleMapSnapshot.fromJson(Map<String, dynamic> json) {
    return BattleMapSnapshot(
      mapPath: json['mapPath'] as String?,
      fogDataBase64: json['fogDataBase64'] as String?,
      canvasWidth: json['canvasWidth'] as int? ?? 2048,
      canvasHeight: json['canvasHeight'] as int? ?? 2048,
      gridSize: json['gridSize'] as int? ?? 50,
      gridVisible: json['gridVisible'] as bool? ?? false,
      feetPerCell: json['feetPerCell'] as int? ?? 5,
      tokenSize: json['tokenSize'] as int? ?? 50,
      tokenSizeMultipliers:
          (json['tokenSizeMultipliers'] as Map?)?.map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ) ??
              const {},
      tokens: (json['tokens'] as List?)
              ?.map((e) => TokenSnapshot.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      turnIndex: json['turnIndex'] as int? ?? -1,
      strokes: (json['strokes'] as List?)
              ?.map((e) => StrokeSnapshot.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      measurements: (json['measurements'] as List?)
              ?.map((e) => MeasurementSnapshot.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      viewportNormalized: json['viewportNormalized'] != null
          ? NormalizedRect.fromJson(
              (json['viewportNormalized'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// JSON-clean polyline stroke. The DM rebuilds these from `DrawStroke.rawPoints`
/// when the user finishes a draw gesture.
class StrokeSnapshot {
  /// Flat point list — `[x0, y0, x1, y1, ...]` in canvas-space coordinates.
  /// Flat encoding keeps the JSON payload smaller than nested arrays.
  final List<double> points;
  final String colorHex;
  final double width;

  const StrokeSnapshot({
    required this.points,
    this.colorHex = '#ff0000',
    this.width = 4,
  });

  Map<String, dynamic> toJson() => {
        'p': points,
        'c': colorHex,
        'w': width,
      };

  factory StrokeSnapshot.fromJson(Map<String, dynamic> json) => StrokeSnapshot(
        points: (json['p'] as List).map((e) => (e as num).toDouble()).toList(),
        colorHex: json['c'] as String? ?? '#ff0000',
        width: (json['w'] as num?)?.toDouble() ?? 4,
      );
}

/// JSON-clean ruler/circle measurement. Two endpoints in canvas space.
class MeasurementSnapshot {
  /// `'ruler'` or `'circle'`.
  final String type;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const MeasurementSnapshot({
    required this.type,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  Map<String, dynamic> toJson() => {
        't': type,
        'a': [x1, y1],
        'b': [x2, y2],
      };

  factory MeasurementSnapshot.fromJson(Map<String, dynamic> json) {
    final a = (json['a'] as List).map((e) => (e as num).toDouble()).toList();
    final b = (json['b'] as List).map((e) => (e as num).toDouble()).toList();
    return MeasurementSnapshot(
      type: json['t'] as String,
      x1: a[0],
      y1: a[1],
      x2: b[0],
      y2: b[1],
    );
  }
}

/// JSON-clean rect in normalized 0..1 coordinates. Used for cross-isolate
/// viewport sync — `dart:ui` Rect isn't directly JSON-serializable in a
/// stable way across the isolate boundary, so we use a primitive struct.
class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'w': width,
        'h': height,
      };

  factory NormalizedRect.fromJson(Map<String, dynamic> json) => NormalizedRect(
        left: (json['l'] as num).toDouble(),
        top: (json['t'] as num).toDouble(),
        width: (json['w'] as num).toDouble(),
        height: (json['h'] as num).toDouble(),
      );
}

class TokenSnapshot {
  final String id;
  final String name;
  final double x;
  final double y;
  final String? imagePath;

  /// Hex color (e.g. '#aabbcc') for the token border / fill fallback.
  final String colorHex;

  /// True for player-controlled tokens (rendered with HP visible).
  final bool isPlayer;

  /// Combat stats — used by the player-window initiative side panel.
  final int hp;
  final int maxHp;
  final int init;

  /// Active conditions with their remaining turn counts. `turns == null`
  /// means an indefinite/passive condition.
  final List<ConditionSnapshot> conditions;

  const TokenSnapshot({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.imagePath,
    this.colorHex = '#888888',
    this.isPlayer = false,
    this.hp = 0,
    this.maxHp = 0,
    this.init = 0,
    this.conditions = const [],
  });

  /// Backwards-compat helper used by older call sites that only need names.
  List<String> get conditionNames => [for (final c in conditions) c.name];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        if (imagePath != null) 'imagePath': imagePath,
        'colorHex': colorHex,
        'isPlayer': isPlayer,
        'hp': hp,
        'maxHp': maxHp,
        'init': init,
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };

  factory TokenSnapshot.fromJson(Map<String, dynamic> json) => TokenSnapshot(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        imagePath: json['imagePath'] as String?,
        colorHex: json['colorHex'] as String? ?? '#888888',
        isPlayer: json['isPlayer'] as bool? ?? false,
        hp: (json['hp'] as num?)?.toInt() ?? 0,
        maxHp: (json['maxHp'] as num?)?.toInt() ?? 0,
        init: (json['init'] as num?)?.toInt() ?? 0,
        conditions: (json['conditions'] as List?)
                ?.map((e) =>
                    ConditionSnapshot.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            // Legacy payload used a flat string list under `conditionNames`.
            ((json['conditionNames'] as List?)
                    ?.map((e) => ConditionSnapshot(name: e as String))
                    .toList() ??
                const []),
      );
}

/// One active combat condition projected to the player. `turns == null`
/// for indefinite conditions; otherwise it's the remaining round count.
class ConditionSnapshot {
  final String name;
  final int? turns;
  /// Absolute path to the condition entity's first image, if any. Loaded
  /// once on the player side and cached so condition badges show their
  /// art.
  final String? imagePath;

  const ConditionSnapshot({required this.name, this.turns, this.imagePath});

  Map<String, dynamic> toJson() => {
        'n': name,
        if (turns != null) 't': turns,
        if (imagePath != null) 'i': imagePath,
      };

  factory ConditionSnapshot.fromJson(Map<String, dynamic> json) =>
      ConditionSnapshot(
        name: json['n'] as String? ?? json['name'] as String? ?? '',
        turns: (json['t'] as num?)?.toInt(),
        imagePath: json['i'] as String?,
      );
}
