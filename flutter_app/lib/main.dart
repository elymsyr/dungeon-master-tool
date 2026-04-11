import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'application/providers/ui_state_provider.dart';
import 'application/services/projection_ipc.dart';
import 'core/config/app_paths.dart';
import 'core/services/log_buffer.dart';
import 'presentation/screens/player_window/player_window_main.dart';
import 'presentation/screens/player_window/screencast_main.dart'
    as screencast_entry;

/// Bumped by the DM-side reverse-IPC handler whenever the player sub-window
/// notifies us that it was closed externally. The `ProjectionController`
/// listens to this notifier and routes a `notifyPlayerClosed()` call so the
/// AppBar cast icon flips back to "closed" without waiting for the next
/// outbound IPC push to fail.
final ValueNotifier<int> playerWindowClosedSignal = ValueNotifier<int>(0);

void main(List<String> args) async {
  // Player sub-window entrypoint — desktop_multi_window launches us with
  // ['multi_window', <windowId>, <argument>]. The sub-isolate needs neither
  // SoLoud nor AppPaths nor uiState — it is a pure rendering slave driven
  // by IPC from the DM. Branch BEFORE any of those heavy initializers.
  if (args.isNotEmpty && args.first == 'multi_window') {
    playerWindowMain(args);
    return;
  }

  // Initialize binding in the root zone — runZonedGuarded around runApp causes
  // a "Zone mismatch" warning on hot restart, so we use PlatformDispatcher's
  // global error hook for uncaught async errors instead.
  WidgetsFlutterBinding.ensureInitialized();
  LogBuffer.install();

  // Reverse-IPC handler so sub-windows can notify the DM. The player window's
  // `WindowListener.onWindowClose` fires this when the user clicks the native
  // X button. We do TWO things:
  //
  //   1. Bump `playerWindowClosedSignal` so the DM's `ProjectionController`
  //      flips the cast icon back to "closed" immediately.
  //   2. Actually destroy the sub-window via
  //      `WindowController.fromWindowId(fromWindowId).close()`. This is the
  //      desktop_multi_window-native close path and the only one that doesn't
  //      crash on Linux — calling `windowManager.destroy()` from inside the
  //      sub-window itself trips a fatal `FlutterEngineRemoveView ...
  //      kInvalidArguments` + EGL/GLX context assertion. The sub-window now
  //      sends us this signal and waits for us to take it down from outside.
  DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
    if (call.method == ProjectionIpcMethods.playerClosed) {
      playerWindowClosedSignal.value++;
      try {
        await WindowController.fromWindowId(fromWindowId).close();
      } catch (_) {
        // Already gone or in a bad state — fine. The DM-side cast icon
        // already flipped via the signal above, so the UI stays consistent.
      }
    }
    return null;
  });

  // Kill any sub-windows that survived a previous run (or hot restart).
  // The player window is a separate OS process and is NOT torn down by
  // hot restart, so without this we end up with stale player windows
  // running OLD code from the previous build. Closing them here means
  // every fresh DM start guarantees a fresh player isolate next time
  // the user clicks the cast button.
  try {
    final stale = await DesktopMultiWindow.getAllSubWindowIds();
    for (final id in stale) {
      try {
        await WindowController.fromWindowId(id).close();
      } catch (_) {
        // Best-effort: window may already be gone or in a bad state.
      }
    }
  } catch (_) {
    // getAllSubWindowIds isn't supported on every platform — skip.
  }

  FlutterError.onError = (details) {
    LogBuffer.instance.recordError(
      details.exception,
      details.stack,
      context: 'FlutterError',
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogBuffer.instance.recordError(error, stack, context: 'PlatformDispatcher');
    return true; // swallow — already logged
  };

  await AppPaths.initialize();

  // SoLoud audio engine — tüm platformlarda çalışır.
  // Wrapped in try/catch so the app can still launch when the audio backend
  // is unavailable (e.g. missing libFLAC on some Linux distros).
  try {
    await SoLoud.instance.init();
  } catch (e, st) {
    LogBuffer.instance.recordError(e, st, context: 'SoLoud.init');
    debugPrint('SoLoud init failed – audio disabled: $e');
  }

  // Desktop window setup
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        minimumSize: Size(
          900,
          800,
        ), // TODO: revert to Size(900, 800) after mobile testing
        title: 'Dungeon Master Tool',
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  // UiState'i SharedPreferences'dan yükle
  final uiStateNotifier = UiStateNotifier();
  await uiStateNotifier.load();

  runApp(
    ProviderScope(
      overrides: [uiStateProvider.overrideWith((_) => uiStateNotifier)],
      child: const DungeonMasterApp(),
    ),
  );
}

/// Secondary entry point for the screencast presentation engine.
/// Must live in the root library (main.dart) because Android's
/// [DartExecutor.DartEntrypoint] with a null library URI only searches
/// the root library for the function name.
@pragma('vm:entry-point')
void screencastMain() => screencast_entry.screencastMain();
