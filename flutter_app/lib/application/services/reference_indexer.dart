import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/asset_ref.dart';
import 'reference_graph.dart';

/// JSON ağacını gezer, AssetRef-benzeri string'leri çıkarır ve
/// [ReferenceGraph]'a diff'li yazar.
///
/// Her DAO write'tan sonra (entity, character, settings, map_data, mind_map,
/// battle_map, packages) hook'lanır → DM ve CDC apply (player) aynı grafı
/// paylaşır. F4 [EvictionSweeper] orphan tespiti için bu grafı kullanır.
///
/// Detect edilen şemalar:
/// - `dmt-asset://...`  (R2 counted)
/// - `dmt-public://...` (Supabase free-media)
/// - `dmt-transient://...` (kısa-ömürlü)
///
/// Local raw path'ler şu an grafa GİRMEZ (legacy + F11 migrator onları
/// AssetRef'e çevirecek). Bu kasıtlı — graph'ın silinen path'lere bağlı
/// false-orphan vermesi önlenir.
class ReferenceIndexer {
  ReferenceIndexer(this._graph);

  final ReferenceGraph _graph;

  /// Owner'ın yeni snapshot'ından ref'leri çıkar, eski snapshot ile diff'le,
  /// asset_refs tablosunu güncelle. [json] null ise tüm ref'ler silinir.
  ///
  /// Dönen [DiffResult]: caller (örn. F4 sweeper) `removed` URI'lerini
  /// orphan check için kullanabilir.
  Future<DiffResult> reindexOwner({
    required String table,
    required String id,
    required Map<String, dynamic>? json,
    String? worldId,
  }) async {
    if (json == null) {
      final removed = await _graph.removeRefsForOwner(table, id);
      return DiffResult(added: const {}, removed: removed.toSet());
    }
    final slots = <RefSlot>[];
    _collect(json, slots, '');
    return _graph.replaceRefsForOwner(
      ownerTable: table,
      ownerId: id,
      newRefs: slots,
      worldId: worldId,
    );
  }

  /// Owner silindiğinde tüm ref'leri grafdan kaldır.
  Future<Set<String>> removeOwner(String table, String id) async {
    final removed = await _graph.removeRefsForOwner(table, id);
    return removed.toSet();
  }

  /// World silindiğinde grafı temizle.
  Future<Set<String>> removeWorld(String worldId) async {
    final removed = await _graph.removeRefsForWorld(worldId);
    return removed.toSet();
  }

  /// Static — testler ve PreWarmOrchestrator (F6) tarafından da kullanılır.
  /// Verilen JSON ağacındaki tüm AssetRef-benzeri string'leri set olarak döner.
  static Set<String> extractRefs(Object? node) {
    final out = <String>{};
    _walk(node, out);
    return out;
  }

  void _collect(Object? node, List<RefSlot> out, String path) {
    if (node == null) return;
    if (node is String) {
      if (_isAssetRef(node)) out.add(RefSlot(uri: node, ownerField: path));
      return;
    }
    if (node is Map) {
      for (final entry in node.entries) {
        final k = entry.key.toString();
        _collect(entry.value, out, path.isEmpty ? k : '$path.$k');
      }
      return;
    }
    if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _collect(node[i], out, '$path[$i]');
      }
      return;
    }
  }

  static void _walk(Object? node, Set<String> out) {
    if (node == null) return;
    if (node is String) {
      if (_isAssetRef(node)) out.add(node);
      return;
    }
    if (node is Map) {
      for (final v in node.values) {
        _walk(v, out);
      }
      return;
    }
    if (node is List) {
      for (final v in node) {
        _walk(v, out);
      }
      return;
    }
  }

  static bool _isAssetRef(String s) {
    return s.startsWith(AssetRef.scheme) ||
        s.startsWith(AssetRef.publicScheme) ||
        s.startsWith(AssetRef.transientScheme);
  }

  /// Hook caller'lar için: fire-and-forget yardımcı; exception log'a düşer
  /// ama caller'ı bloklamaz. UI/sync hot-path'ten çağrılır.
  void scheduleReindex({
    required String table,
    required String id,
    required Map<String, dynamic>? json,
    String? worldId,
  }) {
    reindexOwner(table: table, id: id, json: json, worldId: worldId)
        .catchError((Object e, StackTrace s) {
      debugPrint('ReferenceIndexer.reindex error ($table/$id): $e');
      return DiffResult(added: const {}, removed: const {});
    });
  }

  void scheduleRemove(String table, String id) {
    removeOwner(table, id).catchError((Object e, StackTrace s) {
      debugPrint('ReferenceIndexer.removeOwner error ($table/$id): $e');
      return <String>{};
    });
  }
}

final referenceIndexerProvider = Provider<ReferenceIndexer>((ref) {
  return ReferenceIndexer(ref.watch(referenceGraphProvider));
});
