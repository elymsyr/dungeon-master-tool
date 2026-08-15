import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/characters/character_editor_screen.dart';
import '../screens/characters/wizard/character_creation_wizard_screen.dart';
import '../screens/hub/hub_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/main_screen.dart';
import '../screens/package_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/templates/template_editor_screen.dart';
import 'route_access.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // O1 — a per-route capability check, not a session check. A guest reaches
    // every local-only screen; only the account-only routes bounce to the
    // landing page. The decision itself lives in `route_access.dart` so it can
    // be tested without a live Supabase (`isConfigured` is a compile-time
    // define a test can never flip).
    return resolveRedirect(
      supabaseConfigured: SupabaseConfig.isConfigured,
      hasSession: SupabaseConfig.isConfigured &&
          Supabase.instance.client.auth.currentSession != null,
      location: state.matchedLocation,
    );
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/hub',
      builder: (context, state) => const HubScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/package',
      builder: (context, state) => const PackageScreen(),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) => ProfileScreen(
        userId: state.pathParameters['userId'] ?? 'me',
        openEditOnLoad: state.uri.queryParameters['edit'] == '1',
      ),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/character/new',
      builder: (context, state) => const CharacterCreationWizardScreen(),
    ),
    GoRoute(
      path: '/character/:id',
      builder: (context, state) =>
          CharacterEditorScreen(characterId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/template/edit',
      builder: (context, state) {
        final extra = state.extra;
        WorldSchema schema;
        if (extra is WorldSchema) {
          schema = extra;
        } else if (extra is ({WorldSchema schema, bool isNew})) {
          schema = extra.schema;
        } else {
          schema = generateBuiltinDnd5eV2Schema().schema;
        }
        return TemplateEditorScreen(initial: schema);
      },
    ),
  ],
);
