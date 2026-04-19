/// Sealed AoE shapes. Geometry on the battlemap resolves these; the spec
/// method [includesOrigin] is honored by each case.
sealed class AreaOfEffect {
  const AreaOfEffect();

  bool includesOrigin();
}

class ConeAoE extends AreaOfEffect {
  final double lengthFt;
  const ConeAoE._(this.lengthFt);
  factory ConeAoE(double lengthFt) {
    if (lengthFt <= 0) throw ArgumentError('ConeAoE.lengthFt must be > 0');
    return ConeAoE._(lengthFt);
  }
  @override
  bool includesOrigin() => false;

  @override
  bool operator ==(Object other) =>
      other is ConeAoE && other.lengthFt == lengthFt;
  @override
  int get hashCode => Object.hash('ConeAoE', lengthFt);
  @override
  String toString() => 'ConeAoE($lengthFt ft)';
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

  @override
  bool operator ==(Object other) =>
      other is SphereAoE && other.radiusFt == radiusFt;
  @override
  int get hashCode => Object.hash('SphereAoE', radiusFt);
  @override
  String toString() => 'SphereAoE(r $radiusFt)';
}
