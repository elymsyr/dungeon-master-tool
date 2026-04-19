import '../../../domain/dnd5e/combat/encounter.dart';

/// Persistence boundary for [Encounter] aggregates. The combat services
/// depend only on this interface so they can run identically against an
/// in-memory store (tests, offline mode prototypes) and a Drift-backed
/// implementation (real persistence — separate task, blocked on Doc 03 row
/// shapes for combatants).
abstract class EncounterRepository {
  Future<Encounter?> findById(String id);
  Future<void> save(Encounter encounter);
  Future<void> delete(String id);
  Future<List<Encounter>> listAll();
}

/// Process-local implementation backed by a `Map`. Sufficient for tests,
/// service-layer composition checks, and offline-mode bring-up before the
/// Drift schema for combatants lands.
class InMemoryEncounterRepository implements EncounterRepository {
  final Map<String, Encounter> _store = {};

  @override
  Future<Encounter?> findById(String id) async => _store[id];

  @override
  Future<void> save(Encounter encounter) async {
    _store[encounter.id] = encounter;
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Future<List<Encounter>> listAll() async => List.unmodifiable(_store.values);
}
