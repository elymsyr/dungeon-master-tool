import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'ui_state';

/// copyWith sentinel — distinguish "not supplied" from explicit null.
const Object _sentinel = Object();

/// Which right sidebar is currently open (mutually exclusive).
enum RightSidebar { none, pdf, soundmap, characters }

/// Kalıcı UI state — PyQt'deki closeEvent/restoreState karşılığı.
/// SharedPreferences ile kaydedilir, uygulama açılışında restore edilir.
class UiState {
  // Main
  final int mainTabIndex;
  final bool sidebarOpen;
  final double sidebarWidth;

  // Database
  final double dbSplitterRatio;
  /// Open tab ids per world. Keyed by world id (activeCampaignProvider).
  /// Empty world id (null active) is keyed as ''.
  final Map<String, List<String>> dbOpenLeftByWorld;
  final Map<String, List<String>> dbOpenRightByWorld;
  final Map<String, int> dbActiveLeftByWorld;
  final Map<String, int> dbActiveRightByWorld;
  /// Persisted database-sidebar filter selections, keyed by world id
  /// (activeCampaignProvider). Empty world id (null active) is keyed as ''.
  /// Empty/absent = "show all". Per-world so filters don't leak across worlds
  /// and survive exit/re-entry.
  final Map<String, List<String>> dbFilterSlugsByWorld;
  final Map<String, List<String>> dbFilterSourcesByWorld;
  /// DM-only sharing filter — stores `_ShareFilter.name` strings.
  final Map<String, List<String>> dbFilterShareModesByWorld;
  /// Sort mode — stores `_SortMode.name` string.
  final Map<String, String> dbSortModeByWorld;

  // Session
  final double sessionMainSplitterRatio;
  final double sessionRightSplitterRatio;
  final int sessionBottomTab;
  final int sessionMobileTab;

  // Right Sidebar (PDF / Soundmap)
  final RightSidebar rightSidebar;
  final double pdfSidebarWidth; // shared width for both PDF and Soundmap
  final List<String> pdfOpenPaths;
  final int pdfActiveIndex;
  /// Last-opened character inside the right Characters sidebar. Restored
  /// when the sidebar is reopened so the user lands where they left off.
  /// null = list view.
  final String? charactersSidebarInlineId;

  // Theme & Locale
  final String themeName;
  final String localeCode;

  // Volume
  final double volume;

  // Save & Sync
  final bool autoLocalSave;

  // First-launch onboarding: welcome/beta dialog shown once.
  final bool welcomeSeen;

  const UiState({
    this.mainTabIndex = 0,
    this.sidebarOpen = true,
    this.sidebarWidth = 280,
    this.dbSplitterRatio = 0.5,
    this.dbOpenLeftByWorld = const {},
    this.dbOpenRightByWorld = const {},
    this.dbActiveLeftByWorld = const {},
    this.dbActiveRightByWorld = const {},
    this.dbFilterSlugsByWorld = const {},
    this.dbFilterSourcesByWorld = const {},
    this.dbFilterShareModesByWorld = const {},
    this.dbSortModeByWorld = const {},
    this.sessionMainSplitterRatio = 0.35,
    this.sessionRightSplitterRatio = 0.4,
    this.sessionBottomTab = 0,
    this.sessionMobileTab = 0,
    this.rightSidebar = RightSidebar.none,
    this.pdfSidebarWidth = 450,
    this.pdfOpenPaths = const [],
    this.pdfActiveIndex = -1,
    this.charactersSidebarInlineId,
    this.themeName = 'dark',
    this.localeCode = 'en',
    this.volume = 1.0,
    this.autoLocalSave = true,
    this.welcomeSeen = false,
  });

