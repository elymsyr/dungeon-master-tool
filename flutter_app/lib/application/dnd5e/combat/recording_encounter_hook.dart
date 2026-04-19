import 'encounter_event.dart';
import 'encounter_hook.dart';

/// In-memory journaling hook. Records every event in emission order; useful
/// for tests that want to assert the lifecycle sequence and for a
/// future "session log" UI panel.
///
/// Not thread-safe — `EncounterService` runs synchronously per call.
class RecordingEncounterHook extends EncounterHook {
  final List<EncounterEvent> _events = [];

  /// Snapshot of recorded events in emission order. Returns a fresh
  /// unmodifiable copy so callers can iterate while later events arrive.
  List<EncounterEvent> get events => List.unmodifiable(_events);

  /// Returns only events that match `T` (e.g. `of<DamageDealtEvent>()`).
  List<T> of<T extends EncounterEvent>() =>
      [for (final e in _events) if (e is T) e];

  void clear() => _events.clear();

  @override
  void on(EncounterEvent event) => _events.add(event);
}
