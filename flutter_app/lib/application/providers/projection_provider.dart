import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../../domain/entities/projection/battle_map_snapshot.dart';
import '../../domain/entities/projection/entity_snapshot.dart';
import '../../domain/entities/projection/projection_item.dart';
import '../../domain/entities/projection/projection_state.dart';
import '../../main.dart' show playerWindowClosedSignal;
import '../services/battle_map_snapshot_builder.dart';
import '../services/entity_snapshot_builder.dart';
import '../services/projection_ipc.dart';
import 'combat_provider.dart';
import 'entity_provider.dart';
import 'event_bus_provider.dart';

const _projectionUuid = Uuid();

/// Owns the DM-side `ProjectionState` and routes mutations to:
///   1. local state (for the projection panel UI),
///   2. the player sub-window via IPC (full or patch),
///   3. the AppEventBus (for the future online network bridge).
///
/// Phase 1 supports image projection + blackout. Other item types are
/// modeled but their views are stubbed in the player window.
class ProjectionController extends StateNotifier<ProjectionState> {
  ProjectionController(this._ref) : super(const ProjectionState()) {
    // Listen to the reverse-IPC bridge from main.dart so the player window's
    // native close-button immediately flips our cast icon to "closed".
    playerWindowClosedSignal.addListener(_onPlayerClosedSignal);
  }

  final Ref _ref;

  /// Window id of the open player sub-window. Null when closed.
  int? _windowId;
  int? get windowId => _windowId;

  void _onPlayerClosedSignal() {
    _markWindowClosed();
  }