  UiState copyWith({
    int? mainTabIndex,
    bool? sidebarOpen,
    double? sidebarWidth,
    double? dbSplitterRatio,
    Map<String, List<String>>? dbOpenLeftByWorld,
    Map<String, List<String>>? dbOpenRightByWorld,
    Map<String, int>? dbActiveLeftByWorld,
    Map<String, int>? dbActiveRightByWorld,
    Map<String, List<String>>? dbFilterSlugsByWorld,
    Map<String, List<String>>? dbFilterSourcesByWorld,
    Map<String, List<String>>? dbFilterShareModesByWorld,
    Map<String, String>? dbSortModeByWorld,
    double? sessionMainSplitterRatio,
    double? sessionRightSplitterRatio,
    int? sessionBottomTab,
    int? sessionMobileTab,
    RightSidebar? rightSidebar,
    double? pdfSidebarWidth,
    List<String>? pdfOpenPaths,
    int? pdfActiveIndex,
    Object? charactersSidebarInlineId = _sentinel,
    String? themeName,
    String? localeCode,
    double? volume,
    bool? autoLocalSave,
    bool? welcomeSeen,
  }) {
    return UiState(
      mainTabIndex: mainTabIndex ?? this.mainTabIndex,
      sidebarOpen: sidebarOpen ?? this.sidebarOpen,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      dbSplitterRatio: dbSplitterRatio ?? this.dbSplitterRatio,
      dbOpenLeftByWorld: dbOpenLeftByWorld ?? this.dbOpenLeftByWorld,
      dbOpenRightByWorld: dbOpenRightByWorld ?? this.dbOpenRightByWorld,
      dbActiveLeftByWorld: dbActiveLeftByWorld ?? this.dbActiveLeftByWorld,
      dbActiveRightByWorld: dbActiveRightByWorld ?? this.dbActiveRightByWorld,
      dbFilterSlugsByWorld: dbFilterSlugsByWorld ?? this.dbFilterSlugsByWorld,
      dbFilterSourcesByWorld:
          dbFilterSourcesByWorld ?? this.dbFilterSourcesByWorld,
      dbFilterShareModesByWorld:
          dbFilterShareModesByWorld ?? this.dbFilterShareModesByWorld,
      dbSortModeByWorld: dbSortModeByWorld ?? this.dbSortModeByWorld,
      sessionMainSplitterRatio: sessionMainSplitterRatio ?? this.sessionMainSplitterRatio,
      sessionRightSplitterRatio: sessionRightSplitterRatio ?? this.sessionRightSplitterRatio,
      sessionBottomTab: sessionBottomTab ?? this.sessionBottomTab,
      sessionMobileTab: sessionMobileTab ?? this.sessionMobileTab,
      rightSidebar: rightSidebar ?? this.rightSidebar,
      pdfSidebarWidth: pdfSidebarWidth ?? this.pdfSidebarWidth,
      pdfOpenPaths: pdfOpenPaths ?? this.pdfOpenPaths,
      pdfActiveIndex: pdfActiveIndex ?? this.pdfActiveIndex,
      charactersSidebarInlineId: identical(charactersSidebarInlineId, _sentinel)
          ? this.charactersSidebarInlineId
          : charactersSidebarInlineId as String?,
      themeName: themeName ?? this.themeName,
      localeCode: localeCode ?? this.localeCode,
      volume: volume ?? this.volume,
      autoLocalSave: autoLocalSave ?? this.autoLocalSave,
      welcomeSeen: welcomeSeen ?? this.welcomeSeen,
    );
  }

