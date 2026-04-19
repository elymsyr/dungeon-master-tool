import 'package:dungeon_master_tool/domain/dnd5e/dnd5e_game_system.dart';
import 'package:dungeon_master_tool/domain/game_system/built_in_package.dart';
import 'package:dungeon_master_tool/domain/game_system/game_system.dart';
import 'package:dungeon_master_tool/domain/game_system/game_system_registry.dart';
import 'package:dungeon_master_tool/domain/pathfinder/pathfinder_game_system.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements GameSystem {
  @override
  final String id;
  _Fake(this.id);
  @override
  String get displayName => 'Fake';
  @override
  String get version => '0';
  @override
  List<BuiltInPackage> get autoInstallPackages => const [];
}

void main() {
  group('GameSystemRegistry', () {
    test('register + byId + contains', () {
      final r = GameSystemRegistry();
      r.register(const Dnd5eGameSystem());
      expect(r.contains('dnd5e'), isTrue);
      expect(r.byId('dnd5e')?.displayName, 'D&D 5e');
      expect(r.count, 1);
    });

    test('duplicate id rejected', () {
      final r = GameSystemRegistry();
      r.register(_Fake('dnd5e'));
      expect(() => r.register(_Fake('dnd5e')), throwsStateError);
    });

    test('byId returns null for unknown', () {
      final r = GameSystemRegistry();
      expect(r.byId('coc7'), isNull);
    });

    test('all iterates registered systems', () {
      final r = GameSystemRegistry();
      r.register(const Dnd5eGameSystem());
      r.register(const PathfinderGameSystem()); // stub registration permitted in tests
      expect(r.all().map((s) => s.id), unorderedEquals(['dnd5e', 'pathfinder2e']));
    });

    test('clear empties registry', () {
      final r = GameSystemRegistry();
      r.register(const Dnd5eGameSystem());
      r.clear();
      expect(r.count, 0);
    });
  });
}
