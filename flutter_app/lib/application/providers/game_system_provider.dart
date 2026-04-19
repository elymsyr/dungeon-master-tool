import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dnd5e/dnd5e_game_system.dart';
import '../../domain/game_system/game_system_registry.dart';

/// Process-wide [GameSystemRegistry]. Only D&D 5e is registered in production;
/// the Pathfinder stub lives at `domain/pathfinder/` as a compile-test per
/// Doc 02 and is deliberately **not** wired here.
final gameSystemRegistryProvider = Provider<GameSystemRegistry>((_) {
  final r = GameSystemRegistry();
  r.register(const Dnd5eGameSystem());
  return r;
});
