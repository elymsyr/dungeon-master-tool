import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/supabase_config.dart';

/// Base64-encoded app icon, lazily loaded from assets.
String? _cachedIconBase64;

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

      final iconBase64 = await _loadIconBase64();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(_buildSuccessHtml(iconBase64));
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

  // ── Success page helpers ──────────────────────────────────────────

  Future<String> _loadIconBase64() async {
    if (_cachedIconBase64 != null) return _cachedIconBase64!;
    final bytes = await rootBundle.load('assets/app_icon_transparent.png');
    _cachedIconBase64 = base64Encode(bytes.buffer.asUint8List());
    return _cachedIconBase64!;
  }

  String _buildSuccessHtml(String iconBase64) {
    return '<!DOCTYPE html>'
        '<html lang="en"><head>'
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Authentication Successful - Dungeon Master Tool</title>'
        '<style>'
        // ── Reset & base
        '*{margin:0;padding:0;box-sizing:border-box}'
        'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;'
        'min-height:100vh;display:flex;align-items:center;justify-content:center;'
        'background:#0f0f1a;color:#e0e0e0;overflow:hidden}'
        // ── Animated background
        '.bg{position:fixed;inset:0;'
        'background:radial-gradient(ellipse at 50% 0%,#1a1a2e 0%,#0f0f1a 70%);'
        'z-index:0}'
        '.bg::before{content:"";position:absolute;inset:0;'
        'background:radial-gradient(circle at 30% 80%,rgba(66,165,245,0.04) 0%,transparent 50%),'
        'radial-gradient(circle at 70% 20%,rgba(197,165,90,0.05) 0%,transparent 50%)}'
        // ── Floating particles
        '.particles{position:fixed;inset:0;z-index:1;pointer-events:none}'
        '.p{position:absolute;border-radius:50%;animation:float linear infinite;opacity:0}'
        '@keyframes float{0%{transform:translateY(100vh) scale(0);opacity:0}'
        '10%{opacity:1}90%{opacity:1}100%{transform:translateY(-20vh) scale(1);opacity:0}}'
        // ── Card
        '.card{position:relative;z-index:2;'
        'background:linear-gradient(145deg,rgba(30,30,46,0.9),rgba(20,20,32,0.95));'
        'backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);'
        'border:1px solid rgba(197,165,90,0.2);border-radius:20px;'
        'padding:48px 44px 40px;text-align:center;max-width:440px;width:92%;'
        'box-shadow:0 0 60px rgba(197,165,90,0.06),0 20px 60px rgba(0,0,0,0.5),'
        'inset 0 1px 0 rgba(255,255,255,0.05);'
        'animation:cardIn .7s cubic-bezier(.16,1,.3,1) both}'
        '@keyframes cardIn{from{opacity:0;transform:translateY(30px) scale(.96)}'
        'to{opacity:1;transform:translateY(0) scale(1)}}'
        // ── Icon container
        '.icon-wrap{position:relative;width:100px;height:100px;margin:0 auto 12px;'
        'animation:iconIn .6s cubic-bezier(.16,1,.3,1) .2s both}'
        '@keyframes iconIn{from{opacity:0;transform:scale(.5)}to{opacity:1;transform:scale(1)}}'
        '.icon-glow{position:absolute;inset:-12px;border-radius:50%;'
        'background:radial-gradient(circle,rgba(197,165,90,0.15) 0%,transparent 70%);'
        'animation:pulse 3s ease-in-out infinite}'
        '@keyframes pulse{0%,100%{opacity:.6;transform:scale(1)}50%{opacity:1;transform:scale(1.08)}}'
        '.icon-ring{position:absolute;inset:-4px;border-radius:50%;'
        'border:2px solid transparent;'
        'background:linear-gradient(135deg,rgba(197,165,90,0.4),rgba(197,165,90,0.1)) border-box;'
        '-webkit-mask:linear-gradient(#fff 0 0) padding-box,linear-gradient(#fff 0 0);'
        '-webkit-mask-composite:xor;mask-composite:exclude}'
        '.icon-img{width:100px;height:100px;object-fit:contain;'
        'filter:drop-shadow(0 4px 12px rgba(197,165,90,0.3))}'
        // ── Check badge
        '.badge{position:absolute;bottom:-2px;right:-2px;width:32px;height:32px;'
        'background:linear-gradient(135deg,#4ade80,#22c55e);border-radius:50%;'
        'display:flex;align-items:center;justify-content:center;'
        'box-shadow:0 2px 8px rgba(34,197,94,0.4),0 0 0 3px #0f0f1a;'
        'animation:badgeIn .5s cubic-bezier(.16,1,.3,1) .5s both}'
        '@keyframes badgeIn{from{opacity:0;transform:scale(0)}to{opacity:1;transform:scale(1)}}'
        '.badge svg{width:18px;height:18px}'
        // ── Divider diamond
        '.divider{display:flex;align-items:center;gap:12px;margin:20px 0 16px;'
        'animation:fadeIn .5s ease .6s both}'
        '@keyframes fadeIn{from{opacity:0}to{opacity:1}}'
        '.divider-line{flex:1;height:1px;'
        'background:linear-gradient(90deg,transparent,rgba(197,165,90,0.3),transparent)}'
        '.diamond{width:8px;height:8px;background:linear-gradient(135deg,#c5a55a,#8b7332);'
        'transform:rotate(45deg);border-radius:1px}'
        // ── Text
        'h1{font-size:24px;font-weight:700;color:#fff;letter-spacing:.5px;margin-bottom:6px;'
        'animation:textIn .5s ease .4s both}'
        '@keyframes textIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}'
        '.subtitle{font-size:14px;color:#8888a0;line-height:1.6;'
        'animation:textIn .5s ease .5s both}'
        '.hint{font-size:13px;color:#5a5a70;margin-top:12px;'
        'animation:textIn .5s ease .7s both}'
        '.hint kbd{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;'
        'background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.1);'
        'font-family:inherit;color:#8888a0}'
        // ── Brand footer
        '.brand{display:flex;align-items:center;justify-content:center;gap:8px;'
        'margin-top:24px;animation:textIn .5s ease .8s both}'
        '.brand-text{font-size:11px;color:#404050;letter-spacing:1.5px;'
        'text-transform:uppercase;font-weight:600}'
        '.brand-dot{width:3px;height:3px;border-radius:50%;background:#404050}'
        '.brand-ver{font-size:11px;color:#353545}'
        '</style></head><body>'
        // ── Background
        '<div class="bg"></div>'
        // ── Particles
        '<div class="particles">'
        '<div class="p" style="left:10%;width:2px;height:2px;background:#c5a55a;animation-duration:8s;animation-delay:0s"></div>'
        '<div class="p" style="left:20%;width:1px;height:1px;background:#42a5f5;animation-duration:12s;animation-delay:2s"></div>'
        '<div class="p" style="left:35%;width:2px;height:2px;background:#c5a55a;animation-duration:10s;animation-delay:4s"></div>'
        '<div class="p" style="left:50%;width:1px;height:1px;background:#fff;animation-duration:9s;animation-delay:1s"></div>'
        '<div class="p" style="left:65%;width:2px;height:2px;background:#42a5f5;animation-duration:11s;animation-delay:3s"></div>'
        '<div class="p" style="left:80%;width:1px;height:1px;background:#c5a55a;animation-duration:7s;animation-delay:5s"></div>'
        '<div class="p" style="left:90%;width:2px;height:2px;background:#fff;animation-duration:13s;animation-delay:0s"></div>'
        '</div>'
        // ── Card
        '<div class="card">'
        // ── Icon
        '<div class="icon-wrap">'
        '<div class="icon-glow"></div>'
        '<div class="icon-ring"></div>'
        '<img class="icon-img" src="data:image/png;base64,$iconBase64" alt="Dungeon Master Tool">'
        '<div class="badge"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L19 7"/></svg></div>'
        '</div>'
        // ── Divider
        '<div class="divider"><div class="divider-line"></div><div class="diamond"></div><div class="divider-line"></div></div>'
        // ── Text
        '<h1>Authentication Successful</h1>'
        '<p class="subtitle">You have been authenticated. Return to the app to continue your quest.</p>'
        '<p class="hint">You can safely close this tab</p>'
        // ── Brand
        '<div class="brand">'
        '<span class="brand-text">Dungeon Master Tool</span>'
        '<span class="brand-dot"></span>'
        '<span class="brand-ver">v2.0.3</span>'
        '</div>'
        '</div>'
        '</body></html>';
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
