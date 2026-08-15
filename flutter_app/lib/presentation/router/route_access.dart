/// **Audit phase O1 — who is allowed where, decided per route.**
///
/// The router used to ask one question — "is there a Supabase session?" — and
/// bounce every route but `/` to the landing page when the answer was no. That
/// made offline not a mode a user can choose but a property of how the binary
/// was compiled: a build without the Supabase defines ran fine offline, and the
/// same build *with* them refused to open a local world.
///
/// The question is now asked per route: **does this destination need an
/// account at all?** Almost nothing does. Every world, character, template and
/// bundled pack lives in the local Drift database, which a guest already has
/// (`AppPaths.setUser(null)` → `AppPaths.dataRoot/db/dmt.sqlite`). Only the
/// screens that are *about* the account or the service behind it are gated.
///
/// This file is deliberately Flutter-free and pure so the decision is testable
/// without a Supabase instance — `SupabaseConfig.isConfigured` is a
/// compile-time define, so a widget test can never make it true.
library;

/// Route prefixes that cannot do anything useful without an account.
///
/// `/profile/:userId` renders a Supabase `profiles` row and `/admin` calls the
/// `is_admin()` RPC; both are empty shells for a guest. Everything else —
/// `/hub`, `/main`, `/package`, `/character/*`, `/template/*` — reads the local
/// database only.
const accountRequiredRoutePrefixes = <String>{
  '/profile',
  '/admin',
};

/// True when [location] is one of [accountRequiredRoutePrefixes] or a route
/// nested under one.
bool routeRequiresAccount(String location) {
  for (final prefix in accountRequiredRoutePrefixes) {
    if (location == prefix || location.startsWith('$prefix/')) return true;
  }
  return false;
}

/// The router's redirect, as a pure function.
///
/// Returns the location to redirect to, or null to let the navigation through.
///
/// * A build with no Supabase defines has no auth flow at all — nothing to
///   gate, nothing to redirect.
/// * A signed-in user goes anywhere.
/// * A guest goes anywhere that is not account-only. The landing page is where
///   an account-only route sends them, because that is where the auth form is.
String? resolveRedirect({
  required bool supabaseConfigured,
  required bool hasSession,
  required String location,
}) {
  if (!supabaseConfigured) return null;
  if (hasSession) return null;
  if (routeRequiresAccount(location)) return '/';
  return null;
}
