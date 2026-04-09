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

  // Reverse-IPC handler so sub-windows can notify the DM. Currently used by
  // the player window's `WindowListener.onWindowClose` to flip the cast icon
  // back to "closed" the moment the user closes the second window via its
  // native chrome — without waiting for the next outbound push to fail.
  DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
    if (call.method == ProjectionIpcMethods.playerClosed) {
      playerWindowClosedSignal.value++;
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

  // SoLoud audio engine — tüm platformlarda çalışır
  await SoLoud.instance.init();

  // Desktop window setup
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        minimumSize: Size(800, 600),
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
      overrides: [
        uiStateProvider.overrideWith((_) => uiStateNotifier),
      ],
      child: const DungeonMasterApp(),
    ),
  );
}
