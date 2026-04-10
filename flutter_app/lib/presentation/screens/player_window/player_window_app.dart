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
  /// DM main window so its cast icon flips immediately AND so the DM can
  /// destroy this window via `WindowController.fromWindowId(...).close()` —
  /// the desktop_multi_window-native close path. We deliberately do NOT call
  /// `windowManager.destroy()` from inside the sub-window: on Linux that
  /// tries to remove the implicit Flutter view and triggers a fatal
  /// `FlutterEngineRemoveView ... kInvalidArguments` + GL context teardown
  /// crash. The DM-side close path goes through native window destruction
  /// instead and is the only path that's stable here.
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
      // ignore — DM may have died first; in that case the OS will tear
      // this process down momentarily anyway.
    }
    // Intentionally no destroy() here — wait for the DM to close us via
    // WindowController. setPreventClose(true) stays armed so the OS-level
    // close stays cancelled until the DM yanks the window out from under us.
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
        // Graceful close — just unhook the close-prevent guard and return.
        // The DM follows up with a `WindowController.fromWindowId(id).close()`
        // ~200ms later (see `ProjectionController.closeWindow`) which is the
        // only path that doesn't crash on Linux. We deliberately do NOT call
        // `windowManager.destroy()` here; doing so triggers the same
        // `FlutterEngineRemoveView ... kInvalidArguments` + GL context
        // assertion as the X-button path.
        try {
          await windowManager.setPreventClose(false);
        } catch (_) {
          // window_manager unavailable in this isolate — DM's forced close
          // will handle it.
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