  @override
  void dispose() {
    playerWindowClosedSignal.removeListener(_onPlayerClosedSignal);
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Window lifecycle
  // ---------------------------------------------------------------------

  /// Opens the player sub-window if it isn't already open. Returns the
  /// window id, or null on failure.
  ///
  /// Tries to place the window on a non-primary monitor via screen_retriever.
  /// Falls back to a centered default frame if no second monitor is found
  /// or detection fails (Wayland edge cases).
  Future<int?> openWindow() async {
    if (_windowId != null) return _windowId;
    try {
      final targetFrame = await _resolveTargetFrame();
      final controller = await DesktopMultiWindow.createWindow(jsonEncode({
        'type': 'player_window',
      }));
      controller
        ..setFrame(targetFrame)
        ..setTitle('Player View — Second Screen')
        ..show();
      _windowId = controller.windowId;
      state = state.copyWith(windowOpen: true);
      // Push full state once the sub-window has had a chance to set up its
      // method handler. A short delay is good enough for Phase 1; the
      // sub-window's `projection.ready` ack will replace this in Phase 2.
      Timer(const Duration(milliseconds: 250), () {
        final wid = _windowId;
        if (wid != null) {
          ProjectionIpc.pushFull(wid, state).then((ok) {
            if (!ok) _markWindowClosed();
          });
        }
      });
      return _windowId;
    } catch (e, st) {
      debugPrint('Failed to open player window: $e\n$st');
      return null;
    }
  }

  /// Picks where to place the new player window. Prefers a non-primary
  /// monitor (full screen). Falls back to centered default on the primary.
  Future<Rect> _resolveTargetFrame() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final primary = await screenRetriever.getPrimaryDisplay();
      // Pick first display whose id differs from the primary
      for (final d in displays) {
        if (d.id != primary.id) {
          final pos = d.visiblePosition ?? Offset.zero;
          final size = d.visibleSize ?? d.size;
          return Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
        }
      }
    } catch (e, st) {
      debugPrint('screen_retriever failed: $e\n$st');
    }
    // Fallback: centered 1280x720 on the primary display
    return const Rect.fromLTWH(120, 120, 1280, 720);
  }

  /// Closes the player sub-window. Tries the cooperative IPC close first
  /// (so the player isolate can run cleanup), then forces the OS window
  /// down via `WindowController.close()` so a wedged sub-isolate can't
  /// keep a stale window alive. Both calls are fire-and-forget — the DM
  /// flips its cast icon immediately so the UI stays in sync no matter
  /// what the player isolate does.
  Future<void> closeWindow() async {
    final id = _windowId;
    if (id == null) return;
    _windowId = null;
    state = state.copyWith(windowOpen: false);

    // Cooperative close — lets the player run dispose handlers.
    ProjectionIpc.requestClose(id);
    // Forced close — bypasses a wedged player isolate. Runs after a tiny
    // delay so a healthy player can win the race and shut down cleanly.
    Timer(const Duration(milliseconds: 200), () async {
      try {
        await WindowController.fromWindowId(id).close();
      } catch (_) {
        // Already gone — fine.
      }
    });
  }

  /// Called by the main isolate's reverse-IPC handler when the player
  /// window is closed externally (native X button). Equivalent to
  /// `_markWindowClosed` but exposed publicly so `main.dart` can route the
  /// `projection.player_closed` message into the controller.
  void notifyPlayerClosed() => _markWindowClosed();

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

    // Measure canvas FIRST so the first IPC push already has correct dims.
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
  ///
  /// Combat state only knows about tokens / hp / conditions / turnIndex —
  /// strokes, measurements, fog, grid, token sizing, and the viewport
  /// override are owned by `BattleMapNotifier` and pushed via their own
  /// patch path. To avoid re-encoding the entire `ProjectionState` (which
  /// can be hundreds of KB once fog is base64-encoded) on every HP tick or
  /// token drag, we update only the local state with a merged snapshot
  /// AND ship a token-only patch to the player window.
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
      // Refresh canvas dims if the underlying map was swapped.
      canvasWidth: snapshot.canvasWidth,
      canvasHeight: snapshot.canvasHeight,
      mapPath: snapshot.mapPath,
    );

    // Local state update — no full IPC push.
    final replacement = current.copyWith(snapshot: merged);
    final newItems = [
      for (final it in state.items)
        if (it.id == replacement.id) replacement else it,
    ];
    state = state.copyWith(items: newItems);

    // Tokens-only patch to the player window — small payload regardless
    // of how big the fog bitmap is.
    _pushBattleMapPatch(itemId, {
      'tokens': snapshot.tokens.map((t) => t.toJson()).toList(),
      'turnIndex': snapshot.turnIndex,
    });
  }

  /// Toggles the player viewport lock for a battle map projection. When
  /// locked, viewport sync from the DM's `BattleMapNotifier` becomes a
  /// no-op so the DM can pan/zoom privately.
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
  /// Skips work when the projection is locked. Pass `null` to clear the
  /// override (so the player paints fit-to-its-own-viewport for full-screen).
  /// Uses the optimized patch IPC instead of a full state push.
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
    // Patch instead of full push.
    _pushBattleMapPatch(itemId, {
      if (normalizedRect != null)
        'viewportNormalized': normalizedRect.toJson()
      else
        'viewportNormalized': null,
    });
  }

  /// Updates the "static" battle-map state (strokes, measurements, fog,
  /// token sizing, grid). Called by [BattleMapNotifier] from a debounced
  /// throttle so high-frequency edits don't spam IPC. Sends a patch — never
  /// re-encodes the entire `ProjectionState`.
  ///
  /// [includeFog] is `true` only when the fog has actually changed since
  /// the last push; when `false`, `fogDataBase64` is omitted from the
  /// patch entirely so we don't pay to JSON-serialize 100s of KB of
  /// base64 on every stroke.
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
    final id = _windowId;
    if (id != null) {
      ProjectionIpc.pushBattleMapPatch(id, itemId, patch).then((ok) {
        if (!ok) _markWindowClosed();
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
  // IPC + event bus plumbing
  // ---------------------------------------------------------------------

  void _pushFullAndEmit() {
    final id = _windowId;
    if (id != null) {
      // Fire-and-forget; on failure (window closed externally), clear our
      // stale id so future syncs become no-ops.
      ProjectionIpc.pushFull(id, state).then((ok) {
        if (!ok) _markWindowClosed();
      });
    }
    _emitEvent();
  }

  void _pushPatch(Map<String, dynamic> patch) {
    final id = _windowId;
    if (id != null) {
      ProjectionIpc.pushPatch(id, patch).then((ok) {
        if (!ok) _markWindowClosed();
      });
    }
  }

  /// Called when an IPC push fails — typically because the user closed the
  /// player window via its native X button. Clears the stale window id and
  /// flips `windowOpen` so the AppBar cast icon reflects reality.
  void _markWindowClosed() {
    if (_windowId == null && !state.windowOpen) return;
    _windowId = null;
    if (state.windowOpen) {
      state = state.copyWith(windowOpen: false);
    }
  }

  /// Emits a `projection.content_set` event on the AppEventBus. Offline this
  /// has no subscribers besides our own IPC layer; online (future) the
  /// NetworkBridge interceptor will fan it out to remote players.
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
/// encounter + entity data. Throttled to one rebuild per Riverpod update
/// (no per-token spam).
///
/// Watch this provider once at app start (e.g. in main_screen) to keep the
/// player window's battle map in sync with the DM's edits.
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
