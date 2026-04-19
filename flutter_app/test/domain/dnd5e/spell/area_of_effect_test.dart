import 'package:dungeon_master_tool/domain/dnd5e/spell/area_of_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AreaOfEffect', () {
    test('Cone does not include origin, sphere/cube/emanation do', () {
      expect(ConeAoE(30).includesOrigin(), isFalse);
      expect(CubeAoE(15).includesOrigin(), isTrue);
      expect(SphereAoE(20).includesOrigin(), isTrue);
      expect(EmanationAoE(10).includesOrigin(), isTrue);
      expect(LineAoE(lengthFt: 60, widthFt: 5).includesOrigin(), isFalse);
      expect(CylinderAoE(radiusFt: 10, heightFt: 20).includesOrigin(),
          isTrue);
    });

    test('rejects non-positive dimensions', () {
      expect(() => ConeAoE(0), throwsArgumentError);
      expect(() => CubeAoE(-5), throwsArgumentError);
      expect(() => SphereAoE(0), throwsArgumentError);
      expect(() => EmanationAoE(0), throwsArgumentError);
      expect(() => LineAoE(lengthFt: 0, widthFt: 5), throwsArgumentError);
      expect(() => LineAoE(lengthFt: 30, widthFt: 0), throwsArgumentError);
      expect(
          () => CylinderAoE(radiusFt: 0, heightFt: 10), throwsArgumentError);
    });

    test('equality by dimension', () {
      expect(SphereAoE(20), SphereAoE(20));
      expect(SphereAoE(20) == SphereAoE(30), isFalse);
    });
  });
}
