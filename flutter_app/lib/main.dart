import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_paths.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.initialize();

  runApp(
    const ProviderScope(
      child: DungeonMasterApp(),
    ),
  );
}
