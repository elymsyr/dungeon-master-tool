import 'projection_item.dart';

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

  /// Whether the player sub-window is currently open.
  final bool windowOpen;

  /// Global "go dark now" override — independent of items. F9 toggle.
  final bool blackoutOverride;

  const ProjectionState({
    this.items = const [],
    this.activeItemId,
    this.windowOpen = false,
    this.blackoutOverride = false,
  });

  ProjectionState copyWith({
    List<ProjectionItem>? items,
    Object? activeItemId = _sentinel,
    bool? windowOpen,
    bool? blackoutOverride,
  }) {
    return ProjectionState(
      items: items ?? this.items,
      activeItemId: identical(activeItemId, _sentinel)
          ? this.activeItemId
          : activeItemId as String?,
      windowOpen: windowOpen ?? this.windowOpen,
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
        'windowOpen': windowOpen,
        'blackoutOverride': blackoutOverride,
      };

  factory ProjectionState.fromJson(Map<String, dynamic> json) => ProjectionState(
        items: (json['items'] as List)
            .map((e) => ProjectionItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        activeItemId: json['activeItemId'] as String?,
        windowOpen: json['windowOpen'] as bool? ?? false,
        blackoutOverride: json['blackoutOverride'] as bool? ?? false,
      );
}

const _sentinel = Object();
