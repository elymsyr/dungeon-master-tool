import 'dart:collection';

/// Module-level LRU for typed-card JSON decode results. Cards rebuild on
/// every panel rebuild; without this helper, each rebuild re-ran the full
/// Freezed codec walk over the row's `bodyJson` string — ~30–80ms per
/// card on cold CR-20 stat blocks. Keyed by `id + updatedAt` so forks /
/// edits naturally invalidate when the row changes.
class BodyCache<T> {
  final int maxEntries;
  final LinkedHashMap<String, T> _entries = LinkedHashMap<String, T>();

  BodyCache({this.maxEntries = 32});

  T getOrCompute(String key, T Function() compute) {
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit;
      return hit;
    }
    final v = compute();
    _entries[key] = v;
    if (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return v;
  }
}
