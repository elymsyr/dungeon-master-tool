import 'package:dungeon_master_tool/domain/pathfinder/pathfinder_game_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathfinderGameSystem (stub)', () {
    test('carries stub metadata', () {
      const s = PathfinderGameSystem();
      expect(s.id, 'pathfinder2e');
      expect(s.displayName.toLowerCase(), contains('stub'));
      expect(s.version, '0.0.0');
    });

    test('ships no built-in content', () {
      expect(const PathfinderGameSystem().autoInstallPackages, isEmpty);
    });
  });
}
