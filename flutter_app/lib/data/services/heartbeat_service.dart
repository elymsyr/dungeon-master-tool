import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart' show appVersion;
import '../../core/services/log_buffer.dart';

/// Keeps `profiles.last_active_at` / `app_version` / `platform` populated
/// (admin panel columns) for every authenticated session.
///
/// Triggers a `user_heartbeat` RPC on:
///   1. service start (existing session at boot),
///   2. every `signedIn` / `tokenRefreshed` auth event,
///   3. a 15-minute foreground timer while the app is resumed.
///
/// Pauses the periodic timer when the app is backgrounded so mobile builds
/// don't wake the radio for an idle ping.
class HeartbeatService with WidgetsBindingObserver {
  HeartbeatService._();
  static final HeartbeatService instance = HeartbeatService._();

  static const Duration _interval = Duration(minutes: 15);

  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  bool _started = false;
  bool _foreground = true;

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) {
        switch (event.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            unawaited(send());
          default:
            break;
        }
      },
      onError: (Object e, StackTrace st) {
        LogBuffer.instance.recordError(e, st, context: 'Heartbeat.authStream');
      },
    );

    if (Supabase.instance.client.auth.currentUser != null) {
      unawaited(send());
    }

    _startTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _authSub?.cancel();
    _authSub = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  Future<void> send() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc('user_heartbeat', params: {
        'p_app_version': appVersion,
        'p_platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });
    } catch (e, st) {
      LogBuffer.instance.recordError(e, st, context: 'Heartbeat.send');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer.periodic(_interval, (_) => unawaited(send()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    _foreground = next;
    if (_foreground) {
      unawaited(send());
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}
