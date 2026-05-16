import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../services/sync_engine.dart';

/// Singleton [SyncEngine] — owns the outbox drain loop for the lifetime of
/// the app. Started eagerly from `main.dart` and torn down on auth/user
/// switches via [appDatabaseProvider] invalidation.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = SyncEngine(db, ref)..start();
  ref.onDispose(engine.stop);
  return engine;
});

