import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../../domain/entities/projection/battle_map_snapshot.dart';
import '../../domain/entities/projection/entity_snapshot.dart';
import '../../domain/entities/projection/projection_item.dart';
import '../../domain/entities/projection/projection_output_mode.dart';
import '../../domain/entities/projection/projection_state.dart';
import '../services/battle_map_snapshot_builder.dart';
import '../services/entity_snapshot_builder.dart';
import '../services/projection_output.dart';
import 'combat_provider.dart';
import 'entity_provider.dart';
import 'event_bus_provider.dart';
import 'projection_output_provider.dart';

const _projectionUuid = Uuid();

/// Owns the DM-side `ProjectionState` and routes mutations to:
///   1. local state (for the projection panel UI),
///   2. the active output (second window or screencast) via [ProjectionOutput],
///   3. the AppEventBus (for the future online network bridge).
///
/// Content management (add/remove/reorder items) is fully decoupled from the
/// delivery mechanism. The controller delegates all transport to whichever
/// [ProjectionOutput] is currently active.
class ProjectionController extends StateNotifier<ProjectionState> {
  ProjectionController(this._ref) : super(const ProjectionState());

  final Ref _ref;

  /// Currently active output. Null when no output is active.
  ProjectionOutput? _activeOutput;
  StreamSubscription<void>? _externalCloseSub;

