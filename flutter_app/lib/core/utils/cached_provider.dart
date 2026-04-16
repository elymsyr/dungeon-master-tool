import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight in-memory TTL cache for Riverpod providers.
///
/// Usage inside a `FutureProvider` body:
/// ```dart
/// return cachedFetch(
///   ref: ref,
///   cacheKey: 'feed:all',
///   ttl: const Duration(minutes: 2),
///   fetch: () => remotDs.fetchFeed(),
/// );
/// ```
///
/// Mutation sites must call [invalidateCache] or [invalidateCachePrefix]
/// **before** `ref.invalidate(provider)` to force a fresh fetch.

class _CacheEntry {
  final dynamic data;
  final DateTime fetchedAt;
  _CacheEntry(this.data, this.fetchedAt);
  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) < ttl;
}

final _cache = <String, _CacheEntry>{};

/// Clears a specific cache key. Call before `ref.invalidate(provider)`
/// in mutation code to force a fresh fetch.
void invalidateCache(String key) => _cache.remove(key);

/// Clears cache entries whose key starts with [prefix].
void invalidateCachePrefix(String prefix) =>
    _cache.removeWhere((key, _) => key.startsWith(prefix));

/// Clears the entire cache. Call on sign-out.
void clearCache() => _cache.clear();

/// Returns the age of a cache entry, or `null` if no entry exists.
/// Used for debouncing realtime-triggered invalidations.
Duration? cacheAge(String key) {
  final entry = _cache[key];
  if (entry == null) return null;
  return DateTime.now().difference(entry.fetchedAt);
}

/// Wraps a fetch call with in-memory TTL caching.
///
/// When the provider body re-executes and the cached data is still fresh,
/// the cached data is returned without a network call. A [Timer] is
/// scheduled to auto-invalidate the provider when the TTL expires.
///
/// Mutation-based invalidation must call [invalidateCache] for the
/// relevant key(s) before calling `ref.invalidate(provider)`.
Future<T> cachedFetch<T>({
  required Ref ref,
  required String cacheKey,
  required Duration ttl,
  required Future<T> Function() fetch,
}) async {
  final cached = _cache[cacheKey];
  if (cached != null && cached.isFresh(ttl)) {
    // Still fresh — return cached data, schedule expiry for remaining time.
    final remaining = ttl - DateTime.now().difference(cached.fetchedAt);
    final timer = Timer(remaining, () {
      _cache.remove(cacheKey);
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
    return cached.data as T;
  }

  // Stale or missing — fetch fresh data.
  final data = await fetch();
  _cache[cacheKey] = _CacheEntry(data, DateTime.now());

  // Schedule auto-invalidation at TTL expiry.
  final timer = Timer(ttl, () {
    _cache.remove(cacheKey);
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return data;
}
