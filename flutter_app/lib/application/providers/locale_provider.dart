import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui_state_provider.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(const Locale('en')) {
    state = Locale(_ref.read(uiStateProvider).localeCode);
  }

  void setLocale(String languageCode) {
    state = Locale(languageCode);
    _ref.read(uiStateProvider.notifier).update((s) => s.copyWith(localeCode: languageCode));
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref),
);
