/// **Audit phase O2 — one predicate for "this needs an account".**
///
/// Before this file the question was asked with two reads that answer two
/// different questions, spelled out at ~100 call sites:
/// `SupabaseConfig.isConfigured` says *"was this build wired for online"* and a
/// session read says *"is someone signed in"*. 48 of those sites already wrote
/// `!isConfigured || auth == null` — the correct predicate, copied — and the
/// rest read `isConfigured` alone, which since O1 made guest mode reachable is
/// simply wrong: a guest on a configured build is a third state neither read
/// names, and a bare `isConfigured` hands them cloud UI that cannot work.
///
/// So the states are named once, here, and the surfaces are a table rather
/// than a decision repeated per widget.
///
/// The file is pure apart from the two providers at the bottom: the table and
/// [resolveAccountAccess] take booleans, because `SupabaseConfig.isConfigured`
/// is a compile-time define and no test can make it true (the same reason O1's
/// `route_access.dart` is pure). [accountGateProvider] is the seam a widget
/// test overrides to *be* a guest.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

/// What this device can do about an account, right now.
enum AccountAccess {
  /// The build has no Supabase defines. There is no auth flow to send anyone
  /// to, so an online surface is not "locked" — it does not exist.
  offlineBuild,

  /// A configured build with nobody signed in: the O1 guest. Online surfaces
  /// exist and are one sign-in away, so they are shown and asked for.
  guest,

  /// Signed in. Everything is open (further gates, like `is_admin()`, are the
  /// surface's own business — this one only answers "is there an account").
  signedIn,
}

/// The state, from the two reads it replaces.
AccountAccess resolveAccountAccess({
  required bool supabaseConfigured,
  required bool signedIn,
}) {
  if (!supabaseConfigured) return AccountAccess.offlineBuild;
  return signedIn ? AccountAccess.signedIn : AccountAccess.guest;
}

/// Every surface whose availability depends on the answer — and, deliberately,
/// the local ones too, so the table states what is *not* gated instead of
/// leaving it to be inferred from the absence of a check.
///
/// [requiresAccount] is architecture, not policy: a surface is gated when its
/// data lives behind Supabase RLS or the Worker's JWT chain, and open when it
/// is a local file or a local Drift row.
enum AppSurface {
  // ── account-gated ────────────────────────────────────────────────────────
  /// Community listings, published snapshots, purchases — Supabase tables
  /// under RLS keyed by `auth.uid()`.
  marketplace(requiresAccount: true),

  /// `cloud_backups` rows plus the user's R2 objects, which `AssetService`
  /// reaches with `_requireToken()`.
  cloudBackup(requiresAccount: true),

  /// Shared worlds: membership, invites, presence, character claiming.
  worldSharing(requiresAccount: true),

  /// A `profiles` row — the user's own or somebody else's.
  profile(requiresAccount: true),

  /// Follows / followers, which are `auth.uid()`-scoped rows.
  follows(requiresAccount: true),

  /// Notifications, same.
  notifications(requiresAccount: true),

  /// The admin dashboard behind the `is_admin()` RPC.
  admin(requiresAccount: true),

  // ── local ────────────────────────────────────────────────────────────────
  /// **Measured, and it contradicts the phase's own premise.** The first-party
  /// catalog was assumed account-gated "by construction"; it is not.
  /// `cloudflare/src/worker.ts` documents `GET /catalog/{key}` as *public, no
  /// JWT* ("official content is world-readable"), `FirstPartyCatalogService`
  /// sends no `Authorization` header, and it falls back to
  /// `assets/first_party/` when the request fails. Gating it would take
  /// content away from guests that the server hands out to anyone.
  firstPartyCatalog(requiresAccount: false),

  /// Installing a bundled `assets/open5e_packs` pack — a local file read.
  bundledPackInstall(requiresAccount: false),

  /// Worlds, characters, templates, packages: local Drift rows.
  worlds(requiresAccount: false),
  characters(requiresAccount: false),
  templates(requiresAccount: false),
  packages(requiresAccount: false),

  /// Battlemap and the projection window — IPC and local state.
  battlemap(requiresAccount: false),
  secondScreen(requiresAccount: false);

  const AppSurface({required this.requiresAccount});

  /// True when the surface cannot function without an account.
  final bool requiresAccount;
}

/// What to do with a surface for a given [AccountAccess].
enum SurfaceAccess {
  /// Render it.
  open,

  /// Render a sign-in call to action instead of the surface. The surface's own
  /// widgets must not be built — that is what keeps a guest from constructing
  /// a Supabase client.
  signInRequired,

  /// Hide it: this build cannot reach the service at all, so there is nothing
  /// to ask for.
  hidden,
}

/// The table. Total over both enums — every surface has an answer in every
/// state, which is what makes the O2 test data-driven rather than a list of
/// hand-written cases.
SurfaceAccess resolveSurfaceAccess(AppSurface surface, AccountAccess access) {
  if (!surface.requiresAccount) return SurfaceAccess.open;
  return switch (access) {
    AccountAccess.signedIn => SurfaceAccess.open,
    AccountAccess.guest => SurfaceAccess.signInRequired,
    AccountAccess.offlineBuild => SurfaceAccess.hidden,
  };
}

/// The one gate. Watch this instead of pairing `SupabaseConfig.isConfigured`
/// with an `authProvider` read.
final accountGateProvider = Provider<AccountAccess>((ref) {
  return resolveAccountAccess(
    supabaseConfigured: SupabaseConfig.isConfigured,
    signedIn: ref.watch(authProvider) != null,
  );
});

/// Per-surface answer, for the widget that has to decide what to draw.
final surfaceAccessProvider =
    Provider.family<SurfaceAccess, AppSurface>((ref, surface) {
  return resolveSurfaceAccess(surface, ref.watch(accountGateProvider));
});

/// Shorthand for the many call sites that only ask "is there an account".
final hasAccountProvider = Provider<bool>(
    (ref) => ref.watch(accountGateProvider) == AccountAccess.signedIn);
