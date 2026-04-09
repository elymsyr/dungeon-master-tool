import 'battle_map_snapshot.dart';
import 'entity_snapshot.dart';
import 'image_view_state.dart';

/// A single item in the DM's projection state — one tab in the player window.
///
/// Sealed Dart 3 class. JSON-serializable via a discriminated `type` field
/// so the same payload can travel over `desktop_multi_window` IPC today and
/// over the future online network bridge tomorrow (matches the
/// `projection.content_set` event payload contract).
sealed class ProjectionItem {
  String get id;
  String get label;
  String get type;

  const ProjectionItem();

  Map<String, dynamic> toJson();

  static ProjectionItem fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'image':
        return ImageProjection.fromJson(json);
      case 'entityCard':
        return EntityCardProjection.fromJson(json);
      case 'battleMap':
        return BattleMapProjection.fromJson(json);
      case 'pdf':
        return PdfProjection.fromJson(json);
      case 'blackScreen':
        return BlackScreenProjection.fromJson(json);
      default:
        throw ArgumentError('Unknown projection item type: $type');
    }
  }
}

/// One or more images shown together in the player window. Multi-image items
/// auto-layout (single / row / grid) per `ImageLayout`.
class ImageProjection extends ProjectionItem {
  @override
  final String id;
  @override
  final String label;
  final List<String> filePaths;
  final ImageLayout layout;
  final ImageViewState viewState;

  const ImageProjection({
    required this.id,
    required this.label,
    required this.filePaths,
    this.layout = ImageLayout.auto,
    this.viewState = const ImageViewState(),
  });

  @override
  String get type => 'image';

  ImageProjection copyWith({
    String? label,
    List<String>? filePaths,
    ImageLayout? layout,
    ImageViewState? viewState,
  }) {
    return ImageProjection(
      id: id,
      label: label ?? this.label,
      filePaths: filePaths ?? this.filePaths,
      layout: layout ?? this.layout,
      viewState: viewState ?? this.viewState,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'label': label,
        'filePaths': filePaths,
        'layout': layout.name,
        'viewState': viewState.toJson(),
      };

  factory ImageProjection.fromJson(Map<String, dynamic> json) => ImageProjection(
        id: json['id'] as String,
        label: json['label'] as String,
        filePaths: (json['filePaths'] as List).cast<String>(),
        layout: ImageLayout.values
                .where((l) => l.name == json['layout'])
                .firstOrNull ??
            ImageLayout.auto,
        viewState: json['viewState'] != null
            ? ImageViewState.fromJson(
                (json['viewState'] as Map).cast<String, dynamic>())
            : const ImageViewState(),
      );
}

/// A full entity card rendered in the player window. Carries a serializable
/// snapshot so the player sub-isolate doesn't need entity provider access.
class EntityCardProjection extends ProjectionItem {
  @override
  final String id;
  @override
  final String label;
  final String entityId;
  final EntitySnapshot snapshot;

  const EntityCardProjection({
    required this.id,
    required this.label,
    required this.entityId,
    required this.snapshot,
  });

  @override
  String get type => 'entityCard';

  EntityCardProjection copyWith({String? label, EntitySnapshot? snapshot}) {
    return EntityCardProjection(
      id: id,
      label: label ?? this.label,
      entityId: entityId,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'label': label,
        'entityId': entityId,
        'snapshot': snapshot.toJson(),
      };

  factory EntityCardProjection.fromJson(Map<String, dynamic> json) =>
      EntityCardProjection(
        id: json['id'] as String,
        label: json['label'] as String,
        entityId: json['entityId'] as String,
        snapshot: EntitySnapshot.fromJson(
          (json['snapshot'] as Map).cast<String, dynamic>(),
        ),
      );
}

/// A battle map mirrored to the player window. Uses state-mirroring (not
/// pixel mirroring): the DM ships a serializable [BattleMapSnapshot] each
/// time the underlying state changes, and the player sub-isolate runs its
/// own painter/canvas to render it.
class BattleMapProjection extends ProjectionItem {
  @override
  final String id;
  @override
  final String label;

  /// The encounter id whose battle map this projection mirrors. Used by
  /// the DM-side sync service to subscribe to the right `combatProvider`
  /// and `battleMapProvider` slices.
  final String encounterId;

  /// The most recent snapshot pushed to the player window.
  final BattleMapSnapshot snapshot;

  /// When `true`, the player viewport is frozen and the DM can zoom/pan
  /// freely without affecting the player screen. When `false` (default),
  /// the DM's viewport mirrors to the player in normalized coordinates.
  final bool viewportLocked;

  const BattleMapProjection({
    required this.id,
    required this.label,
    required this.encounterId,
    this.snapshot = const BattleMapSnapshot(),
    this.viewportLocked = false,
  });

  @override
  String get type => 'battleMap';

  BattleMapProjection copyWith({
    String? label,
    BattleMapSnapshot? snapshot,
    bool? viewportLocked,
  }) {
    return BattleMapProjection(
      id: id,
      label: label ?? this.label,
      encounterId: encounterId,
      snapshot: snapshot ?? this.snapshot,
      viewportLocked: viewportLocked ?? this.viewportLocked,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'label': label,
        'encounterId': encounterId,
        'snapshot': snapshot.toJson(),
        'viewportLocked': viewportLocked,
      };

  factory BattleMapProjection.fromJson(Map<String, dynamic> json) =>
      BattleMapProjection(
        id: json['id'] as String,
        label: json['label'] as String,
        encounterId: json['encounterId'] as String? ?? '',
        snapshot: json['snapshot'] != null
            ? BattleMapSnapshot.fromJson(
                (json['snapshot'] as Map).cast<String, dynamic>())
            : const BattleMapSnapshot(),
        viewportLocked: json['viewportLocked'] as bool? ?? false,
      );
}

/// A PDF page projected to the player window (Phase 3).
class PdfProjection extends ProjectionItem {
  @override
  final String id;
  @override
  final String label;
  final String filePath;
  final int page;

  const PdfProjection({
    required this.id,
    required this.label,
    required this.filePath,
    this.page = 0,
  });

  @override
  String get type => 'pdf';

  PdfProjection copyWith({String? label, int? page}) => PdfProjection(
        id: id,
        label: label ?? this.label,
        filePath: filePath,
        page: page ?? this.page,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'label': label,
        'filePath': filePath,
        'page': page,
      };

  factory PdfProjection.fromJson(Map<String, dynamic> json) => PdfProjection(
        id: json['id'] as String,
        label: json['label'] as String,
        filePath: json['filePath'] as String,
        page: json['page'] as int? ?? 0,
      );
}

/// A pure black screen tab (lets the DM "go dark" without losing the other items).
class BlackScreenProjection extends ProjectionItem {
  @override
  final String id;
  @override
  final String label;

  const BlackScreenProjection({required this.id, this.label = 'Black'});

  @override
  String get type => 'blackScreen';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'label': label,
      };

  factory BlackScreenProjection.fromJson(Map<String, dynamic> json) =>
      BlackScreenProjection(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Black',
      );
}