  @override
  void dispose() {
    _externalCloseSub?.cancel();
    _activeOutput?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Output lifecycle
  // ---------------------------------------------------------------------

  /// Activates the given output mode. If another output is already active,
  /// deactivates it first (mutually exclusive).
  ///
  /// For [ProjectionOutputMode.screencast], [displayId] must be provided
  /// (the target external display chosen by the user from the picker).
  ///
  /// Returns `true` on success, `false` if the output could not be started
  /// (e.g. no second monitor, no external display).
  Future<bool> activateOutput(
    ProjectionOutputMode mode, {
    String? displayId,
  }) async {
    if (mode == ProjectionOutputMode.none) {
      await deactivateOutput();
      return true;
    }

    // Already active with the same mode — no-op.
    if (_activeOutput != null && state.outputMode == mode) return true;

    // Deactivate any previous output.
    if (_activeOutput != null) await deactivateOutput();

    final factory = _ref.read(projectionOutputFactoryProvider);
    final output = factory(mode, displayId: displayId);
    if (output == null) {
      debugPrint('Projection output mode $mode not available on this platform');
      return false;
    }

    final ok = await output.activate();
    if (!ok) {
      output.dispose();
      return false;
    }

    _activeOutput = output;
    state = state.copyWith(outputMode: mode);

    _externalCloseSub = output.onExternalClose.listen((_) {
      _markOutputClosed();
    });

    // Push full state immediately — the native side buffers until the
    // presentation engine signals readiness via the engineReady handshake.
    _activeOutput!.pushFull(state).then((ok) {
      if (!ok) _markOutputClosed();
    });

    return true;
  }

  /// Deactivates the current output (if any).
  Future<void> deactivateOutput() async {
    final output = _activeOutput;
    if (output == null) return;
    _activeOutput = null;
    _externalCloseSub?.cancel();
    _externalCloseSub = null;
    state = state.copyWith(outputMode: ProjectionOutputMode.none);
    await output.deactivate();
    output.dispose();
  }

  // ---------------------------------------------------------------------
  // Item mutations
  // ---------------------------------------------------------------------

  /// Adds a new item to the projection list. If `setActive` is true, the
  /// new item also becomes the active one (Project & switch to behavior).
  ///
  /// For [ImageProjection]s, dedupes by file paths — re-projecting the same
  /// image just re-activates the existing tab instead of creating a new one.
  void addItem(ProjectionItem item, {bool setActive = true}) {
    if (item is ImageProjection) {
      final key = [...item.filePaths]..sort();
      for (final existing in state.items.whereType<ImageProjection>()) {
        final other = [...existing.filePaths]..sort();
        if (_listEq(key, other)) {
          if (setActive) this.setActive(existing.id);
          return;
        }
      }
    }
    final newItems = [...state.items, item];
    state = state.copyWith(
      items: newItems,
      activeItemId: setActive ? item.id : state.activeItemId,
    );
    _pushFullAndEmit();
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Replaces the currently-active item with [item], leaving all other
  /// items in place. Used by the "Project & replace active" menu entry.
  void replaceActive(ProjectionItem item) {
    final activeId = state.activeItemId;
    if (activeId == null) {
      addItem(item);
      return;
    }
    final newItems = [
      for (final it in state.items)
        if (it.id == activeId) item else it,
    ];
    state = state.copyWith(
      items: newItems,
      activeItemId: item.id,
    );
    _pushFullAndEmit();
  }

  /// Removes the item with [itemId]. If it was the active item, the
  /// next-most-recent item becomes active (or null if the list is empty).
  void removeItem(String itemId) {
    final newItems = state.items.where((i) => i.id != itemId).toList();
    String? newActive = state.activeItemId;
    if (newActive == itemId) {
      newActive = newItems.isNotEmpty ? newItems.last.id : null;
    }
    state = state.copyWith(items: newItems, activeItemId: newActive);
    _pushFullAndEmit();
  }

  /// Sets the active item. Sends a small patch — the player window only
  /// needs to swap its `IndexedStack.index`.
  void setActive(String itemId) {
    if (state.activeItemId == itemId) return;
    state = state.copyWith(activeItemId: itemId);
    _pushPatch({'activeItemId': itemId});
    _emitEvent();
  }

  /// Reorders the item at [oldIndex] to [newIndex] in the projection list.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final newItems = [...state.items];
    final item = newItems.removeAt(oldIndex);
    newItems.insert(newIndex.clamp(0, newItems.length), item);
    state = state.copyWith(items: newItems);
    _pushFullAndEmit();
  }

  /// Toggles the global blackout. Independent of the active item — sub-window
  /// renders pure black on top of whatever is shown.
  void toggleBlackout() {
    state = state.copyWith(blackoutOverride: !state.blackoutOverride);
    _pushPatch({'blackoutOverride': state.blackoutOverride});
    _emitEvent();
  }

  /// Removes all items and clears the active item.
  void clearAll() {
    state = state.copyWith(items: const [], activeItemId: null);
    _pushFullAndEmit();
  }

  // ---------------------------------------------------------------------
  // Battle map snapshot sync
  // ---------------------------------------------------------------------

  /// Adds a battle map projection for [encounterId]. Awaits the canvas
  /// measurement first so the initial push to the player window already
  /// has accurate dimensions (no flash of empty 2048×2048 placeholder).
  ///
  /// If a battle map projection for the same encounter already exists,
  /// just re-activates that tab instead of creating a duplicate.
  Future<void> addBattleMap({
    required String encounterId,
    required String label,
    bool setActive = true,
  }) async {
    // Dedupe: same encounter already projected → just activate it.
    final existing = state.items
        .whereType<BattleMapProjection>()
        .where((it) => it.encounterId == encounterId)
        .firstOrNull;
    if (existing != null) {
      if (setActive) this.setActive(existing.id);
      return;
    }

    final encounters = _ref.read(combatProvider).encounters;
    final encounter =
        encounters.where((e) => e.id == encounterId).firstOrNull;
    if (encounter == null) return;

    // Measure canvas FIRST so the first push already has correct dims.
    int? w, h;
    if (encounter.mapPath != null && encounter.mapPath!.isNotEmpty) {
      final measured = await BattleMapSnapshotBuilder.measureCanvas(
        encounter.mapPath,
      );
      w = measured.$1;
      h = measured.$2;
    }

    final entities = _ref.read(entityProvider);
    final schema = _ref.read(worldSchemaProvider);
    final snapshot = BattleMapSnapshotBuilder.build(
      encounter: encounter,
      entities: entities,
      schema: schema,
      canvasWidth: w ?? 2048,
      canvasHeight: h ?? 2048,
    );
    final id = _projectionUuid.v4();
    addItem(
      BattleMapProjection(
        id: id,
        label: label,
        encounterId: encounterId,
        snapshot: snapshot,
      ),
      setActive: setActive,
    );
  }

  /// Adds an entity card projection. Builds the snapshot from the live
  /// entity + world schema. Dedupes by `entityId`.
  void addEntityCard({
    required String entityId,
    bool setActive = true,
  }) {
    // Dedupe: same entity already projected → just activate it.
    final existing = state.items
        .whereType<EntityCardProjection>()
        .where((it) => it.entityId == entityId)
        .firstOrNull;
    if (existing != null) {
      if (setActive) this.setActive(existing.id);
      return;
    }

    final entity = _ref.read(entityProvider)[entityId];
    if (entity == null) return;
    final schema = _ref.read(worldSchemaProvider);
    final snapshot = EntitySnapshotBuilder.build(
      entity: entity,
      schema: schema,
    );
    final id = _projectionUuid.v4();
    addItem(
      EntityCardProjection(
        id: id,
        label: entity.name.isEmpty ? 'Entity' : entity.name,
        entityId: entityId,
        snapshot: snapshot,
      ),
      setActive: setActive,
    );
  }

  /// Replaces an entity card snapshot in place. Called by the sync
  /// provider whenever the source entity changes.
  void updateEntitySnapshot(String itemId, EntitySnapshot snapshot) {
    final current = state.items
        .whereType<EntityCardProjection>()
        .where((it) => it.id == itemId)
        .firstOrNull;
    if (current == null) return;
    _replaceItem(current.copyWith(snapshot: snapshot));
  }

  /// Replaces a battle map projection's snapshot in place. Called by the
  /// sync provider whenever combat state changes for an encounter that
  /// has an active battle map projection.
  void updateBattleMapSnapshot(String itemId, BattleMapSnapshot snapshot) {
    final current = state.items
        .whereType<BattleMapProjection>()
        .where((it) => it.id == itemId)
        .firstOrNull;
    if (current == null) return;
    final cur = current.snapshot;

    // Merge: combat data from `snapshot`, drawing/fog/etc. from `cur`.
    final merged = cur.copyWith(
      tokens: snapshot.tokens,
      turnIndex: snapshot.turnIndex,
      canvasWidth: snapshot.canvasWidth,
      canvasHeight: snapshot.canvasHeight,
      mapPath: snapshot.mapPath,
    );

    // Local state update — no full push.
    final replacement = current.copyWith(snapshot: merged);
    final newItems = [
      for (final it in state.items)
        if (it.id == replacement.id) replacement else it,
    ];
    state = state.copyWith(items: newItems);

    // Tokens-only patch to the output — small payload regardless
    // of how big the fog bitmap is.
    _pushBattleMapPatch(itemId, {
      'tokens': snapshot.tokens.map((t) => t.toJson()).toList(),
      'turnIndex': snapshot.turnIndex,
    });
  }

  /// Toggles the player viewport lock for a battle map projection.
  void setBattleMapLocked(String itemId, bool locked) {
    final current = state.items
        .whereType<BattleMapProjection>()
        .where((it) => it.id == itemId)
        .firstOrNull;
    if (current == null) return;
    if (current.viewportLocked == locked) return;
    _replaceItem(current.copyWith(viewportLocked: locked));
  }

  /// Updates only the normalized viewport rect of a battle map projection.
  /// Called at ~30Hz from the DM's `BattleMapNotifier` viewTransform listener.
  void updateBattleMapViewport(String itemId, NormalizedRect? normalizedRect) {
    final current = state.items
        .whereType<BattleMapProjection>()
        .where((it) => it.id == itemId)
        .firstOrNull;
    if (current == null) return;
    if (current.viewportLocked) return;
    final newSnap = current.snapshot.copyWith(
      viewportNormalized: normalizedRect,
      clearViewport: normalizedRect == null,
    );
    final replacement = current.copyWith(snapshot: newSnap);
    final newItems = [
      for (final it in state.items)
        if (it.id == replacement.id) replacement else it,
    ];
    state = state.copyWith(items: newItems);
    _pushBattleMapPatch(itemId, {
      if (normalizedRect != null)
        'viewportNormalized': normalizedRect.toJson()
      else
        'viewportNormalized': null,
    });
  }

  /// Updates the "static" battle-map state (strokes, measurements, fog,
  /// token sizing, grid).
  void updateBattleMapDrawings({
    required String itemId,
    required List<StrokeSnapshot> strokes,
    required List<MeasurementSnapshot> measurements,
    required int tokenSize,
    required Map<String, double> tokenSizeMultipliers,
    required bool gridVisible,
    required int gridSize,
    required int feetPerCell,
    required String? fogDataBase64,
    bool includeFog = false,
  }) {
    final current = state.items
        .whereType<BattleMapProjection>()
        .where((it) => it.id == itemId)
        .firstOrNull;
    if (current == null) return;

    final newSnap = current.snapshot.copyWith(
      strokes: strokes,
      measurements: measurements,
      tokenSize: tokenSize,
      tokenSizeMultipliers: tokenSizeMultipliers,
      gridVisible: gridVisible,
      gridSize: gridSize,
      feetPerCell: feetPerCell,
      fogDataBase64: includeFog ? fogDataBase64 : null,
      clearFog: includeFog && fogDataBase64 == null,
    );
    final replacement = current.copyWith(snapshot: newSnap);
    final newItems = [
      for (final it in state.items)
        if (it.id == replacement.id) replacement else it,
    ];
    state = state.copyWith(items: newItems);

    _pushBattleMapPatch(itemId, {
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'measurements': measurements.map((m) => m.toJson()).toList(),
      'tokenSize': tokenSize,
      'tokenSizeMultipliers': tokenSizeMultipliers,
      'gridVisible': gridVisible,
      'gridSize': gridSize,
      'feetPerCell': feetPerCell,
      if (includeFog) 'fogDataBase64': fogDataBase64,
    });
  }

  void _pushBattleMapPatch(String itemId, Map<String, dynamic> patch) {
    final output = _activeOutput;
    if (output != null) {
      output.pushBattleMapPatch(itemId, patch).then((ok) {
        if (!ok) _markOutputClosed();
      });
    }
    _emitEvent();
  }

  /// Internal: replace one item in the list, preserving everything else.
  void _replaceItem(ProjectionItem replacement) {
    final newItems = [
      for (final it in state.items)
        if (it.id == replacement.id) replacement else it,
    ];
    state = state.copyWith(items: newItems);
    _pushFullAndEmit();
  }

  // ---------------------------------------------------------------------
  // Output transport + event bus plumbing
  // ---------------------------------------------------------------------

  void _pushFullAndEmit() {
    final output = _activeOutput;
    if (output != null) {
      output.pushFull(state).then((ok) {
        if (!ok) _markOutputClosed();
      });
    }
    _emitEvent();
  }

  void _pushPatch(Map<String, dynamic> patch) {
    final output = _activeOutput;
    if (output != null) {
      output.pushPatch(patch).then((ok) {
        if (!ok) _markOutputClosed();
      });
    }
  }

  /// Called when an output push fails or the output is closed externally.
  void _markOutputClosed() {
    if (_activeOutput == null && !state.isActive) return;
    _externalCloseSub?.cancel();
    _externalCloseSub = null;
    _activeOutput?.dispose();
    _activeOutput = null;
    if (state.isActive) {
      state = state.copyWith(outputMode: ProjectionOutputMode.none);
    }
  }

  /// Emits a `projection.content_set` event on the AppEventBus.
  void _emitEvent() {
    try {
      _ref.read(eventBusProvider).emit(EventEnvelope.now(
            EventTypes.projectionContentSet,
            state.toJson(),
          ));
    } catch (_) {
      // Bus disposal during teardown — ignore.
    }
  }
}

final projectionControllerProvider =
    StateNotifierProvider<ProjectionController, ProjectionState>((ref) {
  return ProjectionController(ref);
});

/// Auto-installed sync — whenever any entity in the entity provider
/// changes, walks all active `EntityCardProjection` items and rebuilds
/// their snapshots from the latest entity data + world schema.
final projectionEntitySyncProvider = Provider<void>((ref) {
  ref.listen(entityProvider, (prev, next) {
    final state = ref.read(projectionControllerProvider);
    if (!state.items.any((i) => i is EntityCardProjection)) return;
    final controller = ref.read(projectionControllerProvider.notifier);
    final schema = ref.read(worldSchemaProvider);
    for (final item in state.items) {
      if (item is! EntityCardProjection) continue;
      final entity = next[item.entityId];
      if (entity == null) continue;
      controller.updateEntitySnapshot(
        item.id,
        EntitySnapshotBuilder.build(entity: entity, schema: schema),
      );
    }
  }, fireImmediately: false);
});

/// Auto-installed sync — whenever combat state changes, walks all active
/// `BattleMapProjection` items and rebuilds their snapshots from the latest
/// encounter + entity data.
final projectionBattleMapSyncProvider = Provider<void>((ref) {
  ref.listen<CombatState>(combatProvider, (prev, next) {
    final state = ref.read(projectionControllerProvider);
    if (!state.items.any((i) => i is BattleMapProjection)) return;
    final controller = ref.read(projectionControllerProvider.notifier);
    final entities = ref.read(entityProvider);
    final schema = ref.read(worldSchemaProvider);
    for (final item in state.items) {
      if (item is! BattleMapProjection) continue;
      final encounter = next.encounters
          .where((e) => e.id == item.encounterId)
          .firstOrNull;
      if (encounter == null) continue;
      final newSnap = BattleMapSnapshotBuilder.build(
        encounter: encounter,
        entities: entities,
        schema: schema,
        canvasWidth: item.snapshot.canvasWidth,
        canvasHeight: item.snapshot.canvasHeight,
      );
      controller.updateBattleMapSnapshot(item.id, newSnap);
    }
  }, fireImmediately: false);
});
