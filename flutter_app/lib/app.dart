import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers/locale_provider.dart';
import 'application/providers/theme_provider.dart';
import 'presentation/l10n/app_localizations.dart';
import 'presentation/router/app_router.dart';
import 'presentation/theme/palettes.dart';

class DungeonMasterApp extends ConsumerWidget {
  const DungeonMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeName = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

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
      // Scrollbar ve scroll fizigi optimizasyonu
      scrollBehavior: const _AppScrollBehavior(),
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
