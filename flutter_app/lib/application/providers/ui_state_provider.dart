import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'ui_state';

/// Which right sidebar is currently open (mutually exclusive).
enum RightSidebar { none, pdf, soundmap }

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

  // Right Sidebar (PDF / Soundmap)
  final RightSidebar rightSidebar;
  final double pdfSidebarWidth; // shared width for both PDF and Soundmap
  final List<String> pdfOpenPaths;
  final int pdfActiveIndex;

  // Theme & Locale
  final String themeName;
  final String localeCode;

  // Volume
  final double volume;

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
    this.rightSidebar = RightSidebar.none,
    this.pdfSidebarWidth = 450,
    this.pdfOpenPaths = const [],
    this.pdfActiveIndex = -1,
    this.themeName = 'dark',
    this.localeCode = 'en',
    this.volume = 1.0,
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
    RightSidebar? rightSidebar,
    double? pdfSidebarWidth,
    List<String>? pdfOpenPaths,
    int? pdfActiveIndex,
    String? themeName,
    String? localeCode,
    double? volume,
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
      rightSidebar: rightSidebar ?? this.rightSidebar,
      pdfSidebarWidth: pdfSidebarWidth ?? this.pdfSidebarWidth,
      pdfOpenPaths: pdfOpenPaths ?? this.pdfOpenPaths,
      pdfActiveIndex: pdfActiveIndex ?? this.pdfActiveIndex,
      themeName: themeName ?? this.themeName,
      localeCode: localeCode ?? this.localeCode,
      volume: volume ?? this.volume,
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
    'rightSidebar': rightSidebar.name,
    'pdfSidebarWidth': pdfSidebarWidth,
    'pdfOpenPaths': pdfOpenPaths,
    'pdfActiveIndex': pdfActiveIndex,
    'themeName': themeName,
    'localeCode': localeCode,
    'volume': volume,
  };

  factory UiState.fromJson(Map<String, dynamic> json) {
    // Backward compat: migrate old pdfSidebarOpen bool → RightSidebar enum
    RightSidebar rightSidebar = RightSidebar.none;
    final rsName = json['rightSidebar'] as String?;
    if (rsName != null) {
      rightSidebar = RightSidebar.values.where((e) => e.name == rsName).firstOrNull ?? RightSidebar.none;
    } else if (json['pdfSidebarOpen'] == true) {
      rightSidebar = RightSidebar.pdf;
    }

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
      rightSidebar: rightSidebar,
      pdfSidebarWidth: (json['pdfSidebarWidth'] as num?)?.toDouble() ?? 450,
      pdfOpenPaths: (json['pdfOpenPaths'] as List?)?.cast<String>() ?? const [],
      pdfActiveIndex: json['pdfActiveIndex'] as int? ?? -1,
      themeName: json['themeName'] as String? ?? 'dark',
      localeCode: json['localeCode'] as String? ?? 'en',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
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

/// Set this to an entity ID to navigate to the Database tab and open that entity.
/// Consumers should reset to null after handling.
final entityNavigationProvider = StateProvider<String?>((ref) => null);

/// Set this to a PDF file path to open it in the PDF sidebar.
/// Consumers should reset to null after handling.
final pdfNavigationProvider = StateProvider<String?>((ref) => null);

/// Set this to open the soundmap sidebar from anywhere.
/// Consumers should reset to null after handling.
final soundmapNavigationProvider = StateProvider<bool?>((ref) => null);
