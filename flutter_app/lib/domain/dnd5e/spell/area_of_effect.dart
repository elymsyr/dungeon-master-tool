import 'grid_cell.dart';

/// Sealed AoE shapes. Geometry on the battlemap resolves these; the spec
/// method [includesOrigin] is honored by each case.
///
/// [coverage] returns every affected [GridCell] on a 5 ft-per-cell grid.
/// Direction-agnostic shapes (Sphere, Emanation, Cylinder) ignore the
/// `direction` argument; anchored shapes (Cone, Cube, Line) use it to
/// orient the footprint. Total-cover line-of-effect filtering is the
/// caller's responsibility (SRD §Total Cover).
sealed class AreaOfEffect {
  const AreaOfEffect();

  bool includesOrigin();

  Set<GridCell> coverage(GridCell origin, GridDirection direction);
}

int _cellsFromFt(double ft) => (ft / GridCell.feetPerCell).ceil();

class ConeAoE extends AreaOfEffect {
  final double lengthFt;
  const ConeAoE._(this.lengthFt);
  factory ConeAoE(double lengthFt) {
    if (lengthFt <= 0) throw ArgumentError('ConeAoE.lengthFt must be > 0');
    return ConeAoE._(lengthFt);
  }
  @override
  bool includesOrigin() => false;

