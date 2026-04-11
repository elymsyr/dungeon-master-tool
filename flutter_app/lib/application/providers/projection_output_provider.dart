import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/projection/projection_output_mode.dart';
import '../services/projection_output.dart';
import '../services/projection_output_screencast.dart';
import '../services/projection_output_window.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Which projection output modes are available on the current platform.
///
/// - Desktop: both second window and screencast
/// - Mobile: screencast only
final availableProjectionOutputsProvider =
    Provider<List<ProjectionOutputMode>>((ref) {
  if (_isDesktop) {
    return const [
      ProjectionOutputMode.secondWindow,
      ProjectionOutputMode.screencast,
    ];
  }
  return const [ProjectionOutputMode.screencast];
});

/// Factory that creates the appropriate [ProjectionOutput] for the given mode.
///
/// For [ProjectionOutputMode.screencast], a [displayId] must be provided
/// (the user picks the target display from the picker dialog).
///
/// Returns `null` if the mode is not supported on the current platform.
final projectionOutputFactoryProvider =
    Provider<ProjectionOutput? Function(ProjectionOutputMode, {String? displayId})>((ref) {
  return (mode, {String? displayId}) {
    switch (mode) {
      case ProjectionOutputMode.secondWindow:
        if (!_isDesktop) return null;
        return ProjectionOutputWindow();
      case ProjectionOutputMode.screencast:
        if (displayId == null) return null;
        return ProjectionOutputScreencast(targetDisplayId: displayId);
      case ProjectionOutputMode.none:
        return null;
    }
  };
});
