import 'projection_item.dart';
import 'projection_output_mode.dart';

/// Top-level projection state — owned by `ProjectionController` on the DM
/// side, mirrored to the player sub-window via IPC, and to remote players
/// via the `world_projection` manifest.
///
/// Multiple items can be open simultaneously; the DM switches between them
/// via the projection panel in the Session tab. The player window renders
/// the active item via an `IndexedStack` for zero-latency switching.
class ProjectionState {
  final List<ProjectionItem> items;

  /// Currently displayed item id. Null if no items are open or blackout is on.
  final String? activeItemId;

  /// Which output modes are currently active. Empty = no output. Multiple
  /// modes can run at once (e.g. second window + online fan-out).
  final Set<ProjectionOutputMode> outputModes;

  /// Global "go dark now" override — independent of items. F9 toggle.
  final bool blackoutOverride;

  const ProjectionState({
    this.items = const [],
    this.activeItemId,
    this.outputModes = const {},
    this.blackoutOverride = false,
  });

  /// Whether any output is currently active.
  bool get isActive => outputModes.isNotEmpty;

  /// First active mode, or [ProjectionOutputMode.none] when nothing is
  /// active. For single-icon status UI that pre-dates fan-out.
  ProjectionOutputMode get primaryMode =>
      outputModes.isEmpty ? ProjectionOutputMode.none : outputModes.first;

  ProjectionState copyWith({
    List<ProjectionItem>? items,
    Object? activeItemId = _sentinel,
    Set<ProjectionOutputMode>? outputModes,
    bool? blackoutOverride,
  }) {
    return ProjectionState(
      items: items ?? this.items,
      activeItemId: identical(activeItemId, _sentinel)
          ? this.activeItemId
          : activeItemId as String?,
      outputModes: outputModes ?? this.outputModes,
      blackoutOverride: blackoutOverride ?? this.blackoutOverride,
    );
  }

  ProjectionItem? get activeItem {
    if (activeItemId == null) return null;
    for (final item in items) {
      if (item.id == activeItemId) return item;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'activeItemId': activeItemId,
        // IPC backward compat: player window still reads `windowOpen`.
        'windowOpen': isActive,
        'outputModes': outputModes.map((m) => m.name).toList(),
        'blackoutOverride': blackoutOverride,
      };

  factory ProjectionState.fromJson(Map<String, dynamic> json) {
    return ProjectionState(
      items: (json['items'] as List)
          .map((e) =>
              ProjectionItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      activeItemId: json['activeItemId'] as String?,
      outputModes: _modesFromJson(json),
      blackoutOverride: json['blackoutOverride'] as bool? ?? false,
    );
  }

  static ProjectionOutputMode? _modeByName(Object? name) =>
      ProjectionOutputMode.values
          .where((m) => m.name == name)
          .firstOrNull;

  static Set<ProjectionOutputMode> _modesFromJson(Map<String, dynamic> json) {
    final raw = json['outputModes'];
    if (raw is List) {
      return raw
          .map(_modeByName)
          .whereType<ProjectionOutputMode>()
          .where((m) => m != ProjectionOutputMode.none)
          .toSet();
    }
    // Backward compat: single-mode `outputMode` payloads.
    final single = _modeByName(json['outputMode']);
    if (single != null && single != ProjectionOutputMode.none) {
      return {single};
    }
    // Oldest payloads: only `windowOpen`.
    return (json['windowOpen'] as bool? ?? false)
        ? {ProjectionOutputMode.secondWindow}
        : {};
  }
}

const _sentinel = Object();
