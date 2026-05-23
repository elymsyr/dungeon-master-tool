import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_paths.dart';
import '../../../core/config/supabase_config.dart';
import 'player_window_app.dart';

/// Sub-isolate entrypoint for the player sub-window.
///
/// Called from `main.dart` when launched with `args == ['multi_window', <id>, <payload>]`.
/// Lives in its own isolate — no SoLoud, no shared Riverpod state with the
/// DM. The DM owns the truth and pushes state via IPC. AppPaths IS inited
/// here so ContentStore (used by AssetRef rendering) has a cache dir.
///
/// Supabase IS initialized here: image projection + battle-map background
/// resolve AssetRefs through `assetServiceProvider`, which reads
/// `Supabase.instance` at provider-eval time. Without init the sub-window
/// throws "Supabase.instance not initialized" the moment a cloud asset
/// renders. Auth state is per-isolate; the sub-window stays anonymous and
/// uses the public storage URLs the DM has already prepared.
void playerWindowMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final windowId = int.parse(args[1]);
  // ContentStore (resolved transitively via assetServiceProvider) reads
  // AppPaths.cacheDir. Sub-isolate has its own static fields, so init here
  // too — otherwise LateInitializationError when an AssetRef renders.
  try {
    await AppPaths.initialize();
  } catch (e) {
    debugPrint('PlayerWindow AppPaths init failed: $e');
  }
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('PlayerWindow Supabase init failed: $e');
    }
  }
  runApp(
    ProviderScope(
      child: PlayerWindowApp(windowId: windowId),
    ),
  );
}
