import 'package:dungeon_master_tool/application/providers/account_gate.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/account_gated_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// **Audit phase O2.** The exit criterion, as a table rather than a list of
/// hand-written cases: every surface the roadmap enumerates gets an answer in
/// every account state, a guest gets a sign-in call to action on the gated
/// ones, and — the half that is easy to forget — nothing local is gated.
///
/// The "never constructs a Supabase client" clause is checked structurally: the
/// gated surface's content is a `WidgetBuilder`, so the test can assert the
/// builder was **never called** in guest mode. A surface whose widgets are not
/// built cannot watch a provider that reaches Supabase. (A behavioural check is
/// impossible here for the same reason O1's router decision had to become a
/// pure function: `SupabaseConfig.isConfigured` is a compile-time define and
/// `flutter test` runs with the defines unset, so the real gate can only ever
/// report `offlineBuild`. `accountGateProvider` is the seam.)

/// The surfaces §6 O2 names, spelled out here so the test fails if the enum
/// drifts away from the roadmap rather than silently agreeing with itself.
const _roadmapOnlineSurfaces = <AppSurface>{
  AppSurface.marketplace,
  AppSurface.cloudBackup,
  AppSurface.worldSharing,
  AppSurface.profile,
  AppSurface.follows,
  AppSurface.notifications,
  AppSurface.admin,
};

Widget _harness(Widget child, AccountAccess access) {
  final router = GoRouter(
    initialLocation: '/x',
    routes: [
      GoRoute(path: '/x', builder: (_, _) => Scaffold(body: child)),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('LANDING'))),
    ],
  );
  return ProviderScope(
    overrides: [accountGateProvider.overrideWithValue(access)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildThemeData('dark'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
    ),
  );
}

