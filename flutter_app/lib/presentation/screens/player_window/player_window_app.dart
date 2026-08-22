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
  /// DM main window so its cast icon flips immediately, then HIDE this window.
  /// We deliberately do NOT destroy it (via `windowManager.destroy()` or the
  /// DM-side `close()`): destroying a `fl_view_new` sub-window routes through
  /// `FlutterEngineRemoveView` on the implicit view, which the current engine
  /// rejects and then segfaults on during GL teardown. Hiding keeps the window
  /// + engine alive so the DM can `show()` it again on the next projection.
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
    try {
      await windowManager.hide();
    } catch (_) {
      // window_manager unavailable — the DM's playerClosed handler will hide
      // us from the other side.
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
        // The DM is hiding us — clear the surface so the next show() doesn't
        // flash stale content before the DM pushes fresh state. Never destroy.
        ref.read(playerProjectionStateProvider.notifier).clear();
        try {
          await windowManager.hide();
        } catch (_) {
          // The DM hides us natively right after this IPC; ignore failures.
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
