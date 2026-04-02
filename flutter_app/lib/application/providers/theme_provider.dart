import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/theme/palettes.dart';

/// Aktif tema adını tutar. Runtime'da değiştirilebilir.
class ThemeNotifier extends StateNotifier<String> {
  ThemeNotifier() : super('dark');

  void setTheme(String themeName) {
    if (themeNames.contains(themeName)) {
      state = themeName;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, String>(
  (ref) => ThemeNotifier(),
);