void main() {
  group('resolveAccountAccess', () {
    test('an unconfigured build is offlineBuild whatever the session says', () {
      expect(
        resolveAccountAccess(supabaseConfigured: false, signedIn: false),
        AccountAccess.offlineBuild,
      );
      expect(
        resolveAccountAccess(supabaseConfigured: false, signedIn: true),
        AccountAccess.offlineBuild,
      );
    });

    test('a configured build without a session is the O1 guest', () {
      expect(
        resolveAccountAccess(supabaseConfigured: true, signedIn: false),
        AccountAccess.guest,
      );
    });

    test('configured plus a session is signedIn', () {
      expect(
        resolveAccountAccess(supabaseConfigured: true, signedIn: true),
        AccountAccess.signedIn,
      );
    });
  });

  group('the surface table', () {
    test('the gated set is exactly the set §6 O2 enumerates', () {
      final gated =
          AppSurface.values.where((s) => s.requiresAccount).toSet();
      expect(gated, _roadmapOnlineSurfaces);
    });

    test('the first-party catalog is not gated — the worker serves it to '
        'anyone and it falls back to bundled assets', () {
      expect(AppSurface.firstPartyCatalog.requiresAccount, isFalse);
      for (final access in AccountAccess.values) {
        expect(
          resolveSurfaceAccess(AppSurface.firstPartyCatalog, access),
          SurfaceAccess.open,
        );
      }
    });

    test('every surface has an answer in every state', () {
      for (final surface in AppSurface.values) {
        for (final access in AccountAccess.values) {
          expect(resolveSurfaceAccess(surface, access), isNotNull,
              reason: '$surface / $access');
        }
      }
    });

    test('a guest is asked to sign in for every gated surface', () {
      for (final surface in _roadmapOnlineSurfaces) {
        expect(
          resolveSurfaceAccess(surface, AccountAccess.guest),
          SurfaceAccess.signInRequired,
          reason: '$surface',
        );
      }
    });

    test('a build with no auth flow hides them instead of asking', () {
      for (final surface in _roadmapOnlineSurfaces) {
        expect(
          resolveSurfaceAccess(surface, AccountAccess.offlineBuild),
          SurfaceAccess.hidden,
          reason: '$surface',
        );
      }
    });

    test('no local surface is gated in any state — the inverse clause', () {
      final local =
          AppSurface.values.where((s) => !s.requiresAccount).toList();
      expect(local, isNotEmpty);
      for (final surface in local) {
        for (final access in AccountAccess.values) {
          expect(resolveSurfaceAccess(surface, access), SurfaceAccess.open,
              reason: '$surface / $access');
        }
      }
    });

    test('a signed-in user is open everywhere', () {
      for (final surface in AppSurface.values) {
        expect(resolveSurfaceAccess(surface, AccountAccess.signedIn),
            SurfaceAccess.open);
      }
    });
  });

  group('AccountGatedSurface', () {
    for (final surface in _roadmapOnlineSurfaces) {
      testWidgets('$surface: a guest gets the call to action and the surface '
          'is never built', (tester) async {
        var built = false;
        await tester.pumpWidget(_harness(
          AccountGatedSurface(
            surface: surface,
            builder: (_) {
              built = true;
              return const Text('SURFACE');
            },
          ),
          AccountAccess.guest,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(SignInRequiredNotice), findsOneWidget);
        expect(find.text('Account required'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('SURFACE'), findsNothing);
        // The clause that matters: no widget of the surface was constructed,
        // so no provider of it was watched, so no Supabase client was made.
        expect(built, isFalse);
      });

      testWidgets('$surface: the call to action reaches the auth form',
          (tester) async {
        await tester.pumpWidget(_harness(
          AccountGatedSurface(surface: surface, builder: (_) => const Text('SURFACE')),
          AccountAccess.guest,
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();
        expect(find.text('LANDING'), findsOneWidget);
      });

      testWidgets('$surface: a build with no auth flow renders nothing',
          (tester) async {
        var built = false;
        await tester.pumpWidget(_harness(
          AccountGatedSurface(
            surface: surface,
            builder: (_) {
              built = true;
              return const Text('SURFACE');
            },
          ),
          AccountAccess.offlineBuild,
        ));
        await tester.pumpAndSettle();
        expect(find.byType(SignInRequiredNotice), findsNothing);
        expect(find.text('SURFACE'), findsNothing);
        expect(built, isFalse);
      });

      testWidgets('$surface: a signed-in user gets the surface itself',
          (tester) async {
        await tester.pumpWidget(_harness(
          AccountGatedSurface(surface: surface, builder: (_) => const Text('SURFACE')),
          AccountAccess.signedIn,
        ));
        await tester.pumpAndSettle();
        expect(find.text('SURFACE'), findsOneWidget);
        expect(find.byType(SignInRequiredNotice), findsNothing);
      });
    }

    for (final surface in [
      AppSurface.firstPartyCatalog,
      AppSurface.bundledPackInstall,
      AppSurface.worlds,
      AppSurface.characters,
      AppSurface.templates,
      AppSurface.packages,
      AppSurface.battlemap,
      AppSurface.secondScreen,
    ]) {
      testWidgets('$surface: renders for a guest, ungated', (tester) async {
        await tester.pumpWidget(_harness(
          AccountGatedSurface(surface: surface, builder: (_) => const Text('SURFACE')),
          AccountAccess.guest,
        ));
        await tester.pumpAndSettle();
        expect(find.text('SURFACE'), findsOneWidget);
        expect(find.byType(SignInRequiredNotice), findsNothing);
      });
    }

    testWidgets('a surface-specific message replaces the generic body',
        (tester) async {
      await tester.pumpWidget(_harness(
        AccountGatedSurface(
          surface: AppSurface.marketplace,
          message: 'because the marketplace says so',
          builder: (_) => const Text('SURFACE'),
        ),
        AccountAccess.guest,
      ));
      await tester.pumpAndSettle();
      expect(find.text('because the marketplace says so'), findsOneWidget);
    });

    testWidgets('hiddenBuilder replaces the empty box on an offline build',
        (tester) async {
      await tester.pumpWidget(_harness(
        AccountGatedSurface(
          surface: AppSurface.cloudBackup,
          builder: (_) => const Text('SURFACE'),
          hiddenBuilder: (_) => const Text('LOCAL ONLY'),
        ),
        AccountAccess.offlineBuild,
      ));
      await tester.pumpAndSettle();
      expect(find.text('LOCAL ONLY'), findsOneWidget);
    });
  });
}
