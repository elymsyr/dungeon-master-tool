import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'ui_state';

/// Kalıcı UI state — PyQt'deki closeEvent/restoreState karşılığı.
/// SharedPreferences ile kaydedilir, uygulama açılışında restore edilir.
class UiState {
  // Main
  final int mainTabIndex;
  final bool sidebarOpen;
  final double sidebarWidth;

  // Database
  final double dbSplitterRatio;
  final List<String> dbOpenLeft;
  final List<String> dbOpenRight;
  final int dbActiveLeft;
  final int dbActiveRight;

  // Session
  final double sessionMainSplitterRatio;
  final double sessionRightSplitterRatio;
  final int sessionBottomTab;

  // Theme & Locale
  final String themeName;
  final String localeCode;

  const UiState({
    this.mainTabIndex = 0,
    this.sidebarOpen = true,
    this.sidebarWidth = 280,
    this.dbSplitterRatio = 0.5,
    this.dbOpenLeft = const [],
    this.dbOpenRight = const [],
    this.dbActiveLeft = -1,
    this.dbActiveRight = -1,
    this.sessionMainSplitterRatio = 0.35,
    this.sessionRightSplitterRatio = 0.4,
    this.sessionBottomTab = 0,
    this.themeName = 'dark',
    this.localeCode = 'en',
  });

  UiState copyWith({
    int? mainTabIndex,
    bool? sidebarOpen,
    double? sidebarWidth,
    double? dbSplitterRatio,
    List<String>? dbOpenLeft,
    List<String>? dbOpenRight,
    int? dbActiveLeft,
    int? dbActiveRight,
    double? sessionMainSplitterRatio,
    double? sessionRightSplitterRatio,
    int? sessionBottomTab,
    String? themeName,
    String? localeCode,
  }) {
    return UiState(
      mainTabIndex: mainTabIndex ?? this.mainTabIndex,
      sidebarOpen: sidebarOpen ?? this.sidebarOpen,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      dbSplitterRatio: dbSplitterRatio ?? this.dbSplitterRatio,
      dbOpenLeft: dbOpenLeft ?? this.dbOpenLeft,
      dbOpenRight: dbOpenRight ?? this.dbOpenRight,
      dbActiveLeft: dbActiveLeft ?? this.dbActiveLeft,
      dbActiveRight: dbActiveRight ?? this.dbActiveRight,
      sessionMainSplitterRatio: sessionMainSplitterRatio ?? this.sessionMainSplitterRatio,
      sessionRightSplitterRatio: sessionRightSplitterRatio ?? this.sessionRightSplitterRatio,
      sessionBottomTab: sessionBottomTab ?? this.sessionBottomTab,
      themeName: themeName ?? this.themeName,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'mainTabIndex': mainTabIndex,
    'sidebarOpen': sidebarOpen,
    'sidebarWidth': sidebarWidth,
    'dbSplitterRatio': dbSplitterRatio,
    'dbOpenLeft': dbOpenLeft,
    'dbOpenRight': dbOpenRight,
    'dbActiveLeft': dbActiveLeft,
    'dbActiveRight': dbActiveRight,
    'sessionMainSplitterRatio': sessionMainSplitterRatio,
    'sessionRightSplitterRatio': sessionRightSplitterRatio,
    'sessionBottomTab': sessionBottomTab,
    'themeName': themeName,
    'localeCode': localeCode,
  };

  factory UiState.fromJson(Map<String, dynamic> json) {
    return UiState(
      mainTabIndex: json['mainTabIndex'] as int? ?? 0,
      sidebarOpen: json['sidebarOpen'] as bool? ?? true,
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 280,
      dbSplitterRatio: (json['dbSplitterRatio'] as num?)?.toDouble() ?? 0.5,
      dbOpenLeft: (json['dbOpenLeft'] as List?)?.cast<String>() ?? const [],
      dbOpenRight: (json['dbOpenRight'] as List?)?.cast<String>() ?? const [],
      dbActiveLeft: json['dbActiveLeft'] as int? ?? -1,
      dbActiveRight: json['dbActiveRight'] as int? ?? -1,
      sessionMainSplitterRatio: (json['sessionMainSplitterRatio'] as num?)?.toDouble() ?? 0.35,
      sessionRightSplitterRatio: (json['sessionRightSplitterRatio'] as num?)?.toDouble() ?? 0.4,
      sessionBottomTab: json['sessionBottomTab'] as int? ?? 0,
      themeName: json['themeName'] as String? ?? 'dark',
      localeCode: json['localeCode'] as String? ?? 'en',
    );
  }
}

class UiStateNotifier extends StateNotifier<UiState> {
  UiStateNotifier() : super(const UiState());

  /// SharedPreferences'dan yükle. App başlangıcında bir kere çağrılır.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = UiState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupted data — use defaults
      }
    }
  }

  Timer? _saveTimer;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void update(UiState Function(UiState) updater) {
    state = updater(state);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }
}

final uiStateProvider = StateNotifierProvider<UiStateNotifier, UiState>((ref) {
  return UiStateNotifier();
});
