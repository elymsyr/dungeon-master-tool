import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/theme/palettes.dart';
import 'ui_state_provider.dart';

/// Aktif tema adını tutar. UiState'den başlatılır, değişiklikler persist edilir.
class ThemeNotifier extends StateNotifier<String> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super('dark') {
    // UiState'den başlat
    state = _ref.read(uiStateProvider).themeName;
  }

  void setTheme(String themeName) {
    if (themeNames.contains(themeName)) {
      state = themeName;
      _ref.read(uiStateProvider.notifier).update((s) => s.copyWith(themeName: themeName));
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, String>(
  (ref) => ThemeNotifier(ref),
);
