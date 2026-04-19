import 'built_in_package.dart';

/// Registry/marker for a ruleset the app supports (DnD 5e, Pathfinder 2e, ...).
///
/// Per Doc 02 §Design Principle, switching game systems is compile-time/
/// per-campaign, not per-session — so this interface is a metadata + capability
/// registry, **not** a vtable for every game operation. Game-specific domain
/// code lives in `domain/<systemId>/` and never leaks through here.
///
/// Current scope (Doc 01/02): metadata + auto-install manifest. Later docs
/// extend this interface with UI/persistence/import bindings:
///   - Doc 03 (database): adds `driftTables` getter
///   - Doc 10 (character creation) + Doc 11 (combat) + Doc 32 (sheet):
///     add `buildCharacterCreationFlow`/`buildCombatTracker`/`buildCharacterSheet`
///   - Doc 14 (package system): adds `packageImporter` getter
///   - Router migration: adds `routes` getter
abstract interface class GameSystem {
  /// Stable machine id — 'dnd5e', 'pathfinder2e', 'coc7'.
  String get id;

  /// Human-readable name — 'D&D 5e'. Mechanics identity, not a content claim.
  String get displayName;

  /// Semver of the rules-engine implementation, not of any installed package.
  String get version;

  /// Packages bundled with the app binary that this system offers to
  /// auto-install on fresh-world creation. Empty list = system ships no
  /// default content; fresh worlds start with empty catalogs (per Doc 01 §Note
  /// and Doc 02 Acceptance bullet 4).
  List<BuiltInPackage> get autoInstallPackages;
}
