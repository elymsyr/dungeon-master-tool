import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_engine_provider.dart';

/// Stream of online/offline transitions. `true` when any non-`none` interface
/// is up. Used by the [SyncEngine] to wake on reconnect.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  bool isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);
  try {
    yield isOnline(await conn.checkConnectivity());
  } catch (e) {
    debugPrint('connectivity initial check failed: $e');
    yield true; // fail-open — assume online so syncs aren't paused forever.
  }
  yield* conn.onConnectivityChanged.map(isOnline);
});

/// Side-effect provider: on the offline → online edge, force a SyncEngine
/// tick so the outbox drains without waiting for the next mutation to wake
/// the change stream.
final connectivityWatcherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (prev, next) {
    final wasOnline = prev?.valueOrNull ?? false;
    final isOnline = next.valueOrNull ?? false;
    if (!wasOnline && isOnline) {
      // ignore: discarded_futures
      ref.read(syncEngineProvider).forceTick();
    }
  });
});
