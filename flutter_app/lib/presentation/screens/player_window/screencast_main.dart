import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/projection/projection_state.dart';
import 'player_window_root.dart';
import 'player_window_state_provider.dart';

/// Screencast entry point — runs inside the dedicated FlutterEngine that the
/// native Presentation / UIWindow hosts on the external display.
///
/// Receives state from the DM's main engine via a platform channel
/// (`screencast_render`) instead of `desktop_multi_window` IPC.
@pragma('vm:entry-point')
void screencastMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: const _ScreencastApp(),
    ),
  );
}

class _ScreencastApp extends ConsumerStatefulWidget {
  const _ScreencastApp();

  @override
  ConsumerState<_ScreencastApp> createState() => _ScreencastAppState();
}

class _ScreencastAppState extends ConsumerState<_ScreencastApp> {
  static const _channel =
      MethodChannel('com.elymsyr.dungeon_master_tool/screencast_render');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethod);
    // Signal to the native side that the method call handler is ready.
    _channel.invokeMethod('engineReady', null);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    final notifier = ref.read(playerProjectionStateProvider.notifier);
    switch (call.method) {
      case 'applyState':
        final args = call.arguments;
        if (args is Map) {
          final map = args.cast<String, dynamic>();
          // Check if it's a patch or full state.
          if (map['type'] == 'patch') {
            final payload =
                (map['payload'] as Map).cast<String, dynamic>();
            notifier.applyPatch(payload);
          } else {
            notifier.applyFull(ProjectionState.fromJson(map));
          }
        }
        return null;
      case 'applyBattleMapPatch':
        final args = call.arguments;
        if (args is Map) {
          final map = args.cast<String, dynamic>();
          final itemId = map['itemId'] as String;
          final patch = (map['patch'] as Map).cast<String, dynamic>();
          notifier.applyBattleMapPatch(itemId, patch);
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
