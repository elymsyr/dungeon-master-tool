import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/hub/hub_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/main_screen.dart';
import '../screens/package_screen.dart';
import '../screens/profile/profile_screen.dart';

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
  ],
);
