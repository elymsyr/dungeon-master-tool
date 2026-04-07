import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/screens/mind_map/mind_map_notifier.dart';
import '../../presentation/screens/map/world_map_notifier.dart';
import 'combat_provider.dart';
import 'entity_provider.dart';

/// Dispatches undo/redo to the active tab's notifier.
///
/// Tab indices: 0=Database, 1=Session, 2=MindMap, 3=WorldMap
class UndoRedoDispatcher {
  final Ref _ref;
  UndoRedoDispatcher(this._ref);

  static final _emptyBool = ValueNotifier(false);

  void undo(int tabIndex) {
    switch (tabIndex) {
      case 0:
        _ref.read(entityProvider.notifier).undo();
      case 1:
        _ref.read(combatProvider.notifier).undo();
      case 2:
        _ref.read(mindMapProvider.notifier).undo();
      case 3:
        _ref.read(worldMapProvider.notifier).undo();
    }
  }

  void redo(int tabIndex) {
    switch (tabIndex) {
      case 0:
        _ref.read(entityProvider.notifier).redo();
      case 1:
        _ref.read(combatProvider.notifier).redo();
      case 2:
        _ref.read(mindMapProvider.notifier).redo();
      case 3:
        _ref.read(worldMapProvider.notifier).redo();
    }
  }

  /// Returns (canUndo, canRedo) ValueNotifiers for the given tab.
  (ValueNotifier<bool>, ValueNotifier<bool>) activeNotifiers(int tabIndex) {
    try {
      return switch (tabIndex) {
        0 => (
            _ref.read(entityProvider.notifier).canUndoNotifier,
            _ref.read(entityProvider.notifier).canRedoNotifier,
          ),
        1 => (
            _ref.read(combatProvider.notifier).canUndoNotifier,
            _ref.read(combatProvider.notifier).canRedoNotifier,
          ),
        2 => (
            _ref.read(mindMapProvider.notifier).canUndoNotifier,
            _ref.read(mindMapProvider.notifier).canRedoNotifier,
          ),
        3 => (
            _ref.read(worldMapProvider.notifier).canUndoNotifier,
            _ref.read(worldMapProvider.notifier).canRedoNotifier,
          ),
        _ => (_emptyBool, _emptyBool),
      };
    } catch (_) {
      // autoDispose providers may not be alive yet
      return (_emptyBool, _emptyBool);
    }
  }
}

final undoRedoDispatcherProvider = Provider((ref) => UndoRedoDispatcher(ref));
