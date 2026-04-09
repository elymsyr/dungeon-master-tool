import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../application/services/projection_ipc.dart';
import '../../../domain/entities/projection/projection_state.dart';
import 'player_window_root.dart';
import 'player_window_state_provider.dart';

/// Top-level widget for the player sub-window. Wires the IPC method handler
/// from the DM into the local `PlayerProjectionStateNotifier`.
class PlayerWindowApp extends ConsumerStatefulWidget {
  final int windowId;
  const PlayerWindowApp({required this.windowId, super.key});

  @override
  ConsumerState<PlayerWindowApp> createState() => _PlayerWindowAppState();
}

class _PlayerWindowAppState extends ConsumerState<PlayerWindowApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethod);
    _setupWindowListener();
  }

  Future<void> _setupWindowListener() async {
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      // Hook the close button so we can notify the DM before exiting.
      await windowManager.setPreventClose(true);
    } catch (_) {
      // Wayland / unsupported configurations — fall back to the IPC-failure
      // path on the DM side, which clears the cast icon on the next push.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    DesktopMultiWindow.setMethodHandler(null);
    super.dispose();
  }

  /// Native close-button intercepted by `setPreventClose(true)`. Notify the
  /// DM main window so its cast icon flips immediately, then actually close.
  @override
  void onWindowClose() async {
    try {
      // windowId 0 is the DM main window.
      await DesktopMultiWindow.invokeMethod(
        0,
        ProjectionIpcMethods.playerClosed,
        null,
      );
    } catch (_) {
      // ignore — DM may have died first
    }
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      // last resort
    }
  }

  Future<dynamic> _handleMethod(MethodCall call, int fromWindowId) async {
    switch (call.method) {
      case ProjectionIpcMethods.apply:
        final (type, payload) = ProjectionIpc.decodeApply(call.arguments);
        final notifier = ref.read(playerProjectionStateProvider.notifier);
        if (type == 'full') {
          notifier.applyFull(ProjectionState.fromJson(payload));
        } else {
          notifier.applyPatch(payload);
        }
        return null;
      case ProjectionIpcMethods.battleMapPatch:
        final (itemId, patch) =
            ProjectionIpc.decodeBattleMapPatch(call.arguments);
        ref
            .read(playerProjectionStateProvider.notifier)
            .applyBattleMapPatch(itemId, patch);
        return null;
      case ProjectionIpcMethods.close:
        // Graceful close — windowManager.destroy() detaches just this OS
        // window without using SystemNavigator.pop(), which on Linux
        // desktop_multi_window propagates "Lost connection to device" to
        // the parent process.
        try {
          await windowManager.setPreventClose(false);
          await windowManager.destroy();
        } catch (_) {
          // Fallback if window_manager is unavailable in this isolate.
        }
        return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Player View',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: PlayerWindowRoot(),
      ),
    );
  }
}
