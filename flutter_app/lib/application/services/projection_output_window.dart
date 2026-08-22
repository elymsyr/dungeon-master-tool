import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../../domain/entities/projection/projection_state.dart';
import '../../main.dart' show playerWindowClosedSignal;
import 'projection_ipc.dart';
import 'projection_output.dart';

/// Desktop second-window output via `desktop_multi_window`.
///
/// Extracted from the former `ProjectionController.openWindow` / `closeWindow`
/// / IPC-push methods. Owns the window lifecycle and delegates serialized
/// state transport to [ProjectionIpc].
class ProjectionOutputWindow extends ProjectionOutput {
  /// The native window id, kept across deactivate/activate so the same OS
  /// window (and its Flutter engine) is reused instead of destroyed. Destroying
  /// a sub-window routes through `FlutterEngineRemoveView` on the implicit
  /// view, which the current engine rejects and then segfaults on during GL
  /// teardown — so we never destroy, only hide + show.
  static int? _persistedWindowId;

  int? _windowId;
  final _externalCloseController = StreamController<void>.broadcast();
  VoidCallback? _signalListener;

  @override
  bool get isActive => _windowId != null;

  @override
  Future<bool> activate() async {
    if (_windowId != null) return true;
    try {
      int id;
      if (_persistedWindowId != null) {
        // Reuse the previously-hidden window.
        id = _persistedWindowId!;
        await WindowController.fromWindowId(id).show();
      } else {
        final targetFrame = await _resolveTargetFrame();
        final controller = await DesktopMultiWindow.createWindow(jsonEncode({
          'type': 'player_window',
        }));
        controller
          ..setFrame(targetFrame)
          ..setTitle('Player View — Second Screen')
          ..show();
        id = controller.windowId;
        _persistedWindowId = id;
      }
      _windowId = id;

      // Listen to the reverse-IPC bridge from main.dart so the player
      // window's native close-button fires onExternalClose immediately.
      _signalListener = _onPlayerClosedSignal;
      playerWindowClosedSignal.addListener(_signalListener!);

      return true;
    } catch (e, st) {
      debugPrint('Failed to open player window: $e\n$st');
      return false;
    }
  }

  @override
  Future<void> deactivate() async {
    final id = _windowId;
    if (id == null) return;
    _windowId = null;
    _removeSignalListener();

    // Ask the player to clear its surface, then HIDE the native window.
    // Never close/destroy it — see _persistedWindowId.
    ProjectionIpc.requestClose(id);
    try {
      await WindowController.fromWindowId(id).hide();
    } catch (_) {
      // Window may already be hidden/gone — fine.
    }
  }

  @override
  Future<bool> pushFull(ProjectionState state) async {
    final id = _windowId;
    if (id == null) return false;
    final ok = await ProjectionIpc.pushFull(id, state);
    if (!ok) _markDead();
    return ok;
  }

  @override
  Future<bool> pushPatch(Map<String, dynamic> patch) async {
    final id = _windowId;
    if (id == null) return false;
    final ok = await ProjectionIpc.pushPatch(id, patch);
    if (!ok) _markDead();
    return ok;
  }

  @override
  Future<bool> pushBattleMapPatch(
      String itemId, Map<String, dynamic> patch) async {
    final id = _windowId;
    if (id == null) return false;
    final ok = await ProjectionIpc.pushBattleMapPatch(id, itemId, patch);
    if (!ok) _markDead();
    return ok;
  }

  @override
  Stream<void> get onExternalClose => _externalCloseController.stream;

  @override
  void dispose() {
    _removeSignalListener();
    _externalCloseController.close();
  }

  // -------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------

  /// Picks where to place the new player window. Prefers a non-primary
  /// monitor (full screen). Falls back to centered default on the primary.
  Future<Rect> _resolveTargetFrame() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final primary = await screenRetriever.getPrimaryDisplay();
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
    // Fallback: centered 1280×720 on the primary display.
    return const Rect.fromLTWH(120, 120, 1280, 720);
  }

  void _onPlayerClosedSignal() {
    _markDead();
  }

  void _markDead() {
    final id = _windowId;
    if (id == null) return;
    _windowId = null;
    _removeSignalListener();
    // Hide (never close) — the native window stays alive for reuse on the next
    // activate(). Covers the push-failure path too, where the window may still
    // be visible; the X-button path already hid it via main.dart's handler.
    unawaited(_hideQuietly(id));
    _externalCloseController.add(null);
  }

  static Future<void> _hideQuietly(int id) async {
    try {
      await WindowController.fromWindowId(id).hide();
    } catch (_) {
      // Window already gone/hidden — fine.
    }
  }

  void _removeSignalListener() {
    if (_signalListener != null) {
      playerWindowClosedSignal.removeListener(_signalListener!);
      _signalListener = null;
    }
  }
}
