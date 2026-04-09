import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'application/providers/ui_state_provider.dart';
import 'core/config/app_paths.dart';
import 'core/services/log_buffer.dart';

void main() async {
  // Bug report için debug çıktı yakalama — runApp'ten önce kurulmalı
  LogBuffer.install();

  // Flutter framework hatalarını yakala
  FlutterError.onError = (details) {
    LogBuffer.instance.recordError(
      details.exception,
      details.stack,
      context: 'FlutterError',
    );
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();
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

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          uiStateProvider.overrideWith((_) => uiStateNotifier),
        ],
        child: const DungeonMasterApp(),
      ),
    ),
    (error, stack) {
      LogBuffer.instance.recordError(error, stack, context: 'Zone');
    },
  );
}
