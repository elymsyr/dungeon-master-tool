import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';
import '../../../domain/entities/marketplace_source.dart';

/// Sidecar persistent store for marketplace ↔ local-item links. Lives outside
/// the Drift schema and outside individual item state JSON for two reasons:
///
/// 1. Templates are saved as `WorldSchema` objects whose [WorldSchema.metadata]
///    is part of the content hash. Persisting marketplace fields *inside*
///    that map would invalidate every dependent campaign's template_hash on
///    next publish. Keeping marketplace metadata out of band sidesteps that.
///
/// 2. Uniformity. Worlds, templates and packages all use the same key →
///    record schema.
///
/// Storage layout (single JSON file under [AppPaths.cacheDir]):
/// ```json
/// {
///   "world:My Campaign":  { "listing_ids": ["uuid1","uuid2"], "source": null },
///   "template:abc-123":   { "listing_ids": [], "source": { ... } }
/// }
/// ```
class MarketplaceLinksLocalDataSource {
  String get _filePath => p.join(AppPaths.cacheDir, 'marketplace_links.json');

  Map<String, _Link>? _cache;

  String _key(String itemType, String localId) => '$itemType\u0000$localId';

  Future<void> _load() async {
    if (_cache != null) return;
    final f = File(_filePath);
    if (!await f.exists()) {
      _cache = <String, _Link>{};
      return;
    }
    try {
      final raw = jsonDecode(await f.readAsString());
      final loaded = <String, _Link>{};
      if (raw is Map) {
        for (final entry in raw.entries) {
          final key = entry.key;
          if (key is! String) continue;
          final link = _Link.fromJson(entry.value);
          if (link != null) loaded[key] = link;
        }
      }
      _cache = loaded;
    } catch (_) {
      _cache = <String, _Link>{};
    }
  }

  Future<void> _save() async {
    final f = File(_filePath);
    await f.parent.create(recursive: true);
    final payload = {
      for (final e in _cache!.entries) e.key: e.value.toJson(),
    };
    await f.writeAsString(jsonEncode(payload));
  }

  /// Owner-side: listing ids the user has published for this local item.
  /// Ordered by insertion (newest last).
  Future<List<String>> getOwnedListingIds(
    String itemType,
    String localId,
  ) async {
    await _load();
    final link = _cache![_key(itemType, localId)];
    return link?.listingIds ?? const <String>[];
  }

  Future<void> addOwnedListingId({
    required String itemType,
    required String localId,
    required String listingId,
  }) async {
    await _load();
    final k = _key(itemType, localId);
    final existing = _cache![k];
    final ids = List<String>.from(existing?.listingIds ?? const <String>[]);
    if (!ids.contains(listingId)) ids.add(listingId);
    _cache![k] = _Link(listingIds: ids, source: existing?.source);
    await _save();
  }

  Future<void> removeOwnedListingId({
    required String itemType,
    required String localId,
    required String listingId,
  }) async {
    await _load();
    final k = _key(itemType, localId);
    final existing = _cache![k];
    if (existing == null) return;
    final ids = List<String>.from(existing.listingIds)..remove(listingId);
    if (ids.isEmpty && existing.source == null) {
      _cache!.remove(k);
    } else {
      _cache![k] = _Link(listingIds: ids, source: existing.source);
    }
    await _save();
  }

  Future<MarketplaceSource?> getSource(String itemType, String localId) async {
    await _load();
    return _cache![_key(itemType, localId)]?.source;
  }

  Future<void> setSource({
    required String itemType,
    required String localId,
    required MarketplaceSource source,
  }) async {
    await _load();
    final k = _key(itemType, localId);
    final existing = _cache![k];
    _cache![k] = _Link(
      listingIds: existing?.listingIds ?? const <String>[],
      source: source,
    );
    await _save();
  }

  /// Drop the entire link record for an item (used when the local item is
  /// deleted).
  Future<void> clear({
    required String itemType,
    required String localId,
  }) async {
    await _load();
    _cache!.remove(_key(itemType, localId));
    await _save();
  }

  /// Forces a re-read on next access (e.g. after the user signs out / in).
  void invalidateCache() {
    _cache = null;
  }
}

class _Link {
  final List<String> listingIds;
  final MarketplaceSource? source;
  const _Link({this.listingIds = const <String>[], this.source});

  Map<String, dynamic> toJson() => {
        if (listingIds.isNotEmpty) 'listing_ids': listingIds,
        if (source != null) 'source': source!.toJson(),
      };

  static _Link? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final idsRaw = raw['listing_ids'];
    final listingIds = idsRaw is List
        ? idsRaw.whereType<String>().toList()
        : const <String>[];
    return _Link(
      listingIds: listingIds,
      source: MarketplaceSource.fromJson(raw['source']),
    );
  }
}
