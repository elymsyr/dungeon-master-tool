import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers/ui_state_provider.dart';
import 'core/config/app_paths.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.initialize();

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
