import 'game_system.dart';

/// In-process registry of all [GameSystem]s available to the app. Populated
/// at startup by whoever wires providers (see Doc 02). A [GameSystem] is
/// referenced by stable string id so `campaign.gameSystemId` can survive
/// serialisation/deserialisation.
class GameSystemRegistry {
  final Map<String, GameSystem> _systems = {};

  void register(GameSystem system) {
    if (_systems.containsKey(system.id)) {
      throw StateError('GameSystem "${system.id}" already registered');
    }
    _systems[system.id] = system;
  }

  GameSystem? byId(String id) => _systems[id];

  bool contains(String id) => _systems.containsKey(id);

  Iterable<GameSystem> all() => _systems.values;

  int get count => _systems.length;

  void clear() => _systems.clear();
}
