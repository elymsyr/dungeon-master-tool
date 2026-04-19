import '../game_system/built_in_package.dart';
import '../game_system/game_system.dart';

/// D&D 5e implementation of [GameSystem]. Metadata + auto-install manifest
/// only; UI/persistence/import bindings land with later docs (see GameSystem
/// class comment).
class Dnd5eGameSystem implements GameSystem {
  const Dnd5eGameSystem();

  @override
  String get id => 'dnd5e';

  @override
  String get displayName => 'D&D 5e';

  @override
  String get version => '1.0.0';

  @override
  List<BuiltInPackage> get autoInstallPackages => const [
        BuiltInPackage(
          assetPath: 'assets/packages/srd_core.dnd5e-pkg.json',
          displayName: 'D&D 5e SRD Core Rules',
          description:
              'D&D 5e 5.2.1 under CC BY 4.0. Conditions, spells, monsters, '
              'classes, and the standard damage types.',
        ),
      ];
}
