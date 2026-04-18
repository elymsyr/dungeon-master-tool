# 02 — GameSystem Abstraction

> **For Claude.** Modularity contract for swapping in non-DnD systems later (Pathfinder, CoC).
> **Scope:** Define minimum interface. Default impl = DnD 5e. Out-of-scope: actually implementing other systems.

## Design Principle

**Domain-level namespace, not runtime polymorphism.** Switching games happens at compile-time / per-campaign, not within a session. So `GameSystem` is a registry/marker, not a vtable for every operation.

DnD-specific code lives in `domain/dnd5e/` and `application/dnd5e/`. Future Pathfinder code would live in `domain/pathfinder/` and `application/pathfinder/`. No shared "abstract Character" hierarchy — they are different shapes.

What IS shared: cross-cutting infra (DB, projection, networking, UI shell, soundboard, PDF sidebar, mind map).

## Interface

```dart
// flutter_app/lib/domain/game_system/game_system.dart
abstract interface class GameSystem {
  String get id;                        // 'dnd5e', 'pathfinder2e', 'coc7'
  String get displayName;               // 'D&D 5e (SRD 5.2.1)'
  String get version;                   // '1.0.0'
  String get sourceLicense;             // 'CC BY 4.0'

  /// Routes to the system's character creation entry screen.
  Widget buildCharacterCreationFlow({required VoidCallback onComplete});

  /// Routes to the system's character sheet view.
  Widget buildCharacterSheet({required String characterId, required ViewerRole role});

  /// Routes to the system's combat tracker.
  Widget buildCombatTracker({required String encounterId});

  /// Returns the system's package import handler.
  PackageImporter get packageImporter;

  /// Returns the system's database schema bundle (Drift tables).
  List<TableInfo> get driftTables;

  /// Returns route definitions to be registered with GoRouter.
  List<RouteBase> get routes;
}
```

## Registry

```dart
// flutter_app/lib/domain/game_system/game_system_registry.dart
class GameSystemRegistry {
  final Map<String, GameSystem> _systems = {};
  void register(GameSystem s) => _systems[s.id] = s;
  GameSystem? byId(String id) => _systems[id];
  Iterable<GameSystem> all() => _systems.values;
}

final gameSystemRegistryProvider = Provider<GameSystemRegistry>((_) {
  final r = GameSystemRegistry();
  r.register(Dnd5eGameSystem());
  return r;
});
```

## DnD5e Impl

```dart
// flutter_app/lib/domain/dnd5e/dnd5e_game_system.dart
class Dnd5eGameSystem implements GameSystem {
  @override final id = 'dnd5e';
  @override final displayName = 'D&D 5e (SRD 5.2.1)';
  @override final version = '1.0.0';
  @override final sourceLicense = 'CC BY 4.0';

  @override
  Widget buildCharacterCreationFlow({required VoidCallback onComplete}) =>
    Dnd5eCharacterCreationScreen(onComplete: onComplete);

  @override
  Widget buildCharacterSheet({required String characterId, required ViewerRole role}) =>
    Dnd5eCharacterSheetScreen(characterId: characterId, role: role);

  @override
  Widget buildCombatTracker({required String encounterId}) =>
    Dnd5eCombatTrackerScreen(encounterId: encounterId);

  @override
  PackageImporter get packageImporter => Dnd5ePackageImporter();

  @override
  List<TableInfo> get driftTables => [
    CharactersTable(), MonstersTable(), SpellsTable(), ItemsTable(),
    FeatsTable(), BackgroundsTable(), SpeciesTable(), SubclassesTable(),
    EncountersTable(), CombatantsTable(), /* ... */
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/dnd5e/character-creation', builder: (_, __) => buildCharacterCreationFlow(...)),
    GoRoute(path: '/dnd5e/character/:id', builder: (_, s) => buildCharacterSheet(characterId: s.pathParameters['id']!, role: ViewerRole.owner)),
    GoRoute(path: '/dnd5e/encounter/:id', builder: (_, s) => buildCombatTracker(encounterId: s.pathParameters['id']!)),
  ];
}
```

## Campaign-System Binding

```dart
class Campaign {
  final String id;
  final String name;
  final String gameSystemId;     // 'dnd5e' — fixed at creation, immutable
  // ...
}
```

Campaign creation flow asks user to pick game system (currently only DnD 5e). Stored in DB. UI dispatches to `registry.byId(campaign.gameSystemId).buildXxx()`.

## Pathfinder Stub (Compile-Test Only)

```dart
// flutter_app/lib/domain/pathfinder/pathfinder_game_system.dart  (stub)
class PathfinderGameSystem implements GameSystem {
  @override final id = 'pathfinder2e';
  @override final displayName = 'Pathfinder 2e (stub)';
  @override final version = '0.0.0';
  @override final sourceLicense = 'OGL';

  @override
  Widget buildCharacterCreationFlow({required VoidCallback onComplete}) =>
    const Scaffold(body: Center(child: Text('Pathfinder not implemented')));
  // ... other methods return placeholder widgets
  @override List<TableInfo> get driftTables => [];
  @override List<RouteBase> get routes => [];
  @override PackageImporter get packageImporter => NoopPackageImporter();
}
```

**Do not register the Pathfinder stub** in production. Keep file in repo as compile-time proof modularity holds.

## Acceptance

- `GameSystemRegistry.all()` returns 1 entry (`Dnd5eGameSystem`).
- Adding `PathfinderGameSystem` requires zero changes outside `domain/pathfinder/` and `application/pathfinder/` (and one registry line).
- DnD 5e UI never directly references `Dnd5eGameSystem` from outside `domain/dnd5e/` — always goes through `registry.byId(campaign.gameSystemId)`.

## Open Questions

1. Should `PackageImporter` be a per-system interface or shared? → **Per-system.** Each system has different content shape (DnD 5e: spells/monsters; CoC: investigators/mythos).
2. Does `GameSystem` own its own preferences/settings panel? → Yes: add `Widget buildSettingsPanel()` later. Out of MVP.
3. Where do shared cross-system features (campaign metadata, world map, mind map, soundboard) live? → `application/shared/`, `presentation/shared/`. Not part of `GameSystem`.
