import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/characters/character_editor_screen.dart';
import '../screens/hub/hub_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/main_screen.dart';
import '../screens/package_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/templates/template_editor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // When Supabase is configured, require authentication for all
    // routes except the landing page.
    if (!SupabaseConfig.isConfigured) return null;
    final isLanding = state.matchedLocation == '/';
    final isAuthenticated =
        Supabase.instance.client.auth.currentSession != null;
    if (!isAuthenticated && !isLanding) return '/';
    return null;
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
