import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/supabase_config.dart';

/// Lightweight auth state exposed to the UI.
class AuthState {
  final String uid;
  final String email;
  final String provider; // 'email', 'google', etc.
  final DateTime? createdAt;

  const AuthState({
    required this.uid,
    required this.email,
    this.provider = 'email',
    this.createdAt,
  });
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
          if (user == null) return null;
          final provider =
              user.appMetadata['provider'] as String? ?? 'email';
          return AuthState(
            uid: user.id,
            email: user.email ?? '',
            provider: provider,
            createdAt: DateTime.tryParse(user.createdAt),
          );
        })
        .listen((authState) => state = authState);
  }

  void _setFromUser(User user) {
    final provider = user.appMetadata['provider'] as String? ?? 'email';
    state = AuthState(
      uid: user.id,
      email: user.email ?? '',
      provider: provider,
      createdAt: DateTime.tryParse(user.createdAt),
    );
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

  /// Sign in with an OAuth provider (Google, GitHub, etc.) via PKCE flow.
  /// Uses deep links on mobile and a local HTTP server on desktop.
  Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _signInWithOAuthMobile(provider);
    }
    return _signInWithOAuthDesktop(provider);
  }

  /// Mobile: open browser with deep-link redirect.
  /// supabase_flutter intercepts the callback and exchanges the code
  /// for a session automatically via its built-in deep link handler.
  Future<String?> _signInWithOAuthMobile(OAuthProvider provider) async {
    try {
      const redirectUrl = 'com.elymsyr.dungeonmastertool://auth-callback';

      final res = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: provider,
        redirectTo: redirectUrl,
      );

      await launchUrl(Uri.parse(res.url), mode: LaunchMode.externalApplication);

      // supabase_flutter handles the deep link callback and session
      // exchange. The onAuthStateChange listener in _init() will
      // update the provider state and the UI will navigate to hub.
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Desktop: start a temporary local HTTP server to catch the callback,
  /// then exchange the auth code for a session.
  Future<String?> _signInWithOAuthDesktop(OAuthProvider provider) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind('localhost', 0);
      final redirectUrl = 'http://localhost:${server.port}/auth/callback';

      final res = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: provider,
        redirectTo: redirectUrl,
      );

      await launchUrl(Uri.parse(res.url), mode: LaunchMode.externalApplication);

      final request = await server.first;
      final code = request.uri.queryParameters['code'];

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<!DOCTYPE html>'
          '<html><head>'
          '<meta charset="utf-8">'
          '<meta name="viewport" content="width=device-width,initial-scale=1">'
          '<title>Authentication Successful</title>'
          '<style>'
          '*{margin:0;padding:0;box-sizing:border-box}'
          'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;'
          'background:linear-gradient(135deg,#1a1a2e 0%,#16213e 50%,#0f3460 100%);'
          'color:#e0e0e0;min-height:100vh;display:flex;align-items:center;justify-content:center}'
          '.card{background:rgba(255,255,255,0.07);backdrop-filter:blur(12px);'
          'border:1px solid rgba(255,255,255,0.1);border-radius:16px;'
          'padding:48px 40px;text-align:center;max-width:420px;width:90%}'
          '.icon{width:64px;height:64px;background:linear-gradient(135deg,#4ade80,#22c55e);'
          'border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 24px}'
          '.icon svg{width:32px;height:32px;fill:#fff}'
          'h1{font-size:22px;font-weight:600;margin-bottom:8px;color:#fff}'
          'p{font-size:14px;color:#a0a0b0;line-height:1.6}'
          '.brand{font-size:12px;color:#505060;margin-top:24px}'
          '</style></head><body>'
          '<div class="card">'
          '<div class="icon"><svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg></div>'
          '<h1>Authentication Successful</h1>'
          '<p>You can close this tab and return to the app.</p>'
          '<p class="brand">Dungeon Master Tool</p>'
          '</div></body></html>',
        );
      await request.response.close();
      await server.close();
      server = null;

      if (code != null) {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      }

      return null;
    } on AuthException catch (e) {
      await server?.close();
      return e.message;
    } catch (e) {
      await server?.close();
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
