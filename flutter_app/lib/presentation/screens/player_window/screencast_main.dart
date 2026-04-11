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
  debugPrint('SCREENCAST: screencastMain() entry point started');
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

  bool _hasReceivedState = false;

  @override
  void initState() {
    super.initState();
    debugPrint('SCREENCAST: initState — setting method handler');
    _channel.setMethodCallHandler(_handleMethod);
    // Signal to the native side that the method call handler is ready.
    _channel.invokeMethod('engineReady', null);
    debugPrint('SCREENCAST: engineReady signal sent');
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    debugPrint('SCREENCAST: received method=${call.method}');
    try {
      final notifier = ref.read(playerProjectionStateProvider.notifier);
      switch (call.method) {
        case 'applyState':
          final args = call.arguments;
          if (args is Map) {
            final map = args.cast<String, dynamic>();
            debugPrint('SCREENCAST: applyState keys=${map.keys.toList()}');
            if (map['type'] == 'patch') {
              final payload =
                  (map['payload'] as Map).cast<String, dynamic>();
              notifier.applyPatch(payload);
              debugPrint('SCREENCAST: patch applied');
            } else {
              final state = ProjectionState.fromJson(map);
              notifier.applyFull(state);
              debugPrint(
                  'SCREENCAST: full state applied, ${state.items.length} items, active=${state.activeItemId}');
            }
            if (!_hasReceivedState) {
              setState(() => _hasReceivedState = true);
            }
          } else {
            debugPrint(
                'SCREENCAST: applyState args not a Map: ${args.runtimeType}');
          }
          return null;
        case 'applyBattleMapPatch':
          final args = call.arguments;
          if (args is Map) {
            final map = args.cast<String, dynamic>();
            final itemId = map['itemId'] as String;
            final patch = (map['patch'] as Map).cast<String, dynamic>();
            notifier.applyBattleMapPatch(itemId, patch);
            debugPrint('SCREENCAST: battleMapPatch applied for $itemId');
          }
          return null;
      }
    } catch (e, st) {
      debugPrint('SCREENCAST: ERROR in _handleMethod: $e');
      debugPrint('SCREENCAST: $st');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SCREENCAST: build() hasReceivedState=$_hasReceivedState');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Player View',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PlayerWindowRoot(),
            if (!_hasReceivedState)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cast_connected, color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for projection state...',
                      style: TextStyle(color: Colors.white38, fontSize: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