  /// SRD cone: width at distance d equals d. On a grid, row at distance k
  /// cells gets (2k + 1) cells wide, centred on the axis.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) {
    final cells = _cellsFromFt(lengthFt);
    final out = <GridCell>{};
    for (var d = 1; d <= cells; d++) {
      for (var off = -d; off <= d; off++) {
        out.add(_cellAt(origin, direction, forward: d, side: off));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is ConeAoE && other.lengthFt == lengthFt;
  @override
  int get hashCode => Object.hash('ConeAoE', lengthFt);
  @override
  String toString() => 'ConeAoE($lengthFt ft)';
}

GridCell _cellAt(
  GridCell origin,
  GridDirection dir, {
  required int forward,
  int side = 0,
}) {
  switch (dir) {
    case GridDirection.north:
      return origin.translate(side, -forward);
    case GridDirection.south:
      return origin.translate(side, forward);
    case GridDirection.east:
      return origin.translate(forward, side);
    case GridDirection.west:
      return origin.translate(-forward, side);
  }
}

class CubeAoE extends AreaOfEffect {
  final double sideFt;
  const CubeAoE._(this.sideFt);
  factory CubeAoE(double sideFt) {
    if (sideFt <= 0) throw ArgumentError('CubeAoE.sideFt must be > 0');
    return CubeAoE._(sideFt);
  }
  @override
  bool includesOrigin() => true;

  /// Anchored at [origin]; one face flush with origin, extruded N cells in
  /// [direction]. Width = N cells centred on origin axis.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) {
    final n = _cellsFromFt(sideFt);
    final half = (n - 1) ~/ 2; // centre of (N-1)-wide span, floored
    final out = <GridCell>{};
    for (var d = 0; d < n; d++) {
      for (var off = -half; off <= half + ((n - 1) % 2); off++) {
        out.add(_cellAt(origin, direction, forward: d, side: off));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is CubeAoE && other.sideFt == sideFt;
  @override
  int get hashCode => Object.hash('CubeAoE', sideFt);
  @override
  String toString() => 'CubeAoE($sideFt ft)';
}

class CylinderAoE extends AreaOfEffect {
  final double radiusFt;
  final double heightFt;
  const CylinderAoE._(this.radiusFt, this.heightFt);
  factory CylinderAoE({required double radiusFt, required double heightFt}) {
    if (radiusFt <= 0) throw ArgumentError('CylinderAoE.radiusFt must be > 0');
    if (heightFt <= 0) throw ArgumentError('CylinderAoE.heightFt must be > 0');
    return CylinderAoE._(radiusFt, heightFt);
  }
  @override
  bool includesOrigin() => true;

  /// On a 2D battlemap the cylinder's footprint collapses to a disc —
  /// identical to [SphereAoE.coverage] of the same radius.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) =>
      SphereAoE(radiusFt).coverage(origin, direction);

  @override
  bool operator ==(Object other) =>
      other is CylinderAoE &&
      other.radiusFt == radiusFt &&
      other.heightFt == heightFt;
  @override
  int get hashCode => Object.hash('CylinderAoE', radiusFt, heightFt);
  @override
  String toString() => 'CylinderAoE(r $radiusFt, h $heightFt)';
}

class EmanationAoE extends AreaOfEffect {
  final double distanceFt;
  const EmanationAoE._(this.distanceFt);
  factory EmanationAoE(double distanceFt) {
    if (distanceFt <= 0) {
      throw ArgumentError('EmanationAoE.distanceFt must be > 0');
    }
    return EmanationAoE._(distanceFt);
  }
  @override
  bool includesOrigin() => true;

  /// Chebyshev ring of cells at distance ≤ N from origin, including origin.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) {
    final n = _cellsFromFt(distanceFt);
    final out = <GridCell>{};
    for (var dc = -n; dc <= n; dc++) {
      for (var dr = -n; dr <= n; dr++) {
        out.add(origin.translate(dc, dr));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is EmanationAoE && other.distanceFt == distanceFt;
  @override
  int get hashCode => Object.hash('EmanationAoE', distanceFt);
  @override
  String toString() => 'EmanationAoE($distanceFt ft)';
}

class LineAoE extends AreaOfEffect {
  final double lengthFt;
  final double widthFt;
  const LineAoE._(this.lengthFt, this.widthFt);
  factory LineAoE({required double lengthFt, required double widthFt}) {
    if (lengthFt <= 0) throw ArgumentError('LineAoE.lengthFt must be > 0');
    if (widthFt <= 0) throw ArgumentError('LineAoE.widthFt must be > 0');
    return LineAoE._(lengthFt, widthFt);
  }
  @override
  bool includesOrigin() => false;

  /// Rectangular strip of [length]×[width] cells, starting one cell forward
  /// of origin so the caster's square is not included.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) {
    final len = _cellsFromFt(lengthFt);
    final w = _cellsFromFt(widthFt);
    final halfLow = (w - 1) ~/ 2;
    final halfHigh = w - 1 - halfLow;
    final out = <GridCell>{};
    for (var d = 1; d <= len; d++) {
      for (var off = -halfLow; off <= halfHigh; off++) {
        out.add(_cellAt(origin, direction, forward: d, side: off));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is LineAoE &&
      other.lengthFt == lengthFt &&
      other.widthFt == widthFt;
  @override
  int get hashCode => Object.hash('LineAoE', lengthFt, widthFt);
  @override
  String toString() => 'LineAoE($lengthFt × $widthFt)';
}

class SphereAoE extends AreaOfEffect {
  final double radiusFt;
  const SphereAoE._(this.radiusFt);
  factory SphereAoE(double radiusFt) {
    if (radiusFt <= 0) throw ArgumentError('SphereAoE.radiusFt must be > 0');
    return SphereAoE._(radiusFt);
  }
  @override
  bool includesOrigin() => true;

  /// Chebyshev disc — cells where `chebyshevTo(origin) <= radius/5` per SRD
  /// grid rules. Rounded up so e.g. radius 10 ft = 2 cells, radius 12 ft = 3.
  @override
  Set<GridCell> coverage(GridCell origin, GridDirection direction) {
    final n = _cellsFromFt(radiusFt);
    final out = <GridCell>{};
    for (var dc = -n; dc <= n; dc++) {
      for (var dr = -n; dr <= n; dr++) {
        out.add(origin.translate(dc, dr));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is SphereAoE && other.radiusFt == radiusFt;
  @override
  int get hashCode => Object.hash('SphereAoE', radiusFt);
  @override
  String toString() => 'SphereAoE(r $radiusFt)';
}
