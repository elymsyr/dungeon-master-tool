import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Lightweight auth state exposed to the UI.
class AuthState {
  final String uid;
  final String email;
  const AuthState({required this.uid, required this.email});
}

/// Manages Supabase auth state. When Supabase is not configured the notifier
/// stays inert (state is always null) and the app runs fully offline.
class AuthNotifier extends StateNotifier<AuthState?> {
  AuthNotifier() : super(null) {
    _init();
  }

  StreamSubscription<AuthState?>? _sub;

  void _init() {
    if (!SupabaseConfig.isConfigured) return;

    final client = Supabase.instance.client;

    // Restore session from persistent storage (supabase_flutter handles this).
    final session = client.auth.currentSession;
    if (session != null) {
      _setFromUser(session.user);
    }

    // React to future auth changes (sign-in, sign-out, token refresh).
    _sub = client.auth.onAuthStateChange
        .map((data) {
          final user = data.session?.user;
          if (user != null) {
            return AuthState(uid: user.id, email: user.email ?? '');
          }
          return null;
        })
        .listen((authState) => state = authState);
  }

  void _setFromUser(User user) {
    state = AuthState(uid: user.id, email: user.email ?? '');
  }

  /// Register a new account. Returns `null` on success, an error message on
  /// failure. When Supabase email confirmation is enabled the user will need
  /// to verify their email before a session is established.
  Future<String?> signUp(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with an existing account. Returns `null` on success.
  Future<String?> signIn(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out and clear local session.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    state = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState?>(
  (ref) => AuthNotifier(),
);
