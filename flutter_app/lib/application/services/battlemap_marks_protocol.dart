import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/id_gen.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';

/// Append-only ops protokolü — F8.
///
/// Eski yol: her stroke/fog/circle değişikliğinde `world_battlemap_marks`
/// satırının full state JSON'u re-upload. Sorun: payload sürekli büyür,
/// 30 dk encounter'da binlerce KB push, player rebuild fırtınası.
///
/// Yeni yol: `world_battlemap_mark_ops` tablosuna küçük event satırı
/// append. Client local mirror'da (`bm_mark_ops_local`) tutar + render
/// için snapshot ile birleştirir. DM-side periyodik compaction (5dk veya
/// 500 op) yeni snapshot yazar + eski ops'ları siler.
///
/// Bu sınıf MVP — caller wiring (battlemap_marks_service refactor) bir
/// sonraki PR'da. Protokol kod-ready: push/apply/compact/snapshot reload.
class BattleMapMarksProtocol {
  BattleMapMarksProtocol({
    required AppDatabase db,
    required SupabaseClient? supabase,
  })  : _db = db,
        _sb = supabase;

  final AppDatabase _db;
  final SupabaseClient? _sb;

  static const Duration compactionInterval = Duration(minutes: 5);
  static const int compactionOpThreshold = 500;

  /// Yeni op'u local mirror'a yazar + (online ise) cloud'a push eder.
  /// Push outbox'a gönderilebilir; MVP'de doğrudan upsert — failure best-effort.
  Future<MarkOp> pushOp({
    required String worldId,
    required String encounterId,
    required String authorId,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final opId = newId();
    final seq = DateTime.now().microsecondsSinceEpoch;
    final createdAt = DateTime.now().toUtc();
    final payloadJson = jsonEncode(payload);

    // Local mirror — render anında merge için.
    await _db.customStatement(
      'INSERT OR IGNORE INTO bm_mark_ops_local '
      '(op_id, world_id, encounter_id, author_id, kind, payload_json, seq, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [opId, worldId, encounterId, authorId, kind, payloadJson, seq,
        createdAt.millisecondsSinceEpoch],
    );

    final op = MarkOp(
      opId: opId,
      worldId: worldId,
      encounterId: encounterId,
      authorId: authorId,
      kind: kind,
      payload: payload,
      seq: seq,
      createdAt: createdAt,
    );

    // Cloud push — best-effort. Outbox routing bir sonraki PR.
    final sb = _sb;
    if (sb != null && SupabaseConfig.isConfigured) {
      try {
        await sb.from('world_battlemap_mark_ops').insert({
          'op_id': opId,
          'world_id': worldId,
          'encounter_id': encounterId,
          'author_id': authorId,
          'kind': kind,
          'payload_json': payloadJson,
          'seq': seq,
          'created_at': createdAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('BattleMapMarksProtocol.pushOp cloud error: $e');
      }
    }

    return op;
  }

  /// Realtime CDC veya periodik fetch'le gelen op'u local mirror'a uygular.
  /// Idempotent: aynı op_id ikinci kez gelirse INSERT OR IGNORE no-op.
  Future<void> applyOp(MarkOp op) async {
    await _db.customStatement(
      'INSERT OR IGNORE INTO bm_mark_ops_local '
      '(op_id, world_id, encounter_id, author_id, kind, payload_json, seq, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        op.opId,
        op.worldId,
        op.encounterId,
        op.authorId,
        op.kind,
        jsonEncode(op.payload),
        op.seq,
        op.createdAt.millisecondsSinceEpoch,
      ],
    );
  }

  /// Belirli encounter için tüm op'ları seq sırasıyla oku. Snapshot ile
  /// merge edip render layer'ı kullanır.
  Future<List<MarkOp>> loadOpsForEncounter({
    required String worldId,
    required String encounterId,
    int? sinceSeq,
  }) async {
    final rows = await _db.customSelect(
      'SELECT op_id, author_id, kind, payload_json, seq, created_at '
      'FROM bm_mark_ops_local '
      'WHERE world_id = ? AND encounter_id = ? '
      '${sinceSeq != null ? "AND seq > ?" : ""} '
      'ORDER BY seq ASC',
      variables: [
        Variable<String>(worldId),
        Variable<String>(encounterId),
        if (sinceSeq != null) Variable<int>(sinceSeq),
      ],
    ).get();
    return rows.map((r) {
      final raw = r.read<String>('payload_json');
      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(raw);
        payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        payload = const {};
      }
      return MarkOp(
        opId: r.read<String>('op_id'),
        worldId: worldId,
        encounterId: encounterId,
        authorId: r.read<String>('author_id'),
        kind: r.read<String>('kind'),
        payload: payload,
        seq: r.read<int>('seq'),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      );
    }).toList();
  }

  /// Encounter için lokal op sayısı — compaction tetikleme metriği.
  Future<int> opCount({
    required String worldId,
    required String encounterId,
  }) async {
    final rows = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM bm_mark_ops_local '
      'WHERE world_id = ? AND encounter_id = ?',
      variables: [
        Variable<String>(worldId),
        Variable<String>(encounterId),
      ],
    ).get();
    return rows.isEmpty ? 0 : rows.first.read<int>('n');
  }

  /// DM-side compaction: bu seq'e kadar olan tüm op'ları sil (snapshot
  /// kaydedildikten sonra). Cloud'da [compact_battlemap_marks] RPC çağrılır;
  /// local mirror'da paralel DELETE.
  Future<void> compact({
    required String worldId,
    required String encounterId,
    required int highWaterSeq,
  }) async {
    await _db.customStatement(
      'DELETE FROM bm_mark_ops_local '
      'WHERE world_id = ? AND encounter_id = ? AND seq <= ?',
      [worldId, encounterId, highWaterSeq],
    );

    final sb = _sb;
    if (sb != null && SupabaseConfig.isConfigured) {
      try {
        await sb.rpc('compact_battlemap_marks', params: {
          'p_world_id': worldId,
          'p_encounter_id': encounterId,
          'p_high_water': highWaterSeq,
        });
      } catch (e) {
        debugPrint('BattleMapMarksProtocol.compact cloud error: $e');
      }
    }
  }
}

class MarkOp {
  MarkOp({
    required this.opId,
    required this.worldId,
    required this.encounterId,
    required this.authorId,
    required this.kind,
    required this.payload,
    required this.seq,
    required this.createdAt,
  });

  final String opId;
  final String worldId;
  final String encounterId;
  final String authorId;
  final String kind;
  final Map<String, dynamic> payload;
  final int seq;
  final DateTime createdAt;
}

final battlemapMarksProtocolProvider =
    Provider<BattleMapMarksProtocol>((ref) {
  return BattleMapMarksProtocol(
    db: ref.watch(appDatabaseProvider),
    supabase:
        SupabaseConfig.isConfigured ? Supabase.instance.client : null,
  );
});
