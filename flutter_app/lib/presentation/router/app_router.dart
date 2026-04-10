import 'package:go_router/go_router.dart';

import '../screens/hub/hub_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/main_screen.dart';
import '../screens/package_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
  ],
);
