import '../game_system/built_in_package.dart';
import '../game_system/game_system.dart';

/// Compile-test-only stub per Doc 02 §Pathfinder Stub. Do **not** register
/// this in production — keeping the file in the repo proves the modularity
/// contract holds: adding a new system requires touching only
/// `domain/<systemId>/` (and one registry line).
class PathfinderGameSystem implements GameSystem {
  const PathfinderGameSystem();

  @override
  String get id => 'pathfinder2e';

  @override
  String get displayName => 'Pathfinder 2e (stub)';

  @override
  String get version => '0.0.0';

  @override
  List<BuiltInPackage> get autoInstallPackages => const [];
}
