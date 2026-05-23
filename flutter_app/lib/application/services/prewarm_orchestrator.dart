import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import 'fetch_queue.dart';
import 'reference_indexer.dart';

/// Bir world açılışında kritik medya listesi → eager pre-warm.
///
/// Plan F6:
/// - Aktif tüm `world_characters` portreleri (high priority)
/// - Aktif encounter map background + tüm token resimleri (high priority)
/// - `world_projection.state_json` içindeki entity ref'leri (high priority)
///
/// Galeri / ek resimler (entity images[], mind map node images) lazy
/// kalır — widget mount sırasında [FetchQueue.schedule(low)] tetiklenir.
///
/// Trigger: [campaign_provider.completeLoad] sonu (online dünyalar için).
class PreWarmOrchestrator {
  PreWarmOrchestrator({
    required AppDatabase db,
    required FetchQueue fetchQueue,
  })  : _db = db,
        _queue = fetchQueue;

  final AppDatabase _db;
  final FetchQueue _queue;

  /// Dünya için kritik AssetRef listesini toplar ve queue'ya atar.
  /// Best-effort: hata her bir adımda log'lanır + sıradakine geç.
  Future<int> warmWorld(String worldId) async {
    final refs = <String>{};

    // 1) Karakter portreleri + ek resimleri (payload_json)
    try {
      final rows = await _db.customSelect(
        'SELECT payload_json FROM world_characters WHERE world_id = ?',
        variables: [Variable<String>(worldId)],
      ).get();
      for (final r in rows) {
        final raw = r.read<String>('payload_json');
        try {
          final decoded = jsonDecode(raw);
          refs.addAll(ReferenceIndexer.extractRefs(decoded));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('prewarm chars error: $e');
    }

    // 2) Aktif encounter — map background + tokens (settings.combat_state)
    try {
      final rows = await _db.customSelect(
        'SELECT settings_json FROM world_settings WHERE world_id = ?',
        variables: [Variable<String>(worldId)],
      ).get();
      for (final r in rows) {
        final raw = r.read<String>('settings_json');
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final combat = decoded['combat_state'];
            if (combat != null) {
              refs.addAll(ReferenceIndexer.extractRefs(combat));
            }
            final mindMaps = decoded['mind_maps'];
            if (mindMaps != null) {
              refs.addAll(ReferenceIndexer.extractRefs(mindMaps));
            }
            // Cover image vs.
            final metadata = decoded['metadata'];
            if (metadata != null) {
              refs.addAll(ReferenceIndexer.extractRefs(metadata));
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('prewarm settings error: $e');
    }

    // 3) Online projection manifest (paylaşılan entity/battle map kart)
    //    NB: world_projection mirror tablo yok — Supabase'den anlık fetch
    //    gerekir; F6 MVP'de skip, F7 sonrası entity_shares zaten high
    //    priority enqueue eder.

    if (refs.isEmpty) return 0;
    _queue.scheduleAll(refs, priority: FetchPriority.high);
    return refs.length;
  }
}

final preWarmOrchestratorProvider = Provider<PreWarmOrchestrator>((ref) {
  return PreWarmOrchestrator(
    db: ref.watch(appDatabaseProvider),
    fetchQueue: ref.watch(fetchQueueProvider),
  );
});
