import 'projection_item.dart';
import 'projection_output_mode.dart';

/// Top-level projection state — owned by `ProjectionController` on the DM
/// side, mirrored to the player sub-window via IPC, and (in the future) to
/// remote players via the network bridge.
///
/// Multiple items can be open simultaneously; the DM switches between them
/// via the projection panel in the Session tab. The player window renders
/// the active item via an `IndexedStack` for zero-latency switching.
class ProjectionState {
  final List<ProjectionItem> items;

  /// Currently displayed item id. Null if no items are open or blackout is on.
  final String? activeItemId;

  /// Which output mode is currently active.
  final ProjectionOutputMode outputMode;

  /// Global "go dark now" override — independent of items. F9 toggle.
  final bool blackoutOverride;

  const ProjectionState({
    this.items = const [],
    this.activeItemId,
    this.outputMode = ProjectionOutputMode.none,
    this.blackoutOverride = false,
  });

  /// Whether any output is currently active (second window or screencast).
  bool get isActive => outputMode != ProjectionOutputMode.none;

  ProjectionState copyWith({
    List<ProjectionItem>? items,
    Object? activeItemId = _sentinel,
    ProjectionOutputMode? outputMode,
    bool? blackoutOverride,
  }) {
    return ProjectionState(
      items: items ?? this.items,
      activeItemId: identical(activeItemId, _sentinel)
          ? this.activeItemId
          : activeItemId as String?,
      outputMode: outputMode ?? this.outputMode,
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
        'outputMode': outputMode.name,
        'blackoutOverride': blackoutOverride,
      };

  factory ProjectionState.fromJson(Map<String, dynamic> json) {
    final outputModeStr = json['outputMode'] as String?;
    final ProjectionOutputMode mode;
    if (outputModeStr != null) {
      mode = ProjectionOutputMode.values
              .where((m) => m.name == outputModeStr)
              .firstOrNull ??
          ProjectionOutputMode.none;
    } else {
      // Backward compat: old payloads only have `windowOpen`.
      mode = (json['windowOpen'] as bool? ?? false)
          ? ProjectionOutputMode.secondWindow
          : ProjectionOutputMode.none;
    }
    return ProjectionState(
      items: (json['items'] as List)
          .map((e) =>
              ProjectionItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      activeItemId: json['activeItemId'] as String?,
      outputMode: mode,
      blackoutOverride: json['blackoutOverride'] as bool? ?? false,
    );
  }
}

const _sentinel = Object();
