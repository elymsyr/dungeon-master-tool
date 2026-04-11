import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Describes an external display detected by the platform.
class ExternalDisplay {
  final String id;
  final String name;
  final int width;
  final int height;

  const ExternalDisplay({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
  });

  factory ExternalDisplay.fromMap(Map<String, dynamic> map) => ExternalDisplay(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'External Display',
        width: map['width'] as int? ?? 1920,
        height: map['height'] as int? ?? 1080,
      );
}

/// Thin wrapper around the platform channel for screencast functionality.
///
/// Android: `DisplayManager` + `Presentation` API
/// iOS: `UIScreen` + `UIWindow`
class ScreencastPlatform {
  static const _channel =
      MethodChannel('com.elymsyr.dungeon_master_tool/screencast');
  static const _eventChannel =
      EventChannel('com.elymsyr.dungeon_master_tool/screencast/events');

  StreamSubscription<dynamic>? _eventSub;
  final _displayDisconnectedController = StreamController<void>.broadcast();

  ScreencastPlatform();

  /// Begin listening for display-disconnect events from the platform.
  ///
  /// Must be called only once. Only [ProjectionOutputScreencast] needs this —
  /// the display picker relies on polling alone.
  void startListening() {
    if (_eventSub != null) return;
    _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map && event['event'] == 'displayDisconnected') {
        _displayDisconnectedController.add(null);
      }
    }, onError: (error) {
      debugPrint('ScreencastPlatform: event stream error: $error');
    });
  }

  /// Returns the list of available external displays, or empty if none.
  Future<List<ExternalDisplay>> getAvailableDisplays() async {
    try {
      final result = await _channel.invokeListMethod<Map>('getAvailableDisplays');
      if (result == null) return const [];
      return result
          .map((m) => ExternalDisplay.fromMap(m.cast<String, dynamic>()))
          .toList();
    } on MissingPluginException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Start rendering the projection on the external display with [displayId].
  /// Returns `true` on success.
  Future<bool> startPresentation(String displayId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startPresentation',
        {'displayId': displayId},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint(
          'ScreencastPlatform.startPresentation failed: ${e.code} — ${e.message}');
      return false;
    }
  }

  /// Stop the active presentation.
  Future<void> stopPresentation() async {
    try {
      await _channel.invokeMethod<void>('stopPresentation');
    } catch (_) {
      // ignore
    }
  }

  /// Push projection state JSON to the native presentation Flutter engine.
  Future<bool> pushState(Map<String, dynamic> stateJson) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'pushState',
        stateJson,
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Push a battle map patch to the native presentation Flutter engine.
  Future<bool> pushBattleMapPatch(
      String itemId, Map<String, dynamic> patch) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'pushBattleMapPatch',
        {'itemId': itemId, 'patch': patch},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fires when the external display is disconnected.
  Stream<void> get onDisplayDisconnected =>
      _displayDisconnectedController.stream;

  void dispose() {
    _eventSub?.cancel();
    _displayDisconnectedController.close();
  }
}