  Map<String, dynamic> toJson() => {
    'mainTabIndex': mainTabIndex,
    'sidebarOpen': sidebarOpen,
    'sidebarWidth': sidebarWidth,
    'dbSplitterRatio': dbSplitterRatio,
    'dbOpenLeftByWorld': dbOpenLeftByWorld,
    'dbOpenRightByWorld': dbOpenRightByWorld,
    'dbActiveLeftByWorld': dbActiveLeftByWorld,
    'dbActiveRightByWorld': dbActiveRightByWorld,
    'dbFilterSlugsByWorld': dbFilterSlugsByWorld,
    'dbFilterSourcesByWorld': dbFilterSourcesByWorld,
    'dbFilterShareModesByWorld': dbFilterShareModesByWorld,
    'dbSortModeByWorld': dbSortModeByWorld,
    'sessionMainSplitterRatio': sessionMainSplitterRatio,
    'sessionRightSplitterRatio': sessionRightSplitterRatio,
    'sessionBottomTab': sessionBottomTab,
    'sessionMobileTab': sessionMobileTab,
    'rightSidebar': rightSidebar.name,
    'pdfSidebarWidth': pdfSidebarWidth,
    'pdfOpenPaths': pdfOpenPaths,
    'pdfActiveIndex': pdfActiveIndex,
    'charactersSidebarInlineId': charactersSidebarInlineId,
    'themeName': themeName,
    'localeCode': localeCode,
    'volume': volume,
    'autoLocalSave': autoLocalSave,
    'welcomeSeen': welcomeSeen,
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
      dbOpenLeftByWorld: _decodeListMap(json['dbOpenLeftByWorld']),
      dbOpenRightByWorld: _decodeListMap(json['dbOpenRightByWorld']),
      dbActiveLeftByWorld: _decodeIntMap(json['dbActiveLeftByWorld']),
      dbActiveRightByWorld: _decodeIntMap(json['dbActiveRightByWorld']),
      // Legacy flat `dbFilterSlugs` (global list) intentionally dropped —
      // one-time filter reset on upgrade.
      dbFilterSlugsByWorld: _decodeListMap(json['dbFilterSlugsByWorld']),
      dbFilterSourcesByWorld: _decodeListMap(json['dbFilterSourcesByWorld']),
      dbFilterShareModesByWorld:
          _decodeListMap(json['dbFilterShareModesByWorld']),
      dbSortModeByWorld: _decodeStringMap(json['dbSortModeByWorld']),
      sessionMainSplitterRatio: (json['sessionMainSplitterRatio'] as num?)?.toDouble() ?? 0.35,
      sessionRightSplitterRatio: (json['sessionRightSplitterRatio'] as num?)?.toDouble() ?? 0.4,
      sessionBottomTab: json['sessionBottomTab'] as int? ?? 0,
      sessionMobileTab: json['sessionMobileTab'] as int? ?? 0,
      rightSidebar: rightSidebar,
      pdfSidebarWidth: (json['pdfSidebarWidth'] as num?)?.toDouble() ?? 450,
      pdfOpenPaths: (json['pdfOpenPaths'] as List?)?.cast<String>() ?? const [],
      pdfActiveIndex: json['pdfActiveIndex'] as int? ?? -1,
      charactersSidebarInlineId: json['charactersSidebarInlineId'] as String?,
      themeName: json['themeName'] as String? ?? 'dark',
      localeCode: json['localeCode'] as String? ?? 'en',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      autoLocalSave: json['autoLocalSave'] as bool? ?? true,
      welcomeSeen: json['welcomeSeen'] as bool? ?? false,
    );
  }
}

Map<String, List<String>> _decodeListMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, List<String>>{};
  raw.forEach((k, v) {
    if (k is String && v is List) {
      out[k] = v.whereType<String>().toList();
    }
  });
  return out;
}

Map<String, String> _decodeStringMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    if (k is String && v is String) out[k] = v;
  });
  return out;
}

Map<String, int> _decodeIntMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  raw.forEach((k, v) {
    if (k is String && v is int) out[k] = v;
  });
  return out;
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

/// Optional panel hint paired with [entityNavigationProvider]. 'left',
/// 'right', or 'opposite' (open in the panel that doesn't already host
/// the source card). null = default (left).
final entityNavigationTargetPanelProvider =
    StateProvider<String?>((ref) => null);

/// Bir built-in/pack entity edit'lendiğinde [EntityNotifier.update] yerinde
/// detach etmek yerine yeni bir homebrew kopya forklar; orijinal built-in
/// korunur. Bu sinyal, açık olan kartın/sekmenin kopyaya geçmesi için
/// database screen tarafından dinlenir. Consumer handle ettikten sonra
/// null'a resetlemeli.
class EntityForkRedirect {
  final String oldId;
  final String newId;
  const EntityForkRedirect({required this.oldId, required this.newId});
}

final entityForkRedirectProvider =
    StateProvider<EntityForkRedirect?>((ref) => null);

/// Set this to a PDF file path to open it in the PDF sidebar.
/// Consumers should reset to null after handling.
final pdfNavigationProvider = StateProvider<String?>((ref) => null);

/// Set this to open the soundmap sidebar from anywhere.
/// Consumers should reset to null after handling.
final soundmapNavigationProvider = StateProvider<bool?>((ref) => null);

/// Set this to true to switch to the Session tab and focus the projection
/// (Player Screen) bottom tab. Consumers should reset to null after handling.
final projectionPanelNavigationProvider = StateProvider<bool?>((ref) => null);
