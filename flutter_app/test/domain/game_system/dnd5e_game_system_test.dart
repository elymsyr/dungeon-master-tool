import 'package:dungeon_master_tool/domain/dnd5e/dnd5e_game_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dnd5eGameSystem', () {
    test('stable metadata', () {
      const s = Dnd5eGameSystem();
      expect(s.id, 'dnd5e');
      expect(s.displayName, 'D&D 5e');
      expect(s.version, '1.0.0');
    });

    test('autoInstallPackages contains SRD Core bundle', () {
      const s = Dnd5eGameSystem();
      expect(s.autoInstallPackages, hasLength(1));
      final srd = s.autoInstallPackages.first;
      expect(srd.assetPath, 'assets/packages/srd_core.dnd5e-pkg.json');
      expect(srd.recommendedDefault, isTrue);
      expect(srd.displayName, contains('SRD'));
    });
  });
}
