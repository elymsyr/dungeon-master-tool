import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'application/providers/ui_state_provider.dart';
import 'core/config/app_paths.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.initialize();

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
