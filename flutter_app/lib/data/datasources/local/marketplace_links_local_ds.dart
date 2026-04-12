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
///    next publish, weaponizing the existing template-sync prompt against
///    its own owner. Keeping marketplace metadata out of band sidesteps that
///    entirely.
///
/// 2. Uniformity. Worlds, templates and packages all use the same key →
///    record schema, so the sync service can do one batch read for "all
///    items the user has downloaded from the marketplace" without three
///    different code paths.
///
/// Storage layout (single JSON file under [AppPaths.cacheDir]):
/// ```json
/// {
///   "world:My Campaign":   { "lineage_id": "uuid", "source": null },
///   "template:abc-123":    { "lineage_id": null,  "source": { ... } },
///   "package:Lore Vol 1":  { "lineage_id": "uuid", "source": { ... } }
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

  Future<String?> getOwnerLineageId(String itemType, String localId) async {
    await _load();
    return _cache![_key(itemType, localId)]?.lineageId;
  }

  Future<void> setOwnerLineageId({
    required String itemType,
    required String localId,
    required String lineageId,
  }) async {
    await _load();
    final k = _key(itemType, localId);
    final existing = _cache![k];
    _cache![k] = _Link(
      lineageId: lineageId,
      source: existing?.source,
    );
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
      lineageId: existing?.lineageId,
      source: source,
    );
    await _save();
  }

  /// Drop the entire link record for an item (used when the local item is
  /// deleted, or when the owner asks to "start fresh lineage").
  Future<void> clear({
    required String itemType,
    required String localId,
  }) async {
    await _load();
    _cache!.remove(_key(itemType, localId));
    await _save();
  }

  /// Drop only the lineage_id (owner side) without touching the source.
  Future<void> clearOwnerLineageId({
    required String itemType,
    required String localId,
  }) async {
    await _load();
    final k = _key(itemType, localId);
    final existing = _cache![k];
    if (existing == null) return;
    if (existing.source == null) {
      _cache!.remove(k);
    } else {
      _cache![k] = _Link(lineageId: null, source: existing.source);
    }
    await _save();
  }

  /// Used by `MarketplaceSyncService` to check every downloaded item in one
  /// pass. Returns only entries that carry a `MarketplaceSource` (i.e. items
  /// the user actually downloaded from the marketplace).
  Future<List<MarketplaceLinkEntry>> allReaderSources() async {
    await _load();
    final result = <MarketplaceLinkEntry>[];
    for (final entry in _cache!.entries) {
      final source = entry.value.source;
      if (source == null) continue;
      final parts = entry.key.split('\u0000');
      if (parts.length != 2) continue;
      result.add(MarketplaceLinkEntry(
        itemType: parts[0],
        localId: parts[1],
        source: source,
      ));
    }
    return result;
  }

  /// Forces a re-read on next access (e.g. after the user signs out / in).
  void invalidateCache() {
    _cache = null;
  }
}

class MarketplaceLinkEntry {
  final String itemType;
  final String localId;
  final MarketplaceSource source;
  const MarketplaceLinkEntry({
    required this.itemType,
    required this.localId,
    required this.source,
  });
}

class _Link {
  final String? lineageId;
  final MarketplaceSource? source;
  const _Link({this.lineageId, this.source});

  Map<String, dynamic> toJson() => {
        if (lineageId != null) 'lineage_id': lineageId,
        if (source != null) 'source': source!.toJson(),
      };

  static _Link? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lineageId = raw['lineage_id'];
    final sourceRaw = raw['source'];
    return _Link(
      lineageId: lineageId is String ? lineageId : null,
      source: MarketplaceSource.fromJson(sourceRaw),
    );
  }
}
