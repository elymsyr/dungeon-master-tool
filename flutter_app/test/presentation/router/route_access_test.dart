import 'package:dungeon_master_tool/presentation/router/route_access.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase O1 — the offline entry is reachable.**
///
/// Before O1 the router asked one question and applied it everywhere: with the
/// Supabase defines set and no session, every route but `/` bounced to `/`, so
/// a build that *could* talk to the service refused to open a purely local
/// world. These cases pin the replacement — a per-route capability check — and
/// in particular that the three routes the audit named no longer redirect for
/// a null session.
void main() {
  group('routeRequiresAccount', () {
    test('only the account-only screens are gated', () {
      expect(accountRequiredRoutePrefixes, {'/profile', '/admin'});
      expect(routeRequiresAccount('/admin'), isTrue);
      expect(routeRequiresAccount('/profile'), isTrue);
      expect(routeRequiresAccount('/profile/me'), isTrue);
      expect(routeRequiresAccount('/profile/abc-123'), isTrue);
    });

    test('every local-only route is open', () {
      for (final loc in [
        '/',
        '/hub',
        '/main',
        '/package',
        '/character/new',
        '/character/abc-123',
        '/template/edit',
      ]) {
        expect(routeRequiresAccount(loc), isFalse, reason: loc);
      }
    });

    test('a prefix match is a path segment, not a string prefix', () {
      // `/profiles-of-monsters` must not be gated by `/profile`.
      expect(routeRequiresAccount('/profiles-of-monsters'), isFalse);
      expect(routeRequiresAccount('/administration'), isFalse);
    });
  });

  group('resolveRedirect', () {
    test('a guest is no longer bounced off the local routes', () {
      // The exact regression O1 exists for: all three used to return '/'.
      for (final loc in ['/hub', '/main', '/character/new']) {
        expect(
          resolveRedirect(
            supabaseConfigured: true,
            hasSession: false,
            location: loc,
          ),
          isNull,
          reason: '$loc must open for a null session',
        );
      }
    });

    test('an account-only route still sends a guest to the auth form', () {
      for (final loc in ['/profile/me', '/admin']) {
        expect(
          resolveRedirect(
            supabaseConfigured: true,
            hasSession: false,
            location: loc,
          ),
          '/',
          reason: loc,
        );
      }
    });

    test('a signed-in user goes anywhere', () {
      for (final loc in ['/hub', '/main', '/character/new', '/profile/me', '/admin']) {
        expect(
          resolveRedirect(
            supabaseConfigured: true,
            hasSession: true,
            location: loc,
          ),
          isNull,
          reason: loc,
        );
      }
    });

    test('a build without the defines gates nothing at all', () {
      // No auth flow exists, so even the account-only routes are not
      // redirected — they simply render their empty offline selves. This is
      // the code path guest mode reuses rather than reimplements.
      for (final loc in ['/hub', '/profile/me', '/admin']) {
        expect(
          resolveRedirect(
            supabaseConfigured: false,
            hasSession: false,
            location: loc,
          ),
          isNull,
          reason: loc,
        );
      }
    });

    test('the landing page is never redirected away from', () {
      for (final configured in [true, false]) {
        for (final session in [true, false]) {
          expect(
            resolveRedirect(
              supabaseConfigured: configured,
              hasSession: session,
              location: '/',
            ),
            isNull,
          );
        }
      }
    });
  });
}
