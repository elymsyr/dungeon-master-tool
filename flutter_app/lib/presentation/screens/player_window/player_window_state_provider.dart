import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/projection/battle_map_snapshot.dart';
import '../../../domain/entities/projection/projection_item.dart';
import '../../../domain/entities/projection/projection_state.dart';

/// Sub-isolate state provider — receives full snapshots and patches over
/// IPC and exposes them to the player window's widget tree.
///
/// Lives ONLY in the player sub-isolate. The DM isolate uses
/// `projectionControllerProvider` instead.
class PlayerProjectionStateNotifier extends StateNotifier<ProjectionState> {
  PlayerProjectionStateNotifier() : super(const ProjectionState());

  void applyFull(ProjectionState next) => state = next;

  void applyPatch(Map<String, dynamic> patch) {
    state = state.copyWith(
      activeItemId: patch.containsKey('activeItemId')
          ? patch['activeItemId'] as String?
          : state.activeItemId,
      blackoutOverride: patch['blackoutOverride'] as bool? ?? state.blackoutOverride,
    );
  }

  /// Targeted patch for one battle map projection. Merges the partial JSON
  /// fields into the existing snapshot — used by the optimization path that
  /// avoids re-encoding the entire `ProjectionState` for every stroke / fog
  /// edit / token-size change.
  void applyBattleMapPatch(String itemId, Map<String, dynamic> patch) {
    final newItems = <ProjectionItem>[];
    var changed = false;
    for (final item in state.items) {
      if (item is BattleMapProjection && item.id == itemId) {
        newItems.add(item.copyWith(snapshot: _mergePatch(item.snapshot, patch)));
        changed = true;
      } else {
        newItems.add(item);
      }
    }
    if (changed) {
      state = state.copyWith(items: newItems);
    }
  }

  static BattleMapSnapshot _mergePatch(
      BattleMapSnapshot snap, Map<String, dynamic> patch) {
    return snap.copyWith(
      strokes: patch.containsKey('strokes')
          ? (patch['strokes'] as List)
              .map((e) =>
                  StrokeSnapshot.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : null,
      measurements: patch.containsKey('measurements')
          ? (patch['measurements'] as List)
              .map((e) => MeasurementSnapshot.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList()
          : null,
      tokens: patch.containsKey('tokens')
          ? (patch['tokens'] as List)
              .map((e) =>
                  TokenSnapshot.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : null,
      turnIndex: patch['turnIndex'] as int?,
      tokenSize: patch['tokenSize'] as int?,
      tokenSizeMultipliers: patch['tokenSizeMultipliers'] is Map
          ? (patch['tokenSizeMultipliers'] as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble()))
          : null,
      gridVisible: patch['gridVisible'] as bool?,
      gridSize: patch['gridSize'] as int?,
      feetPerCell: patch['feetPerCell'] as int?,
      fogDataBase64: patch['fogDataBase64'] as String?,
      clearFog: patch.containsKey('fogDataBase64') && patch['fogDataBase64'] == null,
      viewportNormalized: patch.containsKey('viewportNormalized') &&
              patch['viewportNormalized'] != null
          ? NormalizedRect.fromJson(
              (patch['viewportNormalized'] as Map).cast<String, dynamic>())
          : null,
      clearViewport: patch.containsKey('viewportNormalized') &&
          patch['viewportNormalized'] == null,
    );
  }
}

final playerProjectionStateProvider =
    StateNotifierProvider<PlayerProjectionStateNotifier, ProjectionState>(
        (ref) => PlayerProjectionStateNotifier());
