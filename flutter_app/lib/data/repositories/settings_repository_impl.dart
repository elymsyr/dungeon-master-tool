import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/ui_state_provider.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final Ref _ref;
  SettingsRepositoryImpl(this._ref);

  @override
  Future<void> setTheme(String themeName) async {
    _ref.read(uiStateProvider.notifier).update((s) => s.copyWith(themeName: themeName));
  }

  @override
  Future<void> setLocale(String localeCode) async {
    _ref.read(uiStateProvider.notifier).update((s) => s.copyWith(localeCode: localeCode));
  }

  @override
  Future<void> setVolume(double volume) async {
    _ref.read(uiStateProvider.notifier).update((s) => s.copyWith(volume: volume));
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref);
});
