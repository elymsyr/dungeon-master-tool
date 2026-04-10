import 'package:flutter/foundation.dart';

/// Mixin that provides undo/redo stack management for StateNotifier subclasses.
///
/// Usage:
///   class MyNotifier extends StateNotifier<MyState> with UndoRedoMixin<MyState> {
///     void someAction() {
///       pushUndo(state);
///       state = state.copyWith(...);
///     }
///   }
mixin UndoRedoMixin<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];

  int get maxUndoDepth => 20;

  final ValueNotifier<bool> canUndoNotifier = ValueNotifier(false);
  final ValueNotifier<bool> canRedoNotifier = ValueNotifier(false);

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void pushUndo(T currentState) {
    _undoStack.add(currentState);
    if (_undoStack.length > maxUndoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
    _notifyUndoRedo();
  }

  /// Returns the state to restore, or null if nothing to undo.
  T? popUndo(T currentState) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(currentState);
    final restored = _undoStack.removeLast();
    _notifyUndoRedo();
    return restored;
  }

  /// Returns the state to restore, or null if nothing to redo.
  T? popRedo(T currentState) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(currentState);
    final restored = _redoStack.removeLast();
    _notifyUndoRedo();
    return restored;
  }

  void clearUndoRedo() {
    _undoStack.clear();
    _redoStack.clear();
    _notifyUndoRedo();
  }

  void _notifyUndoRedo() {
    canUndoNotifier.value = _undoStack.isNotEmpty;
    canRedoNotifier.value = _redoStack.isNotEmpty;
  }

  void disposeUndoRedo() {
    canUndoNotifier.dispose();
    canRedoNotifier.dispose();
  }
}
