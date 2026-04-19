import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/dnd5e/bootstrap/srd_bootstrap_service.dart';
import 'application/providers/locale_provider.dart';
import 'application/providers/srd_bootstrap_provider.dart';
import 'application/providers/theme_provider.dart';
import 'presentation/l10n/app_localizations.dart';
import 'presentation/router/app_router.dart';
import 'presentation/theme/palettes.dart';
import 'presentation/widgets/global_loading_overlay.dart';

/// Global ScaffoldMessenger key — lets app-level listeners (such as
/// the SRD bootstrap outcome watcher) post snackbars from outside the
/// router subtree.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class DungeonMasterApp extends ConsumerWidget {
  const DungeonMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeName = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    // Surface SRD bootstrap completion / failure as a one-shot snackbar.
    // Fires once per outcome write — UserSessionNotifier.activate triggers
    // runSrdBootstrap on first login per session; on a fresh install this
    // posts the "SRD Core installed" toast, on a corrupted asset it posts
    // the error message. AlreadyInstalled is silent (no signal worth
    // interrupting the user for).
    ref.listen<SrdBootstrapOutcome?>(srdBootstrapOutcomeProvider,
        (prev, next) {
      if (next == null || identical(prev, next)) return;
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      switch (next) {
        case SrdBootstrapInstalled(:final version):
          messenger.showSnackBar(
            SnackBar(
              content: Text('SRD Core $version installed.'),
              duration: const Duration(seconds: 3),
            ),
          );
        case SrdBootstrapError(:final message):
          messenger.showSnackBar(
            SnackBar(
              content: Text('SRD Core install failed: $message'),
              duration: const Duration(seconds: 6),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        case SrdBootstrapAlreadyInstalled():
          break;
      }
    });

    return MaterialApp.router(
      title: 'Dungeon Master Tool',
      debugShowCheckedModeBanner: false,
      theme: buildThemeData(themeName),
      // Tema değişimi animasyonunu kapat — anlık geçiş
      themeAnimationDuration: Duration.zero,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
        Locale('de'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      scaffoldMessengerKey: scaffoldMessengerKey,
      // Scrollbar ve scroll fizigi optimizasyonu
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const GlobalLoadingOverlay(),
        ],
      ),
    );
  }
}

/// Mouse + touch + trackpad scroll desteği — desktop kullanıcıları icin
/// daha akici scroll deneyimi.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
