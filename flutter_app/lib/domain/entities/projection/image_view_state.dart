/// Auto layout mode for multi-image projection items.
/// Mirrors the Python `_image_layout_mode` rule in `ui/player_window.py`:
/// 1=single, 2-3=row, 4+=grid.
enum ImageLayout { auto, single, row, grid }

/// Per-item view state for image projections — zoom, pan offset, fit mode.
/// Stored on the ProjectionItem so switching tabs in the player window
/// restores the prior view.
class ImageViewState {
  final double zoom;
  final double panX;
  final double panY;
  final bool fitToScreen;

  const ImageViewState({
    this.zoom = 1.0,
    this.panX = 0,
    this.panY = 0,
    this.fitToScreen = true,
  });

  ImageViewState copyWith({
    double? zoom,
    double? panX,
    double? panY,
    bool? fitToScreen,
  }) {
    return ImageViewState(
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      fitToScreen: fitToScreen ?? this.fitToScreen,
    );
  }

  Map<String, dynamic> toJson() => {
        'zoom': zoom,
        'panX': panX,
        'panY': panY,
        'fitToScreen': fitToScreen,
      };

  factory ImageViewState.fromJson(Map<String, dynamic> json) => ImageViewState(
        zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
        panX: (json['panX'] as num?)?.toDouble() ?? 0,
        panY: (json['panY'] as num?)?.toDouble() ?? 0,
        fitToScreen: json['fitToScreen'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is ImageViewState &&
      other.zoom == zoom &&
      other.panX == panX &&
      other.panY == panY &&
      other.fitToScreen == fitToScreen;

  @override
  int get hashCode => Object.hash(zoom, panX, panY, fitToScreen);
}
