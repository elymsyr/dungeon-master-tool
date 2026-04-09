import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../../domain/entities/projection/projection_state.dart';

/// IPC method names. One of these is the `MethodCall.method` over
/// `desktop_multi_window`'s window-to-window MethodChannel.
class ProjectionIpcMethods {
  /// DM → sub-window: full state push or partial patch.
  /// arguments = `{ 'type': 'full' | 'patch', 'payload': <json> }`
  static const apply = 'projection.apply';

  /// DM → sub-window: targeted partial update of one battle map projection.
  /// arguments = JSON `{ 'itemId': '...', 'patch': { ...partial snapshot } }`
  /// Drives the optimization path so we don't re-encode the entire
  /// `ProjectionState` for every stroke / fog edit / token-size change.
  static const battleMapPatch = 'projection.battleMapPatch';

  /// Sub-window → DM: ack handshake on first paint, also reports current
  /// `windowId` so the DM can target it for subsequent pushes.
  static const ready = 'projection.ready';

  /// Sub-window → DM: notification that the user closed the player window
  /// from its native chrome. The DM uses this to flip its cast icon back
  /// to "closed" without waiting for the next outbound push to fail.
  static const playerClosed = 'projection.player_closed';

  /// DM → sub-window: graceful close request.
  static const close = 'projection.close';
}

/// Thin wrapper around `DesktopMultiWindow.invokeMethod` for projection
/// state transport. Owns no state — just serializes and dispatches.
class ProjectionIpc {
  /// Push the **complete** projection state to the sub-window. Used on
  /// initial connect and whenever items are added/removed (which would make
  /// a partial patch ambiguous).
  ///
  /// Returns `true` on success. On any error (e.g. the player window has
  /// been closed externally), returns `false` so the caller can clear its
  /// stale `windowId` instead of crashing.
  static Future<bool> pushFull(int windowId, ProjectionState state) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        ProjectionIpcMethods.apply,
        jsonEncode({'type': 'full', 'payload': state.toJson()}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Push a small patch — used for high-frequency updates like active-item
  /// changes, blackout toggles, and per-item view state mutations.
  ///
  /// Patch format intentionally permissive — receiver merges only the keys
  /// it understands. Returns `false` if the target window is gone.
  static Future<bool> pushPatch(int windowId, Map<String, dynamic> patch) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        ProjectionIpcMethods.apply,
        jsonEncode({'type': 'patch', 'payload': patch}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Push a partial battle-map snapshot for one item — optimization path.
  /// Sends only the changed fields so we don't re-encode the entire
  /// `ProjectionState` (which can be hundreds of KB once fog is included)
  /// on every brushstroke or fog edit. Returns `false` if the target window
  /// is gone.
  static Future<bool> pushBattleMapPatch(
    int windowId,
    String itemId,
    Map<String, dynamic> patch,
  ) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        ProjectionIpcMethods.battleMapPatch,
        jsonEncode({'itemId': itemId, 'patch': patch}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Decode a `battleMapPatch` payload received by the sub-window.
  /// Returns `(itemId, patch)`.
  static (String, Map<String, dynamic>) decodeBattleMapPatch(dynamic raw) {
    final json = jsonDecode(raw as String) as Map<String, dynamic>;
    return (
      json['itemId'] as String,
      (json['patch'] as Map).cast<String, dynamic>(),
    );
  }

  /// Ask the sub-window to gracefully close itself.
  static Future<void> requestClose(int windowId) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        ProjectionIpcMethods.close,
        null,
      );
    } catch (_) {
      // Window may already be gone — ignore.
    }
  }

  /// Decode an `apply` payload received by the sub-window. Returns a
  /// `(type, data)` pair where type is `'full'` or `'patch'`.
  static (String, Map<String, dynamic>) decodeApply(dynamic raw) {
    final json = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = json['type'] as String;
    final payload = (json['payload'] as Map).cast<String, dynamic>();
    return (type, payload);
  }
}
