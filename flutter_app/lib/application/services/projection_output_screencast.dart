import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/projection/projection_state.dart';
import 'projection_output.dart';
import 'screencast_platform.dart';

/// External-display output via platform Presentation API.
///
/// Android: `DisplayManager` + `Presentation` with a hosted Flutter engine
/// iOS: `UIScreen` + `UIWindow` with a hosted Flutter view controller
///
/// Unlike [ProjectionOutputWindow], no IPC is needed on mobile — the
/// presentation Flutter engine communicates with this class via platform
/// channels, and state is pushed as JSON.
class ProjectionOutputScreencast extends ProjectionOutput {
  final ScreencastPlatform _platform;
  bool _active = false;
  StreamSubscription<void>? _disconnectSub;
  final _externalCloseController = StreamController<void>.broadcast();

  ProjectionOutputScreencast({ScreencastPlatform? platform})
      : _platform = platform ?? ScreencastPlatform();

  @override
  bool get isActive => _active;

  @override
  Future<bool> activate() async {
    if (_active) return true;

    final displays = await _platform.getAvailableDisplays();
    if (displays.isEmpty) {
      debugPrint('Screencast: no external displays found');
      return false;
    }

    // Use the first available external display.
    final target = displays.first;
    final ok = await _platform.startPresentation(target.id);
    if (!ok) {
      debugPrint('Screencast: failed to start presentation on ${target.name}');
      return false;
    }

    _active = true;
    _disconnectSub = _platform.onDisplayDisconnected.listen((_) {
      _markDead();
    });
    return true;
  }

  @override
  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    _disconnectSub?.cancel();
    _disconnectSub = null;
    await _platform.stopPresentation();
  }

  @override
  Future<bool> pushFull(ProjectionState state) async {
    if (!_active) return false;
    final ok = await _platform.pushState(state.toJson());
    if (!ok) _markDead();
    return ok;
  }

  @override
  Future<bool> pushPatch(Map<String, dynamic> patch) async {
    if (!_active) return false;
    // For screencast, send as a state push with patch type marker.
    final ok = await _platform.pushState({'type': 'patch', 'payload': patch});
    if (!ok) _markDead();
    return ok;
  }

  @override
  Future<bool> pushBattleMapPatch(
      String itemId, Map<String, dynamic> patch) async {
    if (!_active) return false;
    final ok = await _platform.pushBattleMapPatch(itemId, patch);
    if (!ok) _markDead();
    return ok;
  }

  @override
  Stream<void> get onExternalClose => _externalCloseController.stream;

  @override
  void dispose() {
    _disconnectSub?.cancel();
    _externalCloseController.close();
    _platform.dispose();
  }

  void _markDead() {
    if (!_active) return;
    _active = false;
    _disconnectSub?.cancel();
    _disconnectSub = null;
    _externalCloseController.add(null);
  }
}
