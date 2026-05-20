import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_format.dart';

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

/// Wraps a network [fetch] with an offline pre-check and a hard timeout so a
/// provider never hangs on an infinite spinner. Throws [OfflineException]
/// immediately when the device is offline, or after [timeout] elapses (the
/// "connectivity reported up but no real internet" fail-open case).
///
/// `cachedFetch` should stay OUTSIDE this call so a fresh cache is still
/// served while offline.
Future<T> guardedNetwork<T>(
  Ref ref,
  Future<T> Function() fetch, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final online = ref.read(connectivityStreamProvider).valueOrNull ?? true;
  if (!online) throw const OfflineException();
  return fetch().timeout(
    timeout,
    onTimeout: () => throw const OfflineException(),
  );
}
