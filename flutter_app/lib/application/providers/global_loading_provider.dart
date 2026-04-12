import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single long-running operation surfaced to the user via the global
/// loading overlay. [id] is caller-owned and used to end/update the task.
class LoadingTask {
  final String id;
  final String message;
  final double? progress;
  const LoadingTask({
    required this.id,
    required this.message,
    this.progress,
  });

  LoadingTask copyWith({String? message, double? progress}) => LoadingTask(
        id: id,
        message: message ?? this.message,
        progress: progress ?? this.progress,
      );
}

class GlobalLoadingNotifier extends StateNotifier<List<LoadingTask>> {
  GlobalLoadingNotifier() : super(const []);

  void start(LoadingTask task) {
    state = [
      ...state.where((t) => t.id != task.id),
      task,
    ];
  }

  void update(String id, {String? message, double? progress}) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(message: message, progress: progress) else t,
    ];
  }

  void end(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final globalLoadingProvider =
    StateNotifierProvider<GlobalLoadingNotifier, List<LoadingTask>>(
  (_) => GlobalLoadingNotifier(),
);

/// Wraps an async operation with start/end calls on [notifier].
/// The overlay is shown for the duration of [op]; errors propagate.
///
/// Typical call site (from a widget):
/// ```dart
/// await withLoading(
///   ref.read(globalLoadingProvider.notifier),
///   'open-world',
///   "Opening world 'Waterdeep'...",
///   () => ref.read(activeCampaignProvider.notifier).load(name),
/// );
/// ```
Future<T> withLoading<T>(
  GlobalLoadingNotifier notifier,
  String id,
  String message,
  Future<T> Function() op,
) async {
  notifier.start(LoadingTask(id: id, message: message));
  try {
    return await op();
  } finally {
    notifier.end(id);
  }
}
