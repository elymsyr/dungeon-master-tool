import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_window_app.dart';

/// Sub-isolate entrypoint for the player sub-window.
///
/// Called from `main.dart` when launched with `args == ['multi_window', <id>, <payload>]`.
/// Lives in its own isolate — no SoLoud, no AppPaths, no shared Riverpod
/// state with the DM. The DM owns the truth and pushes state via IPC.
void playerWindowMain(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final windowId = int.parse(args[1]);
  runApp(
    ProviderScope(
      child: PlayerWindowApp(windowId: windowId),
    ),
  );
}
