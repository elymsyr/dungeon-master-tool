import '../../domain/entities/projection/projection_state.dart';

/// Abstract delivery mechanism for projection content.
///
/// Two concrete implementations:
/// - [ProjectionOutputWindow] — desktop second OS window via `desktop_multi_window`
/// - [ProjectionOutputScreencast] — external display via platform Presentation API
///
/// The [ProjectionController] delegates all transport to whichever output is
/// active, keeping content management (add/remove/reorder items) decoupled
/// from the delivery mechanism.
abstract class ProjectionOutput {
  /// Whether this output is currently active (window open, cast connected).
  bool get isActive;

  /// Activate the output (open window, connect to external display).
  /// Returns `true` on success.
  Future<bool> activate();

  /// Deactivate the output (close window, disconnect cast).
  Future<void> deactivate();

  /// Push the complete projection state to the output.
  /// Returns `false` if the output has died unexpectedly.
  Future<bool> pushFull(ProjectionState state);

  /// Push a small patch (active item change, blackout toggle).
  /// Returns `false` if the output is gone.
  Future<bool> pushPatch(Map<String, dynamic> patch);

  /// Push a targeted battle map patch for one item.
  /// Returns `false` if the output is gone.
  Future<bool> pushBattleMapPatch(String itemId, Map<String, dynamic> patch);

  /// Fires when the output is closed externally (native X button, Miracast
  /// disconnect, etc.). The controller listens to this to flip its state.
  Stream<void> get onExternalClose;

  /// Release resources.
  void dispose();
}
