---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/providers/auth_provider.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `auth_provider.dart`

> [!abstract] Primary Purpose
> Riverpod-managed Supabase auth state for the app: session restore, sign-up/sign-in (email + OAuth/PKCE with platform-specific callback handling), sign-out, and an account-ban enforcement loop. Exposes the lightweight `AuthState` that the entire online stack gates on.

## Inputs / Outputs
**Inputs**
- Providers watched: `connectivityProvider` (via `guardedNetwork`).
- Supabase subscribed: `client.auth.onAuthStateChange` stream (sign-in / sign-out / token refresh).
- Triggers (lifecycle): `AppLifecycleListener.onResume` (mobile OAuth deep-link grace period).
- Reads asset: `assets/app_icon_transparent.png` (desktop success page).

**Outputs**
- Providers exposed: `authProvider` → `StateNotifierProvider<AuthNotifier, AuthState?>`.
- Public API: `signUp(email,pw)`, `signIn(email,pw)`, `signInWithOAuth(provider)`, `signOut()`, `checkBanStatus()`, `banMessageNotifier` (ValueNotifier<String?>).
- Supabase RPC called: `am_i_banned`.

## Dependencies & Links
- Depends on: `SupabaseConfig`, `connectivity_provider`, `cached_provider` (`clearCache`), `error_format` (`guardedNetwork`/`isOfflineError`)
- Used by: [[world_membership_provider]], [[heartbeat_service]] (auth events), and virtually all online providers (presence of session)
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: [[migrations-auth-social]]

## Key Logic / Variables
- `AuthState { uid, email, provider, createdAt }`; equality only on `uid`+`email`.
- If `!SupabaseConfig.isConfigured`, the notifier stays inert (state always `null`) — app runs fully offline.
- **Init**: restores `currentSession` if present (and runs a startup ban check), then subscribes to `onAuthStateChange`. The `onError` handler is critical — without it a stream error (e.g. failed deep-link exchange) would cancel the sub permanently.
- **Ban enforcement**: `checkBanStatus()` calls `am_i_banned` RPC; if banned returns a message (with optional reason) — does NOT sign out. `_enforceBanCheck()` runs on startup restore, every sign-in/token-refresh, and signs out + `clearCache()` + sets `banMessageNotifier` (landing screen shows the dialog after the unauth transition — single UX point).
- **OAuth**: `signInWithOAuth` branches by platform:
  - Mobile (`_signInWithOAuthMobile`): `getOAuthSignInUrl(redirectTo: _authRedirect)`, subscribes to `onAuthStateChange` BEFORE launching the browser, waits on a `Completer`. On app resume, an 8-second grace period; if no `signedIn` event arrives, completes with the `oauthDeepLinkTimeout` sentinel (`__OAUTH_DEEP_LINK_TIMEOUT__`) for the UI to localize. supabase_flutter handles the PKCE code exchange via its deep-link handler.
  - Desktop (`_signInWithOAuthDesktop`): binds an ephemeral `localhost:0` HTTP server, uses `http://localhost:<port>/auth/callback` as redirect, catches the `?code`, serves a styled success HTML page, then `exchangeCodeForSession(code)`.
- Constant: deep-link scheme `_authRedirect = 'com.elymsyr.dungeonmastertool://auth-callback'` (registered in Android manifest / iOS Info.plist / desktop scheme registration).
- App-icon base64 is lazily cached in module-level `_cachedIconBase64`.

## Notes
- Email confirmation is handled by a hosted web page (token_hash + verifyOtp), not a deep link — so `signUp` sets no `emailRedirectTo` (see `docs/email_confirmation_setup.md`).
