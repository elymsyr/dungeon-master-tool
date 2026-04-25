import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'application/providers/ui_state_provider.dart';
import 'application/services/projection_ipc.dart';
import 'core/config/app_paths.dart';
import 'core/config/supabase_config.dart';
import 'core/constants.dart' show appVersion;
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

  runApp(const _BootstrapGate());
}

/// Secondary entry point for the screencast presentation engine.
/// Must live in the root library (main.dart) because Android's
/// [DartExecutor.DartEntrypoint] with a null library URI only searches
/// the root library for the function name.
@pragma('vm:entry-point')
void screencastMain() => screencast_entry.screencastMain();

/// Splash + bootstrap sequence. Runs the async initialization steps
/// (AppPaths / Supabase / SoLoud / windowManager / UiState) while showing
/// a progress card with the current step name, then swaps itself out for
/// the real app once everything is ready.
///
/// Lives OUTSIDE of [ProviderScope] because the loaded [UiStateNotifier]
/// is passed as an override into the scope we create for [DungeonMasterApp].
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  String _message = 'Starting Dungeon Master Tool...';
  UiStateNotifier? _uiStateNotifier;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _setMessage(String m) {
    if (mounted) setState(() => _message = m);
  }

  Future<void> _bootstrap() async {
    try {
      _setMessage('Preparing file system...');
      await AppPaths.initialize();

      if (SupabaseConfig.isConfigured) {
        _setMessage('Connecting to cloud...');
        try {
          await Supabase.initialize(
            url: SupabaseConfig.url,
            anonKey: SupabaseConfig.anonKey,
          );
          // Fire-and-forget: updates profiles.last_active_at + app_version +
          // platform (migration 023). beta_participants.last_active_at also
          // bumped if user is in beta.
          if (Supabase.instance.client.auth.currentUser != null) {
            unawaited(
              Supabase.instance.client
                  .rpc('user_heartbeat', params: {
                    'p_app_version': appVersion,
                    'p_platform': kIsWeb ? 'web' : Platform.operatingSystem,
                  })
                  .then<void>((_) {})
                  .catchError((_) {}),
            );
          }
        } catch (e, st) {
          LogBuffer.instance.recordError(e, st, context: 'Supabase.init');
          debugPrint('Supabase init failed – online features disabled: $e');
        }
      }

      _setMessage('Loading audio engine...');
      try {
        await SoLoud.instance.init();
      } catch (e, st) {
        LogBuffer.instance.recordError(e, st, context: 'SoLoud.init');
        debugPrint('SoLoud init failed – audio disabled: $e');
      }

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _setMessage('Setting up window...');
        await windowManager.ensureInitialized();
        await windowManager.waitUntilReadyToShow(
          const WindowOptions(
            minimumSize: Size(900, 800),
            title: 'Dungeon Master Tool',
            titleBarStyle: TitleBarStyle.normal,
          ),
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );
      }

      _setMessage('Loading settings...');
      final uiStateNotifier = UiStateNotifier();
      await uiStateNotifier.load();

      if (!mounted) return;
      setState(() => _uiStateNotifier = uiStateNotifier);
    } catch (e, st) {
      LogBuffer.instance.recordError(e, st, context: 'Bootstrap');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1814),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Startup failed:\n$_error',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    if (_uiStateNotifier == null) {
      // Splash — dark background, app icon, spinner + bootstrap message.
      // Colors match the app's dark theme (castle-gold accent on near-black).
      const bg = Color(0xFF1A1814);
      const gold = Color(0xFFC8A24B);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/app_icon_transparent.png',
                  width: 160,
                  height: 160,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(gold),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ProviderScope(
      overrides: [uiStateProvider.overrideWith((_) => _uiStateNotifier!)],
      child: const DungeonMasterApp(),
    );
  }
}
