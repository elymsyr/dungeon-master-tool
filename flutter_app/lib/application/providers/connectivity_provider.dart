import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of online/offline transitions. `true` when any non-`none` interface
/// is up.
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

/// No-op artık. Sync tamamen manueldir; reconnect otomatik tick yapmaz.
final connectivityWatcherProvider = Provider<void>((ref) {});
