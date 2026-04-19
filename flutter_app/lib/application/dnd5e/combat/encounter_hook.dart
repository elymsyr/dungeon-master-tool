import 'encounter_event.dart';

/// Observer of [EncounterEvent]s emitted by `EncounterService`. The default
/// `on` implementation is a no-op so subclasses can override only the event
/// types they care about by using pattern matching in a single method.
///
/// Hooks must not mutate the encounter. State changes go through the
/// service; hooks observe and side-effect (logging, UI toasts, AI cue
/// queues).
abstract class EncounterHook {
  const EncounterHook();

  /// Called once per emitted event, in emission order. A hook that throws
  /// will propagate out through the service call — catch inside the hook
  /// if listener failures should be isolated.
  void on(EncounterEvent event) {}
}

/// Fan-out hook that forwards every event to a fixed list of delegates.
/// Order is preserved. A composite of zero hooks acts as the no-op default
/// used by `EncounterService` when no hook is supplied.
class CompositeEncounterHook extends EncounterHook {
  final List<EncounterHook> hooks;

  CompositeEncounterHook(List<EncounterHook> hooks)
      : hooks = List.unmodifiable(hooks);

  const CompositeEncounterHook.empty() : hooks = const [];

  @override
  void on(EncounterEvent event) {
    for (final h in hooks) {
      h.on(event);
    }
  }
}
